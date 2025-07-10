import SwiftUI
import Foundation

// ViewModel für das Sync Debug Dashboard
class SyncDebugViewModel: ObservableObject {
    @Published var currentSyncStatus = "Idle"
    @Published var lastSyncTime = "Nie"
    @Published var pendingEntitiesCount = 0
    @Published var networkStatus = "Offline"
    @Published var conflictCount = 0
    @Published var entityStats: [EntitySyncStat] = []
    @Published var filteredLogs: [SyncLogger.LogEntry] = []
    @Published var selectedLogLevel: SyncLogger.LogLevel?
    
    // Performance-Daten
    @Published var averageSyncTime = "0.0"
    @Published var successRate: Double = 0.0
    @Published var throughput: Double = 0.0
    @Published var formattedNetworkBytes = "0 B"
    @Published var entityPerformance: [EntityPerformance] = []
    @Published var recentSyncOperations: [RecentSyncOperation] = []
    
    // Queue-Daten
    @Published var pendingUploads = 0
    @Published var pendingDownloads = 0
    @Published var failedOperations = 0
    @Published var queueOperations: [QueueOperation] = []
    
    struct EntitySyncStat {
        let entityType: String
        let totalCount: Int
        let syncedCount: Int
        let errorCount: Int
        
        var syncProgress: Double {
            guard totalCount > 0 else { return 0 }
            return Double(syncedCount) / Double(totalCount)
        }
        
        var hasErrors: Bool {
            return errorCount > 0
        }
    }
    
    struct EntityPerformance {
        let entityType: String
        let avgDuration: Double
        let relativePerformance: Double
        let status: String
        
        var statusColor: Color {
            switch status {
            case "Excellent": return .green
            case "Good": return .blue
            case "Average": return .orange
            case "Poor": return .red
            default: return .gray
            }
        }
    }
    
    struct RecentSyncOperation {
        let id = UUID()
        let type: String
        let timestamp: Date
        let duration: Double
        let entityCount: Int
        let success: Bool
    }
    
    struct QueueOperation {
        let id = UUID()
        let type: String
        let entityType: String
        let status: String
        let timestamp: Date
        let error: String?
        
        var statusColor: Color {
            switch status {
            case "Pending": return .orange
            case "In Progress": return .blue
            case "Completed": return .green
            case "Failed": return .red
            default: return .gray
            }
        }
    }
    
    func loadData() {
        loadSyncStatus()
        loadEntityStats()
        loadLogs()
        loadPerformanceData()
        loadQueueData()
    }
    
    private func loadSyncStatus() {
        // Simuliere Laden des aktuellen Sync-Status
        // In echter Implementierung würde hier der SyncManager abgefragt
        
        // Zufällige Status für Demo
        let statuses = ["Synchronisiert", "Wird synchronisiert...", "Offline", "Fehler"]
        currentSyncStatus = statuses.randomElement() ?? "Idle"
        
        // Netzwerk-Status simulieren
        networkStatus = ["Online", "Offline", "Schwach"].randomElement() ?? "Offline"
        
        // Letzte Sync-Zeit simulieren
        let randomMinutes = Int.random(in: 1...120)
        lastSyncTime = "Vor \(randomMinutes) Minuten"
        
        // Pending Entities simulieren
        pendingEntitiesCount = Int.random(in: 0...25)
        
        // Konflikte simulieren
        conflictCount = Int.random(in: 0...3)
    }
    
    private func loadEntityStats() {
        entityStats = [
            EntitySyncStat(
                entityType: "TagCategories",
                totalCount: 8,
                syncedCount: 8,
                errorCount: 0
            ),
            EntitySyncStat(
                entityType: "Tags",
                totalCount: 45,
                syncedCount: 43,
                errorCount: 1
            ),
            EntitySyncStat(
                entityType: "Trips",
                totalCount: 15,
                syncedCount: 15,
                errorCount: 0
            ),
            EntitySyncStat(
                entityType: "Memories",
                totalCount: 234,
                syncedCount: 220,
                errorCount: 2
            ),
            EntitySyncStat(
                entityType: "MediaItems",
                totalCount: 567,
                syncedCount: 445,
                errorCount: 5
            ),
            EntitySyncStat(
                entityType: "GPXTracks",
                totalCount: 23,
                syncedCount: 23,
                errorCount: 0
            )
        ]
    }
    
    func loadLogs() {
        // Lade Logs vom SyncLogger
        let allLogs = SyncLogger.shared.getRecentLogs(count: 100)
        
        if let selectedLevel = selectedLogLevel {
            filteredLogs = allLogs.filter { $0.level == selectedLevel }
        } else {
            filteredLogs = allLogs
        }
        
        // Falls keine echten Logs vorhanden sind, erstelle Demo-Logs
        if filteredLogs.isEmpty {
            createDemoLogs()
        }
    }
    
