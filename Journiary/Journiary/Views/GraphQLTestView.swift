//
//  GraphQLTestView.swift
//  Journiary
//
//  Created by Christian Bram on 28.06.25.
//

import SwiftUI
import Combine

struct GraphQLTestView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var apolloClient = ApolloClientManager.shared
    @StateObject private var userService = GraphQLUserService()
    
    @State private var isLoading = false
    @State private var testResults: [TestResult] = []
    @State private var showingResults = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("GraphQL Connectivity Test")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.top)
                
                // Backend Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Backend Konfiguration")
                        .font(.headline)
                    
                    HStack {
                        Text("URL:")
                            .fontWeight(.medium)
                        Text(appSettings.backendURL)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Storage Mode:")
                            .fontWeight(.medium)
                        Text(appSettings.storageMode.rawValue)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Test Buttons
                VStack(spacing: 12) {
                    TestButton(
                        title: "1. Backend Erreichbarkeit",
                        subtitle: "Teste HTTP-Verbindung",
                        icon: "wifi",
                        color: .blue
                    ) {
                        performConnectivityTest()
                    }
                    
                    TestButton(
                        title: "2. Hello World Query",
                        subtitle: "GraphQL Schema laden",
                        icon: "bubble.left.and.bubble.right",
                        color: .green
                    ) {
                        performHelloWorldTest()
                    }
                    
                    TestButton(
                        title: "3. Authentication Test",
                        subtitle: "Login/Token-Validierung",
                        icon: "person.badge.key",
                        color: .orange
                    ) {
                        performAuthTest()
                    }
                    
                    TestButton(
                        title: "4. Full Integration Test",
                        subtitle: "Alle Tests durchführen",
                        icon: "checkmark.seal",
                        color: .purple
                    ) {
                        performFullTest()
                    }
                }
                
                Spacer()
                
                // Results
                if !testResults.isEmpty {
                    Button("Testergebnisse anzeigen") {
                        showingResults = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if isLoading {
                    ProgressView("Tests laufen...")
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            .padding()
            .navigationTitle("GraphQL Tests")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingResults) {
                TestResultsView(results: testResults)
            }
        }
    }
    
    // MARK: - Test Methods
    
    private func performConnectivityTest() {
        isLoading = true
        
        let startTime = Date()
        
        // HTTP Connectivity Test
        guard let url = URL(string: "\(appSettings.backendURL)/graphql") else {
            addTestResult(.init(
                name: "Backend Erreichbarkeit",
                success: false,
                message: "Ungültige URL: \(appSettings.backendURL)",
                duration: 0
            ))
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        // Einfache HTTP-Test ohne GraphQL
        let pingData = """
        {"query": "{ __typename }"}
        """.data(using: .utf8)
        request.httpBody = pingData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                let duration = Date().timeIntervalSince(startTime)
                
                if let error = error {
                    addTestResult(.init(
                        name: "Backend Erreichbarkeit",
                        success: false,
                        message: "Verbindungsfehler: \(error.localizedDescription)",
                        duration: duration
                    ))
                } else if let httpResponse = response as? HTTPURLResponse {
                    let success = httpResponse.statusCode == 200
                    addTestResult(.init(
                        name: "Backend Erreichbarkeit",
                        success: success,
                        message: success ? "HTTP 200 OK" : "HTTP \(httpResponse.statusCode)",
                        duration: duration
                    ))
                } else {
                    addTestResult(.init(
                        name: "Backend Erreichbarkeit",
                        success: false,
                        message: "Keine gültige HTTP-Antwort",
                        duration: duration
                    ))
                }
                
                isLoading = false
            }
        }.resume()
    }
    
    private func performHelloWorldTest() {
        isLoading = true
        
        let startTime = Date()
        
        userService.hello()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    let duration = Date().timeIntervalSince(startTime)
                    
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        addTestResult(.init(
                            name: "Hello World Query",
                            success: false,
                            message: "Fehler: \(error.localizedDescription)",
                            duration: duration
                        ))
                    }
                    isLoading = false
                },
                receiveValue: { message in
                    let duration = Date().timeIntervalSince(startTime)
                    addTestResult(.init(
                        name: "Hello World Query",
                        success: true,
                        message: "Antwort: \(message)",
                        duration: duration
                    ))
                }
            )
            .store(in: &cancellables)
    }
    
    private func performAuthTest() {
        isLoading = true
        
        let startTime = Date()
        
        // Prüfe ob User bereits eingeloggt ist
        if let currentUser = authManager.currentUser,
           let email = currentUser.email,
           let _ = authManager.getCurrentAuthToken() {
            // User ist bereits eingeloggt - teste Token-Validierung
            DispatchQueue.main.async {
                let duration = Date().timeIntervalSince(startTime)
                self.addTestResult(.init(
                    name: "Authentication Test",
                    success: true,
                    message: "✅ Bereits eingeloggt als \(email) (Token gültig)",
                    duration: duration
                ))
                self.isLoading = false
            }
            return
        }
        
        // Falls nicht eingeloggt, verwende Demo-Account für Test
        userService.login(username: "demo@example.com", password: "demo12345")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    let duration = Date().timeIntervalSince(startTime)
                    
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        addTestResult(.init(
                            name: "Authentication Test",
                            success: false,
                            message: "Demo-Login fehlgeschlagen: \(error.localizedDescription)",
                            duration: duration
                        ))
                    }
                    isLoading = false
                },
                receiveValue: { userDTO in
                    let duration = Date().timeIntervalSince(startTime)
                    addTestResult(.init(
                        name: "Authentication Test",
                        success: true,
                        message: "Demo-Login erfolgreich: \(userDTO.username) (Registrieren Sie sich für eigenen Account)",
                        duration: duration
                    ))
                }
            )
            .store(in: &cancellables)
    }
    
    private func performFullTest() {
        testResults.removeAll()
        
        // Tests sequentiell ausführen
        performConnectivityTest()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            performHelloWorldTest()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            performAuthTest()
        }
    }
    
    private func addTestResult(_ result: TestResult) {
        testResults.append(result)
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}

// MARK: - Supporting Views

struct TestButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "play.circle")
                    .foregroundColor(color)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Test Result Model

struct TestResult: Identifiable {
    let id = UUID()
    let name: String
    let success: Bool
    let message: String
    let duration: TimeInterval
    let timestamp = Date()
}

// MARK: - Test Results View

struct TestResultsView: View {
    let results: [TestResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(results) { result in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.success ? .green : .red)
                        
                        Text(result.name)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(String(format: "%.2fs", result.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(result.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text(DateFormatter.localizedString(from: result.timestamp, dateStyle: .none, timeStyle: .medium))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Testergebnisse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct GraphQLTestView_Previews: PreviewProvider {
    static var previews: some View {
        GraphQLTestView()
            .environmentObject(AppSettings.shared)
    }
} 