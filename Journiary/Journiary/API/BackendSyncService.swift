//
//  BackendSyncService.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import CoreData
import Combine

/// Status der Synchronisierung
enum SyncStatus {
    case idle
    case syncing
    case success(Date)
    case error(Error)
}

/// Fehlertypen, die bei der Synchronisierung auftreten können
enum SyncError: Error {
    case notAuthenticated
    case notEnabled
    case networkError(Error)
    case conflictDetected
    case coreDataError(Error)
    case backendError(Error)
    
    var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return "Nicht angemeldet. Bitte melde dich an, um zu synchronisieren."
        case .notEnabled:
            return "Synchronisierung ist deaktiviert."
        case .networkError(let error):
            return "Netzwerkfehler: \(error.localizedDescription)"
        case .conflictDetected:
            return "Konflikt erkannt. Bitte löse den Konflikt manuell."
        case .coreDataError(let error):
            return "Core Data Fehler: \(error.localizedDescription)"
        case .backendError(let error):
            return "Backend-Fehler: \(error.localizedDescription)"
        }
    }
}

/// Service für die Synchronisierung zwischen Core Data und dem Backend
class BackendSyncService: ObservableObject {
    static let shared = BackendSyncService()
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var isSyncing = false
    
    private let apiClient = APIClient.shared
    private let minioClient = MinIOClient.shared
    private let settings = AppSettings.shared
    private var persistenceController: PersistenceController?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Automatische Synchronisierung basierend auf den Einstellungen einrichten
        setupAutoSync()
    }
    
    /// Setzt den PersistenceController für die Synchronisierung
    /// - Parameter controller: Der PersistenceController
    func setPersistenceController(_ controller: PersistenceController) {
        self.persistenceController = controller
    }
    
    /// Richtet die automatische Synchronisierung ein
    private func setupAutoSync() {
        // Timer für automatische Synchronisierung
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkAndRunAutoSync()
            }
            .store(in: &cancellables)
    }
    
    /// Prüft, ob eine automatische Synchronisierung durchgeführt werden soll
    private func checkAndRunAutoSync() {
        guard settings.autoSync && settings.syncEnabled else { return }
        
        // Prüfe, ob das Synchronisierungsintervall abgelaufen ist
        let lastSync = settings.lastSyncDate
        let now = Date()
        let interval = settings.syncIntervalSeconds
        
        if now.timeIntervalSince(lastSync) >= interval {
            // Prüfe WLAN-Einstellung
            if settings.syncOnWifiOnly {
                // Hier würden wir prüfen, ob WLAN verbunden ist
                // Für jetzt nehmen wir einfach an, dass WLAN verbunden ist
                Task {
                    await synchronize()
                }
            } else {
                Task {
                    await synchronize()
                }
            }
        }
    }
    
    /// Führt eine vollständige Synchronisierung durch
    @MainActor
    func synchronize() async {
        guard let persistenceController = persistenceController else {
            syncStatus = .error(SyncError.coreDataError(NSError(domain: "BackendSyncService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "PersistenceController nicht gesetzt"])))
            return
        }
        
        guard settings.syncEnabled else {
            syncStatus = .error(SyncError.notEnabled)
            return
        }
        
        guard settings.storageMode != .cloudKit else {
            // Im CloudKit-Modus machen wir nichts
            return
        }
        
        guard AuthManager.shared.authStatus == .authenticated else {
            syncStatus = .error(SyncError.notAuthenticated)
            return
        }
        
        // Synchronisierung starten
        syncStatus = .syncing
        isSyncing = true
        
        do {
            // 1. Trips synchronisieren
            try await syncTrips(persistenceController: persistenceController)
            
            // 2. Memories synchronisieren
            try await syncMemories(persistenceController: persistenceController)
            
            // 3. MediaItems synchronisieren
            try await syncMediaItems(persistenceController: persistenceController)
            
            // 4. Tags synchronisieren
            try await syncTags(persistenceController: persistenceController)
            
            // Synchronisierung erfolgreich
            let now = Date()
            syncStatus = .success(now)
            lastSyncDate = now
            settings.lastSyncDate = now
            isSyncing = false
        } catch {
            syncStatus = .error(error)
            isSyncing = false
        }
    }
    
    // MARK: - Trip Synchronization
    
    /// Synchronisiert Trips zwischen Core Data und dem Backend
    /// - Parameter persistenceController: Der PersistenceController
    private func syncTrips(persistenceController: PersistenceController) async throws {
        // 1. Trips vom Backend abrufen
        let tripsResponse: GraphQLResponse<TripsData> = try await apiClient.performRequest(
            query: TripDTO.allTripsQuery
        )
        
        guard let backendTrips = tripsResponse.data?.trips else {
            throw SyncError.backendError(NSError(domain: "BackendSyncService", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Keine Trips vom Backend erhalten"]))
        }
        
        // 2. Trips aus Core Data abrufen
        let localTrips = try await fetchLocalTrips(persistenceController: persistenceController)
        
        // 3. Trips abgleichen und synchronisieren
        try await persistenceController.performBackgroundTask { context in
            // Hier würden wir die eigentliche Synchronisierungslogik implementieren
            // Für jeden Trip im Backend:
            // - Wenn er lokal existiert, aktualisieren
            // - Wenn er nicht lokal existiert, erstellen
            
            // Für jeden lokalen Trip:
            // - Wenn er im Backend existiert, wurde er bereits aktualisiert
            // - Wenn er nicht im Backend existiert, hochladen
            
            // Beispiel für das Erstellen eines neuen Trips aus dem Backend
            for backendTrip in backendTrips {
                if let existingTrip = try self.findLocalTrip(withId: backendTrip.id, in: context) {
                    // Trip existiert bereits, aktualisieren
                    backendTrip.updateCoreData(existingTrip, context: context)
                } else {
                    // Trip existiert nicht, erstellen
                    _ = backendTrip.createCoreDataObject(context: context)
                }
            }
            
            // Lokale Trips, die nicht im Backend existieren, hochladen
            for localTrip in localTrips {
                let localTripId = localTrip.id?.uuidString ?? ""
                if !backendTrips.contains(where: { $0.id == localTripId }) {
                    // Trip existiert nicht im Backend, hochladen
                    let tripDTO = TripDTO.fromCoreData(localTrip)
                    
                    // Hier würden wir den Trip zum Backend hochladen
                    // Für jetzt machen wir nichts
                }
            }
            
            // Änderungen speichern
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    /// Sucht einen Trip in Core Data anhand seiner ID
    /// - Parameters:
    ///   - id: Die ID des Trips
    ///   - context: Der NSManagedObjectContext
    /// - Returns: Der gefundene Trip oder nil
    private func findLocalTrip(withId id: String, in context: NSManagedObjectContext) throws -> Trip? {
        let fetchRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", UUID(uuidString: id)! as CVarArg)
        fetchRequest.fetchLimit = 1
        
        let trips = try context.fetch(fetchRequest)
        return trips.first
    }
    
    /// Ruft alle Trips aus Core Data ab
    /// - Parameter persistenceController: Der PersistenceController
    /// - Returns: Ein Array aller Trips
    private func fetchLocalTrips(persistenceController: PersistenceController) async throws -> [Trip] {
        return try await withCheckedThrowingContinuation { continuation in
            persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
                    let trips = try context.fetch(fetchRequest)
                    continuation.resume(returning: trips)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Memory Synchronization
    
    /// Synchronisiert Memories zwischen Core Data und dem Backend
    /// - Parameter persistenceController: Der PersistenceController
    private func syncMemories(persistenceController: PersistenceController) async throws {
        // Implementierung für Phase 2
        // Ähnlich wie syncTrips, aber für Memories
    }
    
    // MARK: - MediaItem Synchronization
    
    /// Synchronisiert MediaItems zwischen Core Data und dem Backend
    /// - Parameter persistenceController: Der PersistenceController
    private func syncMediaItems(persistenceController: PersistenceController) async throws {
        // 1. MediaItems vom Backend abrufen
        let mediaItemsResponse: GraphQLResponse<MediaItemsData> = try await apiClient.performRequest(
            query: MediaItemDTO.allMediaItemsQuery
        )
        
        guard let backendMediaItems = mediaItemsResponse.data?.mediaItems else {
            throw SyncError.backendError(NSError(domain: "BackendSyncService", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Keine MediaItems vom Backend erhalten"]))
        }
        
        // 2. MediaItems aus Core Data abrufen
        let localMediaItems = try await fetchLocalMediaItems(persistenceController: persistenceController)
        
        // 3. MediaItems abgleichen und synchronisieren
        try await persistenceController.performBackgroundTask { context in
            // MediaSyncManager für die Mediensynchronisierung
            let mediaSyncManager = MediaSyncManager.shared
            let mediaSyncCoordinator = MediaSyncCoordinator.shared
            
            // Für jedes MediaItem im Backend:
            for backendMediaItem in backendMediaItems {
                if let existingMediaItem = try self.findLocalMediaItem(withId: backendMediaItem.id, in: context) {
                    // MediaItem existiert bereits, aktualisieren
                    backendMediaItem.updateCoreData(existingMediaItem, context: context)
                    
                    // Wenn das MediaItem im Backend ein objectName hat, aber lokal keine Daten,
                    // dann müssen wir die Daten herunterladen, wenn autoDownloadMedia aktiviert ist
                    if let objectName = existingMediaItem.objectName, !objectName.isEmpty, existingMediaItem.mediaData == nil,
                       self.settings.autoDownloadMedia && existingMediaItem.memory != nil {
                        // Wir laden die Daten nicht direkt hier herunter, sondern überlassen das dem MediaSyncCoordinator
                        // Der MediaSyncCoordinator wird bei Bedarf die Daten herunterladen
                    }
                } else {
                    // MediaItem existiert nicht, erstellen
                    let newMediaItem = backendMediaItem.createCoreDataObject(context: context)
                    
                    // Wenn das MediaItem im Backend ein objectName hat, dann müssen wir die Daten herunterladen,
                    // wenn autoDownloadMedia aktiviert ist
                    if let objectName = newMediaItem.objectName, !objectName.isEmpty, newMediaItem.memory != nil,
                       self.settings.autoDownloadMedia {
                        // Wir laden die Daten nicht direkt hier herunter, sondern überlassen das dem MediaSyncCoordinator
                        // Der MediaSyncCoordinator wird bei Bedarf die Daten herunterladen
                    }
                }
            }
            
            // Lokale MediaItems, die nicht im Backend existieren, hochladen
            if self.settings.autoUploadMedia {
                for localMediaItem in localMediaItems {
                    let localMediaItemId = localMediaItem.id?.uuidString ?? ""
                    if !backendMediaItems.contains(where: { $0.id == localMediaItemId }) {
                        // MediaItem existiert nicht im Backend, hochladen
                        
                        // Zuerst prüfen, ob wir Mediendaten haben und ob das MediaItem zu einer Memory gehört
                        if let mediaData = localMediaItem.mediaData, localMediaItem.memory != nil {
                            // Wenn das MediaItem noch keinen objectName hat, müssen wir die Daten hochladen
                            if localMediaItem.objectName == nil || localMediaItem.objectName?.isEmpty == true {
                                // Wenn kein Dateiname vorhanden ist, generieren wir einen
                                if localMediaItem.filename == nil || localMediaItem.filename?.isEmpty == true {
                                    localMediaItem.filename = mediaSyncManager.generateUniqueFilename(for: localMediaItem)
                                }
                                
                                // Wir laden die Daten nicht direkt hier hoch, sondern überlassen das dem MediaSyncCoordinator
                                // Der MediaSyncCoordinator wird bei Bedarf die Daten hochladen
                                
                                // MediaItemDTO erstellen und zum Backend hochladen
                                let mediaItemDTO = MediaItemDTO.fromCoreData(localMediaItem)
                                
                                // Hier würden wir das MediaItem zum Backend hochladen
                                // Für jetzt machen wir nichts
                            } else {
                                // MediaItem hat bereits einen objectName, aber ist nicht im Backend
                                // Also müssen wir nur das DTO hochladen
                                let mediaItemDTO = MediaItemDTO.fromCoreData(localMediaItem)
                                
                                // Hier würden wir das MediaItem zum Backend hochladen
                                // Für jetzt machen wir nichts
                            }
                        }
                    }
                }
            }
            
            // Änderungen speichern
            if context.hasChanges {
                try context.save()
            }
        }
        
        // 4. Wenn autoSync aktiviert ist, starten wir die Mediensynchronisierung für alle Memories
        if settings.autoSync && (settings.autoUploadMedia || settings.autoDownloadMedia) {
            // Alle Memories abrufen
            let memories = try await fetchAllMemories(persistenceController: persistenceController)
            
            // MediaSyncCoordinator für die Mediensynchronisierung
            let mediaSyncCoordinator = MediaSyncCoordinator.shared
            
            // Für jede Memory die Mediendateien synchronisieren
            for memory in memories {
                // Wir verwenden try? hier, damit die Hauptsynchronisierung nicht fehlschlägt,
                // wenn die Mediensynchronisierung für eine Memory fehlschlägt
                try? await mediaSyncCoordinator.syncMediaForMemory(memory)
            }
        }
    }
    
    /// Sucht ein MediaItem in Core Data anhand seiner ID
    /// - Parameters:
    ///   - id: Die ID des MediaItems
    ///   - context: Der NSManagedObjectContext
    /// - Returns: Das gefundene MediaItem oder nil
    private func findLocalMediaItem(withId id: String, in context: NSManagedObjectContext) throws -> MediaItem? {
        let fetchRequest: NSFetchRequest<MediaItem> = MediaItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", UUID(uuidString: id)! as CVarArg)
        fetchRequest.fetchLimit = 1
        
        let mediaItems = try context.fetch(fetchRequest)
        return mediaItems.first
    }
    
    /// Ruft alle MediaItems aus Core Data ab
    /// - Parameter persistenceController: Der PersistenceController
    /// - Returns: Ein Array aller MediaItems
    private func fetchLocalMediaItems(persistenceController: PersistenceController) async throws -> [MediaItem] {
        return try await withCheckedThrowingContinuation { continuation in
            persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<MediaItem> = MediaItem.fetchRequest()
                    let mediaItems = try context.fetch(fetchRequest)
                    continuation.resume(returning: mediaItems)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Ruft alle Memories aus Core Data ab
    /// - Parameter persistenceController: Der PersistenceController
    /// - Returns: Ein Array aller Memories
    private func fetchAllMemories(persistenceController: PersistenceController) async throws -> [Memory] {
        return try await withCheckedThrowingContinuation { continuation in
            persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
                    let memories = try context.fetch(fetchRequest)
                    continuation.resume(returning: memories)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Tag Synchronization
    
    /// Synchronisiert Tags zwischen Core Data und dem Backend
    /// - Parameter persistenceController: Der PersistenceController
    private func syncTags(persistenceController: PersistenceController) async throws {
        // Implementierung für Phase 2
        // Ähnlich wie syncTrips, aber für Tags
    }
}

// MARK: - Response Models

struct TripsData: Decodable {
    let trips: [TripDTO]
}

struct MemoriesData: Decodable {
    let memoriesForTrip: [MemoryDTO]
}

struct TagsData: Decodable {
    let tags: [TagDTO]
}

struct MediaItemsData: Decodable {
    let mediaItems: [MediaItemDTO]
} 