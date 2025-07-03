//
//  GraphQLSyncService.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine
import CoreData

/// GraphQL Sync Service - Demo Mode Implementation
/// Vereinfachte Synchronisation zwischen Core Data und Backend
class GraphQLSyncService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0.0
    @Published var lastSyncDate: Date?
    @Published var syncError: GraphQLError?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let context = EnhancedPersistenceController.shared.container.viewContext
    
    // Services
    private let userService = GraphQLUserService()
    private let tripService = GraphQLTripService()
    private let mediaService = GraphQLMediaService()
    
    // MARK: - Demo Mode
    
    private var isDemoMode: Bool {
        return AppSettings.shared.backendURL.contains("localhost") ||
               AppSettings.shared.backendURL.contains("127.0.0.1")
    }
    
    // MARK: - Full Sync Operations
    
    /// Vollständige Synchronisation durchführen
    /// - Returns: Publisher mit Bool (Erfolg)
    func performFullSync() -> AnyPublisher<Bool, GraphQLError> {
        if isDemoMode {
            return performDemoSync()
        }

        // Produktionsmodus: Erst Upload, dann Download
        return uploadChanges()
            .flatMap { _ in self.downloadChanges() }
            .eraseToAnyPublisher()
    }
    
    /// Nur Upload durchführen (lokale Änderungen zum Server)
    /// - Returns: Publisher mit Bool (Erfolg)
    func uploadChanges() -> AnyPublisher<Bool, GraphQLError> {
        if isDemoMode {
            return simulateUpload()
        }

        // 1) Aktuelle Trips vom Server holen
        return ApolloClientManager.shared.fetch(query: GetTripsQuery.self, cachePolicy: .networkOnly)
            .map { response -> Set<String> in
                let ids = response.trips.map { $0.id }
                return Set(ids)
            }
            .flatMap { [weak self] serverTripIds -> AnyPublisher<Bool, GraphQLError> in
                guard let self = self else {
                    return Fail(error: GraphQLError.unknown("Service deinitiert"))
                        .eraseToAnyPublisher()
                }

                // Trips, die bereits am Server existieren, aber evtl. keine Membership haben
                var claimTrips: [Trip] = []
                var createTrips: [Trip] = []
                self.context.performAndWait {
                    let request: NSFetchRequest<Trip> = Trip.fetchRequest()
                    if let localTrips = try? self.context.fetch(request) {
                        for trip in localTrips {
                            var tripUUID: String
                            if let uuid = trip.id?.uuidString {
                                tripUUID = uuid
                            } else {
                                // Generiere neue UUID für Trip ohne Backend-ID
                                let newId = UUID()
                                trip.id = newId
                                tripUUID = newId.uuidString
                            }

                            if serverTripIds.contains(tripUUID) {
                                claimTrips.append(trip)
                            } else {
                                createTrips.append(trip)
                            }
                        }
                    }
                }

                print("🚀 UploadChanges: createTrips=\(createTrips.count), claimTrips=\(claimTrips.count)")

                // 3a) Upload neue Trips
                let uploadPublishers = createTrips.compactMap { trip -> AnyPublisher<Bool, GraphQLError>? in
                    guard let dto = TripDTO.from(coreData: trip) else { return nil }

                    return self.tripService.createTrip(
                        name: dto.name,
                        description: dto.tripDescription,
                        startDate: dto.startDate,
                        endDate: dto.endDate
                    )
                    .tryMap { createdDTO -> Bool in
                        // Backend-ID in Core Data Trip übernehmen
                        self.context.performAndWait {
                            if let newUUID = UUID(uuidString: createdDTO.id) {
                                trip.id = newUUID
                                try? self.context.save()
                            }
                        }
                        print("✅ Trip '\(dto.name)' hochgeladen (Server-ID: \(createdDTO.id))")
                        return true
                    }
                    .mapError { error -> GraphQLError in
                        if let gError = error as? GraphQLError { return gError }
                        return GraphQLError.serverError(error.localizedDescription)
                    }
                    .eraseToAnyPublisher()
                }

                // 3b) Claim bestehende Trips
                let claimPublishers = claimTrips.compactMap { trip -> AnyPublisher<Bool, GraphQLError>? in
                    guard let idStr = trip.id?.uuidString else { return nil }
                    return self.tripService.claimTrip(id: idStr)
                        .map { _ in true }
                        .eraseToAnyPublisher()
                }

                let allPublishers = uploadPublishers + claimPublishers

                guard !allPublishers.isEmpty else {
                    return Just(true)
                        .setFailureType(to: GraphQLError.self)
                        .eraseToAnyPublisher()
                }

                // 4) Sequenziell ausführen und Ergebnis zusammenführen
                return allPublishers
                    .publisher
                    .flatMap { $0 }
                    .collect()
                    .flatMap { _ -> AnyPublisher<Bool, GraphQLError> in
                        // ===== MEMORY UPLOAD =====
                        let memoryService = GraphQLMemoryService()

                        // 1. Server-Memories holen IDs
                        return ApolloClientManager.shared.fetch(query: GetMemoriesQuery.self, cachePolicy: .networkOnly)
                            .map { $0.memories.map { $0.id } }
                            .flatMap { serverMemoryIds -> AnyPublisher<Bool, GraphQLError> in
                                var newMemories: [Memory] = []
                                self.context.performAndWait {
                                    let req: NSFetchRequest<Memory> = Memory.fetchRequest()
                                    if let locals = try? self.context.fetch(req) {
                                        newMemories.append(contentsOf: locals)
                                    }
                                }

                                guard !newMemories.isEmpty else {
                                    return Just(true).setFailureType(to: GraphQLError.self).eraseToAnyPublisher()
                                }

                                let memPublishers = newMemories.compactMap { mem -> AnyPublisher<Bool, GraphQLError>? in
                                    guard let dto = MemoryDTO.from(coreData: mem) else { return nil }
                                    return memoryService.createMemory(input: dto)
                                        .map { _ in true }
                                        .eraseToAnyPublisher()
                                }

                                return memPublishers.publisher
                                    .flatMap { $0 }
                                    .collect()
                                    .map { _ in true }
                                    .eraseToAnyPublisher()
                            }
                            .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Nur Download durchführen (Server-Änderungen zu lokal)
    /// - Returns: Publisher mit Bool (Erfolg)
    func downloadChanges() -> AnyPublisher<Bool, GraphQLError> {
        if isDemoMode {
            return simulateDownload()
        }

        DispatchQueue.main.async {
            self.isSyncing = true
            self.syncProgress = 0.0
            self.syncError = nil
        }

        // Trips abrufen
        return ApolloClientManager.shared.fetch(query: GetTripsQuery.self, cachePolicy: .networkOnly)
            .tryMap { [weak self] tripsData -> Bool in
                guard let self = self else { throw GraphQLError.unknown("Service deinitiert") }

                self.syncProgress = 0.3

                // Trips verarbeiten und lokale Löschungen feststellen
                let remoteTripIds = Set(tripsData.trips.map { $0.id })
                self.context.performAndWait {
                    print("🔄 Starte Trip-Import – empfangene Trips: \(tripsData.trips.count)")
                    if let cu = AuthManager.shared.currentUser {
                        print("👤 currentUser.backendId = \(cu.backendUserId ?? "nil")  email = \(cu.email ?? "nil")")
                    } else {
                        print("⚠️ currentUser ist NIL während Trip-Import")
                    }
                    for trip in tripsData.trips {
                        print("➡️ Verarbeite Trip #\(trip.id) – \(trip.name)")
                        var tripDict: [String: Any] = [
                            "id": trip.id,
                            "name": trip.name,
                            "isActive": trip.isActive,
                            "totalDistance": trip.totalDistance,
                            "gpsTrackingEnabled": trip.gpsTrackingEnabled,
                            "tripDescription": trip.tripDescription as Any,
                            "coverImageObjectName": trip.coverImageObjectName as Any,
                            "coverImageUrl": trip.coverImageUrl as Any,
                            "travelCompanions": trip.travelCompanions as Any,
                            "visitedCountries": trip.visitedCountries as Any,
                            "startDate": trip.startDate as Any,
                            "endDate": trip.endDate as Any,
                            "createdAt": trip.createdAt,
                            "updatedAt": trip.updatedAt
                        ]

                        if let dto = TripDTO.from(graphQL: tripDict) {
                            let tripCD = dto.toCoreData(context: self.context)
                            print("📝 Trip \(tripCD.name ?? "?") (id: \(tripCD.id?.uuidString ?? "nil")) in Core Data aktualisiert/erstellt")
                            // Owner und Membership setzen
                            if let currentUser = AuthManager.shared.currentUser {
                                // Owner setzen, falls noch nicht vorhanden
                                if tripCD.owner == nil {
                                    tripCD.owner = currentUser
                                }

                                // Prüfen, ob bereits ein Membership-Eintrag existiert
                                let membershipRequest: NSFetchRequest<TripMembership> = TripMembership.fetchRequest()
                                if let backendId = currentUser.backendUserId {
                                    membershipRequest.predicate = NSPredicate(format: "trip == %@ AND user.backendUserId == %@", tripCD, backendId)
                                } else {
                                    membershipRequest.predicate = NSPredicate(format: "trip == %@ AND user == %@", tripCD, currentUser)
                                }

                                if (try? self.context.fetch(membershipRequest).first) == nil {
                                    _ = TripMembership(
                                        context: self.context,
                                        trip: tripCD,
                                        user: currentUser,
                                        permission: .admin,
                                        invitedBy: nil,
                                        invitedAt: nil,
                                        joinedAt: Date(),
                                        status: .accepted
                                    )
                                    print("✅ Membership für Trip \(trip.id) und User \(currentUser.email ?? currentUser.backendUserId ?? "?") angelegt")
                                } else {
                                    print("ℹ️ Membership für Trip \(trip.id) existiert bereits")
                                }
                            }
                        }
                    }

                    // MARK: – Entferne lokale Trips, die auf dem Server nicht mehr vorhanden sind
                    let allTripsRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
                    if let localTrips = try? self.context.fetch(allTripsRequest) {
                        for localTrip in localTrips {
                            guard let localId = localTrip.id?.uuidString else { continue }
                            if !remoteTripIds.contains(localId) {
                                print("🗑️ Lösche lokalen Trip, da er auf dem Server fehlt: \(localTrip.name ?? "?") (id: \(localId))")
                                self.context.delete(localTrip)
                            }
                        }
                    }

                    if self.context.hasChanges {
                        try? self.context.save()
                    }
                }

                // DEBUG: Core Data Status nach Import
                if let currentUser = AuthManager.shared.currentUser {
                    let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
                    let totalTrips = (try? self.context.count(for: tripRequest)) ?? -1

                    let orphanTripsRequest = NSFetchRequest<Trip>(entityName: "Trip")
                    orphanTripsRequest.predicate = NSPredicate(format: "owner == nil")
                    let orphanTrips = (try? self.context.count(for: orphanTripsRequest)) ?? -1

                    let membershipRequest: NSFetchRequest<TripMembership> = TripMembership.fetchRequest()
                    if let backendId = currentUser.backendUserId {
                        membershipRequest.predicate = NSPredicate(format: "user.backendUserId == %@", backendId)
                    } else {
                        membershipRequest.predicate = NSPredicate(format: "user == %@", currentUser)
                    }
                    let memberships = (try? self.context.count(for: membershipRequest)) ?? -1

                    print("🔍 Debug Sync: TotalTrips=\(totalTrips), OrphanTrips=\(orphanTrips), MembershipsForUser=\(memberships)")
                } else {
                    print("⚠️ Debug Sync: Kein currentUser gesetzt – Eigentümerzuordnung nicht möglich")
                }

                return true
            }
            .mapError { error -> GraphQLError in
                if let graphError = error as? GraphQLError {
                    return graphError
                }
                return GraphQLError.networkError(error.localizedDescription)
            }
            .flatMap { _ in
                // Memories abrufen
                ApolloClientManager.shared.fetch(query: MemoryListQuery.self, cachePolicy: .networkOnly)
            }
            .tryMap { [weak self] memoriesData -> Bool in
                guard let self = self else { throw GraphQLError.unknown("Service deinitiert") }

                self.syncProgress = 0.7

                self.context.performAndWait {
                    for memory in memoriesData.memories {
                        var memDict: [String: Any] = [
                            "id": memory.id,
                            "title": memory.title,
                            "content": memory.text as Any,
                            "tripId": memory.tripId,
                            "userId": AuthManager.shared.currentUser?.backendUserId ?? "unknown",
                            "latitude": memory.latitude as Any,
                            "longitude": memory.longitude as Any,
                            "address": memory.locationName as Any,
                            "createdAt": memory.timestamp,
                            "updatedAt": memory.timestamp,
                            "location": [
                                "latitude": memory.latitude as Any,
                                "longitude": memory.longitude as Any,
                                "name": memory.locationName as Any
                            ]
                        ]

                        if let dto = MemoryDTO.from(graphQL: memDict) {
                            _ = dto.toCoreData(context: self.context)
                        }
                    }
                    if self.context.hasChanges {
                        try? self.context.save()
                    }
                }

                return true
            }
            .map { _ -> Bool in
                // Datenmodelle aktualisieren
                self.tripService.getTrips()
                    .sink(receiveCompletion: { _ in }, receiveValue: { trips in
                        DispatchQueue.main.async {
                            self.tripService.trips = trips
                        }
                    })
                    .store(in: &self.cancellables)

                DispatchQueue.main.async {
                    self.isSyncing = false
                    self.syncProgress = 1.0
                    self.lastSyncDate = Date()
                }
                return true
            }
            .mapError { error -> GraphQLError in
                if let graphError = error as? GraphQLError {
                    return graphError
                }
                return GraphQLError.networkError(error.localizedDescription)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Conflict Resolution
    
    /// Konflikte auflösen
    /// - Parameter strategy: Auflösungsstrategie
    /// - Returns: Publisher mit Bool (Erfolg)
    func resolveConflicts(strategy: ConflictResolutionStrategy = .serverWins) -> AnyPublisher<Bool, GraphQLError> {
        
        if isDemoMode {
            return Just(true)
                .setFailureType(to: GraphQLError.self)
                .delay(for: .seconds(1), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    // MARK: - Background Sync
    
    /// Hintergrund-Synchronisation starten
    func startBackgroundSync() {
        guard !isSyncing else { return }
        
        Timer.publish(every: 300, on: .main, in: .common) // Alle 5 Minuten
            .autoconnect()
            .sink { [weak self] _ in
                self?.performQuietSync()
            }
            .store(in: &cancellables)
    }
    
    /// Stille Synchronisation (ohne UI Updates)
    private func performQuietSync() {
        guard !isSyncing else { return }
        
        uploadChanges()
            .sink(
                receiveCompletion: { _ in
                    // Fehler ignorieren bei stiller Sync
                },
                receiveValue: { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.lastSyncDate = Date()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Demo Mode Implementations
    
    private func performDemoSync() -> AnyPublisher<Bool, GraphQLError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown("Service nicht verfügbar")))
                return
            }
            
            DispatchQueue.main.async {
                self.isSyncing = true
                self.syncProgress = 0.0
                self.syncError = nil
            }
            
            // Simuliere Sync-Schritte
            self.simulateSyncSteps { success in
                DispatchQueue.main.async {
                    self.isSyncing = false
                    self.syncProgress = success ? 1.0 : 0.0
                    self.lastSyncDate = success ? Date() : nil
                    
                    if success {
                        promise(.success(true))
                    } else {
                        let error = GraphQLError.unknown("Sync-Demo fehlgeschlagen")
                        self.syncError = error
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func simulateSyncSteps(completion: @escaping (Bool) -> Void) {
        let steps = [
            "Verbindung prüfen...",
            "Trips hochladen...",
            "Memories synchronisieren...",
            "Media-Dateien abgleichen...",
            "Konflikte auflösen...",
            "Synchronisation abschließen..."
        ]
        
        var currentStep = 0
        
        func executeNextStep() {
            guard currentStep < steps.count else {
                completion(true)
                return
            }
            
            let progress = Double(currentStep) / Double(steps.count)
            
            DispatchQueue.main.async {
                self.syncProgress = progress
            }
            
            // Simuliere Verarbeitungszeit
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                currentStep += 1
                executeNextStep()
            }
        }
        
        executeNextStep()
    }
    
    private func simulateUpload() -> AnyPublisher<Bool, GraphQLError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown("Service nicht verfügbar")))
                return
            }
            
            DispatchQueue.main.async {
                self.isSyncing = true
                self.syncProgress = 0.0
            }
            
            // Simuliere Upload
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.isSyncing = false
                self.syncProgress = 1.0
                self.lastSyncDate = Date()
                promise(.success(true))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func simulateDownload() -> AnyPublisher<Bool, GraphQLError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown("Service nicht verfügbar")))
                return
            }
            
            DispatchQueue.main.async {
                self.isSyncing = true
                self.syncProgress = 0.0
            }
            
            // Simuliere Download
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.isSyncing = false
                self.syncProgress = 1.0
                self.lastSyncDate = Date()
                promise(.success(true))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Conflict Resolution Strategy

enum ConflictResolutionStrategy {
    case serverWins      // Server-Version gewinnt
    case clientWins      // Client-Version gewinnt
    case manual          // Manuelle Auflösung erforderlich
    case merge           // Automatisches Merging
}

// MARK: - Sync Status

struct SyncStatus {
    let isActive: Bool
    let progress: Double
    let currentStep: String?
    let lastSyncDate: Date?
    let error: GraphQLError?
    
    var isComplete: Bool {
        return !isActive && progress >= 1.0
    }
    
    var hasError: Bool {
        return error != nil
    }
}

// MARK: - Helper Response Types

// Kein separater Response-Typ mehr nötig – MemoryListQuery.Data wird verwendet

// MARK: - Helper GraphQL Query for Memories

fileprivate struct MemoryRaw: Codable {
    let id: String
    let title: String
    let text: String?
    let timestamp: String
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let tripId: String
}

fileprivate struct MemoryListQuery: GraphQLQuery {
    static let operationName = "GetMemories"
    static let document = """
    query GetMemories {
      memories {
        id
        title
        text
        timestamp
        latitude
        longitude
        locationName
        tripId
      }
    }
    """

    struct Data: Codable {
        let memories: [MemoryRaw]
    }
} 