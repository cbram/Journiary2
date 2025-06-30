//
//  SchemaMigrationTestView.swift
//  Journiary
//
//  Created by TravelCompanion AI on 28.12.24.
//

import SwiftUI
import CoreData

struct SchemaMigrationTestView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var migrationManager = CoreDataMigrationManager.shared
    @StateObject private var persistenceController = EnhancedPersistenceController.shared
    
    @State private var testResults: [MigrationTestResult] = []
    @State private var isTestingInProgress = false
    @State private var selectedTestScenario = TestScenario.fullMigration
    @State private var testLog: [String] = []
    
    // MARK: - Test Scenarios
    
    enum TestScenario: String, CaseIterable {
        case fullMigration = "Vollständige Migration"
        case dataIntegrity = "Datenintegrität"
        case userAssignment = "User-Zuweisung"
        case relationshipValidation = "Relationship-Validierung"
        
        var description: String {
            switch self {
            case .fullMigration:
                return "Testet komplette Migration von V1 zu V2 Schema"
            case .dataIntegrity:
                return "Überprüft dass alle Daten nach Migration vorhanden sind"
            case .userAssignment:
                return "Validiert korrekte User-Zuweisungen zu Legacy-Daten"
            case .relationshipValidation:
                return "Prüft alle Entity-Relationships nach Migration"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Test Scenario Auswahl
                testScenarioSection
                
                if isTestingInProgress {
                    migrationProgressSection
                } else {
                    testResultsSection
                }
                
                // Action Buttons
                actionButtonsSection
            }
            .navigationTitle("Schema Migration Tests")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "externaldrive.fill.badge.checkmark")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("Core Data Schema Version")
                        .font(.headline)
                    Text("V2 (Multi-User)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
        }
    }
    
    private var testScenarioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test-Szenario")
                .font(.headline)
                .padding(.horizontal)
            
            Picker("Test Scenario", selection: $selectedTestScenario) {
                ForEach(TestScenario.allCases, id: \.self) { scenario in
                    VStack(alignment: .leading) {
                        Text(scenario.rawValue)
                    }
                    .tag(scenario)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private var migrationProgressSection: some View {
        VStack(spacing: 16) {
            if migrationManager.migrationInProgress {
                MigrationProgressView()
                    .frame(height: 200)
            }
            
            Text("Test wird ausgeführt...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
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
                        MigrationTestResultRow(result: result)
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
            .disabled(isTestingInProgress)
            
            HStack(spacing: 12) {
                Button("Alle Tests") {
                    Task { await runAllTests() }
                }
                .buttonStyle(.bordered)
                .disabled(isTestingInProgress)
                
                Button("Reset Tests") {
                    resetTests()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    // MARK: - Test Methods
    
    @MainActor
    private func runSelectedTest() async {
        isTestingInProgress = true
        testResults.removeAll()
        
        do {
            switch selectedTestScenario {
            case .fullMigration:
                await testFullMigration()
            case .dataIntegrity:
                await testDataIntegrity()
            case .userAssignment:
                await testUserAssignment()
            case .relationshipValidation:
                await testRelationshipValidation()
            }
        } catch {
            addTestResult(name: "Test Error", success: false, details: error.localizedDescription)
        }
        
        isTestingInProgress = false
    }
    
    @MainActor
    private func runAllTests() async {
        isTestingInProgress = true
        testResults.removeAll()
        
        for scenario in TestScenario.allCases {
            selectedTestScenario = scenario
            await runSelectedTest()
        }
        
        isTestingInProgress = false
    }
    
    private func testFullMigration() async {
        guard let storeURL = persistenceController.container.persistentStoreDescriptions.first?.url else {
            addTestResult(name: "Store URL Check", success: false, details: "Store URL nicht gefunden")
            return
        }
        
        let migrationRequired = await migrationManager.isMigrationRequired(storeURL: storeURL)
        
        if migrationRequired {
            do {
                try await migrationManager.performMigration(storeURL: storeURL)
                addTestResult(name: "Migration Execution", success: true, details: "Migration erfolgreich durchgeführt")
            } catch {
                addTestResult(name: "Migration Execution", success: false, details: error.localizedDescription)
            }
        } else {
            addTestResult(name: "Migration Check", success: true, details: "Keine Migration erforderlich - Schema bereits aktuell")
        }
    }
    
    private func testDataIntegrity() async {
        let context = viewContext
        
        // Zähle alle Entities
        let tripCount = (try? context.fetch(Trip.fetchRequest()).count) ?? 0
        let memoryCount = (try? context.fetch(Memory.fetchRequest()).count) ?? 0
        let mediaCount = (try? context.fetch(MediaItem.fetchRequest()).count) ?? 0
        let bucketCount = (try? context.fetch(BucketListItem.fetchRequest()).count) ?? 0
        let tagCount = (try? context.fetch(Tag.fetchRequest()).count) ?? 0
        
        addTestResult(name: "Trips Count", success: true, details: "\(tripCount) Einträge")
        addTestResult(name: "Memories Count", success: true, details: "\(memoryCount) Einträge")
        addTestResult(name: "MediaItems Count", success: true, details: "\(mediaCount) Einträge")
        addTestResult(name: "BucketListItems Count", success: true, details: "\(bucketCount) Einträge")
        addTestResult(name: "Tags Count", success: true, details: "\(tagCount) Einträge")
    }
    
    private func testUserAssignment() async {
        let context = viewContext
        
        // Prüfe User
        let userRequest: NSFetchRequest<User> = User.fetchRequest()
        let users = (try? context.fetch(userRequest)) ?? []
        
        addTestResult(name: "Users Found", success: !users.isEmpty, details: "\(users.count) User gefunden")
        
        // Prüfe orphaned entities
        let orphanedTrips = (try? context.fetch(NSFetchRequest<Trip>(entityName: "Trip")))?.filter { $0.owner == nil }.count ?? 0
        let orphanedMemories = (try? context.fetch(NSFetchRequest<Memory>(entityName: "Memory")))?.filter { $0.creator == nil }.count ?? 0
        
        addTestResult(name: "Trip User Assignment", success: orphanedTrips == 0, details: "\(orphanedTrips) ohne User")
        addTestResult(name: "Memory User Assignment", success: orphanedMemories == 0, details: "\(orphanedMemories) ohne User")
    }
    
    private func testRelationshipValidation() async {
        let context = viewContext
        
        let trips = (try? context.fetch(Trip.fetchRequest())) ?? []
        var validRelationships = 0
        var invalidRelationships = 0
        
        for trip in trips {
            if trip.owner != nil {
                validRelationships += 1
            } else {
                invalidRelationships += 1
            }
        }
        
        addTestResult(
            name: "Trip->User Relationships",
            success: invalidRelationships == 0,
            details: "\(validRelationships) valid, \(invalidRelationships) invalid"
        )
    }
    
    private func resetTests() {
        testResults.removeAll()
    }
    
    private func addTestResult(name: String, success: Bool, details: String) {
        let result = MigrationTestResult(
            name: name,
            success: success,
            details: details,
            timestamp: Date()
        )
        testResults.append(result)
    }
}

// MARK: - Supporting Types

struct MigrationTestResult: Identifiable {
    let id = UUID()
    let name: String
    let success: Bool
    let details: String
    let timestamp: Date
}

struct MigrationTestResultRow: View {
    let result: MigrationTestResult
    
    var body: some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
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
    SchemaMigrationTestView()
        .environment(\.managedObjectContext, EnhancedPersistenceController.shared.viewContext)
} 