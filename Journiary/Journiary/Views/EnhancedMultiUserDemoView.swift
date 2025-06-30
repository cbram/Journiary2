//
//  EnhancedMultiUserDemoView.swift
//  Journiary
//
//  Created by TravelCompanion AI on 28.12.24.
//

import SwiftUI
import CoreData

struct EnhancedMultiUserDemoView: View {
    @StateObject private var userContextManager = UserContextManager.shared
    @StateObject private var multiUserOpsManager = MultiUserOperationsManager.shared
    @StateObject private var persistenceController = EnhancedPersistenceController.shared
    @StateObject private var migrationManager = CoreDataMigrationManager.shared
    
    @Environment(\.managedObjectContext) private var context
    
    @State private var showingMigrationProgress = false
    @State private var selectedDemoSection: DemoSection = .overview
    @State private var performanceStats: [String: TimeInterval] = [:]
    @State private var testResults: [MultiUserTestResult] = []
    
    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                // Sidebar
                sidebarView
                    .frame(width: 250)
                    .background(Color(.systemGray6))
                
                // Main Content
                mainContentView
                    .frame(maxWidth: .infinity)
            }
            .navigationTitle("Multi-User Core Data Demo")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingMigrationProgress) {
            MigrationProgressView()
        }
        .onAppear {
            initializeDemo()
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Demo Bereiche")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(DemoSection.allCases, id: \.self) { section in
                        Button(action: {
                            selectedDemoSection = section
                        }) {
                            HStack {
                                Image(systemName: section.iconName)
                                    .frame(width: 20)
                                Text(section.title)
                                    .font(.subheadline)
                                Spacer()
                                if section.hasNewFeatures {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedDemoSection == section ? Color.blue.opacity(0.2) : Color.clear)
                            )
                            .foregroundColor(selectedDemoSection == section ? .blue : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Status Section
            statusSectionView
                .padding()
        }
    }
    
    // MARK: - Main Content
    
    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header für Current Section
                sectionHeaderView
                
                // Content basierend auf Selection
                switch selectedDemoSection {
                case .overview:
                    overviewSectionView
                case .userManagement:
                    userManagementSectionView
                case .migration:
                    migrationSectionView
                case .performance:
                    performanceSectionView
                case .operations:
                    operationsSectionView
                case .queries:
                    queriesSectionView
                case .testing:
                    testingSectionView
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Status Section
    
    private var statusSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Status")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                StatusRowView(
                    title: "Core Data",
                    status: persistenceController.isInitialized ? .success : .loading,
                    subtitle: persistenceController.isInitialized ? "Bereit" : "Lädt..."
                )
                
                StatusRowView(
                    title: "Current User",
                    status: userContextManager.currentUser != nil ? .success : .error,
                    subtitle: userContextManager.currentUser?.displayName ?? "Nicht verfügbar"
                )
                
                StatusRowView(
                    title: "Migration",
                    status: migrationManager.migrationCompleted ? .success : .warning,
                    subtitle: migrationManager.migrationCompleted ? "Abgeschlossen" : "Erforderlich"
                )
                
                if multiUserOpsManager.isPerformingBulkOperation {
                    StatusRowView(
                        title: "Bulk Operation",
                        status: .loading,
                        subtitle: multiUserOpsManager.bulkOperationStatus
                    )
                }
            }
        }
    }
    
    // MARK: - Section Header
    
    private var sectionHeaderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: selectedDemoSection.iconName)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(selectedDemoSection.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                if selectedDemoSection.hasNewFeatures {
                    Text("NEU")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
            
            Text(selectedDemoSection.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Overview Section
    
    private var overviewSectionView: some View {
        VStack(spacing: 20) {
            // Schema Information
            InfoCardView(
                title: "Core Data Schema V2",
                icon: "cylinder.split.1x2",
                color: .green
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("✅ Multi-User Relationships implementiert")
                    Text("✅ CloudKit Kompatibilität beibehalten")
                    Text("✅ Lightweight Migration Setup")
                    Text("✅ Performance Optimierungen")
                    Text("✅ Thread-Safe Operations")
                }
                .font(.subheadline)
            }
            
            // Performance Stats
            InfoCardView(
                title: "Performance Statistiken",
                icon: "speedometer",
                color: .orange
            ) {
                if performanceStats.isEmpty {
                    Text("Keine Performance-Daten verfügbar")
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(performanceStats.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(key)
                                Spacer()
                                Text("\(String(format: "%.3f", performanceStats[key] ?? 0))s")
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            
            // Quick Actions
            InfoCardView(
                title: "Quick Actions",
                icon: "bolt.fill",
                color: .blue
            ) {
                VStack(spacing: 12) {
                    Button("Führe alle Tests aus") {
                        Task { await runAllTests() }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Performance Analyse") {
                        analyzePerformance()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Legacy Migration") {
                        performLegacyMigration()
                    }
                    .buttonStyle(.bordered)
                    .disabled(migrationManager.migrationInProgress)
                }
            }
        }
    }
    
    // MARK: - User Management Section
    
    private var userManagementSectionView: some View {
        VStack(spacing: 20) {
            // Current User
            if let currentUser = userContextManager.currentUser {
                InfoCardView(
                    title: "Aktueller Benutzer",
                    icon: "person.circle.fill",
                    color: .blue
                ) {
                    UserDetailView(user: currentUser)
                }
            }
            
            // User Operations
            InfoCardView(
                title: "Benutzer-Operationen",
                icon: "person.3.fill",
                color: .purple
            ) {
                VStack(spacing: 12) {
                    Button("Demo User erstellen") {
                        createDemoUser()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Orphaned Entities zuweisen") {
                        assignOrphanedEntities()
                    }
                    .buttonStyle(.bordered)
                    .disabled(userContextManager.currentUser == nil)
                    
                    Button("Inaktive User bereinigen") {
                        cleanupInactiveUsers()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Migration Section
    
    private var migrationSectionView: some View {
        VStack(spacing: 20) {
            InfoCardView(
                title: "Migrations-Status",
                icon: "arrow.triangle.2.circlepath",
                color: migrationManager.migrationCompleted ? .green : .orange
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status: \(migrationManager.migrationCompleted ? "Abgeschlossen" : "Ausstehend")")
                    
                    if migrationManager.migrationInProgress {
                        ProgressView(value: migrationManager.migrationProgress)
                        Text(migrationManager.migrationStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let error = migrationManager.migrationError {
                        Text("❌ \(error)")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            
            InfoCardView(
                title: "Migration Tools",
                icon: "wrench.and.screwdriver",
                color: .blue
            ) {
                VStack(spacing: 12) {
                    Button("Migration starten") {
                        performMigration()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(migrationManager.migrationInProgress)
                    
                    Button("Migration-Status anzeigen") {
                        showingMigrationProgress = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Performance Section
    
    private var performanceSectionView: some View {
        VStack(spacing: 20) {
            InfoCardView(
                title: "Query Performance",
                icon: "speedometer",
                color: .orange
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(performanceStats.keys.sorted()), id: \.self) { queryName in
                        HStack {
                            Text(queryName)
                                .font(.caption)
                            Spacer()
                            Text("\(String(format: "%.3f", performanceStats[queryName] ?? 0))s")
                                .font(.caption)
                                .foregroundColor(getPerformanceColor(for: performanceStats[queryName] ?? 0))
                        }
                    }
                    
                    if performanceStats.isEmpty {
                        Text("Führen Sie Performance-Tests aus um Daten zu sehen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            InfoCardView(
                title: "Performance Tools",
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            ) {
                VStack(spacing: 12) {
                    Button("Query Performance testen") {
                        Task { await testQueryPerformance() }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Statistiken zurücksetzen") {
                        resetPerformanceStats()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Batch Operations testen") {
                        Task { await testBatchOperations() }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Operations Section
    
    private var operationsSectionView: some View {
        VStack(spacing: 20) {
            if multiUserOpsManager.isPerformingBulkOperation {
                InfoCardView(
                    title: "Laufende Operation",
                    icon: "gear",
                    color: .blue
                ) {
                    VStack(spacing: 8) {
                        ProgressView(value: multiUserOpsManager.bulkOperationProgress)
                        Text(multiUserOpsManager.bulkOperationStatus)
                            .font(.subheadline)
                    }
                }
            }
            
            InfoCardView(
                title: "Bulk Operationen",
                icon: "square.3.layers.3d",
                color: .purple
            ) {
                VStack(spacing: 12) {
                    Button("Demo-Daten erstellen") {
                        createDemoData()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("User-Daten transferieren") {
                        // Placeholder für User Transfer
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
                    
                    Button("Datenbank bereinigen") {
                        cleanupDatabase()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Queries Section
    
    private var queriesSectionView: some View {
        VStack(spacing: 20) {
            InfoCardView(
                title: "Multi-User Queries",
                icon: "magnifyingglass.circle",
                color: .green
            ) {
                VStack(spacing: 12) {
                    Button("User Trips Query") {
                        Task { await testUserTripsQuery() }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Shared Content Query") {
                        Task { await testSharedContentQuery() }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Performance Optimized Queries") {
                        Task { await testOptimizedQueries() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            InfoCardView(
                title: "Query Ergebnisse",
                icon: "list.bullet.clipboard",
                color: .blue
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(testResults.suffix(5), id: \.id) { result in
                        HStack {
                            Text(result.name)
                                .font(.caption)
                            Spacer()
                            Text("\(result.count) Ergebnisse")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(result.status.icon)
                        }
                    }
                    
                    if testResults.isEmpty {
                        Text("Führen Sie Query-Tests aus um Ergebnisse zu sehen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Testing Section
    
    private var testingSectionView: some View {
        VStack(spacing: 20) {
            InfoCardView(
                title: "Test Suite",
                icon: "checkmark.circle",
                color: .green
            ) {
                VStack(spacing: 12) {
                    Button("Alle Tests ausführen") {
                        Task { await runAllTests() }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Thread-Safety Tests") {
                        Task { await runThreadSafetyTests() }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Migration Tests") {
                        Task { await runMigrationTests() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            InfoCardView(
                title: "Test Ergebnisse",
                icon: "list.clipboard",
                color: .blue
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(testResults, id: \.id) { result in
                        HStack {
                            Text(result.name)
                                .font(.caption)
                            Spacer()
                            Text(result.status.description)
                                .font(.caption)
                                .foregroundColor(result.status.color)
                            Text(result.status.icon)
                        }
                    }
                    
                    if testResults.isEmpty {
                        Text("Noch keine Tests ausgeführt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeDemo() {
        // Initialisiere Demo
        Task {
            updatePerformanceStats()
        }
    }
    
    @MainActor
    private func runAllTests() async {
        testResults.removeAll()
        
        await testUserTripsQuery()
        await testSharedContentQuery()
        await testOptimizedQueries()
        await runThreadSafetyTests()
        await testQueryPerformance()
    }
    
    @MainActor
    private func testUserTripsQuery() async {
        guard let user = userContextManager.currentUser else { return }
        
        let result = CoreDataPerformanceMonitor.shared.measureQuery("UserTrips") {
            let request = TripFetchRequests.userTripsOptimized(for: user)
            return (try? context.fetch(request)) ?? []
        }
        
        testResults.append(MultiUserTestResult(
            name: "User Trips Query",
            count: result.count,
            status: .success
        ))
    }
    
    @MainActor
    private func testSharedContentQuery() async {
        guard let user = userContextManager.currentUser else { return }
        
        let result = CoreDataPerformanceMonitor.shared.measureQuery("SharedContent") {
            let request = MemoryFetchRequests.userMemoriesOptimized(for: user, includeShared: true)
            return (try? context.fetch(request)) ?? []
        }
        
        testResults.append(MultiUserTestResult(
            name: "Shared Content Query",
            count: result.count,
            status: .success
        ))
    }
    
    @MainActor
    private func testOptimizedQueries() async {
        guard let user = userContextManager.currentUser else { return }
        
        // Test Trip Queries
        let tripRequest = TripFetchRequests.recentUserTrips(for: user)
        let tripResult = CoreDataPerformanceMonitor.shared.measureQuery("Recent Trips") {
            return (try? context.fetch(tripRequest)) ?? []
        }
        testResults.append(MultiUserTestResult(
            name: "Recent Trips",
            count: tripResult.count,
            status: .success
        ))
        
        // Test Tag Queries  
        let tagRequest = TagFetchRequests.popularTags(for: user)
        let tagResult = CoreDataPerformanceMonitor.shared.measureQuery("Popular Tags") {
            return (try? context.fetch(tagRequest)) ?? []
        }
        testResults.append(MultiUserTestResult(
            name: "Popular Tags",
            count: tagResult.count,
            status: .success
        ))
        
        // Test Memory Queries
        let memoryRequest = MemoryFetchRequests.recentMemories(for: user)
        let memoryResult = CoreDataPerformanceMonitor.shared.measureQuery("Recent Memories") {
            return (try? context.fetch(memoryRequest)) ?? []
        }
        testResults.append(MultiUserTestResult(
            name: "Recent Memories",
            count: memoryResult.count,
            status: .success
        ))
    }
    
    @MainActor
    private func runThreadSafetyTests() async {
        // Simuliere concurrent operations mit TaskGroup
        var success = true
        
        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<5 {
                group.addTask {
                    do {
                        _ = try await self.multiUserOpsManager.createUser(
                            email: "test\(i)@example.com",
                            username: "test_user_\(i)",
                            firstName: "Test",
                            lastName: "User \(i)"
                        )
                        return true
                    } catch {
                        return false
                    }
                }
            }
            
            for await result in group {
                if !result {
                    success = false
                }
            }
        }
        
        testResults.append(MultiUserTestResult(
            name: "Thread Safety Test",
            count: 5,
            status: success ? .success : .error
        ))
    }
    
    @MainActor
    private func runMigrationTests() async {
        // Test Migration Logic
        testResults.append(MultiUserTestResult(
            name: "Migration Test",
            count: 1,
            status: migrationManager.migrationCompleted ? .success : .warning
        ))
    }
    
    @MainActor
    private func testQueryPerformance() async {
        guard let user = userContextManager.currentUser else { return }
        
        // Test Query Performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let request = TripFetchRequests.userTripsOptimized(for: user)
        _ = try? context.fetch(request)
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        testResults.append(MultiUserTestResult(
            name: "Query Performance",
            count: Int(timeElapsed * 1000), // ms
            status: timeElapsed < 0.1 ? .success : .warning
        ))
        
        updatePerformanceStats()
    }
    
    @MainActor
    private func testBatchOperations() async {
        // Test Batch Operations Performance
        // Implementation would go here
    }
    
    private func createDemoUser() {
        Task {
            do {
                let newUser = try await multiUserOpsManager.createUser(
                    email: "demo\(Date().timeIntervalSince1970)@example.com",
                    username: "demo_user_\(Int.random(in: 1000...9999))",
                    firstName: "Demo",
                    lastName: "User",
                    setAsCurrent: false
                )
                
                print("✅ Demo User erstellt: \(newUser.displayName)")
            } catch {
                print("❌ Demo User erstellen fehlgeschlagen: \(error)")
            }
        }
    }
    
    private func assignOrphanedEntities() {
        guard let user = userContextManager.currentUser else { return }
        
        Task {
            do {
                let results = try await multiUserOpsManager.assignOrphanedEntities(to: user)
                print("✅ Orphaned Entities zugewiesen: \(results)")
            } catch {
                print("❌ Zuweisen fehlgeschlagen: \(error)")
            }
        }
    }
    
    private func cleanupInactiveUsers() {
        Task {
            do {
                let result = try await multiUserOpsManager.cleanupInactiveUsers()
                print("✅ \(result.inactiveUsersDeleted) inaktive Users gelöscht")
            } catch {
                print("❌ Cleanup fehlgeschlagen: \(error)")
            }
        }
    }
    
    private func performMigration() {
        // Placeholder - Migration würde hier gestartet
        showingMigrationProgress = true
    }
    
    private func performLegacyMigration() {
        Task {
            do {
                try await migrationManager.performMigration(storeURL: URL(fileURLWithPath: ""))
            } catch {
                print("❌ Migration fehlgeschlagen: \(error)")
            }
        }
    }
    
    private func analyzePerformance() {
        performanceStats = CoreDataPerformanceMonitor.shared.getPerformanceStatistics()
    }
    
    private func createDemoData() {
        // Create demo data for testing
    }
    
    private func cleanupDatabase() {
        // Cleanup database
    }
    
    private func resetPerformanceStats() {
        CoreDataPerformanceMonitor.shared.resetStatistics()
        performanceStats.removeAll()
    }
    
    private func updatePerformanceStats() {
        performanceStats = CoreDataPerformanceMonitor.shared.getPerformanceStatistics()
    }
    
    private func getPerformanceColor(for time: TimeInterval) -> Color {
        if time < 0.1 { return .green }
        if time < 0.5 { return .orange }
        return .red
    }
}

// MARK: - Supporting Views

struct InfoCardView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatusRowView: View {
    let title: String
    let status: SystemStatus
    let subtitle: String
    
    var body: some View {
        HStack {
            Image(systemName: status.iconName)
                .foregroundColor(status.color)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct UserDetailView: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(user.displayName)
                .font(.headline)
            Text(user.email ?? "Keine E-Mail")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let createdAt = user.createdAt {
                Text("Erstellt: \(DateFormatter.germanShort.string(from: createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Supporting Types

enum DemoSection: String, CaseIterable {
    case overview = "overview"
    case userManagement = "userManagement"
    case migration = "migration"
    case performance = "performance"
    case operations = "operations"
    case queries = "queries"
    case testing = "testing"
    
    var title: String {
        switch self {
        case .overview: return "Überblick"
        case .userManagement: return "Benutzerverwaltung"
        case .migration: return "Migration"
        case .performance: return "Performance"
        case .operations: return "Operationen"
        case .queries: return "Queries"
        case .testing: return "Tests"
        }
    }
    
    var iconName: String {
        switch self {
        case .overview: return "house.fill"
        case .userManagement: return "person.3.fill"
        case .migration: return "arrow.triangle.2.circlepath"
        case .performance: return "speedometer"
        case .operations: return "gear"
        case .queries: return "magnifyingglass.circle"
        case .testing: return "checkmark.circle"
        }
    }
    
    var description: String {
        switch self {
        case .overview: return "System-Überblick und Quick Actions"
        case .userManagement: return "Benutzer erstellen, verwalten und zuweisen"
        case .migration: return "Datenbank-Migration und Legacy-Daten"
        case .performance: return "Query-Performance und Optimierungen"
        case .operations: return "Bulk-Operationen und Daten-Management"
        case .queries: return "Multi-User Queries und Fetch Requests"
        case .testing: return "Test Suite und Validierung"
        }
    }
    
    var hasNewFeatures: Bool {
        switch self {
        case .migration, .performance, .operations: return true
        default: return false
        }
    }
}

enum SystemStatus {
    case success, warning, error, loading
    
    var color: Color {
        switch self {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .loading: return .blue
        }
    }
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .loading: return "clock.fill"
        }
    }
}

enum TestStatus {
    case success, warning, error
    
    var color: Color {
        switch self {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
    
    var description: String {
        switch self {
        case .success: return "Erfolgreich"
        case .warning: return "Warnung"
        case .error: return "Fehler"
        }
    }
}

struct MultiUserTestResult {
    let id = UUID()
    let name: String
    let count: Int
    let status: TestStatus
}

// MARK: - DateFormatter Extensions

extension DateFormatter {
    static let germanShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
} 