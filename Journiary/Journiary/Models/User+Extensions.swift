//
//  User+Extensions.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import CoreData

extension User {
    
    // MARK: - Convenience Properties
    
    var displayName: String {
        if let firstName = firstName, let lastName = lastName, !firstName.isEmpty, !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        } else if let firstName = firstName, !firstName.isEmpty {
            return firstName
        } else if let username = username, !username.isEmpty {
            return username
        } else if let email = email, !email.isEmpty {
            return email
        } else {
            return "Unbekannter Benutzer"
        }
    }
    
    var initials: String {
        if let firstName = firstName, let lastName = lastName, !firstName.isEmpty, !lastName.isEmpty {
            let firstInitial = String(firstName.prefix(1)).uppercased()
            let lastInitial = String(lastName.prefix(1)).uppercased()
            return "\(firstInitial)\(lastInitial)"
        } else if let firstName = firstName, !firstName.isEmpty {
            return String(firstName.prefix(2)).uppercased()
        } else if let username = username, !username.isEmpty {
            return String(username.prefix(2)).uppercased()
        } else if let email = email, !email.isEmpty {
            return String(email.prefix(2)).uppercased()
        } else {
            return "?"
        }
    }
    
    // MARK: - Core Data Fetch Requests
    // fetchRequest() wird automatisch von Core Data generiert
    
    static func fetchCurrentUser(context: NSManagedObjectContext) -> User? {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "isCurrentUser == true")
        request.fetchLimit = 1
        
        do {
            let users = try context.fetch(request)
            return users.first
        } catch {
            print("❌ Fehler beim Abrufen des aktuellen Benutzers: \(error)")
            return nil
        }
    }
    
    static func setCurrentUser(_ user: User, context: NSManagedObjectContext) {
        // Alle anderen Benutzer als nicht aktuell markieren
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "isCurrentUser == true")
        
        do {
            let currentUsers = try context.fetch(request)
            for currentUser in currentUsers {
                currentUser.isCurrentUser = false
            }
            
            // Neuen Benutzer als aktuell setzen
            user.isCurrentUser = true
            user.updatedAt = Date()
            
            try context.save()
        } catch {
            print("❌ Fehler beim Setzen des aktuellen Benutzers: \(error)")
        }
    }
    
    static func findUser(byEmail email: String, context: NSManagedObjectContext) -> User? {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        request.fetchLimit = 1
        
        do {
            let users = try context.fetch(request)
            return users.first
        } catch {
            print("❌ Fehler beim Suchen des Benutzers mit E-Mail \(email): \(error)")
            return nil
        }
    }
    
    static func findUser(byBackendId backendId: String, context: NSManagedObjectContext) -> User? {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "backendUserId == %@", backendId)
        request.fetchLimit = 1
        
        do {
            let users = try context.fetch(request)
            return users.first
        } catch {
            print("❌ Fehler beim Suchen des Benutzers mit Backend-ID \(backendId): \(error)")
            return nil
        }
    }
    
    // MARK: - Convenience Initializer
    
    convenience init(context: NSManagedObjectContext, email: String, username: String, firstName: String? = nil, lastName: String? = nil, backendUserId: String? = nil) {
        self.init(context: context)
        
        self.id = UUID()
        self.email = email
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.backendUserId = backendUserId
        self.isCurrentUser = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Validation
    
    func validateEmail() -> Bool {
        guard let email = email, !email.isEmpty else { return false }
        
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var isValid: Bool {
        return validateEmail() && 
               username != nil && !username!.isEmpty &&
               username!.count >= 3
    }
} 