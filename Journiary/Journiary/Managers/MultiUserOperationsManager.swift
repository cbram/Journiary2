//
//  MultiUserOperationsManager.swift
//  Journiary
//
//  Created by TravelCompanion AI on 28.12.24.
//

import Foundation
import CoreData
import Combine

/// Thread-Safe Multi-User Operations Manager
/// Behandelt sichere Core Data Operationen für Multi-User Szenarien
@MainActor
class MultiUserOperationsManager: ObservableObject {
    
    static let shared = MultiUserOperationsManager()
    
    // MARK: - Published Properties
    
    @Published var isPerformingBulkOperation = false
    @Published var bulkOperationProgress: Double = 0.0
    @Published var bulkOperationStatus = ""
    
    // MARK: - Private Properties
    
    private let persistenceController = EnhancedPersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Thread-Safe Operation Queue
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "MultiUserOperationsQueue"
        queue.maxConcurrentOperationCount = 3
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    private init() {}
    
    // MARK: - User Assignment Operations
    
    /// Weist alle User-losen Entitäten einem bestimmten User zu
    /// - Parameters:
    ///   - user: Der Ziel-User
    ///   - entityTypes: Array von Entity-Typen die zugewiesen werden sollen
    /// - Returns: Anzahl zugewiesener Objekte
    func assignOrphanedEntities(
        to user: User,
        entityTypes: [OrphanedEntityType] = OrphanedEntityType.allCases
    ) async throws -> [String: Int] {
        
        isPerformingBulkOperation = true
        bulkOperationProgress = 0.0
        var results: [String: Int] = [:]
        
        defer {
            Task { @MainActor in
                isPerformingBulkOperation = false
                bulkOperationProgress = 0.0
                bulkOperationStatus = ""
            }
        }
        
        let context = persistenceController.backgroundContext
        let totalSteps = entityTypes.count
        
        try await context.perform {
            for (index, entityType) in entityTypes.enumerated() {
                let stepProgress = Double(index) / Double(totalSteps)
                await self.updateBulkOperationProgress(stepProgress, status: "Verarbeite \(entityType.displayName)...")
                
                let count = try self.assignOrphanedEntities(of: entityType, to: user, in: context)
                results[entityType.rawValue] = count
                
                print("✅ \(count) \(entityType.displayName) zu User zugewiesen")
            }
            
            // Änderungen speichern
            await self.updateBulkOperationProgress(0.9, status: "Speichere Änderungen...")
            try context.save()
            
            await self.updateBulkOperationProgress(1.0, status: "✅ Abgeschlossen")
        }
        
        return results
    }
    
    /// Weist orphaned Entities eines bestimmten Typs zu
    private func assignOrphanedEntities(
        of type: OrphanedEntityType,
        to user: User,
        in context: NSManagedObjectContext
    ) throws -> Int {
        
        let request = NSFetchRequest<NSManagedObject>(entityName: type.entityName)
        request.predicate = type.orphanedPredicate
        
        let orphanedEntities = try context.fetch(request)
        
        for entity in orphanedEntities {
            entity.setValue(user, forKey: type.userRelationshipKey)
        }
        
        return orphanedEntities.count
    }
    
    // MARK: - Bulk User Operations
    
