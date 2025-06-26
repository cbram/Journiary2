//
//  TagChip.swift
//  Journiary
//
//  Created by Assistant on 06.11.25.
//

import SwiftUI

struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    init(tag: Tag, isSelected: Bool, action: @escaping () -> Void = {}) {
        self.tag = tag
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Emoji falls vorhanden
                if let emoji = tag.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.caption)
                }
                
                // Tag-Name
                Text(tag.displayName ?? tag.name ?? "")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // Auswahl-Indikator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
            )
            .foregroundColor(foregroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tag.colorValue, lineWidth: isSelected ? 0 : 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return tag.colorValue
        } else {
            return colorScheme == .dark ? Color(.systemGray5).opacity(0.18) : Color(.systemGray6)
        }
    }
    
    private var foregroundColor: Color {
        if isSelected {
            return .white
        } else {
            return colorScheme == .dark ? .white : .primary
        }
    }
}

struct RemovableTagChip: View {
    let tag: Tag
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // Emoji falls vorhanden
            if let emoji = tag.emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.caption)
            }
            
            // Tag-Name
            Text(tag.displayName ?? tag.name ?? "")
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)
            
            // Remove-Button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(tag.colorValue)
        )
        .foregroundColor(.white)
    }
}

struct CompactTagChip: View {
    let tag: Tag
    let showEmoji: Bool
    let onTap: (() -> Void)?
    
    init(tag: Tag, showEmoji: Bool = true, onTap: (() -> Void)? = nil) {
        self.tag = tag
        self.showEmoji = showEmoji
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 3) {
                if showEmoji, let emoji = tag.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.caption2)
                } else if !showEmoji {
                    Circle()
                        .fill(tag.colorValue)
                        .frame(width: 6, height: 6)
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
                    .fill(tag.colorValue.opacity(0.15))
            )
            .foregroundColor(tag.colorValue)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tag.colorValue.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}

struct IconOnlyTagChip: View {
    let tag: Tag
    let size: CGFloat
    let onTap: (() -> Void)?
    
    init(tag: Tag, size: CGFloat = 20, onTap: (() -> Void)? = nil) {
        self.tag = tag
        self.size = size
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            Group {
                if let emoji = tag.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: size * 0.7))
                } else {
                    Circle()
                        .fill(tag.colorValue)
                        .frame(width: size * 0.5, height: size * 0.5)
                }
            }
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(tag.colorValue.opacity(0.15))
            )
            .overlay(
                Circle()
                    .stroke(tag.colorValue.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}

#if DEBUG
struct TagChip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            // Standard Tag Chip
            TagChip(tag: sampleTag(), isSelected: false) { }
            
            // Selected Tag Chip
            TagChip(tag: sampleTag(), isSelected: true) { }
            
            // Compact Tag Chip
            CompactTagChip(tag: sampleTag())
            
            // Icon Only Tag Chip
            IconOnlyTagChip(tag: sampleTag())
            
            // Removable Tag Chip
            RemovableTagChip(tag: sampleTag()) { }
        }
        .padding()
    }
    
    static func sampleTag() -> Tag {
        // Preview Tag erstellen (nur für Preview)
        let tag = Tag()
        tag.name = "Strand"
        tag.emoji = "🏖️"
        tag.color = "blue"
        return tag
    }
}
#endif 