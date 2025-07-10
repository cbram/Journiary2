import Foundation

/// Prioritäts-Struktur für Datei-Synchronisation
/// Definiert die Priorität einer Datei basierend auf Typ, Größe und Alter
struct FileSyncPriority {
    let entityId: String
    let entityType: String
    let priority: Int
    let fileSize: Int64?
    let createdAt: Date?
    
    /// Initialisiert eine neue FileSyncPriority-Instanz
    /// - Parameters:
    ///   - entityId: Die ID der Entität (serverId)
    ///   - entityType: Der Typ der Entität (MediaItem, GPXTrack, etc.)
    ///   - fileSize: Die Dateigröße in Bytes (optional)
    ///   - createdAt: Das Erstellungsdatum (optional)
    init(entityId: String, entityType: String, fileSize: Int64? = nil, createdAt: Date? = nil) {
        self.entityId = entityId
        self.entityType = entityType
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.priority = Self.calculatePriority(entityType: entityType, fileSize: fileSize, createdAt: createdAt)
    }
    
    /// Berechnet die Priorität basierend auf verschiedenen Faktoren
    /// - Parameters:
    ///   - entityType: Der Typ der Entität
    ///   - fileSize: Die Dateigröße (optional)
    ///   - createdAt: Das Erstellungsdatum (optional)
    /// - Returns: Die berechnete Priorität (höhere Zahlen = höhere Priorität)
    private static func calculatePriority(entityType: String, fileSize: Int64?, createdAt: Date?) -> Int {
        var priority = 0
        
        // Basis-Priorität nach Typ
        switch entityType {
        case "MediaItem":
            priority += 100
        case "GPXTrack":
            priority += 50
        default:
            priority += 10
        }
        
        // Größe berücksichtigen (kleinere Dateien zuerst)
        if let size = fileSize {
            if size < 1_000_000 { // < 1MB
                priority += 50
            } else if size < 10_000_000 { // < 10MB
                priority += 20
            }
        }
        
        // Neuheit berücksichtigen
        if let created = createdAt {
            let daysSinceCreation = Date().timeIntervalSince(created) / (24 * 60 * 60)
            if daysSinceCreation < 1 {
                priority += 30
            } else if daysSinceCreation < 7 {
                priority += 10
            }
        }
        
        return priority
    }
}

/// Manager für die Priorisierung von Datei-Synchronisations-Aufgaben
/// Sortiert Datei-Tasks nach Priorität für optimale Sync-Performance
class FileSyncPriorityManager {
    
    // MARK: - Public Methods
    
    /// Priorisiert eine Liste von Datei-Tasks nach ihrer Priorität
    /// - Parameter tasks: Array von FileSyncPriority-Objekten
    /// - Returns: Nach Priorität sortiertes Array (höchste Priorität zuerst)
    func prioritizeFileTasks(_ tasks: [FileSyncPriority]) -> [FileSyncPriority] {
        return tasks.sorted { $0.priority > $1.priority }
    }
    
    /// Erstellt FileSyncPriority-Objekte aus Media-Entitäten
    /// - Parameter mediaItems: Array von MediaItem-Objekten
    /// - Returns: Array von FileSyncPriority-Objekten
    func createPrioritiesForMediaItems(_ mediaItems: [MediaItem]) -> [FileSyncPriority] {
        return mediaItems.compactMap { mediaItem -> FileSyncPriority? in
            guard let serverId = mediaItem.serverId else { return nil }
            
            return FileSyncPriority(
                entityId: serverId,
                entityType: "MediaItem",
                fileSize: mediaItem.filesize,
                createdAt: mediaItem.createdAt
            )
        }
    }
    
    /// Erstellt FileSyncPriority-Objekte aus GPX-Track-Entitäten
    /// - Parameter gpxTracks: Array von GPXTrack-Objekten
    /// - Returns: Array von FileSyncPriority-Objekten
    func createPrioritiesForGPXTracks(_ gpxTracks: [GPXTrack]) -> [FileSyncPriority] {
        return gpxTracks.compactMap { gpxTrack -> FileSyncPriority? in
            guard let serverId = gpxTrack.serverId else { return nil }
            
            return FileSyncPriority(
                entityId: serverId,
                entityType: "GPXTrack",
                fileSize: nil, // GPX-Dateien sind normalerweise klein
                createdAt: gpxTrack.createdAt
            )
        }
    }
    
    /// Filtert Tasks nach Prioritäts-Schwellenwerten
    /// - Parameters:
    ///   - tasks: Array von FileSyncPriority-Objekten
    ///   - minimumPriority: Mindestpriorität für die Filterung
    /// - Returns: Gefilterte Tasks oberhalb der Mindestpriorität
    func filterByMinimumPriority(_ tasks: [FileSyncPriority], minimumPriority: Int) -> [FileSyncPriority] {
        return tasks.filter { $0.priority >= minimumPriority }
    }
    
    /// Gruppiert Tasks nach Prioritätskategorien
    /// - Parameter tasks: Array von FileSyncPriority-Objekten
    /// - Returns: Dictionary mit Prioritätskategorien als Keys
    func groupByPriorityCategory(_ tasks: [FileSyncPriority]) -> [PriorityCategory: [FileSyncPriority]] {
        var grouped: [PriorityCategory: [FileSyncPriority]] = [:]
        
        for task in tasks {
            let category = PriorityCategory.from(priority: task.priority)
            if grouped[category] == nil {
                grouped[category] = []
            }
            grouped[category]?.append(task)
        }
        
        return grouped
    }
}

// MARK: - Supporting Types

/// Prioritätskategorien für die Gruppierung
enum PriorityCategory: String, CaseIterable {
    case high = "high"      // Priorität >= 150
    case medium = "medium"  // Priorität 100-149
    case low = "low"        // Priorität < 100
    
    /// Bestimmt die Kategorie basierend auf der Prioritätszahl
    /// - Parameter priority: Die Prioritätszahl
    /// - Returns: Die entsprechende PriorityCategory
    static func from(priority: Int) -> PriorityCategory {
        if priority >= 150 {
            return .high
        } else if priority >= 100 {
            return .medium
        } else {
            return .low
        }
    }
    
    /// Lokalisierter Anzeigename für die Kategorie
    var displayName: String {
        switch self {
        case .high: return "Hohe Priorität"
        case .medium: return "Mittlere Priorität"
        case .low: return "Niedrige Priorität"
        }
    }
} 