//
//  GraphQLAuthManager.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine
import SwiftUI
import CoreData

/// Erweiterte Authentication Manager mit GraphQL Integration
/// Demo Mode Implementation ohne komplexe Apollo Dependencies
extension AuthManager {
    
    // MARK: - GraphQL Services
    
    private var userService: GraphQLUserService {
        return GraphQLUserService()
    }
    
    // MARK: - GraphQL Login
    
    /// Login mit GraphQL Backend
    /// - Parameters:
    ///   - username: Benutzername
    ///   - password: Passwort
    /// - Returns: Publisher mit Bool (Erfolg)
    func loginWithGraphQL(username: String, password: String) -> AnyPublisher<Bool, GraphQLError> {
        return userService.login(username: username, password: password)
            .map { [weak self] userDTO in
                // GraphQL.User für AuthManager erstellen
                let displayName = [userDTO.firstName, userDTO.lastName].compactMap { $0 }.joined(separator: " ").isEmpty ? userDTO.username : [userDTO.firstName, userDTO.lastName].compactMap { $0 }.joined(separator: " ")
                let initials = [userDTO.firstName, userDTO.lastName].compactMap { $0?.prefix(1) }.joined().uppercased()
                
                let userData = GraphQL.User(
                    id: userDTO.id,
                    email: userDTO.email,
                    username: userDTO.username,
                    firstName: userDTO.firstName,
                    lastName: userDTO.lastName,
                    displayName: displayName,
                    initials: initials.isEmpty ? String(userDTO.username.prefix(2)).uppercased() : initials,
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )
                
                // Demo Login simulieren
                DispatchQueue.main.async {
                    self?.simulateSuccessfulLogin(userData: userData)
                }
                
                return true
            }
            .eraseToAnyPublisher()
    }
    
    /// Registrierung mit GraphQL Backend
    /// - Parameters:
    ///   - username: Benutzername
    ///   - email: E-Mail
    ///   - password: Passwort
    ///   - firstName: Vorname (optional)
    ///   - lastName: Nachname (optional)
    /// - Returns: Publisher mit Bool (Erfolg)
    func registerWithGraphQL(
        username: String,
        email: String,
        password: String,
        firstName: String? = nil,
        lastName: String? = nil
    ) -> AnyPublisher<Bool, GraphQLError> {
        return userService.register(
            username: username,
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName
        )
        .map { [weak self] userDTO in
            // GraphQL.User für AuthManager erstellen
            let displayName = [userDTO.firstName, userDTO.lastName].compactMap { $0 }.joined(separator: " ").isEmpty ? userDTO.username : [userDTO.firstName, userDTO.lastName].compactMap { $0 }.joined(separator: " ")
            let initials = [userDTO.firstName, userDTO.lastName].compactMap { $0?.prefix(1) }.joined().uppercased()
            
            let userData = GraphQL.User(
                id: userDTO.id,
                email: userDTO.email,
                username: userDTO.username,
                firstName: userDTO.firstName,
                lastName: userDTO.lastName,
                displayName: displayName,
                initials: initials.isEmpty ? String(userDTO.username.prefix(2)).uppercased() : initials,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            // Demo Registration simulieren
            DispatchQueue.main.async {
                self?.simulateSuccessfulLogin(userData: userData)
            }
            
            return true
        }
        .eraseToAnyPublisher()
    }
    
    /// Token Refresh mit GraphQL
    /// - Returns: Publisher mit Bool (Erfolg)
    func refreshTokenWithGraphQL() -> AnyPublisher<Bool, GraphQLError> {
        // In Demo Mode einfach erfolgreichen Refresh simulieren
        return Just(true)
            .setFailureType(to: GraphQLError.self)
            .eraseToAnyPublisher()
    }
    
    /// Profil aktualisieren mit GraphQL
    /// - Parameters:
    ///   - firstName: Neuer Vorname
    ///   - lastName: Neuer Nachname
    ///   - email: Neue E-Mail
    /// - Returns: Publisher mit UserDTO
    func updateProfileWithGraphQL(firstName: String?, lastName: String?, email: String?) -> AnyPublisher<UserDTO, GraphQLError> {
        return userService.updateUser(
            firstName: firstName,
            lastName: lastName,
            email: email
        )
        .handleEvents(receiveOutput: { [weak self] userDTO in
            // Core Data User direkt aktualisieren (für Demo Mode)
            DispatchQueue.main.async {
                if let currentUser = self?.currentUser {
                    currentUser.firstName = userDTO.firstName
                    currentUser.lastName = userDTO.lastName
                    currentUser.email = userDTO.email
                    currentUser.updatedAt = Date()
                    
                    let context = EnhancedPersistenceController.shared.container.viewContext
                    try? context.save()
                }
            }
        })
        .eraseToAnyPublisher()
    }
    
    /// Hello World Test mit GraphQL
    /// - Returns: Publisher mit String
    func helloWithGraphQL() -> AnyPublisher<String, GraphQLError> {
        return userService.hello()
    }
    
    // MARK: - Private Helper Methods
    
    /// Simuliere erfolgreichen Login für Demo Mode
    /// Arbeitet direkt mit Core Data ohne private AuthManager Methoden
    private func simulateSuccessfulLogin(userData: GraphQL.User) {
        let context = EnhancedPersistenceController.shared.container.viewContext
        
        // Prüfen ob Benutzer bereits existiert
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", userData.email)
        
        do {
            let existingUsers = try context.fetch(request)
            let user: User
            
            if let existingUser = existingUsers.first {
                user = existingUser
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
            
            // Als aktuellen User setzen
            self.currentUser = user
            
            try context.save()
            
            // Authentication Status setzen
            isAuthenticated = true
            authenticationError = nil
            
            #if DEBUG
            print("✅ GraphQL Demo Login erfolgreich: \(userData.username ?? userData.email)")
            #endif
            
        } catch {
            print("❌ Fehler beim Speichern des Demo-Users: \(error)")
            authenticationError = AuthError.networkError
        }
    }
}

// UserData ist bereits in AuthManager.swift definiert

// MARK: - SwiftUI Integration

/// SwiftUI View Modifier für GraphQL Authentication
struct GraphQLAuthModifier: ViewModifier {
    @EnvironmentObject private var authManager: AuthManager
    @State private var showingLogin = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Prüfe Authentication Status
                if !authManager.isAuthenticated {
                    showingLogin = true
                }
            }
            .sheet(isPresented: $showingLogin) {
                LoginView()
            }
    }
}

extension View {
    func requiresGraphQLAuth() -> some View {
        modifier(GraphQLAuthModifier())
    }
} 