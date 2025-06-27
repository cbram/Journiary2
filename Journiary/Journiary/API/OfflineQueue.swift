//
//  OfflineQueue.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import CoreData

/// Typ der Operation in der Offline-Warteschlange
enum OfflineOperationType: String, Codable {
    case create
    case update
    case delete
}

/// Entitätstyp für die Offline-Warteschlange
enum OfflineEntityType: String, Codable {
    case trip
    case memory
    case mediaItem
    case tag
    case tagCategory
    case bucketListItem
}

/// Eine Operation in der Offline-Warteschlange
struct OfflineOperation: Identifiable, Codable {
    let id: UUID
    let entityType: OfflineEntityType
    let entityId: String
    let operationType: OfflineOperationType
    let data: Data?
    let createdAt: Date
    let priority: Int
    
    init(entityType: OfflineEntityType, entityId: String, operationType: OfflineOperationType, data: [String: Any]? = nil, priority: Int = 0) {
        self.id = UUID()
        self.entityType = entityType
        self.entityId = entityId
        self.operationType = operationType
        self.createdAt = Date()
        self.priority = priority
        
        // Konvertiere das Dictionary in Data, wenn vorhanden
        if let data = data {
            self.data = try? JSONSerialization.data(withJSONObject: data, options: [])
        } else {
            self.data = nil
        }
    }
}

/// Manager für die Offline-Warteschlange
class OfflineQueue: ObservableObject {
    static let shared = OfflineQueue()
    
    @Published var operations: [OfflineOperation] = []
    @Published var isProcessing = false
    
    private let settings = AppSettings.shared
    private let userDefaults = UserDefaults.standard
    private let queueKey = "offlineQueueOperations"
    
    private init() {
        loadQueue()
    }
    
    /// Lädt die Warteschlange aus den UserDefaults
    private func loadQueue() {
        if let data = userDefaults.data(forKey: queueKey),
           let decodedOperations = try? JSONDecoder().decode([OfflineOperation].self, from: data) {
            operations = decodedOperations
        }
    }
    
    /// Speichert die Warteschlange in den UserDefaults
    private func saveQueue() {
        if let encodedData = try? JSONEncoder().encode(operations) {
            userDefaults.set(encodedData, forKey: queueKey)
        }
    }
    
    /// Fügt eine Operation zur Warteschlange hinzu
    /// - Parameters:
    ///   - entityType: Der Typ der Entität
    ///   - entityId: Die ID der Entität
    ///   - operationType: Der Typ der Operation
    ///   - data: Die Daten für die Operation (optional)
    ///   - priority: Die Priorität der Operation (höhere Werte = höhere Priorität)
    func addOperation(entityType: OfflineEntityType, entityId: String, operationType: OfflineOperationType, data: [String: Any]? = nil, priority: Int = 0) {
        let operation = OfflineOperation(entityType: entityType, entityId: entityId, operationType: operationType, data: data, priority: priority)
        
        // Entferne vorherige Operationen für dieselbe Entität
        operations.removeAll { $0.entityId == entityId && $0.entityType == entityType }
        
        // Füge die neue Operation hinzu
        operations.append(operation)
        
        // Sortiere die Warteschlange nach Priorität und dann nach Erstellungsdatum
        operations.sort { 
            if $0.priority == $1.priority {
                return $0.createdAt < $1.createdAt
            }
            return $0.priority > $1.priority
        }
        
        // Speichere die aktualisierte Warteschlange
        saveQueue()
    }
    
    /// Entfernt eine Operation aus der Warteschlange
    /// - Parameter operationId: Die ID der zu entfernenden Operation
    func removeOperation(operationId: UUID) {
        operations.removeAll { $0.id == operationId }
        saveQueue()
    }
    
