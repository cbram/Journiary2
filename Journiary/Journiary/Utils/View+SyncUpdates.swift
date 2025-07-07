import SwiftUI
import Combine

/// View-Extension für automatische UI-Updates nach erfolgreicher Synchronisation.
/// 
/// Diese Extension implementiert Phase 5.4 des Implementierungsplans:
/// "UI-Aktualisierung: Sicherstellen, dass die Benutzeroberfläche nach einem 
/// erfolgreichen Sync-Zyklus die neuen Daten korrekt darstellt."
extension View {
    
    /// Automatische UI-Aktualisierung nach erfolgreichem Sync
    /// - Parameters:
    ///   - refreshAction: Optionale Aktion die beim Sync-Erfolg ausgeführt wird
    ///   - includeErrorHandling: Wenn true, wird auch auf Sync-Fehler reagiert
    /// - Returns: Eine View die automatisch auf Sync-Events reagiert
    func refreshOnSyncSuccess(
        refreshAction: (() -> Void)? = nil,
        includeErrorHandling: Bool = false
    ) -> some View {
        self.modifier(
            SyncSuccessRefreshModifier(
                refreshAction: refreshAction,
                includeErrorHandling: includeErrorHandling
            )
        )
    }
    
    /// Zeigt einen kurzen Indikator bei automatischem Refresh
    /// - Parameter showIndicator: Ob ein visueller Indikator gezeigt werden soll
    /// - Returns: Eine View mit optionalem Refresh-Indikator
    func withSyncRefreshIndicator(showIndicator: Bool = true) -> some View {
        self.modifier(SyncRefreshIndicatorModifier(showIndicator: showIndicator))
    }
    
    /// Kombiniert automatisches Refresh mit visuellem Indikator
    /// - Parameters:
    ///   - refreshAction: Optionale Aktion die beim Sync-Erfolg ausgeführt wird
    ///   - showIndicator: Ob ein visueller Indikator gezeigt werden soll
    /// - Returns: Eine View die automatisch refresht und einen Indikator zeigt
    func autoRefreshOnSync(
        refreshAction: (() -> Void)? = nil,
        showIndicator: Bool = true
    ) -> some View {
        self
            .refreshOnSyncSuccess(refreshAction: refreshAction)
            .withSyncRefreshIndicator(showIndicator: showIndicator)
    }
}

// MARK: - Sync Success Refresh Modifier

/// ViewModifier der auf Sync-Erfolg reagiert und die UI automatisch aktualisiert
struct SyncSuccessRefreshModifier: ViewModifier {
    let refreshAction: (() -> Void)?
    let includeErrorHandling: Bool
    
    @State private var refreshID = UUID()
    @State private var lastSyncTime: Date?
    
    func body(content: Content) -> some View {
        content
            .id(refreshID)
            .onReceive(SyncNotificationCenter.shared.syncSuccessPublisher) { event in
                handleSyncSuccess(event)
            }
            .onReceive(SyncNotificationCenter.shared.syncErrorPublisher) { event in
                if includeErrorHandling {
                    handleSyncError(event)
                }
            }
    }
    
    private func handleSyncSuccess(_ event: SyncSuccessEvent) {
        print("🔄 View-Refresh: Sync erfolgreich (\(event.reason)) - \(event.syncedEntities.totalUpdated) Entitäten aktualisiert")
        
        // Aktualisiere nur wenn tatsächlich Daten synchronisiert wurden
        if event.syncedEntities.hasUpdates {
            // Kurze Verzögerung für bessere UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                refreshID = UUID()
                lastSyncTime = event.timestamp
                refreshAction?()
            }
        }
    }
    
    private func handleSyncError(_ event: SyncErrorEvent) {
        print("❌ View-Refresh: Sync-Fehler (\(event.reason)) - \(event.error.localizedDescription)")
        // Bei Fehlern können wir optional auch eine Aktualisierung triggern
        // für den Fall, dass partielle Daten existieren
    }
}

// MARK: - Sync Refresh Indicator Modifier

/// ViewModifier der einen visuellen Indikator für automatisches Refresh zeigt
struct SyncRefreshIndicatorModifier: ViewModifier {
    let showIndicator: Bool
    
    @State private var isShowingRefreshIndicator = false
    @State private var lastRefreshTime: Date?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if showIndicator && isShowingRefreshIndicator {
                VStack {
                    HStack {
                        Spacer()
                        refreshIndicator
                        Spacer()
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
        .onReceive(SyncNotificationCenter.shared.syncSuccessPublisher) { event in
            if event.syncedEntities.hasUpdates {
                showRefreshIndicator()
            }
        }
    }
    
    private var refreshIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.clockwise")
                .font(.caption)
                .foregroundColor(.white)
            
            Text("Daten aktualisiert")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.9))
        .clipShape(Capsule())
        .shadow(radius: 2)
    }
    
    private func showRefreshIndicator() {
        guard showIndicator else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingRefreshIndicator = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isShowingRefreshIndicator = false
            }
        }
    }
}

// MARK: - Convenience Extensions für häufige Use Cases

extension View {
    /// Spezielle Extension für Listen-Views
    func autoRefreshList() -> some View {
        self.autoRefreshOnSync(
            refreshAction: {
                // Bei Listen reicht meist der ID-Refresh
                print("📋 Liste automatisch aktualisiert")
            },
            showIndicator: true
        )
    }
    
    /// Spezielle Extension für Detail-Views
    func autoRefreshDetail(refreshAction: @escaping () -> Void) -> some View {
        self.autoRefreshOnSync(
            refreshAction: refreshAction,
            showIndicator: false // Detail-Views brauchen meist keinen Indikator
        )
    }
}

// MARK: - Sync Statistics für Debugging

/// Hilfsklasse für Sync-Statistiken (nur für Debug-Zwecke)
class SyncStatistics: ObservableObject {
    @Published var totalSyncs: Int = 0
    @Published var successfulSyncs: Int = 0
    @Published var failedSyncs: Int = 0
    @Published var lastSyncTime: Date?
    @Published var lastSyncReason: String?
    
    static let shared = SyncStatistics()
    
    private init() {
        // Lausche auf Sync-Events
        SyncNotificationCenter.shared.syncSuccessPublisher
            .sink { event in
                DispatchQueue.main.async {
                    self.totalSyncs += 1
                    self.successfulSyncs += 1
                    self.lastSyncTime = event.timestamp
                    self.lastSyncReason = event.reason
                }
            }
            .store(in: &cancellables)
        
        SyncNotificationCenter.shared.syncErrorPublisher
            .sink { event in
                DispatchQueue.main.async {
                    self.totalSyncs += 1
                    self.failedSyncs += 1
                    self.lastSyncTime = event.timestamp
                    self.lastSyncReason = event.reason
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    var successRate: Double {
        guard totalSyncs > 0 else { return 0.0 }
        return Double(successfulSyncs) / Double(totalSyncs)
    }
} 