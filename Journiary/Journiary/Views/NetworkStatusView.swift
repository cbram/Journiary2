//
//  NetworkStatusView.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import SwiftUI

struct NetworkStatusView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var offlineQueue = OfflineQueue.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if networkMonitor.status == .disconnected {
                offlineStatusBar
            } else if !offlineQueue.operations.isEmpty {
                pendingOperationsBar
            }
            
            Divider()
        }
    }
    
    private var offlineStatusBar: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.white)
            
            Text("Offline-Modus")
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
            
            if !offlineQueue.operations.isEmpty {
                Text("\(offlineQueue.operations.count) ausstehend")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.red)
        .transition(.move(edge: .top))
    }
    
    private var pendingOperationsBar: some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.white)
            
            Text("Ausstehende Änderungen")
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(offlineQueue.operations.count)")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.orange)
        .transition(.move(edge: .top))
    }
}

struct NetworkStatusBadge: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .foregroundColor(statusColor)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var iconName: String {
        switch networkMonitor.connectionType {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .ethernet:
            return "network"
        case .unknown:
            return "wifi.slash"
        }
    }
    
    private var statusText: String {
        if networkMonitor.status == .connected {
            switch networkMonitor.connectionType {
            case .wifi:
                return "WLAN"
            case .cellular:
                return "Mobilfunk"
            case .ethernet:
                return "Ethernet"
            case .unknown:
                return "Verbunden"
            }
        } else {
            return "Offline"
        }
    }
    
    private var statusColor: Color {
        if networkMonitor.status == .connected {
            if networkMonitor.isExpensive {
                return .orange
            } else {
                return .green
            }
        } else {
            return .red
        }
    }
}

struct ConnectionDetailsView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var offlineQueue = OfflineQueue.shared
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            connectionStatusSection
            
            if networkMonitor.status == .connected {
                connectionDetailsSection
            }
            
            if !offlineQueue.operations.isEmpty {
                offlineQueueSection
            }
            
            syncSettingsSection
        }
        .padding()
    }
    
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verbindungsstatus")
                .font(.headline)
            
            HStack {
                NetworkStatusBadge()
                
                Spacer()
                
                Text(networkMonitor.status == .connected ? "Verbunden" : "Keine Verbindung")
                    .foregroundColor(networkMonitor.status == .connected ? .green : .red)
                    .font(.subheadline)
            }
        }
    }
    
    private var connectionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verbindungsdetails")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                connectionDetailRow(label: "Typ", value: connectionTypeText)
                connectionDetailRow(label: "Kostenpflichtig", value: networkMonitor.isExpensive ? "Ja" : "Nein")
                connectionDetailRow(label: "Eingeschränkt", value: networkMonitor.isConstrained ? "Ja" : "Nein")
                connectionDetailRow(label: "Synchronisierung möglich", value: networkMonitor.canSync() ? "Ja" : "Nein")
            }
        }
    }
    
    private var offlineQueueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Offline-Warteschlange")
                .font(.headline)
            
            HStack {
                Text("\(offlineQueue.operations.count) ausstehende Operationen")
                    .font(.subheadline)
                
                Spacer()
                
                NavigationLink(destination: OfflineQueueView()) {
                    Text("Anzeigen")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var syncSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Synchronisierungseinstellungen")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                connectionDetailRow(label: "Synchronisierung aktiviert", value: settings.syncEnabled ? "Ja" : "Nein")
                connectionDetailRow(label: "Nur über WLAN", value: settings.syncOnlyOnWifi ? "Ja" : "Nein")
                connectionDetailRow(label: "Teure Verbindungen vermeiden", value: settings.avoidExpensiveConnections ? "Ja" : "Nein")
            }
            
            NavigationLink(destination: SyncSettingsView()) {
                Text("Einstellungen ändern")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.top, 4)
        }
    }
    
    private func connectionDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
        }
    }
    
    private var connectionTypeText: String {
        switch networkMonitor.connectionType {
        case .wifi:
            return "WLAN"
        case .cellular:
            return "Mobilfunk"
        case .ethernet:
            return "Ethernet"
        case .unknown:
            return "Unbekannt"
        }
    }
}

struct NetworkStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            NetworkStatusView()
            Spacer()
        }
    }
} 