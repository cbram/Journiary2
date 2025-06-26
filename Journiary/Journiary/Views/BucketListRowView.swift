//
//  BucketListRowView.swift
//  Journiary
//
//  Created by AI Assistant on [Current Date]
//

import SwiftUI

struct BucketListRowView: View {
    let item: BucketListItem
    let onToggleComplete: () -> Void
    let onTap: () -> Void
    let showDistance: Bool
    let formattedDistance: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Art Logo oben links
            HStack {
                HStack(spacing: 8) {
                    // Moderner Mini-Pin für Row
                    ZStack {
                        // Pin-Form
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .frame(width: 20, height: 20)
                            
                            Triangle()
                                .frame(width: 5, height: 3)
                                .offset(y: 11.5)
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    colorForType(item.type ?? "").opacity(0.9),
                                    colorForType(item.type ?? "").opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: colorForType(item.type ?? "").opacity(0.3), radius: 2, x: 0, y: 1)
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0.5)
                        
                        // Glasmorphism-Overlay
                        RoundedRectangle(cornerRadius: 6)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.3),
                                        .white.opacity(0.1),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Icon
                        Image(systemName: iconForType(item.type ?? ""))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 0.5, x: 0, y: 0.25)
                    }
                    
                    Text(displayNameForType(item.type ?? ""))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(colorForType(item.type ?? ""))
                }
                
                Spacer()
            }
            
            // Hauptinformationen
            VStack(alignment: .leading, spacing: 6) {
                // Titel
                Text(item.name ?? "(Kein Name)")
                    .font(.headline)
                    .foregroundColor(item.isDone ? .green : .primary)
                    .lineLimit(2)
                
                // Flagge Land - Region
                HStack(spacing: 4) {
                    if let country = item.country, !country.isEmpty {
                        Text(CountryHelper.flag(for: country))
                            .font(.caption)
                        Text(country)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let region = item.region, !region.isEmpty {
                            Text("- \(region)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let region = item.region, !region.isEmpty {
                        Text(region)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Entfernung und Erinnerungen
                HStack(spacing: 8) {
                    if showDistance, let distance = formattedDistance {
                        HStack(spacing: 2) {
                            Image(systemName: "location")
                                .font(.caption2)
                            Text(distance)
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                    
                    if item.hasMemories {
                        HStack(spacing: 2) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                            Text("\(item.memoryCount) Erinnerung\(item.memoryCount == 1 ? "" : "en")")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    // MARK: - Helper Methods
    
    private func iconForType(_ typeString: String) -> String {
        guard let type = BucketListType(rawValue: typeString) else {
            return "star.fill"
        }
        
        switch type {
        case .nationalpark:
            return "tree.fill"
        case .stadt:
            return "building.2.fill"
        case .spot:
            return "camera.fill"
        case .bauwerk:
            return "building.columns.fill"
        case .wanderung:
            return "figure.walk"
        case .radtour:
            return "bicycle"
        case .traumstrasse:
            return "road.lanes"
        case .sonstiges:
            return "star.fill"
        }
    }
    
    private func colorForType(_ typeString: String) -> Color {
        guard let type = BucketListType(rawValue: typeString) else {
            return .gray
        }
        
        switch type {
        case .nationalpark:
            return .green
        case .stadt:
            return .blue
        case .spot:
            return .orange
        case .bauwerk:
            return .brown
        case .wanderung:
            return .mint
        case .radtour:
            return .cyan
        case .traumstrasse:
            return .purple
        case .sonstiges:
            return .gray
        }
    }
    
    private func displayNameForType(_ typeString: String) -> String {
        guard let type = BucketListType(rawValue: typeString) else {
            return "Sonstiges"
        }
        switch type {
        case .nationalpark: return "Nationalpark"
        case .stadt: return "Stadt"
        case .spot: return "Spot"
        case .bauwerk: return "Bauwerk"
        case .wanderung: return "Wanderung"
        case .radtour: return "Radtour"
        case .traumstrasse: return "Traumstraße"
        case .sonstiges: return "Sonstiges"
        }
    }
}

struct FilterStatusChip: View {
    let title: String
    let icon: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.15))
        )
        .foregroundColor(.blue)
    }
}

#Preview {
    // Create a sample BucketListItem for preview
    let context = PersistenceController.preview.container.viewContext
    let sampleItem = BucketListItem(context: context)
    sampleItem.name = "Neuschwanstein"
    sampleItem.country = "Deutschland"
    sampleItem.region = "Bayern"
    sampleItem.type = "sehenswuerdigkeit"
    sampleItem.isDone = false
    
    return VStack {
        BucketListRowView(
            item: sampleItem,
            onToggleComplete: {},
            onTap: {},
            showDistance: true,
            formattedDistance: "25.3 km"
        )
        .padding()
        
        Divider()
        
        FilterStatusChip(
            title: "Deutschland",
            icon: "globe",
            onRemove: {}
        )
        .padding()
    }
} 