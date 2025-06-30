//
//  UserProfileView.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingLogoutAlert = false
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    profileHeaderView
                    
                    // User Information
                    userInfoSection
                    
                    // Account Actions
                    accountActionsSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Abmelden", isPresented: $showingLogoutAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Abmelden", role: .destructive) {
                authManager.logout()
                dismiss()
            }
        } message: {
            Text("Möchten Sie sich wirklich abmelden? Ihre lokalen Daten bleiben erhalten.")
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeaderView: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                
                Text(authManager.currentUser?.initials ?? "?")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 4)
            
            // Name and Username
            VStack(spacing: 4) {
                Text(authManager.currentUser?.displayName ?? "Unbekannter Benutzer")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let username = authManager.currentUser?.username {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - User Info Section
    
    private var userInfoSection: some View {
        VStack(spacing: 16) {
            // Section Header
            HStack {
                Text("Kontoinformationen")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                Button("Bearbeiten") {
                    showingEditProfile = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                // Email
                InfoRow(
                    icon: "envelope.fill",
                    title: "E-Mail",
                    value: authManager.currentUser?.email ?? "Nicht verfügbar",
                    iconColor: .blue
                )
                
                // Full Name
                if let firstName = authManager.currentUser?.firstName,
                   let lastName = authManager.currentUser?.lastName,
                   !firstName.isEmpty, !lastName.isEmpty {
                    InfoRow(
                        icon: "person.fill",
                        title: "Name",
                        value: "\(firstName) \(lastName)",
                        iconColor: .green
                    )
                }
                
                // Account Creation
                if let createdAt = authManager.currentUser?.createdAt {
                    InfoRow(
                        icon: "calendar",
                        title: "Mitglied seit",
                        value: DateFormatter.germanMedium.string(from: createdAt),
                        iconColor: .orange
                    )
                }
                
                // Backend Connection
                InfoRow(
                    icon: "server.rack",
                    title: "Server",
                    value: appSettings.backendURL,
                    iconColor: .purple
                )
            }
            .padding(.vertical, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Account Actions
    
    private var accountActionsSection: some View {
        VStack(spacing: 12) {
            // Section Header
            HStack {
                Text("Kontoeinstellungen")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 8) {
                // Edit Profile Button
                ActionButton(
                    icon: "person.crop.circle",
                    title: "Profil bearbeiten",
                    subtitle: "Name und E-Mail ändern",
                    color: .blue
                ) {
                    showingEditProfile = true
                }
                
                // Backend Settings Button
                ActionButton(
                    icon: "gear",
                    title: "Backend-Einstellungen",
                    subtitle: "Server-Konfiguration",
                    color: .gray
                ) {
                    // Zu Backend-Einstellungen navigieren
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Logout Button
                ActionButton(
                    icon: "arrow.right.square",
                    title: "Abmelden",
                    subtitle: "Lokale Daten bleiben erhalten",
                    color: .red
                ) {
                    showingLogoutAlert = true
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Persönliche Informationen") {
                    TextField("Vorname", text: $firstName)
                        .textContentType(.givenName)
                    
                    TextField("Nachname", text: $lastName)
                        .textContentType(.familyName)
                }
                
                Section("Kontakt") {
                    TextField("E-Mail", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Profil bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        saveProfile()
                    }
                    .disabled(isLoading)
                }
            }
        }
        .onAppear {
            loadCurrentData()
        }
        .alert("Profil aktualisiert", isPresented: $showingAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadCurrentData() {
        firstName = authManager.currentUser?.firstName ?? ""
        lastName = authManager.currentUser?.lastName ?? ""
        email = authManager.currentUser?.email ?? ""
    }
    
    private func saveProfile() {
        isLoading = true
        
        // Hier würde normalerweise der UserService aufgerufen
        // Für jetzt aktualisieren wir nur lokal
        let context = EnhancedPersistenceController.shared.container.viewContext
        
        if let user = authManager.currentUser {
            user.firstName = firstName.isEmpty ? nil : firstName
            user.lastName = lastName.isEmpty ? nil : lastName
            user.email = email
            user.updatedAt = Date()
            
            do {
                try context.save()
                alertMessage = "Profil erfolgreich aktualisiert"
                showingAlert = true
            } catch {
                alertMessage = "Fehler beim Speichern: \(error.localizedDescription)"
                showingAlert = true
            }
        }
        
        isLoading = false
    }
}

// MARK: - Preview

struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileView()
            .environmentObject(AuthManager.shared)
            .environmentObject(AppSettings.shared)
    }
} 