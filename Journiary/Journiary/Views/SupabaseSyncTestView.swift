import SwiftUI
import CoreData

// MARK: - SupabaseSyncTestView

struct SupabaseSyncTestView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var supabaseManager = SupabaseManager.shared
    @StateObject private var syncService: TripSyncService
    
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    @State private var showingLogs = false
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        _syncService = StateObject(wrappedValue: TripSyncService(context: context))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status
                connectionStatusView
                
                // Sync Progress
                syncProgressView
                
                // Test Buttons
                testButtonsView
                
                // Test Results
                testResultsView
                
                Spacer()
            }
            .padding()
            .navigationTitle("Supabase Sync Test")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logs") {
                        showingLogs = true
                    }
                }
            }
            .sheet(isPresented: $showingLogs) {
                syncLogsView
            }
        }
    }
    
    // MARK: - UI Components
    
    private var connectionStatusView: some View {
        VStack {
            Text("Verbindungsstatus")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(connectionStatusColor)
                    .frame(width: 12, height: 12)
                
                Text(supabaseManager.connectionStatus.description)
                    .font(.subheadline)
                
                Spacer()
                
                Button("Neuverbinden") {
                    Task {
                        await testConnection()
                    }
                }
                .disabled(isRunningTests)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var syncProgressView: some View {
        VStack {
            Text("Synchronisationsfortschritt")
                .font(.headline)
            
            VStack(spacing: 10) {
                HStack {
                    Text("Fortschritt:")
                    Spacer()
                    Text("\(syncService.syncProgress.processedItems) / \(syncService.syncProgress.totalItems)")
                }
                
                ProgressView(value: syncService.syncProgress.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                if let lastSync = syncService.lastSyncDate {
                    HStack {
                        Text("Letzter Sync:")
                        Spacer()
                        Text(lastSync, style: .time)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var testButtonsView: some View {
        VStack(spacing: 10) {
            Text("Test-Aktionen")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                TestButton(title: "Connection Test", icon: "wifi") {
                    Task { await testConnection() }
                }
                
                TestButton(title: "Create Test Trip", icon: "plus.circle") {
                    await createTestTrip()
                }
                
                TestButton(title: "Full Sync", icon: "arrow.triangle.2.circlepath") {
                    Task { await performFullSync() }
                }
                
                TestButton(title: "Incremental Sync", icon: "arrow.clockwise") {
                    Task { await performIncrementalSync() }
                }
                
                TestButton(title: "Fetch All Trips", icon: "square.and.arrow.down") {
                    Task { await fetchAllTrips() }
                }
                
                TestButton(title: "Clear Results", icon: "trash") {
                    clearTestResults()
                }
            }
        }
        .disabled(isRunningTests)
    }
    
    private var testResultsView: some View {
        VStack(alignment: .leading) {
            Text("Test-Ergebnisse")
                .font(.headline)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    ForEach(testResults.indices, id: \.self) { index in
                        Text(testResults[index])
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(testResults[index].contains("✅") ? .green : 
                                           testResults[index].contains("❌") ? .red : .primary)
                    }
                }
            }
            .frame(maxHeight: 200)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var syncLogsView: some View {
        NavigationView {
            VStack {
                Text("Sync-Fehler")
                    .font(.headline)
                    .padding()
                
                if syncService.syncErrors.isEmpty {
                    Text("Keine Fehler")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(syncService.syncErrors, id: \.timestamp) { error in
                        VStack(alignment: .leading) {
                            Text(error.operation)
                                .font(.headline)
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(error.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Sync-Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        showingLogs = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var connectionStatusColor: Color {
        switch supabaseManager.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .red
        case .unknown:
            return .gray
        case .error(_):
            return .red
        }
    }
    
    // MARK: - Test Methods
    
    private func testConnection() async {
        isRunningTests = true
        addTestResult("🔄 Teste Verbindung zu Supabase...")
        
        await supabaseManager.checkConnection()
        
        if supabaseManager.isConnected {
            addTestResult("✅ Verbindung erfolgreich")
        } else {
            addTestResult("❌ Verbindung fehlgeschlagen")
        }
        
        isRunningTests = false
    }
    
    private func createTestTrip() async {
        isRunningTests = true
        addTestResult("🔄 Erstelle Test-Trip...")
        
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.name = "Test Trip \(Date().timeIntervalSince1970)"
        trip.tripDescription = "Ein Test-Trip für die Supabase-Synchronisation"
        trip.startDate = Date()
        trip.endDate = Date().addingTimeInterval(7*24*60*60) // 7 Tage später
        trip.isActive = false
        trip.needsSync = true
        trip.createdAt = Date()
        trip.updatedAt = Date()
        trip.syncVersion = 1
        
        do {
            try context.save()
            addTestResult("✅ Test-Trip erstellt: \(trip.name!)")
        } catch {
            addTestResult("❌ Fehler beim Erstellen des Test-Trips: \(error.localizedDescription)")
        }
        
        isRunningTests = false
    }
    
    private func performFullSync() async {
        isRunningTests = true
        addTestResult("🔄 Starte vollständige Synchronisation...")
        
        await syncService.performFullSync()
        
        if syncService.syncErrors.isEmpty {
            addTestResult("✅ Vollständige Synchronisation erfolgreich")
        } else {
            addTestResult("❌ Synchronisation mit \(syncService.syncErrors.count) Fehlern abgeschlossen")
        }
        
        isRunningTests = false
    }
    
    private func performIncrementalSync() async {
        isRunningTests = true
        addTestResult("🔄 Starte inkrementelle Synchronisation...")
        
        await syncService.performIncrementalSync()
        
        if syncService.syncErrors.isEmpty {
            addTestResult("✅ Inkrementelle Synchronisation erfolgreich")
        } else {
            addTestResult("❌ Synchronisation mit \(syncService.syncErrors.count) Fehlern abgeschlossen")
        }
        
        isRunningTests = false
    }
    
    private func fetchAllTrips() async {
        isRunningTests = true
        addTestResult("🔄 Lade alle Trips von Supabase...")
        
        do {
            let trips = try await supabaseManager.fetchAllTrips()
            addTestResult("✅ \(trips.count) Trips von Supabase geladen")
            
            for trip in trips {
                addTestResult("  - \(trip.name)")
            }
        } catch {
            addTestResult("❌ Fehler beim Laden der Trips: \(error.localizedDescription)")
        }
        
        isRunningTests = false
    }
    
    private func clearTestResults() {
        testResults.removeAll()
        addTestResult("🗑️ Test-Ergebnisse gelöscht")
    }
    
    private func addTestResult(_ message: String) {
        DispatchQueue.main.async {
            testResults.append("[\(Date().formatted(date: .omitted, time: .shortened))] \(message)")
        }
    }
}

// MARK: - Supporting Views

struct TestButton: View {
    let title: String
    let icon: String
    let action: () async -> Void
    
    var body: some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(8)
        }
    }
}

// MARK: - Preview

struct SupabaseSyncTestView_Previews: PreviewProvider {
    static var previews: some View {
        SupabaseSyncTestView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
} 