    /// Transferiert alle Daten von einem User zu einem anderen
    /// - Parameters:
    ///   - fromUser: Quell-User
    ///   - toUser: Ziel-User
    ///   - deleteSourceUser: Ob der Quell-User gelöscht werden soll
    func transferUserData(
        from fromUser: User,
        to toUser: User,
        deleteSourceUser: Bool = false
    ) async throws -> TransferResult {
        
        isPerformingBulkOperation = true
        bulkOperationProgress = 0.0
        
        defer {
            Task { @MainActor in
                isPerformingBulkOperation = false
            }
        }
        
        let context = persistenceController.backgroundContext
        var transferResult = TransferResult()
        
        try await context.perform {
            // Hole User-Objekte im Background Context
            guard let fromUserInContext = try self.getUser(withId: fromUser.objectID, in: context),
                  let toUserInContext = try self.getUser(withId: toUser.objectID, in: context) else {
                throw MultiUserOperationError.userNotFound
            }
            
            await self.updateBulkOperationProgress(0.1, status: "Übertrage Trips...")
            
            // Trips übertragen
            if let ownedTrips = fromUserInContext.ownedTrips?.allObjects as? [Trip] {
                for trip in ownedTrips {
                    trip.owner = toUserInContext
                }
                transferResult.tripsTransferred = ownedTrips.count
            }
            
            await self.updateBulkOperationProgress(0.3, status: "Übertrage Memories...")
            
            // Memories übertragen
            if let createdMemories = fromUserInContext.createdMemories?.allObjects as? [Memory] {
                for memory in createdMemories {
                    memory.creator = toUserInContext
                }
                transferResult.memoriesTransferred = createdMemories.count
            }
            
            await self.updateBulkOperationProgress(0.5, status: "Übertrage Tags...")
            
            // Tags übertragen
            if let createdTags = fromUserInContext.createdTags?.allObjects as? [Tag] {
                for tag in createdTags {
                    tag.creator = toUserInContext
                }
                transferResult.tagsTransferred = createdTags.count
            }
            
            await self.updateBulkOperationProgress(0.7, status: "Übertrage weitere Daten...")
            
            // MediaItems übertragen
            if let uploadedMediaItems = fromUserInContext.uploadedMediaItems?.allObjects as? [MediaItem] {
                for mediaItem in uploadedMediaItems {
                    mediaItem.uploader = toUserInContext
                }
                transferResult.mediaItemsTransferred = uploadedMediaItems.count
            }
            
            // BucketListItems übertragen
            if let bucketListItems = fromUserInContext.createdBucketListItems?.allObjects as? [BucketListItem] {
                for bucketListItem in bucketListItems {
                    bucketListItem.creator = toUserInContext
                }
                transferResult.bucketListItemsTransferred = bucketListItems.count
            }
            
            await self.updateBulkOperationProgress(0.9, status: "Speichere Änderungen...")
            
            // Quell-User löschen falls gewünscht
            if deleteSourceUser {
                context.delete(fromUserInContext)
                transferResult.sourceUserDeleted = true
            }
            
            try context.save()
            
            await self.updateBulkOperationProgress(1.0, status: "✅ Transfer abgeschlossen")
        }
        
        return transferResult
    }
    
    // MARK: - User Cleanup Operations
    
    /// Bereinigt inaktive oder doppelte User
    func cleanupInactiveUsers() async throws -> CleanupResult {
        isPerformingBulkOperation = true
        bulkOperationProgress = 0.0
        
        defer {
            Task { @MainActor in
                isPerformingBulkOperation = false
            }
        }
        
        let context = persistenceController.backgroundContext
        var cleanupResult = CleanupResult()
        
        try await context.perform {
            await self.updateBulkOperationProgress(0.2, status: "Suche inaktive Users...")
            
            // Finde Users ohne zugeordnete Daten
            let userRequest: NSFetchRequest<User> = User.fetchRequest()
            userRequest.predicate = NSPredicate(format: "isCurrentUser == NO")
            let allUsers = try context.fetch(userRequest)
            
            var usersToDelete: [User] = []
            
            for user in allUsers {
                let hasTrips = (user.ownedTrips?.count ?? 0) > 0
                let hasMemories = (user.createdMemories?.count ?? 0) > 0
                let hasTags = (user.createdTags?.count ?? 0) > 0
                let hasMediaItems = (user.uploadedMediaItems?.count ?? 0) > 0
                let hasBucketListItems = (user.createdBucketListItems?.count ?? 0) > 0
                
                if !hasTrips && !hasMemories && !hasTags && !hasMediaItems && !hasBucketListItems {
                    usersToDelete.append(user)
                }
            }
            
            await self.updateBulkOperationProgress(0.7, status: "Lösche inaktive Users...")
            
            for user in usersToDelete {
                context.delete(user)
            }
            
            cleanupResult.inactiveUsersDeleted = usersToDelete.count
            
            await self.updateBulkOperationProgress(0.9, status: "Speichere Änderungen...")
            try context.save()
            
            await self.updateBulkOperationProgress(1.0, status: "✅ Cleanup abgeschlossen")
        }
        
        return cleanupResult
    }
    
    // MARK: - Thread-Safe User Operations
    
