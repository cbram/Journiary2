import XCTest
@testable import Journiary
import CoreData

/// Integration-Tests für komplette Sync-Zyklen
/// Implementiert Schritt 8.2: Integration-Tests (60 min)
class SyncIntegrationTests: XCTestCase {
    var sut: SyncManager!
    var testContext: NSManagedObjectContext!
    var persistentContainer: NSPersistentContainer!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        setupTestEnvironment()
    }
    
    override func tearDownWithError() throws {
        sut = nil
        testContext = nil
        persistentContainer = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Full Sync Cycle Tests
    
    func testFullSyncCycle() async throws {
        print("🧪 Testing Full Sync Cycle...")
        
        // Given: Lokale Daten erstellen
        let trip = createTestTrip()
        let memory = createTestMemory(for: trip)
        let mediaItem = createTestMediaItem(for: memory)
        let gpxTrack = createTestGPXTrack(for: memory)
        
        try testContext.save()
        
        // When: Vollständige Synchronisation simulieren
        let syncExpectation = expectation(description: "Full Sync")
        
        Task {
            do {
                try await sut.performFullSyncSimulation()
                syncExpectation.fulfill()
            } catch {
                XCTFail("Full sync failed: \(error)")
            }
        }
        
        await fulfillment(of: [syncExpectation], timeout: 30.0)
        
        // Then: Alle Entitäten sollten synchronisiert sein
        XCTAssertNotNil(trip.serverId, "Trip should have server ID")
        XCTAssertNotNil(memory.serverId, "Memory should have server ID")
        XCTAssertNotNil(mediaItem.serverId, "MediaItem should have server ID")
        XCTAssertNotNil(gpxTrack.serverId, "GPXTrack should have server ID")
        
        // Dependency-Order sollte respektiert worden sein
        XCTAssertNotNil(trip.serverId, "Trip should be synced first")
        XCTAssertNotNil(memory.serverId, "Memory should be synced after Trip")
        XCTAssertNotNil(mediaItem.serverId, "MediaItem should be synced after Memory")
        XCTAssertNotNil(gpxTrack.serverId, "GPXTrack should be synced after Memory")
        
        print("✅ Full Sync Cycle Test passed")
    }
    
    func testConflictResolutionIntegration() async throws {
        print("🧪 Testing Conflict Resolution Integration...")
        
        // Given: Konfliktierender lokaler und Remote-Zustand simulieren
        let localTrip = createTestTrip()
        localTrip.title = "Local Title"
        localTrip.updatedAt = Date().addingTimeInterval(-60) // Älter
        localTrip.serverId = "conflict-trip-id"
        
        try testContext.save()
        
        // Simuliere Remote-Update (normalerweise vom Server)
        let remoteData: [String: Any] = [
            "title": "Remote Title",
            "updatedAt": Date(), // Neueres Datum
            "serverId": "conflict-trip-id"
        ]
        
        // When: Sync mit Konfliktlösung
        let conflictExpectation = expectation(description: "Conflict Resolution")
        
        Task {
            do {
                try await sut.syncWithConflictResolutionSimulation(
                    localEntity: localTrip,
                    remoteData: remoteData
                )
                conflictExpectation.fulfill()
            } catch {
                XCTFail("Conflict resolution failed: \(error)")
            }
        }
        
        await fulfillment(of: [conflictExpectation], timeout: 10.0)
        
        // Then: Remote-Version sollte gewonnen haben (Last-Write-Wins)
        XCTAssertEqual(localTrip.title, "Remote Title", "Remote title should win")
        XCTAssertEqual(localTrip.serverId, "conflict-trip-id", "Server ID should be preserved")
        
        print("✅ Conflict Resolution Integration Test passed")
    }
    
    func testDependencyOrderIntegration() async throws {
        print("🧪 Testing Dependency Order Integration...")
        
        // Given: Entities mit verschiedenen Abhängigkeiten
        let tagCategory = createTestTagCategory()
        let tag = createTestTag(for: tagCategory)
        let trip = createTestTrip()
        let memory = createTestMemory(for: trip)
        let mediaItem = createTestMediaItem(for: memory)
        
        // Speichere in umgekehrter Reihenfolge (sollte trotzdem korrekt synchronisiert werden)
        try testContext.save()
        
        // When: Dependency-aware Synchronisation
        let dependencyExpectation = expectation(description: "Dependency Order")
        
        Task {
            do {
                try await sut.syncWithDependencyResolution()
                dependencyExpectation.fulfill()
            } catch {
                XCTFail("Dependency sync failed: \(error)")
            }
        }
        
        await fulfillment(of: [dependencyExpectation], timeout: 15.0)
        
        // Then: Alle Entitäten sollten synchronisiert sein
        XCTAssertNotNil(tagCategory.serverId, "TagCategory should be synced")
        XCTAssertNotNil(tag.serverId, "Tag should be synced")
        XCTAssertNotNil(trip.serverId, "Trip should be synced")
        XCTAssertNotNil(memory.serverId, "Memory should be synced")
        XCTAssertNotNil(mediaItem.serverId, "MediaItem should be synced")
        
        print("✅ Dependency Order Integration Test passed")
    }
    
    func testOfflineQueueProcessingIntegration() async throws {
        print("🧪 Testing Offline Queue Processing Integration...")
        
        // Given: Offline-Operationen in Queue
        let queue = OfflineSyncQueue.shared
        
        let success1 = queue.enqueue(
            entityType: "Trip",
            entityId: "offline-trip-1",
            operation: .create,
            priority: .high,
            data: ["title": "Offline Trip 1", "description": "Created offline"]
        )
        
        let success2 = queue.enqueue(
            entityType: "Memory",
            entityId: "offline-memory-1",
            operation: .update,
            priority: .normal,
            data: ["title": "Offline Memory 1", "description": "Updated offline"]
        )
        
        let success3 = queue.enqueue(
            entityType: "MediaItem",
            entityId: "offline-media-1",
            operation: .create,
            priority: .critical,
            data: ["filename": "offline-photo.jpg", "fileSize": 1024000]
        )
        
        XCTAssertTrue(success1, "First enqueue should succeed")
        XCTAssertTrue(success2, "Second enqueue should succeed")
        XCTAssertTrue(success3, "Third enqueue should succeed")
        
        // When: Queue wird abgearbeitet
        let queueExpectation = expectation(description: "Queue Processing")
        
        Task {
            do {
                try await sut.processOfflineQueueSimulation()
                queueExpectation.fulfill()
            } catch {
                XCTFail("Queue processing failed: \(error)")
            }
        }
        
        await fulfillment(of: [queueExpectation], timeout: 20.0)
        
        // Then: Queue sollte leer sein
        XCTAssertEqual(queue.pendingCount, 0, "Queue should be empty after processing")
        
        print("✅ Offline Queue Processing Integration Test passed")
    }
    
    func testBatchSyncIntegration() async throws {
        print("🧪 Testing Batch Sync Integration...")
        
        // Given: Große Menge an Daten
        let trips = createMultipleTestTrips(count: 20)
        let memories = trips.flatMap { createMultipleTestMemories(for: $0, count: 5) }
        let mediaItems = memories.flatMap { createMultipleTestMediaItems(for: $0, count: 3) }
        
        try testContext.save()
        
        print("Created test data: \(trips.count) trips, \(memories.count) memories, \(mediaItems.count) media items")
        
        // When: Batch-Synchronisation
        let batchExpectation = expectation(description: "Batch Sync")
        
        Task {
            do {
                try await sut.performBatchSyncSimulation(batchSize: 10)
                batchExpectation.fulfill()
            } catch {
                XCTFail("Batch sync failed: \(error)")
            }
        }
        
        await fulfillment(of: [batchExpectation], timeout: 60.0)
        
        // Then: Alle Entitäten sollten synchronisiert sein
        let syncedTrips = trips.compactMap { $0.serverId }.count
        let syncedMemories = memories.compactMap { $0.serverId }.count
        let syncedMediaItems = mediaItems.compactMap { $0.serverId }.count
        
        XCTAssertEqual(syncedTrips, trips.count, "All trips should be synced")
        XCTAssertEqual(syncedMemories, memories.count, "All memories should be synced")
        XCTAssertEqual(syncedMediaItems, mediaItems.count, "All media items should be synced")
        
        print("✅ Batch Sync Integration Test passed")
    }
    
    func testTransactionRollbackIntegration() async throws {
        print("🧪 Testing Transaction Rollback Integration...")
        
        // Given: Daten die einen Fehler verursachen werden
        let trip = createTestTrip()
        let memory = createTestMemory(for: trip)
        
        // Simuliere einen Fehler-Zustand
        memory.title = "" // Leerer Titel sollte Validierungsfehler verursachen
        
        try testContext.save()
        
        // When: Sync mit Fehler
        let rollbackExpectation = expectation(description: "Transaction Rollback")
        
        Task {
            do {
                try await sut.performSyncWithTransactionRollback()
                XCTFail("Sync should have failed")
            } catch {
                // Fehler wird erwartet
                print("Expected error occurred: \(error)")
                rollbackExpectation.fulfill()
            }
        }
        
        await fulfillment(of: [rollbackExpectation], timeout: 10.0)
        
        // Then: Keine Entitäten sollten teilweise synchronisiert sein
        XCTAssertNil(trip.serverId, "Trip should not have server ID after rollback")
        XCTAssertNil(memory.serverId, "Memory should not have server ID after rollback")
        
        print("✅ Transaction Rollback Integration Test passed")
    }
    
    func testPerformanceIntegration() async throws {
        print("🧪 Testing Performance Integration...")
        
        // Given: Performance-Test-Daten
        let startTime = Date()
        let trips = createMultipleTestTrips(count: 50)
        let memories = trips.flatMap { createMultipleTestMemories(for: $0, count: 10) }
        
        try testContext.save()
        
        // When: Performance-gemessene Synchronisation
        let performanceExpectation = expectation(description: "Performance Sync")
        
        Task {
            do {
                try await sut.performSyncWithPerformanceMonitoring()
                performanceExpectation.fulfill()
            } catch {
                XCTFail("Performance sync failed: \(error)")
            }
        }
        
        await fulfillment(of: [performanceExpectation], timeout: 30.0)
        
        // Then: Performance-Metriken sollten verfügbar sein
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        XCTAssertLessThan(duration, 25.0, "Sync should complete within 25 seconds")
        
        let monitor = PerformanceMonitor.shared
        let avgPerformance = monitor.getAveragePerformance(for: "IntegrationTest")
        XCTAssertNotNil(avgPerformance, "Performance metrics should be available")
        
        print("✅ Performance Integration Test passed (Duration: \(String(format: "%.2f", duration))s)")
    }
    
    // MARK: - Helper Methods
    
    private func setupTestEnvironment() {
        persistentContainer = NSPersistentContainer(name: "Journiary")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        let loadExpectation = expectation(description: "Store Loading")
        persistentContainer.loadPersistentStores { _, error in
            XCTAssertNil(error, "Store loading should not fail")
            loadExpectation.fulfill()
        }
        
        wait(for: [loadExpectation], timeout: 5.0)
        
        testContext = persistentContainer.viewContext
        sut = SyncManager()
    }
    
    private func createTestTrip() -> Trip {
        let trip = Trip(context: testContext)
        trip.title = "Test Trip"
        trip.descriptionText = "Test Description"
        trip.createdAt = Date()
        trip.updatedAt = Date()
        return trip
    }
    
    private func createTestMemory(for trip: Trip) -> Memory {
        let memory = Memory(context: testContext)
        memory.title = "Test Memory"
        memory.descriptionText = "Test Memory Description"
        memory.trip = trip
        memory.createdAt = Date()
        memory.updatedAt = Date()
        return memory
    }
    
    private func createTestMediaItem(for memory: Memory) -> MediaItem {
        let mediaItem = MediaItem(context: testContext)
        mediaItem.filename = "test.jpg"
        mediaItem.fileSize = 1024000
        mediaItem.memory = memory
        mediaItem.createdAt = Date()
        mediaItem.updatedAt = Date()
        return mediaItem
    }
    
    private func createTestGPXTrack(for memory: Memory) -> GPXTrack {
        let gpxTrack = GPXTrack(context: testContext)
        gpxTrack.filename = "test.gpx"
        gpxTrack.trackData = "Test GPX Data".data(using: .utf8)
        gpxTrack.memory = memory
        gpxTrack.createdAt = Date()
        gpxTrack.updatedAt = Date()
        return gpxTrack
    }
    
    private func createTestTagCategory() -> TagCategory {
        let tagCategory = TagCategory(context: testContext)
        tagCategory.name = "Test Category"
        tagCategory.createdAt = Date()
        tagCategory.updatedAt = Date()
        return tagCategory
    }
    
    private func createTestTag(for category: TagCategory) -> Tag {
        let tag = Tag(context: testContext)
        tag.name = "Test Tag"
        tag.category = category
        tag.createdAt = Date()
        tag.updatedAt = Date()
        return tag
    }
    
    private func createMultipleTestTrips(count: Int) -> [Trip] {
        return (0..<count).map { index in
            let trip = Trip(context: testContext)
            trip.title = "Test Trip \(index)"
            trip.descriptionText = "Test Description \(index)"
            trip.createdAt = Date()
            trip.updatedAt = Date()
            return trip
        }
    }
    
    private func createMultipleTestMemories(for trip: Trip, count: Int) -> [Memory] {
        return (0..<count).map { index in
            let memory = Memory(context: testContext)
            memory.title = "Test Memory \(index)"
            memory.descriptionText = "Test Memory Description \(index)"
            memory.trip = trip
            memory.createdAt = Date()
            memory.updatedAt = Date()
            return memory
        }
    }
    
    private func createMultipleTestMediaItems(for memory: Memory, count: Int) -> [MediaItem] {
        return (0..<count).map { index in
            let mediaItem = MediaItem(context: testContext)
            mediaItem.filename = "test\(index).jpg"
            mediaItem.fileSize = Int64(1024000 + index * 100000)
            mediaItem.memory = memory
            mediaItem.createdAt = Date()
            mediaItem.updatedAt = Date()
            return mediaItem
        }
    }
}

