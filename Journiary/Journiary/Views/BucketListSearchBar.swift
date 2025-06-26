//
//  BucketListSearchBar.swift
//  Journiary
//
//  Created by AI Assistant
//

import SwiftUI

struct BucketListSearchBar: View {
    @ObservedObject var filterManager: BucketListFilterManager
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Suchicon
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .medium))
            
            // Suchfeld
            TextField("Bucket List durchsuchen...", text: $filterManager.searchText)
                .focused($isSearchFieldFocused)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .submitLabel(.search)
                .onSubmit {
                    isSearchFieldFocused = false
                }
                .onKeyPress(.escape) {
                    dismissKeyboard()
                    return .handled
                }
            
            // Clear Button
            if !filterManager.searchText.isEmpty {
                Button(action: {
                    filterManager.clearSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16, weight: .medium))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSearchFieldFocused ? Color.blue : Color.clear, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isSearchFieldFocused)
        .animation(.easeInOut(duration: 0.2), value: filterManager.searchText.isEmpty)
    }
    
    // MARK: - Helper Methods
    
    private func dismissKeyboard() {
        isSearchFieldFocused = false
    }
}

#Preview {
    VStack {
        BucketListSearchBar(
            filterManager: BucketListFilterManager(
                context: PersistenceController.preview.container.viewContext
            )
        )
        .padding()
        
        Spacer()
    }
} 