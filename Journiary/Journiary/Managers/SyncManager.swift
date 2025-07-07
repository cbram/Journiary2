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
    /// The process consists of three main phases:
    /// 1.  **Upload Phase:** Local changes are sent to the server.
    /// 2.  **Download Phase:** Remote changes are fetched from the server and applied locally.
    /// 3.  **File Sync Phase:** Upload and download files asynchronously.
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
                
                // Start file synchronization asynchronously (doesn't block the main sync)
                Task {
                    await self.fileSyncPhase()
                }
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
        try await uploadStringBasedEntitiesForMediaItem(
            fetchRequest: MediaItem.fetchRequest(),
            context: context
        )
        
        // Upload GPXTracks (string-based sync status) 
        try await uploadStringBasedEntitiesForGPX(
            fetchRequest: GPXTrack.fetchRequest(),
            context: context
        )
        
        // Upload Tags (using special method since Tag responses don't include updatedAt)
        try await uploadTagEntities(
            fetchRequest: Tag.fetchRequest(),
            context: context
        )
        
        // Upload TagCategories (string-based sync status)
        try await uploadStringBasedEntities(
            fetchRequest: TagCategory.fetchRequest(),
            context: context,
            create: { input in
                let result = try await self.networkProvider.createTagCategory(input: input as! TagCategoryInput)
                return (result.id, result.updatedAt)
            }
        )
        
        // Upload BucketListItems (string-based sync status)
        try await uploadStringBasedEntities(
            fetchRequest: BucketListItem.fetchRequest(),
            context: context,
            create: { input in
                let result = try await self.networkProvider.createBucketListItem(input: input as! BucketListItemInput)
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
        
        // Process tag deletions
        if !deletedIds.tags.isEmpty {
            try await self.deleteLocalObjects(entityName: "Tag", serverIds: deletedIds.tags.map { $0 }, context: context)
        }
        
        // Process tag category deletions
        if !deletedIds.tagCategories.isEmpty {
            try await self.deleteLocalObjects(entityName: "TagCategory", serverIds: deletedIds.tagCategories.map { $0 }, context: context)
        }
        
        // Process bucket list item deletions
        if !deletedIds.bucketListItems.isEmpty {
            try await self.deleteLocalObjects(entityName: "BucketListItem", serverIds: deletedIds.bucketListItems.map { $0 }, context: context)
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
        
        // Process tags if they exist
        let tags = syncData.tags
        if !tags.isEmpty {
            try await upsertTags(tags, context: context)
        }
        
        // Process tag categories if they exist
        let tagCategories = syncData.tagCategories
        if !tagCategories.isEmpty {
            try await upsertTagCategories(tagCategories, context: context)
        }
        
        // Process bucket list items if they exist
        let bucketListItems = syncData.bucketListItems
        if !bucketListItems.isEmpty {
            try await upsertBucketListItems(bucketListItems, context: context)
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
                
                // Set ID if creating new entity
                if localMediaItem == nil {
                    mediaItemToUpdate.id = UUID()
                }
                
                mediaItemToUpdate.serverID = remoteMediaItem.id
                mediaItemToUpdate.filename = remoteMediaItem.filename
                mediaItemToUpdate.mediaType = remoteMediaItem.mimeType
                mediaItemToUpdate.timestamp = self.dateTimeToDate(remoteMediaItem.timestamp) ?? Date()
                mediaItemToUpdate.order = Int16(remoteMediaItem.order)
                mediaItemToUpdate.filesize = Int64(remoteMediaItem.fileSize)
                mediaItemToUpdate.duration = Double(remoteMediaItem.duration ?? 0)
                mediaItemToUpdate.createdAt = self.dateTimeToDate(remoteMediaItem.createdAt) ?? Date()
                mediaItemToUpdate.updatedAt = self.dateTimeToDate(remoteMediaItem.updatedAt) ?? Date()
                mediaItemToUpdate.syncStatus = String(SyncStatus.inSync.rawValue)
                
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
                
                // Set ID if creating new entity
                if localGPXTrack == nil {
                    gpxTrackToUpdate.id = UUID()
                }
                
                gpxTrackToUpdate.serverID = remoteGPXTrack.id
                gpxTrackToUpdate.name = remoteGPXTrack.name
                gpxTrackToUpdate.originalFilename = remoteGPXTrack.originalFilename
                gpxTrackToUpdate.creator = remoteGPXTrack.creator
                gpxTrackToUpdate.trackType = remoteGPXTrack.trackType
                gpxTrackToUpdate.createdAt = self.dateTimeToDate(remoteGPXTrack.createdAt) ?? Date()
                gpxTrackToUpdate.updatedAt = self.dateTimeToDate(remoteGPXTrack.updatedAt) ?? Date()
                gpxTrackToUpdate.syncStatus = String(SyncStatus.inSync.rawValue)
                
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
        case "Tag":
            fetchRequest = Tag.fetchRequest() as! NSFetchRequest<NSManagedObject>
        case "TagCategory":
            fetchRequest = TagCategory.fetchRequest() as! NSFetchRequest<NSManagedObject>
        case "BucketListItem":
            fetchRequest = BucketListItem.fetchRequest() as! NSFetchRequest<NSManagedObject>
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
            let objectID = object.objectID // Capture the ObjectID
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
                    if var managedObject = try? context.existingObject(with: objectID) as? T {
                        managedObject.serverId = result.id
                        managedObject.updatedAt = self.dateTimeToDate(result.updatedAt)
                        managedObject.syncStatus = .inSync
                    }
                }
            } catch {
                print("Failed to upload \(T.entity().name ?? "entity") with local ID \(object.objectID): \(error)")
            }
        }
    }
    
    private func uploadStringBasedEntities<T: StringSynchronizable>(
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
            let objectID = object.objectID // Capture the ObjectID
            do {
                let result = try await create(input)
                print("Created \(T.entity().name ?? "entity"): \(result.id)")

                // Update local object with server data after successful upload
                try await context.perform {
                    if var managedObject = try? context.existingObject(with: objectID) as? T {
                        managedObject.serverId = result.id
                        managedObject.setValue(self.dateTimeToDate(result.updatedAt), forKey: "updatedAt")
                        managedObject.synchronizationStatus = .inSync
                    }
                }
            } catch {
                print("Failed to upload \(T.entity().name ?? "entity") with local ID \(object.objectID): \(error)")
                // Set status to failed upload
                try await context.perform {
                    if var managedObject = try? context.existingObject(with: objectID) as? T {
                        managedObject.synchronizationStatus = .needsUpload // Keep trying for now
                    }
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
                case "Tag":
                    _ = try await self.networkProvider.deleteTag(id: entityId)
                    print("Deleted tag with id: \(entityId) on server.")
                case "TagCategory":
                    _ = try await self.networkProvider.deleteTagCategory(id: entityId)
                    print("Deleted tag category with id: \(entityId) on server.")
                case "BucketListItem":
                    _ = try await self.networkProvider.deleteBucketListItem(id: entityId)
                    print("Deleted bucket list item with id: \(entityId) on server.")
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
    
    /// Special upload method for Tags since their responses don't include updatedAt
    private func uploadTagEntities(
        fetchRequest: NSFetchRequest<Tag>,
        context: NSManagedObjectContext
    ) async throws {
        
        let objectsToUpload = try await context.perform { () -> [Tag] in
            fetchRequest.predicate = NSPredicate(format: "syncStatus == %@", String(SyncStatus.needsUpload.rawValue))
            return try context.fetch(fetchRequest)
        }

        for object in objectsToUpload {
            let input = object.toGraphQLInput()
            do {
                var result: (id: String, updatedAt: DateTime?)

                if let serverId = object.serverId, !serverId.isEmpty {
                    result = try await networkProvider.updateTag(id: serverId, input: input as! UpdateTagInput)
                    print("Updated Tag: \(result.id)")
                } else {
                    result = try await networkProvider.createTag(input: input as! TagInput)
                    print("Created Tag: \(result.id)")
                }

                // Update local object with server data after successful upload
                try await context.perform {
                    object.serverId = result.id
                    // For tags, we set updatedAt to current time since server doesn't return it
                    object.setValue(Date(), forKey: "updatedAt")
                    object.synchronizationStatus = .inSync
                }
            } catch {
                print("Failed to upload Tag with local ID \(object.objectID): \(error)")
            }
        }
    }
    
    /// Upload method for TagCategories with string-based sync status
    private func uploadStringBasedTagCategoryEntities(
        fetchRequest: NSFetchRequest<TagCategory>,
        context: NSManagedObjectContext
    ) async throws {
        
        let objectsToUpload = try await context.perform { () -> [TagCategory] in
            fetchRequest.predicate = NSPredicate(format: "syncStatus == %@", String(SyncStatus.needsUpload.rawValue))
            return try context.fetch(fetchRequest)
        }

        for object in objectsToUpload {
            let input = object.toGraphQLInput()
            do {
                var result: (id: String, updatedAt: DateTime)

                if let serverId = object.serverId, !serverId.isEmpty {
                    result = try await networkProvider.updateTagCategory(id: serverId, input: input as! UpdateTagCategoryInput)
                    print("Updated TagCategory: \(result.id)")
                } else {
                    result = try await networkProvider.createTagCategory(input: input as! TagCategoryInput)
                    print("Created TagCategory: \(result.id)")
                }

                // Update local object with server data after successful upload
                try await context.perform {
                    object.serverId = result.id
                    object.setValue(self.dateTimeToDate(result.updatedAt), forKey: "updatedAt")
                    object.synchronizationStatus = .inSync
                }
            } catch {
                print("Failed to upload TagCategory with local ID \(object.objectID): \(error)")
            }
        }
    }
    
    /// Upload method for BucketListItems with string-based sync status
    private func uploadStringBasedBucketListItemEntities(
        fetchRequest: NSFetchRequest<BucketListItem>,
        context: NSManagedObjectContext
    ) async throws {
        
        let objectsToUpload = try await context.perform { () -> [BucketListItem] in
            fetchRequest.predicate = NSPredicate(format: "syncStatus == %@", String(SyncStatus.needsUpload.rawValue))
            return try context.fetch(fetchRequest)
        }

        for object in objectsToUpload {
            let input = object.toGraphQLInput()
            do {
                var result: (id: String, updatedAt: DateTime)

                if let serverId = object.serverId, !serverId.isEmpty {
                    result = try await networkProvider.updateBucketListItem(id: serverId, input: input as! BucketListItemInput)
                    print("Updated BucketListItem: \(result.id)")
                } else {
                    result = try await networkProvider.createBucketListItem(input: input as! BucketListItemInput)
                    print("Created BucketListItem: \(result.id)")
                }

                // Update local object with server data after successful upload
                try await context.perform {
                    object.serverId = result.id
                    object.setValue(self.dateTimeToDate(result.updatedAt), forKey: "updatedAt")
                    object.synchronizationStatus = .inSync
                }
            } catch {
                print("Failed to upload BucketListItem with local ID \(object.objectID): \(error)")
            }
        }
    }
    
    // MARK: - Entity Upsert Methods
    
    private func upsertTags(_ tags: [SyncQuery.Data.Sync.Tag], context: NSManagedObjectContext) async throws {
        for remoteTag in tags {
            try await context.perform {
                let fetchRequest = Tag.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "serverId == %@", remoteTag.id)
                fetchRequest.fetchLimit = 1

                let localTag = try context.fetch(fetchRequest).first

                // Last-Write-Wins: only update if server data is newer
                if let localTag = localTag, let localUpdatedAt = localTag.updatedAt, let remoteUpdatedAt = self.dateTimeToDate(remoteTag.updatedAt), remoteUpdatedAt <= localUpdatedAt {
                    print("Skipping update for Tag \(remoteTag.id), local version is newer or same.")
                    return
                }

                let tagToUpdate = localTag ?? Tag(context: context)
                
                // Set ID if creating new entity
                if localTag == nil {
                    tagToUpdate.id = UUID()
                }
                
                tagToUpdate.serverId = remoteTag.id
                tagToUpdate.name = remoteTag.name
                tagToUpdate.emoji = remoteTag.emoji
                tagToUpdate.color = remoteTag.color
                tagToUpdate.isSystemTag = remoteTag.isSystemTag
                tagToUpdate.usageCount = Int32(remoteTag.usageCount)
                tagToUpdate.createdAt = self.dateTimeToDate(remoteTag.createdAt) ?? Date()
                tagToUpdate.updatedAt = self.dateTimeToDate(remoteTag.updatedAt) ?? Date()
                tagToUpdate.syncStatus = String(SyncStatus.inSync.rawValue)
                
                // Set TagCategory relationship if categoryId is provided
                if let categoryId = remoteTag.categoryId {
                    let categoryFetchRequest = TagCategory.fetchRequest()
                    categoryFetchRequest.predicate = NSPredicate(format: "serverId == %@", categoryId)
                    categoryFetchRequest.fetchLimit = 1
                    
                    if let tagCategory = try context.fetch(categoryFetchRequest).first {
                        tagToUpdate.category = tagCategory
                    }
                } else {
                    tagToUpdate.category = nil
                }
            }
        }
    }
    
    private func upsertTagCategories(_ tagCategories: [SyncQuery.Data.Sync.TagCategory], context: NSManagedObjectContext) async throws {
        for remoteTagCategory in tagCategories {
            try await context.perform {
                let fetchRequest = TagCategory.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "serverId == %@", remoteTagCategory.id)
                fetchRequest.fetchLimit = 1

                let localTagCategory = try context.fetch(fetchRequest).first

                // Last-Write-Wins: only update if server data is newer
                if let localTagCategory = localTagCategory, let localUpdatedAt = localTagCategory.updatedAt, let remoteUpdatedAt = self.dateTimeToDate(remoteTagCategory.updatedAt), remoteUpdatedAt <= localUpdatedAt {
                    print("Skipping update for TagCategory \(remoteTagCategory.id), local version is newer or same.")
                    return
                }

                let tagCategoryToUpdate = localTagCategory ?? TagCategory(context: context)
                
                // Set ID if creating new entity
                if localTagCategory == nil {
                    tagCategoryToUpdate.id = UUID()
                }
                
                tagCategoryToUpdate.serverId = remoteTagCategory.id
                tagCategoryToUpdate.name = remoteTagCategory.name
                tagCategoryToUpdate.displayName = remoteTagCategory.displayName
                tagCategoryToUpdate.emoji = remoteTagCategory.emoji
                tagCategoryToUpdate.color = remoteTagCategory.color
                tagCategoryToUpdate.isSystemCategory = remoteTagCategory.isSystemCategory
                tagCategoryToUpdate.sortOrder = Int32(remoteTagCategory.sortOrder)
                tagCategoryToUpdate.isExpanded = remoteTagCategory.isExpanded
                tagCategoryToUpdate.createdAt = self.dateTimeToDate(remoteTagCategory.createdAt) ?? Date()
                tagCategoryToUpdate.updatedAt = self.dateTimeToDate(remoteTagCategory.updatedAt) ?? Date()
                tagCategoryToUpdate.syncStatus = String(SyncStatus.inSync.rawValue)
            }
        }
    }
    
    private func upsertBucketListItems(_ bucketListItems: [SyncQuery.Data.Sync.BucketListItem], context: NSManagedObjectContext) async throws {
        for remoteBucketListItem in bucketListItems {
            try await context.perform {
                let fetchRequest = BucketListItem.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "serverId == %@", remoteBucketListItem.id)
                fetchRequest.fetchLimit = 1

                let localBucketListItem = try context.fetch(fetchRequest).first

                // Last-Write-Wins: only update if server data is newer
                if let localBucketListItem = localBucketListItem, let localUpdatedAt = localBucketListItem.updatedAt, let remoteUpdatedAt = self.dateTimeToDate(remoteBucketListItem.updatedAt), remoteUpdatedAt <= localUpdatedAt {
                    print("Skipping update for BucketListItem \(remoteBucketListItem.id), local version is newer or same.")
                    return
                }

                let bucketListItemToUpdate = localBucketListItem ?? BucketListItem(context: context)
                
                // Set ID if creating new entity
                if localBucketListItem == nil {
                    bucketListItemToUpdate.id = UUID()
                }
                
                bucketListItemToUpdate.serverId = remoteBucketListItem.id
                bucketListItemToUpdate.name = remoteBucketListItem.name
                bucketListItemToUpdate.country = remoteBucketListItem.country
                bucketListItemToUpdate.region = remoteBucketListItem.region
                bucketListItemToUpdate.type = remoteBucketListItem.type
                bucketListItemToUpdate.latitude1 = remoteBucketListItem.latitude1 ?? 0.0
                bucketListItemToUpdate.longitude1 = remoteBucketListItem.longitude1 ?? 0.0
                bucketListItemToUpdate.latitude2 = remoteBucketListItem.latitude2 ?? 0.0
                bucketListItemToUpdate.longitude2 = remoteBucketListItem.longitude2 ?? 0.0
                bucketListItemToUpdate.isDone = remoteBucketListItem.isDone
                bucketListItemToUpdate.completedAt = self.dateTimeToDate(remoteBucketListItem.completedAt)
                bucketListItemToUpdate.createdAt = self.dateTimeToDate(remoteBucketListItem.createdAt) ?? Date()
                bucketListItemToUpdate.updatedAt = self.dateTimeToDate(remoteBucketListItem.updatedAt) ?? Date()
                bucketListItemToUpdate.syncStatus = String(SyncStatus.inSync.rawValue)
            }
        }
    }
    
    // MARK: - File Synchronization Phase
    
    /// **Phase 3: File Synchronization**
    ///
    /// This phase handles the asynchronous upload and download of files (MediaItems and GPXTracks)
    /// using presigned URLs. It runs independently from the main sync cycle to avoid blocking
    /// the metadata synchronization.
    private func fileSyncPhase() async {
        print("Starting file synchronization phase...")
        
        do {
            // Step 1: Upload pending files
            try await uploadPendingFiles()
            
            // Step 2: Download missing files  
            try await downloadMissingFiles()
            
            print("File synchronization completed successfully.")
        } catch {
            print("File synchronization failed: \(error.localizedDescription)")
        }
    }
    
    /// Uploads files that are pending upload to MinIO.
    private func uploadPendingFiles() async throws {
        print("Uploading pending files...")
        
        let context = persistenceController.container.newBackgroundContext()
        let fileManager = MediaFileManager.shared
        
        // Find MediaItems and GPXTracks that need file upload
        let mediaItemsToUpload = try await findMediaItemsNeedingUpload(context: context)
        let gpxTracksToUpload = try await findGPXTracksNeedingUpload(context: context)
        
        // Combine all upload requests
        var uploadRequests: [JourniaryAPI.UploadRequest] = []
        var uploadTasks: [FileUploadTask] = []
        
        // Process MediaItems
        for mediaItem in mediaItemsToUpload {
            if let localFileURL = getLocalFileURL(for: mediaItem) {
                let fileExtension = localFileURL.pathExtension
                let objectName = fileManager.generateObjectName(entityType: "MediaItem", fileExtension: fileExtension)
                let mimeType = fileManager.mimeType(for: fileExtension)
                
                let uploadRequest = JourniaryAPI.UploadRequest(
                    entityId: mediaItem.id?.uuidString ?? UUID().uuidString,
                    entityType: "MediaItem",
                    objectName: objectName,
                    mimeType: mimeType
                )
                uploadRequests.append(uploadRequest)
                
                let uploadTask = FileUploadTask(
                    entityId: mediaItem.id?.uuidString ?? UUID().uuidString,
                    entityType: "MediaItem",
                    fileURL: localFileURL,
                    uploadURL: "", // Will be filled after getting presigned URLs
                    objectName: objectName,
                    mimeType: mimeType
                )
                uploadTasks.append(uploadTask)
            }
        }
        
        // Process GPXTracks
        for gpxTrack in gpxTracksToUpload {
            if let localFileURL = getLocalFileURL(for: gpxTrack) {
                let fileExtension = localFileURL.pathExtension
                let objectName = fileManager.generateObjectName(entityType: "GPXTrack", fileExtension: fileExtension)
                let mimeType = fileManager.mimeType(for: fileExtension)
                
                let uploadRequest = JourniaryAPI.UploadRequest(
                    entityId: gpxTrack.id?.uuidString ?? UUID().uuidString,
                    entityType: "GPXTrack", 
                    objectName: objectName,
                    mimeType: mimeType
                )
                uploadRequests.append(uploadRequest)
                
                let uploadTask = FileUploadTask(
                    entityId: gpxTrack.id?.uuidString ?? UUID().uuidString,
                    entityType: "GPXTrack",
                    fileURL: localFileURL,
                    uploadURL: "", // Will be filled after getting presigned URLs
                    objectName: objectName,
                    mimeType: mimeType
                )
                uploadTasks.append(uploadTask)
            }
        }
        
        if uploadRequests.isEmpty {
            print("No files to upload.")
            return
        }
        
        // Get presigned upload URLs
        let uploadResponse = try await networkProvider.generateBatchUploadUrls(uploadRequests: uploadRequests)
        
        // Match upload tasks with their URLs
        var completedTasks: [FileUploadTask] = []
        for uploadUrl in uploadResponse.uploadUrls {
            if let taskIndex = uploadTasks.firstIndex(where: { $0.entityId == uploadUrl.entityId && $0.entityType == uploadUrl.entityType }) {
                var task = uploadTasks[taskIndex]
                task = FileUploadTask(
                    entityId: task.entityId,
                    entityType: task.entityType,
                    fileURL: task.fileURL,
                    uploadURL: uploadUrl.uploadUrl,
                    objectName: task.objectName,
                    mimeType: task.mimeType
                )
                completedTasks.append(task)
            }
        }
        
        // Upload files to MinIO
        let uploadResults = try await fileManager.uploadFilesBatch(uploadTasks: completedTasks)
        
        // Mark successful uploads as complete
        for result in uploadResults {
            if result.success {
                let success = try await networkProvider.markFileUploadComplete(
                    entityId: result.task.entityId,
                    entityType: result.task.entityType,
                    objectName: result.task.objectName
                )
                if success {
                    print("✅ Marked upload complete for \(result.task.entityType) \(result.task.entityId)")
                } else {
                    print("❌ Failed to mark upload complete for \(result.task.entityType) \(result.task.entityId)")
                }
            } else {
                print("❌ Upload failed for \(result.task.entityType) \(result.task.entityId): \(result.error?.localizedDescription ?? "Unknown error")")
            }
        }
        
        print("File upload phase completed.")
    }
    
    /// Downloads files that are missing locally.
    private func downloadMissingFiles() async throws {
        print("Downloading missing files...")
        
        let context = persistenceController.container.newBackgroundContext()
        let fileManager = MediaFileManager.shared
        
        // Find MediaItems and GPXTracks that need file download
        let mediaItemsToDownload = try await findMediaItemsNeedingDownload(context: context)
        let gpxTracksToDownload = try await findGPXTracksNeedingDownload(context: context)
        
        // Prepare download requests
        let mediaItemIds = mediaItemsToDownload.compactMap { $0.id?.uuidString }
        let gpxTrackIds = gpxTracksToDownload.compactMap { $0.id?.uuidString }
        
        if mediaItemIds.isEmpty && gpxTrackIds.isEmpty {
            print("No files to download.")
            return
        }
        
        // Get presigned download URLs
        let downloadResponse = try await networkProvider.generateBatchDownloadUrls(
            mediaItemIds: mediaItemIds.isEmpty ? nil : mediaItemIds,
            gpxTrackIds: gpxTrackIds.isEmpty ? nil : gpxTrackIds
        )
        
        // Prepare download tasks
        var downloadTasks: [FileDownloadTask] = []
        for downloadUrl in downloadResponse.downloadUrls {
            let destinationURL = fileManager.localFileURL(for: downloadUrl.objectName, entityType: downloadUrl.entityType)
            
            let downloadTask = FileDownloadTask(
                entityId: downloadUrl.entityId,
                entityType: downloadUrl.entityType,
                downloadURL: downloadUrl.downloadUrl,
                destinationURL: destinationURL,
                objectName: downloadUrl.objectName
            )
            downloadTasks.append(downloadTask)
        }
        
        // Download files from MinIO
        let downloadResults = try await fileManager.downloadFilesBatch(downloadTasks: downloadTasks)
        
        // Log results
        for result in downloadResults {
            if result.success {
                print("✅ Downloaded \(result.task.entityType) \(result.task.entityId)")
            } else {
                print("❌ Download failed for \(result.task.entityType) \(result.task.entityId): \(result.error?.localizedDescription ?? "Unknown error")")
            }
        }
        
        print("File download phase completed.")
    }
    
    // MARK: - Helper Methods for File Synchronization
    
    /// Finds MediaItems that need file upload.
    private func findMediaItemsNeedingUpload(context: NSManagedObjectContext) async throws -> [MediaItem] {
        return try await context.perform {
            let fetchRequest: NSFetchRequest<MediaItem> = MediaItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "syncStatus == %@ AND filename != nil AND serverID == nil", String(SyncStatus.needsUpload.rawValue)) // 1 = needsUpload
            return try context.fetch(fetchRequest)
        }
    }
    
    /// Finds GPXTracks that need file upload.
    private func findGPXTracksNeedingUpload(context: NSManagedObjectContext) async throws -> [GPXTrack] {
        return try await context.perform {
            let fetchRequest: NSFetchRequest<GPXTrack> = GPXTrack.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "syncStatus == %@ AND localFileURL != nil AND serverID == nil", String(SyncStatus.needsUpload.rawValue)) // 1 = needsUpload
            return try context.fetch(fetchRequest)
        }
    }
    
    /// Finds MediaItems that need file download.
    private func findMediaItemsNeedingDownload(context: NSManagedObjectContext) async throws -> [MediaItem] {
        return try await context.perform {
            let fetchRequest: NSFetchRequest<MediaItem> = MediaItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "serverID != nil AND filename != nil AND localFileURL == nil")
            return try context.fetch(fetchRequest)
        }
    }
    
    /// Finds GPXTracks that need file download.
    private func findGPXTracksNeedingDownload(context: NSManagedObjectContext) async throws -> [GPXTrack] {
        return try await context.perform {
            let fetchRequest: NSFetchRequest<GPXTrack> = GPXTrack.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "serverID != nil AND originalFilename != nil AND localFileURL == nil")
            return try context.fetch(fetchRequest)
        }
    }
    
    /// Gets the local file URL for a MediaItem.
    private func getLocalFileURL(for mediaItem: MediaItem) -> URL? {
        guard let localFileURL = mediaItem.localFileURL else { return nil }
        return URL(string: localFileURL)
    }
    
    /// Gets the local file URL for a GPXTrack.
    private func getLocalFileURL(for gpxTrack: GPXTrack) -> URL? {
        guard let localFileURL = gpxTrack.localFileURL else { return nil }
        return URL(string: localFileURL)
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

// MARK: - Missing Upload Methods for MediaItem and GPXTrack

extension SyncManager {
    /// Upload method for MediaItems with string-based sync status
    private func uploadStringBasedEntitiesForMediaItem(
        fetchRequest: NSFetchRequest<MediaItem>,
        context: NSManagedObjectContext
    ) async throws {
        
        let objectsToUpload = try await context.perform { () -> [MediaItem] in
            fetchRequest.predicate = NSPredicate(format: "syncStatus == %@", String(SyncStatus.needsUpload.rawValue))
            return try context.fetch(fetchRequest)
        }

        for object in objectsToUpload {
            let input = object.toGraphQLInput()
            do {
                let result = try await networkProvider.createMediaItem(input: input as! MediaItemInput)
                print("Created MediaItem: \(result.id)")

                // Update local object with server data after successful upload
                try await context.perform {
                    object.serverId = result.id
                    object.setValue(self.dateTimeToDate(result.updatedAt), forKey: "updatedAt")
                    object.syncStatusEnum = .inSync
                }
            } catch {
                print("Failed to upload MediaItem with local ID \(object.objectID): \(error)")
            }
        }
    }
    
    /// Upload method for GPXTracks with string-based sync status
    private func uploadStringBasedEntitiesForGPX(
        fetchRequest: NSFetchRequest<GPXTrack>,
        context: NSManagedObjectContext
    ) async throws {
        
        let objectsToUpload = try await context.perform { () -> [GPXTrack] in
            fetchRequest.predicate = NSPredicate(format: "syncStatus == %@", String(SyncStatus.needsUpload.rawValue))
            return try context.fetch(fetchRequest)
        }

        for object in objectsToUpload {
            let input = object.toGraphQLInput()
            do {
                let result = try await networkProvider.createGPXTrack(input: input as! GPXTrackInput)
                print("Created GPXTrack: \(result.id)")

                // Update local object with server data after successful upload
                try await context.perform {
                    object.serverId = result.id
                    object.setValue(self.dateTimeToDate(result.updatedAt), forKey: "updatedAt")
                    object.syncStatusEnum = .inSync
                }
            } catch {
                print("Failed to upload GPXTrack with local ID \(object.objectID): \(error)")
            }
        }
    }
}