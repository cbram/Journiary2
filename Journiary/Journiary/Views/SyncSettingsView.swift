//
//  SyncSettingsView.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import SwiftUI

struct SyncSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var offlineQueue = OfflineQueue.shared
    @ObservedObject private var conflictResolver = ConflictResolver.shared
    
    @State private var showingResetAlert = false
    @State private var showingManualSyncAlert = false
    @State private var isManualSyncing = false
    @State private var manualSyncResult = ""
    
    var body: some View {
        Form {
            syncStatusSection
            
            generalSyncSection
            
            networkSection
            
            mediaSection
            
            offlineModeSection
            
            conflictResolutionSection
            
            actionSection
        }
        .navigationTitle("Synchronisierung")
        .alert(isPresented: $showingResetAlert) {
            Alert(
                title: Text("Einstellungen zurücksetzen"),
                message: Text("Möchten Sie alle Synchronisierungseinstellungen auf die Standardwerte zurücksetzen?"),
                primaryButton: .destructive(Text("Zurücksetzen")) {
                    resetSyncSettings()
                },
                secondaryButton: .cancel(Text("Abbrechen"))
            )
        }
    }
    
    private var syncStatusSection: some View {
        Section(header: Text("Status")) {
            HStack {
                NetworkStatusBadge()
                
                Spacer()
                
                if networkMonitor.canSync() {
                    Text("Bereit zur Synchronisierung")
                        .foregroundColor(.green)
                } else {
                    Text("Synchronisierung nicht möglich")
                        .foregroundColor(.red)
                }
            }
            
            if !offlineQueue.operations.isEmpty {
                NavigationLink(destination: OfflineQueueView()) {
                    HStack {
                        Text("Ausstehende Operationen")
                        Spacer()
                        Text("\(offlineQueue.operations.count)")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if !conflictResolver.conflicts.isEmpty {
                NavigationLink(destination: ConflictResolutionView()) {
                    HStack {
                        Text("Konflikte")
                        Spacer()
                        Text("\(conflictResolver.conflicts.count)")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private var generalSyncSection: some View {
        Section(header: Text("Allgemeine Einstellungen")) {
            Toggle("Synchronisierung aktivieren", isOn: $settings.syncEnabled)
            
            if settings.syncEnabled {
                Toggle("Automatisch synchronisieren", isOn: $settings.syncAutomatically)
                
                if settings.syncAutomatically {
                    NavigationLink(destination: syncIntervalPicker) {
                        HStack {
                            Text("Synchronisierungsintervall")
                            Spacer()
                            Text(settings.formattedSyncInterval)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Button(action: manualSync) {
                    if isManualSyncing {
                        HStack {
                            Text("Synchronisierung läuft...")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Text("Jetzt synchronisieren")
                    }
                }
                .disabled(isManualSyncing || !networkMonitor.canSync())
                
                if !manualSyncResult.isEmpty {
                    Text(manualSyncResult)
                        .font(.caption)
                        .foregroundColor(manualSyncResult.contains("erfolgreich") ? .green : .red)
                }
            }
        }
    }
    
    private var networkSection: some View {
        Section(header: Text("Netzwerkeinstellungen")) {
            Toggle("Nur über WLAN synchronisieren", isOn: $settings.syncOnlyOnWifi)
            
            Toggle("Nur beim Laden synchronisieren", isOn: $settings.syncOnlyWhenCharging)
            
            Toggle("Teure Verbindungen vermeiden", isOn: $settings.avoidExpensiveConnections)
        }
    }
    
    private var mediaSection: some View {
        Section(header: Text("Medien")) {
            Toggle("Medien synchronisieren", isOn: $settings.syncMedia)
            
            if settings.syncMedia {
                Toggle("Medien automatisch herunterladen", isOn: $settings.autoDownloadMedia)
                
                NavigationLink(destination: ConnectionDetailsView()) {
                    Text("Verbindungsdetails anzeigen")
                }
            }
        }
    }
    
    private var offlineModeSection: some View {
        Section(header: Text("Offline-Modus")) {
            Toggle("Offline-Modus aktivieren", isOn: $settings.offlineModeEnabled)
            
            if settings.offlineModeEnabled {
                NavigationLink(destination: offlineStoragePicker) {
                    HStack {
                        Text("Maximale Speichergröße")
                        Spacer()
                        Text(settings.formattedMaxOfflineStorageSize)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var conflictResolutionSection: some View {
        Section(header: Text("Konfliktlösung")) {
            NavigationLink(destination: ConflictResolutionView()) {
                HStack {
                    Text("Konfliktstrategie")
                    Spacer()
                    Text(conflictStrategyDisplayName)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var actionSection: some View {
        Section {
            Button("Einstellungen zurücksetzen") {
                showingResetAlert = true
            }
            .foregroundColor(.red)
        }
    }
    
    private var syncIntervalPicker: some View {
        VStack {
            Picker("Intervall", selection: $settings.syncInterval) {
                Text("15 Minuten").tag(TimeInterval(15 * 60))
                Text("30 Minuten").tag(TimeInterval(30 * 60))
                Text("1 Stunde").tag(TimeInterval(60 * 60))
                Text("2 Stunden").tag(TimeInterval(2 * 60 * 60))
                Text("4 Stunden").tag(TimeInterval(4 * 60 * 60))
                Text("8 Stunden").tag(TimeInterval(8 * 60 * 60))
                Text("12 Stunden").tag(TimeInterval(12 * 60 * 60))
                Text("24 Stunden").tag(TimeInterval(24 * 60 * 60))
            }
            .pickerStyle(WheelPickerStyle())
            .padding()
            
            Text("Die App wird in diesem Intervall automatisch mit dem Server synchronisiert, wenn eine Verbindung verfügbar ist.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        }
        .navigationTitle("Synchronisierungsintervall")
    }
    
    private var offlineStoragePicker: some View {
        VStack {
            Picker("Maximale Größe", selection: $settings.maxOfflineStorageSize) {
                Text("100 MB").tag(100)
                Text("250 MB").tag(250)
                Text("500 MB").tag(500)
                Text("1 GB").tag(1024)
                Text("2 GB").tag(2048)
                Text("5 GB").tag(5120)
                Text("10 GB").tag(10240)
                Text("Unbegrenzt").tag(Int.max)
            }
            .pickerStyle(WheelPickerStyle())
            .padding()
            
            Text("Dies ist die maximale Menge an Speicherplatz, die für offline verfügbare Medien verwendet wird. Wenn diese Grenze erreicht ist, werden ältere Medien automatisch gelöscht.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        }
        .navigationTitle("Maximale Speichergröße")
    }
    
    private var conflictStrategyDisplayName: String {
        switch settings.conflictResolutionStrategy {
        case "localWins":
            return "Lokale Daten bevorzugen"
        case "remoteWins":
            return "Remote-Daten bevorzugen"
        case "manual":
            return "Manuell auflösen"
        case "newerWins":
            return "Neuere Daten bevorzugen"
        default:
            return "Neuere Daten bevorzugen"
        }
    }
    
    private func resetSyncSettings() {
        settings.syncEnabled = false
        settings.syncMedia = true
        settings.syncAutomatically = true
        settings.syncInterval = 3600 // 1 Stunde
        settings.syncOnlyOnWifi = true
        settings.syncOnlyWhenCharging = false
        settings.avoidExpensiveConnections = true
        settings.offlineModeEnabled = true
        settings.autoDownloadMedia = false
        settings.maxOfflineStorageSize = 1024 // 1 GB
        settings.conflictResolutionStrategy = "newerWins"
    }
    
    private func manualSync() {
        guard networkMonitor.canSync() else {
            manualSyncResult = "Synchronisierung nicht möglich. Bitte überprüfen Sie Ihre Verbindung."
            return
        }
        
        isManualSyncing = true
        manualSyncResult = ""
        
        BackgroundSyncService.shared.startManualBackgroundSync { success in
            isManualSyncing = false
            
            if success {
                manualSyncResult = "Synchronisierung erfolgreich abgeschlossen."
            } else {
                manualSyncResult = "Synchronisierung fehlgeschlagen. Bitte versuchen Sie es später erneut."
            }
        }
    }
}

struct SyncSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SyncSettingsView()
        }
    }
} 