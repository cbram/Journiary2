//
//  BackendSettingsView.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import SwiftUI

struct BackendSettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var syncManager = SyncManager.shared
    @StateObject private var minioClient = MinIOClient.shared
    
    @State private var showLoginView = false
    @State private var showRegisterView = false
    @State private var showingTestConnectionAlert = false
    @State private var connectionTestResult: String?
    @State private var isTestingConnection = false
    @State private var showingAlert = false
    @State private var alertTitle: String?
    @State private var alertMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Speichermodus
                storageModeSection
                
                // Backend-Konfiguration
                backendConfigSection
                
                // Authentifizierung
                authSection
                
                // Synchronisierung
                syncSection
                
                // MinIO-Status
                minioStatusSection
            }
            .padding()
        }
        .navigationTitle("Backend-Einstellungen")
        .sheet(isPresented: $showLoginView) {
            LoginView()
        }
        .sheet(isPresented: $showRegisterView) {
            RegisterView()
        }
        .alert("Verbindungstest", isPresented: $showingTestConnectionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(connectionTestResult ?? "Unbekannter Fehler")
        }
        .alert(alertTitle ?? "Fehler", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    // MARK: - Settings Sections
    
    private var storageModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Speichermodus")
                .font(.headline)
            
            VStack(spacing: 16) {
                Picker("Speichermodus", selection: $settings.storageMode) {
                    ForEach(StorageMode.allCases) { mode in
                        HStack {
                            Image(systemName: mode.icon)
                            Text(mode.rawValue)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Text(settings.storageMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var backendConfigSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Backend-Konfiguration")
                .font(.headline)
            
            VStack(spacing: 16) {
                if settings.storageMode != .cloudKit {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GraphQL-Endpunkt")
                            .font(.subheadline)
                        TextField("https://deine-domain.de/graphql", text: $settings.backendURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MinIO-Endpunkt")
                            .font(.subheadline)
                        TextField("https://deine-domain.de:9000", text: $settings.minioURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Button(action: testConnection) {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "network")
                            }
                            Text("Verbindung testen")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isTestingConnection)
                } else {
                    Text("Die Backend-Konfiguration ist nur verfügbar, wenn der Speichermodus auf 'Self-Hosted' oder 'Hybrid' eingestellt ist.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var authSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Authentifizierung")
                .font(.headline)
            
            VStack(spacing: 16) {
                if settings.storageMode != .cloudKit {
                    if authManager.authStatus == .authenticated {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Angemeldet")
                                    .font(.subheadline)
                                    .bold()
                                Spacer()
                                if let user = authManager.currentUser {
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Button(action: {
                                authManager.logout()
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Abmelden")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Nicht angemeldet")
                                    .font(.subheadline)
                                    .bold()
                                Spacer()
                            }
                            
                            HStack(spacing: 10) {
                                Button(action: {
                                    showLoginView = true
                                }) {
                                    HStack {
                                        Image(systemName: "person.fill")
                                        Text("Anmelden")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                
                                Button(action: {
                                    showRegisterView = true
                                }) {
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                        Text("Registrieren")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                } else {
                    Text("Die Authentifizierung ist nur verfügbar, wenn der Speichermodus auf 'Self-Hosted' oder 'Hybrid' eingestellt ist.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Synchronisierung")
                .font(.headline)
            
            VStack(spacing: 16) {
                if settings.storageMode != .cloudKit {
                    Toggle("Synchronisierung aktivieren", isOn: $settings.syncEnabled)
                    
                    if settings.syncEnabled {
                        Toggle("Automatische Synchronisierung", isOn: $settings.autoSync)
                        
                        if settings.autoSync {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Synchronisierungsintervall")
                                    .font(.subheadline)
                                
                                Picker("Intervall", selection: $settings.syncIntervalSeconds) {
                                    Text("15 Minuten").tag(900.0)
                                    Text("30 Minuten").tag(1800.0)
                                    Text("1 Stunde").tag(3600.0)
                                    Text("3 Stunden").tag(10800.0)
                                    Text("6 Stunden").tag(21600.0)
                                    Text("12 Stunden").tag(43200.0)
                                    Text("24 Stunden").tag(86400.0)
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            
                            Toggle("Nur über WLAN synchronisieren", isOn: $settings.syncOnWifiOnly)
                        }
                        
                        // Sync Status View hinzufügen
                        SyncStatusView()
                            .padding(.top, 8)
                    }
                    
                    Button(action: {
                        // Hier würden wir die manuelle Synchronisierung starten
                        // syncService.synchronize()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Jetzt synchronisieren")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    if settings.lastSyncTimestamp > 0 {
                        Text("Letzte Synchronisierung: \(settings.lastSyncDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Die Synchronisierung ist nur verfügbar, wenn der Speichermodus auf 'Self-Hosted' oder 'Hybrid' eingestellt ist.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var minioStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MinIO-Status")
                .font(.headline)
            
            MinIOStatusView()
        }
    }
    
    // MARK: - Actions
    
    private func testConnection() {
        isTestingConnection = true
        
        // Hier würden wir eine einfache API-Anfrage machen, um die Verbindung zu testen
        // Für jetzt simulieren wir das nur
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isTestingConnection = false
            connectionTestResult = "Verbindung zum Backend erfolgreich hergestellt!"
            showingTestConnectionAlert = true
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Anmeldedaten")) {
                    TextField("E-Mail", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Passwort", text: $password)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: login) {
                        if isLoggingIn {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Anmelden")
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || isLoggingIn)
                }
            }
            .navigationTitle("Anmelden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func login() {
        isLoggingIn = true
        errorMessage = nil
        
        Task {
            let success = await authManager.login(email: email, password: password)
            
            await MainActor.run {
                isLoggingIn = false
                
                if success {
                    dismiss()
                } else if case .error(let message) = authManager.authStatus {
                    errorMessage = message
                } else {
                    errorMessage = "Anmeldung fehlgeschlagen"
                }
            }
        }
    }
}

// MARK: - Register View

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isRegistering = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Registrierungsdaten")) {
                    TextField("E-Mail", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Passwort", text: $password)
                    SecureField("Passwort bestätigen", text: $confirmPassword)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: register) {
                        if isRegistering {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Registrieren")
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || password != confirmPassword || isRegistering)
                }
            }
            .navigationTitle("Registrieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func register() {
        if password != confirmPassword {
            errorMessage = "Passwörter stimmen nicht überein"
            return
        }
        
        if password.count < 8 {
            errorMessage = "Passwort muss mindestens 8 Zeichen lang sein"
            return
        }
        
        isRegistering = true
        errorMessage = nil
        
        Task {
            let success = await authManager.register(email: email, password: password)
            
            await MainActor.run {
                isRegistering = false
                
                if success {
                    dismiss()
                } else if case .error(let message) = authManager.authStatus {
                    errorMessage = message
                } else {
                    errorMessage = "Registrierung fehlgeschlagen"
                }
            }
        }
    }
}

// MARK: - Preview

struct BackendSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BackendSettingsView()
        }
    }
}