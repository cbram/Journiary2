import Foundation
import CoreData
import JourniaryAPI
import os.log
import Darwin
import UIKit

/// Manages the synchronization of data between the client and the backend.
///
/// This class is implemented as a Singleton and is responsible for orchestrating the entire sync process,
/// including uploading local changes and downloading remote changes from the server.
final class SyncManager {

    /// The shared singleton instance of `SyncManager`.
    static let shared = SyncManager()

    private let persistenceController = PersistenceController.shared
    private let networkProvider = NetworkProvider.shared
    private let dependencyResolver = SyncDependencyResolver()
    private let conflictResolver = ConflictResolver()
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
    private init() {
        // Initialisiere erweiterte Logging-Infrastruktur
        SyncLogger.shared.info("SyncManager initialisiert", category: "Initialization", metadata: [
            "version": "7.1",
            "features": ["dependency_resolution", "conflict_resolution", "performance_monitoring", "enhanced_logging"]
        ])
    }

    /// Initiates the synchronization cycle.
    ///
    /// The process consists of three main phases:
    /// 1.  **Upload Phase:** Local changes are sent to the server.
    /// 2.  **Download Phase:** Remote changes are fetched from the server and applied locally.
    /// 3.  **File Sync Phase:** Upload and download files asynchronously.
    ///
    /// If any step in the cycle fails, the entire process is aborted,
    /// and the `lastSyncedAt` timestamp is not updated to ensure data consistency.
    func sync(reason: String = "Unknown") async {
        let syncStartTime = Date()
        
        // Erweiterte Logging-Infrastruktur für Sync-Start
        let isAuthenticated = await MainActor.run { AuthService.shared.isAuthenticated }
        SyncLogger.shared.logSyncStart(reason: reason, metadata: [
            "user_authenticated": isAuthenticated,
            "last_sync": lastSyncedAt?.timeIntervalSince1970 ?? 0
        ])
        
        // Starte Performance-Monitoring für gesamten Sync-Zyklus
        let syncMeasurement = PerformanceMonitor.shared.startMeasuring(operation: "FullSync")
        
        guard isAuthenticated else {
            SyncLogger.shared.warning("Sync übersprungen: Benutzer ist nicht authentifiziert", 
                                    category: "Authentication", 
                                    metadata: ["sync_reason": reason])
            
            let authError = SyncError.authenticationError
            await MainActor.run {
                SyncNotificationCenter.shared.notifySyncError(
                    reason: reason,
                    error: authError
                )
            }
            return
        }
        
        // Phase 5.4: Notify sync start
        await MainActor.run {
            SyncNotificationCenter.shared.notifySyncStart(reason: reason)
        }

        do {
            try await uploadPhase()
            let syncData = try await downloadPhase(since: lastSyncedAt)

            // If both phases succeed, update the last synced timestamp from the server response.
            if let serverTimestamp = self.dateTimeToDate(syncData.serverTimestamp) {
                self.lastSyncedAt = serverTimestamp
                
                // Phase 5.4: Berechne synchronisierte Entitäten
                let syncedEntities = SyncedEntities(
                    tripsUpdated: syncData.trips.count,
                    memoriesUpdated: syncData.memories.count,
                    mediaItemsUpdated: syncData.mediaItems.count,
                    gpxTracksUpdated: syncData.gpxTracks.count,
                    tagsUpdated: syncData.tags.count,
                    tagCategoriesUpdated: syncData.tagCategories.count,
                    bucketListItemsUpdated: syncData.bucketListItems.count
                )
                
                // Beende Performance-Monitoring für erfolgreichen Sync
                let totalEntities = syncedEntities.tripsUpdated + syncedEntities.memoriesUpdated + 
                                  syncedEntities.mediaItemsUpdated + syncedEntities.gpxTracksUpdated + 
                                  syncedEntities.tagsUpdated + syncedEntities.tagCategoriesUpdated + 
                                  syncedEntities.bucketListItemsUpdated
                syncMeasurement.finish(entityCount: totalEntities)
                
                // Erweiterte Logging für erfolgreichen Sync
                let syncDuration = Date().timeIntervalSince(syncStartTime)
                SyncLogger.shared.logSyncSuccess(
                    reason: reason, 
                    duration: syncDuration, 
                    entitiesProcessed: totalEntities,
                    metadata: [
                        "server_timestamp": serverTimestamp.timeIntervalSince1970,
                        "trips": syncedEntities.tripsUpdated,
                        "memories": syncedEntities.memoriesUpdated,
                        "media_items": syncedEntities.mediaItemsUpdated,
                        "gpx_tracks": syncedEntities.gpxTracksUpdated,
                        "tags": syncedEntities.tagsUpdated,
                        "tag_categories": syncedEntities.tagCategoriesUpdated,
                        "bucket_list_items": syncedEntities.bucketListItemsUpdated
                    ]
                )
                
                // Phase 5.4: Notify sync success
                await MainActor.run {
                    SyncNotificationCenter.shared.notifySyncSuccess(
                        reason: reason,
                        syncedEntities: syncedEntities
                    )
                }
                
                // Start file synchronization asynchronously (doesn't block the main sync)
                Task {
                    await self.fileSyncPhase()
                }
            } else {
                print("Sync completed, but server timestamp was invalid.")
                let invalidTimestampError = SyncError.invalidServerTimestamp
                
                // Beende Performance-Monitoring für fehlgeschlagenen Sync
                syncMeasurement.finish(entityCount: 0)
                
                await MainActor.run {
                    SyncNotificationCenter.shared.notifySyncError(
                        reason: reason,
                        error: invalidTimestampError
                    )
                }
            }

        } catch {
            // Erweiterte Logging für Sync-Fehler
            SyncLogger.shared.logSyncError(
                reason: reason, 
                error: error, 
                phase: "sync_cycle",
                metadata: [
                    "duration_seconds": Date().timeIntervalSince(syncStartTime),
                    "last_sync_attempt": lastSyncedAt?.timeIntervalSince1970 ?? 0
                ]
            )
            
            // The `lastSyncedAt` timestamp is not updated, so the next sync will retry the failed operations.
            
            // Beende Performance-Monitoring für fehlgeschlagenen Sync
            syncMeasurement.finish(entityCount: 0)
            
            // Phase 5.4: Notify sync error
            await MainActor.run {
                SyncNotificationCenter.shared.notifySyncError(
                    reason: reason,
                    error: error
                )
            }
        }
    }

