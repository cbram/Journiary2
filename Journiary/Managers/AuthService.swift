//
//  AuthService.swift
//  Journiary
//
//  Created by Gemini on 08.06.25.
//

import Foundation
import Security
// import JourniaryAPI // Importiert die von Apollo generierten Typen -- DIES IST FALSCH

@MainActor
class AuthService: ObservableObject {

    // MARK: - Published Properties
    
    @Published private(set) var isAuthenticated: Bool = false
    
    // MARK: - Private Properties
    
    private let keychainService = "CHJB.Journiary"
    private let tokenKey = "authToken"
    
    // MARK: - Singleton
    
    static let shared = AuthService()
    
    private init() {
        // Check for token on startup
        if let _ = getToken() {
            isAuthenticated = true
        }
    }
    
    // MARK: - Public Methods
    
    func register(user: JourniaryAPI.UserInput, completion: @escaping (Bool, Error?) -> Void) {
        NetworkProvider.shared.apollo.perform(mutation: JourniaryAPI.UserRegistrationMutation(user: user)) { result in
            switch result {
            case .success(let graphQLResult):
                if let token = graphQLResult.data?.register.token {
                    self.saveToken(token)
                    self.isAuthenticated = true
                    completion(true, nil)
                } else {
                    // Handle potential GraphQL errors in the response
                    let error = graphQLResult.errors?.first
                    completion(false, error)
                }
            case .failure(let error):
                completion(false, error)
            }
        }
    }
    
    func login(user: JourniaryAPI.UserInput, completion: @escaping (Bool, Error?) -> Void) {
        NetworkProvider.shared.apollo.perform(mutation: JourniaryAPI.UserLoginMutation(user: user)) { result in
            switch result {
            case .success(let graphQLResult):
                if let token = graphQLResult.data?.login.token {
                    self.saveToken(token)
                    self.isAuthenticated = true
                    completion(true, nil)
                } else {
                    let error = graphQLResult.errors?.first
                    completion(false, error)
                }
            case .failure(let error):
                completion(false, error)
            }
        }
    }
    
    func logout() {
        deleteToken()
        isAuthenticated = false
        // Optional: Add any other cleanup logic here, e.g., clearing caches
    }
    
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        return nil
    }
    
    // MARK: - Private Helper Methods
    
    private func saveToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]
        
        // Delete any existing token before saving the new one
        SecItemDelete(query as CFDictionary)
        
        // Add the new token
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}