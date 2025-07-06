import SwiftUI
import JourniaryAPI

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
    
    @State private var email = ""
    @State private var password = ""
    // Lade die aktuell aktive URL (aus UserDefaults oder Config) als Standardwert.
    @State private var serverURL = NetworkProvider.getBackendURL()

    // Diese Zustände werden später von einem AuthService gesteuert.
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Text("Willkommen bei Journiary")
                    .font(.largeTitle)
                    .fontWeight(.bold)
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
                        .textContentType(.password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Backend URL")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("http://dein-server.de/graphql", text: $serverURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }

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
                    Button(action: login) {
                        Text("Anmelden")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }

                NavigationLink("Noch keinen Account? Registrieren", destination: RegistrationView())
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }

    private func login() {
        // 1. URL im UserDefaults speichern, damit sie persistent ist.
        UserDefaults.standard.set(self.serverURL, forKey: "backendURL")
        print("Backend URL gespeichert: \(self.serverURL)")

        // 2. Login-Logik
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Der NetworkProvider muss neu initialisiert werden, falls sich die URL geändert hat.
                // Dieser Ansatz ist nicht ideal, aber für den Moment funktional.
                // Eine bessere Lösung wäre ein dedizierter URL-Manager.
                NetworkProvider.shared.resetClient()

                let userInput = JourniaryAPI.UserInput(email: email, password: password)
                try await authService.login(user: userInput)
            } catch {
                errorMessage = "Login fehlgeschlagen: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
} 