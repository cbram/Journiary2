//
//  MultiUserPerformanceTests.swift
//  JourniaryTests
//
//  Created by TravelCompanion AI on 28.12.24.
//

import XCTest
import CoreData
import CoreLocation
import Foundation
@testable import Journiary

@MainActor
class MultiUserPerformanceTests: XCTestCase {
    
    // MARK: - Properties
    
    var persistentContainer: NSPersistentContainer!
    var context: NSManagedObjectContext!
    var performanceMetrics: PerformanceMetrics!
    
    // Configuration properties
    var testUsersCount: Int = 50
    var tripsPerUser: Int = 25
    var memoriesPerTrip: Int = 8
    var systemTagsCount: Int = 200
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // In-Memory Core Data Stack für Performance Tests
        persistentContainer = NSPersistentContainer(name: "Journiary")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        
        persistentContainer.persistentStoreDescriptions = [description]
        
        let expectation = self.expectation(description: "Store loaded")
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                XCTFail("Failed to load test store: \(error)")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10.0)
        
        context = persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true
        performanceMetrics = PerformanceMetrics()
        
        print("\n🚀 Performance Test Setup Complete")
        print("📊 Configuration:")
        print("   👥 Users: \(testUsersCount)")
        print("   🗺️  Trips per User: \(tripsPerUser)")
        print("   💭 Memories per Trip: \(memoriesPerTrip)")
        print("   🏷️  System Tags: \(systemTagsCount)")
    }
    
    override func tearDownWithError() throws {
        performanceMetrics.printSummary()
        
        persistentContainer = nil
        context = nil
        performanceMetrics = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Main Performance Test
    
    func testMultiUserPerformanceFullSuite() throws {
        let testStartTime = CFAbsoluteTimeGetCurrent()
        
        print("\n" + String(repeating: "=", count: 80))
        print("🔥 MULTI-USER PERFORMANCE TEST SUITE")
        print(String(repeating: "=", count: 80))
        
        // Phase 1: Data Generation
        try performDataGeneration()
        
        // Phase 2: Query Performance Tests
        try performQueryPerformanceTests()
        
        // Phase 3: Memory Usage Tests
        try performMemoryUsageTests()
        
        // Phase 4: Concurrent Access Tests
        try performConcurrentAccessTests()
        
        // Phase 5: Bulk Operations Tests
        try performBulkOperationTests()
        
        let totalDuration = CFAbsoluteTimeGetCurrent() - testStartTime
        print("\n✅ Performance Test Suite Completed in \(String(format: "%.2f", totalDuration))s")
    }
    
    // MARK: - Phase 1: Data Generation
    
    private func performDataGeneration() throws {
        print("\n📝 Phase 1: Data Generation")
        print(String(repeating: "-", count: 40))
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var totalTrips = 0
        var totalMemories = 0
        
        // Create system tag categories first
        let tagCategories = try createSystemTagCategories()
        
        // Create system tags
        try createSystemTags(with: tagCategories)
        
        // Create users and their data
        for userIndex in 1...testUsersCount {
            let user = createTestUser(index: userIndex)
            
            for tripIndex in 1...tripsPerUser {
                let trip = createTestTrip(for: user, index: tripIndex)
                totalTrips += 1
                
                for memoryIndex in 1...memoriesPerTrip {
                    createTestMemory(for: trip, user: user, index: memoryIndex)
                    totalMemories += 1
                }
            }
            
            if userIndex % 10 == 0 {
                print("   📊 Created \(userIndex) users with \(totalTrips) trips and \(totalMemories) memories")
            }
        }
        
        try context.save()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        print("✅ Data Generation Complete:")
        print("   ⏱️  Duration: \(String(format: "%.2f", duration))s")
        print("   👥 Users: \(testUsersCount)")
        print("   🗺️  Trips: \(totalTrips)")
        print("   💭 Memories: \(totalMemories)")
        print("   🏷️  Tags: \(systemTagsCount)")
        
        performanceMetrics.recordDataGeneration(
            duration: duration,
            users: testUsersCount,
            trips: totalTrips,
            memories: totalMemories
        )
    }
    
    // MARK: - Phase 2: Query Performance Tests
    
    private func performQueryPerformanceTests() throws {
        print("\n🔍 Phase 2: Query Performance Tests")
        print(String(repeating: "-", count: 40))
        
        let allUsers = try fetchAllUsers()
        let sampleUsers = Array(allUsers.prefix(10)) // Test with first 10 users
        
        for user in sampleUsers {
            // Test user-specific trip queries
            try testUserTripQueries(for: user)
            
            // Test user-specific memory queries
            try testUserMemoryQueries(for: user)
            
            // Test complex multi-relationship queries
            try testComplexQueries(for: user)
        }
        
        print("✅ Query Performance Tests Complete")
    }
    
    private func testUserTripQueries(for user: User) throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let request = NSFetchRequest<Trip>(entityName: "Trip")
        request.predicate = NSPredicate(format: "owner == %@", user)
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        let trips = try context.fetch(request)
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        performanceMetrics.recordQuery(
            type: "UserTrips",
            duration: duration,
            resultCount: trips.count,
            user: user.username ?? "unknown"
        )
        
        // Validate performance threshold
        XCTAssertLessThan(duration, 100.0, "User trips query took \(duration)ms, exceeding 100ms threshold")
    }
    
    private func testUserMemoryQueries(for user: User) throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let request = NSFetchRequest<Memory>(entityName: "Memory")
        request.predicate = NSPredicate(format: "creator == %@", user)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = 50
        
        let memories = try context.fetch(request)
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        performanceMetrics.recordQuery(
            type: "UserMemories",
            duration: duration,
            resultCount: memories.count,
            user: user.username ?? "unknown"
        )
        
        XCTAssertLessThan(duration, 100.0, "User memories query took \(duration)ms, exceeding 100ms threshold")
    }
    
    private func testComplexQueries(for user: User) throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let request = NSFetchRequest<Trip>(entityName: "Trip")
        request.predicate = NSPredicate(format: "owner == %@ AND memories.@count > 5", user)
        request.relationshipKeyPathsForPrefetching = ["memories", "memories.tags"]
        
        let trips = try context.fetch(request)
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        performanceMetrics.recordQuery(
            type: "ComplexQuery",
            duration: duration,
            resultCount: trips.count,
            user: user.username ?? "unknown"
        )
        
        XCTAssertLessThan(duration, 100.0, "Complex query took \(duration)ms, exceeding 100ms threshold")
    }
    
    // MARK: - Phase 3: Memory Usage Tests
    
    private func performMemoryUsageTests() throws {
        print("\n🧠 Phase 3: Memory Usage Tests")
        print(String(repeating: "-", count: 40))
        
        let initialMemory = getMemoryUsage()
        
        // Test large result set handling
        try testLargeResultSetHandling()
        
        // Test batch processing
        try testBatchProcessing()
        
        // Test memory cleanup
        try testMemoryCleanup()
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        print("✅ Memory Usage Tests Complete:")
        print("   📊 Initial: \(formatMemoryUsage(initialMemory))")
        print("   📊 Final: \(formatMemoryUsage(finalMemory))")
        print("   📈 Increase: \(formatMemoryUsage(memoryIncrease))")
        
        performanceMetrics.recordMemoryUsage(initial: initialMemory, final: finalMemory)
        
        // Validate memory usage threshold
        let maxMemoryIncrease: Int64 = 100 * 1024 * 1024 // 100MB
        XCTAssertLessThan(memoryIncrease, maxMemoryIncrease, 
                         "Memory increase of \(formatMemoryUsage(memoryIncrease)) exceeds 100MB threshold")
    }
    
    private func testLargeResultSetHandling() throws {
        print("   📊 Testing Large Result Set Handling...")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let request = NSFetchRequest<Memory>(entityName: "Memory")
        request.fetchBatchSize = 100
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let memories = try context.fetch(request)
        
        // Process memories in batches to test memory efficiency
        for memoriesBatch in memories.chunked(into: 100) {
            for memory in memoriesBatch {
                _ = memory.text // Access text to trigger fault
            }
            context.reset() // Clear memory
        }
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("     ✅ Processed \(memories.count) memories in \(String(format: "%.2f", duration))ms")
    }
    
    private func testBatchProcessing() throws {
        print("   📦 Testing Batch Processing...")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let request = NSFetchRequest<Trip>(entityName: "Trip")
        request.fetchBatchSize = 50
        
        let trips = try context.fetch(request)
        
        for tripsBatch in trips.chunked(into: 50) {
            for trip in tripsBatch {
                trip.name = trip.name?.appending(" - Updated")
            }
            try context.save()
            context.reset()
        }
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("     ✅ Batch processed \(trips.count) trips in \(String(format: "%.2f", duration))ms")
    }
    
    private func testMemoryCleanup() throws {
        print("   🧹 Testing Memory Cleanup...")
        
        let beforeCleanup = getMemoryUsage()
        
        // Force garbage collection and context reset
        context.reset()
        
        // Wait a moment for cleanup
        Thread.sleep(forTimeInterval: 0.5)
        
        let afterCleanup = getMemoryUsage()
        let cleaned = beforeCleanup - afterCleanup
        
        if cleaned > 0 {
            print("     ✅ Cleaned up \(formatMemoryUsage(cleaned)) of memory")
        } else {
            print("     ℹ️  No significant memory cleanup detected")
        }
    }
    
    // MARK: - Phase 4: Concurrent Access Tests
    
    private func performConcurrentAccessTests() throws {
        print("\n🔄 Phase 4: Concurrent Access Tests")
        print(String(repeating: "-", count: 40))
        
        let allUsers = try fetchAllUsers()
        let testUsers = Array(allUsers.prefix(5)) // Test with 5 users concurrently
        
        let group = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "concurrent-test-queue", attributes: .concurrent)
        
        for user in testUsers {
            group.enter()
            concurrentQueue.async {
                defer { group.leave() }
                
                do {
                    try self.performConcurrentUserQueries(for: user)
                } catch {
                    print("❌ Error in concurrent query for user \(user.username ?? "unknown"): \(error)")
                }
            }
        }
        
        group.wait()
        print("✅ Concurrent Access Tests Complete")
    }
    
    private func performConcurrentUserQueries(for user: User) throws {
        let backgroundContext = persistentContainer.newBackgroundContext()
        
        var tripsCount = 0
        var memoriesCount = 0
        
        try backgroundContext.performAndWait {
            // Fetch user's trips
            let tripsRequest = NSFetchRequest<Trip>(entityName: "Trip")
            tripsRequest.predicate = NSPredicate(format: "owner.username == %@", user.username ?? "")
            tripsCount = try backgroundContext.fetch(tripsRequest).count
            
            // Fetch user's memories
            let memoriesRequest = NSFetchRequest<Memory>(entityName: "Memory")
            memoriesRequest.predicate = NSPredicate(format: "creator.username == %@", user.username ?? "")
            memoriesCount = try backgroundContext.fetch(memoriesRequest).count
        }
        
        performanceMetrics.recordConcurrentQuery(
            user: user.username ?? "unknown",
            tripsCount: tripsCount,
            memoriesCount: memoriesCount
        )
    }
    
    // MARK: - Phase 5: Bulk Operations Tests
    
    private func performBulkOperationTests() throws {
        print("\n📦 Phase 5: Bulk Operations Tests")
        print(String(repeating: "-", count: 40))
        
        try testBulkInsertPerformance()
        try testBulkUpdatePerformance()
        try testBulkDeletePerformance()
        
        print("✅ Bulk Operations Tests Complete")
    }
    
    private func testBulkInsertPerformance() throws {
        print("   ➕ Testing Bulk Insert Performance...")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let insertTime: CFAbsoluteTime
        
        // Create test user for bulk trips
        let testUser = createTestUser(index: 9999)
        
        // Create 100 test trips in bulk
        for i in 1...100 {
            let trip = Trip(context: context)
            trip.id = UUID()
            trip.name = "Bulk Insert Test Trip \(i)"
            trip.startDate = Date()
            trip.endDate = Date().addingTimeInterval(86400) // +1 day
            trip.owner = testUser
        }
        
        insertTime = CFAbsoluteTimeGetCurrent()
        try context.save()
        let saveTime = CFAbsoluteTimeGetCurrent()
        
        let insertDuration = (insertTime - startTime) * 1000
        let saveDuration = (saveTime - insertTime) * 1000
        let totalDuration = (saveTime - startTime) * 1000
        
        print("     📊 Results: Insert: \(String(format: "%.2f", insertDuration))ms, Save: \(String(format: "%.2f", saveDuration))ms, Total: \(String(format: "%.2f", totalDuration))ms")
        
        performanceMetrics.recordBulkOperation(type: "Insert", duration: totalDuration, count: 100)
    }
    
    private func testBulkUpdatePerformance() throws {
        print("   ✏️ Testing Bulk Update Performance...")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let request = NSFetchRequest<Trip>(entityName: "Trip")
        request.predicate = NSPredicate(format: "name CONTAINS 'Bulk Insert Test'")
        
        let tripsToUpdate = try context.fetch(request)
        
        for trip in tripsToUpdate {
            trip.name = trip.name?.replacingOccurrences(of: "Bulk Insert Test", with: "Bulk Updated")
        }
        
        try context.save()
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("     📊 Updated \(tripsToUpdate.count) trips in \(String(format: "%.2f", duration))ms")
        
        performanceMetrics.recordBulkOperation(type: "Update", duration: duration, count: tripsToUpdate.count)
    }
    
    private func testBulkDeletePerformance() throws {
        print("   🗑️ Testing Bulk Delete Performance...")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let request = NSFetchRequest<Trip>(entityName: "Trip")
        request.predicate = NSPredicate(format: "name CONTAINS 'Bulk Updated'")
        
        let tripsToDelete = try context.fetch(request)
        
        for trip in tripsToDelete {
            context.delete(trip)
        }
        
        try context.save()
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("     📊 Deleted \(tripsToDelete.count) trips in \(String(format: "%.2f", duration))ms")
        
        performanceMetrics.recordBulkOperation(type: "Delete", duration: duration, count: tripsToDelete.count)
    }
    
    // MARK: - Helper Methods
    
    private func fetchAllUsers() throws -> [User] {
        let request = NSFetchRequest<User>(entityName: "User")
        return try context.fetch(request)
    }
    
    private func createSystemTagCategories() throws -> [TagCategory] {
        let categoryNames = ["🏞️ Nature", "🏙️ City", "🍕 Food", "🎭 Culture", "🏖️ Beach", "⛰️ Mountain"]
        var categories: [TagCategory] = []
        
        for (index, categoryName) in categoryNames.enumerated() {
            let category = TagCategory(context: context)
            category.id = UUID()
            category.name = categoryName
            category.displayName = categoryName
            category.emoji = String(categoryName.prefix(2))
            category.color = "blue"
            category.isSystemCategory = true
            category.sortOrder = Int32(index)
            category.createdAt = Date()
            categories.append(category)
        }
        
        try context.save()
        return categories
    }
    
    private func createSystemTags(with categories: [TagCategory]) throws {
        let tagEmojis = ["🌅", "🌲", "🏰", "🍝", "🎨", "🏊", "🥾", "📸", "🎵", "🌟"]
        
        for i in 1...systemTagsCount {
            let tag = Tag(context: context)
            tag.id = UUID()
            tag.name = "\(tagEmojis.randomElement()!) Tag \(i)"
            tag.displayName = tag.name
            tag.emoji = tagEmojis.randomElement()
            tag.color = "blue"
            tag.category = categories.randomElement()
            tag.isSystemTag = true
            tag.usageCount = Int32.random(in: 1...100)
            tag.sortOrder = Int32(i)
            tag.createdAt = Date()
        }
        
        try context.save()
    }
    
    private func createTestUser(index: Int) -> User {
        let user = User(context: context)
        user.id = UUID()
        user.username = "testuser\(index)"
        user.email = "testuser\(index)@example.com"
        user.firstName = "Test"
        user.lastName = "User \(index)"
        user.createdAt = Date()
        user.isCurrentUser = (index == 1)
        return user
    }
    
    private func createTestTrip(for user: User, index: Int) -> Trip {
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.name = "Trip \(index) by \(user.username ?? "unknown")"
        trip.startDate = Date().addingTimeInterval(TimeInterval(-index * 86400))
        trip.endDate = trip.startDate?.addingTimeInterval(TimeInterval.random(in: 86400...604800))
        trip.owner = user
        trip.isActive = (index <= 3) // First 3 trips are active
        trip.totalDistance = Double.random(in: 100000...5000000) // 100km to 5000km in meters
        return trip
    }
    
    private func createTestMemory(for trip: Trip, user: User, index: Int) -> Memory {
        let memory = Memory(context: context)
        memory.title = "Memory \(index) for \(trip.name ?? "unknown trip")"
        memory.text = "This is test content for memory \(index). It contains some sample text to simulate real memory data."
        memory.timestamp = Date().addingTimeInterval(TimeInterval(-index * 3600))
        memory.latitude = Double.random(in: 35...55) // Europe range
        memory.longitude = Double.random(in: -10...25)
        memory.locationName = "Test Location \(index)"
        memory.trip = trip
        memory.creator = user
        return memory
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
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
    
    private func formatMemoryUsage(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Performance Metrics Helper

class PerformanceMetrics {
    private var queryMetrics: [(type: String, duration: Double, resultCount: Int, user: String)] = []
    private var memoryMetrics: (initial: Int64, final: Int64)?
    private var concurrentMetrics: [(user: String, trips: Int, memories: Int)] = []
    private var bulkOperationMetrics: [(type: String, duration: Double, count: Int)] = []
    private var dataGenerationMetrics: (duration: Double, users: Int, trips: Int, memories: Int)?
    
    func recordQuery(type: String, duration: Double, resultCount: Int, user: String) {
        queryMetrics.append((type: type, duration: duration, resultCount: resultCount, user: user))
    }
    
    func recordMemoryUsage(initial: Int64, final: Int64) {
        memoryMetrics = (initial: initial, final: final)
    }
    
    func recordConcurrentQuery(user: String, tripsCount: Int, memoriesCount: Int) {
        concurrentMetrics.append((user: user, trips: tripsCount, memories: memoriesCount))
    }
    
    func recordBulkOperation(type: String, duration: Double, count: Int) {
        bulkOperationMetrics.append((type: type, duration: duration, count: count))
    }
    
    func recordDataGeneration(duration: Double, users: Int, trips: Int, memories: Int) {
        dataGenerationMetrics = (duration: duration, users: users, trips: trips, memories: memories)
    }
    
    func printSummary() {
        print("\n" + String(repeating: "=", count: 80))
        print("📊 PERFORMANCE TEST SUMMARY")
        print(String(repeating: "=", count: 80))
        
        // Data Generation Summary
        if let dataGen = dataGenerationMetrics {
            print("\n📝 DATA GENERATION:")
            print("   ⏱️  Duration: \(String(format: "%.2f", dataGen.duration))s")
            print("   👥 Users: \(dataGen.users)")
            print("   🗺️  Trips: \(dataGen.trips)")
            print("   💭 Memories: \(dataGen.memories)")
            print("   📈 Rate: \(String(format: "%.0f", Double(dataGen.trips + dataGen.memories) / dataGen.duration)) objects/sec")
        }
        
        // Query Performance Summary
        if !queryMetrics.isEmpty {
            print("\n🔍 QUERY PERFORMANCE:")
            let queryGroups = Dictionary(grouping: queryMetrics, by: { $0.type })
            
            for (queryType, queries) in queryGroups {
                let avgDuration = queries.map { $0.duration }.reduce(0, +) / Double(queries.count)
                let maxDuration = queries.map { $0.duration }.max() ?? 0
                let minDuration = queries.map { $0.duration }.min() ?? 0
                let avgResults = queries.map { $0.resultCount }.reduce(0, +) / queries.count
                
                print("   \(queryType):")
                print("     📊 Queries: \(queries.count)")
                print("     ⏱️  Avg: \(String(format: "%.2f", avgDuration))ms")
                print("     ⏱️  Min: \(String(format: "%.2f", minDuration))ms")
                print("     ⏱️  Max: \(String(format: "%.2f", maxDuration))ms")
                print("     📈 Avg Results: \(avgResults)")
            }
        }
        
        // Memory Summary
        if let memory = memoryMetrics {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useKB]
            formatter.countStyle = .memory
            
            let increase = memory.final - memory.initial
            print("\n🧠 MEMORY USAGE:")
            print("   📊 Initial: \(formatter.string(fromByteCount: memory.initial))")
            print("   📊 Final: \(formatter.string(fromByteCount: memory.final))")
            print("   📈 Increase: \(formatter.string(fromByteCount: increase))")
        }
        
        // Concurrent Operations Summary
        if !concurrentMetrics.isEmpty {
            let totalTrips = concurrentMetrics.map { $0.trips }.reduce(0, +)
            let totalMemories = concurrentMetrics.map { $0.memories }.reduce(0, +)
            
            print("\n🔄 CONCURRENT OPERATIONS:")
            print("   👥 Users: \(concurrentMetrics.count)")
            print("   🗺️  Total Trips: \(totalTrips)")
            print("   💭 Total Memories: \(totalMemories)")
        }
        
        // Bulk Operations Summary
        if !bulkOperationMetrics.isEmpty {
            print("\n📦 BULK OPERATIONS:")
            for operation in bulkOperationMetrics {
                let rate = Double(operation.count) / (operation.duration / 1000.0)
                print("   \(operation.type): \(operation.count) objects in \(String(format: "%.2f", operation.duration))ms (\(String(format: "%.0f", rate)) obj/sec)")
            }
        }
        
        print("\n" + String(repeating: "=", count: 80))
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
} 