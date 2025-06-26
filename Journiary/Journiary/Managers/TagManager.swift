//
//  TagManager.swift
//  Journiary
//
//  Created by Assistant on 06.11.25.
//

import Foundation
import CoreData
import SwiftUI
import MapKit

@MainActor
class TagManager: ObservableObject {
    private let viewContext: NSManagedObjectContext
    
    @Published var allTags: [Tag] = []
    @Published var allCategories: [TagCategory] = []
    @Published var filteredTags: [Tag] = []
    @Published var searchQuery: String = ""
    @Published var isInitialized = false
    
    // Computed property für tagCategories (Alias für allCategories)
    var tagCategories: [TagCategory] {
        return allCategories
    }
    
    // Alias für andere Views
    var categories: [TagCategory] {
        return allCategories
    }
    
    // Tags für eine bestimmte Kategorie
    func tags(for category: TagCategory) -> [Tag] {
        return allTags.filter { $0.category == category }
    }
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        setupSystemTagsAndCategories()
        loadData()
        updateFilteredTags()
    }
    
    // MARK: - Data Loading
    
    func loadData() {
        loadTags()
        loadCategories()
    }
    
    private func loadTags() {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        
        do {
            allTags = try viewContext.fetch(request)
        } catch {
            print("Fehler beim Laden der Tags: \(error)")
            allTags = []
        }
    }
    
    private func loadCategories() {
        let request: NSFetchRequest<TagCategory> = TagCategory.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TagCategory.sortOrder, ascending: true)]
        
        do {
            allCategories = try viewContext.fetch(request)
        } catch {
            print("Fehler beim Laden der Kategorien: \(error)")
            allCategories = []
        }
    }
    
    // MARK: - Tag Operations
    
    func createTag(name: String, 
                   displayName: String? = nil, 
                   emoji: String? = nil, 
                   color: String = "blue", 
                   category: TagCategory? = nil) -> Tag? {
        let tag = Tag(context: viewContext)
        tag.id = UUID()
        tag.name = name.lowercased()
        tag.normalizedName = name.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        tag.displayName = displayName ?? name
        tag.emoji = emoji
        tag.color = color
        tag.isSystemTag = false
        tag.usageCount = 0
        tag.createdAt = Date()
        tag.lastUsedAt = Date()
        tag.isArchived = false
        tag.sortOrder = 0
        
        if let category = category {
            tag.category = category
        }
        
        saveContext()
        loadTags()
        
        return tag
    }
    
    func updateTag(_ tag: Tag, 
                   name: String? = nil, 
                   displayName: String? = nil, 
                   emoji: String? = nil, 
                   color: String? = nil, 
                   category: TagCategory? = nil) {
        if let name = name {
            tag.name = name.lowercased()
            tag.normalizedName = name.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        }
        if let displayName = displayName {
            tag.displayName = displayName
        }
        if let emoji = emoji {
            tag.emoji = emoji
        }
        if let color = color {
            tag.color = color
        }
        if let category = category {
            tag.category = category
        }
        
        saveContext()
        loadTags()
    }
    
    func deleteTag(_ tag: Tag) {
        viewContext.delete(tag)
        saveContext()
        loadTags()
    }
    
    func toggleTag(_ tag: Tag, for memory: Memory) {
        if memory.hasTag(tag) {
            memory.removeFromTags(tag)
            decrementUsage(for: tag)
        } else {
            memory.addToTags(tag)
            incrementUsage(for: tag)
        }
        saveContext()
    }
    
    private func incrementUsage(for tag: Tag) {
        tag.usageCount += 1
        tag.lastUsedAt = Date()
    }
    
    private func decrementUsage(for tag: Tag) {
        if tag.usageCount > 0 {
            tag.usageCount -= 1
        }
    }
    
    // MARK: - Category Operations
    
    func createCategory(name: String, 
                       displayName: String? = nil, 
                       emoji: String? = nil, 
                       color: String = "blue") -> TagCategory {
        let category = TagCategory(context: viewContext)
        category.id = UUID()
        category.name = name.lowercased()
        category.displayName = displayName ?? name
        category.emoji = emoji
        category.color = color
        category.isSystemCategory = false
        category.sortOrder = Int32(allCategories.count)
        category.isExpanded = true
        category.createdAt = Date()
        
        saveContext()
        loadCategories()
        
        return category
    }
    
    func updateCategory(_ category: TagCategory, 
                       name: String? = nil, 
                       displayName: String? = nil, 
                       emoji: String? = nil, 
                       color: String? = nil) {
        if let name = name {
            category.name = name.lowercased()
            category.displayName = displayName ?? name
        }
        if let displayName = displayName {
            category.displayName = displayName
        }
        if let emoji = emoji {
            category.emoji = emoji
        }
        if let color = color {
            category.color = color
        }
        
        saveContext()
        loadCategories()
    }
    
    func deleteCategory(_ category: TagCategory) {
        // Tags der Kategorie zu "uncategorized" verschieben
        if let tags = category.tags?.allObjects as? [Tag] {
            for tag in tags {
                tag.category = nil
            }
        }
        
        viewContext.delete(category)
        saveContext()
        loadCategories()
    }
    
    // MARK: - Search
    
    func search(query: String) {
        searchQuery = query
        updateFilteredTags()
    }
    
    func clearSearch() {
        searchQuery = ""
        updateFilteredTags()
    }
    
    func searchTags(query: String) -> [Tag] {
        guard !query.isEmpty else { return allTags.filter { !$0.isArchived } }
        
        let normalizedQuery = query.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        
        return allTags.filter { tag in
            !tag.isArchived && (
                tag.normalizedName?.contains(normalizedQuery) == true ||
                tag.displayName?.lowercased().contains(normalizedQuery) == true ||
                tag.name?.contains(normalizedQuery) == true
            )
        }
    }
    
    // MARK: - Suggestions
    
    var frequentlyUsedTags: [Tag] {
        return allTags
            .filter { !$0.isArchived && $0.usageCount > 0 }
            .sorted { $0.usageCount > $1.usageCount }
            .prefix(10)
            .map { $0 }
    }
    
    func suggestTags(for memory: Memory) -> [Tag] {
        var suggestions: [Tag] = []
        
        // Zeitbasierte Vorschläge
        if let date = memory.timestamp {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            
            switch hour {
            case 5...11:
                suggestions.append(contentsOf: findOrCreateTags(["morgen", "früh"]))
            case 12...17:
                suggestions.append(contentsOf: findOrCreateTags(["mittag", "nachmittag"]))
            case 18...22:
                suggestions.append(contentsOf: findOrCreateTags(["abend"]))
            default:
                suggestions.append(contentsOf: findOrCreateTags(["nacht"]))
            }
        }
        
        // Ortsbasierte Vorschläge
        if let locationName = memory.locationName?.lowercased() {
            let locationTags = analyzeLocationName(locationName)
            suggestions.append(contentsOf: locationTags)
        }
        
        // Textbasierte Vorschläge
        if let text = memory.text?.lowercased() {
            let textTags = analyzeText(text)
            suggestions.append(contentsOf: textTags)
        }
        
        // Duplikate entfernen und bereits verwendete Tags ausschließen
        let uniqueSuggestions = Array(Set(suggestions))
        return uniqueSuggestions.filter { !memory.hasTag($0) }
    }
    
    private func analyzeLocationName(_ locationName: String) -> [Tag] {
        var suggestions: [Tag] = []
        
        let locationKeywords: [String: [String]] = [
            "restaurant": ["🍽️", "restaurant", "essen"],
            "café": ["☕", "café", "kaffee"],
            "park": ["🌳", "park", "natur"],
            "museum": ["🏛️", "museum", "kultur"],
            "strand": ["🏖️", "strand", "meer"],
            "berg": ["⛰️", "berg", "wandern"],
            "hotel": ["🏨", "hotel", "übernachtung"],
            "flughafen": ["✈️", "flughafen", "reise"],
            "bahnhof": ["🚂", "bahnhof", "reise"]
        ]
        
        for (keyword, tags) in locationKeywords {
            if locationName.contains(keyword) {
                suggestions.append(contentsOf: findOrCreateTags(tags))
            }
        }
        
        return suggestions
    }
    
    private func analyzeText(_ text: String) -> [Tag] {
        var suggestions: [Tag] = []
        
        let textKeywords: [String: [String]] = [
            "wandern": ["🥾", "wandern", "sport"],
            "essen": ["🍽️", "essen", "kulinarik"],
            "fotografie": ["📸", "fotografie", "hobby"],
            "strand": ["🏖️", "strand", "entspannung"],
            "museum": ["🏛️", "museum", "kultur"],
            "konzert": ["🎵", "konzert", "musik"],
            "sport": ["⚽", "sport", "aktivität"],
            "familie": ["👨‍👩‍👧‍👦", "familie", "zusammen"],
            "freunde": ["👫", "freunde", "zusammen"]
        ]
        
        for (keyword, tags) in textKeywords {
            if text.contains(keyword) {
                suggestions.append(contentsOf: findOrCreateTags(tags))
            }
        }
        
        return suggestions
    }
    
    private func findOrCreateTags(_ tagNames: [String]) -> [Tag] {
        return tagNames.compactMap { tagName in
            // Erst versuchen zu finden
            if let existingTag = allTags.first(where: { $0.name == tagName.lowercased() }) {
                return existingTag
            }
            
            // Wenn nicht gefunden, erstellen
            let emoji = tagName.first?.isEmoji == true ? String(tagName.first!) : nil
            let name = emoji != nil ? String(tagName.dropFirst()) : tagName
            
            return createTag(
                name: name,
                displayName: name.capitalized,
                emoji: emoji,
                color: randomColor()
            )
        }
    }
    
    private func randomColor() -> String {
        let colors = ["blue", "green", "red", "orange", "purple", "pink", "yellow", "indigo", "teal", "cyan", "mint", "brown"]
        return colors.randomElement() ?? "blue"
    }
    
    // MARK: - System Setup
    
    private func setupSystemTagsAndCategories() {
        guard !isInitialized else { return }
        
        // Prüfen ob bereits System-Kategorien existieren
        let request: NSFetchRequest<TagCategory> = TagCategory.fetchRequest()
        request.predicate = NSPredicate(format: "isSystemCategory == YES")
        
        do {
            let existingCategories = try viewContext.fetch(request)
            if !existingCategories.isEmpty {
                isInitialized = true
                return
            }
        } catch {
            print("Fehler beim Prüfen der System-Kategorien: \(error)")
        }
        
        createSystemCategories()
        createSystemTags()
        
        isInitialized = true
        saveContext()
    }
    
    private func createSystemCategories() {
        let systemCategories = [
            ("orte", "🗺️", "Orte"),
            ("aktivitäten", "🎯", "Aktivitäten"), 
            ("menschen", "👥", "Menschen"),
            ("wetter", "🌤️", "Wetter"),
            ("zeit", "⏰", "Zeit")
        ]
        
        for (index, (name, emoji, displayName)) in systemCategories.enumerated() {
            let category = TagCategory(context: viewContext)
            category.id = UUID()
            category.name = name
            category.displayName = displayName
            category.emoji = emoji
            category.color = "blue"
            category.isSystemCategory = true
            category.sortOrder = Int32(index)
            category.isExpanded = true
            category.createdAt = Date()
        }
    }
    
    private func createSystemTags() {
        let systemTags: [(String, String?, String, String)] = [
            // Orte
            ("restaurant", "🍽️", "Restaurant", "orte"),
            ("café", "☕", "Café", "orte"),
            ("park", "🌳", "Park", "orte"),
            ("museum", "🏛️", "Museum", "orte"),
            ("strand", "🏖️", "Strand", "orte"),
            
            // Aktivitäten
            ("wandern", "🥾", "Wandern", "aktivitäten"),
            ("fotografie", "📸", "Fotografie", "aktivitäten"),
            ("sport", "⚽", "Sport", "aktivitäten"),
            ("essen", "🍽️", "Essen", "aktivitäten"),
            ("entspannung", "😌", "Entspannung", "aktivitäten"),
            
            // Menschen
            ("familie", "👨‍👩‍👧‍👦", "Familie", "menschen"),
            ("freunde", "👫", "Freunde", "menschen"),
            ("allein", "🧘", "Allein", "menschen"),
            
            // Wetter
            ("sonnig", "☀️", "Sonnig", "wetter"),
            ("regnerisch", "🌧️", "Regnerisch", "wetter"),
            ("bewölkt", "☁️", "Bewölkt", "wetter"),
            
            // Zeit
            ("morgen", "🌅", "Morgen", "zeit"),
            ("mittag", "🌞", "Mittag", "zeit"),
            ("abend", "🌅", "Abend", "zeit"),
            ("nacht", "🌙", "Nacht", "zeit")
        ]
        
        for (name, emoji, displayName, categoryName) in systemTags {
            let tag = Tag(context: viewContext)
            tag.id = UUID()
            tag.name = name
            tag.normalizedName = name.folding(options: .diacriticInsensitive, locale: .current)
            tag.displayName = displayName
            tag.emoji = emoji
            tag.color = randomColor()
            tag.isSystemTag = true
            tag.usageCount = 0
            tag.createdAt = Date()
            tag.lastUsedAt = Date()
            tag.isArchived = false
            tag.sortOrder = 0
            
            // Kategorie zuweisen
            if let category = allCategories.first(where: { $0.name == categoryName }) {
                tag.category = category
            }
        }
    }
    
    // MARK: - Utility
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Fehler beim Speichern des Kontexts: \(error)")
        }
    }
    
    private func updateFilteredTags() {
        filteredTags = searchTags(query: searchQuery)
    }
    
    func setTags(_ tags: Set<Tag>, for memory: Memory) {
        // Alle aktuellen Tags entfernen
        let currentTags = memory.tagArray
        for tag in currentTags {
            memory.removeFromTags(tag)
            decrementUsage(for: tag)
        }
        
        // Neue Tags hinzufügen
        for tag in tags {
            memory.addToTags(tag)
            incrementUsage(for: tag)
        }
        
        saveContext()
    }
    
    func addTag(_ tag: Tag, to memory: Memory) {
        if !memory.hasTag(tag) {
            memory.addToTags(tag)
            incrementUsage(for: tag)
            saveContext()
        }
    }
    
    func removeTag(_ tag: Tag, from memory: Memory) {
        if memory.hasTag(tag) {
            memory.removeFromTags(tag)
            decrementUsage(for: tag)
            saveContext()
        }
    }
}

// MARK: - Extensions

extension Character {
    var isEmoji: Bool {
        return unicodeScalars.allSatisfy { scalar in
            scalar.properties.isEmojiPresentation ||
            scalar.properties.isEmojiModifier ||
            scalar.properties.isEmojiModifierBase ||
            (scalar.value >= 0x1F600 && scalar.value <= 0x1F64F) ||
            (scalar.value >= 0x1F300 && scalar.value <= 0x1F5FF) ||
            (scalar.value >= 0x1F680 && scalar.value <= 0x1F6FF) ||
            (scalar.value >= 0x2600 && scalar.value <= 0x26FF) ||
            (scalar.value >= 0x2700 && scalar.value <= 0x27BF)
        }
    }
} 