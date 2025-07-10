# Kleinschrittiger Synchronisations-Implementierungsplan

## Projektziel
Implementierung einer robusten, vollständigen Synchronisation aller Journiary-Daten zwischen iOS-Geräten mit **compile-sicheren Einzelschritten**.

## Grundprinzipien
- **Atomare Schritte**: Jeder Schritt ist in max. 2 Stunden umsetzbar
- **Compile-Tests**: Nach jedem Schritt MUSS das Projekt kompilieren
- **Rollback-fähig**: Jeder Schritt kann rückgängig gemacht werden
- **Validierung**: Explizite Erfolgs-/Fehlschlag-Kriterien

---

## Phase 1: Vorbereitende Maßnahmen (Woche 1)

### Schritt 1.1: Sync-Status-Enum erweitern (30 min)
**Ziel**: Erweitere bestehende SyncStatus um detailliertere Zustände

#### Implementierung:
```swift
// In Journiary/Journiary/Managers/SyncManager.swift
@objc
public enum DetailedSyncStatus: Int16, CaseIterable {
    case inSync = 0
    case needsUpload = 1
    case needsDownload = 2
    case uploading = 3
    case downloading = 4
    case syncError = 5
    case filesPending = 6
    
    var displayName: String {
        switch self {
        case .inSync: return "Synchronisiert"
        case .needsUpload: return "Upload ausstehend"
        case .needsDownload: return "Download ausstehend"
        case .uploading: return "Wird hochgeladen..."
        case .downloading: return "Wird heruntergeladen..."
        case .syncError: return "Sync-Fehler"
        case .filesPending: return "Dateien ausstehend"
        }
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Enum-Werte sind verfügbar, displayName funktioniert

---

### Schritt 1.2: Fehlerbehandlung erweitern (45 min)
**Ziel**: Erweitere SyncError um spezifische Fehlertypen

#### Implementierung:
```swift
// In Journiary/Journiary/Managers/SyncManager.swift - erweitere SyncError
enum SyncError: Error, LocalizedError {
    case invalidServerTimestamp
    case networkError(Error)
    case dataError(String)
    case authenticationError
    case dependencyNotMet(entity: String, dependency: String)
    case consistencyValidationFailed([String])
    case transactionFailed(Error)
    case maxRetriesExceeded
    case noUploadUrlGenerated
    
