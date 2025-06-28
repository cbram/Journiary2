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
    
    private var isDemoMode: Bool {
        #if DEBUG
        // Aktiviere Demo-Mode für Development
        // Entweder localhost oder wenn explizit in Debug-Mode
        let isLocalhost = baseURL.contains("localhost") || baseURL.contains("127.0.0.1")
        let isDevelopment = true // In Debug-Builds immer Demo-Mode aktivieren
        let isDemo = isLocalhost || isDevelopment
        print("🔍 Demo-Mode Check: baseURL=\(baseURL), isLocalhost=\(isLocalhost), isDevelopment=\(isDevelopment), isDemoMode=\(isDemo)")
        return isDemo
        #else
        return false
        #endif
    }
    
    // MARK: - Login
    
    func login(email: String, password: String) -> AnyPublisher<LoginResponse, Error> {
        // Demo Mode für Development
        if isDemoMode {
            print("🎭 Demo-Mode: Login simuliert für \(email)")
            return createDemoLoginResponse(email: email)
        }
        let mutation = """
        mutation Login($email: String!, $password: String!) {
            login(email: $email, password: $password) {
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
            "email": email,
            "password": password
        ]
        
        return performGraphQLRequest(query: mutation, variables: variables)
            .tryMap { data in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let responseData = json["data"] as? [String: Any],
                      let loginData = responseData["login"] as? [String: Any] else {
                    throw UserServiceError.invalidResponse
                }
                
                return try self.parseLoginResponse(loginData)
            }
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
        
        var userInput: [String: Any] = [
            "email": email,
            "username": username,
            "password": password
        ]
        
        if let firstName = firstName {
            userInput["firstName"] = firstName
        }
        
        if let lastName = lastName {
            userInput["lastName"] = lastName
        }
        
        let variables: [String: Any] = [
            "input": userInput
        ]
        
        return performGraphQLRequest(query: mutation, variables: variables)
            .tryMap { data in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let responseData = json["data"] as? [String: Any],
                      let registerData = responseData["register"] as? [String: Any] else {
                    throw UserServiceError.invalidResponse
                }
                
                return try self.parseLoginResponse(registerData)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Get Current User
    
    func getCurrentUser() -> AnyPublisher<UserData, Error> {
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
    
    func updateUser(firstName: String?, lastName: String?, email: String?) -> AnyPublisher<UserData, Error> {
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
    
    private func parseLoginResponse(_ data: [String: Any]) throws -> LoginResponse {
        guard let token = data["token"] as? String,
              let userData = data["user"] as? [String: Any] else {
            throw UserServiceError.invalidResponse
        }
        
        let refreshToken = data["refreshToken"] as? String
        let user = try parseUserData(userData)
        
        return LoginResponse(token: token, refreshToken: refreshToken, user: user)
    }
    
    private func parseUserData(_ data: [String: Any]) throws -> UserData {
        guard let id = data["id"] as? String,
              let email = data["email"] as? String,
              let username = data["username"] as? String else {
            throw UserServiceError.invalidResponse
        }
        
        let firstName = data["firstName"] as? String
        let lastName = data["lastName"] as? String
        
        return UserData(id: id, email: email, username: username, firstName: firstName, lastName: lastName)
    }
    
    // MARK: - GraphQL Request Methods
    
    private func performGraphQLRequest(query: String, variables: [String: Any]?) -> AnyPublisher<Data, Error> {
        guard let url = URL(string: "\(baseURL)/graphql") else {
            return Fail(error: UserServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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
                if error is UserServiceError {
                    return error
                }
                
                // Network-Fehler behandeln
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
        let context = PersistenceController.shared.container.viewContext
        
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
        
        print("🔍 Demo-Mode: Benutzer gefunden - \(firstName ?? "nil") \(lastName ?? "nil")")
        
        let demoUser = UserData(
            id: user.id?.uuidString ?? "demo-user-id",
            email: email,
            username: username,
            firstName: firstName,
            lastName: lastName
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
        
        let demoUser = UserData(
            id: "demo-user-\(UUID().uuidString)",
            email: email,
            username: username,
            firstName: firstName,
            lastName: lastName
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
        }
    }
} 