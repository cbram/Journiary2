//
//  ServerConfigurationView.swift
//  Journiary
//
//  Created by Christian Bram on 29.12.24.
//

import SwiftUI

struct ServerConfigurationView: View {
    @StateObject private var appSettings = AppSettings.shared
    @State private var tempBackendURL: String = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange.gradient)
                    
                    VStack(spacing: 8) {
                        Text("Server-URL konfigurieren")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Geben Sie die URL Ihres Backend-Servers ein")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)
                
                // Current URL Display
                if !appSettings.backendURL.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aktuelle Server-URL:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(appSettings.backendURL)
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                // URL Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server-URL")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("http://192.168.1.100:4000", text: $tempBackendURL)
                        .textFieldStyle(CustomTextFieldStyle())
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                // Help Text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hilfe:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Geben Sie die IP-Adresse Ihres Docker-Servers ein")
                        Text("• Standard-Port ist 4000")
                        Text("• Beispiel: http://192.168.1.100:4000")
                        Text("• Verwenden Sie NICHT localhost oder 127.0.0.1")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    // Save Button
                    Button(action: saveServerURL) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                            }
                            
                            Text(isLoading ? "Speichere..." : "Server-URL speichern")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: canSave ? [.orange, .orange.opacity(0.8)] : [.gray.opacity(0.3), .gray.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(canSave ? .white : .gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canSave || isLoading)
                    
                    // Cancel Button
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            tempBackendURL = appSettings.backendURL
        }
        .alert("Server-Konfiguration", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSave: Bool {
        !tempBackendURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        tempBackendURL != appSettings.backendURL
    }
    
    // MARK: - Actions
    
    private func saveServerURL() {
        let trimmedURL = tempBackendURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedURL.isEmpty else {
            alertMessage = "Bitte geben Sie eine gültige Server-URL ein."
            showingAlert = true
            return
        }
        
        // Basic URL validation
        guard trimmedURL.hasPrefix("http://") || trimmedURL.hasPrefix("https://") else {
            alertMessage = "Die URL muss mit http:// oder https:// beginnen."
            showingAlert = true
            return
        }
        
        isLoading = true
        
        // Simulate brief loading for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Save the URL
            appSettings.backendURL = trimmedURL
            
            // Clear any old authentication data since we're changing servers
            AuthManager.shared.logout()
            
            isLoading = false
            alertMessage = "Server-URL erfolgreich gespeichert!\n\nSie können sich jetzt anmelden."
            showingAlert = true
            
            // Auto-dismiss after showing success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }
}

// MARK: - Preview

struct ServerConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ServerConfigurationView()
            .preferredColorScheme(.light)
        
        ServerConfigurationView()
            .preferredColorScheme(.dark)
    }
} 