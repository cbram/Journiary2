//
//  UserService.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine
import CoreData

class UserService: ObservableObject {
    
    // MARK: - Properties
    
    private let session = URLSession.shared
    private var baseURL: String {
        return AppSettings.shared.backendURL
    }
    
    // MARK: - Demo Mode (für Development/Testing)
    
    // Cache für bessere Performance
    private static var _isDemoModeCache: Bool?
    
    private var isDemoMode: Bool {
        #if DEBUG
        // Cache verwenden um wiederholte Prüfungen zu vermeiden
        if let cached = Self._isDemoModeCache {
            return cached
        }
        
        // Demo-Mode nur für localhost/127.0.0.1 (Production-Ready)
        let isLocalhost = baseURL.contains("localhost") || baseURL.contains("127.0.0.1")
        let isDemo = isLocalhost
        
        // Nur einmal loggen
        print("🔍 Demo-Mode Check: baseURL=\(baseURL), isLocalhost=\(isLocalhost), isDemoMode=\(isDemo)")
        
        Self._isDemoModeCache = isDemo
        return isDemo
        #else
        return false
        #endif
    }
    
    // MARK: - Login
    
    func login(email: String, password: String) -> AnyPublisher<LoginResponse, Error> {
        print("🔐 Backend-Login gestartet für: \(email)")
        
        // Demo Mode für Development
        if isDemoMode {
            print("🎭 Demo-Mode: Login simuliert für \(email)")
            return createDemoLoginResponse(email: email)
        }
        
        print("🌐 Echtes Backend-Login wird durchgeführt...")
        
        let mutation = """
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
                "email": email,
                "password": password
            ]
        ]
        
        print("📤 Sende Login-Mutation an Backend...")
        print("🔍 Login-Mutation: \(mutation)")
        print("🔍 Login-Variables: \(variables)")
        
        return performGraphQLRequest(query: mutation, variables: variables)
            .tryMap { data in
                print("📥 Login-Response erhalten: \(data.count) bytes")
                
                // Parse JSON Response
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("❌ Login-Response ist kein gültiges JSON")
                    throw UserServiceError.invalidResponse
                }
                
                print("🔍 Login-Response JSON: \(json)")
                
                // Check for GraphQL errors first
                if let errors = json["errors"] as? [[String: Any]] {
                    let errorMessages = errors.compactMap { $0["message"] as? String }
                    let errorMessage = errorMessages.joined(separator: ", ")
                    print("❌ GraphQL Login-Fehler: \(errorMessage)")
                    throw UserServiceError.graphqlError(errorMessage)
                }
                
                // Parse successful response
                guard let responseData = json["data"] as? [String: Any],
                      let loginData = responseData["login"] as? [String: Any] else {
                    print("❌ Login-Response hat keine 'data.login' Struktur")
                    print("🔍 Response Data: \(json["data"] ?? "nil")")
                    throw UserServiceError.invalidResponse
                }
                
                print("✅ Login-Daten erfolgreich empfangen")
                
                return try self.parseAuthResponse(loginData)
            }
            .handleEvents(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("✅ Login-Request erfolgreich abgeschlossen")
                    case .failure(let error):
                        print("❌ Login fehlgeschlagen: \(error)")
                        if let userServiceError = error as? UserServiceError {
                            print("🔍 UserServiceError Details: \(userServiceError.localizedDescription)")
                        }
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    // MARK: - Registration
    
    func register(email: String, username: String, password: String, firstName: String? = nil, lastName: String? = nil) -> AnyPublisher<LoginResponse, Error> {
        // Demo Mode für Development
        if isDemoMode {
            print("🎭 Demo-Mode: Registrierung simuliert für \(email)")
            return createDemoRegisterResponse(email: email, username: username, firstName: firstName, lastName: lastName)
        }
        let mutation = """
        mutation Register($input: UserInput!) {
            register(input: $input) {
                id
                email
                createdAt
                updatedAt
            }
        }
        """
        
        let userInput: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        let variables: [String: Any] = [
            "input": userInput
        ]
        
        return performGraphQLRequest(query: mutation, variables: variables)
            .tryMap { data in
                print("📥 Register-Response erhalten: \(data.count) bytes")
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("❌ Register-Response ist kein gültiges JSON")
                    throw UserServiceError.invalidResponse
                }
                
                print("🔍 Register-Response JSON: \(json)")
                
                // Check for GraphQL errors first
                if let errors = json["errors"] as? [[String: Any]] {
                    let errorMessages = errors.compactMap { $0["message"] as? String }
                    let errorMessage = errorMessages.joined(separator: ", ")
                    print("❌ GraphQL Register-Fehler: \(errorMessage)")
                    throw UserServiceError.graphqlError(errorMessage)
                }
                
                guard let responseData = json["data"] as? [String: Any],
                      let userData = responseData["register"] as? [String: Any] else {
                    print("❌ Register-Response hat keine 'data.register' Struktur")
                    throw UserServiceError.invalidResponse
                }
                
                print("✅ Register erfolgreich - User erstellt: \(userData)")
                return userData
            }
            .flatMap { userData in
                print("🔄 Starte automatischen Login nach erfolgreicher Registrierung...")
                return self.login(email: email, password: password)
                    .handleEvents(receiveOutput: { loginResponse in
                        print("✅ Automatischer Login nach Registrierung erfolgreich!")
                    })
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Get Current User
    
    func getCurrentUser() -> AnyPublisher<GraphQL.User, Error> {
        let query = """
        query GetCurrentUser {
            me {
                id
                email
                username
                firstName
                lastName
            }
        }
        """
        
        return performAuthenticatedGraphQLRequest(query: query, variables: nil)
            .tryMap { data in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let responseData = json["data"] as? [String: Any],
                      let userData = responseData["me"] as? [String: Any] else {
                    throw UserServiceError.invalidResponse
                }
                
                return try self.parseUserData(userData)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Update User
    
    func updateUser(firstName: String?, lastName: String?, email: String?) -> AnyPublisher<GraphQL.User, Error> {
        let mutation = """
        mutation UpdateUser($input: UpdateUserInput!) {
            updateUser(input: $input) {
                id
                email
                username
                firstName
                lastName
            }
        }
        """
        
        var updateInput: [String: Any] = [:]
        
        if let firstName = firstName {
            updateInput["firstName"] = firstName
        }
        
        if let lastName = lastName {
            updateInput["lastName"] = lastName
        }
        
        if let email = email {
            updateInput["email"] = email
        }
        
        let variables: [String: Any] = [
            "input": updateInput
        ]
        
        return performAuthenticatedGraphQLRequest(query: mutation, variables: variables)
            .tryMap { data in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let responseData = json["data"] as? [String: Any],
                      let userData = responseData["updateUser"] as? [String: Any] else {
                    throw UserServiceError.invalidResponse
                }
                
                return try self.parseUserData(userData)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Token Refresh
    
    func refreshToken(_ refreshToken: String) -> AnyPublisher<LoginResponse, Error> {
        let mutation = """
        mutation RefreshToken($refreshToken: String!) {
            refreshToken(refreshToken: $refreshToken) {
                token
                refreshToken
                user {
                    id
                    email
                    username
                    firstName
                    lastName
                }
            }
        }
        """
        
        let variables: [String: Any] = [
            "refreshToken": refreshToken
        ]
        
        return performGraphQLRequest(query: mutation, variables: variables)
            .tryMap { data in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let responseData = json["data"] as? [String: Any],
                      let refreshData = responseData["refreshToken"] as? [String: Any] else {
                    throw UserServiceError.invalidResponse
                }
                
                return try self.parseLoginResponse(refreshData)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    // MARK: - Backend-Schema Response Parsing
    
    /// Parse AuthResponse (für Login)
    private func parseAuthResponse(_ data: [String: Any]) throws -> LoginResponse {
        guard let token = data["token"] as? String,
              let userData = data["user"] as? [String: Any] else {
            print("❌ AuthResponse fehlt token oder user: \(data)")
            throw UserServiceError.invalidResponse
        }
        
        let user = try parseBackendUserData(userData)
        
        return LoginResponse(token: token, refreshToken: "", user: user)
    }
    
    /// Parse User Registration Response (für Register + Auto-Login)
    private func parseUserRegistrationResponse(_ userData: [String: Any], email: String, password: String) throws -> LoginResponse {
        print("🔄 User registriert - führe automatischen Login durch...")
        
        // Für das Backend machen wir automatisch einen Login nach der Registrierung
        // Da das Register nur User zurückgibt, aber die App ein Token braucht
        let user = try parseBackendUserData(userData)
        
        // Erstelle einen "fake" LoginResponse für die Demo
        // In der Produktion sollte das Backend direkt ein Token zurückgeben
        // oder wir machen einen echten Login-Call
        return LoginResponse(
            token: "registration-requires-login", // Marker für nachgelagerten Login
            refreshToken: "",
            user: user
        )
    }
    
    /// Parse Backend User Data (echtes Schema)
    private func parseBackendUserData(_ data: [String: Any]) throws -> GraphQL.User {
        guard let id = data["id"] as? String,
              let email = data["email"] as? String else {
            print("❌ Backend User fehlt id oder email: \(data)")
            throw UserServiceError.invalidResponse
        }
        
        // Backend hat nur email, generiere username aus email
        let username = email.components(separatedBy: "@").first ?? "user"
        
        return GraphQL.User(
            id: id,
            email: email,
            username: username,
            firstName: nil,
            lastName: nil,
            displayName: username,
            initials: String(username.prefix(2)).uppercased(),
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    // MARK: - Legacy Demo Methods (für Compatibility)
    
    private func parseLoginResponse(_ data: [String: Any]) throws -> LoginResponse {
        // Legacy method - sollte nicht mehr verwendet werden
        return try parseAuthResponse(data)
    }
    
    private func parseUserData(_ data: [String: Any]) throws -> GraphQL.User {
        // Legacy method - versuche zuerst neues Schema, dann altes
        if data["username"] != nil {
            // Altes Demo-Schema
            guard let id = data["id"] as? String,
                  let email = data["email"] as? String,
                  let username = data["username"] as? String else {
                throw UserServiceError.invalidResponse
            }
            
            let firstName = data["firstName"] as? String
            let lastName = data["lastName"] as? String
            
            let displayName = [firstName, lastName].compactMap { $0 }.joined(separator: " ").isEmpty ? username : [firstName, lastName].compactMap { $0 }.joined(separator: " ")
            let initials = [firstName, lastName].compactMap { $0?.prefix(1) }.joined().uppercased()
            
            return GraphQL.User(
                id: id,
                email: email,
                username: username,
                firstName: firstName,
                lastName: lastName,
                displayName: displayName,
                initials: initials.isEmpty ? String(username.prefix(2)).uppercased() : initials,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        } else {
            // Neues Backend-Schema
            return try parseBackendUserData(data)
        }
    }
    
    // MARK: - GraphQL Request Methods
    
    private func performGraphQLRequest(query: String, variables: [String: Any]?) -> AnyPublisher<Data, Error> {
        let fullURL = baseURL.hasSuffix("/graphql") ? baseURL : "\(baseURL)/graphql"
        print("🌐 GraphQL Request an: \(fullURL)")
        
        guard let url = URL(string: fullURL) else {
            print("❌ Ungültige Backend-URL: \(fullURL)")
            return Fail(error: UserServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0
        
        print("🔗 Request URL: \(url)")
        print("⏱️ Timeout: 30.0 Sekunden")
        
        var requestBody: [String: Any] = ["query": query]
        if let variables = variables {
            requestBody["variables"] = variables
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("📤 Request Body: \(requestBody)")
        } catch {
            print("❌ Fehler beim JSON-Kodieren: \(error)")
            return Fail(error: UserServiceError.encodingError)
                .eraseToAnyPublisher()
        }
        
        print("🚀 Sende HTTP-Request...")
        
        return session.dataTaskPublisher(for: request)
            .timeout(.seconds(30), scheduler: DispatchQueue.main)
            .tryMap { data, response in
                print("📥 HTTP-Response erhalten")
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Response ist keine HTTPURLResponse")
                    throw UserServiceError.invalidResponse
                }
                
                print("📊 HTTP Status Code: \(httpResponse.statusCode)")
                print("📋 Response Headers: \(httpResponse.allHeaderFields)")
                print("📦 Response Data: \(data.count) bytes")
                
                // Response Data als String für Debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Response Body: \(responseString)")
                }
                
                // GraphQL kann auch bei 200 Fehler enthalten
                if httpResponse.statusCode == 200 {
                    // Prüfe auf GraphQL-Errors
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errors = json["errors"] as? [[String: Any]] {
                        let errorMessage = errors.first?["message"] as? String ?? "Unbekannter GraphQL-Fehler"
                        throw UserServiceError.graphqlError(errorMessage)
                    }
                    return data
                }
                
                switch httpResponse.statusCode {
                case 401:
                    throw UserServiceError.unauthorized
                case 400...499:
                    throw UserServiceError.clientError(httpResponse.statusCode)
                case 500...599:
                    throw UserServiceError.serverError(httpResponse.statusCode)
                default:
                    throw UserServiceError.unknownError(httpResponse.statusCode)
                }
            }
            .mapError { error in
                print("❌ GraphQL Request Fehler: \(error)")
                
                if error is UserServiceError {
                    return error
                }
                
                // Network-Fehler behandeln
                if let urlError = error as? URLError {
                    print("🌐 URLError: \(urlError.localizedDescription) (Code: \(urlError.code.rawValue))")
                    switch urlError.code {
                    case .notConnectedToInternet:
                        print("🚫 Keine Internetverbindung")
                        return UserServiceError.noInternetConnection
                    case .timedOut:
                        print("⏰ Request-Timeout")
                        return UserServiceError.timeout
                    default:
                        print("🌐 Allgemeiner Netzwerk-Fehler")
                        return UserServiceError.networkError(urlError.localizedDescription)
                    }
                }
                
                print("❓ Unbekannter Fehler: \(error)")
                return UserServiceError.unknownError(0)
            }
            .eraseToAnyPublisher()
    }
    
    private func performAuthenticatedGraphQLRequest(query: String, variables: [String: Any]?) -> AnyPublisher<Data, Error> {
        guard let token = AuthManager.shared.getCurrentAuthToken() else {
            return Fail(error: UserServiceError.unauthorized)
                .eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "\(baseURL)/graphql") else {
            return Fail(error: UserServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        var requestBody: [String: Any] = ["query": query]
        if let variables = variables {
            requestBody["variables"] = variables
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: UserServiceError.encodingError)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .timeout(.seconds(30), scheduler: DispatchQueue.main)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw UserServiceError.invalidResponse
                }
                
                if httpResponse.statusCode == 200 {
                    // Prüfe auf GraphQL-Errors
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errors = json["errors"] as? [[String: Any]] {
                        let errorMessage = errors.first?["message"] as? String ?? "Unbekannter GraphQL-Fehler"
                        throw UserServiceError.graphqlError(errorMessage)
                    }
                    return data
                }
                
                switch httpResponse.statusCode {
                case 401:
                    throw UserServiceError.unauthorized
                case 400...499:
                    throw UserServiceError.clientError(httpResponse.statusCode)
                case 500...599:
                    throw UserServiceError.serverError(httpResponse.statusCode)
                default:
                    throw UserServiceError.unknownError(httpResponse.statusCode)
                }
            }
            .mapError { error in
                if error is UserServiceError {
                    return error
                }
                
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet:
                        return UserServiceError.noInternetConnection
                    case .timedOut:
                        return UserServiceError.timeout
                    default:
                        return UserServiceError.networkError(urlError.localizedDescription)
                    }
                }
                
                return UserServiceError.unknownError(0)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Demo Mode Helper Methods
    
    private func createDemoLoginResponse(email: String) -> AnyPublisher<LoginResponse, Error> {
        print("🎭 Demo-Mode: Anmeldung für \(email) simuliert")
        
        // WICHTIG: Prüfe ob Benutzer tatsächlich existiert
        let context = EnhancedPersistenceController.shared.container.viewContext
        
        guard let user = User.findUser(byEmail: email, context: context) else {
            print("❌ Demo-Mode: Benutzer \(email) nicht gefunden")
            return Fail(error: UserServiceError.unauthorized)
                .delay(for: .seconds(1), scheduler: DispatchQueue.main) // Simuliere Network-Delay
                .eraseToAnyPublisher()
        }
        
        // Lade echte Benutzerdaten
        let firstName = user.firstName?.isEmpty == false ? user.firstName : nil
        let lastName = user.lastName?.isEmpty == false ? user.lastName : nil
        let username = user.username ?? extractUsernameFromEmail(email)
        
        #if DEBUG
        print("🔍 Demo-Mode: Benutzer gefunden - \(firstName ?? "nil") \(lastName ?? "nil")")
        #endif
        
        let displayName = [firstName, lastName].compactMap { $0 }.joined(separator: " ").isEmpty ? username : [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        let initials = [firstName, lastName].compactMap { $0?.prefix(1) }.joined().uppercased()
        
        let demoUser = GraphQL.User(
            id: user.id?.uuidString ?? "demo-user-id",
            email: email,
            username: username,
            firstName: firstName,
            lastName: lastName,
            displayName: displayName,
            initials: initials.isEmpty ? String(username.prefix(2)).uppercased() : initials,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        let response = LoginResponse(
            token: createDemoJWTToken(),
            refreshToken: "demo-refresh-token",
            user: demoUser
        )
        
        // Simuliere Network-Delay
        return Just(response)
            .delay(for: .seconds(1), scheduler: DispatchQueue.main)
            .handleEvents(receiveOutput: { _ in
                print("✅ Demo-Mode: Anmeldung erfolgreich für registrierten Benutzer")
            })
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    private func createDemoRegisterResponse(email: String, username: String, firstName: String?, lastName: String?) -> AnyPublisher<LoginResponse, Error> {
        print("🎭 Demo-Mode: Registrierung für \(email) simuliert")
        
        let displayName = [firstName, lastName].compactMap { $0 }.joined(separator: " ").isEmpty ? username : [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        let initials = [firstName, lastName].compactMap { $0?.prefix(1) }.joined().uppercased()
        
        let demoUser = GraphQL.User(
            id: "demo-user-\(UUID().uuidString)",
            email: email,
            username: username,
            firstName: firstName,
            lastName: lastName,
            displayName: displayName,
            initials: initials.isEmpty ? String(username.prefix(2)).uppercased() : initials,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        let response = LoginResponse(
            token: createDemoJWTToken(),
            refreshToken: "demo-refresh-token",
            user: demoUser
        )
        
        // Simuliere Network-Delay
        return Just(response)
            .delay(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .handleEvents(receiveOutput: { _ in
                print("✅ Demo-Mode: Registrierung erfolgreich")
            })
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    private func createDemoJWTToken() -> String {
        // Erstelle einen simplen Demo-JWT Token (nicht für Production!)
        let header = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}"
        let payload = "{\"sub\":\"demo-user\",\"name\":\"Demo User\",\"iat\":\(Int(Date().timeIntervalSince1970)),\"exp\":\(Int(Date().timeIntervalSince1970) + 3600)}"
        
        let headerData = header.data(using: .utf8)?.base64EncodedString() ?? ""
        let payloadData = payload.data(using: .utf8)?.base64EncodedString() ?? ""
        
        return "\(headerData).\(payloadData).demo-signature"
    }
    
    private func extractUsernameFromEmail(_ email: String) -> String {
        let components = email.components(separatedBy: "@")
        return components.first ?? "demouser"
    }
    

}

// MARK: - User Service Errors

enum UserServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case encodingError
    case unauthorized
    case clientError(Int)
    case serverError(Int)
    case unknownError(Int)
    case noInternetConnection
    case timeout
    case networkError(String)
    case graphqlError(String)
    case registrationSuccess // Special case für automatischen Login nach Registration
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ungültige Server-URL"
        case .invalidResponse:
            return "Ungültige Server-Antwort"
        case .encodingError:
            return "Fehler beim Kodieren der Anfrage"
        case .unauthorized:
            return "Nicht autorisiert - Bitte melden Sie sich erneut an"
        case .clientError(let code):
            return "Client-Fehler (\(code))"
        case .serverError(let code):
            return "Server-Fehler (\(code))"
        case .unknownError(let code):
            return "Unbekannter Fehler (\(code))"
        case .noInternetConnection:
            return "Keine Internetverbindung"
        case .timeout:
            return "Zeitüberschreitung"
        case .networkError(let message):
            return "Netzwerkfehler: \(message)"
        case .graphqlError(let message):
            return message
        case .registrationSuccess:
            return "Registrierung erfolgreich"
        }
    }
} 