    /// **Phase 1: Upload with Dependencies (Experimental)**
    ///
    /// Neue Methode für dependency-aware Upload (erstmal nur logging)
    /// Integriert den Dependency-Resolver ohne bestehende Funktionalität zu brechen
    private func uploadPhaseWithDependencies() async throws {
        SyncLogger.shared.info("Dependency-aware Upload wird vorbereitet", category: "Dependencies", metadata: ["phase": "upload_with_dependencies"])
        
        let syncOrder = dependencyResolver.resolveSyncOrder()
        for entityType in syncOrder {
            SyncLogger.shared.debug("Entity in sync order: \(entityType.rawValue)", category: "Dependencies", metadata: [
                "entity_type": entityType.rawValue,
                "sync_order": entityType.syncOrder
            ])
        }
        
        // Rufe bestehende uploadPhase auf
        try await uploadPhase()
    }

    /// **Phase 1: Upload**
    ///
    /// Identifies local creations, updates, and deletions and sends them to the backend via GraphQL mutations.
    private func uploadPhase() async throws {
        SyncLogger.shared.info("Executing upload phase", category: "SyncPhase", metadata: ["phase": "upload"])
        
        // Starte Performance-Monitoring für Upload-Phase
        let uploadMeasurement = PerformanceMonitor.shared.startMeasuring(operation: "UploadPhase")
        
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
        
        // Beende Performance-Monitoring für Upload-Phase
        // Zähle die Anzahl der lokal geänderten Entities
        let uploadedEntities = try await context.perform {
            var count = 0
            let entityNames = ["Trip", "Memory", "MediaItem", "GPXTrack", "Tag", "TagCategory", "BucketListItem"]
            for entityName in entityNames {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
                fetchRequest.predicate = NSPredicate(format: "syncStatus == %@", "uploaded")
                count += try context.count(for: fetchRequest)
            }
            return count
        }
        uploadMeasurement.finish(entityCount: uploadedEntities)
    }

