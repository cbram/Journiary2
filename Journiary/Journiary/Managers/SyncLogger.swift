import Foundation
import os.log

/// Erweiterte Logging-Infrastruktur für Synchronisations-Operationen
/// Implementiert Phase 7.1: Strukturiertes Logging für Debug und Monitoring
class SyncLogger {
    static let shared = SyncLogger()
    
    private let logger = Logger(subsystem: "com.journiary.sync", category: "SyncManager")
    private let logQueue = DispatchQueue(label: "SyncLogger", qos: .utility)
    
    /// Log-Level mit entsprechenden Prioritäten und visueller Darstellung
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        
        /// Emoji für visuelle Unterscheidung der Log-Level
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
        
        /// Priorität für Filterung und Sortierung
        var priority: Int {
            switch self {
            case .debug: return 0
            case .info: return 1
            case .warning: return 2
            case .error: return 3
            case .critical: return 4
            }
        }
    }
    
    /// Strukturierter Log-Eintrag mit umfassenden Metadaten
    struct LogEntry {
        let id: UUID
        let timestamp: Date
        let level: LogLevel
        let category: String
        let message: String
        let metadata: [String: Any]
        let stackTrace: String?
        let threadName: String
        let memoryUsage: UInt64
        
        /// Formatierte Ausgabe für Console und Export
        var formattedMessage: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            let timeString = formatter.string(from: timestamp)
            
            var message = "\(level.emoji) [\(timeString)] [\(threadName)] \(category): \(self.message)"
            
            if !metadata.isEmpty {
                let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                message += " {\(metadataString)}"
            }
            
            if memoryUsage > 0 {
                message += " [Mem: \(formatBytes(memoryUsage))]"
            }
            
            return message
        }
        
        /// JSON-Serialisierung für strukturierte Logs
        var jsonRepresentation: [String: Any] {
            var json: [String: Any] = [
                "id": id.uuidString,
                "timestamp": ISO8601DateFormatter().string(from: timestamp),
                "level": level.rawValue,
                "category": category,
                "message": message,
                "thread": threadName,
                "memory_bytes": memoryUsage
            ]
            
            if !metadata.isEmpty {
                json["metadata"] = metadata
            }
            
            if let stackTrace = stackTrace {
                json["stack_trace"] = stackTrace
            }
            
            return json
        }
        
        /// Formatiert Bytes in lesbare Einheiten
        private func formatBytes(_ bytes: UInt64) -> String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .memory
            return formatter.string(fromByteCount: Int64(bytes))
        }
    }
    
    // MARK: - Properties
    
    private var logEntries: [LogEntry] = []
    private let maxLogEntries = 1000
    private let logLock = NSLock()
    
    /// Konfiguration für Log-Persistierung
    private let persistenceEnabled = true
    private let logFileURL: URL
    
    /// Performance-Statistiken
    private var logCounts: [LogLevel: Int] = [:]
    private var lastCleanupTime = Date()
    private let cleanupInterval: TimeInterval = 300 // 5 Minuten
    
    // MARK: - Initialization
    
    private init() {
        // Erstelle Log-File-URL im Documents-Verzeichnis
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = documentsPath.appendingPathComponent("sync_logs.json")
        
        // Initialisiere Log-Counts
        for level in LogLevel.allCases {
            logCounts[level] = 0
        }
        
        // Lade persistierte Logs
        loadPersistedLogs()
        
        // Starte periodische Bereinigung
        startPeriodicCleanup()
        
        info("SyncLogger initialisiert", category: "Initialization", metadata: [
            "max_entries": maxLogEntries,
            "persistence": persistenceEnabled,
            "log_file": logFileURL.path
        ])
    }
    
    // MARK: - Public Logging Methods
    
    /// Hauptmethode für strukturiertes Logging
    /// - Parameters:
    ///   - level: Log-Level für Priorität und Filterung
    ///   - category: Kategorisierung für bessere Organisation
    ///   - message: Die eigentliche Log-Nachricht
    ///   - metadata: Zusätzliche strukturierte Informationen
    ///   - includeStackTrace: Ob Stack-Trace mit aufgezeichnet werden soll
    func log(
        level: LogLevel,
        category: String,
        message: String,
        metadata: [String: Any] = [:],
        includeStackTrace: Bool = false
    ) {
        let stackTrace = includeStackTrace ? Thread.callStackSymbols.joined(separator: "\n") : nil
        let threadName = Thread.current.name ?? "Unknown"
        let memoryUsage = getCurrentMemoryUsage()
        
        let entry = LogEntry(
            id: UUID(),
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            stackTrace: stackTrace,
            threadName: threadName,
            memoryUsage: memoryUsage
        )
        
        // Asynchrone Verarbeitung für Performance
        logQueue.async { [weak self] in
            self?.processLogEntry(entry)
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Debug-Logging für detaillierte Entwicklungsinformationen
    func debug(_ message: String, category: String = "General", metadata: [String: Any] = [:]) {
        log(level: .debug, category: category, message: message, metadata: metadata)
    }
    
    /// Info-Logging für allgemeine Informationen
    func info(_ message: String, category: String = "General", metadata: [String: Any] = [:]) {
        log(level: .info, category: category, message: message, metadata: metadata)
    }
    
    /// Warning-Logging für potenzielle Probleme
    func warning(_ message: String, category: String = "General", metadata: [String: Any] = [:]) {
        log(level: .warning, category: category, message: message, metadata: metadata)
    }
    
    /// Error-Logging für Fehler mit optionalem Stack-Trace
    func error(_ message: String, category: String = "General", metadata: [String: Any] = [:], includeStackTrace: Bool = true) {
        log(level: .error, category: category, message: message, metadata: metadata, includeStackTrace: includeStackTrace)
    }
    
    /// Critical-Logging für schwerwiegende Probleme (immer mit Stack-Trace)
    func critical(_ message: String, category: String = "General", metadata: [String: Any] = [:]) {
        log(level: .critical, category: category, message: message, metadata: metadata, includeStackTrace: true)
    }
    
    // MARK: - Retrieval Methods
    
    /// Ruft die neuesten Log-Einträge ab
    /// - Parameters:
    ///   - count: Anzahl der gewünschten Einträge
    ///   - level: Optionale Filterung nach Log-Level
    ///   - category: Optionale Filterung nach Kategorie
    /// - Returns: Array der gefilterten Log-Einträge
    func getRecentLogs(count: Int = 100, level: LogLevel? = nil, category: String? = nil) -> [LogEntry] {
        return logQueue.sync {
            var filteredLogs = logEntries
            
            // Filter nach Level
            if let level = level {
                filteredLogs = filteredLogs.filter { $0.level == level }
            }
            
            // Filter nach Kategorie
            if let category = category {
                filteredLogs = filteredLogs.filter { $0.category == category }
            }
            
            // Sortiere nach Timestamp (neueste zuerst) und begrenze
            return Array(filteredLogs.sorted { $0.timestamp > $1.timestamp }.prefix(count))
        }
    }
    
    /// Exportiert alle Logs als formatierte String-Ausgabe
    /// - Parameter includeMetadata: Ob Metadaten in Export enthalten sein sollen
    /// - Returns: Formatierte Log-Ausgabe
    func exportLogs(includeMetadata: Bool = true) -> String {
        return logQueue.sync {
            let sortedLogs = logEntries.sorted { $0.timestamp < $1.timestamp }
            
            if includeMetadata {
                return sortedLogs.map { $0.formattedMessage }.joined(separator: "\n")
            } else {
                return sortedLogs.map { entry in
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm:ss.SSS"
                    let timeString = formatter.string(from: entry.timestamp)
                    return "\(entry.level.emoji) [\(timeString)] \(entry.category): \(entry.message)"
                }.joined(separator: "\n")
            }
        }
    }
    
    /// Exportiert Logs als JSON für maschinelle Verarbeitung
    /// - Returns: JSON-String mit strukturierten Log-Daten
    func exportLogsAsJSON() -> String {
        return logQueue.sync {
            let sortedLogs = logEntries.sorted { $0.timestamp < $1.timestamp }
            let jsonLogs = sortedLogs.map { $0.jsonRepresentation }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: jsonLogs, options: .prettyPrinted)
                return String(data: jsonData, encoding: .utf8) ?? "[]"
            } catch {
                self.error("Failed to serialize logs to JSON", category: "Export", metadata: ["error": error.localizedDescription])
                return "[]"
            }
        }
    }
    
    // MARK: - Statistics and Monitoring
    
    /// Ruft Logging-Statistiken ab
    /// - Returns: Dictionary mit Statistiken pro Log-Level
    func getLogStatistics() -> [String: Any] {
        return logQueue.sync {
            var stats: [String: Any] = [
                "total_entries": logEntries.count,
                "max_entries": maxLogEntries,
                "memory_usage_bytes": getCurrentMemoryUsage(),
                "last_cleanup": ISO8601DateFormatter().string(from: lastCleanupTime)
            ]
            
            // Counts pro Level
            var levelCounts: [String: Int] = [:]
            for (level, count) in logCounts {
                levelCounts[level.rawValue] = count
            }
            stats["level_counts"] = levelCounts
            
            // Kategorien-Statistiken
            let categories = Dictionary(grouping: logEntries) { $0.category }
            var categoryStats: [String: Int] = [:]
            for (category, entries) in categories {
                categoryStats[category] = entries.count
            }
            stats["category_counts"] = categoryStats
            
            return stats
        }
    }
    
    /// Bereinigt alte Log-Einträge und optimiert Speicherverbrauch
    func performCleanup() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.logLock.lock()
            defer { self.logLock.unlock() }
            
            let initialCount = self.logEntries.count
            
            // Entferne alte Einträge wenn Limit überschritten
            if self.logEntries.count > self.maxLogEntries {
                let removeCount = self.logEntries.count - self.maxLogEntries
                self.logEntries.removeFirst(removeCount)
            }
            
            // Entferne Debug-Logs älter als 1 Stunde
            let oneHourAgo = Date().addingTimeInterval(-3600)
            self.logEntries.removeAll { entry in
                entry.level == .debug && entry.timestamp < oneHourAgo
            }
            
            let finalCount = self.logEntries.count
            self.lastCleanupTime = Date()
            
            // Persistiere nach Bereinigung
            if self.persistenceEnabled {
                self.persistLogs()
            }
            
            self.debug("Log cleanup completed", category: "Maintenance", metadata: [
                "initial_count": initialCount,
                "final_count": finalCount,
                "removed_count": initialCount - finalCount
            ])
        }
    }
    
    // MARK: - Private Methods
    
    /// Verarbeitet einen Log-Eintrag (Thread-sicher)
    private func processLogEntry(_ entry: LogEntry) {
        logLock.lock()
        defer { logLock.unlock() }
        
        // Füge zum internen Array hinzu
        logEntries.append(entry)
        
        // Aktualisiere Statistiken
        logCounts[entry.level, default: 0] += 1
        
        // Console und System-Logger-Ausgabe
        outputLog(entry)
        
        // Periodische Bereinigung
        if logEntries.count % 100 == 0 {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.performCleanup()
            }
        }
    }
    
    /// Gibt Log-Eintrag an Console und System-Logger aus
    private func outputLog(_ entry: LogEntry) {
        // Console-Output
        print(entry.formattedMessage)
        
        // System-Logger mit entsprechendem Level
        switch entry.level {
        case .debug:
            logger.debug("\(entry.message)")
        case .info:
            logger.info("\(entry.message)")
        case .warning:
            logger.warning("\(entry.message)")
        case .error:
            logger.error("\(entry.message)")
        case .critical:
            logger.critical("\(entry.message)")
        }
    }
    
    /// Ermittelt aktuelle Speichernutzung
    private func getCurrentMemoryUsage() -> UInt64 {
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
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
    
    /// Startet periodische Bereinigung
    private func startPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
    }
    
    /// Lädt persistierte Logs beim Start
    private func loadPersistedLogs() {
        guard persistenceEnabled, FileManager.default.fileExists(atPath: logFileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: logFileURL)
            let jsonLogs = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            
            // Konvertiere JSON zurück zu LogEntry (vereinfacht)
            for jsonLog in jsonLogs.suffix(maxLogEntries / 2) { // Lade nur die neuesten
                if let timestamp = jsonLog["timestamp"] as? String,
                   let levelString = jsonLog["level"] as? String,
                   let level = LogLevel(rawValue: levelString),
                   let category = jsonLog["category"] as? String,
                   let message = jsonLog["message"] as? String {
                    
                    let date = ISO8601DateFormatter().date(from: timestamp) ?? Date()
                    let metadata = jsonLog["metadata"] as? [String: Any] ?? [:]
                    let stackTrace = jsonLog["stack_trace"] as? String
                    let threadName = jsonLog["thread"] as? String ?? "Unknown"
                    let memoryUsage = jsonLog["memory_bytes"] as? UInt64 ?? 0
                    
                    let entry = LogEntry(
                        id: UUID(),
                        timestamp: date,
                        level: level,
                        category: category,
                        message: message,
                        metadata: metadata,
                        stackTrace: stackTrace,
                        threadName: threadName,
                        memoryUsage: memoryUsage
                    )
                    
                    logEntries.append(entry)
                    logCounts[level, default: 0] += 1
                }
            }
            
            debug("Loaded \(logEntries.count) persisted log entries", category: "Initialization")
        } catch {
            print("⚠️ Failed to load persisted logs: \(error.localizedDescription)")
        }
    }
    
    /// Persistiert aktuelle Logs
    private func persistLogs() {
        guard persistenceEnabled else { return }
        
        let jsonLogs = logEntries.map { $0.jsonRepresentation }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonLogs, options: .prettyPrinted)
            try jsonData.write(to: logFileURL)
        } catch {
            print("⚠️ Failed to persist logs: \(error.localizedDescription)")
        }
    }
}

