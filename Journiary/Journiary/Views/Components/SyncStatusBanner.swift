import SwiftUI

/// Banner zur persistenten Anzeige des Synchronisationsstatus.
/// 
/// Dieses Banner implementiert Phase 5.3 des Implementierungsplans:
/// "Visuelles Feedback: Anzeige von Indikatoren um dem Benutzer zu signalisieren,
/// dass eine Synchronisation stattfindet."
///
/// Das Banner zeigt sich nur bei wichtigen Sync-Zuständen:
/// - Aktive Synchronisation
/// - Sync-Fehler  
/// - Veraltete Daten (nach längerer Zeit)
struct SyncStatusBanner: View {
    @EnvironmentObject private var syncTriggerManager: SyncTriggerManager
    
    /// Zeigt das Banner an, wenn es relevante Informationen gibt
    private var shouldShowBanner: Bool {
        syncTriggerManager.isSyncing || 
        syncTriggerManager.lastSyncError != nil ||
        syncTriggerManager.isLastSyncStale(threshold: 1800) // 30 Minuten
    }
    
    /// Bestimmt den Banner-Typ basierend auf dem aktuellen Status
    private var bannerType: BannerType {
        if syncTriggerManager.isSyncing {
            return .syncing
        } else if syncTriggerManager.lastSyncError != nil {
            return .error
        } else if syncTriggerManager.isLastSyncStale(threshold: 1800) {
            return .stale
        } else {
            return .syncing // Fallback, sollte nicht erreicht werden
        }
    }
    
    enum BannerType {
        case syncing
        case error
        case stale
        
        var backgroundColor: Color {
            switch self {
            case .syncing: return .blue
            case .error: return .red
            case .stale: return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .syncing: return "arrow.triangle.2.circlepath"
            case .error: return "exclamationmark.triangle.fill"
            case .stale: return "clock.fill"
            }
        }
        
        var message: String {
            switch self {
            case .syncing: return "Synchronisation läuft..."
            case .error: return "Synchronisation fehlgeschlagen"
            case .stale: return "Daten sind veraltet"
            }
        }
    }
    
    var body: some View {
        if shouldShowBanner {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: bannerType.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(bannerType == .syncing && syncTriggerManager.isSyncing ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), 
                              value: bannerType == .syncing && syncTriggerManager.isSyncing)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Hauptnachricht
                    Text(bannerType.message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    // Zusätzliche Info
                    if let additionalInfo = additionalInfo {
                        Text(additionalInfo)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Aktion-Button
                if bannerType != .syncing {
                    actionButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(bannerType.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 0)) // Gesamte Breite
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: shouldShowBanner)
        }
    }
    
    // MARK: - Computed Properties
    
