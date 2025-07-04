//
//  SyncOperation.swift
//  Journiary
//
//  Erstellt als Teil der neuen, strukturierten Sync-Architektur (Schritt 1.1)
//
//  Dieses Modell bildet einen einzelnen, noch nicht mit dem Backend
//  synchronisierten Vorgang ab (Create/Update/Delete).
//  Die Warteschlange dieser Objekte ermöglicht Offline-Fähigkeit.
//

import Foundation

/// Art des auszuführenden Sync-Vorgangs
enum SyncOperationType: String, Codable {
    case create
    case update
    case delete
}

/// Ein einzelner Eintrag in der lokalen Sync-Warteschlange.
/// Wird persistiert, bis der Vorgang erfolgreich ans Backend übertragen wurde.
struct SyncOperation: Codable, Identifiable {
    let id: UUID
    let entityName: String        // Core-Data-Entity, z.B. "Memory"
    let entityId: String          // `id` (Backend) oder `localId` (Core-Data) – eindeutig
    let operationType: SyncOperationType
    let payload: Data?            // Optional: JSON-Payload bei create/update
    let createdAt: Date

    init(entityName: String,
         entityId: String,
         operationType: SyncOperationType,
         payload: Data? = nil,
         createdAt: Date = Date()) {
        self.id = UUID()
        self.entityName = entityName
        self.entityId = entityId
        self.operationType = operationType
        self.payload = payload
        self.createdAt = createdAt

} 