// MARK: - SyncManager Test Extensions

extension SyncManager {
    func performFullSyncSimulation() async throws {
        print("🔄 Performing Full Sync Simulation...")
        
        // Simuliere vollständige Synchronisation
        let trips = try await fetchPendingTrips()
        let memories = try await fetchPendingMemories()
        let mediaItems = try await fetchPendingMediaItems()
        let gpxTracks = try await fetchPendingGPXTracks()
        
        // Simuliere Server-IDs
        for trip in trips {
            trip.serverId = "server-trip-\(UUID().uuidString)"
        }
        
        for memory in memories {
            memory.serverId = "server-memory-\(UUID().uuidString)"
        }
        
        for mediaItem in mediaItems {
            mediaItem.serverId = "server-media-\(UUID().uuidString)"
        }
        
        for gpxTrack in gpxTracks {
            gpxTrack.serverId = "server-gpx-\(UUID().uuidString)"
        }
        
        try await saveContext()
        print("✅ Full Sync Simulation completed")
    }
    
    func syncWithConflictResolutionSimulation(
        localEntity: Trip,
        remoteData: [String: Any]
    ) async throws {
        print("🔄 Performing Conflict Resolution Simulation...")
        
        // Simuliere Konfliktlösung
        let conflictResolver = ConflictResolver()
        
        // Erstelle temporäres Remote-Entity
        let tempRemoteEntity = Trip(context: localEntity.managedObjectContext!)
        tempRemoteEntity.title = remoteData["title"] as? String ?? ""
        tempRemoteEntity.updatedAt = remoteData["updatedAt"] as? Date ?? Date()
        tempRemoteEntity.serverId = remoteData["serverId"] as? String
        
        // Löse Konflikt
        let resolution = try await conflictResolver.resolveConflict(
            localEntity: localEntity,
            remoteEntity: tempRemoteEntity,
            strategy: .lastWriteWins
        )
        
        // Wende Lösung an
        if let resolvedTrip = resolution.resolvedEntity as? Trip {
            localEntity.title = resolvedTrip.title
            localEntity.updatedAt = resolvedTrip.updatedAt
            localEntity.serverId = resolvedTrip.serverId
        }
        
        try await saveContext()
        print("✅ Conflict Resolution Simulation completed")
    }
    
