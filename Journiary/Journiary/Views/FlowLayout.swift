//
//  FlowLayout.swift
//  Journiary
//
//  Created by Assistant on 06.11.25.
//

import SwiftUI

// Einfache Grid-basierte Implementierung für Tags
struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    
    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 300), spacing: spacing)], spacing: spacing) {
            content()
        }
    }
}

// Alternative, einfachere Implementierung für Tags
struct TagFlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(subviews: subviews, in: proposal.width ?? 0)
        let height = rows.reduce(0) { result, row in
            result + row.maxHeight + spacing
        } - spacing
        
        return CGSize(width: proposal.width ?? 0, height: max(0, height))
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(subviews: subviews, in: bounds.width)
        var y = bounds.minY
        
        for row in rows {
            var x = bounds.minX
            
            for subview in row.subviews {
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: subview.sizeThatFits(.unspecified).width, height: row.maxHeight))
                x += subview.sizeThatFits(.unspecified).width + spacing
            }
            
            y += row.maxHeight + spacing
        }
    }
    
    private func computeRows(subviews: Subviews, in width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var currentWidth: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if currentWidth + subviewSize.width + spacing > width && !currentRow.subviews.isEmpty {
                rows.append(currentRow)
                currentRow = Row()
                currentRow.subviews.append(subview)
                currentRow.maxHeight = subviewSize.height
                currentWidth = subviewSize.width
            } else {
                currentRow.subviews.append(subview)
                currentRow.maxHeight = max(currentRow.maxHeight, subviewSize.height)
                currentWidth += subviewSize.width + (currentRow.subviews.count > 1 ? spacing : 0)
            }
        }
        
        if !currentRow.subviews.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    private struct Row {
        var subviews: [LayoutSubview] = []
        var maxHeight: CGFloat = 0
    }
}

// Einfache Fallback-Implementierung für ältere iOS-Versionen
struct SimpleFlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    
    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            TagFlowLayout(spacing: spacing) {
                content()
            }
        } else {
            // Fallback für ältere iOS-Versionen
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 300), spacing: spacing)], spacing: spacing) {
                content()
            }
        }
    }
} 