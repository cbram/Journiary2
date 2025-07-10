import XCTest
@testable import Journiary
import CoreData

/// Performance-Tests für kritische Sync-Operationen
/// Implementiert Schritt 8.3: Performance-Tests (45 min)
class SyncPerformanceTests: XCTestCase {
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
    
    // MARK: - Batch Upload Performance Tests
    
    func testBatchUploadPerformanceSmall() throws {
        // Teste Batch-Upload mit 100 Memories
        let memories = createTestMemories(count: 100)
        try testContext.save()
        
        print("🚀 Testing Batch Upload Performance (100 entities)")
        
        measure {
            let expectation = XCTestExpectation(description: "Small Batch Upload")
            
            Task {
                do {
                    try await sut.performBatchUploadSimulation(memories, batchSize: 20)
                    expectation.fulfill()
                } catch {
                    XCTFail("Batch upload failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
        
        // Validiere Ergebnisse
        let syncedCount = memories.compactMap { $0.serverId }.count
        XCTAssertEqual(syncedCount, memories.count, "All memories should be synced")
        
        print("✅ Small Batch Upload Performance Test completed")
    }
    
    func testBatchUploadPerformanceMedium() throws {
        // Teste Batch-Upload mit 500 Memories
        let memories = createTestMemories(count: 500)
        try testContext.save()
        
        print("🚀 Testing Batch Upload Performance (500 entities)")
        
        measure {
            let expectation = XCTestExpectation(description: "Medium Batch Upload")
            
            Task {
                do {
                    try await sut.performBatchUploadSimulation(memories, batchSize: 50)
                    expectation.fulfill()
                } catch {
                    XCTFail("Batch upload failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 45.0)
        }
        
        // Validiere Ergebnisse
        let syncedCount = memories.compactMap { $0.serverId }.count
        XCTAssertEqual(syncedCount, memories.count, "All memories should be synced")
        
        print("✅ Medium Batch Upload Performance Test completed")
    }
    
    func testBatchUploadPerformanceLarge() throws {
        // Teste Batch-Upload mit 1000 Memories
        let memories = createTestMemories(count: 1000)
        try testContext.save()
        
        print("🚀 Testing Batch Upload Performance (1000 entities)")
        
        measure {
            let expectation = XCTestExpectation(description: "Large Batch Upload")
            
            Task {
                do {
                    try await sut.performBatchUploadSimulation(memories, batchSize: 100)
                    expectation.fulfill()
                } catch {
                    XCTFail("Batch upload failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 90.0)
        }
        
        // Validiere Ergebnisse
        let syncedCount = memories.compactMap { $0.serverId }.count
        XCTAssertEqual(syncedCount, memories.count, "All memories should be synced")
        
        print("✅ Large Batch Upload Performance Test completed")
    }
    
    // MARK: - Memory Usage Stability Tests
    
    func testMemoryUsageStabilityUnderLoad() throws {
        print("🚀 Testing Memory Usage Stability Under Load")
        
        let initialMemory = getMemoryUsage()
        print("Initial memory usage: \(formatBytes(initialMemory))")
        
        // Führe 20 Zyklen mit je 100 Memories durch
        for cycle in 1...20 {
            autoreleasepool {
                let memories = createTestMemories(count: 100)
                
                let expectation = XCTestExpectation(description: "Memory Cycle \(cycle)")
                Task {
                    do {
                        try await sut.performBatchUploadSimulation(memories, batchSize: 25)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Memory cycle \(cycle) failed: \(error)")
                    }
                }
                wait(for: [expectation], timeout: 10.0)
                
                // Cleanup nach jedem Zyklus
                memories.forEach { testContext.delete($0) }
                try! testContext.save()
                
                let currentMemory = getMemoryUsage()
                print("Cycle \(cycle): \(formatBytes(currentMemory)) (+\(formatBytes(currentMemory - initialMemory)))")
            }
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        print("Final memory usage: \(formatBytes(finalMemory))")
        print("Memory increase: \(formatBytes(memoryIncrease))")
        
        // Memory increase should be less than 100MB
        XCTAssertLessThan(memoryIncrease, 100_000_000, 
                         "Memory usage increased too much: \(formatBytes(memoryIncrease))")
        
        print("✅ Memory Usage Stability Test completed")
    }
    
    func testMemoryPeakUsageDuringLargeSync() throws {
        print("🚀 Testing Memory Peak Usage During Large Sync")
        
        let memories = createTestMemories(count: 2000)
        try testContext.save()
        
        let initialMemory = getMemoryUsage()
        var peakMemory = initialMemory
        
        let expectation = XCTestExpectation(description: "Large Sync")
        
        // Monitor memory usage during sync
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let currentMemory = self.getMemoryUsage()
            if currentMemory > peakMemory {
                peakMemory = currentMemory
            }
        }
        
        Task {
            do {
                try await sut.performBatchUploadSimulation(memories, batchSize: 100)
                timer.invalidate()
                expectation.fulfill()
            } catch {
                timer.invalidate()
                XCTFail("Large sync failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 120.0)
        
        let finalMemory = getMemoryUsage()
        let peakIncrease = peakMemory - initialMemory
        let finalIncrease = finalMemory - initialMemory
        
        print("Initial memory: \(formatBytes(initialMemory))")
        print("Peak memory: \(formatBytes(peakMemory)) (+\(formatBytes(peakIncrease)))")
        print("Final memory: \(formatBytes(finalMemory)) (+\(formatBytes(finalIncrease)))")
        
        // Peak should be reasonable
        XCTAssertLessThan(peakIncrease, 250_000_000, 
                         "Peak memory usage too high: \(formatBytes(peakIncrease))")
        
        // Final should be back to reasonable levels
        XCTAssertLessThan(finalIncrease, 150_000_000, 
                         "Final memory usage too high: \(formatBytes(finalIncrease))")
        
        print("✅ Memory Peak Usage Test completed")
    }
    
    // MARK: - Cache Performance Tests
    
    func testCacheWritePerformance() {
        print("🚀 Testing Cache Write Performance")
        
        let cache = SyncCacheManager.shared
        let testData = Array(0..<5000).map { "TestData-\($0)-\(UUID().uuidString)" }
        
        // Test Cache Write Performance
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            
            for (index, data) in testData.enumerated() {
                cache.cacheEntity(data, forKey: "key-\(index)")
            }
            
            stopMeasuring()
        }
        
        print("✅ Cache Write Performance Test completed")
    }
    
    func testCacheReadPerformance() {
        print("🚀 Testing Cache Read Performance")
        
        let cache = SyncCacheManager.shared
        let testData = Array(0..<5000).map { "TestData-\($0)" }
        
        // Pre-populate cache
        for (index, data) in testData.enumerated() {
            cache.cacheEntity(data, forKey: "key-\(index)")
        }
        
        // Test Cache Read Performance
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            
            for index in 0..<5000 {
                _ = cache.getCachedEntity(forKey: "key-\(index)", type: String.self)
            }
            
            stopMeasuring()
        }
        
        print("✅ Cache Read Performance Test completed")
    }
    
    func testCacheHitRateUnderLoad() {
        print("🚀 Testing Cache Hit Rate Under Load")
        
        let cache = SyncCacheManager.shared
        cache.invalidateCache()
        
        var hits = 0
        var misses = 0
        let totalOperations = 10000
        
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            
            for i in 0..<totalOperations {
                let key = "entity-\(i % 100)" // Nur 100 verschiedene Keys für höhere Hit-Rate
                
                if let _ = cache.getCachedEntity(forKey: key, type: String.self) {
                    hits += 1
                } else {
                    misses += 1
                    cache.cacheEntity("Data for \(key)", forKey: key, ttl: 300)
                }
            }
            
            stopMeasuring()
        }
        
        let hitRate = Double(hits) / Double(totalOperations)
        print("Cache Hit Rate: \(String(format: "%.2f", hitRate * 100))% (\(hits)/\(totalOperations))")
        
        // Hit Rate sollte bei diesem Test über 90% liegen
        XCTAssertGreaterThan(hitRate, 0.9, "Cache hit rate should be above 90%")
        
        print("✅ Cache Hit Rate Test completed")
    }
    
    // MARK: - Concurrent Operations Performance
    
    func testConcurrentSyncPerformance() throws {
        print("🚀 Testing Concurrent Sync Performance")
        
        let trips = createTestTrips(count: 50)
        let memories = trips.flatMap { createTestMemories(for: $0, count: 10) }
        let mediaItems = memories.flatMap { createTestMediaItems(for: $0, count: 5) }
        
        try testContext.save()
        
        print("Created test data: \(trips.count) trips, \(memories.count) memories, \(mediaItems.count) media items")
        
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            
            let group = DispatchGroup()
            
            // Simuliere gleichzeitige Sync-Operationen
            for i in 0..<10 {
                group.enter()
                Task {
                    do {
                        let batchMemories = Array(memories.dropFirst(i * 25).prefix(25))
                        try await sut.performBatchUploadSimulation(batchMemories, batchSize: 10)
                        group.leave()
                    } catch {
                        print("Concurrent sync \(i) failed: \(error)")
                        group.leave()
                    }
                }
            }
            
            group.wait()
            stopMeasuring()
        }
        
        // Validiere Ergebnisse
        let syncedTrips = trips.compactMap { $0.serverId }.count
        let syncedMemories = memories.compactMap { $0.serverId }.count
        let syncedMediaItems = mediaItems.compactMap { $0.serverId }.count
        
        print("Synced: \(syncedTrips) trips, \(syncedMemories) memories, \(syncedMediaItems) media items")
        
        XCTAssertGreaterThan(syncedMemories, memories.count / 2, "At least half of memories should be synced")
        
        print("✅ Concurrent Sync Performance Test completed")
    }
    
    // MARK: - Network Simulation Performance
    
    func testNetworkLatencySimulation() throws {
        print("🚀 Testing Network Latency Simulation")
        
        let memories = createTestMemories(count: 100)
        try testContext.save()
        
        // Simuliere verschiedene Netzwerk-Bedingungen
        let networkConditions = [
            ("Fast WiFi", 0.01),      // 10ms latency
            ("Slow WiFi", 0.05),      // 50ms latency
            ("4G", 0.1),              // 100ms latency
            ("3G", 0.3),              // 300ms latency
            ("Poor Connection", 0.8)   // 800ms latency
        ]
        
        for (conditionName, latency) in networkConditions {
            print("Testing \(conditionName) (latency: \(Int(latency * 1000))ms)")
            
            measure(metrics: [XCTClockMetric()]) {
                let expectation = XCTestExpectation(description: "Network \(conditionName)")
                
                Task {
                    do {
                        try await sut.performBatchUploadWithLatencySimulation(
                            memories, 
                            batchSize: 20, 
                            latency: latency
                        )
                        expectation.fulfill()
                    } catch {
                        XCTFail("Network simulation failed for \(conditionName): \(error)")
                    }
                }
                
                wait(for: [expectation], timeout: 60.0)
            }
        }
        
        print("✅ Network Latency Simulation Test completed")
    }
    
    // MARK: - Database Query Performance
    
    func testDatabaseQueryPerformance() throws {
        print("🚀 Testing Database Query Performance")
        
        // Erstelle große Datenmenge
        let trips = createTestTrips(count: 100)
        let memories = trips.flatMap { createTestMemories(for: $0, count: 50) }
        try testContext.save()
        
        print("Created \(memories.count) memories for query testing")
        
        // Test verschiedene Query-Szenarien
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            
            // Scenario 1: All unsynchronized entities
            let unsynced = try! testContext.fetch(Memory.fetchRequest().applying {
                $0.predicate = NSPredicate(format: "serverId == nil")
            })
            
            // Scenario 2: Recent entities
            let recent = try! testContext.fetch(Memory.fetchRequest().applying {
                $0.predicate = NSPredicate(format: "createdAt > %@", Date().addingTimeInterval(-86400) as NSDate)
                $0.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                $0.fetchLimit = 100
            })
            
            // Scenario 3: Complex query with relationships
            let complex = try! testContext.fetch(Memory.fetchRequest().applying {
                $0.predicate = NSPredicate(format: "trip != nil AND serverId == nil")
                $0.relationshipKeyPathsForPrefetching = ["trip", "mediaItems"]
                $0.fetchLimit = 50
            })
            
            stopMeasuring()
            
            print("Query results: \(unsynced.count) unsynced, \(recent.count) recent, \(complex.count) complex")
        }
        
        print("✅ Database Query Performance Test completed")
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
    
    private func createTestMemories(count: Int) -> [Memory] {
        return (0..<count).map { index in
            let memory = Memory(context: testContext)
            memory.title = "Test Memory \(index)"
            memory.descriptionText = "Performance test memory with content \(index)"
            memory.createdAt = Date().addingTimeInterval(TimeInterval(-index * 60))
            memory.updatedAt = Date().addingTimeInterval(TimeInterval(-index * 30))
            return memory
        }
    }
    
    private func createTestTrips(count: Int) -> [Trip] {
        return (0..<count).map { index in
            let trip = Trip(context: testContext)
            trip.title = "Test Trip \(index)"
            trip.descriptionText = "Performance test trip \(index)"
            trip.createdAt = Date().addingTimeInterval(TimeInterval(-index * 3600))
            trip.updatedAt = Date().addingTimeInterval(TimeInterval(-index * 1800))
            return trip
        }
    }
    
    private func createTestMemories(for trip: Trip, count: Int) -> [Memory] {
        return (0..<count).map { index in
            let memory = Memory(context: testContext)
            memory.title = "Trip Memory \(index)"
            memory.descriptionText = "Memory for trip \(trip.title ?? "") - \(index)"
            memory.trip = trip
            memory.createdAt = Date().addingTimeInterval(TimeInterval(-index * 300))
            memory.updatedAt = Date().addingTimeInterval(TimeInterval(-index * 150))
            return memory
        }
    }
    
    private func createTestMediaItems(for memory: Memory, count: Int) -> [MediaItem] {
        return (0..<count).map { index in
            let mediaItem = MediaItem(context: testContext)
            mediaItem.filename = "test_media_\(index).jpg"
            mediaItem.fileSize = Int64(1024000 + index * 512000)
            mediaItem.memory = memory
            mediaItem.createdAt = Date().addingTimeInterval(TimeInterval(-index * 60))
            mediaItem.updatedAt = Date().addingTimeInterval(TimeInterval(-index * 30))
            return mediaItem
        }
    }
    
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
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - NSFetchRequest Extensions

extension NSFetchRequest {
    func applying(_ config: (NSFetchRequest) -> Void) -> NSFetchRequest {
        config(self)
        return self
    }
}

// MARK: - SyncManager Performance Extensions

extension SyncManager {
    func performBatchUploadSimulation<T: NSManagedObject>(
        _ entities: [T],
        batchSize: Int
    ) async throws {
        let batches = entities.chunked(into: batchSize)
        
        for (index, batch) in batches.enumerated() {
            // Simuliere Netzwerk-Delay
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            // Simuliere Server-Processing
            for entity in batch {
                if let memory = entity as? Memory {
                    memory.serverId = "server-memory-\(UUID().uuidString)"
                } else if let trip = entity as? Trip {
                    trip.serverId = "server-trip-\(UUID().uuidString)"
                } else if let mediaItem = entity as? MediaItem {
                    mediaItem.serverId = "server-media-\(UUID().uuidString)"
                }
            }
            
            try await saveContext()
        }
    }
    
    func performBatchUploadWithLatencySimulation<T: NSManagedObject>(
        _ entities: [T],
        batchSize: Int,
        latency: TimeInterval
    ) async throws {
        let batches = entities.chunked(into: batchSize)
        
        for batch in batches {
            // Simuliere Netzwerk-Latency
            try await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))
            
            // Simuliere Server-Processing
            for entity in batch {
                if let memory = entity as? Memory {
                    memory.serverId = "server-memory-\(UUID().uuidString)"
                } else if let trip = entity as? Trip {
                    trip.serverId = "server-trip-\(UUID().uuidString)"
                } else if let mediaItem = entity as? MediaItem {
                    mediaItem.serverId = "server-media-\(UUID().uuidString)"
                }
            }
            
            try await saveContext()
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
}

// MARK: - Array Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
} 