    /// Erstellt einen neuen User thread-safe
    func createUser(
        email: String,
        username: String,
        firstName: String?,
        lastName: String?,
        setAsCurrent: Bool = false
    ) async throws -> User {
        
        let context = persistenceController.backgroundContext
        
        return try await context.perform {
            // Prüfe ob User bereits existiert
            let existingUserRequest: NSFetchRequest<User> = User.fetchRequest()
            existingUserRequest.predicate = NSPredicate(format: "email == %@ OR username == %@", email, username)
            existingUserRequest.fetchLimit = 1
            
            if let existingUser = try context.fetch(existingUserRequest).first {
                throw MultiUserOperationError.userAlreadyExists
            }
            
            // Erstelle neuen User
            let newUser = User(context: context)
            newUser.id = UUID()
            newUser.email = email
            newUser.username = username
            newUser.firstName = firstName
            newUser.lastName = lastName
            newUser.isCurrentUser = setAsCurrent
            newUser.createdAt = Date()
            newUser.updatedAt = Date()
            
            // Falls als aktueller User gesetzt, andere deaktivieren
            if setAsCurrent {
                let otherUsersRequest: NSFetchRequest<User> = User.fetchRequest()
                otherUsersRequest.predicate = NSPredicate(format: "isCurrentUser == YES")
                let otherUsers = try context.fetch(otherUsersRequest)
                
                for otherUser in otherUsers {
                    otherUser.isCurrentUser = false
                }
            }
            
            try context.save()
            
            print("✅ Neuer User erstellt: \(username)")
            return newUser
        }
    }
    
    /// Holt User thread-safe über ObjectID
    private func getUser(withId objectID: NSManagedObjectID, in context: NSManagedObjectContext) throws -> User? {
        guard let user = try context.existingObject(with: objectID) as? User else {
            return nil
        }
        return user
    }
    
    // MARK: - Helper Methods
    
    private func updateBulkOperationProgress(_ progress: Double, status: String) async {
        await MainActor.run {
            bulkOperationProgress = progress
            bulkOperationStatus = status
        }
    }
}

// MARK: - Supporting Types

enum OrphanedEntityType: String, CaseIterable {
    case trips = "Trip"
    case memories = "Memory"
    case tags = "Tag"
    case tagCategories = "TagCategory"
    case bucketListItems = "BucketListItem"
    case mediaItems = "MediaItem"
    case routePoints = "RoutePoint"
    case gpxTracks = "GPXTrack"
    
    var entityName: String {
        return rawValue
    }
    
    var displayName: String {
        switch self {
        case .trips: return "Trips"
        case .memories: return "Memories"
        case .tags: return "Tags"
        case .tagCategories: return "Tag-Kategorien"
        case .bucketListItems: return "Bucket-List Items"
        case .mediaItems: return "Media Items"
        case .routePoints: return "Route Points"
        case .gpxTracks: return "GPX Tracks"
        }
    }
    
    var userRelationshipKey: String {
        switch self {
        case .trips: return "owner"
        case .memories: return "creator"
        case .tags: return "creator"
        case .tagCategories: return "creator"
        case .bucketListItems: return "creator"
        case .mediaItems: return "uploader"
        case .routePoints: return "recorder"
        case .gpxTracks: return "creatorUser"
        }
    }
    
    var orphanedPredicate: NSPredicate {
        switch self {
        case .tags:
            // System Tags ausschließen
            return NSPredicate(format: "\(userRelationshipKey) == nil AND isSystemTag == NO")
        case .tagCategories:
            // System Categories ausschließen
            return NSPredicate(format: "\(userRelationshipKey) == nil AND isSystemCategory == NO")
        default:
            return NSPredicate(format: "\(userRelationshipKey) == nil")
        }
    }
}

struct TransferResult {
    var tripsTransferred = 0
    var memoriesTransferred = 0
    var tagsTransferred = 0
    var mediaItemsTransferred = 0
    var bucketListItemsTransferred = 0
    var sourceUserDeleted = false
    
    var totalItemsTransferred: Int {
        return tripsTransferred + memoriesTransferred + tagsTransferred + 
               mediaItemsTransferred + bucketListItemsTransferred
    }
}

struct CleanupResult {
    var inactiveUsersDeleted = 0
    var duplicateUsersDeleted = 0
}

enum MultiUserOperationError: LocalizedError {
    case userNotFound
    case userAlreadyExists
    case operationInProgress
    case contextNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User konnte nicht gefunden werden."
        case .userAlreadyExists:
            return "Ein User mit dieser E-Mail oder diesem Benutzername existiert bereits."
        case .operationInProgress:
            return "Eine andere Multi-User Operation läuft bereits."
        case .contextNotAvailable:
            return "Core Data Context ist nicht verfügbar."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .userNotFound:
            return "Überprüfen Sie ob der User noch existiert."
        case .userAlreadyExists:
            return "Verwenden Sie eine andere E-Mail oder einen anderen Benutzernamen."
        case .operationInProgress:
            return "Warten Sie bis die aktuelle Operation abgeschlossen ist."
        case .contextNotAvailable:
            return "Starten Sie die App neu."
        }
    }
} 