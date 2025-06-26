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

// MARK: - Tag Manager

@MainActor
class TagManager: ObservableObject {
    
    // MARK: - Properties
    
    private let viewContext: NSManagedObjectContext
    
    @Published var allTags: [Tag] = []
    @Published var tagCategories: [TagCategory] = []
    @Published var suggestedTags: [Tag] = []
    @Published var frequentlyUsedTags: [Tag] = []
    @Published var searchQuery: String = ""
    @Published var filteredTags: [Tag] = []
    
    private var systemTagsInitialized = false
    
    // MARK: - Initialization
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        loadData()
        initializeSystemTagsIfNeeded()
    }
    
    // MARK: - Data Loading
    
    func loadData() {
        loadTags()
        loadCategories()
        updateFilteredTags()
        updateFrequentlyUsedTags()
    }
    
    private func loadTags() {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Tag.usageCount, ascending: false),
            NSSortDescriptor(keyPath: \Tag.name, ascending: true)
        ]
        request.predicate = NSPredicate(format: "isArchived == NO")
        
        do {
            allTags = try viewContext.fetch(request)
        } catch {
            print("Fehler beim Laden der Tags: \(error)")
            allTags = []
        }
    }
    
    private func loadCategories() {
        let request: NSFetchRequest<TagCategory> = TagCategory.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TagCategory.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \TagCategory.name, ascending: true)
        ]
        
        do {
            tagCategories = try viewContext.fetch(request)
        } catch {
            print("Fehler beim Laden der Tag-Kategorien: \(error)")
            tagCategories = []
        }
    }
    
    private func updateFilteredTags() {
        if searchQuery.isEmpty {
            filteredTags = allTags
        } else {
            filteredTags = allTags.filter { tag in
                tag.name?.localizedCaseInsensitiveContains(searchQuery) == true ||
                tag.displayName?.localizedCaseInsensitiveContains(searchQuery) == true
            }
        }
    }
    
    private func updateFrequentlyUsedTags() {
        frequentlyUsedTags = Array(allTags.filter { ($0.usageCount > 0) }.prefix(8))
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
    
    // MARK: - Tag Management
    
    func createTag(name: String, category: TagCategory? = nil, emoji: String? = nil, color: String? = nil) -> Tag? {
        // Prüfe ob Tag bereits existiert
        if let existingTag = findTag(byName: name) {
            return existingTag
        }
        
        let tag = Tag(context: viewContext)
        tag.id = UUID()
        tag.name = name
        tag.normalizedName = normalizedTagName(name)
        tag.displayName = name
        tag.emoji = emoji
        tag.color = color ?? TagColor.defaultColor
        tag.isSystemTag = false
        tag.usageCount = 0
        tag.createdAt = Date()
        tag.lastUsedAt = Date()
        tag.isArchived = false
        tag.sortOrder = 0
        tag.category = category
        
        save()
        loadData()
        
        return tag
    }
    
    func updateTag(_ tag: Tag, name: String? = nil, emoji: String? = nil, color: String? = nil, category: TagCategory? = nil) {
        if let name = name {
            tag.name = name
            tag.normalizedName = normalizedTagName(name)
            tag.displayName = name
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
        
        save()
        loadData()
    }
    
    func deleteTag(_ tag: Tag) {
        viewContext.delete(tag)
        save()
        loadData()
    }
    
    func archiveTag(_ tag: Tag) {
        tag.isArchived = true
        save()
        loadData()
    }
    
    func unarchiveTag(_ tag: Tag) {
        tag.isArchived = false
        save()
        loadData()
    }
    
    // MARK: - Category Management
    
    func createCategory(name: String, emoji: String? = nil, color: String? = nil, sortOrder: Int32 = 0) -> TagCategory? {
        let category = TagCategory(context: viewContext)
        category.id = UUID()
        category.name = name
        category.displayName = name
        category.emoji = emoji
        category.color = color ?? TagColor.defaultColor
        category.isSystemCategory = false
        category.sortOrder = sortOrder
        category.isExpanded = true
        category.createdAt = Date()
        
        save()
        loadData()
        
        return category
    }
    
    func updateCategory(_ category: TagCategory, name: String? = nil, emoji: String? = nil, color: String? = nil) {
        if let name = name {
            category.name = name
            category.displayName = name
        }
        if let emoji = emoji {
            category.emoji = emoji
        }
        if let color = color {
            category.color = color
        }
        
        save()
        loadData()
    }
    
    func deleteCategory(_ category: TagCategory) {
        // Tags in dieser Kategorie zu "Allgemein" verschieben oder ohne Kategorie lassen
        if let tags = category.tags?.allObjects as? [Tag] {
            for tag in tags {
                tag.category = nil
            }
        }
        
        viewContext.delete(category)
        save()
        loadData()
    }
    
    // MARK: - Memory Tag Operations
    
    func addTag(_ tag: Tag, to memory: Memory) {
        if !(memory.tags?.contains(tag) ?? false) {
            memory.addToTags(tag)
            incrementUsageCount(for: tag)
            save()
        }
    }
    
    func removeTag(_ tag: Tag, from memory: Memory) {
        memory.removeFromTags(tag)
        decrementUsageCount(for: tag)
        save()
    }
    
    func setTags(_ tags: Set<Tag>, for memory: Memory) {
        // Entferne alle alten Tags
        if let oldTags = memory.tags?.allObjects as? [Tag] {
            for oldTag in oldTags {
                memory.removeFromTags(oldTag)
                decrementUsageCount(for: oldTag)
            }
        }
        
        // Füge neue Tags hinzu
        for tag in tags {
            memory.addToTags(tag)
            incrementUsageCount(for: tag)
        }
        
        save()
        loadData()
    }
    
    // MARK: - Tag Discovery & Suggestions
    
    func suggestTags(for memory: Memory) -> [Tag] {
        var suggestions: [Tag] = []
        
        // 1. Tags basierend auf Standort
        if let locationName = memory.locationName {
            suggestions.append(contentsOf: suggestTagsForLocation(locationName))
        }
        
        // 2. Tags basierend auf Text-Inhalt
        if let text = memory.text {
            suggestions.append(contentsOf: suggestTagsForText(text))
        }
        
        // 3. Tags basierend auf Zeitpunkt
        if let timestamp = memory.timestamp {
            suggestions.append(contentsOf: suggestTagsForTime(timestamp))
        }
        
        // 4. Häufig verwendete Tags
        suggestions.append(contentsOf: frequentlyUsedTags.prefix(3))
        
        // Entferne Duplikate und bereits vorhandene Tags
        let memoryTags = memory.tags?.allObjects as? [Tag] ?? []
        let uniqueSuggestions = Array(Set(suggestions))
            .filter { !memoryTags.contains($0) }
            .prefix(6)
        
        return Array(uniqueSuggestions)
    }
    
    private func suggestTagsForLocation(_ locationName: String) -> [Tag] {
        let locationKeywords = [
            "restaurant": ["🍽️", "Restaurant", "Essen"],
            "museum": ["🏛️", "Museum", "Kultur"],
            "park": ["🌳", "Park", "Natur"],
            "strand": ["🏖️", "Strand", "Meer"],
            "berg": ["⛰️", "Berg", "Wandern"],
            "hotel": ["🏨", "Hotel", "Übernachtung"],
            "flughafen": ["✈️", "Flughafen", "Reise"],
            "bahnhof": ["🚉", "Bahnhof", "Transport"]
        ]
        
        var suggestions: [Tag] = []
        let lowercaseLocation = locationName.lowercased()
        
        for (keyword, tagInfo) in locationKeywords {
            if lowercaseLocation.contains(keyword) {
                if let tag = findOrCreateSystemTag(name: tagInfo[1], emoji: tagInfo[0], category: getOrCreateCategory("Orte")) {
                    suggestions.append(tag)
                }
            }
        }
        
        return suggestions
    }
    
    private func suggestTagsForText(_ text: String) -> [Tag] {
        let textKeywords = [
            "essen": ["🍽️", "Essen"],
            "restaurant": ["🍽️", "Restaurant"],
            "museum": ["🏛️", "Museum"],
            "kunst": ["🎨", "Kunst"],
            "natur": ["🌿", "Natur"],
            "wandern": ["🥾", "Wandern"],
            "strand": ["🏖️", "Strand"],
            "shopping": ["🛍️", "Shopping"],
            "konzert": ["🎵", "Konzert"],
            "sport": ["⚽", "Sport"],
            "freunde": ["👥", "Freunde"],
            "familie": ["👨‍👩‍👧‍👦", "Familie"]
        ]
        
        var suggestions: [Tag] = []
        let lowercaseText = text.lowercased()
        
        for (keyword, tagInfo) in textKeywords {
            if lowercaseText.contains(keyword) {
                if let tag = findOrCreateSystemTag(name: tagInfo[1], emoji: tagInfo[0], category: getOrCreateCategory("Aktivitäten")) {
                    suggestions.append(tag)
                }
            }
        }
        
        return suggestions
    }
    
    private func suggestTagsForTime(_ timestamp: Date) -> [Tag] {
        var suggestions: [Tag] = []
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)
        
        // Tageszeit-basierte Tags
        if hour >= 5 && hour < 12 {
            if let tag = findOrCreateSystemTag(name: "Morgen", emoji: "🌅", category: getOrCreateCategory("Tageszeit")) {
                suggestions.append(tag)
            }
        } else if hour >= 12 && hour < 17 {
            if let tag = findOrCreateSystemTag(name: "Mittag", emoji: "☀️", category: getOrCreateCategory("Tageszeit")) {
                suggestions.append(tag)
            }
        } else if hour >= 17 && hour < 21 {
            if let tag = findOrCreateSystemTag(name: "Abend", emoji: "🌆", category: getOrCreateCategory("Tageszeit")) {
                suggestions.append(tag)
            }
        } else {
            if let tag = findOrCreateSystemTag(name: "Nacht", emoji: "🌙", category: getOrCreateCategory("Tageszeit")) {
                suggestions.append(tag)
            }
        }
        
        // Wochentag-basierte Tags
        let weekday = calendar.component(.weekday, from: timestamp)
        if weekday == 1 || weekday == 7 { // Sonntag oder Samstag
            if let tag = findOrCreateSystemTag(name: "Wochenende", emoji: "🎉", category: getOrCreateCategory("Zeit")) {
                suggestions.append(tag)
            }
        } else {
            if let tag = findOrCreateSystemTag(name: "Wochentag", emoji: "📅", category: getOrCreateCategory("Zeit")) {
                suggestions.append(tag)
            }
        }
        
        return suggestions
    }
    
    // MARK: - Helper Methods
    
    private func normalizedTagName(_ name: String) -> String {
        return name.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .folding(options: .diacriticInsensitive, locale: .current)
    }
    
    private func findTag(byName name: String) -> Tag? {
        let normalizedSearchName = normalizedTagName(name)
        return allTags.first { $0.normalizedName == normalizedSearchName }
    }
    
    private func findOrCreateSystemTag(name: String, emoji: String, category: TagCategory?) -> Tag? {
        if let existingTag = findTag(byName: name) {
            return existingTag
        }
        
        let tag = Tag(context: viewContext)
        tag.id = UUID()
        tag.name = name
        tag.normalizedName = normalizedTagName(name)
        tag.displayName = name
        tag.emoji = emoji
        tag.color = TagColor.systemColor
        tag.isSystemTag = true
        tag.usageCount = 0
        tag.createdAt = Date()
        tag.lastUsedAt = Date()
        tag.isArchived = false
        tag.sortOrder = 0
        tag.category = category
        
        return tag
    }
    
    private func getOrCreateCategory(_ name: String) -> TagCategory? {
        if let existingCategory = tagCategories.first(where: { $0.name == name }) {
            return existingCategory
        }
        
        return createCategory(name: name, emoji: categoryEmoji(for: name), sortOrder: Int32(tagCategories.count))
    }
    
    private func categoryEmoji(for categoryName: String) -> String {
        switch categoryName {
        case "Orte": return "📍"
        case "Aktivitäten": return "🎯"
        case "Tageszeit": return "⏰"
        case "Zeit": return "📅"
        case "Menschen": return "👥"
        case "Wetter": return "🌤️"
        case "Transport": return "🚗"
        case "Essen": return "🍽️"
        default: return "🏷️"
        }
    }
    
    private func incrementUsageCount(for tag: Tag) {
        tag.usageCount += 1
        tag.lastUsedAt = Date()
    }
    
    private func decrementUsageCount(for tag: Tag) {
        if tag.usageCount > 0 {
            tag.usageCount -= 1
        }
    }
    
    private func save() {
        do {
            try viewContext.save()
        } catch {
            print("Fehler beim Speichern der Tags: \(error)")
        }
    }
    
    // MARK: - System Tags Initialization
    
    private func initializeSystemTagsIfNeeded() {
        if systemTagsInitialized || !allTags.isEmpty { return }
        
        let systemTags = [
            ("Orte", [
                ("Restaurant", "🍽️"),
                ("Museum", "🏛️"),
                ("Park", "🌳"),
                ("Strand", "🏖️"),
                ("Berg", "⛰️"),
                ("Hotel", "🏨"),
                ("Flughafen", "✈️"),
                ("Bahnhof", "🚉")
            ]),
            ("Aktivitäten", [
                ("Essen", "🍽️"),
                ("Wandern", "🥾"),
                ("Shopping", "🛍️"),
                ("Konzert", "🎵"),
                ("Sport", "⚽"),
                ("Kultur", "🎭"),
                ("Entspannung", "🧘"),
                ("Abenteuer", "🗺️")
            ]),
            ("Menschen", [
                ("Familie", "👨‍👩‍👧‍👦"),
                ("Freunde", "👥"),
                ("Alleine", "🧍"),
                ("Paar", "💑")
            ]),
            ("Wetter", [
                ("Sonnig", "☀️"),
                ("Regnerisch", "🌧️"),
                ("Bewölkt", "☁️"),
                ("Schnee", "❄️")
            ])
        ]
        
        for (categoryName, tags) in systemTags {
            let category = getOrCreateCategory(categoryName)
            
            for (tagName, emoji) in tags {
                _ = findOrCreateSystemTag(name: tagName, emoji: emoji, category: category)
            }
        }
        
        save()
        loadData()
        systemTagsInitialized = true
    }
}

// MARK: - Tag Colors

struct TagColor {
    static let defaultColor = "blue"
    static let systemColor = "gray"
    
    static let availableColors = [
        "blue", "green", "red", "orange", "purple", "pink", 
        "yellow", "indigo", "teal", "cyan", "mint", "brown"
    ]
    
    static func color(from string: String) -> Color {
        switch string {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "indigo": return .indigo
        case "teal": return .teal
        case "cyan": return .cyan
        case "mint": return .mint
        case "brown": return .brown
        default: return .blue
        }
    }
}

// MARK: - Extensions

extension Memory {
    var tagArray: [Tag] {
        return (tags?.allObjects as? [Tag])?.sorted { $0.name ?? "" < $1.name ?? "" } ?? []
    }
    
    func hasTag(_ tag: Tag) -> Bool {
        return tags?.contains(tag) ?? false
    }
}

extension Tag {
    var colorValue: Color {
        return TagColor.color(from: color ?? TagColor.defaultColor)
    }
    
    var displayText: String {
        if let emoji = emoji, !emoji.isEmpty {
            return "\(emoji) \(displayName ?? name ?? "")"
        }
        return displayName ?? name ?? ""
    }
} 