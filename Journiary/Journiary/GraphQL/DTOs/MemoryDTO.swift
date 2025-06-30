//
//  MemoryDTO.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import CoreData
import CoreLocation

/// Data Transfer Object für Memory-Entität
/// Konvertiert zwischen Core Data Memory und GraphQL Memory
struct MemoryDTO {
    let id: String
    let title: String
    let content: String?
    let location: LocationDTO?
    let tripId: String?
    let userId: String
    let createdAt: Date?
    let updatedAt: Date?
    let creatorId: String?
    
    // MARK: - Core Data to DTO
    
    /// Erstellt MemoryDTO aus Core Data Memory
    /// - Parameter memory: Core Data Memory Entität
    /// - Returns: MemoryDTO oder nil falls Daten unvollständig
    static func from(coreData memory: Memory) -> MemoryDTO? {
        guard let title = memory.title else {
            return nil
        }
        
        // Backend ID generieren falls nicht vorhanden
        let backendId = UUID().uuidString // Memory hat keine Backend ID im Core Data
        
        // Location aus Core Data extrahieren
        var location: LocationDTO?
        if memory.latitude != 0 || memory.longitude != 0 {
            location = LocationDTO(
                latitude: memory.latitude,
                longitude: memory.longitude,
                name: memory.locationName
            )
        }
        
        // Trip ID extrahieren
        let tripId = memory.trip?.id?.uuidString
        
        // User ID aus aktuell angemeldetem User oder Default
        let userId = AuthManager.shared.currentUser?.backendUserId ?? "unknown"
        
        return MemoryDTO(
            id: backendId,
            title: title,
            content: memory.text,
            location: location,
            tripId: tripId,
            userId: userId,
            createdAt: memory.timestamp,
            updatedAt: memory.timestamp,
            creatorId: memory.creator?.id?.uuidString
        )
    }
    
    // MARK: - GraphQL to DTO
    
    /// Erstellt MemoryDTO aus GraphQL Response
    /// - Parameter memoryData: GraphQL Memory Dictionary
    /// - Returns: MemoryDTO oder nil falls Parsing fehlschlägt
    static func from(graphQL memoryData: Any) -> MemoryDTO? {
        guard let dict = memoryData as? [String: Any],
              let id = dict["id"] as? String,
              let title = dict["title"] as? String,
              let userId = dict["userId"] as? String else {
            return nil
        }
        
        let content = dict["content"] as? String
        let tripId = dict["tripId"] as? String
        
        // Location Parsing
        var location: LocationDTO?
        if let locationData = dict["location"] as? [String: Any] {
            location = LocationDTO.from(graphQL: locationData)
        }
        
        // Date Parsing
        var createdAt: Date?
        var updatedAt: Date?
        
        if let createdAtString = dict["createdAt"] as? String {
            createdAt = ISO8601DateFormatter().date(from: createdAtString)
        }
        
        if let updatedAtString = dict["updatedAt"] as? String {
            updatedAt = ISO8601DateFormatter().date(from: updatedAtString)
        }
        
        let creatorId = dict["creatorId"] as? String
        
        return MemoryDTO(
            id: id,
            title: title,
            content: content,
            location: location,
            tripId: tripId,
            userId: userId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            creatorId: creatorId
        )
    }
    
    // MARK: - DTO to Core Data
    
    /// Aktualisiert oder erstellt Core Data Memory aus DTO
    /// - Parameter context: Core Data Context
    /// - Returns: Core Data Memory Entität
    @discardableResult
    func toCoreData(context: NSManagedObjectContext) -> Memory {
        // Memory immer neu erstellen da keine Backend ID im Core Data
        let memory = Memory(context: context)
        
        // Memory Daten setzen
        memory.title = title
        memory.text = content
        memory.timestamp = createdAt ?? Date()
        
        // Location setzen
        if let location = location {
            memory.latitude = location.latitude
            memory.longitude = location.longitude
            memory.locationName = location.name
        }
        
        // Trip verknüpfen falls vorhanden
        if let tripId = tripId, let tripUUID = UUID(uuidString: tripId) {
            let tripRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
            tripRequest.predicate = NSPredicate(format: "id == %@", tripUUID as CVarArg)
            
            if let trip = try? context.fetch(tripRequest).first {
                memory.trip = trip
            }
        }
        
        // WICHTIG: Bei neuen Memories aus Backend Creator zuweisen!
        // Versuche User via UUID zu finden, falls vorhanden
        if let creatorId = creatorId,
           let creatorUUID = UUID(uuidString: creatorId) {
            let userRequest: NSFetchRequest<User> = User.fetchRequest()
            userRequest.predicate = NSPredicate(format: "id == %@", creatorUUID as CVarArg)
            userRequest.fetchLimit = 1
            
            if let creator = try? context.fetch(userRequest).first {
                memory.creator = creator
                print("✅ Memory aus Backend mit bekanntem Creator zugewiesen: \(creator.displayName)")
            } else {
                print("⚠️ Warnung: Creator UUID \(creatorId) nicht in lokaler DB gefunden")
            }
        } else {
            print("⚠️ Warnung: Memory aus Backend ohne Creator-Information")
        }
        
        return memory
    }
    