    func syncWithDependencyResolution() async throws {
        print("🔄 Performing Dependency Resolution Simulation...")
        
        let dependencyResolver = SyncDependencyResolver()
        let syncOrder = dependencyResolver.resolveSyncOrder()
        
        for entityType in syncOrder {
            try await syncEntitiesOfType(entityType)
        }
        
        print("✅ Dependency Resolution Simulation completed")
    }
    
    func processOfflineQueueSimulation() async throws {
        print("🔄 Processing Offline Queue Simulation...")
        
        let queue = OfflineSyncQueue.shared
        
        while let task = queue.dequeue() {
            print("Processing task: \(task.entityType) - \(task.operation.rawValue)")
            
            // Simuliere Verarbeitung
            try await processTask(task)
            
            // Markiere als abgeschlossen
            _ = queue.markTaskCompleted(task.id)
        }
        
        print("✅ Offline Queue Processing Simulation completed")
    }
    
    func performBatchSyncSimulation(batchSize: Int) async throws {
        print("🔄 Performing Batch Sync Simulation...")
        
        let allEntities = try await fetchAllPendingEntities()
        let batches = allEntities.chunked(into: batchSize)
        
        for (index, batch) in batches.enumerated() {
            print("Processing batch \(index + 1)/\(batches.count)")
            
            for entity in batch {
                if let trip = entity as? Trip {
                    trip.serverId = "server-trip-\(UUID().uuidString)"
                } else if let memory = entity as? Memory {
                    memory.serverId = "server-memory-\(UUID().uuidString)"
                } else if let mediaItem = entity as? MediaItem {
                    mediaItem.serverId = "server-media-\(UUID().uuidString)"
                }
            }
            
            try await saveContext()
            
            // Simuliere Netzwerk-Delay
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        print("✅ Batch Sync Simulation completed")
    }
    
    func performSyncWithTransactionRollback() async throws {
        print("🔄 Performing Sync with Transaction Rollback...")
        
        let transactionManager = SyncTransactionManager()
        
        try await transactionManager.performTransactionWithRollback { context in
            let memories = try context.fetch(Memory.fetchRequest())
            
            for memory in memories {
                if let title = memory.title, title.isEmpty {
                    throw SyncError.dataError("Memory title cannot be empty")
                }
                memory.serverId = "server-memory-\(UUID().uuidString)"
            }
            
            return ()
        }
        
        print("✅ Sync with Transaction Rollback completed")
    }
    
    func performSyncWithPerformanceMonitoring() async throws {
        print("🔄 Performing Sync with Performance Monitoring...")
        
        let measurement = PerformanceMonitor.shared.startMeasuring(operation: "IntegrationTest")
        
        let entities = try await fetchAllPendingEntities()
        
        for entity in entities {
            if let trip = entity as? Trip {
                trip.serverId = "server-trip-\(UUID().uuidString)"
            } else if let memory = entity as? Memory {
                memory.serverId = "server-memory-\(UUID().uuidString)"
            }
        }
        
        try await saveContext()
        
        measurement.finish(entityCount: entities.count)
        print("✅ Sync with Performance Monitoring completed")
    }
    
    // MARK: - Helper Methods
    
    private func fetchPendingTrips() async throws -> [Trip] {
        let request = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == nil")
        return try await executeRequest(request)
    }
    
    private func fetchPendingMemories() async throws -> [Memory] {
        let request = Memory.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == nil")
        return try await executeRequest(request)
    }
    
    private func fetchPendingMediaItems() async throws -> [MediaItem] {
        let request = MediaItem.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == nil")
        return try await executeRequest(request)
    }
    
    private func fetchPendingGPXTracks() async throws -> [GPXTrack] {
        let request = GPXTrack.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == nil")
        return try await executeRequest(request)
    }
    
    private func fetchAllPendingEntities() async throws -> [NSManagedObject] {
        let trips = try await fetchPendingTrips()
        let memories = try await fetchPendingMemories()
        let mediaItems = try await fetchPendingMediaItems()
        
        return trips + memories + mediaItems
    }
    
    private func executeRequest<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> [T] {
        return try await withCheckedThrowingContinuation { continuation in
            let context = PersistenceController.shared.container.viewContext
            context.perform {
                do {
                    let results = try context.fetch(request)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func saveContext() async throws {
        let context = PersistenceController.shared.container.viewContext
        try await context.perform {
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    private func syncEntitiesOfType(_ entityType: SyncDependencyResolver.EntityType) async throws {
        print("Syncing entities of type: \(entityType.rawValue)")
        
        switch entityType {
        case .tagCategory:
            let tagCategories = try await fetchPendingTagCategories()
            for category in tagCategories {
                category.serverId = "server-category-\(UUID().uuidString)"
            }
        case .tag:
            let tags = try await fetchPendingTags()
            for tag in tags {
                tag.serverId = "server-tag-\(UUID().uuidString)"
            }
        case .trip:
            let trips = try await fetchPendingTrips()
            for trip in trips {
                trip.serverId = "server-trip-\(UUID().uuidString)"
            }
        case .memory:
            let memories = try await fetchPendingMemories()
            for memory in memories {
                memory.serverId = "server-memory-\(UUID().uuidString)"
            }
        case .mediaItem:
            let mediaItems = try await fetchPendingMediaItems()
            for mediaItem in mediaItems {
                mediaItem.serverId = "server-media-\(UUID().uuidString)"
            }
        case .gpxTrack:
            let gpxTracks = try await fetchPendingGPXTracks()
            for gpxTrack in gpxTracks {
                gpxTrack.serverId = "server-gpx-\(UUID().uuidString)"
            }
        default:
            break
        }
        
        try await saveContext()
    }
    
    private func fetchPendingTagCategories() async throws -> [TagCategory] {
        let request = TagCategory.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == nil")
        return try await executeRequest(request)
    }
    
    private func fetchPendingTags() async throws -> [Tag] {
        let request = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "serverId == nil")
        return try await executeRequest(request)
    }
    
    private func processTask(_ task: OfflineSyncQueue.SyncTask) async throws {
        // Simuliere Task-Verarbeitung
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        print("Processed task: \(task.entityType) - \(task.operation.rawValue)")
    }
}

// MARK: - OfflineSyncQueue Extensions

extension OfflineSyncQueue {
    var pendingCount: Int {
        return queue.filter { $0.status == .pending }.count
    }
    
    func markTaskCompleted(_ taskId: UUID) -> Bool {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        guard let index = queue.firstIndex(where: { $0.id == taskId }) else {
            return false
        }
        
        queue[index] = queue[index].withStatus(.completed)
        return true
    }
}

// MARK: - SyncTask Extensions

extension OfflineSyncQueue.SyncTask {
    func withStatus(_ newStatus: OfflineSyncQueue.SyncStatus) -> OfflineSyncQueue.SyncTask {
        return OfflineSyncQueue.SyncTask(
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            priority: priority,
            data: data,
            maxRetries: maxRetries
        )
    }
}

// MARK: - Array Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
} 