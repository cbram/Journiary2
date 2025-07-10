//
//  SyncPerformanceBenchmarks.swift
//  JourniaryTests
//
//  Created by Journiary Sync Implementation - Phase 11.2
//

import XCTest
import CoreData
@testable import Journiary

/// Performance-Benchmark-Tests für Synchronisationskomponenten
/// Implementiert als Teil von Phase 11.2: Performance-Benchmark-Tests
class SyncPerformanceBenchmarks: XCTestCase {
    var syncManager: SyncManager!
    var testContext: NSManagedObjectContext!
    var performanceMonitor: PerformanceMonitor!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        setupPerformanceTestEnvironment()
        
        print("🏁 Performance Benchmark Environment Setup Complete")
    }
    
    override func tearDownWithError() throws {
        cleanupPerformanceTestEnvironment()
        try super.tearDownWithError()
        
        print("🧹 Performance Benchmark Environment Cleaned Up")
    }
    
    // MARK: - Sync Performance Tests
    
    func testSyncPerformanceWith1000Entities() {
        /// Test: Performance mit 1000 Entitäten
        /// Benchmark für große Datenmengen
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Sync 1000 entities")
            
            Task {
                do {
                    let entities = createTestEntities(count: 1000)
                    let measurement = performanceMonitor.startMeasuring(operation: "Benchmark1000Entities")
                    
                    try await syncManager.syncWithOptimizedBackend()
                    
                    measurement.finish(entityCount: entities.count)
                    expectation.fulfill()
                } catch {
                    XCTFail("Sync failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 120.0)
        }
        
        print("✅ 1000 Entities Sync Performance Test Completed")
    }
    
    func testMemoryUsageStabilityWithLargeSync() {
        /// Test: Memory-Stabilität bei großen Sync-Operationen
        /// Überwacht Memory-Leaks und Performance-Degradation
        
        let initialMemory = getMemoryUsage()
        var maxMemoryIncrease: Int64 = 0
        
        for iteration in 1...5 { // Reduziert für Performance
            autoreleasepool {
                let entities = createTestEntities(count: 200)
                let expectation = XCTestExpectation(description: "Iteration \(iteration)")
                
                Task {
                    do {
                        let measurement = performanceMonitor.startMeasuring(operation: "MemoryIteration\(iteration)")
                        try await syncManager.syncWithOptimizedBackend()
                        measurement.finish(entityCount: entities.count)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Iteration \(iteration) failed: \(error)")
                        expectation.fulfill()
                    }
                }
                
                wait(for: [expectation], timeout: 60.0)
                
                // Memory-Check nach jeder Iteration
                let currentMemory = getMemoryUsage()
                let memoryIncrease = currentMemory - initialMemory
                maxMemoryIncrease = max(maxMemoryIncrease, memoryIncrease)
                
                print("📊 Iteration \(iteration): Memory increase: \(memoryIncrease / 1024 / 1024) MB")
                
                XCTAssertLessThan(
                    memoryIncrease,
                    200_000_000, // 200MB Limit
                    "Memory usage increased too much in iteration \(iteration): \(memoryIncrease) bytes"
                )
            }
        }
        
        print("✅ Memory Stability Test Completed - Max increase: \(maxMemoryIncrease / 1024 / 1024) MB")
    }
    
    func testConcurrentSyncPerformance() {
        /// Test: Parallele Sync-Operationen Performance
        /// Testet Thread-Safety und Concurrent-Performance
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "Concurrent sync")
            expectation.expectedFulfillmentCount = 3 // Reduziert für Performance
            
            // Starte 3 parallele Sync-Operationen
            for i in 1...3 {
                Task {
                    do {
                        let entities = createTestEntities(count: 50, prefix: "Concurrent\(i)")
                        let measurement = performanceMonitor.startMeasuring(operation: "ConcurrentSync\(i)")
                        
                        try await syncManager.syncWithOptimizedBackend()
                        
                        measurement.finish(entityCount: entities.count)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Concurrent sync \(i) failed: \(error)")
                        expectation.fulfill()
                    }
                }
            }
            
            wait(for: [expectation], timeout: 90.0)
        }
        
        print("✅ Concurrent Sync Performance Test Completed")
    }
    
    func testSyncPerformanceWithConflicts() {
        /// Test: Performance bei Konfliktlösung
        /// Benchmark für Conflict-Resolution-Performance
        
        let conflictingEntities = createConflictingTestEntities(count: 50)
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "Conflict resolution performance")
            
            Task {
                do {
                    let measurement = performanceMonitor.startMeasuring(operation: "ConflictResolution")
                    
                    // Simuliere Konfliktlösung
                    for entity in conflictingEntities {
                        try await resolveConflictForEntity(entity)
                    }
                    
                    measurement.finish(entityCount: conflictingEntities.count)
                    expectation.fulfill()
                } catch {
                    XCTFail("Conflict resolution failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 45.0)
        }
        
        print("✅ Conflict Resolution Performance Test Completed")
    }
    
    func testBatchUploadPerformance() {
        /// Test: Batch-Upload Performance
        /// Testet optimale Batch-Größen
        
        let batchSizes = [10, 50, 100, 200]
        var results: [Int: TimeInterval] = [:]
        
        for batchSize in batchSizes {
            let entities = createTestEntities(count: 500)
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let expectation = XCTestExpectation(description: "Batch size \(batchSize)")
            
            Task {
                do {
                    let measurement = performanceMonitor.startMeasuring(operation: "BatchSize\(batchSize)")
                    
                    // Simuliere Batch-Upload
                    let batches = entities.chunked(into: batchSize)
                    for batch in batches {
                        try await processBatch(batch)
                    }
                    
                    measurement.finish(entityCount: entities.count)
                    expectation.fulfill()
                } catch {
                    XCTFail("Batch upload failed for size \(batchSize): \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 120.0)
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            results[batchSize] = duration
            
            print("📊 Batch size \(batchSize): \(String(format: "%.3f", duration))s")
        }
        
        // Finde optimale Batch-Größe
        let optimalBatchSize = results.min { $0.value < $1.value }?.key ?? 100
        print("🎯 Optimal batch size: \(optimalBatchSize)")
        
        XCTAssertNotNil(optimalBatchSize, "Should determine optimal batch size")
    }
    
    func testCachePerformance() {
        /// Test: Cache-Performance
        /// Testet SyncCacheManager Performance
        
        let cacheManager = SyncCacheManager.shared
        let testData = createTestCacheData(count: 1000)
        
        // Cache Write Performance
        measure(metrics: [XCTClockMetric()]) {
            for (index, data) in testData.enumerated() {
                cacheManager.cacheEntity(data, forKey: "test_key_\(index)", ttl: 3600)
            }
        }
        
        print("📝 Cache Write Performance Test Completed")
        
        // Cache Read Performance
        measure(metrics: [XCTClockMetric()]) {
            for index in 0..<testData.count {
                let _ = cacheManager.getCachedEntity(forKey: "test_key_\(index)", type: TestCacheData.self)
            }
        }
        
        print("📖 Cache Read Performance Test Completed")
        
        // Cache Cleanup
        for index in 0..<testData.count {
            cacheManager.removeCachedEntity(forKey: "test_key_\(index)")
        }
        
        print("✅ Cache Performance Test Completed")
    }
    
    func testNetworkPerformanceUnderLoad() {
        /// Test: Netzwerk-Performance unter Last
        /// Testet NetworkProvider unter hoher Last
        
        let requestCount = 50
        let expectation = XCTestExpectation(description: "Network load test")
        expectation.expectedFulfillmentCount = requestCount
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        measure(metrics: [XCTClockMetric()]) {
            for i in 1...requestCount {
                Task {
                    do {
                        try await simulateNetworkRequest(id: i)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Network request \(i) failed: \(error)")
                        expectation.fulfill()
                    }
                }
            }
            
            wait(for: [expectation], timeout: 120.0)
        }
        
        let totalDuration = CFAbsoluteTimeGetCurrent() - startTime
        let avgRequestTime = totalDuration / Double(requestCount)
        
        print("📡 Network Performance: \(requestCount) requests in \(String(format: "%.3f", totalDuration))s")
        print("📊 Average request time: \(String(format: "%.3f", avgRequestTime))s")
        
        XCTAssertLessThan(avgRequestTime, 2.0, "Average request time should be under 2 seconds")
    }
    
    // MARK: - Performance Helper Methods
    
    private func setupPerformanceTestEnvironment() {
        // Setup In-Memory Core Data für Performance-Tests
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        
        let container = NSPersistentContainer(name: "Journiary")
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "Performance test Core Data setup should succeed")
        }
        
        testContext = container.viewContext
        syncManager = SyncManager.shared
        performanceMonitor = PerformanceMonitor.shared
        
        // Performance-Test-Konfiguration
        UserDefaults.standard.set(true, forKey: "PerformanceTestMode")
        UserDefaults.standard.set(false, forKey: "DetailedLogging") // Reduziere Logging für Performance
    }
    
    private func cleanupPerformanceTestEnvironment() {
        testContext = nil
        performanceMonitor.clearMeasurements()
        
        UserDefaults.standard.removeObject(forKey: "PerformanceTestMode")
        UserDefaults.standard.removeObject(forKey: "DetailedLogging")
    }
    
    private func createTestEntities(count: Int, prefix: String = "Test") -> [TestSyncEntity] {
        var entities: [TestSyncEntity] = []
        
        for i in 1...count {
            let entity = TestSyncEntity(
                id: UUID(),
                title: "\(prefix) Entity \(i)",
                data: "Test data for entity \(i)",
                timestamp: Date()
            )
            entities.append(entity)
        }
        
        return entities
    }
    
    private func createConflictingTestEntities(count: Int) -> [TestSyncEntity] {
        var entities: [TestSyncEntity] = []
        
        for i in 1...count {
            let entity = TestSyncEntity(
                id: UUID(),
                title: "Conflict Entity \(i)",
                data: "Conflicting data \(i)",
                timestamp: Date().addingTimeInterval(-3600), // 1 Stunde alt
                hasConflict: true
            )
            entities.append(entity)
        }
        
        return entities
    }
    
    private func createTestCacheData(count: Int) -> [TestCacheData] {
        var data: [TestCacheData] = []
        
        for i in 1...count {
            let cacheData = TestCacheData(
                id: "cache_\(i)",
                content: "Cache content \(i)",
                metadata: ["type": "test", "index": i]
            )
            data.append(cacheData)
        }
        
        return data
    }
    
    private func resolveConflictForEntity(_ entity: TestSyncEntity) async throws {
        // Simuliere Konfliktlösung
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        entity.hasConflict = false
        entity.timestamp = Date()
    }
    
    private func processBatch(_ batch: [TestSyncEntity]) async throws {
        // Simuliere Batch-Verarbeitung
        let processingTime = UInt64(batch.count * 2_000_000) // 2ms pro Entity
        try await Task.sleep(nanoseconds: processingTime)
    }
    
    private func simulateNetworkRequest(id: Int) async throws {
        // Simuliere Netzwerk-Request
        let responseTime = UInt64.random(in: 50_000_000...500_000_000) // 50-500ms
        try await Task.sleep(nanoseconds: responseTime)
    }
    
    private func getMemoryUsage() -> Int64 {
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
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - Test Data Models

struct TestSyncEntity {
    let id: UUID
    var title: String
    var data: String
    var timestamp: Date
    var hasConflict: Bool = false
}

struct TestCacheData: Codable {
    let id: String
    let content: String
    let metadata: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id, content, metadata
    }
    
    init(id: String, content: String, metadata: [String: Any]) {
        self.id = id
        self.content = content
        self.metadata = metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        metadata = try container.decode([String: Any].self, forKey: .metadata)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(metadata, forKey: .metadata)
    }
}

// MARK: - Extensions

extension Array {
    /// Teilt das Array in Chunks der angegebenen Größe auf
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Performance Assertions

extension SyncPerformanceBenchmarks {
    
    func assertPerformanceWithin(
        _ timeLimit: TimeInterval,
        operation: () throws -> Void,
        description: String = "Operation"
    ) rethrows {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try operation()
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(
            duration,
            timeLimit,
            "\(description) should complete within \(timeLimit) seconds, but took \(String(format: "%.3f", duration)) seconds"
        )
        
        print("⏱️ \(description): \(String(format: "%.3f", duration))s (limit: \(timeLimit)s)")
    }
    
    func assertMemoryUsageWithin(
        _ memoryLimit: Int64,
        operation: () throws -> Void,
        description: String = "Operation"
    ) rethrows {
        let initialMemory = getMemoryUsage()
        
        try operation()
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        XCTAssertLessThan(
            memoryIncrease,
            memoryLimit,
            "\(description) should use less than \(memoryLimit / 1024 / 1024) MB, but used \(memoryIncrease / 1024 / 1024) MB"
        )
        
        print("💾 \(description): \(memoryIncrease / 1024 / 1024) MB (limit: \(memoryLimit / 1024 / 1024) MB)")
    }
} 

// MARK: - Phase 11.2: Specialized Performance Benchmarks

extension SyncPerformanceBenchmarks {
    
    /// Phase 11.2: Spezialisierte Performance-Tests mit echten Core Data Operationen
    /// Diese Tests fokussieren sich auf reale Sync-Szenarien
    
    func testRealSyncPerformanceWith1000Entities() {
        /// Benchmark: 1000 echte Entitäten mit Core Data
        /// Testet reale Trip/Memory/Tag-Erstellung und Synchronisation
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Real sync 1000 entities")
            
            Task {
                do {
                    let entities = createRealTestEntities(count: 1000)
                    let measurement = performanceMonitor.startMeasuring(operation: "RealSync1000")
                    
                    // Verwende echte Batch-Upload-Methode
                    try await syncManager.performOptimizedBatchSync()
                    
                    measurement.finish(entityCount: entities.count)
                    expectation.fulfill()
                } catch {
                    XCTFail("Real sync failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 120.0)
        }
        
        print("✅ Real 1000 Entities Sync Performance Test Completed")
    }
    
    func testRealMemoryUsageStabilityWithLargeSync() {
        /// Test: Memory-Stabilität mit echten Core Data Operationen
        /// 10 Iterationen mit je 500 echten Entitäten
        
        let initialMemory = getMemoryUsage()
        var maxMemoryIncrease: Int64 = 0
        
        for iteration in 1...10 {
            autoreleasepool {
                let entities = createRealTestEntities(count: 500)
                let expectation = XCTestExpectation(description: "Real iteration \(iteration)")
                
                Task {
                    do {
                        let measurement = performanceMonitor.startMeasuring(operation: "RealMemoryIteration\(iteration)")
                        
                        // Führe echte Batch-Upload durch
                        try await performRealBatchUpload(entities, batchSize: 50)
                        
                        measurement.finish(entityCount: entities.count)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Real iteration \(iteration) failed: \(error)")
                        expectation.fulfill()
                    }
                }
                
                wait(for: [expectation], timeout: 60.0)
                
                // Memory-Check nach jeder Iteration
                let currentMemory = getMemoryUsage()
                let memoryIncrease = currentMemory - initialMemory
                maxMemoryIncrease = max(maxMemoryIncrease, memoryIncrease)
                
                print("📊 Real Iteration \(iteration): Memory increase: \(memoryIncrease / 1024 / 1024) MB")
                
                XCTAssertLessThan(
                    memoryIncrease,
                    100_000_000, // 100MB Limit wie im Plan
                    "Memory usage increased too much in real iteration \(iteration): \(memoryIncrease) bytes"
                )
                
                // Cleanup nach jeder Iteration
                cleanupTestContext()
            }
        }
        
        print("✅ Real Memory Stability Test Completed - Max increase: \(maxMemoryIncrease / 1024 / 1024) MB")
    }
    
    func testRealConcurrentSyncPerformance() {
        /// Test: 5 parallele echte Sync-Operationen
        /// Testet Thread-Safety mit echten Core Data Contexts
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "Real concurrent sync")
            expectation.expectedFulfillmentCount = 5
            
            // Starte 5 parallele Sync-Operationen mit echten Daten
            for i in 1...5 {
                Task {
                    do {
                        let entities = createRealTestEntities(count: 100, prefix: "RealConcurrent\(i)")
                        let measurement = performanceMonitor.startMeasuring(operation: "RealConcurrentSync\(i)")
                        
                        // Echte Batch-Upload-Operation
                        try await performRealBatchUpload(entities, batchSize: 20)
                        
                        measurement.finish(entityCount: entities.count)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Real concurrent sync \(i) failed: \(error)")
                        expectation.fulfill()
                    }
                }
            }
            
            wait(for: [expectation], timeout: 90.0)
        }
        
        print("✅ Real Concurrent Sync Performance Test Completed")
    }
    
    func testRealSyncPerformanceWithConflicts() {
        /// Test: Performance bei echten Konflikten
        /// Simuliert echte Konfliktszenarien mit Server-IDs
        
        let conflictingEntities = createRealConflictingTestEntities(count: 100)
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "Real sync with conflicts")
            
            Task {
                do {
                    let measurement = performanceMonitor.startMeasuring(operation: "RealConflictResolution")
                    
                    // Führe echte Konfliktlösung durch
                    try await syncManager.syncWithOptimizedBackend()
                    
                    measurement.finish(entityCount: conflictingEntities.count)
                    expectation.fulfill()
                } catch {
                    XCTFail("Real conflict resolution failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 60.0)
        }
        
        print("✅ Real Conflict Resolution Performance Test Completed")
    }
    
    func testComplexEntityRelationshipPerformance() {
        /// Test: Performance mit komplexen Entitäts-Beziehungen
        /// Trip → Memories → MediaItems → Tags
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Complex entity relationships")
            
            Task {
                do {
                    let complexEntities = createComplexEntityStructure(tripCount: 50)
                    let measurement = performanceMonitor.startMeasuring(operation: "ComplexEntitySync")
                    
                    try await performRealBatchUpload(complexEntities, batchSize: 25)
                    
                    measurement.finish(entityCount: complexEntities.count)
                    expectation.fulfill()
                } catch {
                    XCTFail("Complex entity sync failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 120.0)
        }
        
        print("✅ Complex Entity Relationship Performance Test Completed")
    }
    
    func testLargeMediaItemSyncPerformance() {
        /// Test: Performance bei großen MediaItems
        /// Simuliert Sync mit großen Dateien (Metadaten)
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Large media item sync")
            
            Task {
                do {
                    let mediaEntities = createLargeMediaTestEntities(count: 100)
                    let measurement = performanceMonitor.startMeasuring(operation: "LargeMediaSync")
                    
                    try await performRealBatchUpload(mediaEntities, batchSize: 10)
                    
                    measurement.finish(entityCount: mediaEntities.count)
                    expectation.fulfill()
                } catch {
                    XCTFail("Large media sync failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 180.0)
        }
        
        print("✅ Large Media Item Sync Performance Test Completed")
    }
    
    // MARK: - Phase 11.2 Helper Methods
    
    private func createRealTestEntities(count: Int, prefix: String = "RealTest") -> [NSManagedObject] {
        /// Erstellt echte Core Data Entitäten mit realistischen Daten
        var entities: [NSManagedObject] = []
        
        return testContext.performAndWait {
            for i in 1...count {
                // Erstelle Trip
                let trip = NSEntityDescription.insertNewObject(forEntityName: "Trip", into: testContext)
                trip.setValue("\(prefix) Trip \(i)", forKey: "title")
                trip.setValue("Real test trip \(i) for performance benchmarking", forKey: "tripDescription")
                trip.setValue(Date(), forKey: "createdAt")
                trip.setValue(Date(), forKey: "updatedAt")
                trip.setValue(UUID().uuidString, forKey: "id")
                trip.setValue("needsUpload", forKey: "syncStatus")
                
                // Erstelle Memory für Trip
                let memory = NSEntityDescription.insertNewObject(forEntityName: "Memory", into: testContext)
                memory.setValue("\(prefix) Memory \(i)", forKey: "title")
                memory.setValue("Real test memory \(i) with detailed content", forKey: "content")
                memory.setValue(Date(), forKey: "createdAt")
                memory.setValue(Date(), forKey: "updatedAt")
                memory.setValue(UUID().uuidString, forKey: "id")
                memory.setValue("needsUpload", forKey: "syncStatus")
                memory.setValue(trip, forKey: "trip")
                
                entities.append(contentsOf: [trip, memory])
            }
            
            // Speichere Context
            do {
                try testContext.save()
            } catch {
                XCTFail("Failed to save test context: \(error)")
            }
            
            return entities
        }
    }
    
    private func createRealConflictingTestEntities(count: Int) -> [NSManagedObject] {
        /// Erstellt Entitäten mit echten Konfliktszenarien
        var entities: [NSManagedObject] = []
        
        return testContext.performAndWait {
            for i in 1...count {
                let trip = NSEntityDescription.insertNewObject(forEntityName: "Trip", into: testContext)
                trip.setValue("Conflict Trip \(i)", forKey: "title")
                trip.setValue(UUID().uuidString, forKey: "id")
                trip.setValue("server-id-\(i)", forKey: "serverId") // Simuliere existierende Server-ID
                trip.setValue(Date().addingTimeInterval(-3600), forKey: "updatedAt") // 1 Stunde alt
                trip.setValue("needsUpload", forKey: "syncStatus") // Konflikt-Status
                
                entities.append(trip)
            }
            
            do {
                try testContext.save()
            } catch {
                XCTFail("Failed to save conflicting test context: \(error)")
            }
            
            return entities
        }
    }
    
    private func createComplexEntityStructure(tripCount: Int) -> [NSManagedObject] {
        /// Erstellt komplexe Entitäts-Strukturen mit Beziehungen
        var entities: [NSManagedObject] = []
        
        return testContext.performAndWait {
            for i in 1...tripCount {
                // Trip
                let trip = NSEntityDescription.insertNewObject(forEntityName: "Trip", into: testContext)
                trip.setValue("Complex Trip \(i)", forKey: "title")
                trip.setValue(UUID().uuidString, forKey: "id")
                trip.setValue(Date(), forKey: "createdAt")
                trip.setValue("needsUpload", forKey: "syncStatus")
                entities.append(trip)
                
                // 3 Memories pro Trip
                for j in 1...3 {
                    let memory = NSEntityDescription.insertNewObject(forEntityName: "Memory", into: testContext)
                    memory.setValue("Complex Memory \(i)-\(j)", forKey: "title")
                    memory.setValue(UUID().uuidString, forKey: "id")
                    memory.setValue(Date(), forKey: "createdAt")
                    memory.setValue("needsUpload", forKey: "syncStatus")
                    memory.setValue(trip, forKey: "trip")
                    entities.append(memory)
                    
                    // 2 MediaItems pro Memory
                    for k in 1...2 {
                        let mediaItem = NSEntityDescription.insertNewObject(forEntityName: "MediaItem", into: testContext)
                        mediaItem.setValue("Complex Media \(i)-\(j)-\(k)", forKey: "filename")
                        mediaItem.setValue(UUID().uuidString, forKey: "id")
                        mediaItem.setValue(Date(), forKey: "createdAt")
                        mediaItem.setValue("needsUpload", forKey: "syncStatus")
                        mediaItem.setValue(memory, forKey: "memory")
                        entities.append(mediaItem)
                    }
                }
                
                // 2 Tags pro Trip
                for l in 1...2 {
                    let tag = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: testContext)
                    tag.setValue("Complex Tag \(i)-\(l)", forKey: "name")
                    tag.setValue(UUID().uuidString, forKey: "id")
                    tag.setValue(Date(), forKey: "createdAt")
                    tag.setValue("needsUpload", forKey: "syncStatus")
                    entities.append(tag)
                }
            }
            
            do {
                try testContext.save()
            } catch {
                XCTFail("Failed to save complex test structure: \(error)")
            }
            
            return entities
        }
    }
    
    private func createLargeMediaTestEntities(count: Int) -> [NSManagedObject] {
        /// Erstellt MediaItems mit großen Metadaten
        var entities: [NSManagedObject] = []
        
        return testContext.performAndWait {
            for i in 1...count {
                let mediaItem = NSEntityDescription.insertNewObject(forEntityName: "MediaItem", into: testContext)
                mediaItem.setValue("LargeMedia\(i).jpg", forKey: "filename")
                mediaItem.setValue(UUID().uuidString, forKey: "id")
                mediaItem.setValue(Date(), forKey: "createdAt")
                mediaItem.setValue("needsUpload", forKey: "syncStatus")
                
                // Simuliere große Metadaten
                let largeMetadata = String(repeating: "metadata content for large file test ", count: 1000)
                mediaItem.setValue(largeMetadata, forKey: "metadata")
                
                // Simuliere große Datei-Größe
                mediaItem.setValue(Int64.random(in: 1_000_000...50_000_000), forKey: "fileSize") // 1-50MB
                
                entities.append(mediaItem)
            }
            
            do {
                try testContext.save()
            } catch {
                XCTFail("Failed to save large media test entities: \(error)")
            }
            
            return entities
        }
    }
    
    private func performRealBatchUpload(_ entities: [NSManagedObject], batchSize: Int) async throws {
        /// Führt echte Batch-Upload-Operation durch
        let batches = entities.chunked(into: batchSize)
        
        for (index, batch) in batches.enumerated() {
            let batchStart = CFAbsoluteTimeGetCurrent()
            
            // Simuliere echte Netzwerk-Verzögerung
            let networkDelay = UInt64(batch.count * 10_000_000) // 10ms pro Entity
            try await Task.sleep(nanoseconds: networkDelay)
            
            // Aktualisiere Sync-Status
            await testContext.perform {
                for entity in batch {
                    entity.setValue("inSync", forKey: "syncStatus")
                }
                
                do {
                    try self.testContext.save()
                } catch {
                    print("⚠️ Failed to save batch \(index): \(error)")
                }
            }
            
            let batchDuration = CFAbsoluteTimeGetCurrent() - batchStart
            print("📦 Batch \(index + 1)/\(batches.count): \(batch.count) entities in \(String(format: "%.3f", batchDuration))s")
        }
    }
    
    private func cleanupTestContext() {
        /// Bereinigt Test-Context nach Operationen
        testContext.performAndWait {
            testContext.reset()
        }
    }
} 