    var errorDescription: String? {
        switch self {
        case .invalidServerTimestamp:
            return "Server-Zeitstempel ist ungültig"
        case .networkError(let error):
            return "Netzwerkfehler: \(error.localizedDescription)"
        case .dataError(let message):
            return "Datenfehler: \(message)"
        case .authenticationError:
            return "Authentifizierungsfehler"
        case .dependencyNotMet(let entity, let dependency):
            return "Abhängigkeit fehlt: \(entity) benötigt \(dependency)"
        case .consistencyValidationFailed(let issues):
            return "Konsistenzfehler: \(issues.joined(separator: ", "))"
        case .transactionFailed(let error):
            return "Transaktionsfehler: \(error.localizedDescription)"
        case .maxRetriesExceeded:
            return "Maximale Wiederholungsversuche erreicht"
        case .noUploadUrlGenerated:
            return "Keine Upload-URL generiert"
        }
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Neue Fehlertypen sind verfügbar

---

### Schritt 1.3: Basis-Protokoll für erweiterte Synchronisation (60 min)
**Ziel**: Definiere Protokoll für erweiterte Synchronisations-Features

#### Implementierung:
```swift
// Neue Datei: Journiary/Journiary/Managers/EnhancedSyncProtocols.swift
import Foundation
import CoreData

protocol EnhancedSynchronizable: AnyObject {
    var serverId: String? { get set }
    var syncStatus: DetailedSyncStatus { get set }
    var createdAt: Date? { get set }
    var updatedAt: Date? { get set }
    var lastSyncAttempt: Date? { get set }
    var syncErrorMessage: String? { get set }
    
    func validateForSync() throws
    func toGraphQLInput() -> Any
}

protocol SyncValidator {
    func validate<T: EnhancedSynchronizable>(_ entity: T) throws
}

protocol SyncTransactionProvider {
    func performTransaction<T>(_ operation: @escaping () throws -> T) throws -> T
}

// Basis-Implementierung
class DefaultSyncValidator: SyncValidator {
    func validate<T: EnhancedSynchronizable>(_ entity: T) throws {
        // Basis-Validierung
        if let serverId = entity.serverId, serverId.isEmpty {
            throw SyncError.dataError("Server-ID ist leer")
        }
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Protokolle sind definiert, Basis-Implementierung funktioniert

---

### Schritt 1.4: Logging-System erweitern (45 min)
**Ziel**: Erweitere bestehende Logging-Funktionen

#### Implementierung:
```swift
// In Journiary/Journiary/Managers/SyncManager.swift - erweitere um Logging
import os.log

extension SyncManager {
    private static let logger = Logger(subsystem: "com.journiary.sync", category: "SyncManager")
    
    private func logSyncStart(reason: String) {
        Self.logger.info("🔄 Sync gestartet: \(reason)")
        print("🔄 Sync gestartet: \(reason)")
    }
    
    private func logSyncSuccess(reason: String, duration: TimeInterval) {
        Self.logger.info("✅ Sync erfolgreich: \(reason) (\(duration)s)")
        print("✅ Sync erfolgreich: \(reason) (\(duration)s)")
    }
    
    private func logSyncError(reason: String, error: Error) {
        Self.logger.error("❌ Sync fehlgeschlagen: \(reason) - \(error.localizedDescription)")
        print("❌ Sync fehlgeschlagen: \(reason) - \(error.localizedDescription)")
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Logging-Funktionen sind verfügbar

---

## Phase 2: Dependency-System (Woche 2)

### Schritt 2.1: Entity-Dependency-Mapping (60 min)
**Ziel**: Definiere Abhängigkeitsstruktur ohne bestehende Funktionalität zu ändern

#### Implementierung:
```swift
// Neue Datei: Journiary/Journiary/Managers/SyncDependencyResolver.swift
import Foundation

class SyncDependencyResolver {
    enum EntityType: String, CaseIterable {
        case tagCategory = "TagCategory"
        case tag = "Tag"
        case bucketListItem = "BucketListItem"
        case trip = "Trip"
        case memory = "Memory"
        case mediaItem = "MediaItem"
        case gpxTrack = "GPXTrack"
        
        var syncOrder: Int {
            switch self {
            case .tagCategory: return 1
            case .tag: return 2
            case .bucketListItem: return 3
            case .trip: return 4
            case .memory: return 5
            case .mediaItem: return 6
            case .gpxTrack: return 7
            }
        }
        
        var dependencies: [EntityType] {
            switch self {
            case .tagCategory: return []
            case .tag: return [.tagCategory]
            case .bucketListItem: return []
            case .trip: return []
            case .memory: return [.trip]
            case .mediaItem: return [.memory]
            case .gpxTrack: return [.memory]
            }
        }
    }
    
    func resolveSyncOrder() -> [EntityType] {
        return EntityType.allCases.sorted { $0.syncOrder < $1.syncOrder }
    }
    
    func getDependencies(for entityType: EntityType) -> [EntityType] {
        return entityType.dependencies
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Dependency-Resolver ist verfügbar, Sync-Order ist korrekt

---

### Schritt 2.2: Dependency-Validation (45 min)
**Ziel**: Prüfe Abhängigkeiten vor Synchronisation

#### Implementierung:
```swift
// In Journiary/Journiary/Managers/SyncDependencyResolver.swift - erweitern
import CoreData

extension SyncDependencyResolver {
    func validateDependencies(for entityType: EntityType, in context: NSManagedObjectContext) async throws {
        for dependency in entityType.dependencies {
            let hasUnresolvedDependencies = try await checkUnresolvedDependencies(
                type: dependency,
                context: context
            )
            
            if hasUnresolvedDependencies {
                throw SyncError.dependencyNotMet(
                    entity: entityType.rawValue,
                    dependency: dependency.rawValue
                )
            }
        }
    }
    
    private func checkUnresolvedDependencies(type: EntityType, context: NSManagedObjectContext) async throws -> Bool {
        return try await context.perform {
            let fetchRequest = self.createFetchRequest(for: type)
            fetchRequest.predicate = NSPredicate(format: "serverId == nil")
            fetchRequest.fetchLimit = 1
            
            let count = try context.count(for: fetchRequest)
            return count > 0
        }
    }
    
    private func createFetchRequest(for type: EntityType) -> NSFetchRequest<NSManagedObject> {
        return NSFetchRequest<NSManagedObject>(entityName: type.rawValue)
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Dependency-Validation funktioniert

---

### Schritt 2.3: Integration in bestehenden SyncManager (30 min)
**Ziel**: Integriere Dependency-Resolver ohne bestehende Funktionalität zu brechen

#### Implementierung:
```swift
// In Journiary/Journiary/Managers/SyncManager.swift - erweitern
final class SyncManager {
    // ... bestehende Properties
    
    private let dependencyResolver = SyncDependencyResolver()
    
    // Neue Methode für dependency-aware Upload (erstmal nur logging)
    private func uploadPhaseWithDependencies() async throws {
        print("📋 Dependency-aware Upload wird vorbereitet...")
        
        let syncOrder = dependencyResolver.resolveSyncOrder()
        for entityType in syncOrder {
            print("  - \(entityType.rawValue) (Order: \(entityType.syncOrder))")
        }
        
        // Rufe bestehende uploadPhase auf
        try await uploadPhase()
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Neue Methode ist verfügbar, bestehende Funktionalität unverändert

---

## Phase 3: Transaktionale Konsistenz (Woche 3)

### Schritt 3.1: Basis-Transaction-Manager (60 min)
**Ziel**: Einfacher Transaction-Manager für Core Data

#### Implementierung:
```swift
// Neue Datei: Journiary/Journiary/Managers/SyncTransactionManager.swift
import Foundation
import CoreData

class SyncTransactionManager {
    private let persistenceController = PersistenceController.shared
    
    func performTransaction<T>(
        operation: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = persistenceController.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return try await context.perform {
            let result = try operation(context)
            
            if context.hasChanges {
                try context.save()
            }
            
            return result
        }
    }
    
    func performTransactionWithRollback<T>(
        operation: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = persistenceController.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return try await context.perform {
            do {
                let result = try operation(context)
                
                if context.hasChanges {
                    try context.save()
                }
                
                return result
            } catch {
                // Rollback bei Fehler
                context.rollback()
                throw error
            }
        }
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Transaction-Manager ist verfügbar

---

### Schritt 3.2: Konsistenz-Validator (45 min)
**Ziel**: Einfache Konsistenz-Prüfungen

#### Implementierung:
```swift
// Neue Datei: Journiary/Journiary/Managers/ConsistencyValidator.swift
import Foundation
import CoreData

class ConsistencyValidator {
    func validateBasicConsistency(context: NSManagedObjectContext) async throws -> [String] {
        var issues: [String] = []
        
        // Prüfe Memory-Trip-Beziehungen
        let memoryIssues = try await validateMemoryTripRelationships(context: context)
        issues.append(contentsOf: memoryIssues)
        
        // Prüfe MediaItem-Memory-Beziehungen
        let mediaIssues = try await validateMediaItemMemoryRelationships(context: context)
        issues.append(contentsOf: mediaIssues)
        
        return issues
    }
    
    private func validateMemoryTripRelationships(context: NSManagedObjectContext) async throws -> [String] {
        return try await context.perform {
            var issues: [String] = []
            
            let memoryRequest = Memory.fetchRequest()
            memoryRequest.predicate = NSPredicate(format: "trip == nil")
            
            let memoriesWithoutTrip = try context.fetch(memoryRequest)
            for memory in memoriesWithoutTrip {
                issues.append("Memory ohne Trip: \(memory.serverId ?? "unknown")")
            }
            
            return issues
        }
    }
    
    private func validateMediaItemMemoryRelationships(context: NSManagedObjectContext) async throws -> [String] {
        return try await context.perform {
            var issues: [String] = []
            
            let mediaRequest = MediaItem.fetchRequest()
            mediaRequest.predicate = NSPredicate(format: "memory == nil")
            
            let mediaWithoutMemory = try context.fetch(mediaRequest)
            for media in mediaWithoutMemory {
                issues.append("MediaItem ohne Memory: \(media.serverId ?? "unknown")")
            }
            
            return issues
        }
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Konsistenz-Validator funktioniert

---

## Phase 4: Erweiterte Datei-Synchronisation (Woche 4)

### Schritt 4.1: File-Sync-Priority-System (45 min)
**Ziel**: Priorisierungs-System für Datei-Synchronisation

#### Implementierung:
```swift
// Neue Datei: Journiary/Journiary/Managers/FileSyncPriorityManager.swift
import Foundation

struct FileSyncPriority {
    let entityId: String
    let entityType: String
    let priority: Int
    let fileSize: Int64?
    let createdAt: Date?
    
    init(entityId: String, entityType: String, fileSize: Int64? = nil, createdAt: Date? = nil) {
        self.entityId = entityId
        self.entityType = entityType
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.priority = Self.calculatePriority(entityType: entityType, fileSize: fileSize, createdAt: createdAt)
    }
    
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

class FileSyncPriorityManager {
    func prioritizeFileTasks(_ tasks: [FileSyncPriority]) -> [FileSyncPriority] {
        return tasks.sorted { $0.priority > $1.priority }
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Priority-System ist verfügbar

---

### Schritt 4.2: Adaptive Batch-Size-Logik (60 min)
**Ziel**: Dynamische Anpassung der Batch-Größen basierend auf Netzwerkbedingungen

#### Implementierung:
```swift
// Neue Datei: Journiary/Journiary/Managers/AdaptiveBatchManager.swift
import Foundation
import Network

class AdaptiveBatchManager {
    enum NetworkQuality {
        case excellent  // WiFi, schnelle Verbindung
        case good      // WiFi, mittlere Verbindung  
        case fair      // 4G/5G mit guter Signalstärke
        case poor      // 3G oder schwache Verbindung
    }
    
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    private var currentNetworkQuality: NetworkQuality = .good
    private var performanceMetrics: [TimeInterval] = []
    
    init() {
        startNetworkMonitoring()
    }
    
    func getOptimalBatchSize(for entityType: String) -> Int {
        let baseBatchSize = getBaseBatchSize(for: entityType)
        return adjustBatchSize(baseBatchSize, for: currentNetworkQuality)
    }
    
    private func getBaseBatchSize(for entityType: String) -> Int {
        switch entityType {
        case "MediaItem": return 5
        case "Memory": return 20
        case "Trip": return 10
        default: return 15
        }
    }
    
    private func adjustBatchSize(_ baseSize: Int, for quality: NetworkQuality) -> Int {
        switch quality {
        case .excellent: return baseSize * 2
        case .good: return baseSize
        case .fair: return max(baseSize / 2, 1)
        case .poor: return 1
        }
    }
    
    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.updateNetworkQuality(for: path)
        }
        pathMonitor.start(queue: monitorQueue)
    }
    
    private func updateNetworkQuality(for path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            currentNetworkQuality = .excellent
        } else if path.usesInterfaceType(.cellular) {
            currentNetworkQuality = .fair
        } else {
            currentNetworkQuality = .poor
        }
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Adaptive Batch-Manager ist verfügbar, Netzwerk-Monitoring funktioniert

---

### Schritt 4.3: Erweiterte Offline-Sync-Warteschlange (90 min)
**Ziel**: Robuste Warteschlange für Offline-Synchronisation mit Persistierung

#### Implementierung:
```swift
// Neue Datei: Journiary/Journiary/Managers/OfflineSyncQueue.swift
import Foundation

class OfflineSyncQueue {
    enum SyncOperationType: String, CaseIterable {
        case create = "CREATE"
        case update = "UPDATE"
        case delete = "DELETE"
        case fileUpload = "FILE_UPLOAD"
        case fileDownload = "FILE_DOWNLOAD"
    }
    
    enum SyncPriority: Int, CaseIterable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3
    }
    
    enum SyncStatus: String, CaseIterable {
        case pending = "PENDING"
        case inProgress = "IN_PROGRESS"
        case completed = "COMPLETED"
        case failed = "FAILED"
        case cancelled = "CANCELLED"
    }
    
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
    }
    
    static let shared = OfflineSyncQueue()
    
    private var queue: [SyncTask] = []
    private let queueLock = NSLock()
    private let persistentStorage = UserDefaults.standard
    private let storageKey = "OfflineSyncQueue"
    
    private init() {
        loadFromPersistentStorage()
    }
    
    func enqueue(entityType: String, entityId: String, operation: SyncOperationType,
                 priority: SyncPriority = .normal, data: [String: Any] = [:]) -> Bool {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        let task = SyncTask(
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            priority: priority,
            data: data
        )
        
        queue.append(task)
        sortQueue()
        saveToPersistentStorage()
        
        return true
    }
    
    func dequeue() -> SyncTask? {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        guard let index = queue.firstIndex(where: { $0.status == .pending }) else {
            return nil
        }
        
        let task = queue[index]
        queue[index] = task.withStatus(.inProgress)
        saveToPersistentStorage()
        
        return queue[index]
    }
    
    private func sortQueue() {
        queue.sort { task1, task2 in
            if task1.priority != task2.priority {
                return task1.priority.rawValue > task2.priority.rawValue
            }
            return task1.createdAt < task2.createdAt
        }
    }
    
    private func saveToPersistentStorage() {
        // JSON-Serialisierung der Queue
    }
    
    private func loadFromPersistentStorage() {
        // JSON-Deserialisierung der Queue
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Offline-Sync-Queue ist verfügbar, Persistierung funktioniert

---

## Phase 5: Optimierung und Performance (Woche 5)

### Schritt 5.1: Performance-Monitoring (45 min)
**Ziel**: System zur Überwachung der Sync-Performance

#### Implementierung:
```swift
// Neue Datei: Journiary/Journiary/Managers/PerformanceMonitor.swift
import Foundation

struct SyncPerformanceMetrics {
    let operation: String
    let duration: TimeInterval
    let entityCount: Int
    let timestamp: Date
    let memoryUsage: UInt64
    let networkBytesTransferred: Int64
    
    var throughput: Double {
        return Double(entityCount) / duration
    }
    
    var bytesPerSecond: Double {
        return Double(networkBytesTransferred) / duration
    }
}

class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private var metrics: [SyncPerformanceMetrics] = []
    private let metricsLock = NSLock()
    
    private init() {}
    
    func startMeasuring(operation: String) -> PerformanceMeasurement {
        return PerformanceMeasurement(operation: operation, monitor: self)
    }
    
    func recordMetrics(_ metrics: SyncPerformanceMetrics) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        self.metrics.append(metrics)
        
        // Behalte nur die letzten 100 Messungen
        if self.metrics.count > 100 {
            self.metrics.removeFirst(self.metrics.count - 100)
        }
        
        logPerformanceMetrics(metrics)
    }
    
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
    
    private func logPerformanceMetrics(_ metrics: SyncPerformanceMetrics) {
        print("📊 Performance: \(metrics.operation) - \(metrics.entityCount) entities in \(String(format: "%.2f", metrics.duration))s (Throughput: \(String(format: "%.1f", metrics.throughput)) entities/s)")
    }
}

class PerformanceMeasurement {
    let operation: String
    let startTime: Date
    let startMemory: UInt64
    private weak var monitor: PerformanceMonitor?
    
    init(operation: String, monitor: PerformanceMonitor) {
        self.operation = operation
        self.startTime = Date()
        self.startMemory = getMemoryUsage()
        self.monitor = monitor
    }
    
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
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Performance-Monitor ist verfügbar, Messungen funktionieren

---

### Schritt 5.2: Memory-Management-Optimierung (60 min)
**Ziel**: Optimierte Speicherverwaltung für große Sync-Operationen

#### Implementierung:
```swift
// In Journiary/Journiary/Managers/SyncManager.swift - erweitern
extension SyncManager {
    private func optimizedBatchUpload<T: NSManagedObject>(
        entities: [T],
        batchSize: Int = 50,
        memoryThreshold: UInt64 = 100_000_000 // 100MB
    ) async throws {
        let measurement = PerformanceMonitor.shared.startMeasuring(operation: "BatchUpload-\(T.self)")
        
        let batches = entities.chunked(into: batchSize)
        var processedCount = 0
        
        for batch in batches {
            // Memory-Check vor jeder Batch
            if getMemoryUsage() > memoryThreshold {
                print("⚠️ Memory-Threshold erreicht, pausiere für Garbage Collection")
                await Task.yield() // Lasse andere Tasks laufen
                
                // Explicit Memory Pressure Relief
                await forceMemoryRelease()
            }
            
            try await uploadBatch(batch)
            processedCount += batch.count
            
            print("📤 Batch hochgeladen: \(processedCount)/\(entities.count)")
        }
        
        measurement.finish(entityCount: entities.count)
    }
    
    private func forceMemoryRelease() async {
        // Background-Context für Memory-intensive Operationen verwenden
        let context = persistenceController.container.newBackgroundContext()
        await context.perform {
            context.reset()
        }
        
        // Explicit Autorelease Pool Drain
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    // Trigger Memory Cleanup
                    Thread.sleep(forTimeInterval: 0.1)
                }
                continuation.resume()
            }
        }
    }
    
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
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Memory-Management funktioniert, Batch-Upload ist optimiert

---

### Schritt 5.3: Cache-Optimierung (45 min)
**Ziel**: Intelligente Caching-Mechanismen für Sync-Daten

#### Implementierung:
```swift
// Neue Datei: Journiary/Journiary/Managers/SyncCacheManager.swift
import Foundation

class SyncCacheManager {
    static let shared = SyncCacheManager()
    
    private let cache = NSCache<NSString, CacheEntry>()
    private let cacheQueue = DispatchQueue(label: "SyncCache", attributes: .concurrent)
    
    private init() {
        setupCache()
    }
    
    private func setupCache() {
        cache.countLimit = 1000 // Max 1000 Einträge
        cache.totalCostLimit = 50 * 1024 * 1024 // Max 50MB
    }
    
    func cacheEntity(_ entity: Any, forKey key: String, ttl: TimeInterval = 300) {
        cacheQueue.async(flags: .barrier) {
            let entry = CacheEntry(data: entity, expirationDate: Date().addingTimeInterval(ttl))
            let cost = self.estimateSize(of: entity)
            self.cache.setObject(entry, forKey: NSString(string: key), cost: cost)
        }
    }
    
    func getCachedEntity<T>(forKey key: String, type: T.Type) -> T? {
        return cacheQueue.sync {
            guard let entry = cache.object(forKey: NSString(string: key)) else {
                return nil
            }
            
            if entry.isExpired {
                cache.removeObject(forKey: NSString(string: key))
                return nil
            }
            
            return entry.data as? T
        }
    }
    
    func invalidateCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAllObjects()
        }
    }
    
    func invalidateExpiredEntries() {
        cacheQueue.async(flags: .barrier) {
            let allKeys = self.getAllCacheKeys()
            
            for key in allKeys {
                if let entry = self.cache.object(forKey: NSString(string: key)),
                   entry.isExpired {
                    self.cache.removeObject(forKey: NSString(string: key))
                }
            }
        }
    }
    
    private func estimateSize(of object: Any) -> Int {
        // Vereinfachte Größenschätzung
        if let string = object as? String {
            return string.utf8.count
        } else if let data = object as? Data {
            return data.count
        } else {
            // Default-Schätzung für komplexe Objekte
            return 1024
        }
    }
    
    private func getAllCacheKeys() -> [String] {
        // Cache-Keys sind nicht direkt zugänglich, daher verwenden wir
        // einen separaten Key-Tracker in einer echten Implementierung
        return []
    }
}

private class CacheEntry {
    let data: Any
    let expirationDate: Date
    
    init(data: Any, expirationDate: Date) {
        self.data = data
        self.expirationDate = expirationDate
    }
    
    var isExpired: Bool {
        return Date() > expirationDate
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Cache-Manager ist verfügbar, TTL funktioniert

---

### Schritt 5.4: Network-Request-Optimierung (60 min)
**Ziel**: Optimierte Netzwerkanfragen mit Request-Batching und Compression

#### Implementierung:
```swift
// Neue Datei: Journiary/Journiary/Managers/OptimizedNetworkManager.swift
import Foundation
import Apollo

class OptimizedNetworkManager {
    static let shared = OptimizedNetworkManager()
    
    private let requestQueue = DispatchQueue(label: "NetworkRequests", attributes: .concurrent)
    private var pendingRequests: [String: [RequestBatch]] = [:]
    private let requestLock = NSLock()
    
    private init() {}
    
    struct RequestBatch {
        let requests: [GraphQLRequest]
        let completion: (Result<[Any], Error>) -> Void
        let createdAt: Date
        
        var isExpired: Bool {
            return Date().timeIntervalSince(createdAt) > 5.0 // 5 Sekunden Timeout
        }
    }
    
    func batchRequest<T>(
        _ requests: [GraphQLRequest],
        maxWaitTime: TimeInterval = 0.1,
        completion: @escaping (Result<[T], Error>) -> Void
    ) {
        requestLock.lock()
        defer { requestLock.unlock() }
        
        let batchKey = generateBatchKey(for: requests)
        let batch = RequestBatch(
            requests: requests,
            completion: { result in
                switch result {
                case .success(let responses):
                    let typedResponses = responses.compactMap { $0 as? T }
                    completion(.success(typedResponses))
                case .failure(let error):
                    completion(.failure(error))
                }
            },
            createdAt: Date()
        )
        
        if pendingRequests[batchKey] == nil {
            pendingRequests[batchKey] = []
        }
        pendingRequests[batchKey]?.append(batch)
        
        // Verzögerte Ausführung für Batch-Optimierung
        DispatchQueue.global().asyncAfter(deadline: .now() + maxWaitTime) {
            self.executeBatch(for: batchKey)
        }
    }
    
    private func executeBatch(for key: String) {
        requestLock.lock()
        let batches = pendingRequests[key] ?? []
        pendingRequests[key] = nil
        requestLock.unlock()
        
        guard !batches.isEmpty else { return }
        
        let measurement = PerformanceMonitor.shared.startMeasuring(operation: "NetworkBatch")
        
        // Kombiniere alle Requests
        let allRequests = batches.flatMap { $0.requests }
        let allCompletions = batches.map { $0.completion }
        
        // Führe Batch-Request aus
        executeBatchRequests(allRequests) { results in
            measurement.finish(entityCount: allRequests.count)
            
            // Verteile Ergebnisse an alle Completion-Handler
            for completion in allCompletions {
                completion(results)
            }
        }
    }
    
    private func executeBatchRequests(
        _ requests: [GraphQLRequest],
        completion: @escaping (Result<[Any], Error>) -> Void
    ) {
        // Implementierung abhängig von GraphQL-Backend
        // Hier würde die tatsächliche Batch-Query ausgeführt
        
        // Simulation für Compile-Test
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            completion(.success([]))
        }
    }
    
    private func generateBatchKey(for requests: [GraphQLRequest]) -> String {
        // Generiere einzigartigen Key basierend auf Request-Typen
        let typeNames = requests.map { String(describing: type(of: $0)) }.sorted()
        return typeNames.joined(separator: "-")
    }
}

// Request-Protocol für Typisierung
protocol GraphQLRequest {
    var operationType: String { get }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Network-Optimierung ist verfügbar, Batching funktioniert

---

### Schritt 5.5: Backend-Performance-Optimierungen (90 min)
**Ziel**: Backend-seitige Performance-Verbesserungen für Sync-Operationen

#### Backend-Implementierung:
```typescript
// Backend: src/resolvers/SyncResolver.ts - erweitern

// Erweiterte Batch-Synchronisation mit Performance-Optimierung
export class OptimizedSyncResolver {
    private readonly batchProcessor = new BatchProcessor();
    private readonly cacheManager = new RedisCacheManager();
    
    @Mutation(() => BatchSyncResponse)
    async batchSync(
        @Arg("operations") operations: [SyncOperation],
        @Arg("options", { nullable: true }) options: BatchSyncOptions,
        @Ctx() ctx: Context
    ): Promise<BatchSyncResponse> {
        const measurement = new PerformanceMeasurement("BatchSync");
        
        try {
            // Parallelisiere Batch-Operationen
            const batchSize = options?.batchSize || 100;
            const batches = this.chunkOperations(operations, batchSize);
            
            const results = await Promise.allSettled(
                batches.map(batch => this.processBatch(batch, ctx))
            );
            
            const successful = results
                .filter(r => r.status === 'fulfilled')
                .map(r => (r as PromiseFulfilledResult<any>).value);
                
            const failed = results
                .filter(r => r.status === 'rejected')
                .map(r => (r as PromiseRejectedResult).reason);
            
            measurement.finish(operations.length);
            
            return {
                successful: successful.flat(),
                failed: failed.map(error => ({ error: error.message })),
                processed: operations.length,
                duration: measurement.duration
            };
            
        } catch (error) {
            measurement.finish(operations.length, error);
            throw error;
        }
    }
    
    private async processBatch(
        operations: SyncOperation[],
        ctx: Context
    ): Promise<SyncResult[]> {
        // Optimierte Batch-Verarbeitung mit Transaktionen
        return await this.entityManager.transaction(async manager => {
            const results: SyncResult[] = [];
            
            // Sortiere nach Abhängigkeiten
            const sortedOps = this.sortByDependencies(operations);
            
            for (const op of sortedOps) {
                try {
                    const result = await this.processOperation(op, manager, ctx);
                    results.push(result);
                } catch (error) {
                    // Fehler-Behandlung ohne Abbruch der gesamten Batch
                    results.push({
                        id: op.id,
                        status: 'failed',
                        error: error.message
                    });
                }
            }
            
            return results;
        });
    }
    
    private chunkOperations(operations: SyncOperation[], size: number): SyncOperation[][] {
        const chunks: SyncOperation[][] = [];
        for (let i = 0; i < operations.length; i += size) {
            chunks.push(operations.slice(i, i + size));
        }
        return chunks;
    }
    
    private sortByDependencies(operations: SyncOperation[]): SyncOperation[] {
        const dependencyMap = new Map<string, string[]>();
        const ordered: SyncOperation[] = [];
        const processed = new Set<string>();
        
        // Erstelle Dependency-Map
        for (const op of operations) {
            dependencyMap.set(op.id, op.dependencies || []);
        }
        
        // Topologische Sortierung
        const visit = (opId: string) => {
            if (processed.has(opId)) return;
            
            const deps = dependencyMap.get(opId) || [];
            for (const dep of deps) {
                visit(dep);
            }
            
            processed.add(opId);
            const operation = operations.find(op => op.id === opId);
            if (operation) ordered.push(operation);
        };
        
        for (const op of operations) {
            visit(op.id);
        }
        
        return ordered;
    }
}

// Performance-Messung für Backend
class PerformanceMeasurement {
    private startTime: Date;
    private operation: string;
    
    constructor(operation: string) {
        this.operation = operation;
        this.startTime = new Date();
    }
    
    finish(entityCount: number, error?: Error): void {
        const duration = Date.now() - this.startTime.getTime();
        
        // Metriken an Monitoring-System senden
        MetricsCollector.record({
            operation: this.operation,
            duration,
            entityCount,
            success: !error,
            timestamp: new Date()
        });
        
        console.log(`📊 ${this.operation}: ${entityCount} entities in ${duration}ms`);
    }
    
    get duration(): number {
        return Date.now() - this.startTime.getTime();
    }
}

// Batch-Processor für optimierte Verarbeitung
class BatchProcessor {
    private readonly maxConcurrency = 10;
    
    async processConcurrently<T, R>(
        items: T[],
        processor: (item: T) => Promise<R>,
        concurrency: number = this.maxConcurrency
    ): Promise<R[]> {
        const results: R[] = [];
        
        for (let i = 0; i < items.length; i += concurrency) {
            const batch = items.slice(i, i + concurrency);
            const batchResults = await Promise.allSettled(
                batch.map(item => processor(item))
            );
            
            const successfulResults = batchResults
                .filter(r => r.status === 'fulfilled')
                .map(r => (r as PromiseFulfilledResult<R>).value);
                
            results.push(...successfulResults);
        }
        
        return results;
    }
}

// Type-Definitionen
interface SyncOperation {
    id: string;
    type: 'CREATE' | 'UPDATE' | 'DELETE';
    entityType: string;
    data: any;
    dependencies?: string[];
}

interface BatchSyncOptions {
    batchSize?: number;
    maxConcurrency?: number;
    timeout?: number;
}

interface SyncResult {
    id: string;
    status: 'success' | 'failed';
    data?: any;
    error?: string;
}

interface BatchSyncResponse {
    successful: SyncResult[];
    failed: { error: string }[];
    processed: number;
    duration: number;
}
```

**Compile-Test**: Backend muss kompilieren (`npm run build`)
**Validierung**: Batch-Sync-Performance ist deutlich verbessert, Parallelisierung funktioniert

---

## Phase 6: Conflict Resolution (Woche 6)

### Schritt 6.1: Last-Write-Wins Implementierung (60 min)
**Ziel**: Einfache Konfliktlösung basierend auf Zeitstempel

#### Implementierung:
```swift
// Neue Datei: Journiary/Journiary/Managers/ConflictResolver.swift
import Foundation
import CoreData

class ConflictResolver {
    enum ConflictResolutionStrategy {
        case lastWriteWins
        case userDecision
        case keepBoth
    }
    
    struct ConflictResult {
        let resolvedEntity: NSManagedObject
        let strategy: ConflictResolutionStrategy
        let conflictDetails: String
    }
    
    func resolveConflict<T: NSManagedObject>(
        localEntity: T,
        remoteEntity: T,
        strategy: ConflictResolutionStrategy = .lastWriteWins
    ) async throws -> ConflictResult {
        
        switch strategy {
        case .lastWriteWins:
            return try await resolveLastWriteWins(local: localEntity, remote: remoteEntity)
        case .userDecision:
            return try await resolveUserDecision(local: localEntity, remote: remoteEntity)
        case .keepBoth:
            return try await resolveKeepBoth(local: localEntity, remote: remoteEntity)
        }
    }
    
    private func resolveLastWriteWins<T: NSManagedObject>(
        local: T,
        remote: T
    ) async throws -> ConflictResult {
        
        let localDate = getLastModifiedDate(for: local)
        let remoteDate = getLastModifiedDate(for: remote)
        
        let winningEntity: T
        let details: String
        
        if remoteDate > localDate {
            winningEntity = remote
            details = "Remote entity newer (remote: \(remoteDate), local: \(localDate))"
        } else {
            winningEntity = local
            details = "Local entity newer or equal (local: \(localDate), remote: \(remoteDate))"
        }
        
        return ConflictResult(
            resolvedEntity: winningEntity,
            strategy: .lastWriteWins,
            conflictDetails: details
        )
    }
    
    private func getLastModifiedDate(for entity: NSManagedObject) -> Date {
        if let updatedAt = entity.value(forKey: "updatedAt") as? Date {
            return updatedAt
        } else if let createdAt = entity.value(forKey: "createdAt") as? Date {
            return createdAt
        } else {
            return Date.distantPast
        }
    }
    
    private func resolveUserDecision<T: NSManagedObject>(
        local: T,
        remote: T
    ) async throws -> ConflictResult {
        // Placeholder für User-Entscheidung
        // In echter Implementierung würde hier UI gezeigt
        return ConflictResult(
            resolvedEntity: local,
            strategy: .userDecision,
            conflictDetails: "User decision required (defaulted to local)"
        )
    }
    
    private func resolveKeepBoth<T: NSManagedObject>(
        local: T,
        remote: T
    ) async throws -> ConflictResult {
        // Placeholder für "Beide behalten"
        // Remote wird mit neuer ID gespeichert
        return ConflictResult(
            resolvedEntity: remote,
            strategy: .keepBoth,
            conflictDetails: "Both entities kept, remote got new ID"
        )
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Conflict-Resolver ist verfügbar, Last-Write-Wins funktioniert

---

### Schritt 6.2: Konflikt-Erkennung (45 min)
**Ziel**: Automatische Erkennung von Synchronisationskonflikten

#### Implementierung:
```swift
// Erweitere ConflictResolver.swift
extension ConflictResolver {
    struct ConflictDetectionResult {
        let hasConflict: Bool
        let conflictType: ConflictType
        let conflictedFields: [String]
        let localVersion: String
        let remoteVersion: String
    }
    
    enum ConflictType {
        case none
        case simpleUpdate // Lokale und Remote-Änderungen an verschiedenen Feldern
        case complexUpdate // Überlappende Feld-Änderungen
        case deletion // Einer wurde gelöscht, der andere modifiziert
    }
    
    func detectConflict<T: NSManagedObject>(
        localEntity: T,
        remoteEntity: T
    ) -> ConflictDetectionResult {
        
        let localDate = getLastModifiedDate(for: localEntity)
        let remoteDate = getLastModifiedDate(for: remoteEntity)
        let timeDifference = abs(localDate.timeIntervalSince(remoteDate))
        
        // Kein Konflikt wenn Zeitstempel identisch oder sehr nah beieinander
        if timeDifference < 1.0 { // 1 Sekunde Toleranz
            return ConflictDetectionResult(
                hasConflict: false,
                conflictType: .none,
                conflictedFields: [],
                localVersion: localDate.description,
                remoteVersion: remoteDate.description
            )
        }
        
        // Prüfe geänderte Felder
        let conflictedFields = findConflictedFields(local: localEntity, remote: remoteEntity)
        
        let conflictType: ConflictType
        if conflictedFields.isEmpty {
            conflictType = .none
        } else if conflictedFields.count <= 2 {
            conflictType = .simpleUpdate
        } else {
            conflictType = .complexUpdate
        }
        
        return ConflictDetectionResult(
            hasConflict: !conflictedFields.isEmpty,
            conflictType: conflictType,
            conflictedFields: conflictedFields,
            localVersion: localDate.description,
            remoteVersion: remoteDate.description
        )
    }
    
    private func findConflictedFields<T: NSManagedObject>(
        local: T,
        remote: T
    ) -> [String] {
        var conflictedFields: [String] = []
        
        let entityDescription = local.entity
        
        for attribute in entityDescription.attributesByName {
            let fieldName = attribute.key
            
            // Skip system fields
            if ["createdAt", "updatedAt", "serverId"].contains(fieldName) {
                continue
            }
            
            let localValue = local.value(forKey: fieldName)
            let remoteValue = remote.value(forKey: fieldName)
            
            if !isEqual(localValue, remoteValue) {
                conflictedFields.append(fieldName)
            }
        }
        
        return conflictedFields
    }
    
    private func isEqual(_ value1: Any?, _ value2: Any?) -> Bool {
        switch (value1, value2) {
        case (nil, nil):
            return true
        case let (str1 as String, str2 as String):
            return str1 == str2
        case let (date1 as Date, date2 as Date):
            return abs(date1.timeIntervalSince(date2)) < 1.0
        case let (num1 as NSNumber, num2 as NSNumber):
            return num1 == num2
        default:
            return false
        }
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Konflikt-Erkennung funktioniert, verschiedene Konflikttypen werden erkannt

---

### Schritt 6.3: Integration in Sync-Prozess (45 min)
**Ziel**: Integration der Konfliktlösung in den bestehenden Sync-Prozess

#### Implementierung:
```swift
// In Journiary/Journiary/Managers/SyncManager.swift - erweitern
extension SyncManager {
    private let conflictResolver = ConflictResolver()
    
    private func syncEntityWithConflictResolution<T: NSManagedObject>(
        localEntity: T,
        remoteData: [String: Any],
        context: NSManagedObjectContext
    ) async throws -> T {
        
        // Erstelle temporäres Remote-Entity zum Vergleich
        let tempRemoteEntity = try createTempEntity(from: remoteData, type: T.self, context: context)
        
        // Erkennung von Konflikten
        let conflictDetection = conflictResolver.detectConflict(
            localEntity: localEntity,
            remoteEntity: tempRemoteEntity
        )
        
        if conflictDetection.hasConflict {
            print("⚠️ Konflikt erkannt: \(conflictDetection.conflictType) - Felder: \(conflictDetection.conflictedFields.joined(separator: ", "))")
            
            // Löse Konflikt
            let resolution = try await conflictResolver.resolveConflict(
                localEntity: localEntity,
                remoteEntity: tempRemoteEntity,
                strategy: .lastWriteWins
            )
            
            print("✅ Konflikt gelöst mit Strategie: \(resolution.strategy) - \(resolution.conflictDetails)")
            
            return resolution.resolvedEntity as! T
        } else {
            // Kein Konflikt - normale Synchronisation
            updateLocalEntity(localEntity, with: remoteData)
            return localEntity
        }
    }
    
    private func createTempEntity<T: NSManagedObject>(
        from data: [String: Any],
        type: T.Type,
        context: NSManagedObjectContext
    ) throws -> T {
        let entityName = String(describing: type)
        
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            throw SyncError.dataError("Entity description not found for \(entityName)")
        }
        
        let tempEntity = T(entity: entity, insertInto: nil) // Nicht in Context einfügen
        updateLocalEntity(tempEntity, with: data)
        
        return tempEntity
    }
    
    private func updateLocalEntity<T: NSManagedObject>(_ entity: T, with data: [String: Any]) {
        for (key, value) in data {
            if entity.entity.attributesByName.keys.contains(key) {
                entity.setValue(value, forKey: key)
            }
        }
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Konfliktlösung ist in Sync-Prozess integriert

---

### Schritt 6.4: Backend-Conflict-Resolution-Verbesserungen (90 min)
**Ziel**: Erweiterte server-seitige Konfliktlösung mit Multi-Device-Support

#### Backend-Implementierung:
```typescript
// Backend: src/resolvers/ConflictResolver.ts - neue Datei

import { Repository } from 'typeorm';
import { ConflictResolutionStrategy, ConflictMetadata } from '../types/ConflictTypes';

export class BackendConflictResolver {
    private readonly conflictLog: Repository<ConflictLog>;
    private readonly deviceRegistry: DeviceRegistry;
    
    constructor(
        conflictLogRepository: Repository<ConflictLog>,
        deviceRegistry: DeviceRegistry
    ) {
        this.conflictLog = conflictLogRepository;
        this.deviceRegistry = deviceRegistry;
    }
    
    async resolveConflict<T extends BaseEntity>(
        entityType: string,
        localVersion: T,
        remoteVersion: T,
        strategy: ConflictResolutionStrategy = 'lastWriteWins',
        deviceId: string
    ): Promise<ConflictResolutionResult<T>> {
        const conflictId = this.generateConflictId(entityType, localVersion.id);
        
        // Protokolliere Konflikt
        const conflict = await this.logConflict({
            id: conflictId,
            entityType,
            entityId: localVersion.id,
            deviceId,
            strategy,
            localVersion: this.serializeEntity(localVersion),
            remoteVersion: this.serializeEntity(remoteVersion),
            timestamp: new Date()
        });
        
        let resolvedEntity: T;
        let metadata: ConflictMetadata;
        
        switch (strategy) {
            case 'lastWriteWins':
                ({ resolvedEntity, metadata } = await this.resolveLastWriteWins(
                    localVersion, 
                    remoteVersion
                ));
                break;
                
            case 'fieldLevel':
                ({ resolvedEntity, metadata } = await this.resolveFieldLevel(
                    localVersion, 
                    remoteVersion
                ));
                break;
                
            case 'devicePriority':
                ({ resolvedEntity, metadata } = await this.resolveDevicePriority(
                    localVersion, 
                    remoteVersion, 
                    deviceId
                ));
                break;
                
            case 'userChoice':
                ({ resolvedEntity, metadata } = await this.resolveUserChoice(
                    localVersion, 
                    remoteVersion, 
                    conflictId
                ));
                break;
                
            default:
                throw new Error(`Unknown conflict resolution strategy: ${strategy}`);
        }
        
        // Aktualisiere Konflikt-Log
        await this.updateConflictLog(conflictId, {
            resolution: metadata,
            resolvedAt: new Date(),
            status: 'resolved'
        });
        
        return {
            resolvedEntity,
            conflictId,
            metadata,
            strategy
        };
    }
    
    private async resolveLastWriteWins<T extends BaseEntity>(
        local: T,
        remote: T
    ): Promise<{ resolvedEntity: T; metadata: ConflictMetadata }> {
        const localTimestamp = local.updatedAt || local.createdAt;
        const remoteTimestamp = remote.updatedAt || remote.createdAt;
        
        const winner = remoteTimestamp > localTimestamp ? remote : local;
        const metadata: ConflictMetadata = {
            strategy: 'lastWriteWins',
            winner: winner === local ? 'local' : 'remote',
            localTimestamp,
            remoteTimestamp,
            details: `${winner === local ? 'Local' : 'Remote'} version newer`
        };
        
        return { resolvedEntity: winner, metadata };
    }
    
    private async resolveFieldLevel<T extends BaseEntity>(
        local: T,
        remote: T
    ): Promise<{ resolvedEntity: T; metadata: ConflictMetadata }> {
        const merged = { ...local };
        const changedFields: string[] = [];
        
        // Feld-für-Feld-Vergleich
        for (const [field, remoteValue] of Object.entries(remote)) {
            if (field === 'id' || field === 'createdAt') continue;
            
            const localValue = local[field as keyof T];
            const remoteTimestamp = remote.updatedAt || remote.createdAt;
            const localTimestamp = local.updatedAt || local.createdAt;
            
            if (localValue !== remoteValue) {
                // Nehme neueren Wert pro Feld
                if (remoteTimestamp > localTimestamp) {
                    merged[field as keyof T] = remoteValue;
                    changedFields.push(field);
                }
            }
        }
        
        // Aktualisiere Timestamp
        merged.updatedAt = new Date();
        
        const metadata: ConflictMetadata = {
            strategy: 'fieldLevel',
            changedFields,
            details: `Field-level merge: ${changedFields.join(', ')}`
        };
        
        return { resolvedEntity: merged, metadata };
    }
    
    private async resolveDevicePriority<T extends BaseEntity>(
        local: T,
        remote: T,
        deviceId: string
    ): Promise<{ resolvedEntity: T; metadata: ConflictMetadata }> {
        const deviceInfo = await this.deviceRegistry.getDevice(deviceId);
        const devicePriority = deviceInfo?.priority || 0;
        
        // Höhere Priorität gewinnt
        const winner = devicePriority > 5 ? local : remote;
        const metadata: ConflictMetadata = {
            strategy: 'devicePriority',
            winner: winner === local ? 'local' : 'remote',
            devicePriority,
            details: `Device priority: ${devicePriority}`
        };
        
        return { resolvedEntity: winner, metadata };
    }
    
    private async resolveUserChoice<T extends BaseEntity>(
        local: T,
        remote: T,
        conflictId: string
    ): Promise<{ resolvedEntity: T; metadata: ConflictMetadata }> {
        // Markiere als pending user choice
        await this.conflictLog.update(conflictId, {
            status: 'pending_user_choice',
            metadata: {
                local: this.serializeEntity(local),
                remote: this.serializeEntity(remote)
            }
        });
        
        // Für jetzt: Default zu Remote (wird später durch User-UI ersetzt)
        const metadata: ConflictMetadata = {
            strategy: 'userChoice',
            status: 'pending',
            details: 'Awaiting user decision'
        };
        
        return { resolvedEntity: remote, metadata };
    }
    
    private async logConflict(conflict: ConflictLog): Promise<ConflictLog> {
        return await this.conflictLog.save(conflict);
    }
    
    private async updateConflictLog(
        conflictId: string, 
        updates: Partial<ConflictLog>
    ): Promise<void> {
        await this.conflictLog.update(conflictId, updates);
    }
    
    private generateConflictId(entityType: string, entityId: string): string {
        return `conflict_${entityType}_${entityId}_${Date.now()}`;
    }
    
    private serializeEntity<T>(entity: T): string {
        return JSON.stringify(entity, null, 2);
    }
}

// Erweiterte Sync-Resolver mit Conflict-Resolution
export class ConflictAwareSyncResolver extends OptimizedSyncResolver {
    private readonly conflictResolver: BackendConflictResolver;
    
    constructor(conflictResolver: BackendConflictResolver) {
        super();
        this.conflictResolver = conflictResolver;
    }
    
    @Mutation(() => ConflictAwareSyncResponse)
    async conflictAwareSync(
        @Arg("operations") operations: SyncOperation[],
        @Arg("deviceId") deviceId: string,
        @Arg("strategy", { nullable: true }) strategy?: ConflictResolutionStrategy,
        @Ctx() ctx: Context
    ): Promise<ConflictAwareSyncResponse> {
        const conflicts: ConflictInfo[] = [];
        const resolved: SyncResult[] = [];
        const failed: FailedOperation[] = [];
        
        for (const operation of operations) {
            try {
                const existingEntity = await this.findExistingEntity(
                    operation.entityType,
                    operation.data.id || operation.data.serverId
                );
                
                if (existingEntity && this.hasConflict(existingEntity, operation.data)) {
                    const resolution = await this.conflictResolver.resolveConflict(
                        operation.entityType,
                        existingEntity,
                        operation.data,
                        strategy || 'lastWriteWins',
                        deviceId
                    );
                    
                    conflicts.push({
                        conflictId: resolution.conflictId,
                        entityType: operation.entityType,
                        entityId: operation.data.id,
                        resolution: resolution.metadata,
                        strategy: resolution.strategy
                    });
                    
                    // Speichere aufgelöste Entität
                    const saved = await this.saveEntity(
                        operation.entityType,
                        resolution.resolvedEntity
                    );
                    
                    resolved.push({
                        id: operation.id,
                        status: 'resolved',
                        data: saved,
                        conflictId: resolution.conflictId
                    });
                } else {
                    // Keine Konflikte - normale Verarbeitung
                    const result = await this.processOperation(operation, ctx);
                    resolved.push(result);
                }
            } catch (error) {
                failed.push({
                    id: operation.id,
                    error: error.message,
                    entityType: operation.entityType
                });
            }
        }
        
        return {
            resolved,
            conflicts,
            failed,
            totalProcessed: operations.length
        };
    }
    
    private hasConflict(existing: any, incoming: any): boolean {
        const existingTimestamp = existing.updatedAt || existing.createdAt;
        const incomingTimestamp = incoming.updatedAt || incoming.createdAt;
        
        // Konflikt wenn beide in letzten 5 Minuten geändert wurden
        const timeDiff = Math.abs(existingTimestamp - incomingTimestamp);
        return timeDiff < 5 * 60 * 1000; // 5 Minuten in ms
    }
}

// Type-Definitionen
interface ConflictLog {
    id: string;
    entityType: string;
    entityId: string;
    deviceId: string;
    strategy: ConflictResolutionStrategy;
    localVersion: string;
    remoteVersion: string;
    timestamp: Date;
    resolution?: ConflictMetadata;
    resolvedAt?: Date;
    status: 'pending' | 'resolved' | 'pending_user_choice';
    metadata?: any;
}

interface ConflictResolutionResult<T> {
    resolvedEntity: T;
    conflictId: string;
    metadata: ConflictMetadata;
    strategy: ConflictResolutionStrategy;
}

interface ConflictInfo {
    conflictId: string;
    entityType: string;
    entityId: string;
    resolution: ConflictMetadata;
    strategy: ConflictResolutionStrategy;
}

interface ConflictAwareSyncResponse {
    resolved: SyncResult[];
    conflicts: ConflictInfo[];
    failed: FailedOperation[];
    totalProcessed: number;
}

interface FailedOperation {
    id: string;
    error: string;
    entityType: string;
}

type ConflictResolutionStrategy = 'lastWriteWins' | 'fieldLevel' | 'devicePriority' | 'userChoice';
```

**Compile-Test**: Backend muss kompilieren (`npm run build`)
**Validierung**: Erweiterte Konfliktlösung funktioniert, Multi-Device-Support ist aktiv

---

## Phase 7: Monitoring & Debugging (Woche 7)

### Schritt 7.1: Erweiterte Logging-Infrastruktur (60 min)
**Ziel**: Strukturiertes Logging für Debug und Monitoring

#### Implementierung:
```swift
// Neue Datei: Journiary/Journiary/Managers/SyncLogger.swift
import Foundation
import os.log

class SyncLogger {
    static let shared = SyncLogger()
    
    private let logger = Logger(subsystem: "com.journiary.sync", category: "SyncManager")
    private let logQueue = DispatchQueue(label: "SyncLogger", qos: .utility)
    
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
    }
    
    struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let category: String
        let message: String
        let metadata: [String: Any]
        let stackTrace: String?
        
        var formattedMessage: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            let timeString = formatter.string(from: timestamp)
            
            var message = "\(level.emoji) [\(timeString)] \(category): \(self.message)"
            
            if !metadata.isEmpty {
                let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                message += " {\(metadataString)}"
            }
            
            return message
        }
    }
    
    private var logEntries: [LogEntry] = []
    private let maxLogEntries = 1000
    
    private init() {}
    
    func log(
        level: LogLevel,
        category: String,
        message: String,
        metadata: [String: Any] = [:],
        includeStackTrace: Bool = false
    ) {
        let stackTrace = includeStackTrace ? Thread.callStackSymbols.joined(separator: "\n") : nil
        
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            stackTrace: stackTrace
        )
        
        logQueue.async { [weak self] in
            self?.addLogEntry(entry)
            self?.outputLog(entry)
        }
    }
    
    private func addLogEntry(_ entry: LogEntry) {
        logEntries.append(entry)
        
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
    }
    
    private func outputLog(_ entry: LogEntry) {
        // Console-Output
        print(entry.formattedMessage)
        
        // System-Logger
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
    
    func getRecentLogs(count: Int = 100, level: LogLevel? = nil) -> [LogEntry] {
        return logQueue.sync {
            let filteredLogs = level == nil ? logEntries : logEntries.filter { $0.level == level }
            return Array(filteredLogs.suffix(count))
        }
    }
    
    func exportLogs() -> String {
        return logQueue.sync {
            return logEntries.map { $0.formattedMessage }.joined(separator: "\n")
        }
    }
}

// Convenience-Erweiterungen
extension SyncLogger {
    func debug(_ message: String, category: String = "General", metadata: [String: Any] = [:]) {
        log(level: .debug, category: category, message: message, metadata: metadata)
    }
    
    func info(_ message: String, category: String = "General", metadata: [String: Any] = [:]) {
        log(level: .info, category: category, message: message, metadata: metadata)
    }
    
    func warning(_ message: String, category: String = "General", metadata: [String: Any] = [:]) {
        log(level: .warning, category: category, message: message, metadata: metadata)
    }
    
    func error(_ message: String, category: String = "General", metadata: [String: Any] = [:], includeStackTrace: Bool = true) {
        log(level: .error, category: category, message: message, metadata: metadata, includeStackTrace: includeStackTrace)
    }
    
    func critical(_ message: String, category: String = "General", metadata: [String: Any] = [:]) {
        log(level: .critical, category: category, message: message, metadata: metadata, includeStackTrace: true)
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Erweiterte Logging-Infrastruktur ist verfügbar

---

### Schritt 7.2: Backend-Monitoring-System (75 min)
**Ziel**: Umfassendes Backend-Monitoring für Sync-Operationen

#### Backend-Implementierung:
```typescript
// Backend: src/monitoring/SyncMonitoringSystem.ts - neue Datei

import { Repository } from 'typeorm';
import { EventEmitter } from 'events';

export class SyncMonitoringSystem extends EventEmitter {
    private readonly metricsRepository: Repository<SyncMetric>;
    private readonly alertsRepository: Repository<SyncAlert>;
    private readonly healthCheckRepository: Repository<HealthCheck>;
    private readonly metricsBuffer: Map<string, SyncMetric[]> = new Map();
    
    constructor(
        metricsRepo: Repository<SyncMetric>,
        alertsRepo: Repository<SyncAlert>,
        healthRepo: Repository<HealthCheck>
    ) {
        super();
        this.metricsRepository = metricsRepo;
        this.alertsRepository = alertsRepo;
        this.healthCheckRepository = healthRepo;
        
        // Starte periodische Auswertungen
        this.startPeriodicAnalysis();
    }
    
    // Sync-Metriken aufzeichnen
    async recordSyncMetric(metric: SyncMetricData): Promise<void> {
        const syncMetric = new SyncMetric();
        syncMetric.operation = metric.operation;
        syncMetric.entityType = metric.entityType;
        syncMetric.entityCount = metric.entityCount;
        syncMetric.duration = metric.duration;
        syncMetric.success = metric.success;
        syncMetric.errorMessage = metric.errorMessage;
        syncMetric.deviceId = metric.deviceId;
        syncMetric.timestamp = new Date();
        
        // Puffere Metriken für bessere Performance
        if (!this.metricsBuffer.has(metric.operation)) {
            this.metricsBuffer.set(metric.operation, []);
        }
        this.metricsBuffer.get(metric.operation)!.push(syncMetric);
        
        // Speichere Batch periodisch
        if (this.metricsBuffer.get(metric.operation)!.length >= 100) {
            await this.flushMetrics(metric.operation);
        }
        
        // Echtzeitanalyse für kritische Metriken
        await this.analyzeMetricRealtime(syncMetric);
    }
    
    // Performance-Analyse
    async getPerformanceAnalysis(
        timeWindow: 'hour' | 'day' | 'week' = 'hour'
    ): Promise<PerformanceAnalysis> {
        const windowStart = this.getTimeWindowStart(timeWindow);
        
        const metrics = await this.metricsRepository
            .createQueryBuilder('metric')
            .where('metric.timestamp >= :start', { start: windowStart })
            .getMany();
        
        return {
            totalOperations: metrics.length,
            successRate: this.calculateSuccessRate(metrics),
            averageDuration: this.calculateAverageDuration(metrics),
            throughput: this.calculateThroughput(metrics, timeWindow),
            errorRate: this.calculateErrorRate(metrics),
            performanceByEntityType: this.analyzeByEntityType(metrics),
            devicePerformance: this.analyzeByDevice(metrics),
            timeSeriesData: this.generateTimeSeriesData(metrics)
        };
    }
    
    // Sync-Health-Check
    async performHealthCheck(): Promise<HealthCheckResult> {
        const healthCheck = new HealthCheck();
        healthCheck.timestamp = new Date();
        
        try {
            // Prüfe Database-Performance
            const dbPerformance = await this.checkDatabasePerformance();
            
            // Prüfe Sync-Queue Status
            const queueStatus = await this.checkSyncQueueStatus();
            
            // Prüfe Error-Rate
            const errorRate = await this.checkErrorRate();
            
            // Prüfe Memory-Usage
            const memoryUsage = await this.checkMemoryUsage();
            
            const overallHealth = this.calculateOverallHealth(
                dbPerformance,
                queueStatus,
                errorRate,
                memoryUsage
            );
            
            healthCheck.status = overallHealth.status;
            healthCheck.score = overallHealth.score;
            healthCheck.details = {
                database: dbPerformance,
                queue: queueStatus,
                errorRate,
                memory: memoryUsage
            };
            
            await this.healthCheckRepository.save(healthCheck);
            
            // Trigger Alerts wenn nötig
            if (overallHealth.score < 0.7) {
                await this.triggerHealthAlert(healthCheck);
            }
            
            return {
                status: healthCheck.status,
                score: healthCheck.score,
                timestamp: healthCheck.timestamp,
                details: healthCheck.details
            };
            
        } catch (error) {
            healthCheck.status = 'critical';
            healthCheck.score = 0;
            healthCheck.details = { error: error.message };
            
            await this.healthCheckRepository.save(healthCheck);
            await this.triggerHealthAlert(healthCheck);
            
            return {
                status: 'critical',
                score: 0,
                timestamp: healthCheck.timestamp,
                details: { error: error.message }
            };
        }
    }
    
    // Alert-System
    async triggerAlert(
        type: AlertType,
        severity: AlertSeverity,
        message: string,
        details?: any
    ): Promise<void> {
        const alert = new SyncAlert();
        alert.type = type;
        alert.severity = severity;
        alert.message = message;
        alert.details = details;
        alert.timestamp = new Date();
        alert.acknowledged = false;
        
        await this.alertsRepository.save(alert);
        
        // Emittiere Event für externe Systeme
        this.emit('alert', alert);
        
        // Sende Benachrichtigungen basierend auf Severity
        switch (severity) {
            case 'critical':
                await this.sendCriticalAlert(alert);
                break;
            case 'warning':
                await this.sendWarningAlert(alert);
                break;
            case 'info':
                await this.sendInfoAlert(alert);
                break;
        }
    }
    
    // Sync-Trends analysieren
    async analyzeSyncTrends(days: number = 7): Promise<SyncTrendAnalysis> {
        const endDate = new Date();
        const startDate = new Date();
        startDate.setDate(endDate.getDate() - days);
        
        const dailyMetrics = await this.metricsRepository
            .createQueryBuilder('metric')
            .select([
                'DATE(metric.timestamp) as date',
                'COUNT(*) as operations',
                'AVG(metric.duration) as avgDuration',
                'SUM(CASE WHEN metric.success = true THEN 1 ELSE 0 END) as successCount'
            ])
            .where('metric.timestamp BETWEEN :start AND :end', { 
                start: startDate, 
                end: endDate 
            })
            .groupBy('DATE(metric.timestamp)')
            .orderBy('date', 'ASC')
            .getRawMany();
        
        const trends = this.calculateTrends(dailyMetrics);
        
        return {
            period: `${days} days`,
            trends,
            recommendations: this.generateRecommendations(trends),
            forecast: this.generateForecast(dailyMetrics)
        };
    }
    
    // Private Hilfsmethoden
    private async flushMetrics(operation: string): Promise<void> {
        const metrics = this.metricsBuffer.get(operation) || [];
        if (metrics.length > 0) {
            await this.metricsRepository.save(metrics);
            this.metricsBuffer.set(operation, []);
        }
    }
    
    private async analyzeMetricRealtime(metric: SyncMetric): Promise<void> {
        // Prüfe auf Anomalien
        if (metric.duration > 30000) { // > 30 Sekunden
            await this.triggerAlert(
                'performance',
                'warning',
                `Slow sync operation detected: ${metric.operation} took ${metric.duration}ms`,
                { metric }
            );
        }
        
        if (!metric.success) {
            await this.triggerAlert(
                'error',
                'warning',
                `Sync operation failed: ${metric.operation} - ${metric.errorMessage}`,
                { metric }
            );
        }
    }
    
    private startPeriodicAnalysis(): void {
        // Alle 5 Minuten: Metriken flushen
        setInterval(async () => {
            for (const operation of this.metricsBuffer.keys()) {
                await this.flushMetrics(operation);
            }
        }, 5 * 60 * 1000);
        
        // Alle 15 Minuten: Health-Check
        setInterval(async () => {
            await this.performHealthCheck();
        }, 15 * 60 * 1000);
        
        // Stündlich: Trend-Analyse
        setInterval(async () => {
            const trends = await this.analyzeSyncTrends(1);
            this.emit('trends', trends);
        }, 60 * 60 * 1000);
    }
    
    private calculateSuccessRate(metrics: SyncMetric[]): number {
        const successful = metrics.filter(m => m.success).length;
        return metrics.length > 0 ? successful / metrics.length : 0;
    }
    
    private calculateAverageDuration(metrics: SyncMetric[]): number {
        const totalDuration = metrics.reduce((sum, m) => sum + m.duration, 0);
        return metrics.length > 0 ? totalDuration / metrics.length : 0;
    }
    
    private calculateThroughput(metrics: SyncMetric[], timeWindow: string): number {
        const totalEntities = metrics.reduce((sum, m) => sum + m.entityCount, 0);
        const windowHours = this.getTimeWindowHours(timeWindow);
        return totalEntities / windowHours;
    }
    
    private calculateErrorRate(metrics: SyncMetric[]): number {
        const failed = metrics.filter(m => !m.success).length;
        return metrics.length > 0 ? failed / metrics.length : 0;
    }
    
    private getTimeWindowStart(window: string): Date {
        const now = new Date();
        switch (window) {
            case 'hour':
                return new Date(now.getTime() - 60 * 60 * 1000);
            case 'day':
                return new Date(now.getTime() - 24 * 60 * 60 * 1000);
            case 'week':
                return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
            default:
                return new Date(now.getTime() - 60 * 60 * 1000);
        }
    }
    
    private getTimeWindowHours(window: string): number {
        switch (window) {
            case 'hour': return 1;
            case 'day': return 24;
            case 'week': return 168;
            default: return 1;
        }
    }
}

// Type-Definitionen
interface SyncMetricData {
    operation: string;
    entityType: string;
    entityCount: number;
    duration: number;
    success: boolean;
    errorMessage?: string;
    deviceId?: string;
}

interface PerformanceAnalysis {
    totalOperations: number;
    successRate: number;
    averageDuration: number;
    throughput: number;
    errorRate: number;
    performanceByEntityType: Record<string, any>;
    devicePerformance: Record<string, any>;
    timeSeriesData: any[];
}

interface HealthCheckResult {
    status: 'healthy' | 'warning' | 'critical';
    score: number;
    timestamp: Date;
    details: any;
}

interface SyncTrendAnalysis {
    period: string;
    trends: any;
    recommendations: string[];
    forecast: any;
}

type AlertType = 'performance' | 'error' | 'health' | 'capacity';
type AlertSeverity = 'info' | 'warning' | 'critical';

// Entitäten
class SyncMetric {
    id: string;
    operation: string;
    entityType: string;
    entityCount: number;
    duration: number;
    success: boolean;
    errorMessage?: string;
    deviceId?: string;
    timestamp: Date;
}

class SyncAlert {
    id: string;
    type: AlertType;
    severity: AlertSeverity;
    message: string;
    details?: any;
    timestamp: Date;
    acknowledged: boolean;
    acknowledgedBy?: string;
    acknowledgedAt?: Date;
}

class HealthCheck {
    id: string;
    status: 'healthy' | 'warning' | 'critical';
    score: number;
    details: any;
    timestamp: Date;
}
```

**Compile-Test**: Backend muss kompilieren (`npm run build`)
**Validierung**: Backend-Monitoring ist aktiv, Alerts funktionieren, Performance-Analyse läuft

---

### Schritt 7.3: Debug-Dashboard (75 min)
**Ziel**: Dashboard-View für Sync-Status und Debugging

#### Implementierung:
```swift
// Neue Datei: Journiary/Journiary/Views/SyncDebugDashboard.swift
import SwiftUI

struct SyncDebugDashboard: View {
    @StateObject private var viewModel = SyncDebugViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Debug-Kategorie", selection: $selectedTab) {
                    Text("Status").tag(0)
                    Text("Logs").tag(1)
                    Text("Performance").tag(2)
                    Text("Queue").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                TabView(selection: $selectedTab) {
                    SyncStatusView(viewModel: viewModel)
                        .tag(0)
                    
                    SyncLogsView(viewModel: viewModel)
                        .tag(1)
                    
                    PerformanceView(viewModel: viewModel)
                        .tag(2)
                    
                    QueueStatusView(viewModel: viewModel)
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Sync Debug")
            .onAppear {
                viewModel.loadData()
            }
        }
    }
}

struct SyncStatusView: View {
    @ObservedObject var viewModel: SyncDebugViewModel
    
    var body: some View {
        List {
            Section("Aktueller Status") {
                HStack {
                    Text("Sync-Status")
                    Spacer()
                    Text(viewModel.currentSyncStatus)
                        .foregroundColor(statusColor)
                }
                
                HStack {
                    Text("Letzte Synchronisation")
                    Spacer()
                    Text(viewModel.lastSyncTime)
                        .font(.caption)
                }
                
                HStack {
                    Text("Pending Entities")
                    Spacer()
                    Text("\(viewModel.pendingEntitiesCount)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            Section("Statistiken") {
                ForEach(viewModel.entityStats, id: \.entityType) { stat in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(stat.entityType)
                                .font(.headline)
                            Spacer()
                            Text("\(stat.syncedCount)/\(stat.totalCount)")
                                .font(.caption)
                        }
                        
                        ProgressView(value: stat.syncProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private var statusColor: Color {
        switch viewModel.currentSyncStatus {
        case "Synchronisiert": return .green
        case "Wird synchronisiert...": return .orange
        case "Fehler": return .red
        default: return .gray
        }
    }
}

struct SyncLogsView: View {
    @ObservedObject var viewModel: SyncDebugViewModel
    
    var body: some View {
        VStack {
            HStack {
                Picker("Log Level", selection: $viewModel.selectedLogLevel) {
                    Text("Alle").tag(Optional<SyncLogger.LogLevel>.none)
                    ForEach(SyncLogger.LogLevel.allCases, id: \.rawValue) { level in
                        Text(level.rawValue).tag(Optional(level))
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Spacer()
                
                Button("Export") {
                    viewModel.exportLogs()
                }
            }
            .padding()
            
            List(viewModel.filteredLogs, id: \.timestamp) { log in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(log.level.emoji)
                        Text(log.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(log.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(log.message)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.vertical, 2)
            }
        }
    }
}

class SyncDebugViewModel: ObservableObject {
    @Published var currentSyncStatus = "Idle"
    @Published var lastSyncTime = "Nie"
    @Published var pendingEntitiesCount = 0
    @Published var entityStats: [EntitySyncStat] = []
    @Published var filteredLogs: [SyncLogger.LogEntry] = []
    @Published var selectedLogLevel: SyncLogger.LogLevel?
    
    struct EntitySyncStat {
        let entityType: String
        let totalCount: Int
        let syncedCount: Int
        
        var syncProgress: Double {
            guard totalCount > 0 else { return 0 }
            return Double(syncedCount) / Double(totalCount)
        }
    }
    
    func loadData() {
        loadSyncStatus()
        loadEntityStats()
        loadLogs()
    }
    
    private func loadSyncStatus() {
        // Lade aktuellen Sync-Status
        currentSyncStatus = "Synchronisiert"
        lastSyncTime = "Vor 5 Minuten"
        pendingEntitiesCount = 12
    }
    
    private func loadEntityStats() {
        entityStats = [
            EntitySyncStat(entityType: "Trips", totalCount: 15, syncedCount: 15),
            EntitySyncStat(entityType: "Memories", totalCount: 234, syncedCount: 220),
            EntitySyncStat(entityType: "MediaItems", totalCount: 567, syncedCount: 445),
            EntitySyncStat(entityType: "GPXTracks", totalCount: 23, syncedCount: 23)
        ]
    }
    
    private func loadLogs() {
        filteredLogs = SyncLogger.shared.getRecentLogs(count: 50, level: selectedLogLevel)
    }
    
    func exportLogs() {
        let logs = SyncLogger.shared.exportLogs()
        // Implementiere Export-Funktionalität
        print("Exporting logs...")
        print(logs)
    }
}

// Placeholder Views
struct PerformanceView: View {
    @ObservedObject var viewModel: SyncDebugViewModel
    
    var body: some View {
        Text("Performance Metrics")
            .font(.title2)
    }
}

struct QueueStatusView: View {
    @ObservedObject var viewModel: SyncDebugViewModel
    
    var body: some View {
        Text("Queue Status")
            .font(.title2)
    }
}
```

**Compile-Test**: `⌘+B` - Projekt muss kompilieren
**Validierung**: Debug-Dashboard ist verfügbar und zeigt Sync-Informationen

---

## Phase 8: Testing & Validierung (Woche 8)

### Schritt 8.1: Unit-Tests für Sync-Komponenten (90 min)
**Ziel**: Umfassende Unit-Tests für alle Sync-Manager

#### Implementierung:
```swift
// Neue Datei: JourniaryTests/SyncManagerTests.swift
import XCTest
@testable import Journiary
import CoreData

class SyncManagerTests: XCTestCase {
    var sut: SyncManager!
    var mockContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Setup In-Memory Core Data Stack for Testing
        let persistentContainer = NSPersistentContainer(name: "Journiary")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        mockContext = persistentContainer.viewContext
        sut = SyncManager()
    }
    
    override func tearDownWithError() throws {
        sut = nil
        mockContext = nil
        try super.tearDownWithError()
    }
    
    func testDependencyResolverOrder() throws {
        // Given
        let resolver = SyncDependencyResolver()
        
        // When
        let order = resolver.resolveSyncOrder()
        
        // Then
        XCTAssertEqual(order.first, .tagCategory, "TagCategory should be first")
        XCTAssertEqual(order.last, .gpxTrack, "GPXTrack should be last")
        
        // Validate dependencies are respected
        let tagIndex = order.firstIndex(of: .tag)!
        let tagCategoryIndex = order.firstIndex(of: .tagCategory)!
        XCTAssertLessThan(tagCategoryIndex, tagIndex, "TagCategory must come before Tag")
    }
    
    func testConflictResolutionLastWriteWins() async throws {
        // Given
        let resolver = ConflictResolver()
        
        let trip1 = Trip(context: mockContext)
        trip1.title = "Local Trip"
        trip1.updatedAt = Date().addingTimeInterval(-100) // Older
        
        let trip2 = Trip(context: mockContext)
        trip2.title = "Remote Trip"
        trip2.updatedAt = Date() // Newer
        
        // When
        let result = try await resolver.resolveConflict(
            localEntity: trip1,
            remoteEntity: trip2,
            strategy: .lastWriteWins
        )
        
        // Then
        XCTAssertEqual(result.strategy, .lastWriteWins)
        XCTAssertEqual((result.resolvedEntity as! Trip).title, "Remote Trip")
        XCTAssertTrue(result.conflictDetails.contains("Remote entity newer"))
    }
    
    func testPerformanceMonitoring() {
        // Given
        let monitor = PerformanceMonitor.shared
        
        // When
        let measurement = monitor.startMeasuring(operation: "TestOperation")
        
        // Simulate some work
        Thread.sleep(forTimeInterval: 0.1)
        
        measurement.finish(entityCount: 10, networkBytes: 1024)
        
        // Then
        let avgPerformance = monitor.getAveragePerformance(for: "TestOperation")
        XCTAssertNotNil(avgPerformance)
        XCTAssertGreaterThan(avgPerformance!, 0)
    }
    
    func testOfflineSyncQueue() {
        // Given
        let queue = OfflineSyncQueue.shared
        
        // When
        let success = queue.enqueue(
            entityType: "Trip",
            entityId: "test-trip-1",
            operation: .create,
            priority: .high
        )
        
        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(queue.pendingCount, 1)
        
        // Test dequeue
        let task = queue.dequeue()
        XCTAssertNotNil(task)
        XCTAssertEqual(task?.entityType, "Trip")
        XCTAssertEqual(task?.priority, .high)
    }
    
    func testFileSyncPriority() {
        // Given
        let manager = FileSyncPriorityManager()
        
        let highPriorityFile = FileSyncPriority(
            entityId: "media-1",
            entityType: "MediaItem",
            fileSize: 500_000, // Small file
            createdAt: Date() // Recent
        )
        
        let lowPriorityFile = FileSyncPriority(
            entityId: "media-2",
            entityType: "MediaItem",
            fileSize: 50_000_000, // Large file
            createdAt: Date().addingTimeInterval(-86400 * 7) // Old
        )
        
        // When
        let prioritized = manager.prioritizeFileTasks([lowPriorityFile, highPriorityFile])
        
        // Then
        XCTAssertEqual(prioritized.first?.entityId, "media-1")
        XCTAssertGreaterThan(prioritized.first!.priority, prioritized.last!.priority)
    }
}
```

**Compile-Test**: `⌘+B` - Tests müssen kompilieren
**Validierung**: Tests laufen erfolgreich durch

---

### Schritt 8.2: Integration-Tests (60 min)
**Ziel**: End-to-End Tests für komplette Sync-Zyklen

#### Implementierung:
```swift
// Neue Datei: JourniaryTests/SyncIntegrationTests.swift
import XCTest
@testable import Journiary
import CoreData

class SyncIntegrationTests: XCTestCase {
    var sut: SyncManager!
    var testContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        setupTestEnvironment()
    }
    
    func testFullSyncCycle() async throws {
        // Given: Lokale Daten erstellen
        let trip = createTestTrip()
        let memory = createTestMemory(for: trip)
        let mediaItem = createTestMediaItem(for: memory)
        
        try testContext.save()
        
        // When: Vollständige Synchronisation
        try await sut.performFullSync()
        
        // Then: Alle Entitäten sollten synchronisiert sein
        XCTAssertNotNil(trip.serverId)
        XCTAssertNotNil(memory.serverId)
        XCTAssertNotNil(mediaItem.serverId)
        
        // Dependency-Order sollte respektiert worden sein
        XCTAssertNotNil(trip.serverId, "Trip should be synced first")
        XCTAssertNotNil(memory.serverId, "Memory should be synced after Trip")
        XCTAssertNotNil(mediaItem.serverId, "MediaItem should be synced after Memory")
    }
    
    func testConflictResolutionIntegration() async throws {
        // Given: Konfliktierender lokaler und Remote-Zustand simulieren
        let localTrip = createTestTrip()
        localTrip.title = "Local Title"
        localTrip.updatedAt = Date().addingTimeInterval(-60)
        
        // Simuliere Remote-Update (normalerweise vom Server)
        let remoteData: [String: Any] = [
            "title": "Remote Title",
            "updatedAt": Date(), // Neueres Datum
            "serverId": "remote-trip-id"
        ]
        
        // When: Sync mit Konfliktlösung
        try await sut.syncWithConflictResolution(
            localEntity: localTrip,
            remoteData: remoteData
        )
        
        // Then: Remote-Version sollte gewonnen haben (Last-Write-Wins)
        XCTAssertEqual(localTrip.title, "Remote Title")
        XCTAssertEqual(localTrip.serverId, "remote-trip-id")
    }
    
    func testOfflineQueueProcessing() async throws {
        // Given: Offline-Operationen in Queue
        let queue = OfflineSyncQueue.shared
        
        _ = queue.enqueue(
            entityType: "Trip",
            entityId: "offline-trip-1",
            operation: .create,
            priority: .high
        )
        
        _ = queue.enqueue(
            entityType: "Memory",
            entityId: "offline-memory-1",
            operation: .update,
            priority: .normal
        )
        
        // When: Queue wird abgearbeitet
        try await sut.processOfflineQueue()
        
        // Then: Queue sollte leer sein
        XCTAssertEqual(queue.pendingCount, 0)
    }
    
    // MARK: - Helper Methods
    
    private func setupTestEnvironment() {
        let persistentContainer = NSPersistentContainer(name: "Journiary")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        testContext = persistentContainer.viewContext
        sut = SyncManager()
    }
    
    private func createTestTrip() -> Trip {
        let trip = Trip(context: testContext)
        trip.title = "Test Trip"
        trip.createdAt = Date()
        trip.updatedAt = Date()
        return trip
    }
    
    private func createTestMemory(for trip: Trip) -> Memory {
        let memory = Memory(context: testContext)
        memory.title = "Test Memory"
        memory.trip = trip
        memory.createdAt = Date()
        memory.updatedAt = Date()
        return memory
    }
    
    private func createTestMediaItem(for memory: Memory) -> MediaItem {
        let mediaItem = MediaItem(context: testContext)
        mediaItem.filename = "test.jpg"
        mediaItem.memory = memory
        mediaItem.createdAt = Date()
        mediaItem.updatedAt = Date()
        return mediaItem
    }
}
```

**Compile-Test**: `⌘+B` - Tests müssen kompilieren
**Validierung**: Integration-Tests laufen erfolgreich durch

---

### Schritt 8.3: Performance-Tests (45 min)
**Ziel**: Tests für Performance-kritische Sync-Operationen

#### Implementierung:
```swift
// Neue Datei: JourniaryTests/SyncPerformanceTests.swift
import XCTest
@testable import Journiary
import CoreData

class SyncPerformanceTests: XCTestCase {
    var sut: SyncManager!
    var testContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        setupTestEnvironment()
    }
    
    func testBatchUploadPerformance() {
        // Teste Batch-Upload mit 1000 Memories
        let memories = createTestMemories(count: 1000)
        
        measure {
            let expectation = XCTestExpectation(description: "Batch Upload")
            
            Task {
                try await sut.batchUpload(memories, batchSize: 50)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    func testMemoryUsageStability() {
        // Teste Memory-Stabilität bei großen Sync-Operationen
        let initialMemory = getMemoryUsage()
        
        for _ in 0..<10 {
            let memories = createTestMemories(count: 100)
            
            let expectation = XCTestExpectation(description: "Memory Cycle")
            Task {
                try await sut.batchUpload(memories, batchSize: 20)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10.0)
            
            // Cleanup
            memories.forEach { testContext.delete($0) }
            try! testContext.save()
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be less than 50MB
        XCTAssertLessThan(memoryIncrease, 50_000_000, "Memory usage increased too much: \(memoryIncrease) bytes")
    }
    
    func testCachePerformance() {
        // Teste Cache-Performance
        let cache = SyncCacheManager.shared
        let testData = Array(0..<1000).map { "TestData-\($0)" }
        
        // Test Cache Write Performance
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            
            for (index, data) in testData.enumerated() {
                cache.cacheEntity(data, forKey: "key-\(index)")
            }
            
            stopMeasuring()
        }
        
        // Test Cache Read Performance
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            
            for index in 0..<1000 {
                _ = cache.getCachedEntity(forKey: "key-\(index)", type: String.self)
            }
            
            stopMeasuring()
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupTestEnvironment() {
        let persistentContainer = NSPersistentContainer(name: "Journiary")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        testContext = persistentContainer.viewContext
        sut = SyncManager()
    }
    
    private func createTestMemories(count: Int) -> [Memory] {
        return (0..<count).map { index in
            let memory = Memory(context: testContext)
            memory.title = "Test Memory \(index)"
            memory.createdAt = Date()
            memory.updatedAt = Date()
            return memory
        }
    }
    
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
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
}
```

**Compile-Test**: `⌘+B` - Tests müssen kompilieren
**Validierung**: Performance-Tests laufen durch und zeigen akzeptable Werte

---

## Erfolgskriterien für jeden Schritt

1. **Kompilierung**: Projekt muss nach jedem Schritt kompilieren
2. **Rückwärtskompatibilität**: Bestehende Funktionalität darf nicht beeinträchtigt werden  
3. **Testbarkeit**: Jede neue Komponente muss testbar sein
4. **Dokumentation**: Jede Änderung muss dokumentiert werden
5. **Performance**: Keine Verschlechterung der App-Performance

## Rollback-Strategie

- **Git-Branch**: Jeder Schritt wird in eigenem Branch entwickelt
- **Backup**: Vor größeren Änderungen wird Backup erstellt  
- **Schrittweise Integration**: Neue Features werden schrittweise integriert
- **Feature-Flags**: Kritische Features können per Flag aktiviert/deaktiviert werden

---

## Phase 9: Backend-Architektur-Verbesserungen (Woche 9)

### Schritt 9.1: Redis-Caching-System (90 min)
**Ziel**: Implementierung eines Redis-basierten Caching-Systems für bessere Performance

#### Backend-Implementierung:
```typescript
// Backend: src/caching/RedisCacheManager.ts - neue Datei

import Redis from 'ioredis';
import { injectable } from 'inversify';

@injectable()
export class RedisCacheManager {
    private redis: Redis;
    private readonly defaultTTL = 3600; // 1 Stunde
    
    constructor() {
        this.redis = new Redis({
            host: process.env.REDIS_HOST || 'localhost',
            port: parseInt(process.env.REDIS_PORT || '6379'),
            password: process.env.REDIS_PASSWORD,
            retryDelayOnFailover: 100,
            maxRetriesPerRequest: 3,
            lazyConnect: true
        });
        
        this.redis.on('error', (error) => {
            console.error('Redis connection error:', error);
        });
        
        this.redis.on('connect', () => {
            console.log('Redis connected successfully');
        });
    }
    
    // Sync-Daten cachen
    async cacheSyncData(key: string, data: any, ttl: number = this.defaultTTL): Promise<void> {
        try {
            const serializedData = JSON.stringify(data);
            await this.redis.setex(key, ttl, serializedData);
        } catch (error) {
            console.error('Error caching sync data:', error);
            throw error;
        }
    }
    
    // Cached Sync-Daten abrufen
    async getCachedSyncData<T>(key: string): Promise<T | null> {
        try {
            const data = await this.redis.get(key);
            return data ? JSON.parse(data) : null;
        } catch (error) {
            console.error('Error retrieving cached sync data:', error);
            return null;
        }
    }
    
    // Smart Caching für häufig abgerufene Daten
    async smartCache<T>(
        key: string,
        fetchFunction: () => Promise<T>,
        ttl: number = this.defaultTTL
    ): Promise<T> {
        // Versuche zuerst aus Cache
        const cached = await this.getCachedSyncData<T>(key);
        if (cached) {
            // Aktualisiere Hit-Counter
            await this.incrementHitCounter(key);
            return cached;
        }
        
        // Lade Daten und cache sie
        const data = await fetchFunction();
        await this.cacheSyncData(key, data, ttl);
        
        // Aktualisiere Miss-Counter
        await this.incrementMissCounter(key);
        
        return data;
    }
    
    // Preload-System für vorhersagbare Daten
    async preloadUserData(userId: string): Promise<void> {
        const preloadTasks = [
            this.preloadUserTrips(userId),
            this.preloadUserTags(userId),
            this.preloadUserBucketList(userId)
        ];
        
        await Promise.allSettled(preloadTasks);
    }
    
    private async preloadUserTrips(userId: string): Promise<void> {
        const key = `user:${userId}:trips`;
        const cached = await this.getCachedSyncData(key);
        
        if (!cached) {
            // Simuliere Trip-Laden (würde normalerweise DB-Query sein)
            const trips = await this.fetchUserTrips(userId);
            await this.cacheSyncData(key, trips, 7200); // 2 Stunden Cache
        }
    }
    
    private async preloadUserTags(userId: string): Promise<void> {
        const key = `user:${userId}:tags`;
        const cached = await this.getCachedSyncData(key);
        
        if (!cached) {
            const tags = await this.fetchUserTags(userId);
            await this.cacheSyncData(key, tags, 3600); // 1 Stunde Cache
        }
    }
    
    private async preloadUserBucketList(userId: string): Promise<void> {
        const key = `user:${userId}:bucketlist`;
        const cached = await this.getCachedSyncData(key);
        
        if (!cached) {
            const bucketList = await this.fetchUserBucketList(userId);
            await this.cacheSyncData(key, bucketList, 1800); // 30 Minuten Cache
        }
    }
    
    // Hilfsmethoden
    private parseMemoryInfo(info: string): number {
        const lines = info.split('\n');
        const usedMemoryLine = lines.find(line => line.startsWith('used_memory:'));
        return usedMemoryLine ? parseInt(usedMemoryLine.split(':')[1]) : 0;
    }
    
    private async calculateHitRate(): Promise<number> {
        const hits = await this.redis.get('cache:hits') || '0';
        const misses = await this.redis.get('cache:misses') || '0';
        const total = parseInt(hits) + parseInt(misses);
        return total > 0 ? parseInt(hits) / total : 0;
    }
    
    private async getUptime(): Promise<number> {
        const info = await this.redis.info('server');
        const uptimeLine = info.split('\n').find(line => line.startsWith('uptime_in_seconds:'));
        return uptimeLine ? parseInt(uptimeLine.split(':')[1]) : 0;
    }
    
    private async incrementHitCounter(key: string): Promise<void> {
        await this.redis.incr('cache:hits');
        await this.redis.incr(`cache:hits:${key}`);
    }
    
    private async incrementMissCounter(key: string): Promise<void> {
        await this.redis.incr('cache:misses');
        await this.redis.incr(`cache:misses:${key}`);
    }
    
    // Placeholder-Methoden (würden normalerweise richtige DB-Queries sein)
    private async fetchUserTrips(userId: string): Promise<any[]> {
        // Echte Implementierung würde DB abfragen
        return [];
    }
    
    private async fetchUserTags(userId: string): Promise<any[]> {
        return [];
    }
    
    private async fetchUserBucketList(userId: string): Promise<any[]> {
        return [];
    }
}

// Cache-Statistiken Interface
interface CacheStats {
    keyCount: number;
    memoryUsage: number;
    hitRate: number;
    uptime: number;
}

// Cache-Decorator für automatisches Caching
export function Cached(ttl: number = 3600, keyPrefix: string = '') {
    return function(target: any, propertyKey: string, descriptor: PropertyDescriptor) {
        const originalMethod = descriptor.value;
        
        descriptor.value = async function(...args: any[]) {
            const cacheManager = new RedisCacheManager();
            const key = `${keyPrefix}:${propertyKey}:${JSON.stringify(args)}`;
            
            return await cacheManager.smartCache(key, async () => {
                return await originalMethod.apply(this, args);
            }, ttl);
        };
        
        return descriptor;
    };
}
```

**Compile-Test**: Backend muss kompilieren (`npm run build`)
**Validierung**: Redis-Caching ist aktiv, Smart-Caching funktioniert, Performance ist verbessert

---

### Schritt 9.2: Database-Connection-Pooling (60 min)
**Ziel**: Optimierte Datenbankverbindungen für bessere Performance

#### Backend-Implementierung:
```typescript
// Backend: src/database/OptimizedConnectionManager.ts - neue Datei

import { DataSource, DataSourceOptions } from 'typeorm';
import { Pool } from 'pg';

export class OptimizedConnectionManager {
    private dataSource: DataSource;
    private readonly pools: Map<string, Pool> = new Map();
    
    constructor() {
        this.initializeOptimizedDataSource();
    }
    
    private initializeOptimizedDataSource(): void {
        const options: DataSourceOptions = {
            type: 'postgres',
            host: process.env.DB_HOST || 'localhost',
            port: parseInt(process.env.DB_PORT || '5432'),
            username: process.env.DB_USERNAME || 'postgres',
            password: process.env.DB_PASSWORD || 'password',
            database: process.env.DB_NAME || 'journiary',
            
            // Optimierte Pool-Einstellungen
            extra: {
                max: 20, // Maximum 20 Verbindungen
                min: 5,  // Minimum 5 Verbindungen
                idleTimeoutMillis: 30000, // 30 Sekunden Idle-Timeout
                connectionTimeoutMillis: 5000, // 5 Sekunden Connection-Timeout
                maxUses: 7500, // Verbindung nach 7500 Nutzungen erneuern
                acquireTimeoutMillis: 60000, // 60 Sekunden Acquire-Timeout
                
                // Optimized PostgreSQL-spezifische Einstellungen
                application_name: 'journiary_sync',
                statement_timeout: 30000, // 30 Sekunden Statement-Timeout
                query_timeout: 25000, // 25 Sekunden Query-Timeout
                
                // Connection-Pool-Optimierungen
                poolErrorHandler: (err: Error) => {
                    console.error('Pool error:', err);
                },
                
                // Retry-Logik
                retryAttempts: 3,
                retryDelay: 1000
            },
            
            // Query-Optimierungen
            cache: {
                duration: 30000, // 30 Sekunden Query-Cache
                type: 'redis',
                options: {
                    host: process.env.REDIS_HOST || 'localhost',
                    port: parseInt(process.env.REDIS_PORT || '6379')
                }
            },
            
            // Logging für Performance-Monitoring
            logging: ['error', 'warn', 'migration'],
            maxQueryExecutionTime: 5000, // Warnung bei Queries > 5 Sekunden
            
            // Optimierte Entity-Metadaten
            synchronize: false, // Nie in Production verwenden
            migrationsRun: true,
            dropSchema: false,
            
            // Bulk-Insert-Optimierungen
            extra: {
                ...this.getBulkInsertOptimizations()
            }
        };
        
        this.dataSource = new DataSource(options);
    }
    
    // Spezialisierte Pools für verschiedene Operationen
    async createSpecializedPools(): Promise<void> {
        // Read-Only Pool für Abfragen
        const readOnlyPool = new Pool({
            host: process.env.DB_READ_HOST || process.env.DB_HOST || 'localhost',
            port: parseInt(process.env.DB_READ_PORT || process.env.DB_PORT || '5432'),
            user: process.env.DB_READ_USERNAME || process.env.DB_USERNAME || 'postgres',
            password: process.env.DB_READ_PASSWORD || process.env.DB_PASSWORD || 'password',
            database: process.env.DB_NAME || 'journiary',
            max: 15,
            min: 3,
            idleTimeoutMillis: 30000,
            connectionTimeoutMillis: 5000,
            application_name: 'journiary_read_only'
        });
        
        // Write-Heavy Pool für Sync-Operationen
        const writeHeavyPool = new Pool({
            host: process.env.DB_HOST || 'localhost',
            port: parseInt(process.env.DB_PORT || '5432'),
            user: process.env.DB_USERNAME || 'postgres',
            password: process.env.DB_PASSWORD || 'password',
            database: process.env.DB_NAME || 'journiary',
            max: 10,
            min: 2,
            idleTimeoutMillis: 20000,
            connectionTimeoutMillis: 3000,
            application_name: 'journiary_write_heavy'
        });
        
        // Analytics Pool für Reporting
        const analyticsPool = new Pool({
            host: process.env.DB_ANALYTICS_HOST || process.env.DB_HOST || 'localhost',
            port: parseInt(process.env.DB_ANALYTICS_PORT || process.env.DB_PORT || '5432'),
            user: process.env.DB_ANALYTICS_USERNAME || process.env.DB_USERNAME || 'postgres',
            password: process.env.DB_ANALYTICS_PASSWORD || process.env.DB_PASSWORD || 'password',
            database: process.env.DB_NAME || 'journiary',
            max: 5,
            min: 1,
            idleTimeoutMillis: 60000,
            connectionTimeoutMillis: 10000,
            application_name: 'journiary_analytics'
        });
        
        this.pools.set('readonly', readOnlyPool);
        this.pools.set('writeheavy', writeHeavyPool);
        this.pools.set('analytics', analyticsPool);
    }
    
    // Intelligente Connection-Auswahl
    getOptimalConnection(operationType: 'read' | 'write' | 'analytics' = 'read'): Pool | DataSource {
        switch (operationType) {
            case 'read':
                return this.pools.get('readonly') || this.dataSource;
            case 'write':
                return this.pools.get('writeheavy') || this.dataSource;
            case 'analytics':
                return this.pools.get('analytics') || this.dataSource;
            default:
                return this.dataSource;
        }
    }
    
    // Bulk-Insert-Optimierungen
    private getBulkInsertOptimizations(): any {
        return {
            // PostgreSQL-spezifische Optimierungen
            synchronous_commit: 'off', // Für bessere Bulk-Insert-Performance
            wal_buffers: '16MB',
            checkpoint_segments: 32,
            checkpoint_completion_target: 0.9,
            
            // Batch-Größen-Optimierungen
            batch_size: 1000,
            max_batch_size: 5000,
            
            // Memory-Optimierungen
            work_mem: '256MB',
            maintenance_work_mem: '256MB',
            shared_buffers: '256MB',
            
            // Connection-Optimierungen
            tcp_keepalives_idle: 600,
            tcp_keepalives_interval: 30,
            tcp_keepalives_count: 3
        };
    }
    
    // Connection-Health-Monitoring
    async monitorConnectionHealth(): Promise<ConnectionHealthStatus> {
        const pools = Array.from(this.pools.entries());
        const healthStatus: ConnectionHealthStatus = {
            totalConnections: 0,
            activeConnections: 0,
            idleConnections: 0,
            waitingConnections: 0,
            poolStatuses: []
        };
        
        for (const [name, pool] of pools) {
            const poolStatus = {
                name,
                totalCount: pool.totalCount,
                idleCount: pool.idleCount,
                waitingCount: pool.waitingCount,
                health: 'healthy' as 'healthy' | 'warning' | 'critical'
            };
            
            // Bewerte Pool-Gesundheit
            const utilization = (pool.totalCount - pool.idleCount) / pool.totalCount;
            if (utilization > 0.9) {
                poolStatus.health = 'critical';
            } else if (utilization > 0.7) {
                poolStatus.health = 'warning';
            }
            
            healthStatus.totalConnections += pool.totalCount;
            healthStatus.activeConnections += (pool.totalCount - pool.idleCount);
            healthStatus.idleConnections += pool.idleCount;
            healthStatus.waitingConnections += pool.waitingCount;
            healthStatus.poolStatuses.push(poolStatus);
        }
        
        return healthStatus;
    }
    
    // Graceful Shutdown
    async gracefulShutdown(): Promise<void> {
        console.log('Initiating graceful database shutdown...');
        
        // Schließe alle Pools
        for (const [name, pool] of this.pools) {
            console.log(`Closing pool: ${name}`);
            await pool.end();
        }
        
        // Schließe Haupt-DataSource
        if (this.dataSource.isInitialized) {
            await this.dataSource.destroy();
        }
        
        console.log('Database shutdown complete.');
    }
}

// Interfaces
interface ConnectionHealthStatus {
    totalConnections: number;
    activeConnections: number;
    idleConnections: number;
    waitingConnections: number;
    poolStatuses: PoolStatus[];
}

interface PoolStatus {
    name: string;
    totalCount: number;
    idleCount: number;
    waitingCount: number;
    health: 'healthy' | 'warning' | 'critical';
}
```

**Compile-Test**: Backend muss kompilieren (`npm run build`)
**Validierung**: Connection-Pooling ist optimiert, Spezialisierte Pools funktionieren, Health-Monitoring ist aktiv

---

### Schritt 9.3: GraphQL-Optimierungen (75 min)
**Ziel**: N+1-Problem lösen und Query-Performance verbessern

#### Backend-Implementierung:
```typescript
// Backend: src/graphql/OptimizedResolvers.ts - neue Datei

import { Resolver, Query, Mutation, Arg, Ctx, FieldResolver, Root } from 'type-graphql';
import { Service } from 'typedi';
import DataLoader from 'dataloader';

@Service()
@Resolver(of => Trip)
export class OptimizedTripResolver {
    private memoryLoader: DataLoader<string, Memory[]>;
    private mediaItemLoader: DataLoader<string, MediaItem[]>;
    private tagLoader: DataLoader<string, Tag[]>;
    
    constructor() {
        this.initializeDataLoaders();
    }
    
    private initializeDataLoaders(): void {
        // Memory-Loader für Trips
        this.memoryLoader = new DataLoader<string, Memory[]>(
            async (tripIds: readonly string[]) => {
                const memories = await Memory.find({
                    where: { tripId: In(tripIds as string[]) },
                    relations: ['trip']
                });
                
                // Gruppiere nach tripId
                const memoryMap = new Map<string, Memory[]>();
                for (const memory of memories) {
                    const tripId = memory.tripId;
                    if (!memoryMap.has(tripId)) {
                        memoryMap.set(tripId, []);
                    }
                    memoryMap.get(tripId)!.push(memory);
                }
                
                return tripIds.map(tripId => memoryMap.get(tripId) || []);
            },
            {
                cache: true,
                batchScheduleFn: callback => setTimeout(callback, 1), // 1ms Batch-Delay
                maxBatchSize: 100
            }
        );
        
        // MediaItem-Loader für Memories
        this.mediaItemLoader = new DataLoader<string, MediaItem[]>(
            async (memoryIds: readonly string[]) => {
                const mediaItems = await MediaItem.find({
                    where: { memoryId: In(memoryIds as string[]) },
                    relations: ['memory']
                });
                
                const mediaMap = new Map<string, MediaItem[]>();
                for (const item of mediaItems) {
                    const memoryId = item.memoryId;
                    if (!mediaMap.has(memoryId)) {
                        mediaMap.set(memoryId, []);
                    }
                    mediaMap.get(memoryId)!.push(item);
                }
                
                return memoryIds.map(memoryId => mediaMap.get(memoryId) || []);
            },
            {
                cache: true,
                batchScheduleFn: callback => setTimeout(callback, 1),
                maxBatchSize: 200
            }
        );
        
        // Tag-Loader mit Caching
        this.tagLoader = new DataLoader<string, Tag[]>(
            async (entityIds: readonly string[]) => {
                const tagAssignments = await TagAssignment.find({
                    where: { entityId: In(entityIds as string[]) },
                    relations: ['tag']
                });
                
                const tagMap = new Map<string, Tag[]>();
                for (const assignment of tagAssignments) {
                    const entityId = assignment.entityId;
                    if (!tagMap.has(entityId)) {
                        tagMap.set(entityId, []);
                    }
                    tagMap.get(entityId)!.push(assignment.tag);
                }
                
                return entityIds.map(entityId => tagMap.get(entityId) || []);
            },
            {
                cache: true,
                cacheKeyFn: (entityId: string) => `tags:${entityId}`,
                batchScheduleFn: callback => setTimeout(callback, 1),
                maxBatchSize: 150
            }
        );
    }
    
    @Query(() => [Trip])
    async tripsOptimized(
        @Arg('userId') userId: string,
        @Arg('limit', { defaultValue: 50 }) limit: number,
        @Arg('offset', { defaultValue: 0 }) offset: number,
        @Ctx() context: any
    ): Promise<Trip[]> {
        // Verwende Query-Builder für komplexe Abfragen
        const queryBuilder = Trip.createQueryBuilder('trip')
            .leftJoinAndSelect('trip.memories', 'memory')
            .leftJoinAndSelect('memory.mediaItems', 'mediaItem')
            .leftJoinAndSelect('trip.tags', 'tag')
            .where('trip.userId = :userId', { userId })
            .orderBy('trip.createdAt', 'DESC')
            .limit(limit)
            .offset(offset);
        
        // Füge Caching-Hint hinzu
        queryBuilder.cache(`trips:${userId}:${limit}:${offset}`, 300000); // 5 Minuten Cache
        
        return await queryBuilder.getMany();
    }
    
    @FieldResolver(() => [Memory])
    async memories(@Root() trip: Trip): Promise<Memory[]> {
        return await this.memoryLoader.load(trip.id);
    }
    
    @FieldResolver(() => [Tag])
    async tags(@Root() trip: Trip): Promise<Tag[]> {
        return await this.tagLoader.load(trip.id);
    }
    
    @Mutation(() => Trip)
    async createTripOptimized(
        @Arg('input') input: TripInput,
        @Ctx() context: any
    ): Promise<Trip> {
        // Verwende Transaction für atomare Operationen
        return await Trip.transaction(async manager => {
            const trip = manager.create(Trip, input);
            await manager.save(trip);
            
            // Invalidiere relevante Caches
            await this.invalidateRelatedCaches(trip);
            
            return trip;
        });
    }
    
    // Erweiterte Sync-Query mit Optimierungen
    @Query(() => SyncResponse)
    async syncOptimized(
        @Arg('lastSync', { nullable: true }) lastSync?: Date,
        @Arg('entityTypes', () => [String], { nullable: true }) entityTypes?: string[],
        @Arg('limit', { defaultValue: 1000 }) limit: number,
        @Ctx() context: any
    ): Promise<SyncResponse> {
        const userId = context.user.id;
        const syncTimestamp = new Date();
        
        // Baue Union-Query für alle Entity-Typen
        const entities = await this.buildOptimizedSyncQuery(
            userId,
            lastSync,
            entityTypes,
            limit
        );
        
        // Preload verwandte Daten mit DataLoader
        await this.preloadRelatedData(entities);
        
        return {
            entities,
            timestamp: syncTimestamp,
            hasMore: entities.length === limit
        };
    }
    
    private async buildOptimizedSyncQuery(
        userId: string,
        lastSync?: Date,
        entityTypes?: string[],
        limit: number = 1000
    ): Promise<any[]> {
        const baseQuery = `
            SELECT 
                'trip' as entityType,
                id,
                title,
                description,
                created_at,
                updated_at,
                deleted_at
            FROM trips 
            WHERE user_id = $1
        `;
        
        const conditions = [];
        const params = [userId];
        
        if (lastSync) {
            conditions.push(`updated_at > $${params.length + 1}`);
            params.push(lastSync);
        }
        
        if (entityTypes && entityTypes.length > 0) {
            conditions.push(`'trip' = ANY($${params.length + 1})`);
            params.push(entityTypes);
        }
        
        const whereClause = conditions.length > 0 ? `AND ${conditions.join(' AND ')}` : '';
        
        // Union mit anderen Entity-Typen
        const unionQuery = `
            ${baseQuery} ${whereClause}
            
            UNION ALL
            
            SELECT 
                'memory' as entityType,
                m.id,
                m.title,
                m.description,
                m.created_at,
                m.updated_at,
                m.deleted_at
            FROM memories m
            JOIN trips t ON m.trip_id = t.id
            WHERE t.user_id = $1 ${whereClause.replace('updated_at', 'm.updated_at')}
            
            ORDER BY updated_at DESC
            LIMIT $${params.length + 1}
        `;
        
        params.push(limit);
        
        return await this.executeRawQuery(unionQuery, params);
    }
    
    private async preloadRelatedData(entities: any[]): Promise<void> {
        const tripIds = entities.filter(e => e.entityType === 'trip').map(e => e.id);
        const memoryIds = entities.filter(e => e.entityType === 'memory').map(e => e.id);
        
        // Preload Memories für Trips
        if (tripIds.length > 0) {
            await Promise.all(tripIds.map(id => this.memoryLoader.load(id)));
        }
        
        // Preload MediaItems für Memories
        if (memoryIds.length > 0) {
            await Promise.all(memoryIds.map(id => this.mediaItemLoader.load(id)));
        }
        
        // Preload Tags für alle Entities
        const allEntityIds = entities.map(e => e.id);
        if (allEntityIds.length > 0) {
            await Promise.all(allEntityIds.map(id => this.tagLoader.load(id)));
        }
    }
    
    private async invalidateRelatedCaches(trip: Trip): Promise<void> {
        // Invalidiere DataLoader-Caches
        this.memoryLoader.clear(trip.id);
        this.tagLoader.clear(trip.id);
        
        // Invalidiere Redis-Caches
        const cacheManager = new RedisCacheManager();
        await cacheManager.invalidateCache(`trips:${trip.userId}:*`);
        await cacheManager.invalidateCache(`user:${trip.userId}:*`);
    }
    
    private async executeRawQuery(query: string, params: any[]): Promise<any[]> {
        const connection = getConnection();
        return await connection.query(query, params);
    }
}

// Query-Komplexitäts-Analyzer
export class QueryComplexityAnalyzer {
    static analyzeComplexity(query: string): QueryComplexity {
        const complexity = {
            score: 0,
            factors: [],
            recommendations: []
        };
        
        // Analysiere Joins
        const joinMatches = query.match(/JOIN/gi);
        if (joinMatches) {
            complexity.score += joinMatches.length * 2;
            complexity.factors.push(`${joinMatches.length} joins found`);
        }
        
        // Analysiere Subqueries
        const subqueryMatches = query.match(/\(SELECT/gi);
        if (subqueryMatches) {
            complexity.score += subqueryMatches.length * 3;
            complexity.factors.push(`${subqueryMatches.length} subqueries found`);
        }
        
        // Analysiere DISTINCT
        if (query.includes('DISTINCT')) {
            complexity.score += 2;
            complexity.factors.push('DISTINCT operation');
        }
        
        // Analysiere ORDER BY
        if (query.includes('ORDER BY')) {
            complexity.score += 1;
            complexity.factors.push('ORDER BY clause');
        }
        
        // Empfehlungen basierend auf Komplexität
        if (complexity.score > 10) {
            complexity.recommendations.push('Consider using DataLoader for related data');
            complexity.recommendations.push('Add database indexes for frequently queried columns');
        }
        
        if (complexity.score > 15) {
            complexity.recommendations.push('Consider query optimization or caching');
            complexity.recommendations.push('Break down complex query into simpler ones');
        }
        
        return complexity;
    }
}

interface QueryComplexity {
    score: number;
    factors: string[];
    recommendations: string[];
}
```

**Compile-Test**: Backend muss kompilieren (`npm run build`)
**Validierung**: DataLoader funktioniert, N+1-Problem ist gelöst, Query-Performance ist verbessert

---

*Dieser erweiterte Plan integriert umfassende Backend-Verbesserungen für eine hochperformante, skalierbare Synchronisations-Architektur.* 