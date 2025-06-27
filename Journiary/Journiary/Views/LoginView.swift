//
//  LoginView.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var settings = AppSettings.shared
    
    @State private var username = ""
    @State private var password = ""
    @State private var showingRegistration = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isLoggingIn = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Hintergrund
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Logo und Titel
                    VStack(spacing: 10) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Journiary")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Melde dich an, um deine Reisen zu synchronisieren")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Anmeldeformular
                    VStack(spacing: 15) {
                        TextField("Benutzername", text: $username)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        SecureField("Passwort", text: $password)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                        
                        // Anmelde-Button
                        Button(action: {
                            login()
                        }) {
                            if isLoggingIn {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            } else {
                                Text("Anmelden")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .disabled(username.isEmpty || password.isEmpty || isLoggingIn)
                        
                        // Registrieren-Button
                        Button(action: {
                            showingRegistration = true
                        }) {
                            Text("Noch kein Konto? Registrieren")
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Server-Info
                    if let serverURL = settings.backendURL {
                        Text("Server: \(serverURL)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Anmelden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showingRegistration) {
                RegisterView()
            }
        }
    }
    
    private func login() {
        guard !username.isEmpty, !password.isEmpty else {
            showAlert(title: "Fehler", message: "Bitte gib Benutzername und Passwort ein.")
            return
        }
        
        isLoggingIn = true
        
        Task {
            do {
                try await authManager.login(username: username, password: password)
                
                DispatchQueue.main.async {
                    isLoggingIn = false
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    isLoggingIn = false
                    showAlert(title: "Anmeldung fehlgeschlagen", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
} 