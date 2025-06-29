//
//  LoginView.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var errorHandler = ErrorHandler.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showingRegister = false
    @State private var rememberMe = false
    
    // Animation und Fokus
    @FocusState private var focusedField: Field?
    @State private var animateFields = false
    
    enum Field: Hashable {
        case email, password
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Login Form
                    loginFormView
                    
                    // Buttons
                    buttonSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
            }
            .background(backgroundGradient)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingRegister) {
            RegisterView()
        }
        .handleErrors()
        .onReceive(authManager.$authenticationError) { error in
            if let error = error {
                errorHandler.handle(error) {
                    // Retry login with same credentials
                    performLogin()
                }
                // Clear the auth manager error to avoid duplicate handling
                authManager.authenticationError = nil
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
            Spacer(minLength: 60)
            
            // App Icon/Logo
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
                .scaleEffect(animateFields ? 1.0 : 0.8)
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateFields)
            
            VStack(spacing: 8) {
                Text("Travel Companion")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Melden Sie sich an, um Ihre Reisen zu synchronisieren")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(y: animateFields ? 0 : 20)
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: animateFields)
            
            Spacer(minLength: 40)
        }
    }
    
    // MARK: - Login Form
    
    private var loginFormView: some View {
        VStack(spacing: 20) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("E-Mail")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("ihre.email@beispiel.com", text: $email)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .focused($focusedField, equals: .email)
                    .onSubmit {
                        focusedField = .password
                    }
            }
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(x: animateFields ? 0 : -50)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateFields)
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Passwort")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                SecureField("Ihr Passwort", text: $password)
                    .textFieldStyle(CustomTextFieldStyle())
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        if isValidInput {
                            performLogin()
                        }
                    }
            }
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(x: animateFields ? 0 : -50)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateFields)
            
            // Remember Me Toggle
            HStack {
                Toggle("Angemeldet bleiben", isOn: $rememberMe)
                    .font(.subheadline)
                
                Spacer()
            }
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(x: animateFields ? 0 : -50)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animateFields)
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Button Section
    
    private var buttonSection: some View {
        VStack(spacing: 16) {
            // Login Button
            Button(action: performLogin) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                    }
                    
                    Text(authManager.isLoading ? "Anmeldung läuft..." : "Anmelden")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: isValidInput ? [.blue, .blue.opacity(0.8)] : [.gray.opacity(0.3), .gray.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(isValidInput ? .white : .gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .scaleEffect(authManager.isLoading ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: authManager.isLoading)
            }
            .disabled(!isValidInput || authManager.isLoading)
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(y: animateFields ? 0 : 30)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: animateFields)
            
            // Register Link
            Button("Noch kein Konto? Jetzt registrieren") {
                showingRegister = true
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            .opacity(animateFields ? 1.0 : 0.0)
            .offset(y: animateFields ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7), value: animateFields)
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
    
    private var isValidInput: Bool {
        isValidEmail && !password.isEmpty && password.count >= 6
    }
    
    private var isValidEmail: Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Actions
    
    private func performLogin() {
        // Keyboard verstecken
        focusedField = nil
        
        // Haptic Feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Login durchführen
        authManager.login(email: email, password: password)
    }
}

// MARK: - Custom Text Field Style is now in Components/CustomTextFieldStyle.swift

// MARK: - Preview

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .preferredColorScheme(.light)
        
        LoginView()
            .preferredColorScheme(.dark)
    }
} 