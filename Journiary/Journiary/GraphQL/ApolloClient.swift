//
//  ApolloClient.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine
import SQLite3
// TODO: Nach Apollo iOS Installation ersetzen durch:
// import Apollo
// import ApolloSQLite 
// import ApolloAPI

/// Production-ready GraphQL Client Implementation
/// Mit SQLite Cache, JWT Authentication und Error Handling
/// Apollo-kompatibel - wird später zu Apollo migriert
class ApolloClientManager: ObservableObject {
    
    static let shared = ApolloClientManager()
    
    // MARK: - Published Properties
    
    @Published var isConnected = false
    @Published var lastError: GraphQLError?
    
    // MARK: - Private Properties
    
    private let graphQLCache: GraphQLCache
    private let networkClient: GraphQLNetworkClient
    private let authManager = AuthManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Cache und Storage wird über static method erstellt
    
    private init() {
        self.networkClient = GraphQLNetworkClient()
        self.graphQLCache = GraphQLCache(databaseURL: Self.createCacheFileURL())
        setupClient()
        checkConnection()
    }
    
    private static func createCacheFileURL() -> URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return URL(fileURLWithPath: documentsPath).appendingPathComponent("graphql_cache.sqlite")
    }
    
    // MARK: - Client Setup
    
    private func setupClient() {
        // Cache initialisieren
        graphQLCache.initialize()
        print("✅ GraphQL Client erfolgreich konfiguriert")
        print("📦 Cache: \(Self.createCacheFileURL().path)")
    }
    
    // MARK: - Public Methods
    
    /// GraphQL Query ausführen mit Cache-First Policy
    func fetch<T: Codable>(
        query: String,
        variables: [String: Any] = [:],
        cachePolicy: CachePolicy = .cacheFirst,
        resultType: T.Type
    ) -> AnyPublisher<T, GraphQLError> {
        
        let queryHash = query.sha256
        
        // 1. Cache prüfen (falls erlaubt)
        if cachePolicy != .networkOnly {
            if let cachedResult = graphQLCache.getCachedResult(for: queryHash, resultType: resultType) {
                print("📦 Cache Hit für Query: \(queryHash.prefix(8))")
                return Just(cachedResult)
                    .setFailureType(to: GraphQLError.self)
                    .eraseToAnyPublisher()
            }
        }
        
        // 2. Network Request mit JWT Authentication
        return networkClient.performQuery(query: query, variables: variables)
            .tryMap { [weak self] jsonResult -> T in
                // Response parsen
                guard let data = jsonResult["data"] as? [String: Any] else {
                    throw GraphQLError.serverError("Keine data in GraphQL Response")
                }
                
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let result = try JSONDecoder().decode(T.self, from: jsonData)
                
                // In Cache speichern (falls erlaubt)
                if cachePolicy != .networkOnly {
                    self?.graphQLCache.cacheResult(result, for: queryHash)
                }
                
                return result
            }
            .mapError { error -> GraphQLError in
                if let graphQLError = error as? GraphQLError {
                    return graphQLError
                } else {
                    return GraphQLError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Cache komplett löschen
    func clearCache() {
        graphQLCache.clearAll()
        print("✅ GraphQL Cache erfolgreich geleert")
    }
    
    /// Backend URL geändert → Client neu konfigurieren
    func recreateClientForNewBackendURL() {
        setupClient()
        checkConnection()
    }
    
    // MARK: - Connection Management
    
    func checkConnection() {
        healthCheck()
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        self?.isConnected = false
                        self?.lastError = error
                    }
                },
                receiveValue: { [weak self] success in
                    self?.isConnected = success
                    if success {
                        self?.lastError = nil
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Health Check
    
    func healthCheck() -> AnyPublisher<Bool, GraphQLError> {
        let helloQuery = "{ hello }"
        
        return networkClient.performQuery(query: helloQuery)
            .map { result -> Bool in
                if let data = result["data"] as? [String: Any],
                   let _ = data["hello"] {
                    return true
                } else {
                    return false
                }
            }
            .mapError { error -> GraphQLError in
                if let graphQLError = error as? GraphQLError {
                    return graphQLError
                } else {
                    return GraphQLError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - GraphQL Cache

class GraphQLCache {
    private var db: OpaquePointer?
    private let databaseURL: URL
    private let queue = DispatchQueue(label: "graphql.cache", qos: .utility)
    
    init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }
    
    func initialize() {
        queue.sync {
            if sqlite3_open(databaseURL.path, &db) == SQLITE_OK {
                createTable()
            } else {
                print("❌ SQLite Cache konnte nicht geöffnet werden")
            }
        }
    }
    
    private func createTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS graphql_cache (
                query_hash TEXT PRIMARY KEY,
                result_json TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                expires_at INTEGER
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ Cache Tabelle konnte nicht erstellt werden")
        }
    }
    
    func getCachedResult<T: Codable>(for queryHash: String, resultType: T.Type) -> T? {
        var result: T?
        
        queue.sync {
            let selectSQL = "SELECT result_json FROM graphql_cache WHERE query_hash = ? AND (expires_at IS NULL OR expires_at > ?);"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, queryHash, -1, nil)
                sqlite3_bind_int64(statement, 2, Int64(Date().timeIntervalSince1970))
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    if let jsonString = sqlite3_column_text(statement, 0) {
                        let jsonData = Data(String(cString: jsonString).utf8)
                        result = try? JSONDecoder().decode(T.self, from: jsonData)
                    }
                }
            }
            
            sqlite3_finalize(statement)
        }
        
        return result
    }
    
    func cacheResult<T: Codable>(_ result: T, for queryHash: String, expiresIn: TimeInterval = 300) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let encoder = JSONEncoder()
            if let jsonData = try? encoder.encode(result),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                
                let insertSQL = "INSERT OR REPLACE INTO graphql_cache (query_hash, result_json, timestamp, expires_at) VALUES (?, ?, ?, ?);"
                var statement: OpaquePointer?
                
                if sqlite3_prepare_v2(self.db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_text(statement, 1, queryHash, -1, nil)
                    sqlite3_bind_text(statement, 2, jsonString, -1, nil)
                    sqlite3_bind_int64(statement, 3, Int64(Date().timeIntervalSince1970))
                    sqlite3_bind_int64(statement, 4, Int64(Date().timeIntervalSince1970 + expiresIn))
                    
                    sqlite3_step(statement)
                }
                
                sqlite3_finalize(statement)
            }
        }
    }
    
    func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let deleteSQL = "DELETE FROM graphql_cache;"
            sqlite3_exec(self.db, deleteSQL, nil, nil, nil)
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
}

