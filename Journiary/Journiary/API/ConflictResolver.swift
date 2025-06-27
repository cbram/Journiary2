//
//  ConflictResolver.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import CoreData

/// Strategie zur Auflösung von Konflikten
enum ConflictResolutionStrategy {
    case localWins
    case remoteWins
    case manual
    case newerWins
}

/// Typ des Konflikts
enum ConflictType {
    case create
    case update
    case delete
}

/// Ein Konflikt zwischen lokalen und Remote-Daten
struct Conflict {
    let entityType: String
    let entityId: String
    let conflictType: ConflictType
    let localVersion: Date
    let remoteVersion: Date
    let localData: [String: Any]
    let remoteData: [String: Any]
}

/// Manager für die Erkennung und Auflösung von Konflikten
class ConflictResolver: ObservableObject {
    static let shared = ConflictResolver()
    
    @Published var conflicts: [Conflict] = []
    @Published var resolutionStrategy: ConflictResolutionStrategy = .newerWins
    
    private let settings = AppSettings.shared
    
    private init() {
        // Lade die Konfliktstrategie aus den Einstellungen
        if let savedStrategy = UserDefaults.standard.string(forKey: "conflictResolutionStrategy") {
            switch savedStrategy {
            case "localWins":
                resolutionStrategy = .localWins
            case "remoteWins":
                resolutionStrategy = .remoteWins
            case "manual":
                resolutionStrategy = .manual
            case "newerWins":
                resolutionStrategy = .newerWins
            default:
                resolutionStrategy = .newerWins
            }
        }
    }
    
    /// Setzt die Konfliktstrategie
    /// - Parameter strategy: Die neue Strategie
    func setResolutionStrategy(_ strategy: ConflictResolutionStrategy) {
        resolutionStrategy = strategy
        
        // Speichere die Strategie in den Einstellungen
        let strategyString: String
        switch strategy {
        case .localWins:
            strategyString = "localWins"
        case .remoteWins:
            strategyString = "remoteWins"
        case .manual:
            strategyString = "manual"
        case .newerWins:
            strategyString = "newerWins"
        }
        
        UserDefaults.standard.set(strategyString, forKey: "conflictResolutionStrategy")
    }
    
    /// Erkennt Konflikte zwischen lokalen und Remote-Daten
    /// - Parameters:
    ///   - localEntity: Die lokale Entität
    ///   - remoteData: Die Remote-Daten
    ///   - entityType: Der Typ der Entität
    /// - Returns: Ein Konflikt, wenn einer erkannt wurde, sonst nil
    func detectConflict(localEntity: NSManagedObject, remoteData: [String: Any], entityType: String) -> Conflict? {
        guard let localId = localEntity.value(forKey: "id") as? UUID,
              let localModified = localEntity.value(forKey: "modifiedAt") as? Date,
              let remoteId = remoteData["id"] as? String,
              let remoteModified = remoteData["modifiedAt"] as? Date else {
            return nil
        }
        
        // Prüfe, ob die IDs übereinstimmen
        guard localId.uuidString == remoteId else {
            return nil
        }
        
        // Prüfe, ob die Änderungsdaten unterschiedlich sind
        guard localModified != remoteModified else {
            return nil
        }
        
        // Erstelle ein Dictionary mit den lokalen Daten
        let localData = localEntityToDictionary(localEntity)
        
        // Erstelle einen Konflikt
        let conflictType: ConflictType = .update // Für jetzt nehmen wir immer .update an
        
        return Conflict(
            entityType: entityType,
            entityId: localId.uuidString,
            conflictType: conflictType,
            localVersion: localModified,
            remoteVersion: remoteModified,
            localData: localData,
            remoteData: remoteData
        )
    }
    
    /// Löst einen Konflikt basierend auf der aktuellen Strategie auf
    /// - Parameters:
    ///   - conflict: Der aufzulösende Konflikt
    ///   - context: Der NSManagedObjectContext
    /// - Returns: Die aufgelösten Daten
    func resolveConflict(_ conflict: Conflict, context: NSManagedObjectContext) -> [String: Any] {
        switch resolutionStrategy {
        case .localWins:
            return conflict.localData
        case .remoteWins:
            return conflict.remoteData
        case .manual:
            // Bei manueller Auflösung fügen wir den Konflikt zur Liste hinzu
            // und geben die lokalen Daten zurück, bis der Benutzer entscheidet
            if !conflicts.contains(where: { $0.entityId == conflict.entityId }) {
                conflicts.append(conflict)
            }
            return conflict.localData
        case .newerWins:
            return conflict.localVersion > conflict.remoteVersion ? conflict.localData : conflict.remoteData
        }
    }
    
    /// Löst einen Konflikt manuell auf
    /// - Parameters:
    ///   - conflictId: Die ID des Konflikts
    ///   - useLocalData: Ob die lokalen Daten verwendet werden sollen
    /// - Returns: Die aufgelösten Daten oder nil, wenn der Konflikt nicht gefunden wurde
    func resolveManually(conflictId: String, useLocalData: Bool) -> [String: Any]? {
        guard let index = conflicts.firstIndex(where: { $0.entityId == conflictId }) else {
            return nil
        }
        
        let conflict = conflicts[index]
        conflicts.remove(at: index)
        
        return useLocalData ? conflict.localData : conflict.remoteData
    }
    
    /// Konvertiert eine lokale Entität in ein Dictionary
    /// - Parameter entity: Die zu konvertierende Entität
    /// - Returns: Ein Dictionary mit den Daten der Entität
    private func localEntityToDictionary(_ entity: NSManagedObject) -> [String: Any] {
        var dict = [String: Any]()
        
        for attribute in entity.entity.attributesByName {
            if let value = entity.value(forKey: attribute.key) {
                dict[attribute.key] = value
            }
        }
        
        return dict
    }
}

// MARK: - Extensions

extension NSManagedObject {
    /// Aktualisiert die Entität mit den gegebenen Daten
    /// - Parameter data: Die Daten, mit denen die Entität aktualisiert werden soll
    func update(with data: [String: Any]) {
        for (key, value) in data {
            if entity.attributesByName[key] != nil {
                setValue(value, forKey: key)
            }
        }
    }
} 