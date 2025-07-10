import Foundation

/// Struktur für Performance-Metriken einer Sync-Operation
struct SyncPerformanceMetrics {
    let operation: String
    let duration: TimeInterval
    let entityCount: Int
    let timestamp: Date
    let memoryUsage: UInt64
    let networkBytesTransferred: Int64
    
    /// Durchsatz in Entitäten pro Sekunde
    var throughput: Double {
        return Double(entityCount) / duration
    }
    
    /// Netzwerk-Durchsatz in Bytes pro Sekunde
    var bytesPerSecond: Double {
        return Double(networkBytesTransferred) / duration
    }
}

/// Zentraler Performance-Monitor für Sync-Operationen
/// Implementiert als Singleton zur Sammlung und Auswertung von Performance-Metriken
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private var metrics: [SyncPerformanceMetrics] = []
    private let metricsLock = NSLock()
    
    private init() {}
    
    /// Startet eine neue Performance-Messung
    /// - Parameter operation: Name der Operation (z.B. "SyncUpload", "SyncDownload")
    /// - Returns: PerformanceMeasurement-Objekt für die Messung
    func startMeasuring(operation: String) -> PerformanceMeasurement {
        return PerformanceMeasurement(operation: operation, monitor: self)
    }
    
    /// Zeichnet Performance-Metriken auf
    /// - Parameter metrics: Die aufzuzeichnenden Metriken
    func recordMetrics(_ metrics: SyncPerformanceMetrics) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        self.metrics.append(metrics)
        
        // Behalte nur die letzten 100 Messungen für Memory-Effizienz
        if self.metrics.count > 100 {
            self.metrics.removeFirst(self.metrics.count - 100)
        }
        
        logPerformanceMetrics(metrics)
    }
    
    /// Berechnet die durchschnittliche Performance für eine Operation
    /// - Parameters:
    ///   - operation: Name der Operation
    ///   - lastMinutes: Zeitfenster für die Berechnung (Standard: 60 Minuten)
    /// - Returns: Durchschnittlicher Durchsatz oder nil wenn keine Daten verfügbar
    func getAveragePerformance(for operation: String, lastMinutes: Int = 60) -> Double? {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        let cutoffTime = Date().addingTimeInterval(-TimeInterval(lastMinutes * 60))
        let recentMetrics = metrics.filter { 
            $0.operation == operation && $0.timestamp > cutoffTime 
        }
        
        guard !recentMetrics.isEmpty else { return nil }
        
        let totalThroughput = recentMetrics.reduce(0) { $0 + $1.throughput }
        return totalThroughput / Double(recentMetrics.count)
    }
    
    /// Gibt alle verfügbaren Metriken zurück
    /// - Returns: Array aller gespeicherten Metriken
    func getAllMetrics() -> [SyncPerformanceMetrics] {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        return metrics
    }
    
    /// Gibt Metriken für eine bestimmte Operation zurück
    /// - Parameter operation: Name der Operation
    /// - Returns: Array der Metriken für die Operation
    func getMetrics(for operation: String) -> [SyncPerformanceMetrics] {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        return metrics.filter { $0.operation == operation }
    }
    
    /// Löscht alle gespeicherten Metriken
    func clearMetrics() {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        metrics.removeAll()
    }
    
    /// Berechnet Performance-Statistiken für eine Operation
    /// - Parameter operation: Name der Operation
    /// - Returns: Performance-Statistiken oder nil wenn keine Daten verfügbar
    func getPerformanceStats(for operation: String) -> PerformanceStats? {
        let operationMetrics = getMetrics(for: operation)
        guard !operationMetrics.isEmpty else { return nil }
        
        let durations = operationMetrics.map { $0.duration }
        let throughputs = operationMetrics.map { $0.throughput }
        
        return PerformanceStats(
            operation: operation,
            measurementCount: operationMetrics.count,
            averageDuration: durations.reduce(0, +) / Double(durations.count),
            minDuration: durations.min() ?? 0,
            maxDuration: durations.max() ?? 0,
            averageThroughput: throughputs.reduce(0, +) / Double(throughputs.count),
            minThroughput: throughputs.min() ?? 0,
            maxThroughput: throughputs.max() ?? 0
        )
    }
    
    /// Protokolliert Performance-Metriken
    /// - Parameter metrics: Die zu protokollierenden Metriken
    private func logPerformanceMetrics(_ metrics: SyncPerformanceMetrics) {
        print("📊 Performance: \(metrics.operation) - \(metrics.entityCount) entities in \(String(format: "%.2f", metrics.duration))s (Throughput: \(String(format: "%.1f", metrics.throughput)) entities/s)")
    }
}

/// Klasse für die Messung der Performance einer einzelnen Operation
class PerformanceMeasurement {
    let operation: String
    let startTime: Date
    let startMemory: UInt64
    private weak var monitor: PerformanceMonitor?
    
    init(operation: String, monitor: PerformanceMonitor) {
        self.operation = operation
        self.startTime = Date()
        self.monitor = monitor
        
        // Memory-Nutzung direkt erfassen
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        self.startMemory = kerr == KERN_SUCCESS ? info.resident_size : 0
    }
    
    /// Beendet die Messung und zeichnet die Metriken auf
    /// - Parameters:
    ///   - entityCount: Anzahl der verarbeiteten Entitäten
    ///   - networkBytes: Anzahl der übertragenen Netzwerk-Bytes
    func finish(entityCount: Int, networkBytes: Int64 = 0) {
        let duration = Date().timeIntervalSince(startTime)
        let endMemory = getMemoryUsage()
        
        let metrics = SyncPerformanceMetrics(
            operation: operation,
            duration: duration,
            entityCount: entityCount,
            timestamp: Date(),
            memoryUsage: endMemory - startMemory,
            networkBytesTransferred: networkBytes
        )
        
        monitor?.recordMetrics(metrics)
    }
    
    /// Ermittelt die aktuelle Speichernutzung
    /// - Returns: Speichernutzung in Bytes
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }
}

/// Struktur für Performance-Statistiken
struct PerformanceStats {
    let operation: String
    let measurementCount: Int
    let averageDuration: TimeInterval
    let minDuration: TimeInterval
    let maxDuration: TimeInterval
    let averageThroughput: Double
    let minThroughput: Double
    let maxThroughput: Double
    
    /// Formatierte Darstellung der Statistiken
    var formattedDescription: String {
        return """
        📊 Performance Stats für \(operation):
        - Messungen: \(measurementCount)
        - Durchschnittsdauer: \(String(format: "%.2f", averageDuration))s
        - Min/Max Dauer: \(String(format: "%.2f", minDuration))s / \(String(format: "%.2f", maxDuration))s
        - Durchschnittlicher Durchsatz: \(String(format: "%.1f", averageThroughput)) entities/s
        - Min/Max Durchsatz: \(String(format: "%.1f", minThroughput)) / \(String(format: "%.1f", maxThroughput)) entities/s
        """
    }
} 