    /// Verarbeitet die Warteschlange, wenn eine Verbindung verfügbar ist
    /// - Parameters:
    ///   - context: Der NSManagedObjectContext
    ///   - completion: Der Abschlusshandler mit dem Erfolg der Verarbeitung
    func processQueue(context: NSManagedObjectContext, completion: @escaping (Bool) -> Void) {
        guard !operations.isEmpty && !isProcessing else {
            completion(true)
            return
        }
        
        isProcessing = true
        
        // Kopiere die Operationen, um während der Verarbeitung Änderungen zu vermeiden
        let operationsToProcess = operations
        
        // Verarbeite jede Operation
        var success = true
        let group = DispatchGroup()
        
        for operation in operationsToProcess {
            group.enter()
            
            processOperation(operation, context: context) { result in
                if result {
                    // Bei Erfolg entferne die Operation aus der Warteschlange
                    DispatchQueue.main.async {
                        self.removeOperation(operationId: operation.id)
                    }
                } else {
                    success = false
                }
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.isProcessing = false
            completion(success)
        }
    }
    
    /// Verarbeitet eine einzelne Operation
    /// - Parameters:
    ///   - operation: Die zu verarbeitende Operation
    ///   - context: Der NSManagedObjectContext
    ///   - completion: Der Abschlusshandler mit dem Erfolg der Verarbeitung
    private func processOperation(_ operation: OfflineOperation, context: NSManagedObjectContext, completion: @escaping (Bool) -> Void) {
        // Hier würde die tatsächliche API-Kommunikation stattfinden
        // Dies ist eine vereinfachte Version, die je nach Entitätstyp und Operationstyp
        // die entsprechende API-Anfrage durchführen würde
        
        // Beispiel für eine allgemeine Verarbeitung:
        let apiClient = APIClient.shared
        
        // Konvertiere die Daten zurück in ein Dictionary, wenn vorhanden
        var data: [String: Any]?
        if let operationData = operation.data {
            data = try? JSONSerialization.jsonObject(with: operationData, options: []) as? [String: Any]
        }
        
        switch operation.operationType {
        case .create:
            // Erstelle die Entität auf dem Server
            createEntity(operation.entityType, data: data, completion: completion)
            
        case .update:
            // Aktualisiere die Entität auf dem Server
            updateEntity(operation.entityType, entityId: operation.entityId, data: data, completion: completion)
            
        case .delete:
            // Lösche die Entität auf dem Server
            deleteEntity(operation.entityType, entityId: operation.entityId, completion: completion)
        }
    }
    
    // MARK: - API-Operationen
    
    /// Erstellt eine Entität auf dem Server
    /// - Parameters:
    ///   - entityType: Der Typ der Entität
    ///   - data: Die Daten für die Erstellung
    ///   - completion: Der Abschlusshandler mit dem Erfolg der Operation
    private func createEntity(_ entityType: OfflineEntityType, data: [String: Any]?, completion: @escaping (Bool) -> Void) {
        guard let data = data else {
            completion(false)
            return
        }
        
        let apiClient = APIClient.shared
        
        switch entityType {
        case .trip:
            apiClient.createTrip(data: data) { result in
                completion(result != nil)
            }
            
        case .memory:
            apiClient.createMemory(data: data) { result in
                completion(result != nil)
            }
            
        case .mediaItem:
            apiClient.createMediaItem(data: data) { result in
                completion(result != nil)
            }
            
        case .tag:
            apiClient.createTag(data: data) { result in
                completion(result != nil)
            }
            
        case .tagCategory:
            apiClient.createTagCategory(data: data) { result in
                completion(result != nil)
            }
            
        case .bucketListItem:
            apiClient.createBucketListItem(data: data) { result in
                completion(result != nil)
            }
        }
    }
    
    /// Aktualisiert eine Entität auf dem Server
    /// - Parameters:
    ///   - entityType: Der Typ der Entität
    ///   - entityId: Die ID der Entität
    ///   - data: Die Daten für die Aktualisierung
    ///   - completion: Der Abschlusshandler mit dem Erfolg der Operation
    private func updateEntity(_ entityType: OfflineEntityType, entityId: String, data: [String: Any]?, completion: @escaping (Bool) -> Void) {
        guard let data = data else {
            completion(false)
            return
        }
        
        let apiClient = APIClient.shared
        
        switch entityType {
        case .trip:
            apiClient.updateTrip(id: entityId, data: data) { result in
                completion(result != nil)
            }
            
        case .memory:
            apiClient.updateMemory(id: entityId, data: data) { result in
                completion(result != nil)
            }
            
        case .mediaItem:
            apiClient.updateMediaItem(id: entityId, data: data) { result in
                completion(result != nil)
            }
            
        case .tag:
            apiClient.updateTag(id: entityId, data: data) { result in
                completion(result != nil)
            }
            
        case .tagCategory:
            apiClient.updateTagCategory(id: entityId, data: data) { result in
                completion(result != nil)
            }
            
        case .bucketListItem:
            apiClient.updateBucketListItem(id: entityId, data: data) { result in
                completion(result != nil)
            }
        }
    }
    
    /// Löscht eine Entität auf dem Server
    /// - Parameters:
    ///   - entityType: Der Typ der Entität
    ///   - entityId: Die ID der Entität
    ///   - completion: Der Abschlusshandler mit dem Erfolg der Operation
    private func deleteEntity(_ entityType: OfflineEntityType, entityId: String, completion: @escaping (Bool) -> Void) {
        let apiClient = APIClient.shared
        
        switch entityType {
        case .trip:
            apiClient.deleteTrip(id: entityId) { success in
                completion(success)
            }
            
        case .memory:
            apiClient.deleteMemory(id: entityId) { success in
                completion(success)
            }
            
        case .mediaItem:
            apiClient.deleteMediaItem(id: entityId) { success in
                completion(success)
            }
            
        case .tag:
            apiClient.deleteTag(id: entityId) { success in
                completion(success)
            }
            
        case .tagCategory:
            apiClient.deleteTagCategory(id: entityId) { success in
                completion(success)
            }
            
        case .bucketListItem:
            apiClient.deleteBucketListItem(id: entityId) { success in
                completion(success)
            }
        }
    }
} 