//
//  TagDTO.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import CoreData
import SwiftUI

/// Data Transfer Object für Tag-Entitäten
struct TagDTO: Codable, Identifiable {
    let id: String
    let name: String
    let displayName: String?
    let emoji: String?
    let color: String?
    let isSystemTag: Bool
    let usageCount: Int
    let categoryId: String?
    
    // GraphQL Queries
    static let allTagsQuery = """
    query GetAllTags {
      tags {
        id
        name
        displayName
        emoji
        color
        isSystemTag
        usageCount
        categoryId
      }
    }
    """
    
    static let tagByIdQuery = """
    query GetTagById($id: String!) {
      tag(id: $id) {
        id
        name
        displayName
        emoji
        color
        isSystemTag
        usageCount
        categoryId
      }
    }
    """
    
    static let createTagMutation = """
    mutation CreateTag($input: TagInput!) {
      createTag(input: $input) {
        id
        name
        displayName
        emoji
        color
        isSystemTag
        usageCount
        categoryId
      }
    }
    """
    
    static let updateTagMutation = """
    mutation UpdateTag($id: String!, $input: TagInput!) {
      updateTag(id: $id, input: $input) {
        id
        name
        displayName
        emoji
        color
        isSystemTag
        usageCount
        categoryId
      }
    }
    """
    
    // Konvertierung von Core Data zu DTO
    static func fromCoreData(_ tag: Tag) -> TagDTO {
        return TagDTO(
            id: tag.id?.uuidString ?? UUID().uuidString,
            name: tag.name ?? "Unbenannter Tag",
            displayName: tag.displayName,
            emoji: tag.emoji,
            color: tag.color,
            isSystemTag: tag.isSystemTag,
            usageCount: Int(tag.usageCount),
            categoryId: tag.category?.id?.uuidString
        )
    }
    
    // Konvertierung von DTO zu Core Data
    func createCoreDataObject(context: NSManagedObjectContext) -> Tag {
        let tag = Tag(context: context)
        updateCoreData(tag, context: context)
        return tag
    }
    
    // Aktualisiert ein bestehendes Core Data Objekt mit den Werten aus dem DTO
    func updateCoreData(_ tag: Tag, context: NSManagedObjectContext) {
        // ID setzen, wenn nicht vorhanden
        if tag.id == nil {
            tag.id = UUID(uuidString: id)
        }
        
        tag.name = name
        tag.displayName = displayName
        tag.emoji = emoji
        tag.color = color
        tag.isSystemTag = isSystemTag
        tag.usageCount = Int16(usageCount)
        
        // Kategorie-Beziehung setzen, wenn categoryId vorhanden ist
        if let categoryId = categoryId, let categoryUUID = UUID(uuidString: categoryId) {
            let fetchRequest: NSFetchRequest<TagCategory> = TagCategory.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", categoryUUID as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let categories = try context.fetch(fetchRequest)
                if let category = categories.first {
                    tag.category = category
                }
            } catch {
                print("❌ Fehler beim Abrufen der Kategorie für Tag: \(error)")
            }
        }
    }
    
    // Konvertiert das DTO in ein Dictionary für GraphQL Mutationen
    func toInputDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "isSystemTag": isSystemTag,
            "usageCount": usageCount
        ]
        
        if let displayName = displayName {
            dict["displayName"] = displayName
        }
        
        if let emoji = emoji {
            dict["emoji"] = emoji
        }
        
        if let color = color {
            dict["color"] = color
        }
        
        if let categoryId = categoryId {
            dict["categoryId"] = categoryId
        }
        
        return dict
    }
    
    // Hilfsfunktion zum Konvertieren der Farbe in SwiftUI Color
    func getColor() -> Color {
        guard let colorString = color else {
            return .gray
        }
        
        // Versuche, die Farbe aus dem Hex-String zu erstellen
        if colorString.hasPrefix("#") {
            let hex = colorString.dropFirst()
            var rgbValue: UInt64 = 0
            Scanner(string: String(hex)).scanHexInt64(&rgbValue)
            
            let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
            let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
            let b = Double(rgbValue & 0x0000FF) / 255.0
            
            return Color(red: r, green: g, blue: b)
        }
        
        // Fallback für benannte Farben
        switch colorString.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "gray", "grey": return .gray
        default: return .gray
        }
    }
} 