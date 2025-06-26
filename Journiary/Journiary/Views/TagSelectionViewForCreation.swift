//
//  TagSelectionViewForCreation.swift
//  Journiary
//
//  Created by Assistant on 06.11.25.
//

import SwiftUI
import CoreData
import MapKit

struct TagSelectionViewForCreation: View {
    @Binding var selectedTags: Set<Tag>
    let viewContext: NSManagedObjectContext
    
    @StateObject private var tagManager: TagManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var showingCreateTag = false
    @State private var selectedCategory: TagCategory?
    
    init(selectedTags: Binding<Set<Tag>>, viewContext: NSManagedObjectContext) {
        self._selectedTags = selectedTags
        self.viewContext = viewContext
        self._tagManager = StateObject(wrappedValue: TagManager(viewContext: viewContext))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchSection
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Suggestions
                        if searchText.isEmpty {
                            suggestionsSection
                        }
                        
                        // Categories and Tags
                        if searchText.isEmpty {
                            categoriesSection
                        } else {
                            searchResultsSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Tags auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Neuer Tag") {
                        showingCreateTag = true
                    }
                }
            }
        }
        .onAppear {
            tagManager.loadData()
        }
        .sheet(isPresented: $showingCreateTag) {
            CreateTagSheet(viewContext: viewContext, tagManager: tagManager)
        }
    }
    
    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Tags suchen...", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button("Löschen") {
                    searchText = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Häufig verwendet")
                .font(.headline)
                .padding(.horizontal)
            
            if tagManager.frequentlyUsedTags.isEmpty {
                Text("Noch keine Tags verwendet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                          } else {
                FlowLayout(spacing: 8) {
                    ForEach(tagManager.frequentlyUsedTags.prefix(10), id: \.objectID) { tag in
                        TagChip(tag: tag, isSelected: selectedTags.contains(tag)) {
                            toggleTag(tag)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(tagManager.categories, id: \.objectID) { category in
                CategorySection(
                    category: category,
                    tags: tagManager.tags(for: category),
                    selectedTags: selectedTags,
                    onTagToggle: toggleTag
                )
            }
        }
    }
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suchergebnisse")
                .font(.headline)
            
            let results = tagManager.searchTags(query: searchText)
            
            if results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Keine Tags gefunden")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("'\(searchText)' als neuen Tag erstellen") {
                        createTagFromSearch()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                          } else {
                FlowLayout(spacing: 8) {
                    ForEach(results, id: \.objectID) { tag in
                        TagChip(tag: tag, isSelected: selectedTags.contains(tag)) {
                            toggleTag(tag)
                        }
                    }
                }
            }
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func createTagFromSearch() {
        if let newTag = tagManager.createTag(
            name: searchText,
            emoji: nil,
            color: TagColor.defaultColor,
            category: nil
        ) {
            selectedTags.insert(newTag)
            searchText = ""
        }
    }
}

struct CategorySection: View {
    let category: TagCategory
    let tags: [Tag]
    let selectedTags: Set<Tag>
    let onTagToggle: (Tag) -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    if let emoji = category.emoji, !emoji.isEmpty {
                        Text(emoji)
                            .font(.title3)
                    }
                    
                    Text(category.displayName ?? category.name ?? "")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            if isExpanded && !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.objectID) { tag in
                        TagChip(tag: tag, isSelected: selectedTags.contains(tag)) {
                            onTagToggle(tag)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
}

struct CreateTagSheet: View {
    let viewContext: NSManagedObjectContext
    let tagManager: TagManager
    
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = ""
    @State private var selectedColor = TagColor.defaultColor
    @State private var selectedCategory: TagCategory?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Tag-Details") {
                    TextField("Name", text: $name)
                    TextField("Emoji (optional)", text: $emoji)
                }
                
                Section("Farbe") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(TagColor.availableColors, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(TagColor.color(from: color))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section("Kategorie") {
                    Picker("Kategorie", selection: $selectedCategory) {
                        Text("Keine Kategorie").tag(TagCategory?.none)
                        ForEach(tagManager.categories, id: \.objectID) { category in
                            Text(category.displayName ?? category.name ?? "").tag(category as TagCategory?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Neuen Tag erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Erstellen") {
                        createTag()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createTag() {
        _ = tagManager.createTag(
            name: name,
            emoji: emoji.isEmpty ? nil : emoji,
            color: selectedColor,
            category: selectedCategory
        )
        dismiss()
    }
} 