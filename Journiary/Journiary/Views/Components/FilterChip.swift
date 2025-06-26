//
//  FilterChip.swift
//  Journiary
//
//  Created by Assistant on 06.11.25.
//

import SwiftUI

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int?
    let action: () -> Void
    
    init(title: String, icon: String, isSelected: Bool, count: Int? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.count = count
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                if let count = count, count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
} 