    // MARK: - GraphQL Input
    
    /// Erstellt GraphQL MemoryInput Dictionary
    /// - Returns: Dictionary für GraphQL MemoryInput
    func toGraphQLInput() -> [String: Any] {
        var input: [String: Any] = [
            "title": title
        ]
        
        if let content = content {
            input["content"] = content
        }
        
        if let location = location {
            input["location"] = location.toGraphQLInput()
        }
        
        if let tripId = tripId {
            input["tripId"] = tripId
        }
        
        return input
    }
    
    /// Erstellt GraphQL UpdateMemoryInput Dictionary
    /// - Returns: Dictionary für GraphQL UpdateMemoryInput
    func toGraphQLUpdateInput() -> [String: Any] {
        var input: [String: Any] = [:]
        
        input["title"] = title
        
        if let content = content {
            input["content"] = content
        } else {
            input["content"] = NSNull()
        }
        
        if let location = location {
            input["location"] = location.toGraphQLInput()
        } else {
            input["location"] = NSNull()
        }
        
        return input
    }
}

// MARK: - Location DTO

struct LocationDTO {
    let latitude: Double
    let longitude: Double
    let name: String?
    
    /// Erstellt LocationDTO aus GraphQL Location Dictionary
    /// - Parameter locationData: GraphQL Location Dictionary
    /// - Returns: LocationDTO oder nil falls Parsing fehlschlägt
    static func from(graphQL locationData: [String: Any]) -> LocationDTO? {
        guard let latitude = locationData["latitude"] as? Double,
              let longitude = locationData["longitude"] as? Double else {
            return nil
        }
        
        let name = locationData["name"] as? String
        
        return LocationDTO(
            latitude: latitude,
            longitude: longitude,
            name: name
        )
    }
    
    /// Erstellt GraphQL LocationInput Dictionary
    /// - Returns: Dictionary für GraphQL LocationInput
    func toGraphQLInput() -> [String: Any] {
        var input: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]
        
        if let name = name {
            input["name"] = name
        }
        
        return input
    }
    
    /// Konvertiert zu CoreLocation CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Helper Extensions

extension MemoryDTO {
    /// Formatierte Datumsanzeige für die UI
    var formattedDate: String {
        guard let createdAt = createdAt else {
            return "Unbekanntes Datum"
        }
        
        return DateFormatter.germanMedium.string(from: createdAt)
    }
    
    /// Kurzer Textauszug für Listen-Anzeige
    var excerpt: String {
        guard let content = content else {
            return "Keine Beschreibung"
        }
        
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "..."
        }
        
        return trimmed
    }
    
    /// Hat Location Information
    var hasLocation: Bool {
        return location != nil
    }
    
    /// Entfernung zu einem anderen Standort
    /// - Parameter coordinate: Ziel-Koordinate
    /// - Returns: Entfernung in Metern oder nil falls keine Location
    func distance(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let location = location else { return nil }
        
        let memoryLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        return memoryLocation.distance(from: targetLocation)
    }
}

// MARK: - Bulk Operations

struct BulkMemoryUpdateDTO {
    let id: String
    let input: [String: Any]
    
    /// Erstellt Bulk Update Dictionary
    /// - Returns: Dictionary für GraphQL BulkMemoryUpdate
    func toGraphQLInput() -> [String: Any] {
        return [
            "id": id,
            "input": input
        ]
    }
} 