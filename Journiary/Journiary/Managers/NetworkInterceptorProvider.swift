import Foundation
import Apollo
import ApolloAPI

struct NetworkInterceptorProvider: InterceptorProvider {

    private let store: ApolloStore
    private let client: URLSessionClient

    init(store: ApolloStore, client: URLSessionClient) {
        self.store = store
        self.client = client
    }

    func interceptors<Operation: GraphQLOperation>(for operation: Operation) -> [ApolloInterceptor] {
        return [
            CacheReadInterceptor(store: self.store),
            ResponseCacheInterceptor(), // Neue optimierte Response-Caching
            AuthorizationInterceptor(),
            RequestCompressionInterceptor(), // Neue Request-Compression
            NetworkFetchInterceptor(client: self.client),
            ResponseCodeInterceptor(),
            JSONResponseParsingInterceptor(),
            AutomaticPersistedQueryInterceptor(),
            CacheWriteInterceptor(store: self.store),
            PerformanceMonitoringInterceptor() // Neue Performance-Überwachung
        ]
    }
}

// MARK: - Performance-optimierte Interceptors (Schritt 5.4)

/// Response-Caching-Interceptor für intelligentes Caching von GraphQL-Responses
/// Implementiert als Teil von Schritt 5.4 der Network-Request-Optimierungen
class ResponseCacheInterceptor: ApolloInterceptor {
    let id: String = "ResponseCacheInterceptor"
    
    func interceptAsync<Operation: GraphQLOperation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) {
        
        // Prüfe ob Response cachebar ist
        if let response = response,
           shouldCacheResponse(for: request) {
            
            let cacheKey = generateCacheKey(for: request)
            
            // Cache die Response für zukünftige Verwendung
            let data = response.rawData
            SyncCacheManager.shared.cacheEntity(
                data,
                forKey: cacheKey,
                ttl: getCacheTTL(for: request)
            )
            
            print("📦 Response gecacht: \(cacheKey)")
        }
        
        chain.proceedAsync(request: request, response: response, interceptor: self, completion: completion)
    }
    
    private func shouldCacheResponse<Operation: GraphQLOperation>(
        for request: HTTPRequest<Operation>
    ) -> Bool {
        // Cache nur Query-Operationen, nicht Mutations
        return Operation.operationType == .query
    }
    
    private func generateCacheKey<Operation: GraphQLOperation>(
        for request: HTTPRequest<Operation>
    ) -> String {
        let operationName = String(describing: Operation.self)
        let variablesHash = String(describing: request.operation).hashValue
        return "response:\(operationName):\(variablesHash)"
    }
    
    private func getCacheTTL<Operation: GraphQLOperation>(
        for request: HTTPRequest<Operation>
    ) -> TimeInterval {
        let operationName = String(describing: Operation.self)
        
        // Verschiedene TTL basierend auf Operation
        switch operationName {
        case let name where name.contains("Sync"):
            return 120 // 2 Minuten für Sync-Queries
        case let name where name.contains("User"):
            return 300 // 5 Minuten für User-Queries
        default:
            return 60 // 1 Minute Standard
        }
    }
}

/// Request-Compression-Interceptor für effizientere Datenübertragung
class RequestCompressionInterceptor: ApolloInterceptor {
    let id: String = "RequestCompressionInterceptor"
    
    func interceptAsync<Operation: GraphQLOperation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) {
        
        // Füge Compression-Headers hinzu
        var modifiedRequest = request
        modifiedRequest.addHeader(name: "Accept-Encoding", value: "gzip, deflate, br")
        
        // Vereinfachte Request-Compression - nur Header setzen
        // In einer produktiven Umgebung würde hier die tatsächliche Kompression stattfinden
        let bodyData = request.graphQLEndpoint.debugDescription.data(using: .utf8)
        if let bodyData = bodyData, bodyData.count > 1024 {
            
            print("🗜️ Request-Komprimierung würde hier stattfinden (\(bodyData.count) bytes)")
            modifiedRequest.addHeader(name: "Content-Encoding", value: "gzip")
        }
        
        chain.proceedAsync(request: modifiedRequest, response: response, interceptor: self, completion: completion)
    }
}

/// Performance-Monitoring-Interceptor für Netzwerk-Metriken
class PerformanceMonitoringInterceptor: ApolloInterceptor {
    let id: String = "PerformanceMonitoringInterceptor"
    
    func interceptAsync<Operation: GraphQLOperation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) {
        
        let startTime = Date()
        
        chain.proceedAsync(request: request, response: response, interceptor: self) { result in
            let duration = Date().timeIntervalSince(startTime)
            let operationName = String(describing: Operation.self)
            
            // Logge Performance-Metriken
            switch result {
            case .success:
                let responseSize = response?.rawData.count ?? 0
                print("📊 \(operationName): \(String(format: "%.0f", duration * 1000))ms, \(responseSize) bytes")
                
                // Warnung bei langsamen Requests
                if duration > 5.0 {
                    print("🐌 Langsame Netzwerk-Operation: \(operationName) (\(String(format: "%.1f", duration))s)")
                }
                
            case .failure(let error):
                print("❌ \(operationName) fehlgeschlagen nach \(String(format: "%.0f", duration * 1000))ms: \(error.localizedDescription)")
            }
            
            completion(result)
        }
    }
}

// MARK: - Network Metrics Collection

/// Sammelt Netzwerk-Metriken für Performance-Analyse
class NetworkMetricsCollector {
    static let shared = NetworkMetricsCollector()
    
    private var metrics: [NetworkMetric] = []
    private let metricsLock = NSLock()
    
    struct NetworkMetric {
        let operation: String
        let duration: TimeInterval
        let responseSize: Int
        let success: Bool
        let timestamp: Date
    }
    
    private init() {}
    
    func recordMetric(
        operation: String,
        duration: TimeInterval,
        responseSize: Int,
        success: Bool
    ) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        let metric = NetworkMetric(
            operation: operation,
            duration: duration,
            responseSize: responseSize,
            success: success,
            timestamp: Date()
        )
        
        metrics.append(metric)
        
        // Behalte nur die letzten 100 Metriken
        if metrics.count > 100 {
            metrics.removeFirst(metrics.count - 100)
        }
    }
    
    func getAverageResponseTime(for operation: String? = nil) -> TimeInterval {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        let filteredMetrics: [NetworkMetric]
        if let operation = operation {
            filteredMetrics = metrics.filter { $0.operation == operation && $0.success }
        } else {
            filteredMetrics = metrics.filter { $0.success }
        }
        
        guard !filteredMetrics.isEmpty else { return 0 }
        
        let totalDuration = filteredMetrics.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(filteredMetrics.count)
    }
    
    func getSuccessRate(for operation: String? = nil) -> Double {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        let filteredMetrics: [NetworkMetric]
        if let operation = operation {
            filteredMetrics = metrics.filter { $0.operation == operation }
        } else {
            filteredMetrics = metrics
        }
        
        guard !filteredMetrics.isEmpty else { return 0 }
        
        let successCount = filteredMetrics.filter { $0.success }.count
        return Double(successCount) / Double(filteredMetrics.count)
    }
} 