//
//  TagDisplayView.swift
//  Journiary
//
//  Created by Assistant on 06.11.25.
//

import SwiftUI
import CoreData

// MARK: - Kompakte Tag-Anzeige für Memory-Karten

struct TagDisplayView: View {
    let memory: Memory
    let maxDisplayedTags: Int
    let style: TagDisplayStyle
    let onTagTapped: ((Tag) -> Void)?
    
    init(memory: Memory, maxDisplayedTags: Int = 3, style: TagDisplayStyle = .compact, onTagTapped: ((Tag) -> Void)? = nil) {
        self.memory = memory
        self.maxDisplayedTags = maxDisplayedTags
        self.style = style
        self.onTagTapped = onTagTapped
    }
    
    private var displayedTags: [Tag] {
        Array(memory.tagArray.prefix(maxDisplayedTags))
    }
    
    private var remainingTagsCount: Int {
        max(0, memory.tagArray.count - maxDisplayedTags)
    }
    
    var body: some View {
        if !memory.tagArray.isEmpty {
            switch style {
            case .compact:
                compactView
            case .expanded:
                expandedView
            case .minimal:
                minimalView
            }
        }
    }
    
    // MARK: - Compact View (für Memory-Karten)
    
    private var compactView: some View {
        HStack(spacing: 6) {
            ForEach(displayedTags, id: \.objectID) { tag in
                TagMiniChip(tag: tag, onTapped: onTagTapped)
            }
            
            if remainingTagsCount > 0 {
                Text("+\(remainingTagsCount)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Expanded View (für Detail-Ansichten)
    
    private var expandedView: some View {
                        FlowLayout(spacing: 8) {
                    ForEach(memory.tagArray, id: \.objectID) { tag in
                        TagChip(tag: tag, isSelected: false) {
                            onTagTapped?(tag)
                        }
                    }
                }
    }
    
    // MARK: - Minimal View (nur Icons)
    
    private var minimalView: some View {
        HStack(spacing: 4) {
            ForEach(displayedTags, id: \.objectID) { tag in
                if let emoji = tag.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.caption)
                } else {
                    Circle()
                        .fill(tag.colorValue)
                        .frame(width: 8, height: 8)
                }
            }
            
            if remainingTagsCount > 0 {
                Text("•••")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Tag Display Styles

enum TagDisplayStyle {
    case compact    // Für Memory-Karten
    case expanded   // Für Detail-Ansichten
    case minimal    // Nur Icons/Emojis
}

// MARK: - Mini Tag Chip

struct TagMiniChip: View {
    let tag: Tag
    let onTapped: ((Tag) -> Void)?
    
    var body: some View {
        Button(action: { onTapped?(tag) }) {
            HStack(spacing: 3) {
                if let emoji = tag.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.caption2)
                }
                
                Text(tag.displayName ?? tag.name ?? "")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(tag.colorValue)
            )
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tag.colorValue.opacity(0.7), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(onTapped == nil)
    }
}

// MARK: - Editable Tag Section

struct EditableTagSection: View {
    let memory: Memory
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingTagSelection = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Tags", systemImage: "tag.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Bearbeiten") {
                    showingTagSelection = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if memory.tagArray.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Keine Tags")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Tags hinzufügen") {
                        showingTagSelection = true
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                TagDisplayView(
                    memory: memory,
                    maxDisplayedTags: 20,
                    style: .expanded
                )
            }
        }
        .sheet(isPresented: $showingTagSelection) {
            TagSelectionView(memory: memory, viewContext: viewContext)
        }
    }
}

// MARK: - Quick Tag Selector

struct QuickTagSelector: View {
    let memory: Memory
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var tagManager: TagManager
    
    init(memory: Memory, viewContext: NSManagedObjectContext) {
        self.memory = memory
        self._tagManager = StateObject(wrappedValue: TagManager(viewContext: viewContext))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Häufig verwendete Tags")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if tagManager.frequentlyUsedTags.isEmpty {
                Text("Noch keine Tags verwendet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                                 FlowLayout(spacing: 6) {
                    ForEach(tagManager.frequentlyUsedTags, id: \.objectID) { tag in
                        QuickTagButton(
                            tag: tag,
                            isSelected: memory.hasTag(tag),
                            onToggle: {
                                toggleTag(tag)
                            }
                        )
                    }
                }
            }
        }
        .onAppear {
            tagManager.loadData()
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        if memory.hasTag(tag) {
            tagManager.removeTag(tag, from: memory)
        } else {
            tagManager.addTag(tag, to: memory)
        }
    }
}

struct QuickTagButton: View {
    let tag: Tag
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 4) {
                if let emoji = tag.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.caption)
                }
                
                Text(tag.displayName ?? tag.name ?? "")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? tag.colorValue : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(tag.colorValue.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Filter Bar

struct TagFilterBar: View {
    @Binding var selectedTags: Set<Tag>
    @StateObject private var tagManager: TagManager
    let onFilterChanged: () -> Void
    
    init(selectedTags: Binding<Set<Tag>>, viewContext: NSManagedObjectContext, onFilterChanged: @escaping () -> Void) {
        self._selectedTags = selectedTags
        self._tagManager = StateObject(wrappedValue: TagManager(viewContext: viewContext))
        self.onFilterChanged = onFilterChanged
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filter nach Tags")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !selectedTags.isEmpty {
                    Button("Reset") {
                        selectedTags.removeAll()
                        onFilterChanged()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tagManager.frequentlyUsedTags.prefix(10), id: \.objectID) { tag in
                            FilterTagChip(
                                tag: tag,
                                isSelected: false,
                                onToggle: {
                                    selectedTags.insert(tag)
                                    onFilterChanged()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(selectedTags), id: \.objectID) { tag in
                        FilterTagChip(
                            tag: tag,
                            isSelected: true,
                            onToggle: {
                                selectedTags.remove(tag)
                                onFilterChanged()
                            }
                        )
                    }
                }
            }
        }
        .onAppear {
            tagManager.loadData()
        }
    }
}

struct FilterTagChip: View {
    let tag: Tag
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 4) {
                if let emoji = tag.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.caption)
                }
                
                Text(tag.displayName ?? tag.name ?? "")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? tag.colorValue : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tag.colorValue.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
} 