// MARK: - GraphQL Network Client

class GraphQLNetworkClient {
    private let session = URLSession.shared
    
    func performQuery(query: String, variables: [String: Any] = [:]) -> AnyPublisher<[String: Any], GraphQLError> {
        guard let url = URL(string: "\(AppSettings.shared.backendURL)/graphql") else {
            return Fail(error: GraphQLError.networkError("Ungültige Backend URL"))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // JWT Token hinzufügen (Production JWT Authentication)
        if let token = AuthManager.shared.getCurrentAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔐 JWT Token hinzugefügt: \(token.prefix(10))...")
        }
        
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Fail(error: GraphQLError.invalidInput("JSON Serialization fehlgeschlagen"))
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data -> [String: Any] in
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw GraphQLError.invalidInput("Ungültige JSON Antwort")
                }
                
                // GraphQL Errors prüfen
                if let errors = json["errors"] as? [[String: Any]], !errors.isEmpty {
                    let errorMessage = errors.compactMap { $0["message"] as? String }.joined(separator: ", ")
                    throw GraphQLError.serverError(errorMessage)
                }
                
                return json
            }
            .mapError { error -> GraphQLError in
                if let graphQLError = error as? GraphQLError {
                    return graphQLError
                } else {
                    return GraphQLError.networkError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Cache Policy

enum CachePolicy {
    case cacheFirst    // Cache zuerst, dann Network
    case networkFirst  // Network zuerst, Cache als Fallback
    case cacheOnly     // Nur Cache
    case networkOnly   // Nur Network
}

// MARK: - String Extension for Hashing

extension String {
    var sha256: String {
        guard let data = self.data(using: .utf8) else { return self }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - CC_SHA256 Import
import CommonCrypto

// MARK: - GraphQL Error (Production-ready)

enum GraphQLError: LocalizedError {
    case networkError(String)
    case authenticationRequired
    case invalidInput(String)
    case notFound(String)
    case serverError(String)
    case cacheError(String)
    case parseError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Netzwerk-Fehler: \(message)"
        case .authenticationRequired:
            return "Anmeldung erforderlich"
        case .invalidInput(let message):
            return "Ungültige Eingabe: \(message)"
        case .notFound(let message):
            return "Nicht gefunden: \(message)"
        case .serverError(let message):
            return "Server-Fehler: \(message)"
        case .cacheError(let message):
            return "Cache-Fehler: \(message)"
        case .parseError(let message):
            return "Parse-Fehler: \(message)"
        case .unknown(let message):
            return "Unbekannter Fehler: \(message)"
        }
    }
    
    var localizedDescription: String {
        return errorDescription ?? "Unbekannter Fehler"
    }
}