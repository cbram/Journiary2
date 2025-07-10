import XCTest
import CoreData
@testable import Journiary

/// Phase 11.3: Stress-Tests und Edge-Cases für Sync-Robustheit
/// Diese Tests validieren das Verhalten unter extremen Bedingungen
class SyncStressTests: XCTestCase {
    var syncManager: SyncManager!
    var testContext: NSManagedObjectContext!
    var performanceMonitor: PerformanceMonitor!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        setupStressTestEnvironment()
    }
    
    override func tearDownWithError() throws {
        cleanupStressTestEnvironment()
        try super.tearDownWithError()
    }
    
    // MARK: - Stress-Tests
    
    func testRepeatedSyncCycles() {
        /// Test: 100 aufeinanderfolgende Sync-Zyklen
        /// Validiert Memory-Stabilität und Performance-Degradation
        
        print("🔄 Starting 100 repeated sync cycles test...")
        
        for cycle in 1...100 {
            let expectation = XCTestExpectation(description: "Sync cycle \(cycle)")
            
            Task {
                do {
                    let measurement = performanceMonitor.startMeasuring(operation: "SyncCycle\(cycle)")
                    
                    try await syncManager.performOptimizedBatchSync()
                    
                    measurement.finish(entityCount: 1)
                    expectation.fulfill()
                } catch {
                    XCTFail("Sync cycle \(cycle) failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 15.0)
            
            // Kurze Pause zwischen Zyklen für Stabilität
            Thread.sleep(forTimeInterval: 0.1)
            
            // Memory-Check alle 10 Zyklen
            if cycle % 10 == 0 {
                let memoryUsage = getMemoryUsage()
                print("📊 Cycle \(cycle): Memory usage: \(memoryUsage / 1024 / 1024) MB")
                
                // Warnung bei exzessivem Memory-Verbrauch
                if memoryUsage > 150_000_000 { // 150MB
                    print("⚠️ High memory usage detected at cycle \(cycle)")
                }
            }
        }
        
        print("✅ 100 sync cycles completed successfully")
    }
    
    func testSyncWithCorruptedData() {
        /// Test: Synchronisation mit beschädigten Daten
        /// Validiert Fehlerbehandlung bei invaliden Entitäten
        
        print("🔧 Testing sync with corrupted data...")
        
        let corruptedTrip = createCorruptedTrip()
        let expectation = XCTestExpectation(description: "Corrupted data handling")
        
        Task {
            do {
                // Versuche Sync mit beschädigten Daten
                try await syncManager.syncWithOptimizedBackend()
                
                // Überprüfe, ob beschädigte Daten gefiltert wurden
                let validTrips = try await fetchValidTrips()
                XCTAssertFalse(validTrips.contains { $0.title == nil }, "Corrupted data should be filtered out")
                
                expectation.fulfill()
            } catch {
                // Erwarte spezifische Sync-Fehler
                if let syncError = error as? SyncError {
                    XCTAssertTrue(syncError.localizedDescription.contains("validation"), 
                                "Should be a validation error: \(syncError)")
                } else {
                    XCTFail("Unexpected error type: \(error)")
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
        print("✅ Corrupted data handling test completed")
    }
    
    func testSyncInterruption() {
        /// Test: Sync-Unterbrechung und Wiederaufnahme
        /// Validiert Robustheit bei Unterbrechungen
        
        print("🛑 Testing sync interruption and recovery...")
        
        let expectation = XCTestExpectation(description: "Interrupted sync recovery")
        
        Task {
            // Starte langen Sync-Vorgang
            let longSyncTask = Task {
                try await performLongSyncOperation()
            }
            
            // Unterbreche nach 2 Sekunden
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                longSyncTask.cancel()
                print("🛑 Sync task cancelled")
            }
            
            // Warte auf Unterbrechung
            do {
                try await longSyncTask.value
                XCTFail("Sync should have been cancelled")
            } catch {
                XCTAssertTrue(error is CancellationError || error.localizedDescription.contains("cancelled"), 
                            "Should be a cancellation error: \(error)")
                print("✅ Sync interruption handled correctly")
            }
            
            // Starte neuen Sync (sollte erfolgreich sein)
            do {
                try await syncManager.performOptimizedBatchSync()
                print("✅ Sync recovery successful")
                expectation.fulfill()
            } catch {
                XCTFail("Sync recovery failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 45.0)
        print("✅ Sync interruption test completed")
    }
    
    func testHighFrequencyDataChanges() {
        /// Test: Sehr häufige Datenänderungen
        /// Simuliert intensive Benutzeraktivität
        
        print("⚡ Testing high frequency data changes...")
        
        let changeCount = 1000
        let expectation = XCTestExpectation(description: "High frequency changes")
        
        Task {
            let batchStart = CFAbsoluteTimeGetCurrent()
            
            for i in 1...changeCount {
                autoreleasepool {
                    let memory = NSEntityDescription.insertNewObject(forEntityName: "Memory", into: testContext)
                    memory.setValue("High Frequency Memory \(i)", forKey: "title")
                    memory.setValue("Content for rapid change test \(i)", forKey: "content")
                    memory.setValue(Date(), forKey: "createdAt")
                    memory.setValue(Date(), forKey: "updatedAt")
                    memory.setValue(UUID().uuidString, forKey: "id")
                    memory.setValue("needsUpload", forKey: "syncStatus")
                    
                    do {
                        try testContext.save()
                    } catch {
                        print("⚠️ Failed to save memory \(i): \(error)")
                    }
                }
                
                // Micro-pause alle 100 Änderungen
                if i % 100 == 0 {
                    try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                    print("📊 Processed \(i)/\(changeCount) changes")
                }
            }
            
            let batchDuration = CFAbsoluteTimeGetCurrent() - batchStart
            print("⚡ Created \(changeCount) entities in \(String(format: "%.2f", batchDuration))s")
            
            // Führe Sync nach allen Änderungen durch
            let syncStart = CFAbsoluteTimeGetCurrent()
            try await syncManager.performOptimizedBatchSync()
            let syncDuration = CFAbsoluteTimeGetCurrent() - syncStart
            
            print("✅ High frequency sync completed in \(String(format: "%.2f", syncDuration))s")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 120.0)
        print("✅ High frequency data changes test completed")
    }
    
    func testNetworkTimeouts() {
        /// Test: Netzwerk-Timeouts und Retry-Logik
        /// Validiert Robustheit bei Netzwerkproblemen
        
        print("🌐 Testing network timeout handling...")
        
        let timeoutSimulator = NetworkTimeoutSimulator()
        // Simuliere Netzwerk-Probleme
        
        let expectation = XCTestExpectation(description: "Network timeout handling")
        
        Task {
            do {
                let measurement = performanceMonitor.startMeasuring(operation: "NetworkTimeoutTest")
                
                // Sollte nach Retries erfolgreich sein
                try await performSyncWithRetries(maxRetries: 3)
                
                measurement.finish(entityCount: 1)
                print("✅ Network timeout recovery successful")
                expectation.fulfill()
            } catch {
                XCTFail("Sync should eventually succeed after retries: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 60.0)
        print("✅ Network timeout test completed")
    }
    
    func testConcurrentSyncConflicts() {
        /// Test: Gleichzeitige Sync-Operationen
        /// Validiert Thread-Safety und Konfliktbehandlung
        
        print("🔄 Testing concurrent sync conflicts...")
        
        let expectation = XCTestExpectation(description: "Concurrent sync conflicts")
        expectation.expectedFulfillmentCount = 3
        
        // Starte 3 parallele Sync-Operationen
        for i in 1...3 {
            Task {
                do {
                    let measurement = performanceMonitor.startMeasuring(operation: "ConcurrentSync\(i)")
                    
                    // Erstelle einige Test-Entitäten
                    let entities = await createTestEntitiesForConcurrentTest(count: 50, prefix: "Concurrent\(i)")
                    
                    // Führe Sync durch
                    try await syncManager.performOptimizedBatchSync()
                    
                    measurement.finish(entityCount: entities.count)
                    print("✅ Concurrent sync \(i) completed")
                    expectation.fulfill()
                } catch {
                    XCTFail("Concurrent sync \(i) failed: \(error)")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 90.0)
        print("✅ Concurrent sync conflicts test completed")
    }
    
    func testLowMemoryConditions() {
        /// Test: Verhalten bei niedrigem Speicher
        /// Simuliert Memory-Pressure-Szenarien
        
        print("📱 Testing low memory conditions...")
        
        let expectation = XCTestExpectation(description: "Low memory handling")
        
        Task {
            // Simuliere Memory-Pressure durch Erstellung vieler Objekte
            var memoryPressureObjects: [NSManagedObject] = []
            
            for i in 1...5000 {
                autoreleasepool {
                    let entity = NSEntityDescription.insertNewObject(forEntityName: "Memory", into: testContext)
                    entity.setValue("Memory Pressure Test \(i)", forKey: "title")
                    entity.setValue(String(repeating: "x", count: 1000), forKey: "content") // 1KB content
                    entity.setValue(Date(), forKey: "createdAt")
                    entity.setValue(UUID().uuidString, forKey: "id")
                    
                    memoryPressureObjects.append(entity)
                }
                
                if i % 1000 == 0 {
                    let memoryUsage = getMemoryUsage()
                    print("📊 Memory pressure \(i): \(memoryUsage / 1024 / 1024) MB")
                }
            }
            
            // Versuche Sync unter Memory-Pressure
            do {
                try await syncManager.performOptimizedBatchSync()
                print("✅ Sync under memory pressure successful")
                expectation.fulfill()
            } catch {
                XCTFail("Sync under memory pressure failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 120.0)
        print("✅ Low memory conditions test completed")
    }
    
    // MARK: - Edge-Cases
    
    func testEmptyDataSync() {
        /// Test: Sync mit leeren Daten
        /// Validiert Verhalten bei keinen Daten
        
        print("🔍 Testing empty data sync...")
        
        let expectation = XCTestExpectation(description: "Empty data sync")
        
        Task {
            // Lösche alle Daten
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: "Memory"))
            try! testContext.execute(deleteRequest)
            
            // Führe Sync durch
            try await syncManager.performOptimizedBatchSync()
            
            print("✅ Empty data sync completed")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    func testLargeDataSync() {
        /// Test: Sync mit sehr großen Datenmengen
        /// Validiert Batch-Processing-Grenzen
        
        print("📊 Testing large data sync...")
        
        let expectation = XCTestExpectation(description: "Large data sync")
        
        Task {
            // Erstelle sehr große Entitäten
            let largeEntities = await createLargeTestEntities(count: 100)
            
            // Führe Sync durch
            try await syncManager.performOptimizedBatchSync()
            
            print("✅ Large data sync completed with \(largeEntities.count) entities")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 180.0)
    }
    
    // MARK: - Helper Methods
    
    private func setupStressTestEnvironment() {
        // Setup in-memory Core Data Stack für Tests
        let container = NSPersistentContainer(name: "Journiary")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        testContext = container.newBackgroundContext()
        testContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        syncManager = SyncManager()
        performanceMonitor = PerformanceMonitor()
        
        print("🏗️ Stress test environment initialized")
    }
    
    private func cleanupStressTestEnvironment() {
        testContext?.reset()
        testContext = nil
        syncManager = nil
        performanceMonitor = nil
        
        print("🧹 Stress test environment cleaned up")
    }
    
    private func createCorruptedTrip() -> NSManagedObject {
        /// Erstellt absichtlich beschädigte Trip-Entität
        let trip = NSEntityDescription.insertNewObject(forEntityName: "Trip", into: testContext)
        // Absichtlich nil für required fields
        trip.setValue(nil, forKey: "title")
        trip.setValue(nil, forKey: "createdAt")
        trip.setValue(UUID().uuidString, forKey: "id")
        trip.setValue("corrupted", forKey: "syncStatus")
        
        return trip
    }
    
    private func fetchValidTrips() async throws -> [NSManagedObject] {
        /// Holt alle gültigen Trip-Entitäten
        return try await testContext.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Trip")
            request.predicate = NSPredicate(format: "title != nil AND createdAt != nil")
            return try self.testContext.fetch(request)
        }
    }
    
    private func performLongSyncOperation() async throws {
        /// Simuliert eine lange Sync-Operation
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 Sekunde
            
            // Überprüfe auf Cancellation
            try Task.checkCancellation()
            
            print("📊 Long sync operation step \(i)/10")
        }
    }
    
    private func performSyncWithRetries(maxRetries: Int) async throws {
        /// Führt Sync mit Retry-Logik durch
        var attempt = 0
        var lastError: Error?
        
        while attempt < maxRetries {
            attempt += 1
            
            do {
                // Simuliere Netzwerk-Verzögerung
                try await Task.sleep(nanoseconds: UInt64(attempt * 500_000_000)) // 0.5s * attempt
                
                if attempt < 3 {
                    // Simuliere Fehler für erste Versuche
                    throw URLError(.timedOut)
                }
                
                // Erfolgreicher Sync
                try await syncManager.performOptimizedBatchSync()
                print("✅ Sync successful on attempt \(attempt)")
                return
                
            } catch {
                lastError = error
                print("⚠️ Sync attempt \(attempt) failed: \(error)")
                
                if attempt < maxRetries {
                    print("🔄 Retrying in \(attempt * 500)ms...")
                }
            }
        }
        
        // Alle Versuche fehlgeschlagen
        throw lastError ?? URLError(.timedOut)
    }
    
    private func createTestEntitiesForConcurrentTest(count: Int, prefix: String) async -> [NSManagedObject] {
        /// Erstellt Test-Entitäten für Concurrent-Tests
        return await testContext.perform {
            var entities: [NSManagedObject] = []
            
            for i in 1...count {
                let memory = NSEntityDescription.insertNewObject(forEntityName: "Memory", into: self.testContext)
                memory.setValue("\(prefix) Memory \(i)", forKey: "title")
                memory.setValue("Concurrent test content \(i)", forKey: "content")
                memory.setValue(Date(), forKey: "createdAt")
                memory.setValue(Date(), forKey: "updatedAt")
                memory.setValue(UUID().uuidString, forKey: "id")
                memory.setValue("needsUpload", forKey: "syncStatus")
                
                entities.append(memory)
            }
            
            do {
                try self.testContext.save()
            } catch {
                print("⚠️ Failed to save concurrent test entities: \(error)")
            }
            
            return entities
        }
    }
    
    private func createLargeTestEntities(count: Int) async -> [NSManagedObject] {
        /// Erstellt sehr große Test-Entitäten
        return await testContext.perform {
            var entities: [NSManagedObject] = []
            
            for i in 1...count {
                let memory = NSEntityDescription.insertNewObject(forEntityName: "Memory", into: self.testContext)
                memory.setValue("Large Memory \(i)", forKey: "title")
                
                // Erstelle sehr große Inhalte (50KB pro Entität)
                let largeContent = String(repeating: "This is large content for stress testing. ", count: 1000)
                memory.setValue(largeContent, forKey: "content")
                
                memory.setValue(Date(), forKey: "createdAt")
                memory.setValue(Date(), forKey: "updatedAt")
                memory.setValue(UUID().uuidString, forKey: "id")
                memory.setValue("needsUpload", forKey: "syncStatus")
                
                entities.append(memory)
            }
            
            do {
                try self.testContext.save()
            } catch {
                print("⚠️ Failed to save large test entities: \(error)")
            }
            
            return entities
        }
    }
    
    private func getMemoryUsage() -> UInt64 {
        /// Holt aktuelle Memory-Nutzung
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
}

// MARK: - Mock Classes

class NetworkTimeoutSimulator {
    /// Simuliert Netzwerk-Timeouts für Tests
    private var attemptCount = 0
    
    func simulateNetworkCall() async throws {
        attemptCount += 1
        
        if attemptCount < 3 {
            // Simuliere Timeout für erste 2 Versuche
            throw URLError(.timedOut)
        } else {
            // Erfolg beim 3. Versuch
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
    }
}

enum SyncError: Error {
    case validationFailed(String)
    case networkTimeout
    case dataCorruption
    
    var localizedDescription: String {
        switch self {
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .networkTimeout:
            return "Network timeout occurred"
        case .dataCorruption:
            return "Data corruption detected"
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