    private var additionalInfo: String? {
        switch bannerType {
        case .syncing:
            return nil
        case .error:
            if let error = syncTriggerManager.lastSyncError {
                return String(error.prefix(50)) + (error.count > 50 ? "..." : "")
            }
            return nil
        case .stale:
            return "Letzter Sync: \(syncTriggerManager.lastSyncFormatted)"
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch bannerType {
        case .syncing:
            // Kein Button während Sync läuft
            EmptyView()
        case .error, .stale:
            Button(action: {
                Task {
                    await syncTriggerManager.triggerManualSync()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("Wiederholen")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(syncTriggerManager.isSyncing)
        }
    }
}

// MARK: - Conditional Banner

/// Banner, das nur bei bestimmten Bedingungen angezeigt wird
struct ConditionalSyncStatusBanner: View {
    @EnvironmentObject private var syncTriggerManager: SyncTriggerManager
    
    let showOnlyDuringSync: Bool
    let showOnErrors: Bool
    let showOnStaleData: Bool
    
    init(showOnlyDuringSync: Bool = false, 
         showOnErrors: Bool = true, 
         showOnStaleData: Bool = false) {
        self.showOnlyDuringSync = showOnlyDuringSync
        self.showOnErrors = showOnErrors
        self.showOnStaleData = showOnStaleData
    }
    
    private var shouldShow: Bool {
        if showOnlyDuringSync && syncTriggerManager.isSyncing {
            return true
        }
        if showOnErrors && syncTriggerManager.lastSyncError != nil {
            return true
        }
        if showOnStaleData && syncTriggerManager.isLastSyncStale(threshold: 1800) {
            return true
        }
        return false
    }
    
    var body: some View {
        if shouldShow {
            SyncStatusBanner()
        }
    }
}

// MARK: - Inline Sync Status

/// Kompakte Inline-Anzeige für Sync-Status
struct InlineSyncStatus: View {
    @EnvironmentObject private var syncTriggerManager: SyncTriggerManager
    
    var body: some View {
        HStack(spacing: 8) {
            if syncTriggerManager.isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
                
                Text("Synchronisiert...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if syncTriggerManager.lastSyncError != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                
                Text("Sync-Fehler")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                
                Text("Aktuell")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - View Extensions

extension View {
    /// Fügt ein Sync-Status-Banner zur View hinzu
    func withSyncStatusBanner() -> some View {
        VStack(spacing: 0) {
            SyncStatusBanner()
            self
        }
    }
    
    /// Fügt ein konditionelles Sync-Status-Banner hinzu
    func withConditionalSyncBanner(
        showOnlyDuringSync: Bool = false,
        showOnErrors: Bool = true,
        showOnStaleData: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            ConditionalSyncStatusBanner(
                showOnlyDuringSync: showOnlyDuringSync,
                showOnErrors: showOnErrors,
                showOnStaleData: showOnStaleData
            )
            self
        }
    }
}

// MARK: - Preview

struct SyncStatusBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Syncing Banner
            SyncStatusBanner()
                .environmentObject(createSyncingManager())
            
            // Error Banner
            SyncStatusBanner()
                .environmentObject(createErrorManager())
            
            // Stale Banner
            SyncStatusBanner()
                .environmentObject(createStaleManager())
            
            // Inline Status
            InlineSyncStatus()
                .environmentObject(createSyncingManager())
            
            // Enhanced Banner
            EnhancedSyncStatusBanner()
        }
        .previewLayout(.sizeThatFits)
    }
    
    static func createSyncingManager() -> SyncTriggerManager {
        let manager = SyncTriggerManager()
        manager.isSyncing = true
        return manager
    }
    
    static func createErrorManager() -> SyncTriggerManager {
        let manager = SyncTriggerManager()
        manager.lastSyncError = "Netzwerkverbindung fehlgeschlagen"
        return manager
    }
    
    static func createStaleManager() -> SyncTriggerManager {
        let manager = SyncTriggerManager()
        manager.lastSyncAttempt = Date().addingTimeInterval(-2000) // 33 Minuten alt
        return manager
    }
}

// MARK: - Enhanced Sync Status Banner (Step 10.2)

/// Erweiterte Sync-Status-Banner-Implementierung gemäß Schritt 10.2
struct EnhancedSyncStatusBanner: View {
    @StateObject private var viewModel = SyncStatusViewModel()
    @EnvironmentObject private var syncTriggerManager: SyncTriggerManager
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Haupt-Status-Banner
            HStack {
                statusIcon
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.statusText)
                        .font(.headline)
                        .foregroundColor(statusColor)
                    
                    if let detailText = viewModel.detailText {
                        Text(detailText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if viewModel.isActive {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: { showDetails.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .animation(.easeInOut(duration: 0.3), value: viewModel.syncStatus)
            
            // Erweiterte Details (ausklappbar)
            if showDetails {
                SyncDetailView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .slide))
            }
        }
        .cornerRadius(12)
        .shadow(radius: 2)
        .onAppear {
            viewModel.startMonitoring(with: syncTriggerManager)
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
    
    private var statusIcon: some View {
        Group {
            switch viewModel.syncStatus {
            case .idle:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            case .conflict:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.orange)
            }
        }
        .font(.title2)
    }
    
    private var statusColor: Color {
        switch viewModel.syncStatus {
        case .idle: return .green
        case .syncing: return .blue
        case .error: return .red
        case .conflict: return .orange
        }
    }
    
    private var backgroundColor: Color {
        switch viewModel.syncStatus {
        case .idle: return Color.green.opacity(0.1)
        case .syncing: return Color.blue.opacity(0.1)
        case .error: return Color.red.opacity(0.1)
        case .conflict: return Color.orange.opacity(0.1)
        }
    }
}

struct SyncDetailView: View {
    @ObservedObject var viewModel: SyncStatusViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            // Sync-Statistiken
            HStack {
                VStack(alignment: .leading) {
                    Text("Letzte Synchronisation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.lastSyncTime)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Ausstehende Elemente")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.pendingCount)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Fortschrittsbalken für verschiedene Entity-Typen
            ForEach(viewModel.entityProgress, id: \.entityType) { progress in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(progress.entityType)
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(progress.synced)/\(progress.total)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: progress.percentage)
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(y: 0.5)
                }
            }
            
            // Aktions-Buttons
            HStack {
                if viewModel.canRetry {
                    Button("Wiederholen") {
                        viewModel.retrySync()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Spacer()
                
                Button("Sync-Debug") {
                    viewModel.showDebugView = true
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .sheet(isPresented: $viewModel.showDebugView) {
            SyncDebugDashboard()
        }
    }
}

// MARK: - Enhanced Sync Status ViewModel

class SyncStatusViewModel: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle
    @Published var statusText: String = "Synchronisiert"
    @Published var detailText: String?
    @Published var pendingCount: Int = 0
    @Published var lastSyncTime: String = "Nie"
    @Published var entityProgress: [EntityProgress] = []
    @Published var isActive: Bool = false
    @Published var canRetry: Bool = false
    @Published var showDebugView: Bool = false
    
    private var syncManager = SyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // SyncTriggerManager wird über Dependency Injection bereitgestellt
    weak var syncTriggerManager: SyncTriggerManager?
    
    enum SyncStatus {
        case idle
        case syncing
        case error
        case conflict
    }
    
    struct EntityProgress {
        let entityType: String
        let synced: Int
        let total: Int
        
        var percentage: Double {
            total > 0 ? Double(synced) / Double(total) : 0.0
        }
    }
    
    @MainActor
    func startMonitoring(with triggerManager: SyncTriggerManager) {
        self.syncTriggerManager = triggerManager
        
        // Überwache Sync-Status-Änderungen über SyncTriggerManager
        triggerManager.$isSyncing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSyncing in
                self?.updateSyncingStatus(isSyncing)
            }
            .store(in: &cancellables)
        
        // Überwache Sync-Fehler
        triggerManager.$lastSyncError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.updateErrorStatus(error)
            }
            .store(in: &cancellables)
        
        // Timer für regelmäßige Updates
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadInitialData()
                }
            }
            .store(in: &cancellables)
        
        // Initiale Daten laden
        loadInitialData()
    }
    
    func stopMonitoring() {
        cancellables.removeAll()
    }
    
    @MainActor
    private func updateSyncingStatus(_ isSyncing: Bool) {
        if isSyncing {
            syncStatus = .syncing
            statusText = "Synchronisiert..."
            detailText = "Daten werden abgeglichen"
            isActive = true
            canRetry = false
        } else {
            // Zurück zu Idle wenn kein Fehler vorliegt
            if syncTriggerManager?.lastSyncError == nil {
                syncStatus = .idle
                statusText = "Synchronisiert"
                detailText = nil
                isActive = false
                canRetry = false
            }
        }
    }
    
    @MainActor
    private func updateErrorStatus(_ error: String?) {
        if let error = error, syncTriggerManager?.isSyncing == false {
            syncStatus = .error
            statusText = "Sync-Fehler"
            detailText = error
            isActive = false
            canRetry = true
        }
    }
    
    @MainActor
    private func loadInitialData() {
        // Lade Sync-Statistiken aus Core Data
        // Simuliere Statistiken - in echter Implementation würde dies aus Core Data kommen
        self.pendingCount = self.calculatePendingEntities()
        self.lastSyncTime = self.formatLastSyncTime(syncTriggerManager?.lastSyncAttempt)
        self.entityProgress = self.generateEntityProgress()
    }
    
    private func calculatePendingEntities() -> Int {
        // Simulierte Berechnung - in echter Implementation Core Data Query
        return Int.random(in: 0...25)
    }
    
    private func generateEntityProgress() -> [EntityProgress] {
        // Simulierte Entity-Progress - in echter Implementation aus Core Data
        return [
            EntityProgress(entityType: "Memories", synced: 45, total: 50),
            EntityProgress(entityType: "Photos", synced: 128, total: 135),
            EntityProgress(entityType: "Tracks", synced: 12, total: 15),
            EntityProgress(entityType: "Tags", synced: 23, total: 23)
        ]
    }
    
    private func formatLastSyncTime(_ date: Date?) -> String {
        guard let date = date else { return "Nie" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    func retrySync() {
        Task {
            await syncTriggerManager?.triggerManualSync()
        }
    }
}

import Combine 