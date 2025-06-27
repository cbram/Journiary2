//
//  RegisterView.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import SwiftUI

struct RegisterView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var settings = AppSettings.shared
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isRegistering = false
    @State private var registrationSuccess = false
    
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
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Registrieren")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Erstelle ein Konto, um deine Reisen zu synchronisieren")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Registrierungsformular
                    VStack(spacing: 15) {
                        TextField("Benutzername", text: $username)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        TextField("E-Mail", text: $email)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.emailAddress)
                        
                        SecureField("Passwort", text: $password)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                        
                        SecureField("Passwort bestätigen", text: $confirmPassword)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                        
                        // Registrieren-Button
                        Button(action: {
                            register()
                        }) {
                            if isRegistering {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            } else {
                                Text("Registrieren")
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .disabled(username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty || isRegistering)
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
            .navigationTitle("Registrieren")
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
                    dismissButton: .default(Text("OK")) {
                        if registrationSuccess {
                            dismiss()
                        }
                    }
                )
            }
        }
    }
    
    private func register() {
        // Validierung
        guard !username.isEmpty else {
            showAlert(title: "Fehler", message: "Bitte gib einen Benutzernamen ein.")
            return
        }
        
        guard !email.isEmpty, email.contains("@") else {
            showAlert(title: "Fehler", message: "Bitte gib eine gültige E-Mail-Adresse ein.")
            return
        }
        
        guard !password.isEmpty, password.count >= 8 else {
            showAlert(title: "Fehler", message: "Das Passwort muss mindestens 8 Zeichen lang sein.")
            return
        }
        
        guard password == confirmPassword else {
            showAlert(title: "Fehler", message: "Die Passwörter stimmen nicht überein.")
            return
        }
        
        isRegistering = true
        
        Task {
            do {
                try await authManager.register(username: username, email: email, password: password)
                
                DispatchQueue.main.async {
                    isRegistering = false
                    registrationSuccess = true
                    showAlert(title: "Registrierung erfolgreich", message: "Dein Konto wurde erfolgreich erstellt. Du kannst dich jetzt anmelden.")
                }
            } catch {
                DispatchQueue.main.async {
                    isRegistering = false
                    showAlert(title: "Registrierung fehlgeschlagen", message: error.localizedDescription)
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

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
    }
} 