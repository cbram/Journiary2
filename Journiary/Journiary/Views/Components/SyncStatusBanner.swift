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