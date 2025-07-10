import Foundation
import Network

/// Adaptiver Batch-Manager für dynamische Batch-Größen basierend auf Netzwerkbedingungen
/// Optimiert die Upload-/Download-Performance durch intelligente Anpassung der Batch-Größen
class AdaptiveBatchManager {
    
    // MARK: - Types
    
    /// Netzwerkqualität-Bewertung
    enum NetworkQuality {
        case excellent  // WiFi, schnelle Verbindung
        case good      // WiFi, mittlere Verbindung
        case fair      // 4G/5G mit guter Signalstärke
        case poor      // 3G oder schwache Verbindung
        
        var displayName: String {
            switch self {
            case .excellent: return "Ausgezeichnet"
            case .good: return "Gut"
            case .fair: return "Mittelmäßig"
            case .poor: return "Schwach"
            }
        }
    }
    
    /// Batch-Größen-Konfiguration
    struct BatchSizeConfig {
        let mediaItems: Int
        let gpxTracks: Int
        let memories: Int
        let maxTotalSize: Int64  // in Bytes
        
        static let defaultConfig = BatchSizeConfig(
            mediaItems: 5,
            gpxTracks: 10,
            memories: 20,
            maxTotalSize: 50 * 1024 * 1024  // 50 MB
        )
        
        static let excellentNetwork = BatchSizeConfig(
            mediaItems: 15,
            gpxTracks: 25,
            memories: 50,
            maxTotalSize: 200 * 1024 * 1024  // 200 MB
        )
        
        static let goodNetwork = BatchSizeConfig(
            mediaItems: 10,
            gpxTracks: 20,
            memories: 35,
            maxTotalSize: 100 * 1024 * 1024  // 100 MB
        )
        
        static let fairNetwork = BatchSizeConfig(
            mediaItems: 7,
            gpxTracks: 15,
            memories: 25,
            maxTotalSize: 75 * 1024 * 1024  // 75 MB
        )
        
        static let poorNetwork = BatchSizeConfig(
            mediaItems: 3,
            gpxTracks: 8,
            memories: 15,
            maxTotalSize: 25 * 1024 * 1024  // 25 MB
        )
    }
    
    // MARK: - Properties
    
