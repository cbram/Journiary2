//
//  GraphQLTripService.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine
import CoreData

/// GraphQL Trip Service - Demo Mode Implementation
/// Vereinfachte Version die ohne komplexe Apollo Code-Generation funktioniert
class GraphQLTripService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var trips: [TripDTO] = []
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let context = PersistenceController.shared.container.viewContext
    
    // MARK: - Demo Mode
    
    private var isDemoMode: Bool {
        return AppSettings.shared.backendURL.contains("localhost") ||
               AppSettings.shared.backendURL.contains("127.0.0.1")
    }
    
    // MARK: - CRUD Operations
    
    /// Alle Trips abrufen
    /// - Returns: Publisher mit [TripDTO]
    func getTrips() -> AnyPublisher<[TripDTO], GraphQLError> {
        
        if isDemoMode {
            return loadTripsFromCoreData()
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    /// Einzelnen Trip abrufen
    /// - Parameter id: Trip ID
    /// - Returns: Publisher mit TripDTO
    func getTrip(id: String) -> AnyPublisher<TripDTO, GraphQLError> {
        
        if isDemoMode {
            return loadTripFromCoreData(id: id)
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    /// Trip erstellen
    /// - Parameters:
    ///   - name: Name
    ///   - description: Beschreibung (optional)
    ///   - startDate: Startdatum (optional)
    ///   - endDate: Enddatum (optional)
    /// - Returns: Publisher mit TripDTO
    func createTrip(
        name: String,
        description: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> AnyPublisher<TripDTO, GraphQLError> {
        
        if isDemoMode {
            return createTripInCoreData(
                name: name,
                description: description,
                startDate: startDate,
                endDate: endDate
            )
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    /// Trip aktualisieren
    /// - Parameters:
    ///   - id: Trip ID
    ///   - name: Name
    ///   - description: Beschreibung
    ///   - startDate: Startdatum
    ///   - endDate: Enddatum
    ///   - isActive: Aktiv Status
    /// - Returns: Publisher mit TripDTO
    func updateTrip(
        id: String,
        name: String? = nil,
        description: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isActive: Bool? = nil
    ) -> AnyPublisher<TripDTO, GraphQLError> {
        
        if isDemoMode {
            return updateTripInCoreData(
                id: id,
                name: name,
                description: description,
                startDate: startDate,
                endDate: endDate,
                isActive: isActive
            )
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    /// Trip löschen
    /// - Parameter id: Trip ID
    /// - Returns: Publisher mit Bool (Erfolg)
    func deleteTrip(id: String) -> AnyPublisher<Bool, GraphQLError> {
        
        if isDemoMode {
            return deleteTripFromCoreData(id: id)
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    /// Trip teilen
    /// - Parameters:
    ///   - tripId: Trip ID
    ///   - userEmail: E-Mail des zu teilenden Benutzers
    ///   - permission: Berechtigung
    /// - Returns: Publisher mit Bool (Erfolg)
    func shareTrip(
        tripId: String,
        userEmail: String,
        permission: String = "READ"
    ) -> AnyPublisher<Bool, GraphQLError> {
        
        if isDemoMode {
            return Just(true)
                .setFailureType(to: GraphQLError.self)
                .delay(for: .seconds(1), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    // MARK: - Demo Mode Core Data Operations
    
    private func loadTripsFromCoreData() -> AnyPublisher<[TripDTO], GraphQLError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown("Service nicht verfügbar")))
                return
            }
            
            let request: NSFetchRequest<Trip> = Trip.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)
            ]
            
            do {
                let trips = try self.context.fetch(request)
                let tripDTOs = trips.compactMap { TripDTO.from(coreData: $0) }
                promise(.success(tripDTOs))
            } catch {
                promise(.failure(.coreDataError(error)))
            }
        }
        .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    private func loadTripFromCoreData(id: String) -> AnyPublisher<TripDTO, GraphQLError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown("Service nicht verfügbar")))
                return
            }
            
            let request: NSFetchRequest<Trip> = Trip.fetchRequest()
            if let uuidID = UUID(uuidString: id) {
                request.predicate = NSPredicate(format: "id == %@", uuidID as CVarArg)
            } else {
                request.predicate = NSPredicate(format: "name == %@", id)
            }
            
            do {
                let trips = try self.context.fetch(request)
                if let trip = trips.first,
                   let tripDTO = TripDTO.from(coreData: trip) {
                    promise(.success(tripDTO))
                } else {
                    promise(.failure(.unknown("Trip nicht gefunden")))
                }
            } catch {
                promise(.failure(.coreDataError(error)))
            }
        }
        .delay(for: .seconds(0.2), scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    private func createTripInCoreData(
        name: String,
        description: String?,
        startDate: Date?,
        endDate: Date?
    ) -> AnyPublisher<TripDTO, GraphQLError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown("Service nicht verfügbar")))
                return
            }
            
            let trip = Trip(context: self.context)
            trip.id = UUID()
            trip.name = name
            trip.tripDescription = description
            trip.startDate = startDate
            trip.endDate = endDate
            trip.isActive = true
            
            do {
                try self.context.save()
                if let tripDTO = TripDTO.from(coreData: trip) {
                    promise(.success(tripDTO))
                } else {
                    promise(.failure(.unknown("Trip-Konvertierung fehlgeschlagen")))
                }
            } catch {
                promise(.failure(.coreDataError(error)))
            }
        }
        .delay(for: .seconds(0.5), scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    private func updateTripInCoreData(
        id: String,
        name: String?,
        description: String?,
        startDate: Date?,
        endDate: Date?,
        isActive: Bool?
    ) -> AnyPublisher<TripDTO, GraphQLError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown("Service nicht verfügbar")))
                return
            }
            
            let request: NSFetchRequest<Trip> = Trip.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)
            
            do {
                let trips = try self.context.fetch(request)
                if let trip = trips.first {
                    if let name = name { trip.name = name }
                    if let description = description { trip.tripDescription = description }
                    if let startDate = startDate { trip.startDate = startDate }
                    if let endDate = endDate { trip.endDate = endDate }
                    if let isActive = isActive { trip.isActive = isActive }
                    
                    try self.context.save()
                    
                    if let tripDTO = TripDTO.from(coreData: trip) {
                        promise(.success(tripDTO))
                    } else {
                        promise(.failure(.unknown("Trip-Konvertierung fehlgeschlagen")))
                    }
                } else {
                    promise(.failure(.unknown("Trip nicht gefunden")))
                }
            } catch {
                promise(.failure(.coreDataError(error)))
            }
        }
        .delay(for: .seconds(0.5), scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    private func deleteTripFromCoreData(id: String) -> AnyPublisher<Bool, GraphQLError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown("Service nicht verfügbar")))
                return
            }
            
            let request: NSFetchRequest<Trip> = Trip.fetchRequest()
            if let uuidID = UUID(uuidString: id) {
                request.predicate = NSPredicate(format: "id == %@", uuidID as CVarArg)
            } else {
                request.predicate = NSPredicate(format: "name == %@", id)
            }
            
            do {
                let trips = try self.context.fetch(request)
                if let trip = trips.first {
                    self.context.delete(trip)
                    try self.context.save()
                    promise(.success(true))
                } else {
                    promise(.failure(.unknown("Trip nicht gefunden")))
                }
            } catch {
                promise(.failure(.coreDataError(error)))
            }
        }
        .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

// MARK: - Trip Membership DTO

struct TripMembershipDTO {
    let id: String
    let tripId: String
    let userId: String
    let role: String
    let user: UserDTO?
    let createdAt: Date?
    
    static func from(graphQL membershipData: Any) -> TripMembershipDTO? {
        guard let dict = membershipData as? [String: Any],
              let id = dict["id"] as? String,
              let tripId = dict["tripId"] as? String,
              let userId = dict["userId"] as? String,
              let role = dict["role"] as? String else {
            return nil
        }
        
        var user: UserDTO?
        if let userData = dict["user"] as? [String: Any] {
            user = UserDTO.from(graphQL: userData)
        }
        
        var createdAt: Date?
        if let createdAtString = dict["createdAt"] as? String {
            createdAt = ISO8601DateFormatter().date(from: createdAtString)
        }
        
        return TripMembershipDTO(
            id: id,
            tripId: tripId,
            userId: userId,
            role: role,
            user: user,
            createdAt: createdAt
        )
    }
} 