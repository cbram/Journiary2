//
//  InteractiveRoutePointView.swift
//  Journiary
//
//  Created by AI Assistant on 09.06.25.
//

import SwiftUI

struct InteractiveRoutePointView: View {
    let point: RoutePoint
    let isSelected: Bool
    let isSelectedForInsertion: Bool
    let isTrackEditMode: Bool
    let isSelectingForInsertion: Bool
    let onTap: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isPressed: Bool = false
    @State private var isDragging: Bool = false
    
    var body: some View {
        Circle()
            .fill(pointColor)
            .frame(width: pointSize, height: pointSize)
            .overlay(
                Circle()
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .overlay(
                // Auswahl-Indikator
                Group {
                    if isSelected && isTrackEditMode {
                        Image(systemName: "move.3d")
                            .font(.caption2)
                            .foregroundColor(.white)
                    } else if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 4, height: 4)
                    }
                }
            )
            .scaleEffect(isPressed ? 1.2 : (isSelected ? 1.1 : 1.0))
            .offset(dragOffset)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            // Größerer Tap-Bereich (unsichtbar)
            .background(
                Circle()
                    .fill(Color.clear)
                    .frame(width: max(pointSize + 20, 44), height: max(pointSize + 20, 44))
                    .contentShape(Circle())
            )
            .allowsHitTesting(true)
            .gesture(
                // Kombinierte Tap- und Drag-Gesture
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                        
                        // Drag-Verhalten nur im Track-Edit-Modus und wenn Punkt bereits ausgewählt
                        if isTrackEditMode && isSelected && dragDistance > 3 {
                            dragOffset = value.translation
                            isPressed = true
                            
                            if !isDragging {
                                isDragging = true
                                onDragChanged(value)
                                
                                // Haptic feedback beim Start des Dragging
                                let haptic = UIImpactFeedbackGenerator(style: .medium)
                                haptic.impactOccurred()
                            } else {
                                onDragChanged(value)
                            }
                        }
                    }
                    .onEnded { value in
                        let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                        
                        if isDragging && dragDistance > 3 {
                            // Es war ein Drag - verarbeite als Drag
                            onDragEnded(value)
                        } else if dragDistance <= 3 {
                            // Es war ein Tap - verarbeite als Tap
                            onTap()
                            
                            // Haptic feedback für Tap
                            let haptic = UIImpactFeedbackGenerator(style: .light)
                            haptic.impactOccurred()
                        }
                        
                        // Reset mit Animation
                        withAnimation(.easeInOut(duration: 0.2)) {
                            dragOffset = .zero
                            isPressed = false
                        }
                        
                        // Reset nach Animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isDragging = false
                        }
                    }
            )
    }
    
    private var pointColor: Color {
        if isTrackEditMode {
            if isSelectingForInsertion && isSelectedForInsertion {
                return Color.orange
            } else if isSelected {
                return Color.blue
            } else {
                return Color.red.opacity(0.8)
            }
        } else {
            return Color.red
        }
    }
    
    private var pointSize: CGFloat {
        if isTrackEditMode {
            if isSelectedForInsertion {
                return 18
            } else if isSelected {
                return 20
            } else {
                return 14
            }
        } else {
            return 8
        }
    }
    
    private var strokeColor: Color {
        isSelected ? Color.white : Color.white.opacity(0.8)
    }
    
    private var strokeWidth: CGFloat {
        isSelected ? 3 : 2
    }
} 