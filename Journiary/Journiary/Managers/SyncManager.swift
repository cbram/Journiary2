import Foundation
import CoreData
import JourniaryAPI

/// Manages the synchronization of data between the client and the backend.
///
/// This class is implemented as a Singleton and is responsible for orchestrating the entire sync process,
/// including uploading local changes and downloading remote changes from the server.
final class SyncManager {

    /// The shared singleton instance of `SyncManager`.
    static let shared = SyncManager()

    private let persistenceController = PersistenceController.shared
    private let networkProvider = NetworkProvider.shared
    private var lastSyncedAt: Date? {
        get {
            // Retrieve the last sync date from UserDefaults
            UserDefaults.standard.object(forKey: "lastSyncedAt") as? Date
        }
        set {
            // Store the last sync date in UserDefaults
            UserDefaults.standard.set(newValue, forKey: "lastSyncedAt")
        }
    }

    /// Private initializer to enforce the singleton pattern.
    private init() {}

    /// Initiates the synchronization cycle.
    ///
    /// The process consists of two main phases:
    /// 1.  **Upload Phase:** Local changes are sent to the server.
    /// 2.  **Download Phase:** Remote changes are fetched from the server and applied locally.
    ///
    /// If any step in the cycle fails, the entire process is aborted,
    /// and the `lastSyncedAt` timestamp is not updated to ensure data consistency.
    func sync() async {
        print("Sync started...")

        do {
            try await uploadPhase()
            let syncData = try await downloadPhase(since: lastSyncedAt)

            // If both phases succeed, update the last synced timestamp from the server response.
            if let serverTimestamp = self.dateTimeToDate(syncData.timestamp) {
                self.lastSyncedAt = serverTimestamp
                print("Sync completed successfully. New lastSyncedAt: \(serverTimestamp)")
            } else {
                print("Sync completed, but server timestamp was invalid.")
            }

        } catch {
            print("Sync failed: \(error.localizedDescription)")
            // The `lastSyncedAt` timestamp is not updated, so the next sync will retry the failed operations.
        }
    }

    /// **Phase 1: Upload**
    ///
    /// Identifies local creations, updates, and deletions and sends them to the backend via GraphQL mutations.
    private func uploadPhase() async throws {
        print("Executing upload phase...")
        
        let context = persistenceController.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Step 1: Upload new and updated trips
        try await uploadEntities(
            fetchRequest: Trip.fetchRequest(),
            context: context,
            create: { input in
                let result = try await self.networkProvider.createTrip(input: input as! TripInput)
                return (result.id, result.updatedAt)
            },
            update: { id, input in
                let result = try await self.networkProvider.updateTrip(id: id, input: input as! TripInput)
                return (result.id, result.updatedAt)
            }
        )

        // TODO: Add similar calls for other entities like Memory, MediaItem, etc.
        // try await uploadEntities(fetchRequest: Memory.fetchRequest(), ...)
        
        // Step 2: Process deletions
        try await processDeletions(context: context)
        
        // Save the background context if any changes were made
        if context.hasChanges {
            try await context.perform {
                try context.save()
            }
        }
    }

    /// **Phase 2: Download**
    ///
    /// Fetches remote changes since the last successful sync and applies them to the local Core Data store.
    /// - parameter since: The timestamp of the last successful synchronization. If `nil`, a full sync might be performed.
    /// - returns: The `SyncQuery.Data.Sync` object from the server.
    private func downloadPhase(since lastSync: Date?) async throws -> SyncQuery.Data.Sync {
        print("Executing download phase...")
        
        // 1. Call the `sync` query with the `lastSyncedAt` timestamp.
        let syncData = try await networkProvider.sync(lastSyncedAt: lastSync)
        
        let context = persistenceController.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // 2. Process deletions first
        let deletedIds = syncData.deletedIds.reduce(into: [String: [String]]()) { result, deletion in
            result[deletion.entityName, default: []].append(deletion.id)
        }
        
        for (entityName, ids) in deletedIds {
            try await deleteLocalObjects(entityName: entityName, serverIds: ids, context: context)
        }
        
        // 3. Process creations and updates
        // The trips array is non-optional in the schema, so we can iterate directly.
        try await upsertTrips(syncData.trips, context: context)
        
        // TODO: Add processing for other entities like Memory, MediaItem, etc.
        // if let memories = syncData.memories { ... }
        
        // 4. Save changes to the persistent store
        if context.hasChanges {
            try await context.perform {
                try context.save()
            }
        }
        
        // The new timestamp from the server is stored by the calling `sync()` method upon full success.
        print("Download phase completed.")
        return syncData
    }

