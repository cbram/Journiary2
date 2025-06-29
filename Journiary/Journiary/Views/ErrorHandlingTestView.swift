//
//  ErrorHandlingTestView.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import SwiftUI
import Combine

/// Test View für Error Handling Szenarien
struct ErrorHandlingTestView: View {
    @StateObject private var errorHandler = ErrorHandler.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var apolloClient = ApolloClientManager.shared
    @State private var isTestingBackendConnection = false
    @State private var testResults: [String] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerView
                    
                    // Network Status
                    networkStatusView
                    
                    // Backend Connection Status
                    backendConnectionView
                    
                    // Error Test Buttons
                    errorTestsView
                    
                    // Test Results
                    testResultsView
                }
                .padding()
            }
            .navigationTitle("Error Handling Tests")
            .navigationBarTitleDisplayMode(.inline)
            .handleErrors()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "testtube.2")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Error Handling Tests")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Testen Sie verschiedene Fehlerszenarien und deren Behandlung")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Network Status
    
    private var networkStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Netzwerkstatus")
                .font(.headline)
            
            HStack(spacing: 12) {
                Image(systemName: networkMonitor.connectionType.iconName)
                    .foregroundColor(networkMonitor.isConnected ? .green : .red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(networkMonitor.connectionStatusText)
                        .font(.subheadline)
                    
                    if networkMonitor.isExpensive {
                        Text("⚠️ Kostenpflichtige Verbindung")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if networkMonitor.isConstrained {
                        Text("🐌 Begrenzte Bandbreite")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Circle()
                    .fill(networkMonitor.isConnected ? .green : .red)
                    .frame(width: 16, height: 16)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Backend Connection Status
    
    private var backendConnectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Backend-Verbindung")
                    .font(.headline)
                
                Spacer()
                
                Button("Testen") {
                    testBackendConnection()
                }
                .disabled(isTestingBackendConnection)
            }
            
            HStack(spacing: 12) {
                Image(systemName: apolloClient.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(apolloClient.isConnected ? .green : .red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(apolloClient.isConnected ? "Verbunden" : "Nicht verbunden")
                        .font(.subheadline)
                    
                    if let lastError = apolloClient.lastError {
                        Text(lastError.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                if isTestingBackendConnection {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Error Tests
    
    private var errorTestsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fehlerszenarien testen")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                // Backend Offline Error
                ErrorTestButton(
                    title: "Backend Offline",
                    icon: "server.rack",
                    color: .red,
                    description: "Simuliert einen nicht erreichbaren Server"
                ) {
                    testBackendOfflineError()
                }
                
                // Network Error
                ErrorTestButton(
                    title: "Netzwerk-Fehler",
                    icon: "wifi.exclamationmark",
                    color: .orange,
                    description: "Simuliert Netzwerkprobleme"
                ) {
                    testNetworkError()
                }
                
                // Invalid Query Error
                ErrorTestButton(
                    title: "Invalid Query",
                    icon: "doc.text",
                    color: .purple,
                    description: "Simuliert ungültige GraphQL Query"
                ) {
                    testInvalidQueryError()
                }
                
                // Timeout Error
                ErrorTestButton(
                    title: "Timeout",
                    icon: "clock.badge.exclamationmark",
                    color: .yellow,
                    description: "Simuliert Zeitüberschreitung"
                ) {
                    testTimeoutError()
                }
                
                // Authentication Error
                ErrorTestButton(
                    title: "Auth Fehler",
                    icon: "person.badge.key",
                    color: .red,
                    description: "Simuliert Authentifizierungsfehler"
                ) {
                    testAuthenticationError()
                }
                
                // Parse Error
                ErrorTestButton(
                    title: "Parse Fehler",
                    icon: "exclamationmark.triangle",
                    color: .blue,
                    description: "Simuliert Parsing-Probleme"
                ) {
                    testParseError()
                }
            }
        }
    }
    
    // MARK: - Test Results
    
    private var testResultsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Test-Ergebnisse")
                    .font(.headline)
                
                Spacer()
                
                if !testResults.isEmpty {
                    Button("Löschen") {
                        testResults.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if testResults.isEmpty {
                Text("Noch keine Tests durchgeführt")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                    Text("\(index + 1). \(result)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Test Functions
    
    private func testBackendConnection() {
        isTestingBackendConnection = true
        addTestResult("Backend-Verbindung wird getestet...")
        
        apolloClient.checkConnection()
        
        // Nach 3 Sekunden Result prüfen
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            isTestingBackendConnection = false
            let result = apolloClient.isConnected ? "✅ Backend erreichbar" : "❌ Backend nicht erreichbar"
            addTestResult(result)
        }
    }
    
    private func testBackendOfflineError() {
        addTestResult("Backend Offline Error wird getestet...")
        
        let error = GraphQLError.networkError("Connection refused: Der Server ist nicht erreichbar")
        errorHandler.handle(error) {
            addTestResult("🔄 Retry für Backend Offline durchgeführt")
        }
    }
    
    private func testNetworkError() {
        addTestResult("Netzwerk-Fehler wird getestet...")
        
        let error = URLError(.notConnectedToInternet)
        errorHandler.handle(error) {
            addTestResult("🔄 Retry für Netzwerk-Fehler durchgeführt")
        }
    }
    
    private func testInvalidQueryError() {
        addTestResult("Invalid Query Error wird getestet...")
        
        let error = GraphQLError.serverError("Field 'invalidField' is not defined in the schema")
        errorHandler.handle(error) {
            addTestResult("🔄 Retry für Invalid Query durchgeführt")
        }
    }
    
    private func testTimeoutError() {
        addTestResult("Timeout Error wird getestet...")
        
        let error = URLError(.timedOut)
        errorHandler.handle(error) {
            addTestResult("🔄 Retry für Timeout durchgeführt")
        }
    }
    
    private func testAuthenticationError() {
        addTestResult("Authentication Error wird getestet...")
        
        let error = GraphQLError.authenticationRequired
        errorHandler.handle(error) {
            addTestResult("🔄 Retry für Authentication durchgeführt (nicht möglich)")
        }
    }
    
    private func testParseError() {
        addTestResult("Parse Error wird getestet...")
        
        let error = GraphQLError.parseError("JSON parsing failed: Unexpected token")
        errorHandler.handle(error) {
            addTestResult("🔄 Retry für Parse Error durchgeführt")
        }
    }
    
    private func addTestResult(_ result: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        testResults.append("[\(timestamp)] \(result)")
    }
}

// MARK: - Error Test Button

struct ErrorTestButton: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

struct ErrorHandlingTestView_Previews: PreviewProvider {
    static var previews: some View {
        ErrorHandlingTestView()
    }
} 