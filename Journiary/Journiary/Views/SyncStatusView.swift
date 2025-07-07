import SwiftUI

/// View zur Anzeige des Synchronisationsstatus und manuellen Synchronisation.
/// 
/// Diese View zeigt den aktuellen Status der automatischen Sync-Trigger an
/// und ermöglicht es Benutzern, manuelle Synchronisation zu starten.
struct SyncStatusView: View {
    @EnvironmentObject private var syncTriggerManager: SyncTriggerManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Aktueller Sync-Status
                Section("Synchronisationsstatus") {
                    HStack {
                        Image(systemName: syncTriggerManager.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                            .foregroundColor(syncTriggerManager.isSyncing ? .blue : .green)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(syncTriggerManager.isSyncing ? "Synchronisation läuft..." : "Synchronisation bereit")
                                .font(.headline)
                            
                            if let lastSync = syncTriggerManager.lastSyncAttempt {
                                Text("Letzter Versuch: \(syncTriggerManager.lastSyncFormatted)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Noch nie synchronisiert")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if syncTriggerManager.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Fehler-Anzeige
                if let error = syncTriggerManager.lastSyncError {
                    Section("Letzter Fehler") {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                // Manuelle Aktionen
                Section("Aktionen") {
                    Button(action: {
                        Task {
                            await syncTriggerManager.triggerManualSync()
                        }
                    }) {
                        Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(syncTriggerManager.isSyncing)
                    
                    Button(action: {
                        syncTriggerManager.startPeriodicSync()
                    }) {
                        Label("Periodische Sync aktivieren", systemImage: "clock.arrow.circlepath")
                    }
                    
                    Button(action: {
                        syncTriggerManager.stopPeriodicSync()
                    }) {
                        Label("Periodische Sync deaktivieren", systemImage: "clock.badge.xmark")
                    }
                }
                
                // Informationen
                Section("Informationen") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Automatische Synchronisation")
                            .font(.headline)
                        
                        Text("• Beim App-Start")
                        Text("• Nach Authentifizierung")
                        Text("• App in den Vordergrund")
                        Text("• Netzwerk-Wiederherstellung")
                        Text("• Periodisch alle 5 Minuten")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                // Sync-Statistiken
                Section("Statistiken") {
                    HStack {
                        Text("Letzte Synchronisation")
                        Spacer()
                        Text(syncTriggerManager.lastSyncFormatted)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Daten veraltet")
                        Spacer()
                        Text(syncTriggerManager.isLastSyncStale() ? "Ja" : "Nein")
                            .foregroundColor(syncTriggerManager.isLastSyncStale() ? .red : .green)
                    }
                }
            }
            .navigationTitle("Synchronisation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct SyncStatusView_Previews: PreviewProvider {
    static var previews: some View {
        SyncStatusView()
            .environmentObject(SyncTriggerManager())
    }
} 