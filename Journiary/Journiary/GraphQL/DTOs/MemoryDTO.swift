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
        
        // Versuche vorhandene Backend-ID zu lesen
        var serverId: String?
        if memory.entity.attributesByName.keys.contains("id"),
           let sid = memory.value(forKey: "id") as? String {
            serverId = sid
        }
        
        // Falls keine vorhanden – generieren, aber gleichzeitig im Objekt speichern, sofern Attribut existiert
        if serverId == nil {
            serverId = UUID().uuidString
            if memory.entity.attributesByName.keys.contains("id") {
                memory.setValue(serverId, forKey: "id")
            }
        }
        
        guard let finalId = serverId else {
            return nil
        }
        
        // Location aus Core Data extrahieren
        var location: LocationDTO?
        if memory.latitude != 0 || memory.longitude != 0 {
            location = LocationDTO(
                latitude: memory.latitude,
                longitude: memory.longitude,
                name: memory.locationName
            )
        }
        
        // Trip ID ermitteln – primär backendId, sonst lokale UUID
        var tripId: String?
        if let trip = memory.trip {
            if trip.entity.attributesByName.keys.contains("id") {
                tripId = trip.value(forKey: "id") as? String
            }
            if tripId == nil {
                tripId = trip.id?.uuidString
            }
        }
        
        // User ID aus aktuell angemeldetem User oder Default
        let userId = AuthManager.shared.currentUser?.backendUserId ?? "unknown"
        
        return MemoryDTO(
            id: finalId,
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
    
    /// Erstellt MemoryDTO aus typisiertem GraphQL.Memory Struct
    /// - Parameter mem: GraphQL.Memory
    static func from(graphQLStruct mem: GraphQL.Memory) -> MemoryDTO {
        // Location aus Einzelkoordinaten zusammensetzen
        var location: LocationDTO?
        if let lat = mem.latitude, let lon = mem.longitude {
            location = LocationDTO(latitude: lat, longitude: lon, name: mem.address)
        }
        let iso = ISO8601DateFormatter()
        let created = iso.date(from: mem.createdAt)
        let updated = iso.date(from: mem.updatedAt)

        return MemoryDTO(
            id: mem.id,
            title: mem.title,
            content: mem.content,
            location: location,
            tripId: mem.tripId,
            userId: mem.userId,
            createdAt: created,
            updatedAt: updated,
            creatorId: mem.userId
        )
    }
    
    // MARK: - DTO to Core Data
    
    /// Aktualisiert oder erstellt Core Data Memory aus DTO
    /// - Parameter context: Core Data Context
    /// - Returns: Core Data Memory Entität
    @discardableResult
    func toCoreData(context: NSManagedObjectContext) -> Memory {
        // === Backend-ID Attribut prüfen ===
        let entity = NSEntityDescription.entity(forEntityName: "Memory", in: context)
        let hasServerId = entity?.attributesByName.keys.contains("id") == true

        // Versuche vorhandenes Memory anhand der serverId zu finden
        var memory: Memory?
        if hasServerId {
            let fetch: NSFetchRequest<Memory> = Memory.fetchRequest()
            fetch.predicate = NSPredicate(format: "id == %@", self.id)
            fetch.fetchLimit = 1
            memory = try? context.fetch(fetch).first
        }

        // Fallback-Heuristik (Titel + Zeitstempel) wenn keine backendId im Schema oder nichts gefunden
        if memory == nil {
            let fetch: NSFetchRequest<Memory> = Memory.fetchRequest()
            var predicates: [NSPredicate] = [NSPredicate(format: "title == %@", self.title)]
            if let createdAt = self.createdAt {
                predicates.append(NSPredicate(format: "timestamp == %@", createdAt as CVarArg))
            }
            fetch.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            fetch.fetchLimit = 1
            memory = try? context.fetch(fetch).first
        }

        // Falls weiterhin nichts gefunden -> neu anlegen
        let mem = memory ?? Memory(context: context)

        // === Grunddaten setzen / aktualisieren ===
        mem.title = title
        mem.text = content
        mem.timestamp = createdAt ?? Date()

        // Backend-ID setzen sofern Attribut existiert
        if hasServerId {
            mem.setValue(self.id, forKey: "id")
        }

        // Location setzen
        if let location = location {
            mem.latitude = location.latitude
            mem.longitude = location.longitude
            mem.locationName = location.name
        }

        // Trip-Verknüpfung
        if let tripId = tripId, let tripUUID = UUID(uuidString: tripId) {
            let tripFetch: NSFetchRequest<Trip> = Trip.fetchRequest()
            tripFetch.predicate = NSPredicate(format: "id == %@", tripUUID as CVarArg)
            tripFetch.fetchLimit = 1
            if let trip = try? context.fetch(tripFetch).first {
                mem.trip = trip
            }
        }

        // Creator beibehalten/setzen
        if let creatorId = creatorId, let creatorUUID = UUID(uuidString: creatorId) {
            let userFetch: NSFetchRequest<User> = User.fetchRequest()
            userFetch.predicate = NSPredicate(format: "id == %@", creatorUUID as CVarArg)
            userFetch.fetchLimit = 1
            if let creator = try? context.fetch(userFetch).first {
                mem.creator = creator
            }
        }

        return mem
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