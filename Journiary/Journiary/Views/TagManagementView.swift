//
//  TagManagementView.swift
//  Journiary
//
//  Created by Assistant on 06.11.25.
//

import SwiftUI
import CoreData

struct TagManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tagManager: TagManager
    
    @State private var searchText = ""
    @State private var selectedSegment = 0
    @State private var showingCreateTag = false
    @State private var showingCreateCategory = false
    @State private var selectedTag: Tag?
    @State private var selectedCategory: TagCategory?
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: NSManagedObject?
    
    private let segments = ["Tags", "Kategorien"]
    
    init(viewContext: NSManagedObjectContext) {
        self._tagManager = StateObject(wrappedValue: TagManager(viewContext: viewContext))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Segment Control
                Picker("Ansicht", selection: $selectedSegment) {
                    ForEach(0..<segments.count, id: \.self) { index in
                        Text(segments[index]).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Suchen...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onChange(of: searchText) { _, newValue in
                            tagManager.search(query: newValue)
                        }
                    
                    if !searchText.isEmpty {
                        Button("Löschen") {
                            searchText = ""
                            tagManager.clearSearch()
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Content
                Group {
                    if selectedSegment == 0 {
                        tagListView
                    } else {
                        categoryListView
                    }
                }
            }
            .navigationTitle("Tag-Verwaltung")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Neuer Tag", systemImage: "tag.fill") {
                            showingCreateTag = true
                        }
                        
                        Button("Neue Kategorie", systemImage: "folder.fill") {
                            showingCreateCategory = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateTag) {
                CreateTagView(tagManager: tagManager)
            }
            .sheet(isPresented: $showingCreateCategory) {
                CreateCategoryView(tagManager: tagManager)
            }
            .sheet(item: $selectedTag) { tag in
                EditTagView(tag: tag, tagManager: tagManager)
            }
            .sheet(item: $selectedCategory) { category in
                EditCategoryView(category: category, tagManager: tagManager)
            }
            .alert("Löschen bestätigen", isPresented: $showingDeleteAlert) {
                Button("Löschen", role: .destructive) {
                    deleteItem()
                }
                Button("Abbrechen", role: .cancel) {
                    itemToDelete = nil
                }
            } message: {
                if let tag = itemToDelete as? Tag {
                    Text("Möchten Sie den Tag '\(tag.name ?? "")' wirklich löschen?")
                } else if let category = itemToDelete as? TagCategory {
                    Text("Möchten Sie die Kategorie '\(category.name ?? "")' wirklich löschen? Die enthaltenen Tags werden zu 'Allgemein' verschoben.")
                }
            }
            .onAppear {
                tagManager.loadData()
            }
        }
    }
    
    // MARK: - Tag List View
    
    private var tagListView: some View {
        List {
            if tagManager.filteredTags.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tag")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("Keine Tags gefunden")
                        .font(.headline)
                    
                    Button("Ersten Tag erstellen") {
                        showingCreateTag = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(groupedTags, id: \.key) { categoryName, tags in
                    Section {
                        ForEach(tags, id: \.objectID) { tag in
                            TagRowView(tag: tag) {
                                selectedTag = tag
                            } onDelete: {
                                itemToDelete = tag
                                showingDeleteAlert = true
                            }
                        }
                        .onDelete { indexSet in
                            let tagsToDelete = indexSet.map { tags[$0] }
                            for tag in tagsToDelete {
                                tagManager.deleteTag(tag)
                            }
                        }
                    } header: {
                        Text(categoryName)
                            .font(.headline)
                            .textCase(.none)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            tagManager.loadData()
        }
    }
    
    // MARK: - Category List View
    
    private var categoryListView: some View {
        List {
            if tagManager.tagCategories.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("Keine Kategorien gefunden")
                        .font(.headline)
                    
                    Button("Erste Kategorie erstellen") {
                        showingCreateCategory = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(tagManager.tagCategories, id: \.objectID) { category in
                    CategoryRowView(category: category) {
                        selectedCategory = category
                    } onDelete: {
                        itemToDelete = category
                        showingDeleteAlert = true
                    }
                }
                .onDelete { indexSet in
                    let categoriesToDelete = indexSet.map { tagManager.tagCategories[$0] }
                    for category in categoriesToDelete {
                        tagManager.deleteCategory(category)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            tagManager.loadData()
        }
    }
    
    // MARK: - Helper Properties
    
    private var groupedTags: [(key: String, value: [Tag])] {
        let tags = searchText.isEmpty ? tagManager.allTags : tagManager.filteredTags
        let grouped = Dictionary(grouping: tags) { tag in
            tag.category?.displayName ?? "Allgemein"
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    // MARK: - Actions
    
    private func deleteItem() {
        if let tag = itemToDelete as? Tag {
            tagManager.deleteTag(tag)
        } else if let category = itemToDelete as? TagCategory {
            tagManager.deleteCategory(category)
        }
        itemToDelete = nil
    }
}

// MARK: - Row Views

struct TagRowView: View {
    let tag: Tag
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            // Tag Chip
            HStack(spacing: 6) {
                if let emoji = tag.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.displayName ?? tag.name ?? "")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    HStack {
                        if tag.isSystemTag {
                            Label("System", systemImage: "gear")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("\(tag.usageCount) mal verwendet")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Color indicator
                Circle()
                    .fill(tag.colorValue)
                    .frame(width: 12, height: 12)
            }
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.borderless)
        }
        .swipeActions(edge: .trailing) {
            if !tag.isSystemTag {
                Button("Löschen", role: .destructive, action: onDelete)
            }
            Button("Bearbeiten", action: onEdit)
        }
    }
}

struct CategoryRowView: View {
    let category: TagCategory
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var tagCount: Int {
        (category.tags?.allObjects as? [Tag])?.count ?? 0
    }
    
    var body: some View {
        HStack {
            if let emoji = category.emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName ?? category.name ?? "")
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack {
                    if category.isSystemCategory {
                        Label("System", systemImage: "gear")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(tagCount) Tag\(tagCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Color indicator
            if let color = category.color {
                Circle()
                    .fill(TagColor.color(from: color))
                    .frame(width: 12, height: 12)
            }
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.borderless)
        }
        .swipeActions(edge: .trailing) {
            if !category.isSystemCategory {
                Button("Löschen", role: .destructive, action: onDelete)
            }
            Button("Bearbeiten", action: onEdit)
        }
    }
}

// MARK: - Create/Edit Views

struct CreateTagView: View {
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
                    
                    Picker("Farbe", selection: $selectedColor) {
                        ForEach(TagColor.availableColors, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(TagColor.color(from: color))
                                    .frame(width: 20, height: 20)
                                Text(color.capitalized)
                            }
                            .tag(color)
                        }
                    }
                    
                    Picker("Kategorie", selection: $selectedCategory) {
                        Text("Keine Kategorie").tag(nil as TagCategory?)
                        ForEach(tagManager.tagCategories, id: \.objectID) { category in
                            Text(category.displayName ?? "").tag(category as TagCategory?)
                        }
                    }
                }
            }
            .navigationTitle("Neuer Tag")
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

struct CreateCategoryView: View {
    let tagManager: TagManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var emoji = ""
    @State private var selectedColor = TagColor.defaultColor
    
    var body: some View {
        NavigationView {
            Form {
                Section("Kategorie-Details") {
                    TextField("Name", text: $name)
                    TextField("Emoji (optional)", text: $emoji)
                    
                    Picker("Farbe", selection: $selectedColor) {
                        ForEach(TagColor.availableColors, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(TagColor.color(from: color))
                                    .frame(width: 20, height: 20)
                                Text(color.capitalized)
                            }
                            .tag(color)
                        }
                    }
                }
            }
            .navigationTitle("Neue Kategorie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Erstellen") {
                        createCategory()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createCategory() {
        _ = tagManager.createCategory(
            name: name,
            emoji: emoji.isEmpty ? nil : emoji,
            color: selectedColor
        )
        dismiss()
    }
}

struct EditTagView: View {
    let tag: Tag
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
                    TextField("Emoji", text: $emoji)
                    
                    Picker("Farbe", selection: $selectedColor) {
                        ForEach(TagColor.availableColors, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(TagColor.color(from: color))
                                    .frame(width: 20, height: 20)
                                Text(color.capitalized)
                            }
                            .tag(color)
                        }
                    }
                    
                    if !tag.isSystemTag {
                        Picker("Kategorie", selection: $selectedCategory) {
                            Text("Keine Kategorie").tag(nil as TagCategory?)
                            ForEach(tagManager.tagCategories, id: \.objectID) { category in
                                Text(category.displayName ?? "").tag(category as TagCategory?)
                            }
                        }
                    }
                }
                
                Section("Statistiken") {
                    HStack {
                        Text("Verwendungen")
                        Spacer()
                        Text("\(tag.usageCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastUsed = tag.lastUsedAt {
                        HStack {
                            Text("Zuletzt verwendet")
                            Spacer()
                            Text(lastUsed.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Tag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        updateTag()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                loadTagData()
            }
        }
    }
    
    private func loadTagData() {
        name = tag.name ?? ""
        emoji = tag.emoji ?? ""
        selectedColor = tag.color ?? TagColor.defaultColor
        selectedCategory = tag.category
    }
    
    private func updateTag() {
        tagManager.updateTag(
            tag,
            name: name,
            emoji: emoji.isEmpty ? nil : emoji,
            color: selectedColor,
            category: selectedCategory
        )
        dismiss()
    }
}

struct EditCategoryView: View {
    let category: TagCategory
    let tagManager: TagManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var emoji = ""
    @State private var selectedColor = TagColor.defaultColor
    
    var body: some View {
        NavigationView {
            Form {
                Section("Kategorie-Details") {
                    TextField("Name", text: $name)
                    TextField("Emoji", text: $emoji)
                    
                    Picker("Farbe", selection: $selectedColor) {
                        ForEach(TagColor.availableColors, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(TagColor.color(from: color))
                                    .frame(width: 20, height: 20)
                                Text(color.capitalized)
                            }
                            .tag(color)
                        }
                    }
                }
                
                Section("Statistiken") {
                    let tagCount = (category.tags?.allObjects as? [Tag])?.count ?? 0
                    HStack {
                        Text("Enthaltene Tags")
                        Spacer()
                        Text("\(tagCount)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Kategorie bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        updateCategory()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                loadCategoryData()
            }
        }
    }
    
    private func loadCategoryData() {
        name = category.name ?? ""
        emoji = category.emoji ?? ""
        selectedColor = category.color ?? TagColor.defaultColor
    }
    
    private func updateCategory() {
        tagManager.updateCategory(
            category,
            name: name,
            emoji: emoji.isEmpty ? nil : emoji,
            color: selectedColor
        )
        dismiss()
    }
} 