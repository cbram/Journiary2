import SwiftUI

struct RegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Account erstellen")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
                .padding(.bottom, 40)

            VStack(spacing: 15) {
                TextField("E-Mail", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                SecureField("Passwort", text: $password)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                SecureField("Passwort bestätigen", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            if isLoading {
                ProgressView()
                    .padding()
            } else {
                Button(action: register) {
                    Text("Registrieren")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Registrierung")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func register() {
        guard password == confirmPassword else {
            errorMessage = "Die Passwörter stimmen nicht überein."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let userInput = JourniaryAPI.UserInput(email: email, password: password)

        Task {
            do {
                try await authService.register(user: userInput)
                // Bei Erfolg wird der @StateObject in JourniaryApp den isAuthenticated-Status
                // aktualisieren und automatisch zur ContentView wechseln.
                // Ein manuelles dismiss ist nicht mehr nötig.
            } catch {
                // Zeige eine benutzerfreundliche Fehlermeldung an.
                errorMessage = "Registrierung fehlgeschlagen: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RegistrationView()
        }
    }
} 