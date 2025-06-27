//
//  SyncStatusToolbarView.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import SwiftUI

/// Eine View, die den Synchronisierungsstatus in der Toolbar anzeigt
struct SyncStatusToolbarView: View {
    @ObservedObject private var syncManager = SyncManager.shared
    @ObservedObject private var mediaSyncCoordinator = MediaSyncCoordinator.shared
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        Group {
            if settings.storageMode != .cloudKit && settings.syncEnabled {
                if syncManager.isSyncing || mediaSyncCoordinator.isSyncing {
                    // Synchronisierung läuft
                    Button(action: {
                        // Öffne die SyncSettingsView
                    }) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(width: 20, height: 20)
                    }
                } else if let error = syncManager.lastError {
                    // Fehler bei der Synchronisierung
                    Button(action: {
                        // Öffne die SyncSettingsView
                    }) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                } else if syncManager.lastSyncDate != nil {
                    // Letzte Synchronisierung erfolgreich
                    Button(action: {
                        // Öffne die SyncSettingsView
                    }) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                    }
                } else {
                    // Noch keine Synchronisierung durchgeführt
                    Button(action: {
                        // Öffne die SyncSettingsView
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct SyncStatusToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        SyncStatusToolbarView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 