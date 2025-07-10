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
    
    // MARK: - Conflict Detection (aus Schritt 6.2)
    
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
    
    // MARK: - Erweiterte Conflict Detection
    
    /**
     * Erkennt automatisch Konflikte zwischen lokalen und Remote-Entitäten
     */
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
    
    /**
     * Findet Felder mit unterschiedlichen Werten zwischen lokaler und Remote-Entität
     */
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
    
    /**
     * Vergleicht zwei Values auf Gleichheit mit spezieller Behandlung für verschiedene Datentypen
     */
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
        case let (bool1 as Bool, bool2 as Bool):
            return bool1 == bool2
        case let (uuid1 as UUID, uuid2 as UUID):
            return uuid1 == uuid2
        default:
            return false
        }
    }
    
    // MARK: - Erweiterte Last-Write-Wins Implementation
    
    /**
     * Erweiterte Last-Write-Wins Logik mit detaillierten Konflikt-Informationen
     */
    func resolveConflictWithDetection<T: NSManagedObject>(
        localEntity: T,
        remoteEntity: T,
        strategy: ConflictResolutionStrategy = .lastWriteWins
    ) async throws -> ConflictResult {
        
        // Erster Schritt: Konflikte erkennen
        let detection = detectConflict(localEntity: localEntity, remoteEntity: remoteEntity)
        
        // Logging für Debug-Zwecke
        if detection.hasConflict {
            print("⚠️ Konflikt erkannt: \(detection.conflictType)")
            print("   └─ Betroffene Felder: \(detection.conflictedFields.joined(separator: ", "))")
            print("   └─ Local: \(detection.localVersion)")
            print("   └─ Remote: \(detection.remoteVersion)")
        } else {
            print("✅ Kein Konflikt erkannt zwischen lokaler und Remote-Entität")
        }
        
        // Zweiter Schritt: Konflikt auflösen
        var result = try await resolveConflict(
            localEntity: localEntity,
            remoteEntity: remoteEntity,
            strategy: strategy
        )
        
        // Erweitere Konflikt-Details um Detection-Informationen
        if detection.hasConflict {
            result = ConflictResult(
                resolvedEntity: result.resolvedEntity,
                strategy: result.strategy,
                conflictDetails: "\(result.conflictDetails) | Conflict Type: \(detection.conflictType), Fields: \(detection.conflictedFields.joined(separator: ", "))"
            )
        }
        
        return result
    }
    
    // MARK: - Utility Methods
    
    /**
     * Prüft ob zwei Entitäten die gleiche UUID haben (für Konsistenz-Validierung)
     */
    func entitiesRepresentSameObject<T: NSManagedObject>(_ entity1: T, _ entity2: T) -> Bool {
        if let serverId1 = entity1.value(forKey: "serverId") as? String,
           let serverId2 = entity2.value(forKey: "serverId") as? String {
            return serverId1 == serverId2
        }
        return false
    }
    
    /**
     * Erstellt einen Hash für eine Entität basierend auf ihren Werten (für Change-Detection)
     */
    func createEntityHash<T: NSManagedObject>(for entity: T) -> String {
        let entityDescription = entity.entity
        var hashComponents: [String] = []
        
        for attribute in entityDescription.attributesByName.sorted(by: { $0.key < $1.key }) {
            let fieldName = attribute.key
            if let value = entity.value(forKey: fieldName) {
                hashComponents.append("\(fieldName):\(value)")
            }
        }
        
        return hashComponents.joined(separator: "|").hashValue.description
    }
} 