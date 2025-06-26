//
//  TagSelectionView.swift
//  Journiary
//
//  Created by Assistant on 06.11.25.
//

import SwiftUI
import CoreData
import MapKit

struct TagSelectionView: View {
    let memory: Memory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var tagManager: TagManager
    
    @State private var selectedTags: Set<Tag> = []
    @State private var searchText: String = ""
    @State private var showingCreateTag = false
    @State private var showingSuggestions = true
    @State private var newTagName = ""
    @State private var selectedCategory: TagCategory?
    @State private var showingCategoryPicker = false
    
    init(memory: Memory, viewContext: NSManagedObjectContext) {
        self.memory = memory
        self._tagManager = StateObject(wrappedValue: TagManager(viewContext: viewContext))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if showingSuggestions && !suggestedTags.isEmpty {
                            suggestionsSection
                        }
                        
                        if !selectedTags.isEmpty {
                            selectedTagsSection
                        }
                        
                        if !searchText.isEmpty {
                            searchResultsSection
                        } else {
                            categorizedTagsSection
                        }
                        
                        if !searchText.isEmpty && !exactMatchExists {
                            createNewTagSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Tags hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        saveTags()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentTags()
                updateSuggestions()
            }
        }
    }
    
    // MARK: - UI Components
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Tags suchen oder erstellen...", text: $searchText)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { _, newValue in
                    tagManager.search(query: newValue)
                    showingSuggestions = newValue.isEmpty
                }
            
            if !searchText.isEmpty {
                Button("Löschen") {
                    searchText = ""
                    tagManager.clearSearch()
                    showingSuggestions = true
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Vorschläge für diese Erinnerung")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { showingSuggestions.toggle() }) {
                    Image(systemName: showingSuggestions ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            
            if showingSuggestions {
                TagCloudView(
                    tags: suggestedTags,
                    selectedTags: $selectedTags,
                    isSelected: false,
                    onTagTapped: { tag in
                        toggleTag(tag)
                    }
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var selectedTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ausgewählte Tags (\(selectedTags.count))")
                .font(.headline)
                .foregroundColor(.primary)
            
            TagCloudView(
                tags: Array(selectedTags),
                selectedTags: $selectedTags,
                isSelected: true,
                onTagTapped: { tag in
                    toggleTag(tag)
                }
            )
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suchergebnisse")
                .font(.headline)
                .foregroundColor(.primary)
            
            if tagManager.filteredTags.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Keine Tags gefunden")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                TagCloudView(
                    tags: tagManager.filteredTags,
                    selectedTags: $selectedTags,
                    isSelected: false,
                    onTagTapped: { tag in
                        toggleTag(tag)
                    }
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var categorizedTagsSection: some View {
        VStack(spacing: 16) {
            ForEach(tagManager.tagCategories, id: \.objectID) { category in
                CategorySection(
                    category: category,
                    tags: tagManager.tags(for: category),
                    selectedTags: selectedTags,
                    onTagToggle: { tag in
                        toggleTag(tag)
                    }
                )
            }
            
            // Tags ohne Kategorie
            let uncategorizedTags = tagManager.allTags.filter { $0.category == nil }
            if !uncategorizedTags.isEmpty {
                UncategorizedSection(
                    tags: uncategorizedTags,
                    selectedTags: $selectedTags,
                    onTagTapped: { tag in
                        toggleTag(tag)
                    }
                )
            }
        }
    }
    
    private var createNewTagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Neuen Tag erstellen")
                .font(.headline)
                .foregroundColor(.primary)
            
            Button(action: createNewTag) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("'\(searchText)' als neuen Tag hinzufügen")
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Helper Properties
    
    private var suggestedTags: [Tag] {
        tagManager.suggestTags(for: memory)
    }
    
    private var exactMatchExists: Bool {
        tagManager.filteredTags.contains { $0.name?.lowercased() == searchText.lowercased() }
    }
    
    // MARK: - Actions
    
    private func loadCurrentTags() {
        selectedTags = Set(memory.tagArray)
    }
    
    private func toggleTag(_ tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func createNewTag() {
        guard !searchText.isEmpty else { return }
        
        if let newTag = tagManager.createTag(name: searchText, category: selectedCategory) {
            selectedTags.insert(newTag)
            searchText = ""
            tagManager.clearSearch()
        }
    }
    
    private func saveTags() {
        tagManager.setTags(selectedTags, for: memory)
    }
    
    private func updateSuggestions() {
        // Aktualisiere Vorschläge wenn sich die Erinnerung ändert
    }
}

// MARK: - Supporting Views
// CategorySection wird aus TagSelectionViewForCreation.swift verwendet

struct TagCloudView: View {
    let tags: [Tag]
    @Binding var selectedTags: Set<Tag>
    let isSelected: Bool
    let onTagTapped: (Tag) -> Void
    
    init(tags: [Tag], selectedTags: Binding<Set<Tag>>, isSelected: Bool = false, onTagTapped: @escaping (Tag) -> Void) {
        self.tags = tags
        self._selectedTags = selectedTags
        self.isSelected = isSelected
        self.onTagTapped = onTagTapped
    }
    
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.objectID) { tag in
                TagChip(
                    tag: tag,
                    isSelected: isSelected || selectedTags.contains(tag),
                    action: {
                        onTagTapped(tag)
                    }
                )
            }
        }
    }
}

struct UncategorizedSection: View {
    let tags: [Tag]
    @Binding var selectedTags: Set<Tag>
    let onTagTapped: (Tag) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🏷️ Allgemein")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("(\(tags.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            TagCloudView(
                tags: tags,
                selectedTags: $selectedTags,
                isSelected: false,
                onTagTapped: onTagTapped
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// FlowLayout wird aus FlowLayout.swift importiert 