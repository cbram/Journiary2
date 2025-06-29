//
//  ApolloClient.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine
import SQLite3
import QuartzCore // For CACurrentMediaTime high-precision timing
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
    
    let graphQLCache: GraphQLCache // Public für Testing
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
    
    /// Typisierte GraphQL Query ausführen
    func fetch<Query: GraphQLQuery>(
        query: Query.Type,
        variables: [String: Any] = [:],
        cachePolicy: CachePolicy = .cacheFirst
    ) -> AnyPublisher<Query.Data, GraphQLError> {
        
        let queryString = Query.document
        let queryHash = queryString.sha256
        
        // 1. Cache prüfen (falls erlaubt)
        if cachePolicy != .networkOnly {
            if let cachedResult = graphQLCache.getCachedResult(for: queryHash, resultType: Query.Data.self) {
                print("📦 Cache Hit für Query: \(Query.operationName)")
                return Just(cachedResult)
                    .setFailureType(to: GraphQLError.self)
                    .eraseToAnyPublisher()
            }
        }
        
        // 2. Network Request mit JWT Authentication
        return networkClient.performQuery(query: queryString, variables: variables)
            .tryMap { [weak self] jsonResult -> Query.Data in
                // GraphQL Response parsen
                let responseData = try JSONSerialization.data(withJSONObject: jsonResult)
                let response = try JSONDecoder().decode(GraphQLResponse<Query.Data>.self, from: responseData)
                
                // Errors prüfen
                if let errors = response.errors, !errors.isEmpty {
                    let errorMessage = errors.map { $0.message }.joined(separator: ", ")
                    throw GraphQLError.serverError(errorMessage)
                }
                
                guard let data = response.data else {
                    throw GraphQLError.serverError("Keine data in GraphQL Response")
                }
                
                // In Cache speichern (falls erlaubt)
                if cachePolicy != .networkOnly {
                    self?.graphQLCache.cacheResult(data, for: queryHash)
                }
                
                print("✅ Query \(Query.operationName) erfolgreich")
                return data
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
    
    /// Typisierte GraphQL Mutation ausführen
    func perform<Mutation: GraphQLMutation>(
        mutation: Mutation.Type,
        variables: [String: Any] = [:]
    ) -> AnyPublisher<Mutation.Data, GraphQLError> {
        
        let mutationString = Mutation.document
        
        // Mutations verwenden immer networkOnly Policy
        return networkClient.performQuery(query: mutationString, variables: variables)
            .tryMap { jsonResult -> Mutation.Data in
                // GraphQL Response parsen
                let responseData = try JSONSerialization.data(withJSONObject: jsonResult)
                let response = try JSONDecoder().decode(GraphQLResponse<Mutation.Data>.self, from: responseData)
                
                // Errors prüfen
                if let errors = response.errors, !errors.isEmpty {
                    let errorMessage = errors.map { $0.message }.joined(separator: ", ")
                    throw GraphQLError.serverError(errorMessage)
                }
                
                guard let data = response.data else {
                    throw GraphQLError.serverError("Keine data in GraphQL Response")
                }
                
                print("✅ Mutation \(Mutation.operationName) erfolgreich")
                return data
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
    
    /// Legacy String-basierte GraphQL Query (deprecated)
    @available(*, deprecated, message: "Verwende typisierte fetch<Query>() stattdessen")
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
                        DispatchQueue.main.async {
                            self?.isConnected = false
                            self?.lastError = error
                        }
                    }
                },
                receiveValue: { [weak self] success in
                    DispatchQueue.main.async {
                        self?.isConnected = success
                        if success {
                            self?.lastError = nil
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Health Check
    
    func healthCheck() -> AnyPublisher<Bool, GraphQLError> {
        // Verwende typisierte HelloQuery für Health Check
        return fetch(query: HelloQuery.self, cachePolicy: .networkOnly)
            .map { response -> Bool in
                return !response.hello.isEmpty
            }
            .eraseToAnyPublisher()
    }
    
    /// Cache komplett leeren (für Testing)
    func clearAllCaches() {
        graphQLCache.clearAll()
    }
}

// MARK: - GraphQL Cache

class GraphQLCache {
    private var db: OpaquePointer?
    private let databaseURL: URL
    private let queue = DispatchQueue(label: "graphql.cache", qos: .userInitiated) // Higher QoS für bessere Performance
    
    // MARK: - In-Memory Cache Layer für Ultra-Performance
    private var memoryCache: [String: (data: Data, expiry: Date)] = [:]
    private let memoryCacheQueue = DispatchQueue(label: "memory.cache", qos: .userInitiated)
    private let memoryCacheMaxSize = 50 // Max 50 Einträge im Memory
    
    // MARK: - Performance Monitoring
    @Published var lastCacheAccessTime: TimeInterval = 0
    @Published var cacheHitRate: Double = 0
    private var totalAccesses: Int = 0
    private var cacheHits: Int = 0
    private var memoryHits: Int = 0
    
    init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }
    
    func initialize() {
        queue.sync {
            if sqlite3_open(databaseURL.path, &db) == SQLITE_OK {
                createTable()
                optimizeDatabase()
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
                expires_at INTEGER,
                access_count INTEGER DEFAULT 1,
                last_access INTEGER NOT NULL
            );
            
            -- Performance Index für schnelle Lookups
            CREATE INDEX IF NOT EXISTS idx_query_hash_expiry ON graphql_cache(query_hash, expires_at);
            CREATE INDEX IF NOT EXISTS idx_last_access ON graphql_cache(last_access);
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ Cache Tabelle konnte nicht erstellt werden")
        }
    }
    
    private func optimizeDatabase() {
        // SQLite Performance Optimierungen
        let optimizations = [
            "PRAGMA synchronous = NORMAL;",      // Weniger Disk-Syncs
            "PRAGMA cache_size = 10000;",        // Größerer Memory Cache (10MB)
            "PRAGMA temp_store = MEMORY;",       // Temporäre Tables im RAM
            "PRAGMA journal_mode = WAL;",        // Write-Ahead Logging für bessere Concurrency
            "PRAGMA mmap_size = 67108864;"       // Memory-mapped I/O (64MB)
        ]
        
        for sql in optimizations {
            sqlite3_exec(db, sql, nil, nil, nil)
        }
        
        print("🚀 SQLite Cache für Performance optimiert")
    }
    
    func getCachedResult<T: Codable>(for queryHash: String, resultType: T.Type) -> T? {
        let startTime = CACurrentMediaTime()
        var result: T?
        var cacheSource = ""
        totalAccesses += 1
        
        // 1. Memory Cache Check (Ultra-fast < 1ms)
        memoryCacheQueue.sync {
            if let cached = memoryCache[queryHash], cached.expiry > Date() {
                result = try? JSONDecoder().decode(T.self, from: cached.data)
                if result != nil {
                    memoryHits += 1
                    cacheHits += 1
                    cacheSource = "MEMORY"
                }
            }
        }
        
        // 2. SQLite Cache Check (falls Memory Cache Miss)
        if result == nil {
            queue.sync {
                let selectSQL = """
                    SELECT result_json FROM graphql_cache 
                    WHERE query_hash = ? AND (expires_at IS NULL OR expires_at > ?)
                    LIMIT 1;
                """
                var statement: OpaquePointer?
                
                if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_text(statement, 1, queryHash, -1, nil)
                    sqlite3_bind_int64(statement, 2, Int64(Date().timeIntervalSince1970))
                    
                    if sqlite3_step(statement) == SQLITE_ROW {
                        if let jsonString = sqlite3_column_text(statement, 0) {
                            let jsonData = Data(String(cString: jsonString).utf8)
                            result = try? JSONDecoder().decode(T.self, from: jsonData)
                            
                            if result != nil {
                                cacheHits += 1
                                cacheSource = "SQLITE"
                                
                                // 🚀 Promote to Memory Cache for next access
                                memoryCacheQueue.async { [weak self] in
                                    self?.addToMemoryCache(queryHash: queryHash, data: jsonData)
                                }
                                
                                // Update access statistics
                                updateAccessStats(for: queryHash)
                            }
                        }
                    }
                }
                
                sqlite3_finalize(statement)
            }
        }
        
        let duration = (CACurrentMediaTime() - startTime) * 1000 // Convert to milliseconds
        DispatchQueue.main.async {
            self.lastCacheAccessTime = duration
            self.cacheHitRate = Double(self.cacheHits) / Double(self.totalAccesses)
        }
        
        if result != nil {
            print("📦 Cache HIT \(cacheSource) (\(String(format: "%.3f", duration))ms) - Query: \(queryHash.prefix(8))")
        } else {
            print("📭 Cache MISS (\(String(format: "%.3f", duration))ms) - Query: \(queryHash.prefix(8))")
        }
        
        return result
    }
    
    private func addToMemoryCache(queryHash: String, data: Data) {
        // Memory Cache Management mit LRU
        if memoryCache.count >= memoryCacheMaxSize {
            // Remove oldest entry
            if let oldestKey = memoryCache.min(by: { $0.value.expiry < $1.value.expiry })?.key {
                memoryCache.removeValue(forKey: oldestKey)
            }
        }
        
        let expiry = Date().addingTimeInterval(300) // 5 Minuten
        memoryCache[queryHash] = (data: data, expiry: expiry)
    }
    
    private func updateAccessStats(for queryHash: String) {
        let updateSQL = """
            UPDATE graphql_cache 
            SET access_count = access_count + 1, last_access = ?
            WHERE query_hash = ?;
        """
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, Int64(Date().timeIntervalSince1970))
            sqlite3_bind_text(statement, 2, queryHash, -1, nil)
            sqlite3_step(statement)
        }
        
        sqlite3_finalize(statement)
    }
    
    func cacheResult<T: Codable>(_ result: T, for queryHash: String, expiresIn: TimeInterval = 300) {
        let startTime = CACurrentMediaTime()
        
        let encoder = JSONEncoder()
        guard let jsonData = try? encoder.encode(result),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ Cache WRITE Failed - JSON Encoding")
            return
        }
        
        // 1. 🚀 Memory Cache (sofort verfügbar)
        memoryCacheQueue.async { [weak self] in
            self?.addToMemoryCache(queryHash: queryHash, data: jsonData)
        }
        
        // 2. 💾 SQLite Cache (persistent)
        queue.async { [weak self] in
            guard let self = self else { return }
                
            let insertSQL = """
                INSERT OR REPLACE INTO graphql_cache 
                (query_hash, result_json, timestamp, expires_at, access_count, last_access) 
                VALUES (?, ?, ?, ?, 1, ?);
            """
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(self.db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                let now = Int64(Date().timeIntervalSince1970)
                
                sqlite3_bind_text(statement, 1, queryHash, -1, nil)
                sqlite3_bind_text(statement, 2, jsonString, -1, nil)
                sqlite3_bind_int64(statement, 3, now)
                sqlite3_bind_int64(statement, 4, now + Int64(expiresIn))
                sqlite3_bind_int64(statement, 5, now)
                
                sqlite3_step(statement)
            }
            
            sqlite3_finalize(statement)
            
            let duration = (CACurrentMediaTime() - startTime) * 1000
            print("💾 Cache WRITE DUAL (\(String(format: "%.3f", duration))ms) - Query: \(queryHash.prefix(8))")
        }
    }
    
    func clearAll() {
        // 1. Memory Cache leeren
        memoryCacheQueue.async { [weak self] in
            self?.memoryCache.removeAll()
        }
        
        // 2. SQLite Cache leeren
        queue.async { [weak self] in
            guard let self = self else { return }
            let deleteSQL = "DELETE FROM graphql_cache;"
            sqlite3_exec(self.db, deleteSQL, nil, nil, nil)
            
            // Reset statistics
            DispatchQueue.main.async {
                self.totalAccesses = 0
                self.cacheHits = 0
                self.memoryHits = 0
                self.cacheHitRate = 0
                self.lastCacheAccessTime = 0
            }
            
            print("🗑️ Dual Cache (Memory + SQLite) komplett geleert")
        }
    }
    
    // MARK: - Cache Analytics
    
    func getCacheAnalytics() -> AnyPublisher<CacheAnalytics, Never> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.success(CacheAnalytics()))
                return
            }
            
            self.queue.async {
                let statsSQL = """
                    SELECT 
                        COUNT(*) as total_entries,
                        SUM(access_count) as total_accesses,
                        AVG(access_count) as avg_accesses,
                        COUNT(CASE WHEN expires_at > ? THEN 1 END) as valid_entries
                    FROM graphql_cache;
                """
                
                var statement: OpaquePointer?
                var analytics = CacheAnalytics()
                
                if sqlite3_prepare_v2(self.db, statsSQL, -1, &statement, nil) == SQLITE_OK {
                    sqlite3_bind_int64(statement, 1, Int64(Date().timeIntervalSince1970))
                    
                    if sqlite3_step(statement) == SQLITE_ROW {
                        analytics.totalEntries = Int(sqlite3_column_int(statement, 0))
                        analytics.totalAccesses = Int(sqlite3_column_int(statement, 1))
                        analytics.avgAccesses = sqlite3_column_double(statement, 2)
                        analytics.validEntries = Int(sqlite3_column_int(statement, 3))
                        analytics.hitRate = self.cacheHitRate
                        analytics.memoryHitRate = self.totalAccesses > 0 ? Double(self.memoryHits) / Double(self.totalAccesses) : 0
                        analytics.lastAccessTime = self.lastCacheAccessTime
                        
                        // Memory Cache Analytics
                        self.memoryCacheQueue.sync {
                            analytics.memoryEntries = self.memoryCache.count
                        }
                    }
                }
                
                sqlite3_finalize(statement)
                promise(.success(analytics))
            }
        }
        .eraseToAnyPublisher()
    }
    
    deinit {
        sqlite3_close(db)
    }
}

// MARK: - Cache Analytics Model

struct CacheAnalytics: Codable {
    var totalEntries: Int = 0
    var validEntries: Int = 0
    var totalAccesses: Int = 0
    var avgAccesses: Double = 0
    var hitRate: Double = 0
    var memoryHitRate: Double = 0 // Memory Cache Hit Rate
    var lastAccessTime: TimeInterval = 0 // in milliseconds
    var memoryEntries: Int = 0 // Memory Cache Einträge
    
    var isPerformant: Bool {
        return lastAccessTime < 5.0 // Sub-5ms goal
    }
    
    var isUltraPerformant: Bool {
        return lastAccessTime < 1.0 // Sub-1ms goal für Memory Cache
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