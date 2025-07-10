//
//  EnhancedSyncProtocols.swift
//  Journiary
//
//  Created by Assistant on 10.07.25.
//  Implementation of Step 1.3: Basis-Protokoll für erweiterte Synchronisation
//

import Foundation
import CoreData

/// Erweiterte Synchronisations-Funktionalität für Core Data Entitäten
/// Implementiert als Teil von Schritt 1.3 des Sync-Implementierungsplans
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

/// Protokoll für Validatoren in der Synchronisation
protocol SyncValidator {
    func validate<T: EnhancedSynchronizable>(_ entity: T) throws
}

/// Protokoll für Transaktions-Provider in der Synchronisation
protocol SyncTransactionProvider {
    func performTransaction<T>(_ operation: @escaping () throws -> T) throws -> T
}

/// Standard-Implementierung des SyncValidator für Basis-Validierungen
/// Implementiert grundlegende Validierungsregeln für Synchronisation
class DefaultSyncValidator: SyncValidator {
    
    /// Führt Basis-Validierung für synchronisierbare Entitäten durch
    /// - Parameter entity: Die zu validierende Entität
    /// - Throws: SyncError bei Validierungsfehlern
    func validate<T: EnhancedSynchronizable>(_ entity: T) throws {
        // Basis-Validierung: Server-ID darf nicht leer sein, wenn gesetzt
        if let serverId = entity.serverId, serverId.isEmpty {
            throw SyncError.dataError("Server-ID ist leer")
        }
        
        // Weitere Basis-Validierungen können hier hinzugefügt werden
        if entity.createdAt == nil {
            throw SyncError.dataError("Erstellungsdatum fehlt")
        }
        
        if entity.updatedAt == nil {
            throw SyncError.dataError("Aktualisierungsdatum fehlt")
        }
    }
} 