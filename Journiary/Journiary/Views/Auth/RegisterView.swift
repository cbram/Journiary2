//
//  RegisterView.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import SwiftUI

struct RegisterView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Form Fields
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    
    // MARK: - UI State
    @State private var showingAlert = false
    @State private var agreedToTerms = false
    @FocusState private var focusedField: Field?
    @State private var animateFields = false
    
    enum Field: Hashable {
        case email, username, password, confirmPassword, firstName, lastName
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Registration Form
                    registrationFormView
                    
                    // Terms & Conditions
                    termsSection
                    
                    // Register Button
                    registerButtonSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
            }
            .background(backgroundGradient)
            .navigationTitle("Registrierung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Registrierung fehlgeschlagen", isPresented: $showingAlert) {
            Button("OK") { 
                authManager.authenticationError = nil
            }
        } message: {
            Text(authManager.authenticationError?.localizedDescription ?? "Unbekannter Fehler")
        }
        .onReceive(authManager.$authenticationError) { error in
            // Verzögerung hinzufügen, um Alert-Konflikte zu vermeiden
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if error != nil && !showingAlert {
                    showingAlert = true
                }
            }
        }
        .onReceive(authManager.$isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateFields = true
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 20)
            
            Image(systemName: "person.crop.circle.fill.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
                .scaleEffect(animateFields ? 1.0 : 0.8)
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateFields)
            
            VStack(spacing: 4) {
                Text("Neues Konto erstellen")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Erstellen Sie Ihr Travel Companion Konto")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(y: animateFields ? 0 : 20)
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: animateFields)
            
            Spacer(minLength: 30)
        }
    }
    
    // MARK: - Registration Form
    
    private var registrationFormView: some View {
        VStack(spacing: 20) {
            // Personal Information Section
            personalInfoSection
            
            // Account Information Section
            accountInfoSection
        }
        .padding(.horizontal, 8)
    }
    
    private var personalInfoSection: some View {
        VStack(spacing: 16) {
            // Section Header
            HStack {
                Text("Persönliche Informationen")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(x: animateFields ? 0 : -50)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateFields)
            
            // First Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Vorname (optional)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                TextField("Ihr Vorname", text: $firstName)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.givenName)
                    .focused($focusedField, equals: .firstName)
                    .onSubmit { focusedField = .lastName }
            }
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(x: animateFields ? 0 : -50)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateFields)
            
            // Last Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Nachname (optional)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                TextField("Ihr Nachname", text: $lastName)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.familyName)
                    .focused($focusedField, equals: .lastName)
                    .onSubmit { focusedField = .email }
            }
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(x: animateFields ? 0 : -50)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animateFields)
        }
    }
    
    private var accountInfoSection: some View {
        VStack(spacing: 16) {
            // Section Header
            HStack {
                Text("Konto-Informationen")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(x: animateFields ? 0 : -50)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: animateFields)
            
            // Email
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("E-Mail")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("*")
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    if !email.isEmpty {
                        Image(systemName: isValidEmail ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isValidEmail ? .green : .red)
                            .font(.caption)
                    }
                }
                
                TextField("ihre.email@beispiel.com", text: $email)
                    .textFieldStyle(CustomTextFieldStyle(isValid: email.isEmpty || isValidEmail))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .focused($focusedField, equals: .email)
                    .onSubmit { focusedField = .username }
            }
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(x: animateFields ? 0 : -50)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7), value: animateFields)
            
            // Username
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Benutzername (optional)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if !username.isEmpty {
                        Image(systemName: isValidUsername ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isValidUsername ? .green : .red)
                            .font(.caption)
                    }
                }
                
                TextField("wird aus E-Mail generiert, falls leer", text: $username)
                    .textFieldStyle(CustomTextFieldStyle(isValid: username.isEmpty || isValidUsername))
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .focused($focusedField, equals: .username)
                    .onSubmit { focusedField = .password }
                
                if !username.isEmpty && !isValidUsername {
                    Text("Mindestens 3 Zeichen, nur Buchstaben und Zahlen")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(x: animateFields ? 0 : -50)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: animateFields)
            
            // Password
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Passwort")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("*")
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    if !password.isEmpty {
                        Image(systemName: isValidPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isValidPassword ? .green : .red)
                            .font(.caption)
                    }
                }
                
                SecureField("Mindestens 8 Zeichen", text: $password)
                    .textFieldStyle(CustomTextFieldStyle(isValid: password.isEmpty || isValidPassword))
                    .textContentType(nil)  // Deaktiviert iOS Autofill für bessere Eingabe
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .password)
                    .onSubmit { focusedField = .confirmPassword }
                
                if !password.isEmpty && !isValidPassword {
                    Text("Mindestens 8 Zeichen erforderlich")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(x: animateFields ? 0 : -50)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.9), value: animateFields)
            
            // Confirm Password
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Passwort bestätigen")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("*")
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    if !confirmPassword.isEmpty {
                        Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(passwordsMatch ? .green : .red)
                            .font(.caption)
                    }
                }
                
                SecureField("Passwort wiederholen", text: $confirmPassword)
                    .textFieldStyle(CustomTextFieldStyle(isValid: confirmPassword.isEmpty || passwordsMatch))
                    .textContentType(.newPassword)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .confirmPassword)
                    .onSubmit {
                        if isValidRegistrationData {
                            performRegistration()
                        }
                    }
                
                if !confirmPassword.isEmpty && !passwordsMatch {
                    Text("Passwörter stimmen nicht überein")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(x: animateFields ? 0 : -50)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0), value: animateFields)
        }
    }
    
    // MARK: - Terms Section
    
    private var termsSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: { agreedToTerms.toggle() }) {
                Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                    .foregroundColor(agreedToTerms ? .blue : .gray)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Ich stimme den **Nutzungsbedingungen** und der **Datenschutzerklärung** zu.")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Text("*Pflichtfeld")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Spacer()
        }
        .padding(.top, 24)
        .opacity(animateFields ? 1.0 : 0.0)
        .offset(x: animateFields ? 0 : -50)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.1), value: animateFields)
    }
    
    // MARK: - Register Button
    
    private var registerButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: performRegistration) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "person.crop.circle.fill.badge.plus")
                            .font(.title2)
                    }
                    
                    Text(authManager.isLoading ? "Registrierung läuft..." : "Konto erstellen")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: isValidRegistrationData ? [.blue, .blue.opacity(0.8)] : [.gray.opacity(0.3), .gray.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(isValidRegistrationData ? .white : .gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .scaleEffect(authManager.isLoading ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: authManager.isLoading)
            }
            .disabled(!isValidRegistrationData || authManager.isLoading)
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(y: animateFields ? 0 : 30)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.2), value: animateFields)
        }
        .padding(.top, 32)
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.95),
                Color.blue.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Computed Properties
    
    private var isValidEmail: Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private var isValidUsername: Bool {
        return username.isEmpty || (username.count >= 3 && username.allSatisfy { $0.isLetter || $0.isNumber })
    }
    
    private var isValidPassword: Bool {
        return password.count >= 8
    }
    
    private var passwordsMatch: Bool {
        return !password.isEmpty && password == confirmPassword
    }
    
    private var isValidRegistrationData: Bool {
        return isValidEmail && isValidPassword && passwordsMatch && agreedToTerms
    }
    
    // MARK: - Actions
    
    private func performRegistration() {
        // Keyboard verstecken
        focusedField = nil
        
        // Haptic Feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Registrierung durchführen
        let firstNameValue = firstName.isEmpty ? nil : firstName
        let lastNameValue = lastName.isEmpty ? nil : lastName
        
        // Username aus E-Mail generieren, falls leer
        let usernameValue = username.isEmpty ? email.components(separatedBy: "@").first ?? "user" : username
        
        authManager.register(
            email: email,
            username: usernameValue,
            password: password,
            firstName: firstNameValue,
            lastName: lastNameValue
        )
    }
}

// MARK: - Custom Text Field Style is now in Components/CustomTextFieldStyle.swift

// MARK: - Preview

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
            .preferredColorScheme(.light)
        
        RegisterView()
            .preferredColorScheme(.dark)
    }
} 