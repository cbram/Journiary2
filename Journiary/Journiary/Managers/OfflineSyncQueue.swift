import Foundation
import CoreData

/// Erweiterte Offline-Sync-Warteschlange für zuverlässige Synchronisation
/// Speichert und verwaltet Synchronisationsaufträge während Offline-Zeiten
class OfflineSyncQueue {
    
    // MARK: - Types
    
    /// Typen von Synchronisationsoperationen
    enum SyncOperationType: String, CaseIterable {
        case create = "CREATE"
        case update = "UPDATE"
        case delete = "DELETE"
        case fileUpload = "FILE_UPLOAD"
        case fileDownload = "FILE_DOWNLOAD"
        
        var displayName: String {
            switch self {
            case .create: return "Erstellen"
            case .update: return "Aktualisieren"
            case .delete: return "Löschen"
            case .fileUpload: return "Datei-Upload"
            case .fileDownload: return "Datei-Download"
            }
        }
    }
    
    /// Priorität eines Synchronisationsauftrags
    enum SyncPriority: Int, CaseIterable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3
        
        var displayName: String {
            switch self {
            case .low: return "Niedrig"
            case .normal: return "Normal"
            case .high: return "Hoch"
            case .critical: return "Kritisch"
            }
        }
    }
    
    /// Status eines Synchronisationsauftrags
    enum SyncStatus: String, CaseIterable {
        case pending = "PENDING"
        case inProgress = "IN_PROGRESS"
        case completed = "COMPLETED"
        case failed = "FAILED"
        case cancelled = "CANCELLED"
        
        var displayName: String {
            switch self {
            case .pending: return "Ausstehend"
            case .inProgress: return "In Bearbeitung"
            case .completed: return "Abgeschlossen"
            case .failed: return "Fehlgeschlagen"
            case .cancelled: return "Abgebrochen"
            }
        }
    }
    
    /// Synchronisationsauftrag
    struct SyncTask {
        let id: UUID
        let entityType: String
        let entityId: String
        let operation: SyncOperationType
        let priority: SyncPriority
        let data: [String: Any]
        let createdAt: Date
        let retryCount: Int
        let maxRetries: Int
        let status: SyncStatus
        let lastError: String?
        
        init(entityType: String, entityId: String, operation: SyncOperationType,
             priority: SyncPriority = .normal, data: [String: Any] = [:],
             maxRetries: Int = 3) {
            self.id = UUID()
            self.entityType = entityType
            self.entityId = entityId
            self.operation = operation
            self.priority = priority
            self.data = data
            self.createdAt = Date()
            self.retryCount = 0
            self.maxRetries = maxRetries
            self.status = .pending
            self.lastError = nil
        }
        
        /// Erstellt eine neue Instanz mit aktualisiertem Status
        func withStatus(_ newStatus: SyncStatus, error: String? = nil) -> SyncTask {
            return SyncTask(
                id: self.id,
                entityType: self.entityType,
                entityId: self.entityId,
                operation: self.operation,
                priority: self.priority,
                data: self.data,
                createdAt: self.createdAt,
                retryCount: self.retryCount,
                maxRetries: self.maxRetries,
                status: newStatus,
                lastError: error
            )
        }
        
        /// Erstellt eine neue Instanz mit erhöhtem Retry-Zähler
        func withRetry(error: String? = nil) -> SyncTask {
            return SyncTask(
                id: self.id,
                entityType: self.entityType,
                entityId: self.entityId,
                operation: self.operation,
                priority: self.priority,
                data: self.data,
                createdAt: self.createdAt,
                retryCount: self.retryCount + 1,
                maxRetries: self.maxRetries,
                status: .pending,
                lastError: error
            )
        }
        
        /// Prüft, ob weitere Retry-Versuche möglich sind
        var canRetry: Bool {
            return retryCount < maxRetries
        }
        
        fileprivate init(id: UUID, entityType: String, entityId: String, operation: SyncOperationType,
                     priority: SyncPriority, data: [String: Any], createdAt: Date,
                     retryCount: Int, maxRetries: Int, status: SyncStatus, lastError: String?) {
            self.id = id
            self.entityType = entityType
            self.entityId = entityId
            self.operation = operation
            self.priority = priority
            self.data = data
            self.createdAt = createdAt
            self.retryCount = retryCount
            self.maxRetries = maxRetries
            self.status = status
            self.lastError = lastError
        }
    }
    
    // MARK: - Properties
    
    /// Warteschlange für Synchronisationsaufträge
    private var queue: [SyncTask] = []
    
    /// Queue für Thread-sichere Operationen
    private let queueLock = NSLock()
    
    /// Persistenter Speicher für die Warteschlange
    private let persistentStorage = UserDefaults.standard
    private let storageKey = "OfflineSyncQueue"
    
    /// Maximale Anzahl von Aufträgen in der Warteschlange
    private let maxQueueSize = 1000
    
    /// Singleton-Instanz
    static let shared = OfflineSyncQueue()
    
    /// Aktuelle Anzahl der Aufträge in der Warteschlange
    var queueCount: Int {
        queueLock.lock()
        defer { queueLock.unlock() }
        return queue.count
    }
    
    /// Anzahl der ausstehenden Aufträge
    var pendingCount: Int {
        queueLock.lock()
        defer { queueLock.unlock() }
        return queue.filter { $0.status == .pending }.count
    }
    
    /// Anzahl der fehlgeschlagenen Aufträge
    var failedCount: Int {
        queueLock.lock()
        defer { queueLock.unlock() }
        return queue.filter { $0.status == .failed }.count
    }
    
    // MARK: - Initialization
    
    private init() {
        loadFromPersistentStorage()
    }
    
    // MARK: - Public Methods
    
    /// Fügt einen neuen Synchronisationsauftrag zur Warteschlange hinzu
    /// - Parameters:
    ///   - entityType: Typ der Entität (z.B. "Trip", "Memory", "MediaItem")
    ///   - entityId: ID der Entität
    ///   - operation: Art der Synchronisation
    ///   - priority: Priorität des Auftrags
    ///   - data: Zusätzliche Daten für die Synchronisation
    ///   - maxRetries: Maximale Anzahl von Wiederholungsversuchen
    /// - Returns: true, wenn der Auftrag erfolgreich hinzugefügt wurde
    func enqueue(entityType: String, entityId: String, operation: SyncOperationType,
                 priority: SyncPriority = .normal, data: [String: Any] = [:],
                 maxRetries: Int = 3) -> Bool {
        
        queueLock.lock()
        defer { queueLock.unlock() }
        
        // Prüfe Queue-Größe
        if queue.count >= maxQueueSize {
            print("❌ Offline-Sync-Queue ist voll (max: \(maxQueueSize))")
            return false
        }
        
        // Erstelle neuen Auftrag
        let task = SyncTask(
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            priority: priority,
            data: data,
            maxRetries: maxRetries
        )
        
        // Entferne eventuell vorhandene doppelte Aufträge
        queue.removeAll { $0.entityType == entityType && $0.entityId == entityId && $0.operation == operation }
        
        // Füge neuen Auftrag hinzu
        queue.append(task)
        
        // Sortiere Queue nach Priorität und Erstellungsdatum
        sortQueue()
        
        // Speichere persistent
        saveToPersistentStorage()
        
        print("📥 Sync-Auftrag hinzugefügt: \(operation.displayName) \(entityType) \(entityId)")
        return true
    }
    
    /// Holt den nächsten Auftrag aus der Warteschlange
    /// - Returns: Der nächste auszuführende Auftrag oder nil, wenn keine Aufträge vorhanden sind
    func dequeue() -> SyncTask? {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        // Finde den nächsten ausstehenden Auftrag mit höchster Priorität
        guard let index = queue.firstIndex(where: { $0.status == .pending }) else {
            return nil
        }
        
        let task = queue[index]
        
        // Markiere Auftrag als "in Bearbeitung"
        queue[index] = task.withStatus(.inProgress)
        
        // Speichere persistent
        saveToPersistentStorage()
        
        print("📤 Sync-Auftrag dequeued: \(task.operation.displayName) \(task.entityType) \(task.entityId)")
        return queue[index]
    }
    
    /// Markiert einen Auftrag als erfolgreich abgeschlossen
    /// - Parameter taskId: ID des Auftrags
    /// - Returns: true, wenn der Auftrag erfolgreich markiert wurde
    func markCompleted(taskId: UUID) -> Bool {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        guard let index = queue.firstIndex(where: { $0.id == taskId }) else {
            return false
        }
        
        let task = queue[index]
        queue[index] = task.withStatus(.completed)
        
        // Speichere persistent
        saveToPersistentStorage()
        
        print("✅ Sync-Auftrag abgeschlossen: \(task.operation.displayName) \(task.entityType) \(task.entityId)")
        return true
    }
    
    /// Markiert einen Auftrag als fehlgeschlagen und plant ggf. Wiederholung
    /// - Parameters:
    ///   - taskId: ID des Auftrags
    ///   - error: Fehlermeldung
    /// - Returns: true, wenn der Auftrag erfolgreich markiert wurde
    func markFailed(taskId: UUID, error: String) -> Bool {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        guard let index = queue.firstIndex(where: { $0.id == taskId }) else {
            return false
        }
        
        let task = queue[index]
        
        if task.canRetry {
            // Plane Wiederholung
            queue[index] = task.withRetry(error: error)
            print("🔄 Sync-Auftrag für Wiederholung geplant: \(task.operation.displayName) \(task.entityType) \(task.entityId) (Versuch \(task.retryCount + 1)/\(task.maxRetries))")
        } else {
            // Markiere als endgültig fehlgeschlagen
            queue[index] = task.withStatus(.failed, error: error)
            print("❌ Sync-Auftrag endgültig fehlgeschlagen: \(task.operation.displayName) \(task.entityType) \(task.entityId)")
        }
        
        // Speichere persistent
        saveToPersistentStorage()
        
        return true
    }
    
    /// Bricht einen Auftrag ab
    /// - Parameter taskId: ID des Auftrags
    /// - Returns: true, wenn der Auftrag erfolgreich abgebrochen wurde
    func cancelTask(taskId: UUID) -> Bool {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        guard let index = queue.firstIndex(where: { $0.id == taskId }) else {
            return false
        }
        
        let task = queue[index]
        queue[index] = task.withStatus(.cancelled)
        
        // Speichere persistent
        saveToPersistentStorage()
        
        print("🚫 Sync-Auftrag abgebrochen: \(task.operation.displayName) \(task.entityType) \(task.entityId)")
        return true
    }
    
    /// Entfernt alle abgeschlossenen, fehlgeschlagenen und abgebrochenen Aufträge
    /// - Returns: Anzahl der entfernten Aufträge
    func cleanupCompleted() -> Int {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        let initialCount = queue.count
        queue.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
        
        let removedCount = initialCount - queue.count
        
        if removedCount > 0 {
            // Speichere persistent
            saveToPersistentStorage()
            print("🧹 \(removedCount) abgeschlossene Sync-Aufträge entfernt")
        }
        
        return removedCount
    }
    
    /// Gibt alle Aufträge für eine bestimmte Entität zurück
    /// - Parameters:
    ///   - entityType: Typ der Entität
    ///   - entityId: ID der Entität
    /// - Returns: Array von Aufträgen für diese Entität
    func getTasks(for entityType: String, entityId: String) -> [SyncTask] {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        return queue.filter { $0.entityType == entityType && $0.entityId == entityId }
    }
    
    /// Gibt alle Aufträge mit einem bestimmten Status zurück
    /// - Parameter status: Gewünschter Status
    /// - Returns: Array von Aufträgen mit diesem Status
    func getTasks(withStatus status: SyncStatus) -> [SyncTask] {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        return queue.filter { $0.status == status }
    }
    
    /// Gibt eine Zusammenfassung der Warteschlange zurück
    var queueSummary: String {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        let statusCounts = Dictionary(grouping: queue) { $0.status }
            .mapValues { $0.count }
        
        let priorityCounts = Dictionary(grouping: queue.filter { $0.status == .pending }) { $0.priority }
            .mapValues { $0.count }
        
        return """
        Offline-Sync-Queue Zusammenfassung:
        - Gesamt: \(queue.count) Aufträge
        - Ausstehend: \(statusCounts[.pending] ?? 0)
        - In Bearbeitung: \(statusCounts[.inProgress] ?? 0)
        - Abgeschlossen: \(statusCounts[.completed] ?? 0)
        - Fehlgeschlagen: \(statusCounts[.failed] ?? 0)
        - Abgebrochen: \(statusCounts[.cancelled] ?? 0)
        
        Prioritäten (ausstehend):
        - Kritisch: \(priorityCounts[.critical] ?? 0)
        - Hoch: \(priorityCounts[.high] ?? 0)
        - Normal: \(priorityCounts[.normal] ?? 0)
        - Niedrig: \(priorityCounts[.low] ?? 0)
        """
    }
    
    // MARK: - Private Methods
    
    /// Sortiert die Warteschlange nach Priorität und Erstellungsdatum
    private func sortQueue() {
        queue.sort { task1, task2 in
            // Erst nach Status sortieren (pending zuerst)
            if task1.status != task2.status {
                return task1.status == .pending && task2.status != .pending
            }
            
            // Dann nach Priorität sortieren (höhere Priorität zuerst)
            if task1.priority != task2.priority {
                return task1.priority.rawValue > task2.priority.rawValue
            }
            
            // Schließlich nach Erstellungsdatum sortieren (älter zuerst)
            return task1.createdAt < task2.createdAt
        }
    }
    
    /// Speichert die Warteschlange persistent
    private func saveToPersistentStorage() {
        do {
            let data = try JSONSerialization.data(withJSONObject: serializeQueue(), options: [])
            persistentStorage.set(data, forKey: storageKey)
        } catch {
            print("❌ Fehler beim Speichern der Sync-Queue: \(error)")
        }
    }
    
    /// Lädt die Warteschlange aus dem persistenten Speicher
    private func loadFromPersistentStorage() {
        guard let data = persistentStorage.data(forKey: storageKey) else {
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            queue = deserializeQueue(from: json)
            sortQueue()
            print("📂 \(queue.count) Sync-Aufträge aus persistentem Speicher geladen")
        } catch {
            print("❌ Fehler beim Laden der Sync-Queue: \(error)")
        }
    }
    
    /// Serialisiert die Warteschlange für die persistente Speicherung
    private func serializeQueue() -> [[String: Any]] {
        return queue.map { task in
            [
                "id": task.id.uuidString,
                "entityType": task.entityType,
                "entityId": task.entityId,
                "operation": task.operation.rawValue,
                "priority": task.priority.rawValue,
                "data": task.data,
                "createdAt": task.createdAt.timeIntervalSince1970,
                "retryCount": task.retryCount,
                "maxRetries": task.maxRetries,
                "status": task.status.rawValue,
                "lastError": task.lastError ?? NSNull()
            ]
        }
    }
    
    /// Deserialisiert die Warteschlange aus dem persistenten Speicher
    private func deserializeQueue(from json: Any) -> [SyncTask] {
        guard let array = json as? [[String: Any]] else {
            return []
        }
        
        return array.compactMap { dict in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let entityType = dict["entityType"] as? String,
                  let entityId = dict["entityId"] as? String,
                  let operationRaw = dict["operation"] as? String,
                  let operation = SyncOperationType(rawValue: operationRaw),
                  let priorityRaw = dict["priority"] as? Int,
                  let priority = SyncPriority(rawValue: priorityRaw),
                  let data = dict["data"] as? [String: Any],
                  let createdAtTimestamp = dict["createdAt"] as? TimeInterval,
                  let retryCount = dict["retryCount"] as? Int,
                  let maxRetries = dict["maxRetries"] as? Int,
                  let statusRaw = dict["status"] as? String,
                  let status = SyncStatus(rawValue: statusRaw) else {
                return nil
            }
            
            let createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
            let lastError = dict["lastError"] as? String
            
            return SyncTask(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                priority: priority,
                data: data,
                createdAt: createdAt,
                retryCount: retryCount,
                maxRetries: maxRetries,
                status: status,
                lastError: lastError
            )
        }
    }
} 