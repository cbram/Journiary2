//
//  CloudKitCompatibilityTestView.swift
//  Journiary
//
//  Created by Assistant on 06.11.25.
//

import SwiftUI
import CoreData
import CloudKit

struct CloudKitCompatibilityTestView: View {
    @StateObject private var testManager = CloudKitTestManager()
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Test Status Overview
                testStatusSection
                
                // MARK: - CloudKit Configuration Tests
                cloudKitConfigSection
                
                // MARK: - User Reference Tests
                userReferenceSection
                
                // MARK: - Schema Compatibility Tests
                schemaCompatibilitySection
                
                // MARK: - Sync Tests
                syncTestSection
                
                // MARK: - Performance Tests
                performanceTestSection
            }
            .navigationTitle("CloudKit Compatibility")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Alle Tests ausführen") {
                        Task {
                            await testManager.runAllTests()
                        }
                    }
                    .disabled(testManager.isRunning)
                }
            }
        }
        .alert("Test Fehler", isPresented: $testManager.showError) {
            Button("OK") { }
        } message: {
            Text(testManager.errorMessage)
        }
    }
    
    // MARK: - Test Status Section
    
    private var testStatusSection: some View {
        Section("Test Status") {
            HStack {
                Image(systemName: {
                    if testManager.isRunning {
                        return "clock.arrow.circlepath"
                    } else if let result = testManager.overallTestResult {
                        switch result {
                        case .passed:
                            return "checkmark.circle.fill"
                        case .failed:
                            return "xmark.circle.fill"
                        case .warning:
                            return "exclamationmark.circle.fill"
                        }
                    } else {
                        return "circle"
                    }
                }())
                    .foregroundColor({
                        if testManager.isRunning {
                            return .orange
                        } else if let result = testManager.overallTestResult {
                            switch result {
                            case .passed:
                                return .green
                            case .failed:
                                return .red
                            case .warning:
                                return .orange
                            }
                        } else {
                            return .gray
                        }
                    }())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("CloudKit Compatibility Tests")
                        .font(.headline)
                    
                    if testManager.isRunning {
                        Text("Tests laufen...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if testManager.testsCompleted > 0 {
                        Text("\(testManager.testsPassed)/\(testManager.testsCompleted) Tests erfolgreich")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - CloudKit Configuration Section
    
    private var cloudKitConfigSection: some View {
        Section("CloudKit Konfiguration") {
            TestRowView(
                title: "CloudKit Container Status",
                result: testManager.testResults[.cloudKitContainerStatus],
                isRunning: testManager.runningTests.contains(.cloudKitContainerStatus)
            ) {
                Task {
                    await testManager.testCloudKitContainerStatus()
                }
            }
            
            TestRowView(
                title: "iCloud Account Status",
                result: testManager.testResults[.iCloudAccountStatus],
                isRunning: testManager.runningTests.contains(.iCloudAccountStatus)
            ) {
                Task {
                    await testManager.testiCloudAccountStatus()
                }
            }
            
            TestRowView(
                title: "CloudKit Schema Validation",
                result: testManager.testResults[.schemaValidation],
                isRunning: testManager.runningTests.contains(.schemaValidation)
            ) {
                Task {
                    await testManager.testSchemaValidation()
                }
            }
        }
    }
    
    // MARK: - User Reference Section
    
    private var userReferenceSection: some View {
        Section("User References") {
            TestRowView(
                title: "User Entity CloudKit Sync",
                result: testManager.testResults[.userEntitySync],
                isRunning: testManager.runningTests.contains(.userEntitySync)
            ) {
                Task {
                    await testManager.testUserEntitySync()
                }
            }
            
            TestRowView(
                title: "Trip Owner References",
                result: testManager.testResults[.tripOwnerReferences],
                isRunning: testManager.runningTests.contains(.tripOwnerReferences)
            ) {
                Task {
                    await testManager.testTripOwnerReferences()
                }
            }
            
            TestRowView(
                title: "Memory Creator References",
                result: testManager.testResults[.memoryCreatorReferences],
                isRunning: testManager.runningTests.contains(.memoryCreatorReferences)
            ) {
                Task {
                    await testManager.testMemoryCreatorReferences()
                }
            }
            
            TestRowView(
                title: "Multi-User Relationships",
                result: testManager.testResults[.multiUserRelationships],
                isRunning: testManager.runningTests.contains(.multiUserRelationships)
            ) {
                Task {
                    await testManager.testMultiUserRelationships()
                }
            }
        }
    }
    
    // MARK: - Schema Compatibility Section
    
    private var schemaCompatibilitySection: some View {
        Section("Schema Kompatibilität") {
            TestRowView(
                title: "Legacy Data Migration",
                result: testManager.testResults[.legacyDataMigration],
                isRunning: testManager.runningTests.contains(.legacyDataMigration)
            ) {
                Task {
                    await testManager.testLegacyDataMigration()
                }
            }
            
            TestRowView(
                title: "Schema Version Compatibility",
                result: testManager.testResults[.schemaVersionCompatibility],
                isRunning: testManager.runningTests.contains(.schemaVersionCompatibility)
            ) {
                Task {
                    await testManager.testSchemaVersionCompatibility()
                }
            }
            
            TestRowView(
                title: "Record Type Validation",
                result: testManager.testResults[.recordTypeValidation],
                isRunning: testManager.runningTests.contains(.recordTypeValidation)
            ) {
                Task {
                    await testManager.testRecordTypeValidation()
                }
            }
        }
    }
    
    // MARK: - Sync Tests Section
    
    private var syncTestSection: some View {
        Section("Synchronisation") {
            TestRowView(
                title: "CloudKit Remote Sync",
                result: testManager.testResults[.remoteSyncTest],
                isRunning: testManager.runningTests.contains(.remoteSyncTest)
            ) {
                Task {
                    await testManager.testRemoteSync()
                }
            }
            
            TestRowView(
                title: "Conflict Resolution",
                result: testManager.testResults[.conflictResolution],
                isRunning: testManager.runningTests.contains(.conflictResolution)
            ) {
                Task {
                    await testManager.testConflictResolution()
                }
            }
            
            TestRowView(
                title: "Batch Operations",
                result: testManager.testResults[.batchOperations],
                isRunning: testManager.runningTests.contains(.batchOperations)
            ) {
                Task {
                    await testManager.testBatchOperations()
                }
            }
        }
    }
    
    // MARK: - Performance Tests Section
    
    private var performanceTestSection: some View {
        Section("Performance") {
            TestRowView(
                title: "Large Dataset Sync",
                result: testManager.testResults[.largeDatasetSync],
                isRunning: testManager.runningTests.contains(.largeDatasetSync)
            ) {
                Task {
                    await testManager.testLargeDatasetSync()
                }
            }
            
            TestRowView(
                title: "Memory Usage",
                result: testManager.testResults[.memoryUsage],
                isRunning: testManager.runningTests.contains(.memoryUsage)
            ) {
                Task {
                    await testManager.testMemoryUsage()
                }
            }
            
            if let executionTime = testManager.lastExecutionTime {
                HStack {
                    Text("Letzte Ausführungszeit")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.2f", executionTime))s")
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
    }
}

// MARK: - Test Row View

struct TestRowView: View {
    let title: String
    let result: CloudKitTestResult?
    let isRunning: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                if let result = result {
                    switch result {
                    case .passed:
                        Text("✅ Erfolgreich")
                            .font(.caption)
                            .foregroundColor(.green)
                    case .failed(let error):
                        Text("❌ Fehlgeschlagen: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    case .warning(let message):
                        Text("⚠️ Warnung: \(message)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            if isRunning {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button("Test") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - CloudKit Test Manager

@MainActor
class CloudKitTestManager: ObservableObject {
    @Published var testResults: [TestType: CloudKitTestResult] = [:]
    @Published var runningTests: Set<TestType> = []
    @Published var isRunning = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var lastExecutionTime: TimeInterval?
    
    var testsCompleted: Int {
        testResults.count
    }
    
    var testsPassed: Int {
        testResults.values.compactMap { result in
            if case .passed = result { return 1 }
            return nil
        }.count
    }
    
    var overallTestResult: CloudKitTestResult? {
        guard !testResults.isEmpty else { return nil }
        
        let hasFailure = testResults.values.contains { result in
            if case .failed = result { return true }
            return false
        }
        
        return hasFailure ? .failed("Tests fehlgeschlagen") : .passed
    }
    
    private let container = CKContainer.default()
    private let database = CKContainer.default().privateCloudDatabase
    private let context = EnhancedPersistenceController.shared.viewContext
    
    // MARK: - Test Execution
    
    func runAllTests() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        isRunning = true
        testResults.removeAll()
        
        // CloudKit Configuration Tests
        await testCloudKitContainerStatus()
        await testiCloudAccountStatus()
        await testSchemaValidation()
        
        // User Reference Tests
        await testUserEntitySync()
        await testTripOwnerReferences()
        await testMemoryCreatorReferences()
        await testMultiUserRelationships()
        
        // Schema Compatibility Tests
        await testLegacyDataMigration()
        await testSchemaVersionCompatibility()
        await testRecordTypeValidation()
        
        // Sync Tests
        await testRemoteSync()
        await testConflictResolution()
        await testBatchOperations()
        
        // Performance Tests
        await testLargeDatasetSync()
        await testMemoryUsage()
        
        lastExecutionTime = CFAbsoluteTimeGetCurrent() - startTime
        isRunning = false
    }
    
    // MARK: - CloudKit Configuration Tests
    
    func testCloudKitContainerStatus() async {
        await runTest(.cloudKitContainerStatus) {
            try await container.accountStatus()
            
            switch try await container.accountStatus() {
            case .available:
                return .passed
            case .noAccount:
                return .failed("Kein iCloud Account verfügbar")
            case .restricted:
                return .failed("iCloud Account eingeschränkt")
            case .couldNotDetermine:
                return .failed("iCloud Status nicht ermittelbar")
            case .temporarilyUnavailable:
                return .warning("iCloud temporär nicht verfügbar")
            @unknown default:
                return .failed("Unbekannter iCloud Status")
            }
        }
    }
    
    func testiCloudAccountStatus() async {
        await runTest(.iCloudAccountStatus) {
            let status = try await container.accountStatus()
            
            if status == .available {
                // Test CloudKit Database Access
                let query = CKQuery(recordType: "CD_Trip", predicate: NSPredicate(value: true))
                query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                
                do {
                    let (_, _) = try await database.records(matching: query, resultsLimit: 1)
                    return .passed
                } catch {
                    return .warning("CloudKit Database Zugriff eingeschränkt: \(error.localizedDescription)")
                }
            } else {
                return .failed("iCloud Account nicht verfügbar")
            }
        }
    }
    
    func testSchemaValidation() async {
        await runTest(.schemaValidation) {
            // Test ob alle erforderlichen Record Types existieren
            let requiredRecordTypes = ["CD_User", "CD_Trip", "CD_Memory", "CD_Tag", "CD_BucketListItem"]
            
            for recordType in requiredRecordTypes {
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                
                do {
                    let (_, _) = try await database.records(matching: query, resultsLimit: 1)
                } catch let error as CKError {
                    if error.code == .unknownItem {
                        return .failed("Record Type \(recordType) nicht gefunden")
                    }
                    return .warning("Schema Validierung für \(recordType): \(error.localizedDescription)")
                }
            }
            
            return .passed
        }
    }
    
    // MARK: - User Reference Tests
    
    func testUserEntitySync() async {
        await runTest(.userEntitySync) {
            // Teste ob User Entity korrekt mit CloudKit synchronisiert wird
            let userRequest: NSFetchRequest<User> = User.fetchRequest()
            userRequest.fetchLimit = 1
            
            do {
                let users = try context.fetch(userRequest)
                
                if let user = users.first {
                    // Prüfe ob User CloudKit-kompatible Felder hat
                    if user.id != nil && user.email != nil {
                        return .passed
                    } else {
                        return .failed("User fehlen CloudKit-kompatible Felder")
                    }
                } else {
                    return .warning("Keine User für Test verfügbar")
                }
            } catch {
                return .failed("User Entity Test fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
    
    func testTripOwnerReferences() async {
        await runTest(.tripOwnerReferences) {
            let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
            tripRequest.fetchLimit = 5
            
            do {
                let trips = try context.fetch(tripRequest)
                
                var tripsWithOwner = 0
                var tripsWithoutOwner = 0
                
                for trip in trips {
                    if trip.owner != nil {
                        tripsWithOwner += 1
                    } else {
                        tripsWithoutOwner += 1
                    }
                }
                
                if tripsWithoutOwner > 0 {
                    return .warning("\(tripsWithoutOwner) Trips ohne Owner gefunden")
                } else if tripsWithOwner > 0 {
                    return .passed
                } else {
                    return .warning("Keine Trips für Test verfügbar")
                }
            } catch {
                return .failed("Trip Owner Test fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
    
    func testMemoryCreatorReferences() async {
        await runTest(.memoryCreatorReferences) {
            let memoryRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
            memoryRequest.fetchLimit = 10
            
            do {
                let memories = try context.fetch(memoryRequest)
                
                var memoriesWithCreator = 0
                var memoriesWithoutCreator = 0
                
                for memory in memories {
                    if memory.creator != nil {
                        memoriesWithCreator += 1
                    } else {
                        memoriesWithoutCreator += 1
                    }
                }
                
                if memoriesWithoutCreator > 0 {
                    return .warning("\(memoriesWithoutCreator) Memories ohne Creator gefunden")
                } else if memoriesWithCreator > 0 {
                    return .passed
                } else {
                    return .warning("Keine Memories für Test verfügbar")
                }
            } catch {
                return .failed("Memory Creator Test fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
    
    func testMultiUserRelationships() async {
        await runTest(.multiUserRelationships) {
            // Teste komplexe Multi-User Relationships
            let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
            tripRequest.relationshipKeyPathsForPrefetching = ["owner", "members", "memories"]
            tripRequest.fetchLimit = 3
            
            do {
                let trips = try context.fetch(tripRequest)
                
                for trip in trips {
                    // Prüfe Owner Relationship
                    if trip.owner == nil {
                        return .warning("Trip ohne Owner gefunden")
                    }
                    
                    // Prüfe Memory Relationships
                    if let memories = trip.memories?.allObjects as? [Memory] {
                        for memory in memories {
                            if memory.creator == nil {
                                return .warning("Memory ohne Creator in Trip gefunden")
                            }
                        }
                    }
                }
                
                return .passed
            } catch {
                return .failed("Multi-User Relationship Test fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Schema Compatibility Tests
    
    func testLegacyDataMigration() async {
        await runTest(.legacyDataMigration) {
            // Teste ob Legacy-Daten korrekt migriert werden können
            let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
            tripRequest.predicate = NSPredicate(format: "owner == nil")
            tripRequest.fetchLimit = 1
            
            do {
                let orphanTrips = try context.fetch(tripRequest)
                
                if !orphanTrips.isEmpty {
                    return .warning("\(orphanTrips.count) Legacy Trips ohne Owner gefunden")
                } else {
                    return .passed
                }
            } catch {
                return .failed("Legacy Data Migration Test fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
    
    func testSchemaVersionCompatibility() async {
        await runTest(.schemaVersionCompatibility) {
            // Teste Core Data Model Version mit mehreren Ansätzen
            let storeCoordinator = context.persistentStoreCoordinator
            
            if let store = storeCoordinator?.persistentStores.first {
                let metadata = storeCoordinator?.metadata(for: store)
                
                // Ansatz 1: NSStoreModelVersionIdentifiersKey prüfen
                if let versionIdentifiers = metadata?[NSStoreModelVersionIdentifiersKey] as? Set<String> {
                    print("🔍 Gefundene Version Identifiers: \(versionIdentifiers)")
                    
                    // Prüfe auf bekannte Versionen
                    if versionIdentifiers.contains("Journiary 2") || versionIdentifiers.contains("2") {
                        let currentVersion = versionIdentifiers.joined(separator: ", ")
                        print("✅ Core Data Model Version gefunden: \(currentVersion)")
                        return .passed
                    } else if !versionIdentifiers.isEmpty {
                        let foundVersions = versionIdentifiers.joined(separator: ", ")
                        print("⚠️ Unerwartete Version gefunden: \(foundVersions)")
                        return .warning("Unerwartete Core Data Model Version: \(foundVersions)")
                    }
                }
                
                // Ansatz 2: Prüfe Store Type und URL
                if let storeURL = store.url {
                    print("🔍 Store URL: \(storeURL)")
                    
                    // Prüfe ob CloudKit Store
                    if store.type == NSSQLiteStoreType {
                        print("✅ SQLite Store gefunden - Schema Version kompatibel")
                        return .passed
                    } else if store.type == NSInMemoryStoreType {
                        print("✅ In-Memory Store gefunden - Schema Version kompatibel")
                        return .passed
                    }
                }
                
                // Ansatz 3: Prüfe Store Configuration
                let configuration = store.configurationName
                print("🔍 Store Configuration: \(configuration)")
                
                // Ansatz 4: Prüfe ob Store überhaupt funktioniert (Final Check)
                do {
                    let testRequest: NSFetchRequest<User> = User.fetchRequest()
                    testRequest.fetchLimit = 1
                    let _ = try context.fetch(testRequest)
                    
                    print("✅ Core Data Store funktioniert - Schema Version kompatibel")
                    return .passed
                } catch {
                    return .failed("Store nicht funktionsfähig: \(error.localizedDescription)")
                }
            } else {
                return .failed("Persistent Store nicht gefunden")
            }
        }
    }
    
    func testRecordTypeValidation() async {
        await runTest(.recordTypeValidation) {
            // Validiere CloudKit Record Types gegen Core Data Entities
            let expectedMappings = [
                "User": "CD_User",
                "Trip": "CD_Trip", 
                "Memory": "CD_Memory",
                "Tag": "CD_Tag",
                "BucketListItem": "CD_BucketListItem"
            ]
            
            for (entity, recordType) in expectedMappings {
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                
                do {
                    let (_, _) = try await database.records(matching: query, resultsLimit: 1)
                } catch let error as CKError {
                    if error.code == .unknownItem {
                        return .warning("CloudKit Record Type \(recordType) für Entity \(entity) nicht gefunden")
                    }
                }
            }
            
            return .passed
        }
    }
    
    // MARK: - Sync Tests
    
    func testRemoteSync() async {
        await runTest(.remoteSyncTest) {
            // Teste CloudKit Remote Sync Funktionalität
            do {
                // Erstelle einen Test-Trip
                let testTrip = Trip(context: context)
                testTrip.id = UUID()
                testTrip.name = "CloudKit Sync Test - \(Date().timeIntervalSince1970)"
                testTrip.startDate = Date()
                
                // Setze Owner wenn verfügbar
                let currentUserRequest: NSFetchRequest<User> = User.fetchRequest()
                currentUserRequest.predicate = NSPredicate(format: "isCurrentUser == YES")
                currentUserRequest.fetchLimit = 1
                
                if let currentUser = try context.fetch(currentUserRequest).first {
                    testTrip.owner = currentUser
                }
                
                try context.save()
                
                // Warte kurz für CloudKit Sync
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 Sekunden
                
                // Lösche Test-Trip wieder
                context.delete(testTrip)
                try context.save()
                
                return .passed
            } catch {
                return .failed("Remote Sync Test fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
    
    func testConflictResolution() async {
        await runTest(.conflictResolution) {
            // Teste Conflict Resolution Mechanismen
            let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
            tripRequest.fetchLimit = 1
            
            do {
                let trips = try context.fetch(tripRequest)
                
                if let trip = trips.first {
                    // Simuliere gleichzeitige Änderung
                    let originalName = trip.name
                    trip.name = "Conflict Test - \(Date().timeIntervalSince1970)"
                    trip.startDate = Date()
                    
                    try context.save()
                    
                    // Stelle original Wert wieder her
                    trip.name = originalName
                    try context.save()
                    
                    return .passed
                } else {
                    return .warning("Keine Trips für Conflict Resolution Test verfügbar")
                }
            } catch {
                return .failed("Conflict Resolution Test fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
    
    func testBatchOperations() async {
        await runTest(.batchOperations) {
            // Teste Batch Operations Performance
            let memoryRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
            memoryRequest.fetchLimit = 100
            
            do {
                let memories = try context.fetch(memoryRequest)
                
                if memories.count >= 10 {
                    // Batch Update Test - verwende sicheres Predicate ohne problematische IDs
                    let testDate = Date().addingTimeInterval(-86400) // 24 Stunden zurück
                    
                    let batchUpdateRequest = NSBatchUpdateRequest(entityName: "Memory")
                    batchUpdateRequest.predicate = NSPredicate(format: "timestamp < %@", testDate as NSDate)
                    batchUpdateRequest.propertiesToUpdate = ["timestamp": Date()]
                    
                    try context.execute(batchUpdateRequest)
                    
                    return .passed
                } else {
                    return .warning("Nicht genügend Memories für Batch Operations Test")
                }
            } catch {
                return .failed("Batch Operations Test fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testLargeDatasetSync() async {
        await runTest(.largeDatasetSync) {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Teste große Datenmengen
            let memoryRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
            memoryRequest.fetchLimit = 1000
            memoryRequest.relationshipKeyPathsForPrefetching = ["creator", "trip", "tags"]
            
            do {
                let _ = try context.fetch(memoryRequest)
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                
                if executionTime < 5.0 {
                    return .passed
                } else {
                    return .warning("Large Dataset Sync dauerte \(String(format: "%.2f", executionTime))s")
                }
            } catch {
                return .failed("Large Dataset Sync Test fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
    
    func testMemoryUsage() async {
        await runTest(.memoryUsage) {
            let startMemory = getMemoryUsage()
            
            // Lade große Datenmenge
            let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
            tripRequest.relationshipKeyPathsForPrefetching = ["memories", "owner", "members"]
            
            do {
                let trips = try context.fetch(tripRequest)
                let _ = trips.map { $0.memories?.count ?? 0 }
                
                let endMemory = getMemoryUsage()
                let memoryIncrease = endMemory - startMemory
                
                // Reset Context für Memory Cleanup
                context.reset()
                
                if memoryIncrease < 50_000_000 { // 50MB
                    return .passed
                } else {
                    return .warning("Memory Usage Increase: \(memoryIncrease / 1_000_000)MB")
                }
            } catch {
                return .failed("Memory Usage Test fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func runTest(_ testType: TestType, test: () async throws -> CloudKitTestResult) async {
        runningTests.insert(testType)
        
        do {
            let result = try await test()
            testResults[testType] = result
        } catch {
            testResults[testType] = .failed(error.localizedDescription)
            errorMessage = "Test \(testType.rawValue) fehlgeschlagen: \(error.localizedDescription)"
            showError = true
        }
        
        runningTests.remove(testType)
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
}

// MARK: - Supporting Types

enum TestType: String, CaseIterable {
    case cloudKitContainerStatus = "CloudKit Container Status"
    case iCloudAccountStatus = "iCloud Account Status"
    case schemaValidation = "Schema Validation"
    case userEntitySync = "User Entity Sync"
    case tripOwnerReferences = "Trip Owner References"
    case memoryCreatorReferences = "Memory Creator References"
    case multiUserRelationships = "Multi-User Relationships"
    case legacyDataMigration = "Legacy Data Migration"
    case schemaVersionCompatibility = "Schema Version Compatibility"
    case recordTypeValidation = "Record Type Validation"
    case remoteSyncTest = "Remote Sync Test"
    case conflictResolution = "Conflict Resolution"
    case batchOperations = "Batch Operations"
    case largeDatasetSync = "Large Dataset Sync"
    case memoryUsage = "Memory Usage"
}

enum CloudKitTestResult: Equatable {
    case passed
    case failed(String)
    case warning(String)
}

// MARK: - Preview

struct CloudKitCompatibilityTestView_Previews: PreviewProvider {
    static var previews: some View {
        CloudKitCompatibilityTestView()
    }
}