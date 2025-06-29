//
//  AuthManager.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine
import SwiftUI
import CoreData
import Security

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    // MARK: - Published Properties
    
    @Published var currentUser: User? {
        didSet {
            if currentUser != oldValue {
                objectWillChange.send()
            }
        }
    }
    
    @Published var isAuthenticated: Bool = false {
        didSet {
            if isAuthenticated != oldValue {
                objectWillChange.send()
            }
        }
    }
    
    @Published var isLoading: Bool = false
    @Published var authenticationError: AuthError?
    
    // MARK: - Private Properties
    
    private let keychainService = "com.journiary.auth"
    private let jwtTokenKey = "JWT_TOKEN"
    private let refreshTokenKey = "REFRESH_TOKEN"
    
    private var cancellables = Set<AnyCancellable>()
    private let userService = UserService()
    
    // MARK: - Initialization
    
    private init() {
        setupBindings()
        checkAuthenticationStatus()
    }
    
    private func setupBindings() {
        // Wenn currentUser sich ändert, authentication Status aktualisieren
        $currentUser
            .map { $0 != nil }
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Authentication Status
    
    var isAuthenticationRequired: Bool {
        let settings = AppSettings.shared
        return settings.shouldUseBackend && !isAuthenticated
    }
    
    private func checkAuthenticationStatus() {
        guard AppSettings.shared.shouldUseBackend else {
            isAuthenticated = false
            return
        }
        
        // Prüfen ob JWT Token vorhanden ist
        if let token = getJWTToken(), !token.isEmpty {
            // Token validieren
            validateToken(token)
        } else {
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    private func validateToken(_ token: String) {
        // Einfache Token-Validierung (Prüfung auf Ablauf)
        if isTokenExpired(token) {
            // Versuche Token zu erneuern
            refreshAuthenticationToken()
        } else {
            // Token ist gültig, lade Benutzerdaten
            loadCurrentUser()
        }
    }
    
    private func isTokenExpired(_ token: String) -> Bool {
        // JWT Token dekodieren und Ablaufzeit prüfen
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3,
              let data = Data(base64Encoded: parts[1]) else {
            return true
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let exp = json["exp"] as? TimeInterval {
                let expirationDate = Date(timeIntervalSince1970: exp)
                return expirationDate <= Date()
            }
        } catch {
            print("❌ Fehler beim Dekodieren des JWT Tokens: \(error)")
        }
        
        return true
    }
    
    // MARK: - Authentication Methods
    
    func login(email: String, password: String) {
        guard !isLoading else { return } // Verhindere mehrfache gleichzeitige Logins
        
        isLoading = true
        authenticationError = nil
        
        userService.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.authenticationError = AuthError.loginFailed(error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.handleSuccessfulLogin(response)
                }
            )
            .store(in: &cancellables)
    }
    
    func register(email: String, username: String, password: String, firstName: String? = nil, lastName: String? = nil) {
        guard !isLoading else { return } // Verhindere mehrfache gleichzeitige Registrierungen
        
        isLoading = true
        authenticationError = nil
        
        userService.register(email: email, username: username, password: password, firstName: firstName, lastName: lastName)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.authenticationError = AuthError.registrationFailed(error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] response in
                    self?.handleSuccessfulLogin(response)
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleSuccessfulLogin(_ response: LoginResponse) {
        // JWT Token speichern
        setJWTToken(response.token)
        if let refreshToken = response.refreshToken {
            setRefreshToken(refreshToken)
        }
        
        // Benutzerdaten in Core Data speichern/aktualisieren
        saveUserToCore(response.user)
        
        // Authentication Status aktualisieren
        isAuthenticated = true
        authenticationError = nil
        
        #if DEBUG
        print("✅ Benutzer erfolgreich angemeldet: \(response.user.username)")
        #endif
    }
    
    func logout() {
        // Token löschen
        deleteJWTToken()
        deleteRefreshToken()
        
        // Benutzer abmelden
        if let currentUser = currentUser {
            let context = PersistenceController.shared.container.viewContext
            currentUser.isCurrentUser = false
            
            do {
                try context.save()
            } catch {
                print("❌ Fehler beim Speichern nach Logout: \(error)")
            }
        }
        
        currentUser = nil
        isAuthenticated = false
        authenticationError = nil
        
        #if DEBUG
        print("✅ Benutzer abgemeldet")
        #endif
    }
    
    private func loadCurrentUser() {
        let context = PersistenceController.shared.container.viewContext
        currentUser = User.fetchCurrentUser(context: context)
        
        if currentUser == nil {
            // Lade Benutzerdaten vom Server
            userService.getCurrentUser()
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("❌ Fehler beim Laden des aktuellen Benutzers: \(error)")
                        }
                    },
                    receiveValue: { [weak self] user in
                        self?.saveUserToCore(user)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    private func saveUserToCore(_ userData: UserData) {
        let context = PersistenceController.shared.container.viewContext
        
        // Prüfen ob Benutzer bereits existiert
        let existingUser = User.findUser(byEmail: userData.email, context: context)
        
        let user: User
        if let existing = existingUser {
            user = existing
        } else {
            user = User(context: context)
            user.id = UUID()
            user.createdAt = Date()
        }
        
        // Benutzerdaten aktualisieren
        user.email = userData.email
        user.username = userData.username
        user.firstName = userData.firstName
        user.lastName = userData.lastName
        user.backendUserId = userData.id
        user.updatedAt = Date()
        
        // Als aktuellen Benutzer setzen
        User.setCurrentUser(user, context: context)
        
        currentUser = user
        
        do {
            try context.save()
        } catch {
            print("❌ Fehler beim Speichern des Benutzers: \(error)")
        }
    }
    
    // MARK: - Token Refresh
    
    private func refreshAuthenticationToken() {
        guard let refreshToken = getRefreshToken() else {
            logout()
            return
        }
        
        userService.refreshToken(refreshToken)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.logout()
                    }
                },
                receiveValue: { [weak self] response in
                    self?.setJWTToken(response.token)
                    if let newRefreshToken = response.refreshToken {
                        self?.setRefreshToken(newRefreshToken)
                    }
                    self?.loadCurrentUser()
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Keychain Management
    
    private func getJWTToken() -> String? {
        return getKeychainItem(key: jwtTokenKey)
    }
    
    private func setJWTToken(_ token: String) {
        setKeychainItem(key: jwtTokenKey, value: token)
    }
    
    private func deleteJWTToken() {
        deleteKeychainItem(key: jwtTokenKey)
    }
    
    private func getRefreshToken() -> String? {
        return getKeychainItem(key: refreshTokenKey)
    }
    
    private func setRefreshToken(_ token: String) {
        setKeychainItem(key: refreshTokenKey, value: token)
    }
    
    private func deleteRefreshToken() {
        deleteKeychainItem(key: refreshTokenKey)
    }
    
    private func getKeychainItem(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        
        return nil
    }
    
    private func setKeychainItem(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
    
    private func deleteKeychainItem(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Public Token Access
    
    func getCurrentAuthToken() -> String? {
        return getJWTToken()
    }
}

// MARK: - Supporting Types

enum AuthError: LocalizedError {
    case loginFailed(String)
    case registrationFailed(String)
    case tokenExpired
    case networkError
    case invalidCredentials
    
    var errorDescription: String? {
        switch self {
        case .loginFailed(let message):
            return "Anmeldung fehlgeschlagen: \(message)"
        case .registrationFailed(let message):
            return "Registrierung fehlgeschlagen: \(message)"
        case .tokenExpired:
            return "Sitzung abgelaufen. Bitte melden Sie sich erneut an."
        case .networkError:
            return "Netzwerkfehler. Bitte prüfen Sie Ihre Internetverbindung."
        case .invalidCredentials:
            return "Ungültige Anmeldedaten"
        }
    }
}

struct LoginResponse {
    let token: String
    let refreshToken: String?
    let user: UserData
}

struct UserData {
    let id: String
    let email: String
    let username: String
    let firstName: String?
    let lastName: String?
} 