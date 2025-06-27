//
//  MediaItemDTO.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import CoreData

/// Data Transfer Object für MediaItem-Entitäten
struct MediaItemDTO: Codable, Identifiable {
    let id: String
    let mediaType: String
    let timestamp: Date
    let filename: String
    let filesize: Int
    let width: Int?
    let height: Int?
    let duration: Double?
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?
    let locationName: String?
    let objectName: String?
    let memoryId: String?
    let order: Int
    
    // GraphQL Queries
    static let allMediaItemsQuery = """
    query GetAllMediaItems {
      mediaItems {
        id
        mediaType
        timestamp
        filename
        filesize
        width
        height
        duration
        latitude
        longitude
        altitude
        locationName
        objectName
        memoryId
        order
      }
    }
    """
    
    static let mediaItemsForMemoryQuery = """
    query GetMediaItemsForMemory($memoryId: String!) {
      mediaItemsForMemory(memoryId: $memoryId) {
        id
        mediaType
        timestamp
        filename
        filesize
        width
        height
        duration
        latitude
        longitude
        altitude
        locationName
        objectName
        memoryId
        order
      }
    }
    """
    
    static let createMediaItemMutation = """
    mutation CreateMediaItem($input: MediaItemInput!) {
      createMediaItem(input: $input) {
        id
        mediaType
        timestamp
        filename
        filesize
        width
        height
        duration
        latitude
        longitude
        altitude
        locationName
        objectName
        memoryId
        order
      }
    }
    """
    
    static let updateMediaItemMutation = """
    mutation UpdateMediaItem($id: String!, $input: MediaItemInput!) {
      updateMediaItem(id: $id, input: $input) {
        id
        mediaType
        timestamp
        filename
        filesize
        width
        height
        duration
        latitude
        longitude
        altitude
        locationName
        objectName
        memoryId
        order
      }
    }
    """
    
    /// Konvertiert ein CoreData MediaItem-Objekt in ein MediaItemDTO
    /// - Parameter mediaItem: Das CoreData MediaItem-Objekt
    /// - Returns: Ein MediaItemDTO-Objekt
    static func fromCoreData(_ mediaItem: MediaItem) -> MediaItemDTO {
        return MediaItemDTO(
            id: mediaItem.id?.uuidString ?? UUID().uuidString,
            mediaType: mediaItem.mediaType ?? "unknown",
            timestamp: mediaItem.timestamp ?? Date(),
            filename: mediaItem.filename ?? "unknown.jpg",
            filesize: Int(mediaItem.filesize),
            width: mediaItem.width > 0 ? Int(mediaItem.width) : nil,
            height: mediaItem.height > 0 ? Int(mediaItem.height) : nil,
            duration: mediaItem.duration > 0 ? mediaItem.duration : nil,
            latitude: mediaItem.latitude != 0 ? mediaItem.latitude : nil,
            longitude: mediaItem.longitude != 0 ? mediaItem.longitude : nil,
            altitude: mediaItem.altitude != 0 ? mediaItem.altitude : nil,
            locationName: mediaItem.locationName,
            objectName: mediaItem.objectName,
            memoryId: mediaItem.memory?.id?.uuidString,
            order: Int(mediaItem.order)
        )
    }
    
    /// Aktualisiert ein CoreData MediaItem-Objekt mit den Daten aus diesem DTO
    /// - Parameters:
    ///   - mediaItem: Das zu aktualisierende MediaItem-Objekt
    ///   - context: Der NSManagedObjectContext
    func updateCoreData(_ mediaItem: MediaItem, context: NSManagedObjectContext) {
        // ID setzen, wenn nicht vorhanden
        if mediaItem.id == nil {
            mediaItem.id = UUID(uuidString: id)
        }
        
        mediaItem.mediaType = mediaType
        mediaItem.timestamp = timestamp
        mediaItem.filename = filename
        mediaItem.filesize = Int64(filesize)
        
        if let width = width {
            mediaItem.width = Int16(width)
        }
        
        if let height = height {
            mediaItem.height = Int16(height)
        }
        
        if let duration = duration {
            mediaItem.duration = duration
        }
        
        if let latitude = latitude {
            mediaItem.latitude = latitude
        }
        
        if let longitude = longitude {
            mediaItem.longitude = longitude
        }
        
        if let altitude = altitude {
            mediaItem.altitude = altitude
        }
        
        mediaItem.locationName = locationName
        mediaItem.objectName = objectName
        mediaItem.order = Int16(order)
        
        // Memory-Beziehung setzen, wenn memoryId vorhanden ist
        if let memoryId = memoryId, let memoryUUID = UUID(uuidString: memoryId) {
            let fetchRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", memoryUUID as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let memories = try context.fetch(fetchRequest)
                if let memory = memories.first {
                    mediaItem.memory = memory
                }
            } catch {
                print("❌ Fehler beim Abrufen der Memory für MediaItem: \(error)")
            }
        }
    }
    
    /// Erstellt ein neues CoreData MediaItem-Objekt aus diesem DTO
    /// - Parameter context: Der NSManagedObjectContext
    /// - Returns: Das neu erstellte MediaItem-Objekt
    func createCoreDataObject(context: NSManagedObjectContext) -> MediaItem {
        let mediaItem = MediaItem(context: context)
        updateCoreData(mediaItem, context: context)
        return mediaItem
    }
    
    /// Konvertiert das DTO in ein Dictionary für GraphQL Mutationen
    func toInputDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "mediaType": mediaType,
            "timestamp": timestamp.timeIntervalSince1970,
            "filename": filename,
            "filesize": filesize,
            "order": order
        ]
        
        if let width = width {
            dict["width"] = width
        }
        
        if let height = height {
            dict["height"] = height
        }
        
        if let duration = duration {
            dict["duration"] = duration
        }
        
        if let latitude = latitude {
            dict["latitude"] = latitude
        }
        
        if let longitude = longitude {
            dict["longitude"] = longitude
        }
        
        if let altitude = altitude {
            dict["altitude"] = altitude
        }
        
        if let locationName = locationName {
            dict["locationName"] = locationName
        }
        
        if let objectName = objectName {
            dict["objectName"] = objectName
        }
        
        if let memoryId = memoryId {
            dict["memoryId"] = memoryId
        }
        
        return dict
    }
    
    /// GraphQL-Mutation zum Löschen eines MediaItems
    static let deleteMediaItemMutation = """
    mutation DeleteMediaItem($id: ID!) {
      deleteMediaItem(id: $id)
    }
    """
} 