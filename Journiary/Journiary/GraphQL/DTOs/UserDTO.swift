//
//  UserDTO.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import CoreData

/// User Data Transfer Object - Vereinfachte Version ohne Apollo
/// Für Datenübertragung zwischen Core Data und Demo GraphQL Service
struct UserDTO {
    let id: String
    let username: String
    let email: String
    let firstName: String?
    let lastName: String?
    let createdAt: Date
    let updatedAt: Date
    
    // MARK: - Direct Initializer
    
    /// Direkter Konstruktor für UserDTO
    init(id: String, username: String, email: String, firstName: String? = nil, lastName: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.username = username
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Computed Properties
    
    /// Anzeigename für UI
    var displayName: String {
        if let firstName = firstName, let lastName = lastName,
           !firstName.isEmpty, !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        } else if let firstName = firstName, !firstName.isEmpty {
            return firstName
        } else {
            return username
        }
    }
    
    /// Initialen für Avatar
    var initials: String {
        let name = displayName
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].first ?? "?") + String(words[1].first ?? "?")
        } else if !name.isEmpty {
            return String(name.prefix(2))
        } else {
            return "?"
        }
    }
    
    // MARK: - Core Data Integration
    
    /// Erstelle UserDTO aus Core Data User
    init?(from coreDataUser: User) {
        guard let id = coreDataUser.id?.uuidString,
              let username = coreDataUser.username else {
            return nil
        }
        
        self.id = id
        self.username = username
        self.email = coreDataUser.email ?? "\(username)@demo.com"
        self.firstName = coreDataUser.firstName
        self.lastName = coreDataUser.lastName
        self.createdAt = Date() // Core Data hat kein createdAt
        self.updatedAt = Date() // Core Data hat kein updatedAt
    }
    
    /// Speichere in Core Data (für Demo Mode)
    func toCoreData(context: NSManagedObjectContext) throws -> User {
        // Prüfe ob User bereits existiert
        let request: NSFetchRequest<User> = User.fetchRequest()
        if let uuidID = UUID(uuidString: id) {
            request.predicate = NSPredicate(format: "id == %@", uuidID as CVarArg)
        } else {
            request.predicate = NSPredicate(format: "username == %@", username)
        }
        
        let user: User
        if let existingUser = try? context.fetch(request).first {
            user = existingUser
        } else {
            user = User(context: context)
            user.id = UUID(uuidString: id) ?? UUID()
        }
        
        // Daten aktualisieren
        user.username = username
        user.email = email
        user.firstName = firstName
        user.lastName = lastName
        
        return user
    }
}

// MARK: - Response DTOs

/// Login Response DTO für Demo Mode
struct LoginResponseDTO {
    let token: String
    let user: UserDTO
    
    init(token: String, user: UserDTO) {
        self.token = token
        self.user = user
    }
}

/// Token Refresh Response DTO für Demo Mode
struct TokenRefreshResponseDTO {
    let token: String
    
    init(token: String) {
        self.token = token
    }
}

// MARK: - GraphQL Conversion

extension UserDTO {
    /// Erstellt UserDTO aus GraphQL Response
    /// - Parameter userData: GraphQL UserData
    /// - Returns: UserDTO
    static func from(graphQL userData: Any) -> UserDTO? {
        guard let dict = userData as? [String: Any],
              let id = dict["id"] as? String,
              let email = dict["email"] as? String,
              let username = dict["username"] as? String else {
            return nil
        }
        
        let firstName = dict["firstName"] as? String
        let lastName = dict["lastName"] as? String
        
        // Date Parsing
        var createdAt: Date?
        var updatedAt: Date?
        
        if let createdAtString = dict["createdAt"] as? String {
            createdAt = ISO8601DateFormatter().date(from: createdAtString)
        }
        
        if let updatedAtString = dict["updatedAt"] as? String {
            updatedAt = ISO8601DateFormatter().date(from: updatedAtString)
        }
        
        return UserDTO(
            id: id,
            username: username,
            email: email,
            firstName: firstName,
            lastName: lastName,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
    
    // MARK: - GraphQL Input
    
    /// Erstellt GraphQL UserInput Dictionary
    /// - Returns: Dictionary für GraphQL UserInput
    func toGraphQLInput() -> [String: Any] {
        var input: [String: Any] = [
            "email": email,
            "username": username
        ]
        
        if let firstName = firstName {
            input["firstName"] = firstName
        }
        
        if let lastName = lastName {
            input["lastName"] = lastName
        }
        
        return input
    }
    
    /// Erstellt GraphQL UpdateUserInput Dictionary
    /// - Returns: Dictionary für GraphQL UpdateUserInput
    func toGraphQLUpdateInput() -> [String: Any] {
        var input: [String: Any] = [:]
        
        input["email"] = email
        
        if let firstName = firstName {
            input["firstName"] = firstName
        }
        
        if let lastName = lastName {
            input["lastName"] = lastName
        }
        
        return input
    }
} 