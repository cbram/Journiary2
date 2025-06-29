import SwiftUI
import Combine

struct AdminPanelView: View {
    @StateObject private var apolloClient = ApolloClientManager.shared
    @State private var isLoading = false
    @State private var users: [AdminUserInfo] = []
    @State private var message = ""
    @State private var showAlert = false
    @State private var cancellables = Set<AnyCancellable>()
    
    // Reset Password Fields
    @State private var resetEmail = ""
    @State private var resetPassword = ""
    
    // Ensure Admin User Fields
    @State private var adminEmail = "chbram@mailbox.org"
    @State private var adminPassword = "C0mp1Fu-.y"
    
    var body: some View {
        NavigationView {
            Form {
                Section("User Management") {
                    Button("List All Users") {
                        listUsers()
                    }
                    .disabled(isLoading)
                    
                    if !users.isEmpty {
                        ForEach(users, id: \.id) { user in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.email)
                                    .font(.headline)
                                Text("ID: \(user.id)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Hash: \(user.passwordHash)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Created: \(user.createdAt)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                Section("Reset Password") {
                    TextField("Email", text: $resetEmail)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("New Password", text: $resetPassword)
                    
                    Button("Reset Password") {
                        resetUserPassword()
                    }
                    .disabled(isLoading || resetEmail.isEmpty || resetPassword.isEmpty)
                }
                
                Section("Fix Current User") {
                    TextField("Admin Email", text: $adminEmail)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Admin Password", text: $adminPassword)
                    
                    Button("Fix/Create Admin User") {
                        ensureAdminUser()
                    }
                    .disabled(isLoading || adminEmail.isEmpty || adminPassword.isEmpty)
                    .foregroundColor(.blue)
                }
                
                Section("Status") {
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading...")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !message.isEmpty {
                        Text(message)
                            .foregroundColor(message.contains("Error") ? .red : .green)
                    }
                }
            }
            .navigationTitle("Admin Panel")
            .alert("Admin Panel", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(message)
            }
        }
    }
    
    private func listUsers() {
        isLoading = true
        message = ""
        
        let query = """
        query ListUsers {
            listUsers {
                success
                message
                users {
                    id
                    email
                    passwordHash
                    createdAt
                }
            }
        }
        """
        
        performGraphQLRequest(query: query, variables: [:])
            .sink(
                receiveCompletion: { completion in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if case .failure(let error) = completion {
                            self.message = "Error: \(error.localizedDescription)"
                            self.showAlert = true
                        }
                    }
                },
                receiveValue: { data in
                    DispatchQueue.main.async {
                        self.parseListUsersResponse(data)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func resetUserPassword() {
        isLoading = true
        message = ""
        
        let mutation = """
        mutation ResetUserPassword($email: String!, $newPassword: String!) {
            resetUserPassword(email: $email, newPassword: $newPassword) {
                success
                message
                users {
                    id
                    email
                    passwordHash
                    createdAt
                }
            }
        }
        """
        
        let variables: [String: Any] = [
            "email": resetEmail,
            "newPassword": resetPassword
        ]
        
        performGraphQLRequest(query: mutation, variables: variables)
            .sink(
                receiveCompletion: { completion in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if case .failure(let error) = completion {
                            self.message = "Error: \(error.localizedDescription)"
                            self.showAlert = true
                        }
                    }
                },
                receiveValue: { data in
                    DispatchQueue.main.async {
                        self.parseAdminResponse(data, operation: "resetUserPassword")
                        // Clear fields on success
                        if self.message.contains("successful") {
                            self.resetEmail = ""
                            self.resetPassword = ""
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func ensureAdminUser() {
        isLoading = true
        message = ""
        
        let mutation = """
        mutation EnsureAdminUser($email: String!, $password: String!) {
            ensureAdminUser(email: $email, password: $password) {
                success
                message
                users {
                    id
                    email
                    passwordHash
                    createdAt
                }
            }
        }
        """
        
        let variables: [String: Any] = [
            "email": adminEmail,
            "password": adminPassword
        ]
        
        performGraphQLRequest(query: mutation, variables: variables)
            .sink(
                receiveCompletion: { completion in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if case .failure(let error) = completion {
                            self.message = "Error: \(error.localizedDescription)"
                            self.showAlert = true
                        }
                    }
                },
                receiveValue: { data in
                    DispatchQueue.main.async {
                        self.parseAdminResponse(data, operation: "ensureAdminUser")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func parseListUsersResponse(_ data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let errors = json?["errors"] as? [[String: Any]] {
                let errorMessages = errors.compactMap { $0["message"] as? String }
                message = "GraphQL Error: \(errorMessages.joined(separator: ", "))"
                showAlert = true
                return
            }
            
            guard let responseData = json?["data"] as? [String: Any],
                  let listUsersData = responseData["listUsers"] as? [String: Any] else {
                message = "Invalid response structure"
                showAlert = true
                return
            }
            
            parseAdminResponseData(listUsersData)
            
        } catch {
            message = "JSON parsing error: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func parseAdminResponse(_ data: Data, operation: String) {
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let errors = json?["errors"] as? [[String: Any]] {
                let errorMessages = errors.compactMap { $0["message"] as? String }
                message = "GraphQL Error: \(errorMessages.joined(separator: ", "))"
                showAlert = true
                return
            }
            
            guard let responseData = json?["data"] as? [String: Any],
                  let operationData = responseData[operation] as? [String: Any] else {
                message = "Invalid response structure"
                showAlert = true
                return
            }
            
            parseAdminResponseData(operationData)
            
        } catch {
            message = "JSON parsing error: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func parseAdminResponseData(_ data: [String: Any]) {
        let success = data["success"] as? Bool ?? false
        let responseMessage = data["message"] as? String ?? ""
        
        message = responseMessage
        
        if let usersData = data["users"] as? [[String: Any]] {
            users = usersData.compactMap { userData in
                guard let id = userData["id"] as? String,
                      let email = userData["email"] as? String,
                      let passwordHash = userData["passwordHash"] as? String,
                      let createdAtString = userData["createdAt"] as? String else {
                    return nil
                }
                
                return AdminUserInfo(
                    id: id,
                    email: email,
                    passwordHash: passwordHash,
                    createdAt: createdAtString
                )
            }
        }
        
        if success {
            showAlert = true
        }
    }
    
    // MARK: - GraphQL Network Layer
    
    private func performGraphQLRequest(query: String, variables: [String: Any]) -> AnyPublisher<Data, Error> {
        let baseURL = AppSettings.shared.backendURL
        guard !baseURL.isEmpty,
              let url = URL(string: baseURL.hasSuffix("/graphql") ? baseURL : "\(baseURL)/graphql") else {
            return Fail(error: AdminError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return Fail(error: AdminError.encodingError)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        
        // Add auth header if available
        if let token = AuthManager.shared.getCurrentAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
}

enum AdminError: LocalizedError {
    case invalidURL
    case encodingError
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodingError:
            return "Encoding error"
        case .invalidResponse:
            return "Invalid response"
        }
    }
}

struct AdminUserInfo {
    let id: String
    let email: String
    let passwordHash: String
    let createdAt: String
}

#Preview {
    AdminPanelView()
} 