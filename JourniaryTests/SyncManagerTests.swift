import XCTest
@testable import Journiary
import CoreData

/// Unit-Tests für Sync-Komponenten
/// Implementiert Schritt 8.1: Unit-Tests für Sync-Komponenten (90 min)
class SyncManagerTests: XCTestCase {
    var sut: SyncManager!
    var mockContext: NSManagedObjectContext!
    var persistentContainer: NSPersistentContainer!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Setup In-Memory Core Data Stack for Testing
        persistentContainer = NSPersistentContainer(name: "Journiary")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        let expectation = XCTestExpectation(description: "Core Data Setup")
        persistentContainer.loadPersistentStores { _, error in
            XCTAssertNil(error, "Core Data setup should not fail")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
        
        mockContext = persistentContainer.viewContext
        sut = SyncManager.shared
    }
    
    override func tearDownWithError() throws {
        sut = nil
        mockContext = nil
        persistentContainer = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Dependency Resolver Tests
    
    func testDependencyResolverOrder() throws {
        // Given
        let resolver = SyncDependencyResolver()
        
        // When
        let order = resolver.resolveSyncOrder()
        
        // Then
        XCTAssertEqual(order.first, .tagCategory, "TagCategory should be first")
        XCTAssertEqual(order.last, .gpxTrack, "GPXTrack should be last")
        
        // Validate dependencies are respected
        let tagIndex = order.firstIndex(of: .tag)!
        let tagCategoryIndex = order.firstIndex(of: .tagCategory)!
        XCTAssertLessThan(tagCategoryIndex, tagIndex, "TagCategory must come before Tag")
        
        let memoryIndex = order.firstIndex(of: .memory)!
        let tripIndex = order.firstIndex(of: .trip)!
        XCTAssertLessThan(tripIndex, memoryIndex, "Trip must come before Memory")
    }
    
    func testDependencyResolverDependencies() throws {
        // Given
        let resolver = SyncDependencyResolver()
        
        // When & Then
        XCTAssertTrue(resolver.getDependencies(for: .tagCategory).isEmpty, "TagCategory should have no dependencies")
        XCTAssertEqual(resolver.getDependencies(for: .tag), [.tagCategory], "Tag should depend on TagCategory")
        XCTAssertEqual(resolver.getDependencies(for: .memory), [.trip], "Memory should depend on Trip")
        XCTAssertEqual(resolver.getDependencies(for: .mediaItem), [.memory], "MediaItem should depend on Memory")
    }
    
    // MARK: - Conflict Resolution Tests
    
    func testConflictResolutionLastWriteWins() async throws {
        // Given
        let resolver = ConflictResolver()
        
        let trip1 = Trip(context: mockContext)
        trip1.title = "Local Trip"
        trip1.updatedAt = Date().addingTimeInterval(-100) // Older
        
        let trip2 = Trip(context: mockContext)
        trip2.title = "Remote Trip"
        trip2.updatedAt = Date() // Newer
        
        // When
        let result = try await resolver.resolveConflict(
            localEntity: trip1,
            remoteEntity: trip2,
            strategy: .lastWriteWins
        )
        
        // Then
        XCTAssertEqual(result.strategy, .lastWriteWins)
        XCTAssertEqual((result.resolvedEntity as! Trip).title, "Remote Trip")
        XCTAssertTrue(result.conflictDetails.contains("Remote entity newer"))
    }
    
    func testConflictResolutionLocalWins() async throws {
        // Given
        let resolver = ConflictResolver()
        
        let trip1 = Trip(context: mockContext)
        trip1.title = "Local Trip"
        trip1.updatedAt = Date() // Newer
        
        let trip2 = Trip(context: mockContext)
        trip2.title = "Remote Trip"
        trip2.updatedAt = Date().addingTimeInterval(-100) // Older
        
        // When
        let result = try await resolver.resolveConflict(
            localEntity: trip1,
            remoteEntity: trip2,
            strategy: .lastWriteWins
        )
        
        // Then
        XCTAssertEqual(result.strategy, .lastWriteWins)
        XCTAssertEqual((result.resolvedEntity as! Trip).title, "Local Trip")
        XCTAssertTrue(result.conflictDetails.contains("Local entity newer"))
    }
    
    func testConflictDetection() {
        // Given
        let resolver = ConflictResolver()
        
        let trip1 = Trip(context: mockContext)
        trip1.title = "Original Title"
        trip1.updatedAt = Date().addingTimeInterval(-60)
        
        let trip2 = Trip(context: mockContext)
        trip2.title = "Modified Title"
        trip2.updatedAt = Date()
        
        // When
        let detection = resolver.detectConflict(localEntity: trip1, remoteEntity: trip2)
        
        // Then
        XCTAssertTrue(detection.hasConflict, "Should detect conflict")
        XCTAssertEqual(detection.conflictType, .simpleUpdate)
        XCTAssertTrue(detection.conflictedFields.contains("title"))
    }
    
    // MARK: - Performance Monitor Tests
    
    func testPerformanceMonitoring() {
        // Given
        let monitor = PerformanceMonitor.shared
        
        // When
        let measurement = monitor.startMeasuring(operation: "TestOperation")
        
        // Simulate some work
        Thread.sleep(forTimeInterval: 0.1)
        
        measurement.finish(entityCount: 10, networkBytes: 1024)
        
        // Then
        let avgPerformance = monitor.getAveragePerformance(for: "TestOperation")
        XCTAssertNotNil(avgPerformance)
        XCTAssertGreaterThan(avgPerformance!, 0)
    }
    
    func testPerformanceMetricsCalculation() {
        // Given
        let metrics = SyncPerformanceMetrics(
            operation: "TestOp",
            duration: 2.0,
            entityCount: 100,
            timestamp: Date(),
            memoryUsage: 1024,
            networkBytesTransferred: 2048
        )
        
        // When & Then
        XCTAssertEqual(metrics.throughput, 50.0, "Throughput should be 100 entities / 2 seconds = 50")
        XCTAssertEqual(metrics.bytesPerSecond, 1024.0, "Bytes per second should be 2048 / 2 = 1024")
    }
    
    // MARK: - Offline Sync Queue Tests
    
    func testOfflineSyncQueueEnqueue() {
        // Given
        let queue = OfflineSyncQueue.shared
        let initialCount = queue.pendingCount
        
        // When
        let success = queue.enqueue(
            entityType: "Trip",
            entityId: "test-trip-1",
            operation: .create,
            priority: .high
        )
        
        // Then
        XCTAssertTrue(success, "Enqueue should succeed")
        XCTAssertEqual(queue.pendingCount, initialCount + 1, "Pending count should increase")
    }
    
    func testOfflineSyncQueueDequeue() {
        // Given
        let queue = OfflineSyncQueue.shared
        
        // Enqueue a task first
        _ = queue.enqueue(
            entityType: "Trip",
            entityId: "test-trip-dequeue",
            operation: .create,
            priority: .high
        )
        
        // When
        let task = queue.dequeue()
        
        // Then
        XCTAssertNotNil(task, "Should dequeue a task")
        XCTAssertEqual(task?.entityType, "Trip")
        XCTAssertEqual(task?.entityId, "test-trip-dequeue")
        XCTAssertEqual(task?.priority, .high)
        XCTAssertEqual(task?.operation, .create)
    }
    
    func testOfflineSyncQueuePriority() {
        // Given
        let queue = OfflineSyncQueue.shared
        
        // Clear queue first
        _ = queue.cleanupCompleted()
        
        // Enqueue tasks with different priorities
        _ = queue.enqueue(entityType: "Trip", entityId: "low", operation: .create, priority: .low)
        _ = queue.enqueue(entityType: "Trip", entityId: "critical", operation: .create, priority: .critical)
        _ = queue.enqueue(entityType: "Trip", entityId: "normal", operation: .create, priority: .normal)
        
        // When
        let firstTask = queue.dequeue()
        
        // Then
        XCTAssertEqual(firstTask?.priority, .critical, "Highest priority task should be dequeued first")
        XCTAssertEqual(firstTask?.entityId, "critical")
    }
    
    // MARK: - Sync Status Tests
    
    func testDetailedSyncStatusDisplayNames() {
        // When & Then
        XCTAssertEqual(DetailedSyncStatus.inSync.displayName, "Synchronisiert")
        XCTAssertEqual(DetailedSyncStatus.needsUpload.displayName, "Upload ausstehend")
        XCTAssertEqual(DetailedSyncStatus.needsDownload.displayName, "Download ausstehend")
        XCTAssertEqual(DetailedSyncStatus.uploading.displayName, "Wird hochgeladen...")
        XCTAssertEqual(DetailedSyncStatus.downloading.displayName, "Wird heruntergeladen...")
        XCTAssertEqual(DetailedSyncStatus.syncError.displayName, "Sync-Fehler")
        XCTAssertEqual(DetailedSyncStatus.filesPending.displayName, "Dateien ausstehend")
    }
    
    // MARK: - Sync Error Tests
    
    func testSyncErrorDescriptions() {
        // Given & When & Then
        let authError = SyncError.authenticationError
        XCTAssertEqual(authError.localizedDescription, "Authentifizierungsfehler")
        
        let networkError = SyncError.networkError(NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network failed"]))
        XCTAssertTrue(networkError.localizedDescription.contains("Netzwerkfehler"))
        
        let dataError = SyncError.dataError("Invalid data")
        XCTAssertEqual(dataError.localizedDescription, "Datenfehler: Invalid data")
        
        let dependencyError = SyncError.dependencyNotMet(entity: "Memory", dependency: "Trip")
        XCTAssertEqual(dependencyError.localizedDescription, "Abhängigkeit fehlt: Memory benötigt Trip")
    }
    
    // MARK: - Helper Methods
    
    private func createTestTrip() -> Trip {
        let trip = Trip(context: mockContext)
        trip.title = "Test Trip"
        trip.createdAt = Date()
        trip.updatedAt = Date()
        return trip
    }
    
    private func createTestMemory(for trip: Trip) -> Memory {
        let memory = Memory(context: mockContext)
        memory.title = "Test Memory"
        memory.trip = trip
        memory.createdAt = Date()
        memory.updatedAt = Date()
        return memory
    }
    
    private func createTestMediaItem(for memory: Memory) -> MediaItem {
        let mediaItem = MediaItem(context: mockContext)
        mediaItem.filename = "test.jpg"
        mediaItem.memory = memory
        mediaItem.createdAt = Date()
        mediaItem.updatedAt = Date()
        return mediaItem
    }
} 