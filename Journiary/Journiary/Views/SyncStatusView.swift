//
//  SyncStatusView.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import SwiftUI

/// View zur Anzeige des Synchronisierungsstatus
struct SyncStatusView: View {
    @ObservedObject private var syncManager = SyncManager.shared
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Synchronisierungsstatus
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text(statusText)
                    .font(.headline)
                Spacer()
                
                if syncManager.isSyncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            
            // Letzte Synchronisierung
            if let lastSyncDate = settings.lastSyncDate, lastSyncDate.timeIntervalSince1970 > 0 {
                HStack {
                    Text("Letzte Synchronisierung:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(lastSyncDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                }
            }
            
            // Aktuelle Operation
            if let operation = syncManager.currentSyncOperation, syncManager.isSyncing {
                HStack {
                    Text(operation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(syncManager.syncProgress * 100))%")
                        .font(.subheadline)
                }
                
                ProgressView(value: syncManager.syncProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
            }
            
            // Fehlermeldung
            if let error = syncManager.lastSyncError {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fehler bei der letzten Synchronisierung:")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Aktionsbuttons
            HStack {
                Button(action: {
                    Task {
                        await syncManager.startSync()
                    }
                }) {
                    Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .disabled(syncManager.isSyncing || settings.storageMode == .cloudKit || !settings.syncEnabled)
                
                if syncManager.isSyncing {
                    Button(action: {
                        syncManager.cancelSync()
                    }) {
                        Label("Abbrechen", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // Status-Anzeige
    private var statusIcon: String {
        if syncManager.isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if syncManager.lastSyncError != nil {
            return "exclamationmark.triangle"
        } else if settings.storageMode == .cloudKit {
            return "icloud"
        } else if !settings.syncEnabled {
            return "xmark.circle"
        } else {
            return "checkmark.circle"
        }
    }
    
    private var statusColor: Color {
        if syncManager.isSyncing {
            return .blue
        } else if syncManager.lastSyncError != nil {
            return .red
        } else if settings.storageMode == .cloudKit {
            return .gray
        } else if !settings.syncEnabled {
            return .gray
        } else {
            return .green
        }
    }
    
    private var statusText: String {
        if syncManager.isSyncing {
            return "Synchronisierung läuft..."
        } else if syncManager.lastSyncError != nil {
            return "Synchronisierungsfehler"
        } else if settings.storageMode == .cloudKit {
            return "CloudKit Sync aktiv"
        } else if !settings.syncEnabled {
            return "Synchronisierung deaktiviert"
        } else {
            return "Synchronisierung aktiv"
        }
    }
}

/// View für die Anzeige des Synchronisierungsstatus in der Toolbar
struct SyncStatusToolbarView: View {
    @ObservedObject private var syncManager = SyncManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: {
            showingDetails.toggle()
        }) {
            if syncManager.isSyncing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
            }
        }
        .sheet(isPresented: $showingDetails) {
            NavigationView {
                ScrollView {
                    SyncStatusView()
                        .padding()
                }
                .navigationTitle("Synchronisierungsstatus")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Fertig") {
                            showingDetails = false
                        }
                    }
                }
            }
        }
    }
    
    // Status-Anzeige
    private var statusIcon: String {
        if syncManager.lastSyncError != nil {
            return "exclamationmark.triangle"
        } else if settings.storageMode == .cloudKit {
            return "icloud"
        } else if !settings.syncEnabled {
            return "xmark.circle"
        } else {
            return "arrow.triangle.2.circlepath"
        }
    }
    
    private var statusColor: Color {
        if syncManager.lastSyncError != nil {
            return .red
        } else if settings.storageMode == .cloudKit {
            return .gray
        } else if !settings.syncEnabled {
            return .gray
        } else {
            return .blue
        }
    }
}

struct SyncStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            SyncStatusView()
                .padding()
            
            Spacer()
            
            HStack {
                Spacer()
                SyncStatusToolbarView()
                Spacer()
            }
        }
        .padding()
    }
} 