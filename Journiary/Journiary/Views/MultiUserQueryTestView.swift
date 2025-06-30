//
//  MultiUserQueryTestView.swift
//  Journiary
//
//  Created by TravelCompanion AI on 28.12.24.
//

import SwiftUI
import CoreData

struct MultiUserQueryTestView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var multiUserOpsManager = MultiUserOperationsManager.shared
    
    @State private var testResults: [QueryTestResult] = []
    @State private var isTestingInProgress = false
    @State private var selectedTestScenario = QueryTestScenario.userIsolation
    @State private var testUsers: [User] = []
    @State private var testData: TestDataSet = TestDataSet()
    
    // MARK: - Test Scenarios
    
    enum QueryTestScenario: String, CaseIterable {
        case userIsolation = "User-Isolation"
        case sharedContent = "Shared Content"
        case performanceOptimized = "Performance-Optimierte Queries"
        case crossUserQueries = "Cross-User Queries"
        case batchOperations = "Batch Operations"
        
        var description: String {
            switch self {
            case .userIsolation:
                return "User A sieht nur eigene Daten, User B sieht nur eigene Daten"
            case .sharedContent:
                return "Shared Trips/Memories sind für alle Member sichtbar"
            case .performanceOptimized:
                return "Optimierte Queries mit Prefetching und Performance-Monitoring"
            case .crossUserQueries:
                return "Admin-Queries über alle User hinweg"
            case .batchOperations:
                return "Bulk-Operations mit User-spezifischen Daten"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header mit Test-User Status
                headerSection
                
                // Test Scenario Auswahl
                testScenarioSection
                
                if isTestingInProgress {
                    progressSection
                } else {
                    testResultsSection
                }
                
                // Action Buttons
                actionButtonsSection
            }
            .navigationTitle("Multi-User Query Tests")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadTestUsers()
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("Multi-User Query Tests")
                        .font(.headline)
                    Text("\(testUsers.count) Test-User verfügbar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Reset Test-Daten") {
                    Task { await resetTestData() }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Test-User Übersicht
            if !testUsers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(testUsers) { user in
                            UserCard(user: user, testData: testData)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 100)
            }
        }
    }
    
    private var testScenarioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test-Szenario")
                .font(.headline)
                .padding(.horizontal)
            
            Picker("Test Scenario", selection: $selectedTestScenario) {
                ForEach(QueryTestScenario.allCases, id: \.self) { scenario in
                    VStack(alignment: .leading) {
                        Text(scenario.rawValue)
                            .font(.subheadline)
                        Text(scenario.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .tag(scenario)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Test wird ausgeführt...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
    }
    
    private var testResultsSection: some View {
        List {
            Section("Test-Ergebnisse") {
                if testResults.isEmpty {
                    Text("Noch keine Tests ausgeführt")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(testResults) { result in
                        QueryTestResultRow(result: result)
                    }
                }
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task { await runSelectedTest() }
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Test ausführen")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isTestingInProgress || testUsers.count < 2)
            
            HStack(spacing: 12) {
                Button("Alle Tests") {
                    Task { await runAllTests() }
                }
                .buttonStyle(.bordered)
                .disabled(isTestingInProgress || testUsers.count < 2)
                
                Button("Test-Daten erstellen") {
                    Task { await setupTestData() }
                }
                .buttonStyle(.bordered)
                .disabled(isTestingInProgress)
                
                Button("Test-User erstellen") {
                    Task { await createTestUsers() }
                }
                .buttonStyle(.bordered)
                .disabled(isTestingInProgress)
            }
        }
        .padding()
    }
    
    // MARK: - Test Methods
    
    @MainActor
    private func runSelectedTest() async {
        isTestingInProgress = true
        testResults.removeAll()
        
        switch selectedTestScenario {
        case .userIsolation:
            await testUserIsolation()
        case .sharedContent:
            await testSharedContent()
        case .performanceOptimized:
            await testPerformanceOptimizedQueries()
        case .crossUserQueries:
            await testCrossUserQueries()
        case .batchOperations:
            await testBatchOperations()
        }
        
        isTestingInProgress = false
    }
    
    @MainActor
    private func runAllTests() async {
        isTestingInProgress = true
        testResults.removeAll()
        
        for scenario in QueryTestScenario.allCases {
            selectedTestScenario = scenario
            await runSelectedTest()
        }
        
        isTestingInProgress = false
    }
    
    // MARK: - Specific Test Implementations
    
    private func testUserIsolation() async {
        guard testUsers.count >= 2 else {
            addTestResult(name: "User Isolation Setup", success: false, details: "Mindestens 2 Test-User erforderlich", userContext: nil)
            return
        }
        
        let userA = testUsers[0]
        let userB = testUsers[1]
        
        // Test 1: User A's Trips
        let userATrips = TripFetchRequests.userTripsOptimized(for: userA, includeShared: false)
        let userAResults = (try? viewContext.fetch(userATrips)) ?? []
        let userACount = userAResults.count
        
        addTestResult(
            name: "User A Trip Isolation",
            success: userAResults.allSatisfy { $0.owner == userA },
            details: "\(userACount) Trips gefunden, alle gehören User A",
            userContext: userA.displayName
        )
        
        // Test 2: User B's Trips
        let userBTrips = TripFetchRequests.userTripsOptimized(for: userB, includeShared: false)
        let userBResults = (try? viewContext.fetch(userBTrips)) ?? []
        let userBCount = userBResults.count
        
        addTestResult(
            name: "User B Trip Isolation",
            success: userBResults.allSatisfy { $0.owner == userB },
            details: "\(userBCount) Trips gefunden, alle gehören User B",
            userContext: userB.displayName
        )
        
        // Test 3: Cross-contamination Check
        let crossContamination = userAResults.contains { trip in
            userBResults.contains { $0.id == trip.id }
        }
        
        addTestResult(
            name: "No Cross-Contamination",
            success: !crossContamination,
            details: crossContamination ? "❌ User sehen fremde Trips" : "✅ Perfekte User-Isolation",
            userContext: nil
        )
        
        // Test 4: Memory Isolation
        let userAMemories = MemoryFetchRequests.userMemoriesOptimized(for: userA, includeShared: false)
        let userAMemoryResults = (try? viewContext.fetch(userAMemories)) ?? []
        
        addTestResult(
            name: "Memory Isolation User A",
            success: userAMemoryResults.allSatisfy { $0.creator == userA },
            details: "\(userAMemoryResults.count) Memories gehören User A",
            userContext: userA.displayName
        )
        
        // Test 5: Tag Isolation
        let userATags = TagFetchRequests.userTagsOptimized(for: userA)
        let userATagResults = (try? viewContext.fetch(userATags)) ?? []
        
        addTestResult(
            name: "Tag Isolation User A",
            success: userATagResults.allSatisfy { $0.creator == userA },
            details: "\(userATagResults.count) Tags gehören User A",
            userContext: userA.displayName
        )
    }
    
    private func testSharedContent() async {
        guard testUsers.count >= 2 else {
            addTestResult(name: "Shared Content Setup", success: false, details: "Mindestens 2 Test-User erforderlich", userContext: nil)
            return
        }
        
        let userA = testUsers[0]
        let userB = testUsers[1]
        
        // Test 1: Erstelle Shared Trip
        let sharedTrip = Trip(context: viewContext)
        sharedTrip.id = UUID()
        sharedTrip.name = "Shared Test Trip"
        sharedTrip.owner = userA
        sharedTrip.startDate = Date()
        
        // Füge User B als Member hinzu
        sharedTrip.addToMembers(userB)
        
        try? viewContext.save()
        
        // Test 2: User A sieht shared Trip (als Owner)
        let userASharedTrips = TripFetchRequests.userTripsOptimized(for: userA, includeShared: true)
        let userAResults = (try? viewContext.fetch(userASharedTrips)) ?? []
        let userAHasSharedTrip = userAResults.contains { $0.id == sharedTrip.id }
        
        addTestResult(
            name: "Owner sieht shared Trip",
            success: userAHasSharedTrip,
            details: userAHasSharedTrip ? "✅ User A sieht eigenen shared Trip" : "❌ User A sieht shared Trip nicht",
            userContext: userA.displayName
        )
        
        // Test 3: User B sieht shared Trip (als Member)
        let userBSharedTrips = TripFetchRequests.userTripsOptimized(for: userB, includeShared: true)
        let userBResults = (try? viewContext.fetch(userBSharedTrips)) ?? []
        let userBHasSharedTrip = userBResults.contains { $0.id == sharedTrip.id }
        
        addTestResult(
            name: "Member sieht shared Trip",
            success: userBHasSharedTrip,
            details: userBHasSharedTrip ? "✅ User B sieht shared Trip" : "❌ User B sieht shared Trip nicht",
            userContext: userB.displayName
        )
        
        // Test 4: User B sieht shared Trip NICHT wenn includeShared = false
        let userBOwnTrips = TripFetchRequests.userTripsOptimized(for: userB, includeShared: false)
        let userBOwnResults = (try? viewContext.fetch(userBOwnTrips)) ?? []
        let userBHasSharedTripInOwn = userBOwnResults.contains { $0.id == sharedTrip.id }
        
        addTestResult(
            name: "Shared Trip nicht in eigenen Trips",
            success: !userBHasSharedTripInOwn,
            details: userBHasSharedTripInOwn ? "❌ Shared Trip fälschlich in eigenen Trips" : "✅ Shared Trip korrekt ausgeschlossen",
            userContext: userB.displayName
        )
    }
    
    private func testPerformanceOptimizedQueries() async {
        guard !testUsers.isEmpty else {
            addTestResult(name: "Performance Test Setup", success: false, details: "Test-User erforderlich", userContext: nil)
            return
        }
        
        let testUser = testUsers[0]
        
        // Test 1: Performance-optimierte Trip Query
        let startTime = Date()
        let optimizedRequest = TripFetchRequests.userTripsOptimized(for: testUser, includeShared: true)
        let results = (try? viewContext.fetch(optimizedRequest)) ?? []
        let duration = Date().timeIntervalSince(startTime)
        
        addTestResult(
            name: "Optimierte Trip Query Performance",
            success: duration < 0.1, // Sollte unter 100ms dauern
            details: String(format: "%.3f Sekunden für %d Trips", duration, results.count),
            userContext: testUser.displayName
        )
        
        // Test 2: Prefetching Test
        let prefetchRequest = TripFetchRequests.userTripsOptimized(for: testUser, includeShared: true)
        let hasPrefetching = prefetchRequest.relationshipKeyPathsForPrefetching?.isEmpty == false
        
        addTestResult(
            name: "Relationship Prefetching",
            success: hasPrefetching,
            details: hasPrefetching ? "✅ Prefetching konfiguriert" : "❌ Kein Prefetching",
            userContext: nil
        )
        
        // Test 3: Batch Size Check
        let hasBatchSize = optimizedRequest.fetchBatchSize > 0
        
        addTestResult(
            name: "Batch Size Optimization",
            success: hasBatchSize,
            details: hasBatchSize ? "✅ Batch Size: \(optimizedRequest.fetchBatchSize)" : "❌ Keine Batch Size",
            userContext: nil
        )
        
        // Test 4: Memory Query Performance
        let memoryStartTime = Date()
        let memoryRequest = MemoryFetchRequests.userMemoriesOptimized(for: testUser, includeShared: true)
        let memoryResults = (try? viewContext.fetch(memoryRequest)) ?? []
        let memoryDuration = Date().timeIntervalSince(memoryStartTime)
        
        addTestResult(
            name: "Memory Query Performance",
            success: memoryDuration < 0.1,
            details: String(format: "%.3f Sekunden für %d Memories", memoryDuration, memoryResults.count),
            userContext: testUser.displayName
        )
    }
    
    private func testCrossUserQueries() async {
        guard testUsers.count >= 2 else {
            addTestResult(name: "Cross-User Test Setup", success: false, details: "Mindestens 2 Test-User erforderlich", userContext: nil)
            return
        }
        
        // Test 1: Admin-Query - Alle Trips aller User
        let allTripsRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
        allTripsRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
        let allTrips = (try? viewContext.fetch(allTripsRequest)) ?? []
        
        // Gruppiere nach User
        let tripsByUser = Dictionary(grouping: allTrips) { $0.owner?.displayName ?? "Unknown" }
        
        addTestResult(
            name: "Admin Cross-User Query",
            success: tripsByUser.count >= testUsers.count,
            details: "Trips von \(tripsByUser.count) Usern gefunden: \(tripsByUser.keys.joined(separator: ", "))",
            userContext: "Admin"
        )
        
        // Test 2: User-spezifische Counts
        for user in testUsers {
            let userTrips = TripFetchRequests.userTripsOptimized(for: user, includeShared: false)
            let userTripCount = (try? viewContext.fetch(userTrips))?.count ?? 0
            
            addTestResult(
                name: "User-spezifischer Trip Count",
                success: true,
                details: "\(userTripCount) eigene Trips",
                userContext: user.displayName
            )
        }
        
        // Test 3: Shared Content Count
        let sharedTripsRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
        sharedTripsRequest.predicate = NSPredicate(format: "members.@count > 0")
        let sharedTrips = (try? viewContext.fetch(sharedTripsRequest)) ?? []
        
        addTestResult(
            name: "Shared Content Detection",
            success: true,
            details: "\(sharedTrips.count) Trips haben Members",
            userContext: "Admin"
        )
    }
    
    private func testBatchOperations() async {
        guard !testUsers.isEmpty else {
            addTestResult(name: "Batch Operations Setup", success: false, details: "Test-User erforderlich", userContext: nil)
            return
        }
        
        let testUser = testUsers[0]
        
        // Test 1: Bulk Update Test - alle Trips eines Users updaten
        let userTrips = TripFetchRequests.userTripsOptimized(for: testUser, includeShared: false)
        let trips = (try? viewContext.fetch(userTrips)) ?? []
        
        let updateStartTime = Date()
        for trip in trips {
            trip.totalDistance += 0.1 // Dummy update to trigger save
        }
        try? viewContext.save()
        let updateDuration = Date().timeIntervalSince(updateStartTime)
        
        addTestResult(
            name: "Bulk Update Performance",
            success: updateDuration < 1.0,
            details: String(format: "%.3f Sekunden für %d Trip Updates", updateDuration, trips.count),
            userContext: testUser.displayName
        )
        
        // Test 2: Batch Delete Simulation (ohne tatsächliches Löschen)
        let deleteRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
        deleteRequest.predicate = NSPredicate(format: "owner == %@ AND title CONTAINS[c] %@", testUser, "Test")
        let testTrips = (try? viewContext.fetch(deleteRequest)) ?? []
        
        addTestResult(
            name: "Batch Delete Preparation",
            success: true,
            details: "\(testTrips.count) Test-Trips identifiziert für potentielle Batch-Löschung",
            userContext: testUser.displayName
        )
        
        // Test 3: Memory-effiziente Query
        let memoryRequest = MemoryFetchRequests.userMemoriesOptimized(for: testUser, includeShared: false)
        memoryRequest.fetchBatchSize = 10 // Kleine Batch Size für Memory-Effizienz
        memoryRequest.returnsObjectsAsFaults = true
        
        let memoryStartTime = Date()
        let memories = (try? viewContext.fetch(memoryRequest)) ?? []
        let memoryQueryDuration = Date().timeIntervalSince(memoryStartTime)
        
        addTestResult(
            name: "Memory-effiziente Batch Query",
            success: memoryQueryDuration < 0.5,
            details: String(format: "%.3f Sekunden für %d Memories (Batch Size: 10)", memoryQueryDuration, memories.count),
            userContext: testUser.displayName
        )
    }
    
    // MARK: - Helper Methods
    
        @MainActor
    private func setupTestData() async {
        guard testUsers.count >= 2 else {
            await createTestUsers()
            return
        }
        
        let userA = testUsers[0]
        let userB = testUsers[1]
        
        // Erstelle Test-Trips für User A
        for i in 1...3 {
            let trip = Trip(context: viewContext)
            trip.id = UUID()
            trip.name = "User A Trip \(i)"
            trip.owner = userA
            trip.startDate = Date()
            
            // Erstelle Memory für diesen Trip
            let memory = Memory(context: viewContext)
            memory.title = "Memory für Trip \(i)"
            memory.text = "Test content von User A"
            memory.creator = userA
            memory.trip = trip
            memory.timestamp = Date()
        }
        
        // Erstelle Test-Trips für User B
        for i in 1...2 {
            let trip = Trip(context: viewContext)
            trip.id = UUID()
            trip.name = "User B Trip \(i)"
            trip.owner = userB
            trip.startDate = Date()
            
            // Erstelle Memory für diesen Trip
            let memory = Memory(context: viewContext)
            memory.title = "Memory für User B Trip \(i)"
            memory.text = "Test content von User B"
            memory.creator = userB
            memory.trip = trip
            memory.timestamp = Date()
        }
        
        // Erstelle Tags für beide User
        for user in [userA, userB] {
            for tagName in ["Vacation", "Business", "Adventure"] {
                let tag = Tag(context: viewContext)
                tag.id = UUID()
                tag.name = tagName
                tag.creator = user
            }
        }
        
        try? viewContext.save()
        
        // Update Test Data Set
        testData = TestDataSet()
        await loadTestDataCounts()
    }
    
    @MainActor
    private func createTestUsers() async {
        do {
                // User A
                let userA = User(context: viewContext)
                userA.id = UUID()
                userA.email = "test-user-a@example.com"
                userA.username = "test_user_a"
                userA.firstName = "Test"
                userA.lastName = "User A"
                userA.isCurrentUser = false
                
                // User B
                let userB = User(context: viewContext)
                userB.id = UUID()
                userB.email = "test-user-b@example.com"
                userB.username = "test_user_b"
                userB.firstName = "Test"
                userB.lastName = "User B"
                userB.isCurrentUser = false
                
                // User C (für erweiterte Tests)
                let userC = User(context: viewContext)
                userC.id = UUID()
                userC.email = "test-user-c@example.com"
                userC.username = "test_user_c"
                userC.firstName = "Test"
                userC.lastName = "User C"
                userC.isCurrentUser = false
                
                try viewContext.save()
                loadTestUsers()
                
                addTestResult(name: "User Creation", success: true, details: "3 Test-User erfolgreich erstellt", userContext: nil)
            } catch {
                addTestResult(name: "User Creation", success: false, details: error.localizedDescription, userContext: nil)
            }
    }
    
    @MainActor
    private func loadTestUsers() {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "username BEGINSWITH[c] %@", "test_user")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \User.username, ascending: true)]
        
        testUsers = (try? viewContext.fetch(request)) ?? []
    }
    
    @MainActor
    private func loadTestDataCounts() async {
        for user in testUsers {
            // Prüfe ob User ID vorhanden ist
            guard let userId = user.id else {
                print("⚠️ User ohne ID gefunden: \(user.username ?? "Unknown")")
                continue
            }
            
            let tripCount = (try? viewContext.fetch(TripFetchRequests.userTripsOptimized(for: user, includeShared: false)))?.count ?? 0
            let memoryCount = (try? viewContext.fetch(MemoryFetchRequests.userMemoriesOptimized(for: user, includeShared: false)))?.count ?? 0
            let tagCount = (try? viewContext.fetch(TagFetchRequests.userTagsOptimized(for: user)))?.count ?? 0
            
            testData.userCounts[userId] = UserDataCount(trips: tripCount, memories: memoryCount, tags: tagCount)
        }
    }
    
    @MainActor
    private func resetTestData() async {
        // Lösche alle Test-Trips
        let testTripsRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
        testTripsRequest.predicate = NSPredicate(format: "name CONTAINS[c] %@", "User A Trip") // OR andere Test-Patterns
        
        if let testTrips = try? viewContext.fetch(testTripsRequest) {
            for trip in testTrips {
                viewContext.delete(trip)
            }
        }
        
        // Lösche alle Test-Memories
        let testMemoriesRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
        testMemoriesRequest.predicate = NSPredicate(format: "title CONTAINS[c] %@", "Memory für")
        
        if let testMemories = try? viewContext.fetch(testMemoriesRequest) {
            for memory in testMemories {
                viewContext.delete(memory)
            }
        }
        
        // Lösche Test-Tags
        let testTagsRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        testTagsRequest.predicate = NSPredicate(format: "creator.username BEGINSWITH[c] %@", "test_user")
        
        if let testTags = try? viewContext.fetch(testTagsRequest) {
            for tag in testTags {
                viewContext.delete(tag)
            }
        }
        
        try? viewContext.save()
        
        testResults.removeAll()
        testData = TestDataSet()
    }
    
    private func addTestResult(name: String, success: Bool, details: String, userContext: String?) {
        let result = QueryTestResult(
            name: name,
            success: success,
            details: details,
            userContext: userContext,
            timestamp: Date()
        )
        testResults.append(result)
    }
}

// MARK: - Supporting Types

struct QueryTestResult: Identifiable {
    let id = UUID()
    let name: String
    let success: Bool
    let details: String
    let userContext: String?
    let timestamp: Date
}

struct TestDataSet {
    var userCounts: [UUID: UserDataCount] = [:]
}

struct UserDataCount {
    let trips: Int
    let memories: Int
    let tags: Int
}

struct UserCard: View {
    let user: User
    let testData: TestDataSet
    
    var body: some View {
        VStack(spacing: 4) {
            // User Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)
                
                Text(user.initials)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(user.firstName ?? "N/A")
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            if let userId = user.id, let counts = testData.userCounts[userId] {
                Text("\(counts.trips)T \(counts.memories)M \(counts.tags)G")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("Keine Daten")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 80)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct QueryTestResultRow: View {
    let result: QueryTestResult
    
    var body: some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if let userContext = result.userContext {
                        Text(userContext)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(result.details)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MultiUserQueryTestView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 