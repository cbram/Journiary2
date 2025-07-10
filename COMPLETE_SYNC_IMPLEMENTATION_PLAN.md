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

## Weitere Phasen

**Phase 5 (Woche 5)**: Conflict Resolution mit kleinschrittiger Implementierung
**Phase 6 (Woche 6)**: Performance-Optimierungen
**Phase 7 (Woche 7)**: Monitoring & Debugging
**Phase 8 (Woche 8)**: Testing & Validierung

## Erfolgskriterien für jeden Schritt

1. **Kompilierung**: Projekt muss nach jedem Schritt kompilieren
2. **Rückwärtskompatibilität**: Bestehende Funktionalität darf nicht beeinträchtigt werden
3. **Testbarkeit**: Jede neue Komponente muss testbar sein
4. **Dokumentation**: Jede Änderung muss dokumentiert werden

## Rollback-Strategie

- **Git-Branch**: Jeder Schritt wird in eigenem Branch entwickelt
- **Backup**: Vor größeren Änderungen wird Backup erstellt
- **Schrittweise Integration**: Neue Features werden schrittweise integriert

---

*Dieser Plan gewährleistet eine schrittweise, sichere Implementierung ohne Risiko von Compile-Fehlern oder Funktionalitätsverlust.* 