    private func createDemoLogs() {
        let demoMessages = [
            "Sync-Zyklus gestartet",
            "Upload-Phase: 15 Entitäten verarbeitet",
            "Download-Phase: 8 neue Entitäten empfangen",
            "Konflikt erkannt bei Memory: 'Sonnenuntergang am Strand'",
            "Konflikt gelöst: Remote-Version gewählt",
            "Datei-Upload: IMG_1234.jpg erfolgreich",
            "GPX-Track synchronisiert: track_20240110.gpx",
            "Sync-Zyklus abgeschlossen",
        ]
        
        let categories = ["Sync", "Upload", "Download", "Conflict", "File", "Error"]
        let levels: [SyncLogger.LogLevel] = [.info, .debug, .warning, .error]
        
        var tempLogs: [SyncLogger.LogEntry] = []
        for index in 0..<20 {
            let timestamp = Date().addingTimeInterval(-Double(index * 300))
            let level = levels.randomElement() ?? .info
            let category = categories.randomElement() ?? "Sync"
            let message = demoMessages.randomElement() ?? "Demo-Log-Eintrag \(index)"
            let metadata: [String: String] = index % 3 == 0 ? 
                ["entityId": "demo-\(index)", "duration": "\(Double.random(in: 0.1...5.0))s"] : [:]
            
            let logEntry = SyncLogger.LogEntry(
                id: UUID(),
                timestamp: timestamp,
                level: level,
                category: category,
                message: message,
                metadata: metadata,
                stackTrace: nil,
                threadName: "demo-thread",
                memoryUsage: UInt64.random(in: 1024...1048576)
            )
            tempLogs.append(logEntry)
        }
        filteredLogs = tempLogs
        
        // Filtere nach ausgewähltem Level
        if let selectedLevel = selectedLogLevel {
            filteredLogs = filteredLogs.filter { $0.level == selectedLevel }
        }
    }
    
    func loadPerformanceData() {
        // Performance-Metriken simulieren
        averageSyncTime = String(format: "%.1f", Double.random(in: 2.0...15.0))
        successRate = Double.random(in: 0.85...1.0)
        throughput = Double.random(in: 10.0...50.0)
        
        let bytes = Int64.random(in: 1024...10_000_000)
        formattedNetworkBytes = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        
        // Entitäten-Performance
        entityPerformance = [
            EntityPerformance(
                entityType: "Trips",
                avgDuration: Double.random(in: 0.5...2.0),
                relativePerformance: Double.random(in: 0.7...1.0),
                status: "Excellent"
            ),
            EntityPerformance(
                entityType: "Memories",
                avgDuration: Double.random(in: 1.0...4.0),
                relativePerformance: Double.random(in: 0.6...0.9),
                status: "Good"
            ),
            EntityPerformance(
                entityType: "MediaItems",
                avgDuration: Double.random(in: 2.0...8.0),
                relativePerformance: Double.random(in: 0.4...0.8),
                status: "Average"
            ),
            EntityPerformance(
                entityType: "GPXTracks",
                avgDuration: Double.random(in: 1.5...5.0),
                relativePerformance: Double.random(in: 0.5...0.9),
                status: "Good"
            )
        ]
        
        // Letzte Sync-Operationen
        let operationTypes = ["Full Sync", "Incremental Sync", "File Upload", "File Download", "Conflict Resolution"]
        recentSyncOperations = (0..<8).map { index in
            RecentSyncOperation(
                type: operationTypes.randomElement() ?? "Sync",
                timestamp: Date().addingTimeInterval(-Double(index * 600)), // 10 Minuten Abstand
                duration: Double.random(in: 1.0...30.0),
                entityCount: Int.random(in: 1...50),
                success: Double.random(in: 0...1) > 0.1 // 90% Erfolgsrate
            )
        }
    }
    
    func loadQueueData() {
        // Queue-Status simulieren
        pendingUploads = Int.random(in: 0...15)
        pendingDownloads = Int.random(in: 0...8)
        failedOperations = Int.random(in: 0...3)
        
        // Queue-Operationen
        let operationTypes = ["CREATE", "UPDATE", "DELETE", "FILE_UPLOAD", "FILE_DOWNLOAD"]
        let entityTypes = ["Trip", "Memory", "MediaItem", "GPXTrack", "Tag"]
        let statuses = ["Pending", "In Progress", "Completed", "Failed"]
        
        queueOperations = (0..<12).map { index in
            let status = statuses.randomElement() ?? "Pending"
            return QueueOperation(
                type: operationTypes.randomElement() ?? "UPDATE",
                entityType: entityTypes.randomElement() ?? "Memory",
                status: status,
                timestamp: Date().addingTimeInterval(-Double(index * 120)), // 2 Minuten Abstand
                error: status == "Failed" ? "Network timeout after 30 seconds" : nil
            )
        }
    }
    
    func exportLogs() -> String {
        var exportText = "=== SYNC DEBUG LOGS EXPORT ===\n"
        exportText += "Exportiert am: \(Date().formatted())\n"
        exportText += "Log-Level Filter: \(selectedLogLevel?.rawValue ?? "Alle")\n"
        exportText += "Anzahl Logs: \(filteredLogs.count)\n\n"
        
        for log in filteredLogs {
            exportText += "\(log.formattedMessage)\n"
            if !log.metadata.isEmpty {
                exportText += "  Metadata: \(log.metadata)\n"
            }
            exportText += "\n"
        }
        
        return exportText
    }
} 