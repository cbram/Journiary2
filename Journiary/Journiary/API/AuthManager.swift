//
//  AuthManager.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import Combine

/// Status der Authentifizierung
enum AuthStatus {
    case notAuthenticated
    case authenticating
    case authenticated
    case error(Error)
}

/// Manager für die Authentifizierung
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var authStatus: AuthStatus = .notAuthenticated
    @Published var currentUser: User?
    
    private let apiClient = APIClient.shared
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Beobachte Änderungen am Auth-Token
        settings.$authToken
            .sink { [weak self] token in
                if !token.isEmpty {
                    self?.authStatus = .authenticated
                } else {
                    self?.authStatus = .notAuthenticated
                    self?.currentUser = nil
                }
            }
            .store(in: &cancellables)
        
        // Prüfe, ob ein Token vorhanden ist
        if !settings.authToken.isEmpty {
            Task {
                await validateToken()
            }
        }
    }
    
    /// Meldet einen Benutzer an
    /// - Parameters:
    ///   - username: Der Benutzername
    ///   - password: Das Passwort
    func login(username: String, password: String) async throws {
        authStatus = .authenticating
        
        // Erstelle die Login-Mutation
        let loginMutation = """
        mutation {
          login(username: "\(username)", password: "\(password)") {
            token
            user {
              id
              username
              email
            }
          }
        }
        """
        
        // Führe die Login-Mutation aus
        let response: GraphQLResponse<LoginData> = try await apiClient.performRequest(query: loginMutation)
        
        // Prüfe, ob die Anmeldung erfolgreich war
        guard let loginData = response.data?.login else {
            if let errors = response.errors, !errors.isEmpty {
                throw NSError(domain: "AuthManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: errors[0].message])
            }
            throw NSError(domain: "AuthManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Anmeldung fehlgeschlagen"])
        }
        
        // Speichere das Token und den Benutzer
        settings.authToken = loginData.token
        currentUser = loginData.user
        authStatus = .authenticated
    }
    
    /// Registriert einen neuen Benutzer
    /// - Parameters:
    ///   - username: Der Benutzername
    ///   - email: Die E-Mail-Adresse
    ///   - password: Das Passwort
    func register(username: String, email: String, password: String) async throws {
        authStatus = .authenticating
        
        // Erstelle die Register-Mutation
        let registerMutation = """
        mutation {
          register(username: "\(username)", email: "\(email)", password: "\(password)") {
            id
            username
            email
          }
        }
        """
        
        // Führe die Register-Mutation aus
        let response: GraphQLResponse<RegisterData> = try await apiClient.performRequest(query: registerMutation)
        
        // Prüfe, ob die Registrierung erfolgreich war
        guard let registerData = response.data?.register else {
            if let errors = response.errors, !errors.isEmpty {
                throw NSError(domain: "AuthManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: errors[0].message])
            }
            throw NSError(domain: "AuthManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Registrierung fehlgeschlagen"])
        }
        
        // Registrierung war erfolgreich, aber wir sind noch nicht angemeldet
        authStatus = .notAuthenticated
    }
    
    /// Meldet den Benutzer ab
    func logout() {
        settings.authToken = ""
        currentUser = nil
        authStatus = .notAuthenticated
    }
    
    /// Validiert das aktuelle Token
    func validateToken() async {
        guard !settings.authToken.isEmpty else {
            authStatus = .notAuthenticated
            return
        }
        
        // Erstelle die Me-Query
        let meQuery = """
        query {
          me {
            id
            username
            email
          }
        }
        """
        
        do {
            // Führe die Me-Query aus
            let response: GraphQLResponse<MeData> = try await apiClient.performRequest(query: meQuery)
            
            // Prüfe, ob die Query erfolgreich war
            guard let userData = response.data?.me else {
                settings.authToken = ""
                currentUser = nil
                authStatus = .notAuthenticated
                return
            }
            
            // Token ist gültig
            currentUser = userData
            authStatus = .authenticated
        } catch {
            // Token ist ungültig
            settings.authToken = ""
            currentUser = nil
            authStatus = .error(error)
        }
    }
}

// MARK: - Response Models

struct LoginData: Decodable {
    let login: LoginResponse
}

struct LoginResponse: Decodable {
    let token: String
    let user: User
}

struct RegisterData: Decodable {
    let register: User
}

struct MeData: Decodable {
    let me: User
}

struct User: Decodable, Identifiable {
    let id: String
    let username: String
    let email: String
} 