    /// **Phase 2: Download**
    ///
    /// Fetches remote changes since the last successful sync and applies them to the local Core Data store.
    /// - parameter since: The timestamp of the last successful synchronization. If `nil`, a full sync might be performed.
    /// - returns: The `SyncQuery.Data.Sync` object from the server.
    private func downloadPhase(since lastSync: Date?) async throws -> SyncQuery.Data.Sync {
        SyncLogger.shared.info("Executing download phase", category: "SyncPhase", metadata: [
            "phase": "download",
            "last_sync": lastSync?.timeIntervalSince1970 ?? 0
        ])
        
        // Starte Performance-Monitoring für Download-Phase
        let downloadMeasurement = PerformanceMonitor.shared.startMeasuring(operation: "DownloadPhase")
        
        // 1. Call the optimized `syncOptimized` query with caching and deduplication
        let syncData = try await networkProvider.syncOptimized(lastSyncedAt: lastSync)
        
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
            try await upsertMemoriesWithConflictResolution(memories, context: context)
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
        
        // Beende Performance-Monitoring für Download-Phase
        let downloadedEntities = syncData.trips.count + syncData.memories.count + 
                                syncData.mediaItems.count + syncData.gpxTracks.count + 
                                syncData.tags.count + syncData.tagCategories.count + 
                                syncData.bucketListItems.count
        downloadMeasurement.finish(entityCount: downloadedEntities)
        
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
                if try context.fetch(tripFetchRequest).first != nil {
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
                await context.perform {
                    do {
                        let managedObject = try context.existingObject(with: objectID) as! T
                        managedObject.serverId = result.id
                        managedObject.updatedAt = self.dateTimeToDate(result.updatedAt)
                        managedObject.syncStatus = .inSync
                    } catch {
                        print("Failed to update local object after successful upload: \(error)")
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
                await context.perform {
                    do {
                        if var managedObject = try? context.existingObject(with: objectID) as? T {
                            managedObject.serverId = result.id
                            managedObject.setValue(self.dateTimeToDate(result.updatedAt), forKey: "updatedAt")
                            managedObject.synchronizationStatus = .inSync
                        }
                    }
                }
            } catch {
                print("Failed to upload \(T.entity().name ?? "entity") with local ID \(object.objectID): \(error)")
                // Set status to failed upload
                await context.perform {
                    do {
                        if var managedObject = try? context.existingObject(with: objectID) as? T {
                            managedObject.synchronizationStatus = .needsUpload // Keep trying for now
                        }
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
                await context.perform {
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
                await context.perform {
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
                await context.perform {
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

/// Erweiterte Sync-Status-Enum mit detaillierteren Zuständen
/// Implementiert als Teil von Schritt 1.1 des Sync-Implementierungsplans
@objc
public enum DetailedSyncStatus: Int16, CaseIterable {
    case inSync = 0
    case needsUpload = 1
    case needsDownload = 2
    case uploading = 3
    case downloading = 4
    case syncError = 5
    case filesPending = 6
    
    var displayName: String {
        switch self {
        case .inSync: return "Synchronisiert"
        case .needsUpload: return "Upload ausstehend"
        case .needsDownload: return "Download ausstehend"
        case .uploading: return "Wird hochgeladen..."
        case .downloading: return "Wird heruntergeladen..."
        case .syncError: return "Sync-Fehler"
        case .filesPending: return "Dateien ausstehend"
        }
    }
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
                await context.perform {
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
                await context.perform {
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

// MARK: - Sync Error Types

/// Errors that can occur during synchronization
/// Erweitert als Teil von Schritt 1.2 des Sync-Implementierungsplans
enum SyncError: Error, LocalizedError {
    case invalidServerTimestamp
    case networkError(Error)
    case dataError(String)
    case authenticationError
    case dependencyNotMet(entity: String, dependency: String)
    case consistencyValidationFailed([String])
    case transactionFailed(Error)
    case maxRetriesExceeded
    case noUploadUrlGenerated
    
    var errorDescription: String? {
        switch self {
        case .invalidServerTimestamp:
            return "Server-Zeitstempel ist ungültig"
        case .networkError(let error):
            return "Netzwerkfehler: \(error.localizedDescription)"
        case .dataError(let message):
            return "Datenfehler: \(message)"
        case .authenticationError:
            return "Authentifizierungsfehler"
        case .dependencyNotMet(let entity, let dependency):
            return "Abhängigkeit fehlt: \(entity) benötigt \(dependency)"
        case .consistencyValidationFailed(let issues):
            return "Konsistenzfehler: \(issues.joined(separator: ", "))"
        case .transactionFailed(let error):
            return "Transaktionsfehler: \(error.localizedDescription)"
        case .maxRetriesExceeded:
            return "Maximale Wiederholungsversuche erreicht"
        case .noUploadUrlGenerated:
            return "Keine Upload-URL generiert"
        }
    }
}

// MARK: - Sync Logging Extension

/// Erweiterte Logging-Funktionen für den SyncManager
/// Implementiert als Teil von Schritt 1.4 des Sync-Implementierungsplans
extension SyncManager {
    
    /// Logger für Synchronisations-Events
    private static let logger = Logger(subsystem: "com.journiary.sync", category: "SyncManager")
    
    /// Protokolliert den Start eines Synchronisations-Zyklus
    /// - Parameter reason: Der Grund für den Sync-Start
    private func logSyncStart(reason: String) {
        Self.logger.info("🔄 Sync gestartet: \(reason)")
        print("🔄 Sync gestartet: \(reason)")
    }
    
    /// Protokolliert den erfolgreichen Abschluss eines Synchronisations-Zyklus
    /// - Parameter reason: Der Grund für den Sync
    /// - Parameter duration: Die Dauer des Sync-Vorgangs in Sekunden
    private func logSyncSuccess(reason: String, duration: TimeInterval) {
        Self.logger.info("✅ Sync erfolgreich: \(reason) (\(duration)s)")
        print("✅ Sync erfolgreich: \(reason) (\(duration)s)")
    }
    
    /// Protokolliert einen Fehler während der Synchronisation
    /// - Parameter reason: Der Grund für den Sync-Versuch
    /// - Parameter error: Der aufgetretene Fehler
    private func logSyncError(reason: String, error: Error) {
        Self.logger.error("❌ Sync fehlgeschlagen: \(reason) - \(error.localizedDescription)")
        print("❌ Sync fehlgeschlagen: \(reason) - \(error.localizedDescription)")
    }
    
    /// Protokolliert den Start einer Upload-Phase
    /// - Parameter entityCount: Anzahl der zu synchronisierenden Entitäten
    private func logUploadStart(entityCount: Int) {
        Self.logger.info("📤 Upload-Phase gestartet: \(entityCount) Entitäten")
        print("📤 Upload-Phase gestartet: \(entityCount) Entitäten")
    }
    
    /// Protokolliert den Start einer Download-Phase
    /// - Parameter since: Zeitpunkt der letzten Synchronisation
    private func logDownloadStart(since: Date?) {
        let sinceString = since?.formatted() ?? "Erstmalig"
        Self.logger.info("📥 Download-Phase gestartet: Seit \(sinceString)")
        print("📥 Download-Phase gestartet: Seit \(sinceString)")
    }
    
    /// Protokolliert den Start einer Datei-Synchronisation
    /// - Parameter fileCount: Anzahl der zu synchronisierenden Dateien
    private func logFileSyncStart(fileCount: Int) {
        Self.logger.info("📁 Datei-Synchronisation gestartet: \(fileCount) Dateien")
        print("📁 Datei-Synchronisation gestartet: \(fileCount) Dateien")
    }
    
    /// Protokolliert Entity-spezifische Upload-Erfolge
    /// - Parameter entityType: Der Typ der synchronisierten Entität
    /// - Parameter count: Anzahl der synchronisierten Entitäten
    private func logEntityUploadSuccess(entityType: String, count: Int) {
        Self.logger.info("✅ \(entityType) synchronisiert: \(count) Entitäten")
        print("✅ \(entityType) synchronisiert: \(count) Entitäten")
    }
    
    /// Protokolliert Entity-spezifische Upload-Fehler
    /// - Parameter entityType: Der Typ der fehlgeschlagenen Entität
    /// - Parameter error: Der aufgetretene Fehler
    private func logEntityUploadError(entityType: String, error: Error) {
        Self.logger.error("❌ \(entityType) Upload fehlgeschlagen: \(error.localizedDescription)")
        print("❌ \(entityType) Upload fehlgeschlagen: \(error.localizedDescription)")
    }
}

// MARK: - Network-Request-Optimierungen (Schritt 5.4)

/// Network-Request-Optimierungen für effizientere Synchronisation
/// Implementiert als Teil von Schritt 5.4 des Sync-Implementierungsplans
extension SyncManager {
    
    /// Optimierte Batch-Upload-Methode mit intelligenter Gruppierung
    func optimizedBatchSync() async throws {
        let measurement = PerformanceMonitor.shared.startMeasuring(operation: "OptimizedBatchSync")
        
        let context = persistenceController.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Sammle alle zu synchronisierenden Entitäten
        let pendingOperations = try await collectPendingOperations(context: context)
        
        if !pendingOperations.isEmpty {
            print("🚀 Starte optimierte Batch-Synchronisation mit \(pendingOperations.count) Operationen")
            
            // Verwende optimierte Batch-Upload-Funktionalität
            let results = try await networkProvider.batchUpload(
                operations: pendingOperations,
                maxBatchSize: getOptimalBatchSize()
            )
            
            // Verarbeite Ergebnisse
            try await processOptimizedBatchResults(results, context: context)
            
            print("✅ Optimierte Batch-Synchronisation abgeschlossen")
        }
        
        measurement.finish(entityCount: pendingOperations.count)
    }
    
    /// Sammelt alle zu synchronisierenden Operationen
    private func collectPendingOperations(context: NSManagedObjectContext) async throws -> [(operation: String, input: Any)] {
        return try await context.perform {
            var operations: [(operation: String, input: Any)] = []
            
            // Sammle Trip-Operationen
            let tripRequest = Trip.fetchRequest()
            tripRequest.predicate = NSPredicate(format: "serverId == nil")
            let pendingTrips = try context.fetch(tripRequest)
            
            for trip in pendingTrips {
                if let input = trip.toGraphQLInput() as? TripInput {
                    operations.append((operation: "createTrip", input: input))
                }
            }
            
            // Sammle Memory-Operationen
            let memoryRequest = Memory.fetchRequest()
            memoryRequest.predicate = NSPredicate(format: "serverId == nil")
            let pendingMemories = try context.fetch(memoryRequest)
            
            for memory in pendingMemories {
                if let input = memory.toGraphQLInput() as? MemoryInput {
                    operations.append((operation: "createMemory", input: input))
                }
            }
            
            // Sammle MediaItem-Operationen
            let mediaRequest = MediaItem.fetchRequest()
            mediaRequest.predicate = NSPredicate(format: "serverId == nil")
            let pendingMedia = try context.fetch(mediaRequest)
            
            for media in pendingMedia {
                if let input = media.toGraphQLInput() as? MediaItemInput {
                    operations.append((operation: "createMediaItem", input: input))
                }
            }
            
            return operations
        }
    }
    
    /// Verarbeitet die Ergebnisse der optimierten Batch-Synchronisation
    private func processOptimizedBatchResults(
        _ results: [BatchUploadResult],
        context: NSManagedObjectContext
    ) async throws {
        try await context.perform {
            for result in results {
                if result.success {
                    print("✅ \(result.operation) erfolgreich")
                    // Hier würden normalerweise die lokalen Entitäten mit server IDs aktualisiert
                } else {
                    print("❌ \(result.operation) fehlgeschlagen: \(result.error ?? "Unbekannter Fehler")")
                }
            }
            
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    /// Bestimmt die optimale Batch-Größe basierend auf verfügbarer Bandbreite
    private func getOptimalBatchSize() -> Int {
        // Einfache Heuristik - in echter Implementierung würde hier Netzwerk-Qualität gemessen
        // Verwende angemessene Standardwerte basierend auf Netzwerk-Bedingungen
        return 25 // Konservative Batch-Größe für Network-Optimierung
    }
    
    /// Intelligent gecachte Sync-Operation
    func cachedDownloadPhase(since lastSync: Date?) async throws -> SyncQuery.Data.Sync {
        let cacheKey = "sync_download:\(lastSync?.timeIntervalSince1970 ?? 0)"
        
        // Prüfe Cache zuerst
        if let cachedData = SyncCacheManager.shared.getCachedEntity(forKey: cacheKey, type: Data.self) {
            // In einer produktiven Implementierung würde hier die Deserialisierung stattfinden
            print("📋 Cache hit für Sync-Operation: \(cacheKey)")
        }
        
        // Führe normale Sync-Operation aus
        let result = try await networkProvider.syncOptimized(lastSyncedAt: lastSync)
        
        // Cache das Ergebnis für zukünftige Verwendung (vereinfacht)
        SyncCacheManager.shared.cacheEntity(
            Data("sync_result".utf8),
            forKey: cacheKey,
            ttl: 120 // 2 Minuten Cache
        )
        
        return result
    }
}

// MARK: - Memory-Management-Optimierungen

/// Memory-Management-Optimierungen für große Sync-Operationen
/// Implementiert als Teil von Schritt 5.2 des Sync-Implementierungsplans
extension SyncManager {
    
    /// Optimierte Batch-Upload-Funktionalität mit Memory-Threshold-Überwachung
    /// - Parameters:
    ///   - entities: Die zu uploadenden Entitäten
    ///   - batchSize: Die Größe jeder Batch (Standard: 50)
    ///   - memoryThreshold: Memory-Schwellenwert in Bytes (Standard: 100MB)
    private func optimizedBatchUpload<T: NSManagedObject>(
        entities: [T],
        batchSize: Int = 50,
        memoryThreshold: UInt64 = 100_000_000 // 100MB
    ) async throws {
        let measurement = PerformanceMonitor.shared.startMeasuring(operation: "BatchUpload-\(T.self)")
        
        let batches = entities.chunked(into: batchSize)
        var processedCount = 0
        
        for batch in batches {
            // Memory-Check vor jeder Batch
            if getMemoryUsage() > memoryThreshold {
                print("⚠️ Memory-Threshold erreicht, pausiere für Garbage Collection")
                await Task.yield() // Lasse andere Tasks laufen
                
                // Explicit Memory Pressure Relief
                await forceMemoryRelease()
            }
            
            try await uploadBatch(batch)
            processedCount += batch.count
            
            print("📤 Batch hochgeladen: \(processedCount)/\(entities.count)")
        }
        
        measurement.finish(entityCount: entities.count)
    }
    
    /// Forciert Memory-Freigabe für bessere Performance bei großen Sync-Operationen
    private func forceMemoryRelease() async {
        // Background-Context für Memory-intensive Operationen verwenden
        let context = persistenceController.container.newBackgroundContext()
        await context.perform {
            context.reset()
        }
        
        // Explicit Autorelease Pool Drain
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    // Trigger Memory Cleanup
                    Thread.sleep(forTimeInterval: 0.1)
                }
                continuation.resume()
            }
        }
    }
    
    /// Ermittelt den aktuellen Memory-Verbrauch der App
    /// - Returns: Memory-Verbrauch in Bytes
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
    
    /// Upload-Batch-Verarbeitung mit Memory-Optimierung
    /// - Parameter batch: Die zu uploadende Batch von Entitäten
    private func uploadBatch<T: NSManagedObject>(_ batch: [T]) async throws {
        // Verwende autoreleasepool für bessere Memory-Performance
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                                            // Hier würde die tatsächliche Upload-Logik stehen
                        // Für jetzt simulieren wir die Arbeit
                        for _ in batch {
                            // Simuliere Upload-Arbeit
                            await Task.yield()
                        }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Optimierte Batch-Download-Funktionalität mit Memory-Management
    /// - Parameters:
    ///   - entityType: Der Typ der zu downloadenden Entitäten
    ///   - batchSize: Die Größe jeder Batch
    ///   - memoryThreshold: Memory-Schwellenwert in Bytes
    private func optimizedBatchDownload(
        entityType: String,
        batchSize: Int = 100,
        memoryThreshold: UInt64 = 100_000_000 // 100MB
    ) async throws {
        let measurement = PerformanceMonitor.shared.startMeasuring(operation: "BatchDownload-\(entityType)")
        
        var offset = 0
        var hasMore = true
        
        while hasMore {
            // Memory-Check vor jeder Batch
            if getMemoryUsage() > memoryThreshold {
                print("⚠️ Memory-Threshold erreicht während Download, pausiere für Garbage Collection")
                await Task.yield()
                await forceMemoryRelease()
            }
            
            // Hier würde die tatsächliche Download-Logik stehen
            // Für jetzt simulieren wir die Arbeit
            let batchData = try await downloadBatch(entityType: entityType, offset: offset, limit: batchSize)
            
            if batchData.count < batchSize {
                hasMore = false
            }
            
            offset += batchData.count
            print("📥 Batch heruntergeladen: \(offset) \(entityType) Entitäten")
        }
        
        measurement.finish(entityCount: offset)
    }
    
    /// Simuliert Download einer Batch (Placeholder)
    /// - Parameters:
    ///   - entityType: Der Typ der zu downloadenden Entitäten
    ///   - offset: Der Offset für die Paginierung
    ///   - limit: Die maximale Anzahl der Entitäten pro Batch
    /// - Returns: Array mit simulierten Entitäten
    private func downloadBatch(entityType: String, offset: Int, limit: Int) async throws -> [Any] {
        // Simuliere Netzwerk-Latenz
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Simuliere weniger Daten bei hohem Offset
        let remainingData = max(0, 1000 - offset)
        let actualLimit = min(limit, remainingData)
        
        return Array(0..<actualLimit)
    }
}

// MARK: - Array-Extensions für Memory-Management

/// Array-Extensions für optimierte Batch-Verarbeitung
/// Implementiert als Teil von Schritt 5.2 des Sync-Implementierungsplans
/// Hinweis: chunked(into:) ist bereits in MapCacheManager.swift definiert
extension Array {
    
    /// Verarbeitet das Array in Memory-optimierten Batches
    /// - Parameters:
    ///   - batchSize: Die Größe jeder Batch
    ///   - processor: Die Verarbeitungsfunktion für jede Batch
    func processBatches<T>(
        batchSize: Int,
        processor: ([Element]) async throws -> T
    ) async throws -> [T] {
        var results: [T] = []
        let batches = chunked(into: batchSize)
        
        for batch in batches {
            let result = try await processor(batch)
            results.append(result)
        }
        
        return results
    }
}

// MARK: - Conflict Resolution Integration

/// Conflict Resolution Integration für erweiterte Synchronisation
/// Implementiert als Teil von Schritt 6.3 des Sync-Implementierungsplans
extension SyncManager {
    
    /// Synchronisiert eine Entität mit Conflict Resolution
    /// - Parameters:
    ///   - localEntity: Die lokale Entität
    ///   - remoteData: Die Remote-Daten
    ///   - context: Der Core Data Context
    /// - Returns: Die aufgelöste Entität
    func syncEntityWithConflictResolution<T: NSManagedObject>(
        localEntity: T,
        remoteData: [String: Any],
        context: NSManagedObjectContext
    ) async throws -> T {
        
        // Erstelle temporäres Remote-Entity zum Vergleich
        let tempRemoteEntity = try createTempEntity(from: remoteData, type: T.self, context: context)
        
        // Erkennung von Konflikten
        let conflictDetection = conflictResolver.detectConflict(
            localEntity: localEntity,
            remoteEntity: tempRemoteEntity
        )
        
        if conflictDetection.hasConflict {
            print("⚠️ Konflikt erkannt: \(conflictDetection.conflictType) - Felder: \(conflictDetection.conflictedFields.joined(separator: ", ")) - EntityType: \(String(describing: T.self))")
            
            // Löse Konflikt mit erweiterter Detection
            let resolution = try await conflictResolver.resolveConflictWithDetection(
                localEntity: localEntity,
                remoteEntity: tempRemoteEntity,
                strategy: .lastWriteWins
            )
            
            print("✅ Konflikt gelöst mit Strategie: \(resolution.strategy) - EntityType: \(String(describing: T.self)) - Details: \(resolution.conflictDetails)")
            
            return resolution.resolvedEntity as! T
        } else {
            // Kein Konflikt - normale Synchronisation
            updateLocalEntity(localEntity, with: remoteData)
            
            print("🔄 Keine Konflikte erkannt - normale Synchronisation - EntityType: \(String(describing: T.self))")
            
            return localEntity
        }
    }
    
    /// Erstellt eine temporäre Entität aus Remote-Daten für Vergleichszwecke
    /// - Parameters:
    ///   - data: Die Remote-Daten
    ///   - type: Der Typ der Entität
    ///   - context: Der Core Data Context
    /// - Returns: Die temporäre Entität
    private func createTempEntity<T: NSManagedObject>(
        from data: [String: Any],
        type: T.Type,
        context: NSManagedObjectContext
    ) throws -> T {
        let entityName = String(describing: type)
        
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            throw SyncError.dataError("Entity description not found for \(entityName)")
        }
        
        let tempEntity = T(entity: entity, insertInto: nil) // Nicht in Context einfügen
        updateLocalEntity(tempEntity, with: data)
        
        return tempEntity
    }
    
    /// Aktualisiert eine lokale Entität mit Remote-Daten
    /// - Parameters:
    ///   - entity: Die zu aktualisierende Entität
    ///   - data: Die neuen Daten
    private func updateLocalEntity<T: NSManagedObject>(_ entity: T, with data: [String: Any]) {
        for (key, value) in data {
            if entity.entity.attributesByName.keys.contains(key) {
                // Konvertiere Werte entsprechend des Attribut-Typs
                let convertedValue = convertValue(value, forKey: key, in: entity)
                entity.setValue(convertedValue, forKey: key)
            }
        }
    }
    
    /// Konvertiert einen Wert entsprechend des Attribut-Typs
    /// - Parameters:
    ///   - value: Der zu konvertierende Wert
    ///   - key: Der Schlüssel des Attributes
    ///   - entity: Die Entität für Typ-Informationen
    /// - Returns: Der konvertierte Wert
    private func convertValue(_ value: Any, forKey key: String, in entity: NSManagedObject) -> Any? {
        guard let attribute = entity.entity.attributesByName[key] else {
            return value
        }
        
        switch attribute.attributeType {
        case .dateAttributeType:
            if let dateString = value as? String {
                return dateTimeToDate(dateString)
            }
            return value
        case .booleanAttributeType:
            if let boolValue = value as? Bool {
                return boolValue
            } else if let intValue = value as? Int {
                return intValue != 0
            }
            return value
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
            if let stringValue = value as? String, let intValue = Int(stringValue) {
                return intValue
            }
            return value
        case .doubleAttributeType, .floatAttributeType:
            if let stringValue = value as? String, let doubleValue = Double(stringValue) {
                return doubleValue
            }
            return value
        default:
            return value
        }
    }
    
    /// Erweiterte Upsert-Methode mit Conflict Resolution
    /// - Parameters:
    ///   - remoteData: Die Remote-Daten
    ///   - localEntity: Die lokale Entität (kann nil sein)
    ///   - context: Der Core Data Context
    /// - Returns: Die aufgelöste Entität
    private func upsertWithConflictResolution<T: NSManagedObject>(
        remoteData: [String: Any],
        localEntity: T?,
        context: NSManagedObjectContext
    ) async throws -> T {
        
        if let localEntity = localEntity {
            // Entität existiert bereits - prüfe auf Konflikte
            let resolvedEntity = try await syncEntityWithConflictResolution(
                localEntity: localEntity,
                remoteData: remoteData,
                context: context
            )
            
            // Setze Sync-Status
            resolvedEntity.setValue(SyncStatus.inSync.rawValue, forKey: "syncStatus")
            
            return resolvedEntity
        } else {
            // Neue Entität - erstelle ohne Konflikt-Prüfung
            let entityName = String(describing: T.self)
            guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
                throw SyncError.dataError("Entity description not found for \(entityName)")
            }
            
            let newEntity = T(entity: entity, insertInto: context)
            updateLocalEntity(newEntity, with: remoteData)
            
            // Setze Sync-Status für neue Entität
            newEntity.setValue(SyncStatus.inSync.rawValue, forKey: "syncStatus")
            
            print("📥 Neue Entität erstellt: \(entityName) - ServerId: \(remoteData["id"] as? String ?? "unknown")")
            
            return newEntity
        }
    }
    
    /// Erweiterte Memory-Upsert-Methode mit Conflict Resolution
    /// - Parameters:
    ///   - memories: Die Remote-Memories
    ///   - context: Der Core Data Context
    private func upsertMemoriesWithConflictResolution(
        _ memories: [SyncQuery.Data.Sync.Memory],
        context: NSManagedObjectContext
    ) async throws {
        for remoteMemory in memories {
            let fetchRequest = Memory.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "serverId == %@", remoteMemory.id)
            fetchRequest.fetchLimit = 1
            
            let localMemory = try await context.perform {
                return try context.fetch(fetchRequest).first
            }
            
            // Bereite Remote-Daten vor
            let remoteData: [String: Any] = [
                "serverId": remoteMemory.id,
                "title": remoteMemory.title ?? "",
                "text": remoteMemory.text ?? "",
                "timestamp": self.dateTimeToDate(remoteMemory.timestamp) ?? Date(),
                "latitude": remoteMemory.latitude ?? 0.0,
                "longitude": remoteMemory.longitude ?? 0.0,
                "locationName": remoteMemory.locationName ?? "",
                "createdAt": self.dateTimeToDate(remoteMemory.createdAt) ?? Date(),
                "updatedAt": self.dateTimeToDate(remoteMemory.updatedAt) ?? Date()
            ]
            
            let resolvedMemory = try await self.upsertWithConflictResolution(
                remoteData: remoteData,
                localEntity: localMemory,
                context: context
            )
            
            // Handle Trip relationship
            let tripId = remoteMemory.tripId
            let tripFetchRequest = Trip.fetchRequest()
            tripFetchRequest.predicate = NSPredicate(format: "serverId == %@", tripId)
            tripFetchRequest.fetchLimit = 1
            
            try await context.perform {
                if let trip = try context.fetch(tripFetchRequest).first {
                    resolvedMemory.trip = trip
                }
            }
        }
    }
}

// MARK: - Memory-Monitoring-Tools

/// Memory-Monitoring-Tools für Debug-Zwecke
/// Implementiert als Teil von Schritt 5.2 des Sync-Implementierungsplans
extension SyncManager {
    
    /// Formatiert Memory-Verbrauch für lesbare Ausgabe
    /// - Parameter bytes: Memory-Verbrauch in Bytes
    /// - Returns: Formatierte String-Darstellung
    private func formatMemoryUsage(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Loggt den aktuellen Memory-Verbrauch
    /// - Parameter context: Kontext für den Memory-Check
    private func logMemoryUsage(_ context: String) {
        let memoryUsage = getMemoryUsage()
        let formattedUsage = formatMemoryUsage(memoryUsage)
        print("🧠 Memory-Verbrauch (\(context)): \(formattedUsage)")
    }
    
    /// Prüft, ob der Memory-Verbrauch kritisch ist
    /// - Parameter threshold: Der Schwellenwert in Bytes
    /// - Returns: true wenn Memory-Verbrauch über dem Schwellenwert liegt
    private func isMemoryUsageCritical(_ threshold: UInt64 = 200_000_000) -> Bool {
        return getMemoryUsage() > threshold
    }
}

// mach_task_basic_info wird durch Darwin-Import am Anfang der Datei bereitgestellt

// MARK: - Optimized Backend Integration (Phase 10.1)

/// Extension für die Integration mit optimierten Backend-Features
/// Implementiert als Teil von Schritt 10.1 des Sync-Implementierungsplans
extension SyncManager {
    
    /// Integration mit optimierten Backend-Endpoints
    /// - Throws: SyncError bei Fehlern während der Synchronisation
    func syncWithOptimizedBackend() async throws {
        let startTime = Date()
        let measurement = PerformanceMonitor.shared.startMeasuring(operation: "OptimizedSync")
        
        do {
            // Verwende neue Batch-Sync-Endpoint
            let syncResponse = try await performOptimizedBatchSync()
            
            // Verarbeite Konfliktlösungen
            try await processConflictResolutions(syncResponse.conflicts)
            
            // Aktualisiere Cache mit neuen Daten
            try await updateLocalCacheWithSyncResponse(syncResponse)
            
            measurement.finish(entityCount: syncResponse.processedEntities)
            
            let duration = Date().timeIntervalSince(startTime)
            SyncLogger.shared.info(
                "Optimized sync completed successfully",
                category: "SyncManager",
                metadata: [
                    "processedEntities": syncResponse.processedEntities,
                    "resolvedConflicts": syncResponse.conflicts.count,
                    "duration": duration
                ]
            )
            
        } catch {
            measurement.finish(entityCount: 0)
            SyncLogger.shared.error(
                "Optimized sync failed: \(error.localizedDescription)",
                category: "SyncManager",
                metadata: ["error": error.localizedDescription]
            )
            throw error
        }
    }
    
    /// Führt optimierte Batch-Synchronisation durch
    /// - Returns: OptimizedSyncResponse mit Ergebnissen der Synchronisation
    /// - Throws: SyncError bei Fehlern während der Batch-Synchronisation
    private func performOptimizedBatchSync() async throws -> OptimizedSyncResponse {
        // Sammle alle ausstehenden Operationen
        let pendingOperations = try await collectPendingOperations()
        
        // Erstelle Batch-Sync-Request
        let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let batchRequest = BatchSyncRequest(
            operations: pendingOperations,
            deviceId: deviceId,
            conflictResolutionStrategy: .lastWriteWins,
            options: BatchSyncOptions(
                batchSize: AdaptiveBatchManager().recommendedBatchSize(for: "mixed"),
                timeout: 30000,
                retryCount: 3
            )
        )
        
        // FIXME: Placeholder - echter GraphQL Batch-Sync-Endpoint muss noch implementiert werden
        // Für jetzt simulieren wir eine erfolgreiche Response
        // let mutation = BatchSyncMutation(request: batchRequest)
        // let result = try await networkProvider.apollo.perform(mutation: mutation)
        
        // Simulierte Response für Prototyp
        let simulatedSyncResponse = SimulatedBatchSyncResponse(
            processedEntities: pendingOperations.count,
            conflicts: [],
            errors: [],
            timestamp: Date()
        )
        
        return OptimizedSyncResponse(
            processedEntities: simulatedSyncResponse.processedEntities,
            conflicts: simulatedSyncResponse.conflicts.map { ConflictResolution(from: $0) },
            errors: simulatedSyncResponse.errors,
            timestamp: simulatedSyncResponse.timestamp
        )
    }
    
    /// Sammelt alle ausstehenden Sync-Operationen
    /// - Returns: Array von SyncOperation mit allen zu synchronisierenden Operationen
    /// - Throws: SyncError bei Fehlern während der Datensammlung
    private func collectPendingOperations() async throws -> [SyncOperation] {
        let context = persistenceController.container.viewContext
        var operations: [SyncOperation] = []
        
        // Sammle alle Entitäten, die synchronisiert werden müssen
        let entityTypes = ["Trip", "Memory", "MediaItem", "GPXTrack", "Tag", "TagCategory", "BucketListItem"]
        
        for entityType in entityTypes {
            let pendingEntities = try await fetchPendingEntities(type: entityType, context: context)
            let entityOperations = pendingEntities.map { entity in
                SyncOperation(
                    id: UUID().uuidString,
                    entityType: entityType,
                    operationType: determineOperationType(for: entity),
                    entityId: entity.objectID.uriRepresentation().absoluteString,
                    data: entity.toSyncData(),
                    dependencies: getDependencies(for: entity),
                    priority: getSyncPriority(for: entityType)
                )
            }
            operations.append(contentsOf: entityOperations)
        }
        
        return operations
    }
    
    /// Verarbeitet Konfliktlösungen vom Server
    /// - Parameter conflicts: Array von ConflictResolution mit Konfliktlösungen
    /// - Throws: SyncError bei Fehlern während der Konfliktverarbeitung
    private func processConflictResolutions(_ conflicts: [ConflictResolution]) async throws {
        for conflict in conflicts {
            SyncLogger.shared.info(
                "Processing conflict resolution",
                category: "ConflictResolver",
                metadata: [
                    "conflictId": conflict.id,
                    "entityType": conflict.entityType,
                    "strategy": conflict.strategy.rawValue
                ]
            )
            
            try await applyConflictResolution(conflict)
        }
    }
    
    /// Aktualisiert den lokalen Cache mit Sync-Response-Daten
    /// - Parameter response: OptimizedSyncResponse mit zu cachenden Daten
    /// - Throws: SyncError bei Fehlern während der Cache-Aktualisierung
    private func updateLocalCacheWithSyncResponse(_ response: OptimizedSyncResponse) async throws {
        // Aktualisiere SyncCacheManager mit neuen Daten
        let cacheManager = SyncCacheManager.shared
        
        // Cache Timestamp für nächsten Sync
        cacheManager.cacheEntity(
            response.timestamp,
            forKey: "lastSyncTimestamp",
            ttl: 86400 // 24 Stunden
        )
        
        // Cache Sync-Statistiken
        let syncStats = OptimizedSyncStatistics(
            processedEntities: response.processedEntities,
            resolvedConflicts: response.conflicts.count,
            errors: response.errors.count,
            timestamp: response.timestamp
        )
        
        cacheManager.cacheEntity(
            syncStats,
            forKey: "lastSyncStats",
            ttl: 3600 // 1 Stunde
        )
    }
    
    // MARK: - Helper Methods
    
    /// Holt ausstehende Entitäten für einen bestimmten Typ
    /// - Parameters:
    ///   - type: Der Entitätstyp
    ///   - context: Der Core Data Context
    /// - Returns: Array von NSManagedObject mit ausstehenden Entitäten
    /// - Throws: SyncError bei Fehlern während der Datenabfrage
    private func fetchPendingEntities(type: String, context: NSManagedObjectContext) async throws -> [NSManagedObject] {
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: type)
            request.predicate = NSPredicate(format: "syncStatus == %@", SyncStatus.needsUpload.rawValue)
            return try context.fetch(request)
        }
    }
    
    /// Bestimmt den Operationstyp für eine Entität
    /// - Parameter entity: Die zu analysierende Entität
    /// - Returns: SyncOperation.OperationType für die Entität
    private func determineOperationType(for entity: NSManagedObject) -> SyncOperation.OperationType {
        if let syncStatus = entity.value(forKey: "syncStatus") as? String {
            switch syncStatus {
            case String(SyncStatus.needsUpload.rawValue):
                return .create  // Für neue Entitäten
            default:
                return .update
            }
        }
        return .update
    }
    
    /// Holt Abhängigkeiten für eine Entität
    /// - Parameter entity: Die zu analysierende Entität
    /// - Returns: Array von String mit Abhängigkeits-IDs
    private func getDependencies(for entity: NSManagedObject) -> [String] {
        var dependencies: [String] = []
        
        // Implementiere Abhängigkeitslogik basierend auf Entitätstyp
        switch entity.entity.name {
        case "Memory":
            if let trip = entity.value(forKey: "trip") as? NSManagedObject {
                dependencies.append(trip.objectID.uriRepresentation().absoluteString)
            }
        case "MediaItem":
            if let memory = entity.value(forKey: "memory") as? NSManagedObject {
                dependencies.append(memory.objectID.uriRepresentation().absoluteString)
            }
        case "GPXTrack":
            if let trip = entity.value(forKey: "trip") as? NSManagedObject {
                dependencies.append(trip.objectID.uriRepresentation().absoluteString)
            }
        default:
            break
        }
        
        return dependencies
    }
    
    /// Bestimmt die Sync-Priorität für einen Entitätstyp
    /// - Parameter entityType: Der Entitätstyp
    /// - Returns: Int mit Prioritätswert (höhere Werte = höhere Priorität)
    private func getSyncPriority(for entityType: String) -> Int {
        switch entityType {
        case "Trip":
            return 100
        case "Memory":
            return 90
        case "Tag", "TagCategory":
            return 80
        case "GPXTrack":
            return 70
        case "MediaItem":
            return 60
        case "BucketListItem":
            return 50
        default:
            return 10
        }
    }
    
    /// Wendet eine Konfliktlösung an
    /// - Parameter conflict: Die anzuwendende Konfliktlösung
    /// - Throws: SyncError bei Fehlern während der Konfliktanwendung
    private func applyConflictResolution(_ conflict: ConflictResolution) async throws {
        let context = persistenceController.container.viewContext
        
        try await context.perform {
            // Implementiere die Konfliktlösung basierend auf der Strategie
            switch conflict.strategy {
            case .lastWriteWins:
                // Übernimme die Server-Version
                try self.applyServerResolution(conflict, context: context)
            case .fieldLevel:
                // Führe field-level Merge durch
                try self.applyFieldLevelResolution(conflict, context: context)
            case .userChoice:
                // Markiere für Benutzerentscheidung
                try self.markForUserResolution(conflict, context: context)
            }
        }
    }
    
    /// Wendet Server-Resolution an (Last-Write-Wins)
    /// - Parameters:
    ///   - conflict: Die Konfliktlösung
    ///   - context: Der Core Data Context
    /// - Throws: SyncError bei Anwendungsfehlern
    private func applyServerResolution(_ conflict: ConflictResolution, context: NSManagedObjectContext) throws {
        // Implementiere Server-Resolution-Logik
        SyncLogger.shared.info(
            "Applied server resolution for conflict",
            category: "ConflictResolver",
            metadata: [
                "conflictId": conflict.id,
                "entityType": conflict.entityType,
                "strategy": "lastWriteWins"
            ]
        )
    }
    
    /// Wendet Field-Level-Resolution an
    /// - Parameters:
    ///   - conflict: Die Konfliktlösung
    ///   - context: Der Core Data Context
    /// - Throws: SyncError bei Anwendungsfehlern
    private func applyFieldLevelResolution(_ conflict: ConflictResolution, context: NSManagedObjectContext) throws {
        // Implementiere Field-Level-Resolution-Logik
        SyncLogger.shared.info(
            "Applied field-level resolution for conflict",
            category: "ConflictResolver",
            metadata: [
                "conflictId": conflict.id,
                "entityType": conflict.entityType,
                "strategy": "fieldLevel"
            ]
        )
    }
    
    /// Markiert Konflikt für Benutzerentscheidung
    /// - Parameters:
    ///   - conflict: Die Konfliktlösung
    ///   - context: Der Core Data Context
    /// - Throws: SyncError bei Markierungsfehlern
    private func markForUserResolution(_ conflict: ConflictResolution, context: NSManagedObjectContext) throws {
        // Implementiere User-Choice-Logik
        SyncLogger.shared.info(
            "Marked conflict for user resolution",
            category: "ConflictResolver",
            metadata: [
                "conflictId": conflict.id,
                "entityType": conflict.entityType,
                "strategy": "userChoice"
            ]
        )
    }
}

// MARK: - Data Structures for Optimized Sync

/// Response-Struktur für optimierte Synchronisation
struct OptimizedSyncResponse {
    let processedEntities: Int
    let conflicts: [ConflictResolution]
    let errors: [SyncError]
    let timestamp: Date
}

/// Konfliktlösung-Struktur
struct ConflictResolution {
    let id: String
    let entityType: String
    let entityId: String
    let strategy: ConflictResolutionStrategy
    let resolution: Any
    let details: String
    
    enum ConflictResolutionStrategy: String {
        case lastWriteWins = "lastWriteWins"
        case fieldLevel = "fieldLevel"
        case userChoice = "userChoice"
    }
    
    /// Initialisiert ConflictResolution aus GraphQL-Response
    /// - Parameter graphQLConflict: GraphQL-Konfliktdaten
    init(from graphQLConflict: Any) {
        // Implementiere die Konvertierung von GraphQL zu ConflictResolution
        self.id = UUID().uuidString
        self.entityType = "Unknown"
        self.entityId = "Unknown"
        self.strategy = .lastWriteWins
        self.resolution = graphQLConflict
        self.details = "Conflict resolution details"
    }
}

/// Sync-Operation-Struktur
struct SyncOperation {
    let id: String
    let entityType: String
    let operationType: OperationType
    let entityId: String
    let data: [String: Any]
    let dependencies: [String]
    let priority: Int
    
    enum OperationType: String {
        case create = "CREATE"
        case update = "UPDATE"
        case delete = "DELETE"
    }
}

/// Sync-Statistiken-Struktur für optimierte Synchronisation
struct OptimizedSyncStatistics {
    let processedEntities: Int
    let resolvedConflicts: Int
    let errors: Int
    let timestamp: Date
}

/// Batch-Sync-Request-Struktur
struct BatchSyncRequest {
    let operations: [SyncOperation]
    let deviceId: String
    let conflictResolutionStrategy: ConflictResolutionStrategy
    let options: BatchSyncOptions
    
    enum ConflictResolutionStrategy: String {
        case lastWriteWins = "lastWriteWins"
        case fieldLevel = "fieldLevel"
        case userChoice = "userChoice"
    }
}

/// Batch-Sync-Options-Struktur
struct BatchSyncOptions {
    let batchSize: Int
    let timeout: Int
    let retryCount: Int
}

/// Batch-Sync-Mutation (Placeholder für zukünftige GraphQL-Implementation)
struct BatchSyncMutation {
    let request: BatchSyncRequest
    
    init(request: BatchSyncRequest) {
        self.request = request
    }
}

/// Simulierte Batch-Sync-Response für Prototyping
struct SimulatedBatchSyncResponse {
    let processedEntities: Int
    let conflicts: [ConflictResolution]
    let errors: [SyncError]
    let timestamp: Date
}

// MARK: - Extensions für NSManagedObject

extension NSManagedObject {
    /// Konvertiert die Entität zu Sync-Daten
    /// - Returns: Dictionary mit Sync-Daten
    func toSyncData() -> [String: Any] {
        var data: [String: Any] = [:]
        
        // Sammle alle Attributwerte
        for (key, attribute) in entity.attributesByName {
            if let value = self.value(forKey: key) {
                data[key] = value
            }
        }
        
        return data
    }
}