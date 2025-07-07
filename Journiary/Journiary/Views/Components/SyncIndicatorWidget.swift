import SwiftUI

/// Kompaktes Widget zur Anzeige des Synchronisationsstatus.
/// 
/// Dieses Widget implementiert Phase 5.3 des Implementierungsplans:
/// "Visuelles Feedback: Anzeige von Indikatoren um dem Benutzer zu signalisieren,
/// dass eine Synchronisation stattfindet."
///
/// Das Widget zeigt verschiedene Zustände an:
/// - Synchronisation läuft (animierter Indikator)
/// - Synchronisation erfolgreich (Checkmark)
/// - Synchronisation fehlgeschlagen (Warning)
/// - Daten sind veraltet (Clock)
struct SyncIndicatorWidget: View {
    @EnvironmentObject private var syncTriggerManager: SyncTriggerManager
    
    /// Stil-Optionen für das Widget
    enum Style {
        case toolbar    // Kompakt für Toolbar
        case inline     // Inline in Listen
        case prominent  // Prominent in Headers
        case minimal    // Nur Icon
    }
    
    let style: Style
    let showLabel: Bool
    let onTap: (() -> Void)?
    
    init(style: Style = .toolbar, showLabel: Bool = true, onTap: (() -> Void)? = nil) {
        self.style = style
        self.showLabel = showLabel
        self.onTap = onTap
    }
    
    var body: some View {
        Group {
            switch style {
            case .toolbar:
                toolbarStyle
            case .inline:
                inlineStyle
            case .prominent:
                prominentStyle
            case .minimal:
                minimalStyle
            }
        }
        .onTapGesture {
            onTap?()
        }
    }
    
    // MARK: - Style Variants
    
    private var toolbarStyle: some View {
        HStack(spacing: 4) {
            syncIcon
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(iconColor)
            
            if showLabel {
                Text(shortStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var inlineStyle: some View {
        HStack(spacing: 8) {
            syncIcon
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(iconColor)
            
            if showLabel {
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var prominentStyle: some View {
        VStack(spacing: 8) {
            syncIcon
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(iconColor)
            
            if showLabel {
                Text(statusText)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var minimalStyle: some View {
        syncIcon
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(iconColor)
    }
    
    // MARK: - Computed Properties
    
    private var syncIcon: some View {
        Group {
            if syncTriggerManager.isSyncing {
                // Animierter Sync-Indikator
                Image(systemName: "arrow.triangle.2.circlepath")
                    .rotationEffect(.degrees(syncTriggerManager.isSyncing ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: syncTriggerManager.isSyncing)
            } else if syncTriggerManager.lastSyncError != nil {
                // Fehler-Indikator
                Image(systemName: "exclamationmark.triangle.fill")
            } else if syncTriggerManager.isLastSyncStale() {
                // Veraltete Daten
                Image(systemName: "clock.fill")
            } else {
                // Erfolgreich synchronisiert
                Image(systemName: "checkmark.circle.fill")
            }
        }
    }
    
    private var iconColor: Color {
        if syncTriggerManager.isSyncing {
            return .blue
        } else if syncTriggerManager.lastSyncError != nil {
            return .red
        } else if syncTriggerManager.isLastSyncStale() {
            return .orange
        } else {
            return .green
        }
    }
    
    private var backgroundColor: Color {
        if syncTriggerManager.isSyncing {
            return .blue.opacity(0.1)
        } else if syncTriggerManager.lastSyncError != nil {
            return .red.opacity(0.1)
        } else if syncTriggerManager.isLastSyncStale() {
            return .orange.opacity(0.1)
        } else {
            return .green.opacity(0.1)
        }
    }
    
    private var statusText: String {
        if syncTriggerManager.isSyncing {
            return "Synchronisiert..."
        } else if syncTriggerManager.lastSyncError != nil {
            return "Sync-Fehler"
        } else if syncTriggerManager.isLastSyncStale() {
            return "Daten veraltet"
        } else {
            return "Synchronisiert"
        }
    }
    
    private var shortStatusText: String {
        if syncTriggerManager.isSyncing {
            return "Sync..."
        } else if syncTriggerManager.lastSyncError != nil {
            return "Fehler"
        } else if syncTriggerManager.isLastSyncStale() {
            return "Veraltet"
        } else {
            return "OK"
        }
    }
    
    private var subtitleText: String? {
        if syncTriggerManager.isSyncing {
            return nil
        } else if let error = syncTriggerManager.lastSyncError {
            return "Letzter Fehler: \(error.prefix(30))..."
        } else {
            return "Letzter Sync: \(syncTriggerManager.lastSyncFormatted)"
        }
    }
}

// MARK: - Convenience Extensions

extension SyncIndicatorWidget {
    /// Toolbar-Variante für Navigation-Bars
    static func toolbar(onTap: (() -> Void)? = nil) -> some View {
        SyncIndicatorWidget(style: .toolbar, showLabel: true, onTap: onTap)
    }
    
    /// Inline-Variante für Listen und Sections
    static func inline(onTap: (() -> Void)? = nil) -> some View {
        SyncIndicatorWidget(style: .inline, showLabel: true, onTap: onTap)
    }
    
    /// Prominent-Variante für Headers
    static func prominent(onTap: (() -> Void)? = nil) -> some View {
        SyncIndicatorWidget(style: .prominent, showLabel: true, onTap: onTap)
    }
    
    /// Minimal-Variante nur mit Icon
    static func minimal(onTap: (() -> Void)? = nil) -> some View {
        SyncIndicatorWidget(style: .minimal, showLabel: false, onTap: onTap)
    }
}

// MARK: - Preview

struct SyncIndicatorWidget_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Verschiedene Zustände
            Group {
                SyncIndicatorWidget.toolbar()
                    .environmentObject(createSyncingManager())
                
                SyncIndicatorWidget.inline()
                    .environmentObject(createSuccessManager())
                
                SyncIndicatorWidget.prominent()
                    .environmentObject(createErrorManager())
                
                SyncIndicatorWidget.minimal()
                    .environmentObject(createStaleManager())
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
    
    static func createSyncingManager() -> SyncTriggerManager {
        let manager = SyncTriggerManager()
        manager.isSyncing = true
        return manager
    }
    
    static func createSuccessManager() -> SyncTriggerManager {
        let manager = SyncTriggerManager()
        manager.lastSyncAttempt = Date()
        return manager
    }
    
    static func createErrorManager() -> SyncTriggerManager {
        let manager = SyncTriggerManager()
        manager.lastSyncError = "Netzwerkfehler"
        return manager
    }
    
    static func createStaleManager() -> SyncTriggerManager {
        let manager = SyncTriggerManager()
        manager.lastSyncAttempt = Date().addingTimeInterval(-900) // 15 Minuten alt
        return manager
    }
} 