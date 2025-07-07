import SwiftUI

/// Toast-System für Synchronisations-Feedback.
/// 
/// Dieses System implementiert Phase 5.3 des Implementierungsplans:
/// "Visuelles Feedback: Anzeige von Indikatoren um dem Benutzer zu signalisieren,
/// dass eine Synchronisation stattfindet."
///
/// Das Toast-System zeigt temporäre Nachrichten für:
/// - Sync-Erfolg
/// - Sync-Fehler
/// - Sync-Start
/// - Netzwerkstatus-Änderungen
struct SyncToastView: View {
    let message: String
    let type: ToastType
    let duration: Double
    
    @State private var isVisible = false
    @State private var offset: CGFloat = -100
    
    enum ToastType {
        case success
        case error
        case info
        case warning
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .blue
            case .warning: return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(type.color)
                
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
            .offset(y: offset)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    offset = 0
                }
                
                // Auto-dismiss nach duration
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    dismiss()
                }
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            offset = -100
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isVisible = false
        }
    }
    
    func show() {
        isVisible = true
    }
}

// MARK: - Toast Manager

@MainActor
class SyncToastManager: ObservableObject {
    @Published var currentToast: ToastData?
    
    private var toastQueue: [ToastData] = []
    private var isShowingToast = false
    
    struct ToastData: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let type: SyncToastView.ToastType
        let duration: Double
        
        static func == (lhs: ToastData, rhs: ToastData) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    func showSuccess(_ message: String, duration: Double = 3.0) {
        showToast(message, type: .success, duration: duration)
    }
    
    func showError(_ message: String, duration: Double = 5.0) {
        showToast(message, type: .error, duration: duration)
    }
    
    func showInfo(_ message: String, duration: Double = 3.0) {
        showToast(message, type: .info, duration: duration)
    }
    
    func showWarning(_ message: String, duration: Double = 4.0) {
        showToast(message, type: .warning, duration: duration)
    }
    
    private func showToast(_ message: String, type: SyncToastView.ToastType, duration: Double) {
        let toast = ToastData(message: message, type: type, duration: duration)
        
        if isShowingToast {
            // Füge zur Queue hinzu
            toastQueue.append(toast)
        } else {
            // Zeige sofort
            currentToast = toast
            isShowingToast = true
            
            // Schedule dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.dismissCurrentToast()
            }
        }
    }
    
    private func dismissCurrentToast() {
        currentToast = nil
        isShowingToast = false
        
        // Zeige nächste Toast aus Queue
        if !toastQueue.isEmpty {
            let nextToast = toastQueue.removeFirst()
            showToast(nextToast.message, type: nextToast.type, duration: nextToast.duration)
        }
    }
    
    func clearAll() {
        currentToast = nil
        toastQueue.removeAll()
        isShowingToast = false
    }
}

// MARK: - Toast Overlay

struct SyncToastOverlay: View {
    @EnvironmentObject private var toastManager: SyncToastManager
    
    var body: some View {
        VStack {
            if let toast = toastManager.currentToast {
                SyncToastView(
                    message: toast.message,
                    type: toast.type,
                    duration: toast.duration
                )
            }
            
            Spacer()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: toastManager.currentToast)
    }
}

// MARK: - Sync-spezifische Toast-Nachrichten

extension SyncToastManager {
    /// Zeigt Toast für Sync-Start
    func showSyncStarted() {
        showInfo("Synchronisation gestartet...")
    }
    
    /// Zeigt Toast für Sync-Erfolg
    func showSyncCompleted() {
        showSuccess("Synchronisation erfolgreich")
    }
    
    /// Zeigt Toast für Sync-Fehler
    func showSyncFailed(error: String) {
        showError("Sync fehlgeschlagen: \(error)")
    }
    
    /// Zeigt Toast für Netzwerk-Wiederherstellung
    func showNetworkRestored() {
        showInfo("Netzwerk wiederhergestellt - Synchronisation läuft...")
    }
    
    /// Zeigt Toast für veraltete Daten
    func showDataStale() {
        showWarning("Daten sind veraltet - Synchronisation empfohlen")
    }
    
    /// Zeigt Toast für automatische Sync-Trigger
    func showAutoSyncTriggered(reason: String) {
        showInfo("Automatische Synchronisation: \(reason)")
    }
}

// MARK: - View Extension für einfache Integration

extension View {
    /// Fügt Toast-Overlay zur View hinzu
    func withSyncToasts() -> some View {
        self.overlay(
            SyncToastOverlay(),
            alignment: .top
        )
    }
}

// MARK: - Preview

struct SyncToastView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Button("Success Toast") {
                SyncToastManager().showSyncCompleted()
            }
            
            Button("Error Toast") {
                SyncToastManager().showSyncFailed(error: "Netzwerkfehler")
            }
            
            Button("Info Toast") {
                SyncToastManager().showSyncStarted()
            }
            
            Button("Warning Toast") {
                SyncToastManager().showDataStale()
            }
        }
        .padding()
        .withSyncToasts()
        .environmentObject(SyncToastManager())
    }
} 