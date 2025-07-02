//
//  BackendSettingsView.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import SwiftUI
import Combine

struct BackendSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var apiClient = APIClient.shared
    
    @State private var showingConnectionAlert = false
    @State private var connectionAlertTitle = ""
    @State private var connectionAlertMessage = ""
    @State private var tempPassword = ""
    @State private var showingDeleteCredentialsAlert = false
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Storage Mode Selection
                    storageModeSection
                    
                    // Backend Configuration
                    if appSettings.shouldUseBackend {
                        backendConfigurationSection
                        connectionTestSection
                        syncSettingsSection
                    }
                    
                    // Network Status
                    networkStatusSection
                }
                .padding()
            }
            .navigationTitle("Backend-Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            tempPassword = appSettings.password
        }
        .alert(connectionAlertTitle, isPresented: $showingConnectionAlert) {
            Button("OK") { }
        } message: {
            Text(connectionAlertMessage)
        }
        .alert("Anmeldedaten löschen?", isPresented: $showingDeleteCredentialsAlert) {
            Button("Löschen", role: .destructive) {
                deleteCredentials()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Dies wird alle gespeicherten Backend-Anmeldedaten unwiderruflich löschen.")
        }
    }
    
    // MARK: - Storage Mode Section
    
    private var storageModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Speichermodus")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(StorageMode.allCases) { mode in
                    storageModeRow(for: mode)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private func storageModeRow(for mode: StorageMode) -> some View {
        Button {
            appSettings.storageMode = mode
        } label: {
            HStack {
                Image(systemName: mode.iconName)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: appSettings.storageMode == mode ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(appSettings.storageMode == mode ? .blue : .secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Backend Configuration Section
    
    private var backendConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Backend-Konfiguration")
                .font(.headline)
            
            VStack(spacing: 16) {
                // Backend URL
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server-URL")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("https://api.journiary.com", text: $appSettings.backendURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Backend Server URL")
                }
                
                // Username- und Passwortfelder wurden entfernt, da sie nicht mehr editier- oder sichtbar sein sollen.
                
                // Delete Credentials Button
                if appSettings.isBackendConfigured {
                    Button("Anmeldedaten löschen") {
                        showingDeleteCredentialsAlert = true
                    }
                    .foregroundColor(.red)
                    .font(.footnote)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    // MARK: - Connection Test Section
    
    private var connectionTestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Verbindungstest")
                .font(.headline)
            
            VStack(spacing: 16) {
                Button {
                    testConnection()
                } label: {
                    HStack {
                        if apiClient.isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "network")
                        }
                        
                        Text(apiClient.isTestingConnection ? "Teste Verbindung..." : "Verbindung testen")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canTestConnection ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!canTestConnection || apiClient.isTestingConnection)
                .accessibilityLabel("Backend Verbindung testen")
                
                // Last test result
                if let lastTest = apiClient.lastConnectionTest {
                    connectionTestResultView(lastTest)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private func connectionTestResultView(_ result: APIClient.ConnectionTestResult) -> some View {
        HStack {
            Image(systemName: result.isSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.isSuccessful ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if let serverVersion = result.serverVersion {
                    Text("Server-Version: \(serverVersion)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text("Getestet: \(result.timestamp.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(result.isSuccessful ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Sync Settings Section
    
    private var syncSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Synchronisation")
                .font(.headline)
            
            VStack(spacing: 16) {
                // Auto-Sync Toggle
                Toggle("Automatische Synchronisation", isOn: $appSettings.autoSyncEnabled)
                    .accessibilityLabel("Automatische Synchronisation aktivieren")
                
                if appSettings.autoSyncEnabled {
                    // Sync Interval
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sync-Intervall")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Sync-Intervall", selection: $appSettings.syncInterval) {
                            ForEach(AppSettings.syncIntervalOptions, id: \.value) { option in
                                Text(option.title).tag(option.value)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accessibilityLabel("Synchronisations-Intervall auswählen")
                    }
                    
                    // Background Sync
                    Toggle("Hintergrund-Synchronisation", isOn: $appSettings.backgroundSyncEnabled)
                        .accessibilityLabel("Synchronisation im Hintergrund aktivieren")
                    
                    // WiFi-Only Sync
                    Toggle("Nur über WLAN synchronisieren", isOn: $appSettings.wifiOnlySyncEnabled)
                        .accessibilityLabel("Synchronisation nur über WLAN")
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    // MARK: - Network Status Section
    
    private var networkStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Netzwerkstatus")
                .font(.headline)
            
            HStack {
                Image(systemName: networkMonitor.connectionType.iconName)
                    .font(.title2)
                    .foregroundColor(Color(networkMonitor.connectionQualityColor))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(networkMonitor.connectionStatusText)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if networkMonitor.isConnected && appSettings.wifiOnlySyncEnabled && !networkMonitor.isWiFiConnected {
                        Text("Synchronisation pausiert (nur WLAN)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    // MARK: - Helper Properties
    
    private var canTestConnection: Bool {
        return appSettings.isBackendConfigured
    }
    
    // MARK: - Helper Methods
    
    private func saveSettings() {
        // Passwort kann hier nicht geändert werden – lediglich Backend-URL wird live via Binding gespeichert.
    }
    
    private func testConnection() {
        guard canTestConnection else { return }
        
        apiClient.testConnection(
            url: appSettings.backendURL,
            username: appSettings.username,
            password: tempPassword
        )
        .sink { result in
            connectionAlertTitle = result.isSuccessful ? "Verbindung erfolgreich" : "Verbindung fehlgeschlagen"
            connectionAlertMessage = result.statusText
            
            if let serverVersion = result.serverVersion {
                connectionAlertMessage += "\n\nServer-Version: \(serverVersion)"
            }
            
            showingConnectionAlert = true
        }
        .store(in: &cancellables)
    }
    
    private func deleteCredentials() {
        appSettings.username = ""
        appSettings.password = ""
        tempPassword = ""
        appSettings.deletePasswordFromKeychain()
    }
}

#Preview {
    BackendSettingsView()
} 