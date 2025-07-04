//
//  SyncChangeObserver.swift
//  Journiary
//
//  Beobachtet Core-Data-Änderungen und erstellt entsprechende SyncOperation-Einträge.
//  Damit wird die Offline-Warteschlange (1.1) real genutzt.
//

import CoreData
import os
import Foundation

final class SyncChangeObserver {
    static let shared = SyncChangeObserver()

    private let logger = Logger(subsystem: "com.journiary.sync", category: "changeObserver")
    private let queue = SyncQueue.shared

    private init() {
        // Haupt- & Hintergrund-Context überwachen
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
        logger.debug("SyncChangeObserver initialisiert und hört auf NSManagedObjectContextDidSave")
    }

    @objc private func contextDidSave(_ note: Notification) {
        guard let userInfo = note.userInfo else { return }
        if let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> {
            inserts.forEach { handle(object: $0, type: .create) }
        }
        if let updates = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            updates.forEach { handle(object: $0, type: .update) }
        }
        if let deletes = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> {
            deletes.forEach { handle(object: $0, type: .delete) }
        }
    }

    private func handle(object: NSManagedObject, type: SyncOperationType) {
        // Nur synchronisierbare Entitäten berücksichtigen (Trip, Memory)
        guard let entityName = object.entity.name, ["Trip", "Memory"].contains(entityName) else { return }

        // Identifier bestimmen (serverId oder fallback localId)
        let identifier = object.serverId ?? object.localId.uuidString

        // Payload nur bei Create/Update
        var payload: Data? = nil
        if type != .delete {
            do {
                let dict = object.dictionaryWithValues(forKeys: Array(object.entity.attributesByName.keys))
                payload = try JSONSerialization.data(withJSONObject: dict)
            } catch {
                logger.error("Konnte Payload nicht serialisieren: \(error.localizedDescription)")
            }
        }

        let op = SyncOperation(entityName: entityName, entityId: identifier, operationType: type, payload: payload)
        queue.addOperation(op)
        logger.debug("📥 Neuer Queue-Eintrag: {entity=\(entityName), type=\(type.rawValue)}")
    }
} 