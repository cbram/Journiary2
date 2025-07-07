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
            if let serverTimestamp = self.dateTimeToDate(syncData.serverTimestamp) {
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
        try await uploadEntities(
            fetchRequest: Memory.fetchRequest(),
            context: context,
            create: { input in
                let result = try await self.networkProvider.createMemory(input: input as! MemoryInput)
                return (result.id, result.updatedAt)
            },
            update: { id, input in
                let result = try await self.networkProvider.updateMemory(id: id, input: input as! UpdateMemoryInput)
                return (result.id, result.updatedAt)
            }
        )
        
        // Upload MediaItems (string-based sync status)
        try await uploadStringBasedEntities(
            fetchRequest: MediaItem.fetchRequest(),
            context: context,
            create: { input in
                let result = try await self.networkProvider.createMediaItem(input: input as! MediaItemInput)
                return (result.id, result.updatedAt)
            }
        )
        
        // Upload GPXTracks (string-based sync status) 
        try await uploadStringBasedEntities(
            fetchRequest: GPXTrack.fetchRequest(),
            context: context,
            create: { input in
                let result = try await self.networkProvider.createGPXTrack(input: input as! GPXTrackInput)
                return (result.id, result.updatedAt)
            }
        )
        
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
        let deletedIds = syncData.deleted
        
        // Process trip deletions
        if !deletedIds.trips.isEmpty {
            try await self.deleteLocalObjects(entityName: "Trip", serverIds: deletedIds.trips.map { $0 }, context: context)
        }
        
        // Process memory deletions  
        if !deletedIds.memories.isEmpty {
            try await self.deleteLocalObjects(entityName: "Memory", serverIds: deletedIds.memories.map { $0 }, context: context)
        }
        
        // Process media item deletions
        if !deletedIds.mediaItems.isEmpty {
            try await self.deleteLocalObjects(entityName: "MediaItem", serverIds: deletedIds.mediaItems.map { $0 }, context: context)
        }
        
        // Process GPX track deletions
        if !deletedIds.gpxTracks.isEmpty {
            try await self.deleteLocalObjects(entityName: "GPXTrack", serverIds: deletedIds.gpxTracks.map { $0 }, context: context)
        }
        
        // 3. Process creations and updates
        // The trips array is non-optional in the schema, so we can iterate directly.
        try await upsertTrips(syncData.trips, context: context)
        
        // Process memories if they exist
        let memories = syncData.memories
        if !memories.isEmpty {
            try await upsertMemories(memories, context: context)
        }
        
        // Process media items if they exist
        let mediaItems = syncData.mediaItems
        if !mediaItems.isEmpty {
            try await upsertMediaItems(mediaItems, context: context)
        }
        
        // Process GPX tracks if they exist
        let gpxTracks = syncData.gpxTracks
        if !gpxTracks.isEmpty {
            try await upsertGPXTracks(gpxTracks, context: context)
        }
        
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

    private func upsertMemories(_ memories: [SyncQuery.Data.Sync.Memory], context: NSManagedObjectContext) async throws {
        for remoteMemory in memories {
            try await context.perform {
                let fetchRequest = Memory.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "serverId == %@", remoteMemory.id)
                fetchRequest.fetchLimit = 1

                let localMemory = try context.fetch(fetchRequest).first

                // Last-Write-Wins: only update if server data is newer
                if let localMemory = localMemory, let localUpdatedAt = localMemory.updatedAt, let remoteUpdatedAt = self.dateTimeToDate(remoteMemory.updatedAt), remoteUpdatedAt <= localUpdatedAt {
                    print("Skipping update for Memory \(remoteMemory.id), local version is newer or same.")
                    return
                }

                let memoryToUpdate = localMemory ?? Memory(context: context)
                
                memoryToUpdate.serverId = remoteMemory.id
                memoryToUpdate.title = remoteMemory.title
                memoryToUpdate.text = remoteMemory.text // Use correct field name
                memoryToUpdate.timestamp = self.dateTimeToDate(remoteMemory.timestamp) ?? Date()
                memoryToUpdate.latitude = remoteMemory.latitude
                memoryToUpdate.longitude = remoteMemory.longitude
                memoryToUpdate.locationName = remoteMemory.locationName
                memoryToUpdate.createdAt = self.dateTimeToDate(remoteMemory.createdAt) ?? Date()
                memoryToUpdate.updatedAt = self.dateTimeToDate(remoteMemory.updatedAt) ?? Date()
                memoryToUpdate.syncStatus = .inSync
                
                // Handle Trip relationship
                let tripId = remoteMemory.tripId
                let tripFetchRequest = Trip.fetchRequest()
                tripFetchRequest.predicate = NSPredicate(format: "serverId == %@", tripId)
                tripFetchRequest.fetchLimit = 1
                if let trip = try context.fetch(tripFetchRequest).first {
                    memoryToUpdate.trip = trip
                }
            }
        }
    }
    
    private func upsertMediaItems(_ mediaItems: [SyncQuery.Data.Sync.MediaItem], context: NSManagedObjectContext) async throws {
        for remoteMediaItem in mediaItems {
            try await context.perform {
                let fetchRequest = MediaItem.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "serverID == %@", remoteMediaItem.id)
                fetchRequest.fetchLimit = 1

                let localMediaItem = try context.fetch(fetchRequest).first

                // Last-Write-Wins: only update if server data is newer
                if let localMediaItem = localMediaItem, let localUpdatedAt = localMediaItem.updatedAt, let remoteUpdatedAt = self.dateTimeToDate(remoteMediaItem.updatedAt), remoteUpdatedAt <= localUpdatedAt {
                    print("Skipping update for MediaItem \(remoteMediaItem.id), local version is newer or same.")
                    return
                }

                let mediaItemToUpdate = localMediaItem ?? MediaItem(context: context)
                
                mediaItemToUpdate.serverID = remoteMediaItem.id
                mediaItemToUpdate.filename = remoteMediaItem.filename
                mediaItemToUpdate.mediaType = remoteMediaItem.mimeType
                mediaItemToUpdate.timestamp = self.dateTimeToDate(remoteMediaItem.timestamp) ?? Date()
                mediaItemToUpdate.order = Int16(remoteMediaItem.order)
                mediaItemToUpdate.filesize = Int64(remoteMediaItem.fileSize)
                mediaItemToUpdate.duration = Double(remoteMediaItem.duration ?? 0)
                mediaItemToUpdate.createdAt = self.dateTimeToDate(remoteMediaItem.createdAt) ?? Date()
                mediaItemToUpdate.updatedAt = self.dateTimeToDate(remoteMediaItem.updatedAt) ?? Date()
                mediaItemToUpdate.syncStatusEnum = .inSync
                
                // Handle Memory relationship
                let memory = remoteMediaItem.memory
                let memoryFetchRequest = Memory.fetchRequest()
                memoryFetchRequest.predicate = NSPredicate(format: "serverId == %@", memory.id)
                memoryFetchRequest.fetchLimit = 1
                if let localMemory = try context.fetch(memoryFetchRequest).first {
                    mediaItemToUpdate.memory = localMemory
                }
            }
        }
    }
    
    private func upsertGPXTracks(_ gpxTracks: [SyncQuery.Data.Sync.GpxTrack], context: NSManagedObjectContext) async throws {
        for remoteGPXTrack in gpxTracks {
            try await context.perform {
                let fetchRequest = GPXTrack.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "serverID == %@", remoteGPXTrack.id)
                fetchRequest.fetchLimit = 1

                let localGPXTrack = try context.fetch(fetchRequest).first

                // Last-Write-Wins: only update if server data is newer
                if let localGPXTrack = localGPXTrack, let localUpdatedAt = localGPXTrack.updatedAt, let remoteUpdatedAt = self.dateTimeToDate(remoteGPXTrack.updatedAt), remoteUpdatedAt <= localUpdatedAt {
                    print("Skipping update for GPXTrack \(remoteGPXTrack.id), local version is newer or same.")
                    return
                }

                let gpxTrackToUpdate = localGPXTrack ?? GPXTrack(context: context)
                
                gpxTrackToUpdate.serverID = remoteGPXTrack.id
                gpxTrackToUpdate.name = remoteGPXTrack.name
                gpxTrackToUpdate.originalFilename = remoteGPXTrack.originalFilename
                gpxTrackToUpdate.creator = remoteGPXTrack.creator
                gpxTrackToUpdate.trackType = remoteGPXTrack.trackType
                gpxTrackToUpdate.createdAt = self.dateTimeToDate(remoteGPXTrack.createdAt) ?? Date()
                gpxTrackToUpdate.updatedAt = self.dateTimeToDate(remoteGPXTrack.updatedAt) ?? Date()
                gpxTrackToUpdate.syncStatusEnum = .inSync
                
                // Handle Trip relationship (GPXTrack is connected to Trip via Memory)
                let tripId = remoteGPXTrack.tripId
                let tripFetchRequest = Trip.fetchRequest()
                tripFetchRequest.predicate = NSPredicate(format: "serverId == %@", tripId)
                tripFetchRequest.fetchLimit = 1
                if let trip = try context.fetch(tripFetchRequest).first {
                    // Note: GPXTrack doesn't have direct trip relation in Core Data
                    // The relationship is established via Memory
                }
            }
        }
    }

    private func upsertTrips(_ trips: [SyncQuery.Data.Sync.Trip], context: NSManagedObjectContext) async throws {
        for remoteTrip in trips {
            try await context.perform {
                let fetchRequest = Trip.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "serverId == %@", remoteTrip.id)
                fetchRequest.fetchLimit = 1

                let localTrip = try context.fetch(fetchRequest).first

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
        case "Memory":
            fetchRequest = Memory.fetchRequest() as! NSFetchRequest<NSManagedObject>
        case "MediaItem":
            fetchRequest = MediaItem.fetchRequest() as! NSFetchRequest<NSManagedObject>
        case "GPXTrack":
            fetchRequest = GPXTrack.fetchRequest() as! NSFetchRequest<NSManagedObject>
        default:
            print("Unknown entity type for deletion: \(entityName)")
            return
        }
        
        fetchRequest.predicate = NSPredicate(format: "serverId IN %@", serverIds)
        
        try await context.perform {
            let objectsToDelete = try context.fetch(fetchRequest)
            for object in objectsToDelete {
                print("Deleting \(entityName) with server ID \((object as? Synchronizable)?.serverId ?? "") locally.")
                context.delete(object)
            }
        }
    }

    private func uploadEntities<T>(
        fetchRequest: NSFetchRequest<T>,
        context: NSManagedObjectContext,
        create: @escaping (Any) async throws -> (id: String, updatedAt: DateTime),
        update: @escaping (String, Any) async throws -> (id: String, updatedAt: DateTime)
    ) async throws where T: NSManagedObject, T: Synchronizable {
        
        let objectsToUpload = try await context.perform { () -> [T] in
            // We use the underlying Int16 value for the predicate
            fetchRequest.predicate = NSPredicate(format: "syncStatusValue == %d", SyncStatus.needsUpload.rawValue)
            return try context.fetch(fetchRequest)
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
                try await context.perform {
                    object.serverId = result.id
                    object.updatedAt = self.dateTimeToDate(result.updatedAt)
                    object.syncStatus = .inSync
                }
            } catch {
                print("Failed to upload \(T.entity().name ?? "entity") with local ID \(object.objectID): \(error)")
            }
        }
    }
    
    private func uploadStringBasedEntities<T: StringBasedSynchronizable>(
        fetchRequest: NSFetchRequest<T>,
        context: NSManagedObjectContext,
        create: @escaping (Any) async throws -> (id: String, updatedAt: DateTime)
    ) async throws where T: NSManagedObject {
        
        let objectsToUpload = try await context.perform { () -> [T] in
            fetchRequest.predicate = NSPredicate(format: "syncStatus == %@", String(SyncStatus.needsUpload.rawValue))
            return try context.fetch(fetchRequest)
        }

        for object in objectsToUpload {
            let input = object.toGraphQLInput()
            do {
                let result = try await create(input)
                print("Created \(T.entity().name ?? "entity"): \(result.id)")

                // Update local object with server data after successful upload
                try await context.perform {
                    object.serverId = result.id
                    object.updatedAt = self.dateTimeToDate(result.updatedAt)
                    object.syncStatusEnum = .inSync
                }
            } catch {
                print("Failed to upload \(T.entity().name ?? "entity") with local ID \(object.objectID): \(error)")
                // Set status to failed upload
                try await context.perform {
                    object.syncStatusEnum = .needsUpload // Keep trying for now
                }
            }
        }
    }
    
    private func processDeletions(context: NSManagedObjectContext) async throws {
        let deletions = try await context.perform { () -> [DeletionLog] in
            let request = DeletionLog.fetchRequest()
            return try context.fetch(request)
        }
        
        for deletion in deletions {
            guard let entityName = deletion.loggedEntityName, let entityId = deletion.loggedEntityId else { continue }
            
            do {
                switch entityName {
                case "Trip":
                    _ = try await self.networkProvider.deleteTrip(id: entityId)
                    print("Deleted trip with id: \(entityId) on server.")
                case "Memory":
                    _ = try await self.networkProvider.deleteMemory(id: entityId)
                    print("Deleted memory with id: \(entityId) on server.")
                case "MediaItem":
                    _ = try await self.networkProvider.deleteMediaItem(id: entityId)
                    print("Deleted media item with id: \(entityId) on server.")
                case "GPXTrack":
                    _ = try await self.networkProvider.deleteGPXTrack(id: entityId)
                    print("Deleted GPX track with id: \(entityId) on server.")
                default:
                    print("Unknown entity type for deletion: \(entityName)")
                }
                
                // If server deletion was successful, delete the log entry
                try await context.perform {
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

/// A protocol for entities that use String-based sync status (like MediaItem, GPXTrack)
protocol StringBasedSynchronizable: AnyObject {
    var serverId: String? { get set }
    var updatedAt: Date? { get set }
    var syncStatusEnum: SyncStatus { get set }
    
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

extension Memory: Synchronizable {

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
        
        // For updates, we use a different input type.
        // We decide based on whether serverId exists.
        if let _ = self.serverId {
            return UpdateMemoryInput(
                title: self.title.map { .some($0) } ?? .none,
                content: self.text.map { .some($0) } ?? .none,
                date: self.timestamp.map { .some(dateToDateTime($0)) } ?? .none,
                latitude: GraphQLNullable.some(self.latitude),
                longitude: GraphQLNullable.some(self.longitude),
                address: self.locationName.map { .some($0) } ?? .none
            )
        } else {
            return MemoryInput(
                title: self.title ?? "Unnamed Memory",
                content: self.text.map { .some($0) } ?? .none,
                date: self.timestamp.map { .some(dateToDateTime($0)) } ?? .none,
                latitude: GraphQLNullable.some(self.latitude),
                longitude: GraphQLNullable.some(self.longitude),
                address: self.locationName.map { .some($0) } ?? .none,
                tripId: self.trip?.serverId ?? ""
            )
        }
    }
}

// MARK: - MediaItem Synchronizable Extension

extension MediaItem: StringBasedSynchronizable {
    var serverId: String? {
        get { return self.serverID }
        set { self.serverID = newValue }
    }
    
    var syncStatusEnum: SyncStatus {
        get { 
            if let statusString = self.syncStatus, let statusValue = Int16(statusString) {
                return SyncStatus(rawValue: statusValue) ?? .inSync
            }
            return .inSync
        }
        set { 
            self.syncStatus = String(newValue.rawValue)
        }
    }
    
    func toGraphQLInput() -> Any {
        func dateToDateTime(_ date: Date) -> DateTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: date)
        }
        
        // For MediaItem, we only support create for now
        return MediaItemInput(
            objectName: self.filename ?? "",
            thumbnailObjectName: .none,
            memoryId: self.memory?.serverId ?? "",
            mediaType: self.mediaType ?? "unknown",
            timestamp: dateToDateTime(self.timestamp ?? Date()),
            order: Int(self.order),
            filesize: Int(self.filesize),
            duration: self.duration > 0 ? GraphQLNullable.some(Int(self.duration)) : .none
        )
    }
}

// MARK: - GPXTrack Synchronizable Extension

extension GPXTrack: StringBasedSynchronizable {
    var serverId: String? {
        get { return self.serverID }
        set { self.serverID = newValue }
    }
    
    var syncStatusEnum: SyncStatus {
        get {
            if let statusString = self.syncStatus, let statusValue = Int16(statusString) {
                return SyncStatus(rawValue: statusValue) ?? .inSync
            }
            return .inSync
        }
        set {
            self.syncStatus = String(newValue.rawValue)
        }
    }
    
    func toGraphQLInput() -> Any {
        // For GPXTrack, we only support create for now
        return GPXTrackInput(
            name: self.name ?? "Unnamed Track",
            gpxFileObjectName: GraphQLNullable<String>.none, // File sync is handled separately
            originalFilename: self.originalFilename != nil ? GraphQLNullable<String>.some(self.originalFilename!) : GraphQLNullable<String>.none,
            tripId: self.memory?.trip?.serverId ?? "",
            memoryId: self.memory?.serverId != nil ? GraphQLNullable<String>.some(self.memory!.serverId!) : GraphQLNullable<String>.none,
            creator: self.creator != nil ? GraphQLNullable<String>.some(self.creator!) : GraphQLNullable<String>.none,
            trackType: self.trackType != nil ? GraphQLNullable<String>.some(self.trackType!) : GraphQLNullable<String>.none
        )
    }
}