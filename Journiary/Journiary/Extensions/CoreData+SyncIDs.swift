//
//  CoreData+SyncIDs.swift
//  Journiary
//
//  Zentrale Helper, um die neue "localId" / "id"-Logik umzusetzen,
//  ohne dass wir alle Core-Data-Modelle sofort umbauen müssen.
//  Unterstützt folgende Szenarien:
//  • localId  (UUID)   – bevorzugt, falls Attribut existiert.
//  • id       (UUID)   – Legacy-Fall → wird als localId betrachtet.
//  • backendId(String) – Legacy-Server-ID → wird als id betrachtet.
//

import CoreData
import Foundation
import os

private let idLogger = Logger(subsystem: "com.journiary.sync", category: "coredata-id")

extension NSManagedObject {
    /// Liefert eine UUID, die als *lokaler* Primärschlüssel dient.
    /// Falls keine vorhanden ist, wird sie erstellt und gespeichert.
    @objc var localId: UUID {
        get {
            // 1) Neues Attribut "localId"
            if entity.attributesByName.keys.contains("localId"),
               let uuid = value(forKey: "localId") as? UUID {
                return uuid
            }
            // 2) Legacy-Fall: "id" war bisher UUID
            if entity.attributesByName.keys.contains("id"),
               let uuid = value(forKey: "id") as? UUID {
                return uuid
            }
            // 3) Fallback – generiere neue UUID und speichere sie (wenn möglich)
            let newId = UUID()
            if entity.attributesByName.keys.contains("localId") {
                setValue(newId, forKey: "localId")
            } else if entity.attributesByName.keys.contains("id") {
                setValue(newId, forKey: "id")
            }
            return newId
        }
        set {
            if entity.attributesByName.keys.contains("localId") {
                setValue(newValue, forKey: "localId")
            } else if entity.attributesByName.keys.contains("id") {
                setValue(newValue, forKey: "id")
            } else {
                idLogger.error("[localId] Attribut in \(entity.name ?? "?") nicht gefunden – konnte Wert nicht setzen")
            }
        }
    }

    /// Server-seitige ID → String
    @objc var serverId: String? {
        get {
            // 1) Neues Attribut "id" (String)
            if entity.attributesByName.keys.contains("id"),
               let str = value(forKey: "id") as? String, !str.isEmpty {
                return str
            }
            // 2) Legacy-Fall: "backendId"
            if entity.attributesByName.keys.contains("backendId") {
                return value(forKey: "backendId") as? String
            }
            return nil
        }
        set {
            if entity.attributesByName.keys.contains("id") {
                setValue(newValue, forKey: "id")
            } else if entity.attributesByName.keys.contains("backendId") {
                setValue(newValue, forKey: "backendId")
            } else {
                idLogger.error("[serverId] Attribut in \(entity.name ?? "?") nicht gefunden – konnte Wert nicht setzen")
            }
        }
    }
} 