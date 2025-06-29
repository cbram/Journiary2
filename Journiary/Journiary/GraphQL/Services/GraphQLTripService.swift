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
    

    
    // MARK: - CRUD Operations
    
    /// Alle Trips abrufen
    /// - Returns: Publisher mit [TripDTO]
    func getTrips() -> AnyPublisher<[TripDTO], GraphQLError> {
        
        // GraphQL Backend Implementation
        let query = """
        query GetTrips {
            trips {
                id
                name
                isActive
            }
        }
        """
        
        return performGraphQLQuery(query: query)
            .tryMap { data -> [TripDTO] in
                            guard let trips = data["trips"] as? [[String: Any]] else {
                throw GraphQLError.parseError("Ungültige trips Antwort")
            }
                
                let dateFormatter = ISO8601DateFormatter()
                
                return trips.compactMap { tripData -> TripDTO? in
                    guard let id = tripData["id"] as? String,
                          let name = tripData["name"] as? String,
                          let isActive = tripData["isActive"] as? Bool else {
                        return nil
                    }
                    
                    return TripDTO(
                        id: id,
                        name: name,
                        description: nil, // Backend schema unknown
                        startDate: nil,   // Backend schema unknown
                        endDate: nil,     // Backend schema unknown
                        isActive: isActive,
                        createdAt: Date(), // Fallback
                        updatedAt: Date()  // Fallback
                    )
                }
            }
            .mapError { error -> GraphQLError in
                if let graphQLError = error as? GraphQLError {
                    return graphQLError
                } else {
                    return GraphQLError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Einzelnen Trip abrufen
    /// - Parameter id: Trip ID
    /// - Returns: Publisher mit TripDTO
    func getTrip(id: String) -> AnyPublisher<TripDTO, GraphQLError> {
        
        // GraphQL Backend Implementation
        let query = """
        query GetTrip($id: ID!) {
            trip(id: $id) {
                id
                name
                isActive
            }
        }
        """
        
        let variables = ["id": id]
        
        return performGraphQLQuery(query: query, variables: variables)
            .tryMap { data -> TripDTO in
                guard let trip = data["trip"] as? [String: Any],
                      let id = trip["id"] as? String,
                      let name = trip["name"] as? String,
                      let isActive = trip["isActive"] as? Bool else {
                    throw GraphQLError.parseError("Ungültige trip Antwort")
                }
                
                return TripDTO(
                    id: id,
                    name: name,
                    description: nil, // Backend schema unknown
                    startDate: nil,   // Backend schema unknown
                    endDate: nil,     // Backend schema unknown
                    isActive: isActive,
                    createdAt: Date(), // Fallback
                    updatedAt: Date()  // Fallback
                )
            }
            .mapError { error -> GraphQLError in
                if let graphQLError = error as? GraphQLError {
                    return graphQLError
                } else {
                    return GraphQLError.networkError(error.localizedDescription)
                }
            }
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
        
        // GraphQL Backend Implementation
        let mutation = """
        mutation CreateTrip($input: TripInput!) {
            createTrip(input: $input) {
                id
                name
                isActive
            }
        }
        """
        
        var variables: [String: Any] = [
            "input": [
                "name": name,
                "isActive": true
            ]
        ]
        
        // Backend-required Felder (startDate und endDate sind REQUIRED!)
        let actualStartDate = startDate ?? Date()
        let actualEndDate = endDate ?? Calendar.current.date(byAdding: .day, value: 7, to: actualStartDate) ?? Date()
        
        var inputDict: [String: Any] = [
            "name": name,
            "isActive": true,
            "startDate": ISO8601DateFormatter().string(from: actualStartDate),
            "endDate": ISO8601DateFormatter().string(from: actualEndDate)
        ]
        
        // Optionale Beschreibung hinzufügen (Backend erwartet tripDescription!)
        if let description = description {
            inputDict["tripDescription"] = description
        }
        
        variables["input"] = inputDict
        
        return performGraphQLMutation(query: mutation, variables: variables)
            .tryMap { data -> TripDTO in
                guard let createTrip = data["createTrip"] as? [String: Any],
                      let id = createTrip["id"] as? String,
                      let name = createTrip["name"] as? String,
                      let isActive = createTrip["isActive"] as? Bool else {
                    throw GraphQLError.parseError("Ungültige createTrip Antwort")
                }
                
                return TripDTO(
                    id: id,
                    name: name,
                    description: nil, // Backend schema unknown
                    startDate: nil,   // Backend schema unknown
                    endDate: nil,     // Backend schema unknown
                    isActive: isActive,
                    createdAt: Date(), // Fallback
                    updatedAt: Date()  // Fallback
                )
            }
            .mapError { error -> GraphQLError in
                if let graphQLError = error as? GraphQLError {
                    return graphQLError
                } else {
                    return GraphQLError.networkError(error.localizedDescription)
                }
            }
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
        
        // GraphQL Backend Implementation
        let mutation = """
        mutation UpdateTrip($id: ID!, $input: UpdateTripInput!) {
            updateTrip(id: $id, input: $input) {
                id
                name
                isActive
            }
        }
        """
        
        var inputDict: [String: Any] = [:]
        if let name = name { inputDict["name"] = name }
        if let description = description { inputDict["tripDescription"] = description }
        if let startDate = startDate { inputDict["startDate"] = ISO8601DateFormatter().string(from: startDate) }
        if let endDate = endDate { inputDict["endDate"] = ISO8601DateFormatter().string(from: endDate) }
        if let isActive = isActive { inputDict["isActive"] = isActive }
        
        let variables: [String: Any] = [
            "id": id,
            "input": inputDict
        ]
        
        return performGraphQLMutation(query: mutation, variables: variables)
            .tryMap { data -> TripDTO in
                guard let updateTrip = data["updateTrip"] as? [String: Any],
                      let id = updateTrip["id"] as? String,
                      let name = updateTrip["name"] as? String,
                      let isActive = updateTrip["isActive"] as? Bool else {
                    throw GraphQLError.parseError("Ungültige updateTrip Antwort")
                }
                
                return TripDTO(
                    id: id,
                    name: name,
                    description: nil, // Backend schema unknown
                    startDate: nil,   // Backend schema unknown
                    endDate: nil,     // Backend schema unknown
                    isActive: isActive,
                    createdAt: Date(), // Fallback
                    updatedAt: Date()  // Fallback
                )
            }
            .mapError { error -> GraphQLError in
                if let graphQLError = error as? GraphQLError {
                    return graphQLError
                } else {
                    return GraphQLError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Trip löschen
    /// - Parameter id: Trip ID
    /// - Returns: Publisher mit Bool (Erfolg)
    func deleteTrip(id: String) -> AnyPublisher<Bool, GraphQLError> {
        
        // GraphQL Backend Implementation
        let mutation = """
        mutation DeleteTrip($id: ID!) {
            deleteTrip(id: $id)
        }
        """
        
        let variables = ["id": id]
        
        return performGraphQLMutation(query: mutation, variables: variables)
            .tryMap { data -> Bool in
                guard let success = data["deleteTrip"] as? Bool else {
                    throw GraphQLError.parseError("Ungültige deleteTrip Antwort")
                }
                return success
            }
            .mapError { error -> GraphQLError in
                if let graphQLError = error as? GraphQLError {
                    return graphQLError
                } else {
                    return GraphQLError.networkError(error.localizedDescription)
                }
            }
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
        
        // Not implemented yet
        return Fail(error: GraphQLError.networkError("Feature nicht implementiert"))
            .eraseToAnyPublisher()
    }
    
    // MARK: - HTTP GraphQL Helper
    
    private func performGraphQLQuery(query: String, variables: [String: Any] = [:]) -> AnyPublisher<[String: Any], GraphQLError> {
        guard let url = URL(string: "\(AppSettings.shared.backendURL)/graphql") else {
            return Fail(error: GraphQLError.networkError("Ungültige Backend URL"))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // JWT Token hinzufügen falls vorhanden
        if let token = AuthManager.shared.getCurrentAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: GraphQLError.invalidInput("JSON Serialization fehlgeschlagen"))
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data -> [String: Any] in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw GraphQLError.invalidInput("Ungültige JSON Antwort")
                }
                
                // GraphQL Errors prüfen
                if let errors = json["errors"] as? [[String: Any]], !errors.isEmpty {
                    let errorMessage = errors.compactMap { $0["message"] as? String }.joined(separator: ", ")
                    throw GraphQLError.serverError(errorMessage)
                }
                
                guard let data = json["data"] as? [String: Any] else {
                    throw GraphQLError.invalidInput("Fehlende data in GraphQL Antwort")
                }
                
                return data
            }
            .mapError { error -> GraphQLError in
                if let graphQLError = error as? GraphQLError {
                    return graphQLError
                } else {
                    return GraphQLError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func performGraphQLMutation(query: String, variables: [String: Any] = [:]) -> AnyPublisher<[String: Any], GraphQLError> {
        // Mutations verwenden dieselbe HTTP-Methode wie Queries
        return performGraphQLQuery(query: query, variables: variables)
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