    private func upsertTrips(_ trips: [SyncQuery.Data.Sync.Trip], context: NSManagedObjectContext) async throws {
        for remoteTrip in trips {
            await context.perform {
                let fetchRequest = Trip.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "serverId == %@", remoteTrip.id)
                fetchRequest.fetchLimit = 1

                let localTrip = try? context.fetch(fetchRequest).first

                // Last-Write-Wins: only update if server data is newer
                if let localTrip = localTrip, let localUpdatedAt = localTrip.updatedAt, let remoteUpdatedAt = self.dateTimeToDate(remoteTrip.updatedAt), remoteUpdatedAt <= localUpdatedAt {
                    print("Skipping update for Trip \(remoteTrip.id), local version is newer or same.")
                    return
                }

                let tripToUpdate = localTrip ?? Trip(context: context)
                
                tripToUpdate.serverId = remoteTrip.id
                tripToUpdate.name = remoteTrip.name
                tripToUpdate.tripDescription = remoteTrip.tripDescription
                tripToUpdate.travelCompanions = remoteTrip.travelCompanions
                tripToUpdate.visitedCountries = remoteTrip.visitedCountries
                // Handle non-optional dates with a fallback, although they are guaranteed by the schema
                tripToUpdate.startDate = self.dateTimeToDate(remoteTrip.startDate) ?? Date()
                tripToUpdate.endDate = self.dateTimeToDate(remoteTrip.endDate)
                tripToUpdate.isActive = remoteTrip.isActive
                tripToUpdate.totalDistance = remoteTrip.totalDistance
                tripToUpdate.gpsTrackingEnabled = remoteTrip.gpsTrackingEnabled
                tripToUpdate.createdAt = self.dateTimeToDate(remoteTrip.createdAt) ?? Date()
                tripToUpdate.updatedAt = self.dateTimeToDate(remoteTrip.updatedAt) ?? Date()
                tripToUpdate.syncStatus = .inSync
            }
        }
    }

    private func deleteLocalObjects(entityName: String, serverIds: [String], context: NSManagedObjectContext) async throws {
        let fetchRequest: NSFetchRequest<NSManagedObject>
        
        // Create the correct fetch request based on the entity name
        switch entityName {
        case "Trip":
            fetchRequest = Trip.fetchRequest() as! NSFetchRequest<NSManagedObject>
        // TODO: Add cases for other syncable entities
        // case "Memory":
        //     fetchRequest = Memory.fetchRequest()
        default:
            print("Unknown entity type for deletion: \(entityName)")
            return
        }
        
        fetchRequest.predicate = NSPredicate(format: "serverId IN %@", serverIds)
        
        await context.perform {
            do {
                let objectsToDelete = try context.fetch(fetchRequest)
                for object in objectsToDelete {
                    print("Deleting \(entityName) with server ID \((object as? Synchronizable)?.serverId ?? "") locally.")
                    context.delete(object)
                }
            } catch {
                print("Failed to fetch local objects for deletion: \(error)")
            }
        }
    }

    private func uploadEntities<T>(
        fetchRequest: NSFetchRequest<T>,
        context: NSManagedObjectContext,
        create: @escaping (Any) async throws -> (id: String, updatedAt: DateTime),
        update: @escaping (String, Any) async throws -> (id: String, updatedAt: DateTime)
    ) async throws where T: NSManagedObject, T: Synchronizable {
        
        let objectsToUpload = await context.perform { () -> [T] in
            do {
                // We use the underlying Int16 value for the predicate
                fetchRequest.predicate = NSPredicate(format: "syncStatusValue == %d", SyncStatus.needsUpload.rawValue)
                return try context.fetch(fetchRequest)
            } catch {
                print("Failed to fetch \(T.entity().name ?? "entities") for upload: \(error)")
                return []
            }
        }

        for object in objectsToUpload {
            let input = object.toGraphQLInput()
            do {
                var result: (id: String, updatedAt: DateTime)

                if let serverId = object.serverId, !serverId.isEmpty {
                    result = try await update(serverId, input)
                    print("Updated \(T.entity().name ?? "entity"): \(result.id)")
                } else {
                    result = try await create(input)
                    print("Created \(T.entity().name ?? "entity"): \(result.id)")
                }

                // Update local object with server data after successful upload
                await context.perform {
                    object.serverId = result.id
                    object.updatedAt = self.dateTimeToDate(result.updatedAt)
                    object.syncStatus = .inSync
                }
            } catch {
                print("Failed to upload \(T.entity().name ?? "entity") with local ID \(object.objectID): \(error)")
            }
        }
    }
    
    private func processDeletions(context: NSManagedObjectContext) async throws {
        let deletions = await context.perform { () -> [DeletionLog] in
            do {
                let request = DeletionLog.fetchRequest()
                return try context.fetch(request)
            } catch {
                print("Failed to fetch deletion logs: \(error)")
                return []
            }
        }
        
        for deletion in deletions {
            guard let entityName = deletion.loggedEntityName, let entityId = deletion.loggedEntityId else { continue }
            
            do {
                switch entityName {
                case "Trip":
                    _ = try await self.networkProvider.deleteTrip(id: entityId)
                    print("Deleted trip with id: \(entityId) on server.")
                // Add cases for other entities here
                // case "Memory":
                //     _ = try await self.networkProvider.deleteMemory(id: entityId)
                //     print("Deleted memory with id: \(entityId) on server.")
                default:
                    print("Unknown entity type for deletion: \(entityName)")
                }
                
                // If server deletion was successful, delete the log entry
                await context.perform {
                    context.delete(deletion)
                }
            } catch {
                print("Failed to delete \(entityName) with id \(entityId) on server: \(error)")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    /// Converts a Date to DateTime (String) for GraphQL operations
    private func dateToDateTime(_ date: Date) -> DateTime {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    
    /// Converts a DateTime (String) to Date for Core Data operations
    private func dateTimeToDate(_ dateTime: DateTime?) -> Date? {
        guard let dateTime = dateTime else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateTime)
    }
}

/// A protocol for Core Data entities that are synchronizable.
protocol Synchronizable: AnyObject {
    var serverId: String? { get set }
    var updatedAt: Date? { get set }
    var syncStatus: SyncStatus { get set }
    
    func toGraphQLInput() -> Any
}

/// Enum representing the synchronization status of a Core Data entity.
/// The rawValue is Int16 to be compatible with Core Data.
@objc
public enum SyncStatus: Int16 {
    case inSync = 0
    case needsUpload = 1
}


// MARK: - CoreData Entity Conformance to Synchronizable

extension Trip: Synchronizable {

    // The raw value of the enum is stored in a Core Data attribute named 'syncStatusValue'.
    // This computed property provides a convenient way to work with the `SyncStatus` enum.
    var syncStatus: SyncStatus {
        get {
            return SyncStatus(rawValue: self.syncStatusValue) ?? .inSync
        }
        set {
            self.syncStatusValue = newValue.rawValue
        }
    }

    func toGraphQLInput() -> Any {
        
        func dateToDateTime(_ date: Date) -> DateTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: date)
        }
        
        return TripInput(
            name: self.name ?? "Unnamed Trip",
            tripDescription: self.tripDescription ?? .none,
            travelCompanions: self.travelCompanions ?? .none,
            visitedCountries: self.visitedCountries ?? .none,
            startDate: dateToDateTime(self.startDate ?? Date()),
            endDate: self.endDate.map(dateToDateTime) ?? .none,
            isActive: .some(self.isActive),
            totalDistance: .some(self.totalDistance),
            gpsTrackingEnabled: .some(self.gpsTrackingEnabled)
        )
    }
}