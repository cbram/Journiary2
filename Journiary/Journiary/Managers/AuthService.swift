//
//  AuthService.swift
//  Journiary
//
//  Created by Gemini on 08.06.25.
//

import Foundation
import Combine
import Apollo
import ApolloAPI
import KeychainSwift

@MainActor
class AuthService: ObservableObject {
    
    static let shared = AuthService()
    
    @Published var isAuthenticated: Bool = false
    @Published var user: JourniaryAPI.UserLoginMutation.Data.Login.User?
    
    private var keychain = KeychainSwift()
    private static let authTokenKey = "authToken"
    
    init() {
        checkAuthentication()
    }
    
    func getToken() -> String? {
        return keychain.get(Self.authTokenKey)
    }
    
    // MARK: - Public Methods
    
    /// Speichert einen Authentifizierungs-Token sicher im Keychain.
    /// - Parameter token: Der vom Server erhaltene Token.
    func saveToken(_ token: String) {
        keychain.set(token, forKey: Self.authTokenKey)
        self.isAuthenticated = true
        print("Token erfolgreich im Keychain gespeichert.")
    }
    
    /// Löscht den Authentifizierungs-Token aus dem Keychain.
    func deleteToken() {
        keychain.delete(Self.authTokenKey)
        self.isAuthenticated = false
        print("Token erfolgreich aus dem Keychain gelöscht und Benutzer abgemeldet.")
    }
    
    // MARK: - API Calls

    func register(user: JourniaryAPI.UserInput) async throws {
        // 1. Führe die Registrierungsmutation aus
        let registrationMutation = JourniaryAPI.UserRegistrationMutation(input: user)
        let _ = try await perform(mutation: registrationMutation)
        
        print("Registrierung erfolgreich. Versuche jetzt einzuloggen...")
        
        // 2. Führe nach erfolgreicher Registrierung die Login-Mutation aus
        let loginMutation = JourniaryAPI.UserLoginMutation(input: user)
        let result = try await perform(mutation: loginMutation)
        
        guard let token = result.data?.login.token else {
            throw URLError(.cannotParseResponse) // Besserer Fehler hier?
        }
        
        self.user = result.data?.login.user
        saveToken(token)
        print("Login nach Registrierung erfolgreich. Token gespeichert.")
    }
    
    func login(user: JourniaryAPI.UserInput) async throws {
        let loginMutation = JourniaryAPI.UserLoginMutation(input: user)
        let result = try await perform(mutation: loginMutation)
        
        guard let token = result.data?.login.token else {
            throw URLError(.cannotParseResponse)
        }
        
        self.user = result.data?.login.user
        saveToken(token)
        print("Login erfolgreich. Token gespeichert.")
    }

    func logout() {
        deleteToken() // Use the existing deleteToken function
        self.user = nil
        print("Benutzer abgemeldet.")
    }
    
    private func perform<M: GraphQLMutation>(mutation: M) async throws -> GraphQLResult<M.Data> {
        return try await withCheckedThrowingContinuation { continuation in
            NetworkProvider.shared.apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let data):
                    // Wir müssen prüfen, ob GraphQL-Fehler aufgetreten sind
                    if let errors = data.errors {
                        // Der Einfachheit halber werfen wir hier den ersten Fehler
                        // In einer echten App würden Sie dies wahrscheinlich anders handhaben
                        continuation.resume(throwing: errors.first ?? URLError(.badServerResponse))
                        return
                    }
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func checkAuthentication() {
        if getToken() != nil {
            self.isAuthenticated = true
            print("AuthService initialized. User is authenticated.")
        } else {
            self.isAuthenticated = false
            print("AuthService initialized. User is not authenticated.")
        }
    }
} 