    /// Netzwerk-Monitor für Qualitätsbewertung
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "adaptive.batch.network.monitor")
    
    /// Aktuell erkannte Netzwerkqualität
    private(set) var currentNetworkQuality: NetworkQuality = .fair
    
    /// Aktuelle Batch-Konfiguration
    private(set) var currentConfig: BatchSizeConfig = .defaultConfig
    
    /// Performance-Metriken für adaptive Anpassungen
    private var performanceHistory: [PerformanceMetric] = []
    private let maxHistorySize = 20
    
    /// Performance-Metrik für eine Batch-Operation
    private struct PerformanceMetric {
        let batchSize: Int
        let totalBytes: Int64
        let duration: TimeInterval
        let success: Bool
        let timestamp: Date
        
        var throughput: Double {
            guard duration > 0 else { return 0 }
            return Double(totalBytes) / duration  // Bytes pro Sekunde
        }
    }
    
    // MARK: - Initialization
    
    init() {
        startNetworkMonitoring()
        updateConfigForNetworkQuality()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Ermittelt die optimale Batch-Größe für eine bestimmte Entity-Type
    /// - Parameter entityType: Der Typ der zu synchronisierenden Entitäten
    /// - Returns: Die empfohlene Batch-Größe
    func recommendedBatchSize(for entityType: String) -> Int {
        switch entityType.lowercased() {
        case "mediaitem":
            return currentConfig.mediaItems
        case "gpxtrack":
            return currentConfig.gpxTracks
        case "memory":
            return currentConfig.memories
        default:
            return 10  // Standard-Fallback
        }
    }
    
    /// Prüft, ob eine Batch-Operation die maximale Dateigröße überschreitet
    /// - Parameter totalBytes: Die Gesamtgröße der Batch in Bytes
    /// - Returns: true, wenn die Größe akzeptabel ist
    func isBatchSizeAcceptable(totalBytes: Int64) -> Bool {
        return totalBytes <= currentConfig.maxTotalSize
    }
    
    /// Meldet das Ergebnis einer Batch-Operation zur Performance-Optimierung
    /// - Parameters:
    ///   - batchSize: Anzahl der verarbeiteten Elemente
    ///   - totalBytes: Gesamtgröße der übertragenen Daten
    ///   - duration: Dauer der Operation
    ///   - success: Erfolg der Operation
    func reportBatchPerformance(batchSize: Int, totalBytes: Int64, duration: TimeInterval, success: Bool) {
        let metric = PerformanceMetric(
            batchSize: batchSize,
            totalBytes: totalBytes,
            duration: duration,
            success: success,
            timestamp: Date()
        )
        
        performanceHistory.append(metric)
        
        // Halte Performance-Historie begrenzt
        if performanceHistory.count > maxHistorySize {
            performanceHistory.removeFirst()
        }
        
        // Optimiere Konfiguration basierend auf Performance
        optimizeConfigurationBasedOnPerformance()
        
        print("📊 Batch-Performance: \(batchSize) Elemente, \(formatBytes(totalBytes)), \(String(format: "%.1f", duration))s, Erfolg: \(success)")
    }
    
    /// Ermittelt die aktuelle Netzwerkqualität als String für UI-Anzeige
    var networkQualityDescription: String {
        return currentNetworkQuality.displayName
    }
    
    /// Gibt die aktuelle Konfiguration als Debug-String zurück
    var configurationDescription: String {
        return """
        Adaptive Batch-Konfiguration:
        - Netzwerkqualität: \(currentNetworkQuality.displayName)
        - MediaItems: \(currentConfig.mediaItems)
        - GPX-Tracks: \(currentConfig.gpxTracks)
        - Memories: \(currentConfig.memories)
        - Max. Gesamtgröße: \(formatBytes(currentConfig.maxTotalSize))
        - Performance-Historie: \(performanceHistory.count) Einträge
        """
    }
    
    // MARK: - Private Methods
    
    /// Startet das Netzwerk-Monitoring
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkQuality(from: path)
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    /// Aktualisiert die Netzwerkqualität basierend auf dem NWPath
    /// - Parameter path: Der aktuelle Netzwerkpfad
    private func updateNetworkQuality(from path: NWPath) {
        let newQuality: NetworkQuality
        
        if path.status != .satisfied {
            newQuality = .poor
        } else if path.usesInterfaceType(.wifi) {
            // WiFi-Verbindungen sind generell besser
            newQuality = path.isExpensive ? .good : .excellent
        } else if path.usesInterfaceType(.cellular) {
            // Mobilfunk-Qualität abschätzen
            newQuality = path.isExpensive ? .poor : .fair
        } else {
            newQuality = .fair
        }
        
        if newQuality != currentNetworkQuality {
            currentNetworkQuality = newQuality
            updateConfigForNetworkQuality()
            print("🌐 Netzwerkqualität aktualisiert: \(currentNetworkQuality.displayName)")
        }
    }
    
    /// Aktualisiert die Batch-Konfiguration basierend auf der Netzwerkqualität
    private func updateConfigForNetworkQuality() {
        switch currentNetworkQuality {
        case .excellent:
            currentConfig = .excellentNetwork
        case .good:
            currentConfig = .goodNetwork
        case .fair:
            currentConfig = .fairNetwork
        case .poor:
            currentConfig = .poorNetwork
        }
        
        print("⚙️ Batch-Konfiguration angepasst für \(currentNetworkQuality.displayName)-Netzwerk")
    }
    
    /// Optimiert die Konfiguration basierend auf Performance-Metriken
    private func optimizeConfigurationBasedOnPerformance() {
        guard performanceHistory.count >= 5 else { return }  // Mindestens 5 Metriken benötigt
        
        let recentMetrics = Array(performanceHistory.suffix(5))
        let successRate = Double(recentMetrics.filter { $0.success }.count) / Double(recentMetrics.count)
        let averageThroughput = recentMetrics.map { $0.throughput }.reduce(0, +) / Double(recentMetrics.count)
        
        // Wenn Erfolgsrate niedrig ist, reduziere Batch-Größen
        if successRate < 0.8 {
            currentConfig = BatchSizeConfig(
                mediaItems: max(1, Int(Double(currentConfig.mediaItems) * 0.8)),
                gpxTracks: max(1, Int(Double(currentConfig.gpxTracks) * 0.8)),
                memories: max(1, Int(Double(currentConfig.memories) * 0.8)),
                maxTotalSize: Int64(Double(currentConfig.maxTotalSize) * 0.8)
            )
            print("📉 Batch-Größen reduziert aufgrund niedriger Erfolgsrate: \(String(format: "%.1f%%", successRate * 100))")
        }
        // Wenn Performance gut ist, erhöhe Batch-Größen vorsichtig
        else if successRate >= 0.95 && averageThroughput > 1_000_000 {  // > 1 MB/s
            currentConfig = BatchSizeConfig(
                mediaItems: min(20, Int(Double(currentConfig.mediaItems) * 1.1)),
                gpxTracks: min(30, Int(Double(currentConfig.gpxTracks) * 1.1)),
                memories: min(60, Int(Double(currentConfig.memories) * 1.1)),
                maxTotalSize: min(300 * 1024 * 1024, Int64(Double(currentConfig.maxTotalSize) * 1.1))
            )
            print("📈 Batch-Größen erhöht aufgrund guter Performance: \(formatBytes(Int64(averageThroughput)))/s")
        }
    }
    
    /// Formatiert Byte-Werte für lesbare Ausgabe
    /// - Parameter bytes: Anzahl der Bytes
    /// - Returns: Formatierter String
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
} 