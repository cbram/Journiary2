//
//  GraphQLUserService.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine
import CoreData

/// GraphQL User Service - Demo Mode Implementation
/// Vereinfachte Version die ohne komplexe Apollo Code-Generation funktioniert
class GraphQLUserService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var error: GraphQLError?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let context = PersistenceController.shared.container.viewContext
    

    
    // MARK: - Authentication
    
    /// Benutzer einloggen
    /// - Parameters:
    ///   - username: Benutzername
    ///   - password: Passwort
    /// - Returns: Publisher mit UserDTO
    func login(username: String, password: String) -> AnyPublisher<UserDTO, GraphQLError> {
        
        // GraphQL Backend Login
        let loginMutation = """
        mutation Login($input: UserInput!) {
            login(input: $input) {
                token
                user {
                    id
                    email
                    createdAt
                    updatedAt
                }
            }
        }
        """
        
        let variables: [String: Any] = [
            "input": [
                "email": username, // Backend verwendet email als Login
                "password": password
            ]
        ]
        
        return performGraphQLQuery(query: loginMutation, variables: variables)
            .tryMap { json -> UserDTO in
                guard let data = json["data"] as? [String: Any],
                      let login = data["login"] as? [String: Any],
                      let token = login["token"] as? String,
                      let user = login["user"] as? [String: Any],
                      let id = user["id"] as? String,
                      let email = user["email"] as? String else {
                    throw GraphQLError.invalidInput("Ungültige Login-Antwort")
                }
                
                // 🔐 KRITISCH: JWT Token vom Backend speichern!
                AuthManager.shared.setJWTToken(token)
                
                print("✅ JWT Token vom Backend erhalten und gespeichert: \(String(token.prefix(20)))...")
                
                // Backend User hat kein username - verwende email als username
                return UserDTO(
                    id: id,
                    username: email, // Email als Username verwenden
                    email: email,
                    firstName: nil, // Backend hat keine firstName/lastName
                    lastName: nil
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
    
    /// Benutzer registrieren
    /// - Parameters:
    ///   - username: Benutzername
    ///   - email: E-Mail
    ///   - password: Passwort
    ///   - firstName: Vorname (optional)
    ///   - lastName: Nachname (optional)
    /// - Returns: Publisher mit UserDTO
    func register(
        username: String,
        email: String,
        password: String,
        firstName: String? = nil,
        lastName: String? = nil
    ) -> AnyPublisher<UserDTO, GraphQLError> {
        
        // Registration not yet implemented in backend
        return Fail(error: GraphQLError.networkError("Registration noch nicht implementiert"))
            .eraseToAnyPublisher()
    }
    
    /// Aktuellen Benutzer abrufen
    /// - Returns: Publisher mit UserDTO
    func getCurrentUser() -> AnyPublisher<UserDTO, GraphQLError> {
        
        // Get current user not yet implemented
        return Fail(error: GraphQLError.networkError("GetCurrentUser noch nicht implementiert"))
            .eraseToAnyPublisher()
    }
    
    /// Benutzer-Profil aktualisieren
    /// - Parameters:
    ///   - firstName: Vorname
    ///   - lastName: Nachname
    ///   - email: E-Mail
    /// - Returns: Publisher mit UserDTO
    func updateUser(
        firstName: String?,
        lastName: String?,
        email: String?
    ) -> AnyPublisher<UserDTO, GraphQLError> {
        
        // User update not yet implemented
        return Fail(error: GraphQLError.networkError("User Update noch nicht implementiert"))
            .eraseToAnyPublisher()
    }
    
    /// JWT Token aktualisieren
    /// - Parameter refreshToken: Refresh Token
    /// - Returns: Publisher mit neuen Tokens
    func refreshToken(refreshToken: String) -> AnyPublisher<(accessToken: String, refreshToken: String), GraphQLError> {
        
        // Token refresh not yet implemented
        return Fail(error: GraphQLError.networkError("Token Refresh noch nicht implementiert"))
            .eraseToAnyPublisher()
    }
    
    /// Hello World Test (verwendet Apollo Client Cache)
    /// - Returns: Publisher mit String
    func hello() -> AnyPublisher<String, GraphQLError> {
        
        // Apollo Client Test
        return ApolloClientManager.shared.fetch(query: HelloQuery.self, cachePolicy: .cacheFirst)
            .map { response -> String in
                return response.hello
            }
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
                
                return json
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
} 