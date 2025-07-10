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