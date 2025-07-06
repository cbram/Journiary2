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

        // The timestamp for the current sync operation.
        // This will be used to update `lastSyncedAt` upon successful completion.
        let currentSyncTimestamp = Date()

        do {
            try await uploadPhase()
            try await downloadPhase(since: lastSyncedAt)

            // If both phases succeed, update the last synced timestamp.
            self.lastSyncedAt = currentSyncTimestamp
            print("Sync completed successfully.")

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
    private func downloadPhase(since lastSync: Date?) async throws {
        // TODO: Implement download logic
        // 1. Call the `sync` query with the `lastSyncedAt` timestamp.
        // 2. Process the response:
        //    - Create new local objects.
        //    - Update existing local objects based on "Last-Write-Wins".
        //    - Delete local objects that were deleted on the server.
        print("Executing download phase...")
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
    private func dateTimeToDate(_ dateTime: DateTime) -> Date? {
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