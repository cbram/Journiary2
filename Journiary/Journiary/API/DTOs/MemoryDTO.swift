//
//  MemoryDTO.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import CoreData

/// Data Transfer Object für Memory-Entitäten
struct MemoryDTO: Codable, Identifiable {
    let id: String
    let title: String
    let text: String?
    let timestamp: Date
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let tripId: String?
    let tags: [String]?
    
    // GraphQL Queries
    static let allMemoriesQuery = """
    query GetAllMemories {
      memories {
        id
        title
        text
        timestamp
        latitude
        longitude
        locationName
        tripId
        tags
      }
    }
    """
    
    static let memoriesForTripQuery = """
    query GetMemoriesForTrip($tripId: String!) {
      memoriesForTrip(tripId: $tripId) {
        id
        title
        text
        timestamp
        latitude
        longitude
        locationName
        tripId
        tags
      }
    }
    """
    
    static let createMemoryMutation = """
    mutation CreateMemory($input: MemoryInput!) {
      createMemory(input: $input) {
        id
        title
        text
        timestamp
        latitude
        longitude
        locationName
        tripId
        tags
      }
    }
    """
    
    static let updateMemoryMutation = """
    mutation UpdateMemory($id: String!, $input: MemoryInput!) {
      updateMemory(id: $id, input: $input) {
        id
        title
        text
        timestamp
        latitude
        longitude
        locationName
        tripId
        tags
      }
    }
    """
    
    // Konvertierung von Core Data zu DTO
    static func fromCoreData(_ memory: Memory) -> MemoryDTO {
        // Tags extrahieren
        let memoryTags = memory.tags?.allObjects as? [Tag] ?? []
        let tagNames = memoryTags.compactMap { $0.name }
        
        return MemoryDTO(
            id: memory.id?.uuidString ?? UUID().uuidString,
            title: memory.title ?? "Unbenannte Erinnerung",
            text: memory.text,
            timestamp: memory.timestamp ?? Date(),
            latitude: memory.latitude != 0 ? memory.latitude : nil,
            longitude: memory.longitude != 0 ? memory.longitude : nil,
            locationName: memory.locationName,
            tripId: memory.trip?.id?.uuidString,
            tags: tagNames.isEmpty ? nil : tagNames
        )
    }
    
    // Konvertierung von DTO zu Core Data
    func createCoreDataObject(context: NSManagedObjectContext) -> Memory {
        let memory = Memory(context: context)
        updateCoreData(memory, context: context)
        return memory
    }
    
    // Aktualisiert ein bestehendes Core Data Objekt mit den Werten aus dem DTO
    func updateCoreData(_ memory: Memory, context: NSManagedObjectContext) {
        // ID setzen, wenn nicht vorhanden
        if memory.id == nil {
            memory.id = UUID(uuidString: id)
        }
        
        memory.title = title
        memory.text = text
        memory.timestamp = timestamp
        
        if let latitude = latitude {
            memory.latitude = latitude
        }
        
        if let longitude = longitude {
            memory.longitude = longitude
        }
        
        memory.locationName = locationName
        
        // Trip-Beziehung setzen, wenn tripId vorhanden ist
        if let tripId = tripId, let tripUUID = UUID(uuidString: tripId) {
            let fetchRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", tripUUID as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let trips = try context.fetch(fetchRequest)
                if let trip = trips.first {
                    memory.trip = trip
                }
            } catch {
                print("❌ Fehler beim Abrufen der Trip für Memory: \(error)")
            }
        }
        
        // Tags setzen, wenn vorhanden
        if let tags = tags, !tags.isEmpty {
            // Bestehende Tags entfernen
            memory.tags = NSSet()
            
            for tagName in tags {
                // Prüfen, ob der Tag bereits existiert
                let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", tagName)
                fetchRequest.fetchLimit = 1
                
                do {
                    let existingTags = try context.fetch(fetchRequest)
                    let tag: Tag
                    
                    if let existingTag = existingTags.first {
                        tag = existingTag
                    } else {
                        // Tag erstellen, wenn er nicht existiert
                        tag = Tag(context: context)
                        tag.id = UUID()
                        tag.name = tagName
                    }
                    
                    // Tag zur Memory hinzufügen
                    memory.addToTags(tag)
                } catch {
                    print("❌ Fehler beim Abrufen oder Erstellen des Tags: \(error)")
                }
            }
        }
    }
    
    // Konvertiert das DTO in ein Dictionary für GraphQL Mutationen
    func toInputDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "title": title,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        
        if let text = text {
            dict["text"] = text
        }
        
        if let latitude = latitude {
            dict["latitude"] = latitude
        }
        
        if let longitude = longitude {
            dict["longitude"] = longitude
        }
        
        if let locationName = locationName {
            dict["locationName"] = locationName
        }
        
        if let tripId = tripId {
            dict["tripId"] = tripId
        }
        
        if let tags = tags, !tags.isEmpty {
            dict["tags"] = tags
        }
        
        return dict
    }
} 