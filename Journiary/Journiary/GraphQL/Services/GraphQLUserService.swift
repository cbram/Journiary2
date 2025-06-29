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
    
    // MARK: - Demo Mode
    
    private var isDemoMode: Bool {
        // Demo Mode nur wenn Backend-Storage deaktiviert oder explizit localhost
        return !AppSettings.shared.shouldUseBackend ||
               AppSettings.shared.backendURL.contains("localhost") ||
               AppSettings.shared.backendURL.contains("127.0.0.1") ||
               AppSettings.shared.backendURL.lowercased().contains("demo")
    }
    
    // MARK: - Authentication
    
    /// Benutzer einloggen
    /// - Parameters:
    ///   - username: Benutzername
    ///   - password: Passwort
    /// - Returns: Publisher mit UserDTO
    func login(username: String, password: String) -> AnyPublisher<UserDTO, GraphQLError> {
        
        if isDemoMode {
            return createDemoUser(username: username)
                .delay(for: .seconds(1), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        
        // Echte GraphQL Login Mutation (korrigiert für Backend-Schema)
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
                      let user = login["user"] as? [String: Any],
                      let id = user["id"] as? String,
                      let email = user["email"] as? String else {
                    throw GraphQLError.invalidInput("Ungültige Login-Antwort")
                }
                
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
        
        if isDemoMode {
            return createDemoUser(
                username: username,
                email: email,
                firstName: firstName,
                lastName: lastName
            )
            .delay(for: .seconds(1), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    /// Aktuellen Benutzer abrufen
    /// - Returns: Publisher mit UserDTO
    func getCurrentUser() -> AnyPublisher<UserDTO, GraphQLError> {
        
        if isDemoMode {
            // Versuche lokalen User zu finden
            let request: NSFetchRequest<User> = User.fetchRequest()
            request.predicate = NSPredicate(format: "isCurrentUser == %@", NSNumber(value: true))
            
            do {
                let users = try context.fetch(request)
                if let user = users.first,
                   let userDTO = UserDTO(from: user) {
                    return Just(userDTO)
                        .setFailureType(to: GraphQLError.self)
                        .eraseToAnyPublisher()
                }
            } catch {
                // Ignoriere Fehler, erstelle Demo-User
            }
            
            return createDemoUser(username: "demo")
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
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
        
        if isDemoMode {
            return Future { [weak self] promise in
                guard let self = self else {
                    promise(.failure(.unknown("Service nicht verfügbar")))
                    return
                }
                
                // Aktualisiere lokalen User
                let request: NSFetchRequest<User> = User.fetchRequest()
                request.predicate = NSPredicate(format: "isCurrentUser == %@", NSNumber(value: true))
                
                do {
                    let users = try self.context.fetch(request)
                    if let user = users.first {
                        user.firstName = firstName
                        user.lastName = lastName
                        user.email = email ?? user.email
                        user.updatedAt = Date()
                        
                        try self.context.save()
                        
                        if let userDTO = UserDTO(from: user) {
                            promise(.success(userDTO))
                        } else {
                            promise(.failure(.unknown("User-Konvertierung fehlgeschlagen")))
                        }
                    } else {
                        promise(.failure(.unknown("Kein aktueller User gefunden")))
                    }
                } catch {
                    promise(.failure(.cacheError(error.localizedDescription)))
                }
            }
            .delay(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    /// JWT Token aktualisieren
    /// - Parameter refreshToken: Refresh Token
    /// - Returns: Publisher mit neuen Tokens
    func refreshToken(refreshToken: String) -> AnyPublisher<(accessToken: String, refreshToken: String), GraphQLError> {
        
        if isDemoMode {
            let newAccessToken = "demo_access_token_\(UUID().uuidString)"
            let newRefreshToken = "demo_refresh_token_\(UUID().uuidString)"
            
            return Just((accessToken: newAccessToken, refreshToken: newRefreshToken))
                .setFailureType(to: GraphQLError.self)
                .delay(for: .seconds(0.5), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    /// Hello World Test (verwendet Apollo Client Cache)
    /// - Returns: Publisher mit String
    func hello() -> AnyPublisher<String, GraphQLError> {
        
        if isDemoMode {
            return Just("Hallo aus der Demo! 🚀")
                .setFailureType(to: GraphQLError.self)
                .delay(for: .seconds(0.5), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        
        // 🚀 Verwendet Apollo Client mit Cache für bessere Performance
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
    
    // MARK: - Demo Mode Implementations
    
    private func createDemoUser(
        username: String,
        email: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil
    ) -> AnyPublisher<UserDTO, GraphQLError> {
        
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown("Service nicht verfügbar")))
                return
            }
            
            // Erstelle oder aktualisiere Demo-User in Core Data
            let request: NSFetchRequest<User> = User.fetchRequest()
            request.predicate = NSPredicate(format: "username == %@", username)
            
            do {
                let existingUsers = try self.context.fetch(request)
                let user: User
                
                if let existingUser = existingUsers.first {
                    user = existingUser
                } else {
                    user = User(context: self.context)
                    user.id = UUID()
                    user.username = username
                    user.email = email ?? "\(username)@demo.com"
                    user.firstName = firstName
                    user.lastName = lastName
                    user.createdAt = Date()
                }
                
                user.updatedAt = Date()
                user.isCurrentUser = true // Setze als aktueller User
                
                // Alle anderen User als nicht-aktuell markieren
                let allUsersRequest: NSFetchRequest<User> = User.fetchRequest()
                let allUsers = try self.context.fetch(allUsersRequest)
                for otherUser in allUsers where otherUser != user {
                    otherUser.isCurrentUser = false
                }
                
                try self.context.save()
                
                if let userDTO = UserDTO(from: user) {
                    promise(.success(userDTO))
                } else {
                    promise(.failure(.unknown("User-Konvertierung fehlgeschlagen")))
                }
                
            } catch {
                promise(.failure(.cacheError(error.localizedDescription)))
            }
        }
        .eraseToAnyPublisher()
    }
} 