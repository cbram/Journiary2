//
//  TagDTO.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import CoreData

/// Data Transfer Object für Tag-Entität
/// Konvertiert zwischen Core Data Tag und GraphQL Tag
struct TagDTO {
    let id: String
    let name: String
    let color: String?
    let categoryId: String?
    let createdAt: Date?
    
    // MARK: - Core Data to DTO
    
    static func from(coreData tag: Tag) -> TagDTO? {
        guard let name = tag.name else { return nil }
        
        let backendId = tag.id?.uuidString ?? UUID().uuidString
        let categoryId = tag.category?.id?.uuidString
        
        return TagDTO(
            id: backendId,
            name: name,
            color: tag.color,
            categoryId: categoryId,
            createdAt: tag.createdAt
        )
    }
    
    // MARK: - GraphQL to DTO
    
    static func from(graphQL tagData: Any) -> TagDTO? {
        guard let dict = tagData as? [String: Any],
              let id = dict["id"] as? String,
              let name = dict["name"] as? String else {
            return nil
        }
        
        let color = dict["color"] as? String
        let categoryId = dict["categoryId"] as? String
        
        var createdAt: Date?
        if let createdAtString = dict["createdAt"] as? String {
            createdAt = ISO8601DateFormatter().date(from: createdAtString)
        }
        
        return TagDTO(
            id: id,
            name: name,
            color: color,
            categoryId: categoryId,
            createdAt: createdAt
        )
    }
    
    // MARK: - DTO to Core Data
    
    @discardableResult
    func toCoreData(context: NSManagedObjectContext) -> Tag {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        
        if let uuid = UUID(uuidString: id) {
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        } else {
            request.predicate = NSPredicate(format: "name == %@", name)
        }
        
        let existingTag = try? context.fetch(request).first
        let tag = existingTag ?? Tag(context: context)
        
        if tag.id == nil, let uuid = UUID(uuidString: id) {
            tag.id = uuid
        }
        
        tag.name = name
        tag.displayName = name
        tag.normalizedName = name.lowercased()
        tag.color = color
        tag.createdAt = createdAt ?? Date()
        
        // Category verknüpfen
        if let categoryId = categoryId, let categoryUUID = UUID(uuidString: categoryId) {
            let categoryRequest: NSFetchRequest<TagCategory> = TagCategory.fetchRequest()
            categoryRequest.predicate = NSPredicate(format: "id == %@", categoryUUID as CVarArg)
            
            if let category = try? context.fetch(categoryRequest).first {
                tag.category = category
            }
        }
        
        return tag
    }
    
    // MARK: - GraphQL Input
    
    func toGraphQLInput() -> [String: Any] {
        var input: [String: Any] = ["name": name]
        
        if let color = color {
            input["color"] = color
        }
        
        if let categoryId = categoryId {
            input["categoryId"] = categoryId
        }
        
        return input
    }
}

/// Data Transfer Object für TagCategory-Entität
struct TagCategoryDTO {
    let id: String
    let name: String
    let color: String?
    let createdAt: Date?
    
    // MARK: - Core Data to DTO
    
    static func from(coreData category: TagCategory) -> TagCategoryDTO? {
        guard let name = category.name else { return nil }
        
        let backendId = category.id?.uuidString ?? UUID().uuidString
        
        return TagCategoryDTO(
            id: backendId,
            name: name,
            color: category.color,
            createdAt: category.createdAt
        )
    }
    
    // MARK: - GraphQL to DTO
    
    static func from(graphQL categoryData: Any) -> TagCategoryDTO? {
        guard let dict = categoryData as? [String: Any],
              let id = dict["id"] as? String,
              let name = dict["name"] as? String else {
            return nil
        }
        
        let color = dict["color"] as? String
        
        var createdAt: Date?
        if let createdAtString = dict["createdAt"] as? String {
            createdAt = ISO8601DateFormatter().date(from: createdAtString)
        }
        
        return TagCategoryDTO(
            id: id,
            name: name,
            color: color,
            createdAt: createdAt
        )
    }
    
    // MARK: - DTO to Core Data
    
    @discardableResult
    func toCoreData(context: NSManagedObjectContext) -> TagCategory {
        let request: NSFetchRequest<TagCategory> = TagCategory.fetchRequest()
        
        if let uuid = UUID(uuidString: id) {
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        } else {
            request.predicate = NSPredicate(format: "name == %@", name)
        }
        
        let existingCategory = try? context.fetch(request).first
        let category = existingCategory ?? TagCategory(context: context)
        
        if category.id == nil, let uuid = UUID(uuidString: id) {
            category.id = uuid
        }
        
        category.name = name
        category.displayName = name
        category.color = color
        category.createdAt = createdAt ?? Date()
        
        return category
    }
    
    // MARK: - GraphQL Input
    
    func toGraphQLInput() -> [String: Any] {
        var input: [String: Any] = ["name": name]
        
        if let color = color {
            input["color"] = color
        }
        
        return input
    }
} 