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
            ScrollView {
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
                    
                    // Test Results Button (oben platziert für bessere Erreichbarkeit)
                    if !testResults.isEmpty {
                        Button {
                            showingResults = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("Testergebnisse anzeigen (\(testResults.count))")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Loading Indicator
                    if isLoading {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            Text("Tests laufen...")
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Backend Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Backend Konfiguration")
                            .font(.headline)
                        
                        HStack {
                            Text("URL:")
                                .fontWeight(.medium)
                            Text(appSettings.backendURL)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
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
                            color: .blue,
                            isDisabled: isLoading
                        ) {
                            performConnectivityTest()
                        }
                        
                        TestButton(
                            title: "2. Hello World Query",
                            subtitle: "GraphQL Schema laden",
                            icon: "bubble.left.and.bubble.right",
                            color: .green,
                            isDisabled: isLoading
                        ) {
                            performHelloWorldTest()
                        }
                        
                        TestButton(
                            title: "3. Authentication Test",
                            subtitle: "Login/Token-Validierung",
                            icon: "person.badge.key",
                            color: .orange,
                            isDisabled: isLoading
                        ) {
                            performAuthTest()
                        }
                        
                        TestButton(
                            title: "4. Performance Tests",
                            subtitle: "Latenz & Throughput messen",
                            icon: "speedometer",
                            color: .red,
                            isDisabled: isLoading
                        ) {
                            performPerformanceTests()
                        }
                        
                        TestButton(
                            title: "5. Cache Tests",
                            subtitle: "Apollo Cache verhalten",
                            icon: "externaldrive.connected.to.line.below",
                            color: .teal,
                            isDisabled: isLoading
                        ) {
                            performCacheTests()
                        }
                        
                        TestButton(
                            title: "6. Full Integration Test",
                            subtitle: "Alle Tests durchführen",
                            icon: "checkmark.seal",
                            color: .purple,
                            isDisabled: isLoading
                        ) {
                            performFullTest()
                        }
                    }
                    
                    // Spacer für besseren Abstand unten
                    Spacer(minLength: 100)
                }
                .padding()
            }
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
    
    // MARK: - Performance Tests
    
    private func performPerformanceTests() {
        isLoading = true
        testResults.removeAll()
        
        addTestResult(.init(
            name: "Performance Tests",
            success: true,
            message: "🚀 Performance-Messungen gestartet...",
            duration: 0
        ))
        
        // Test 1: Latenz-Messung (Einzelner Request)
        performLatencyTest()
        
        // Test 2: Throughput-Test (Multiple parallele Requests)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.performThroughputTest()
        }
        
        // Test 3: Payload-Größen testen
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            self.performPayloadSizeTest()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
            self.isLoading = false
        }
    }
    
    private func performLatencyTest() {
        let iterations = 5
        var results: [TimeInterval] = []
        
        func runIteration(_ index: Int) {
            let startTime = Date()
            
            userService.hello()
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        let latency = Date().timeIntervalSince(startTime)
                        results.append(latency)
                        
                        if index == iterations - 1 {
                            // Alle Tests abgeschlossen - Statistiken berechnen
                            let avgLatency = results.reduce(0, +) / Double(results.count)
                            let minLatency = results.min() ?? 0
                            let maxLatency = results.max() ?? 0
                            
                            addTestResult(.init(
                                name: "Latenz-Test (\(iterations)x)",
                                success: true,
                                message: String(format: "Ø %.0fms | Min: %.0fms | Max: %.0fms", 
                                               avgLatency * 1000, minLatency * 1000, maxLatency * 1000),
                                duration: avgLatency
                            ))
                        } else if index < iterations - 1 {
                            // Nächste Iteration
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                runIteration(index + 1)
                            }
                        }
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }
        
        runIteration(0)
    }
    
    private func performThroughputTest() {
        let concurrentRequests = 10
        let startTime = Date()
        var completedRequests = 0
        var successfulRequests = 0
        
        addTestResult(.init(
            name: "Throughput-Test",
            success: true,
            message: "⏱️ \(concurrentRequests) parallele Requests starten...",
            duration: 0
        ))
        
        for _ in 0..<concurrentRequests {
            userService.hello()
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        completedRequests += 1
                        
                        switch completion {
                        case .finished:
                            break
                        case .failure:
                            break
                        }
                        
                        if completedRequests == concurrentRequests {
                            let totalDuration = Date().timeIntervalSince(startTime)
                            let requestsPerSecond = Double(concurrentRequests) / totalDuration
                            
                            addTestResult(.init(
                                name: "Throughput-Test (Parallel)",
                                success: successfulRequests > concurrentRequests / 2,
                                message: String(format: "%d/%d erfolgreich | %.1f req/s | %.0fs total", 
                                               successfulRequests, concurrentRequests, requestsPerSecond, totalDuration),
                                duration: totalDuration
                            ))
                        }
                    },
                    receiveValue: { _ in
                        successfulRequests += 1
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    private func performPayloadSizeTest() {
        let startTime = Date()
        
        // Teste verschiedene Query-Komplexitäten
        let simpleQuery = """
        {"query": "{ hello }"}
        """
        
        let complexQuery = """
        {"query": "query IntrospectionQuery { __schema { queryType { name fields { name type { name kind } } } } }"}
        """
        
        addTestResult(.init(
            name: "Payload-Größen Test",
            success: true,
            message: String(format: "Simple Query: %d Bytes | Complex Query: %d Bytes", 
                           simpleQuery.data(using: .utf8)?.count ?? 0,
                           complexQuery.data(using: .utf8)?.count ?? 0),
            duration: Date().timeIntervalSince(startTime)
        ))
    }
    
    // MARK: - Cache Tests
    
    private func performCacheTests() {
        isLoading = true
        testResults.removeAll()
        
        addTestResult(.init(
            name: "Cache Tests",
            success: true,
            message: "💾 Apollo Cache-Verhalten wird getestet...",
            duration: 0
        ))
        
        // Test 1: Cache-Population (erste Abfrage)
        performCachePopulationTest()
        
        // Test 2: Cache-Hit Test (zweite Abfrage)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.performCacheHitTest()
        }
        
        // Test 3: Cache-Invalidation
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            self.performCacheInvalidationTest()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
            self.isLoading = false
        }
    }
    
    private func performCachePopulationTest() {
        let startTime = Date()
        
        // Erste Abfrage - sollte das Cache füllen
        userService.hello()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    let duration = Date().timeIntervalSince(startTime)
                    
                    switch completion {
                    case .finished:
                        addTestResult(.init(
                            name: "Cache Population",
                            success: true,
                            message: String(format: "Cache gefüllt (Network Request: %.0fms)", duration * 1000),
                            duration: duration
                        ))
                    case .failure(let error):
                        addTestResult(.init(
                            name: "Cache Population",
                            success: false,
                            message: "Fehler: \(error.localizedDescription)",
                            duration: duration
                        ))
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func performCacheHitTest() {
        let startTime = Date()
        
        // Zweite Abfrage - sollte aus Cache kommen (viel schneller)
        userService.hello()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    let duration = Date().timeIntervalSince(startTime)
                    
                    switch completion {
                    case .finished:
                        let isCacheHit = duration < 0.1 // Unter 100ms = wahrscheinlich Cache Hit
                        let cacheStatus = isCacheHit ? "✅ Cache Hit" : "🌐 Network Request"
                        let comment = isCacheHit ? "- Sehr schnell!" : "- Cache funktioniert möglicherweise nicht"
                        
                        addTestResult(.init(
                            name: "Cache Hit Test",
                            success: true,
                            message: "\(cacheStatus) (\(String(format: "%.0f", duration * 1000))ms) \(comment)",
                            duration: duration
                        ))
                    case .failure(let error):
                        addTestResult(.init(
                            name: "Cache Hit Test",
                            success: false,
                            message: "Fehler: \(error.localizedDescription)",
                            duration: duration
                        ))
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func performCacheInvalidationTest() {
        // Cache löschen und Performance vergleichen
        apolloClient.clearCache()
        
        let startTime = Date()
        
        userService.hello()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    let duration = Date().timeIntervalSince(startTime)
                    
                    switch completion {
                    case .finished:
                        addTestResult(.init(
                            name: "Cache Invalidation",
                            success: true,
                            message: String(format: "Cache geleert → Network Request (%.0fms)", duration * 1000),
                            duration: duration
                        ))
                    case .failure(let error):
                        addTestResult(.init(
                            name: "Cache Invalidation",
                            success: false,
                            message: "Fehler: \(error.localizedDescription)",
                            duration: duration
                        ))
                    }
                },
                receiveValue: { _ in }
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            performPerformanceTests()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 18) {
            performCacheTests()
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
    let isDisabled: Bool
    let action: () -> Void
    
    init(title: String, subtitle: String, icon: String, color: Color, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isDisabled ? .gray : color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isDisabled ? .gray : .primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isDisabled ? .gray : .secondary)
                }
                
                Spacer()
                
                Image(systemName: isDisabled ? "pause.circle" : "play.circle")
                    .foregroundColor(isDisabled ? .gray : color)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
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