// MARK: - Specialized Logging for Sync Operations

/// Spezialisierte Logging-Methoden für Synchronisations-spezifische Operationen
extension SyncLogger {
    
    /// Loggt den Start einer Sync-Operation
    func logSyncStart(reason: String, metadata: [String: Any] = [:]) {
        var syncMetadata = metadata
        syncMetadata["sync_reason"] = reason
        syncMetadata["sync_phase"] = "start"
        
        info("🔄 Sync gestartet", category: "SyncOperation", metadata: syncMetadata)
    }
    
    /// Loggt den erfolgreichen Abschluss einer Sync-Operation
    func logSyncSuccess(reason: String, duration: TimeInterval, entitiesProcessed: Int, metadata: [String: Any] = [:]) {
        var syncMetadata = metadata
        syncMetadata["sync_reason"] = reason
        syncMetadata["sync_phase"] = "success"
        syncMetadata["duration_seconds"] = duration
        syncMetadata["entities_processed"] = entitiesProcessed
        syncMetadata["throughput_entities_per_second"] = entitiesProcessed > 0 ? Double(entitiesProcessed) / duration : 0
        
        info("✅ Sync erfolgreich abgeschlossen", category: "SyncOperation", metadata: syncMetadata)
    }
    
    /// Loggt Sync-Fehler mit detaillierten Informationen
    func logSyncError(reason: String, error: Error, phase: String = "unknown", metadata: [String: Any] = [:]) {
        var syncMetadata = metadata
        syncMetadata["sync_reason"] = reason
        syncMetadata["sync_phase"] = phase
        syncMetadata["error_type"] = String(describing: type(of: error))
        syncMetadata["error_code"] = (error as NSError).code
        syncMetadata["error_domain"] = (error as NSError).domain
        
        self.error("❌ Sync fehlgeschlagen: \(error.localizedDescription)", 
                  category: "SyncOperation", 
                  metadata: syncMetadata, 
                  includeStackTrace: true)
    }
    
    /// Loggt Konflikt-Resolution-Ereignisse
    func logConflictResolution(entityType: String, conflictType: String, resolution: String, metadata: [String: Any] = [:]) {
        var conflictMetadata = metadata
        conflictMetadata["entity_type"] = entityType
        conflictMetadata["conflict_type"] = conflictType
        conflictMetadata["resolution_strategy"] = resolution
        
        warning("⚠️ Konflikt gelöst", category: "ConflictResolution", metadata: conflictMetadata)
    }
    
    /// Loggt Performance-Metriken
    func logPerformanceMetric(operation: String, duration: TimeInterval, metadata: [String: Any] = [:]) {
        var perfMetadata = metadata
        perfMetadata["operation"] = operation
        perfMetadata["duration_ms"] = duration * 1000
        perfMetadata["performance_category"] = duration < 1.0 ? "fast" : duration < 5.0 ? "normal" : "slow"
        
        let level: LogLevel = duration > 10.0 ? .warning : .debug
        log(level: level, category: "Performance", message: "⏱️ \(operation) completed in \(String(format: "%.2f", duration))s", metadata: perfMetadata)
    }
} 