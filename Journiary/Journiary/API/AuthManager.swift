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
        
        do {
            let loginResponse = try await apiClient.login(email: username, password: password)
            currentUser = loginResponse.user
            authStatus = .authenticated
        } catch {
            authStatus = .error(error)
            throw error
        }
    }
    
    /// Registriert einen neuen Benutzer
    /// - Parameters:
    ///   - username: Der Benutzername
    ///   - email: Die E-Mail-Adresse
    ///   - password: Das Passwort
    func register(username: String, email: String, password: String) async throws {
        authStatus = .authenticating
        
        do {
            // Wir nehmen an, dass die register-Funktion im APIClient angepasst wird,
            // um auch den username zu akzeptieren, oder wir verwenden hier die email.
            // Fürs Erste verwenden wir die E-Mail als Benutzernamen-Äquivalent,
            // falls die API das so erwartet. Die API-Spec wäre hier entscheidend.
            // Die `register` Funktion im APIClient erwartet nur email und passwort.
            // Wir müssen sie entweder erweitern oder hier eine Entscheidung treffen.
            // Annahme: Die `register` Funktion im APIClient sollte angepasst werden.
            // Da wir das hier nicht direkt tun können, rufen wir sie mit den verfügbaren Parametern auf.
            // Der Benutzername wird hier ignoriert.
            _ = try await apiClient.register(email: email, password: password)
            authStatus = .notAuthenticated // Nach der Registrierung muss man sich noch einloggen
        } catch {
            authStatus = .error(error)
            throw error
        }
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
        
        do {
            let user = try await apiClient.me()
            currentUser = user
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