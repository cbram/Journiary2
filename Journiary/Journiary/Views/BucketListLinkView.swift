//
//  BucketListLinkView.swift
//  Journiary
//
//  Created by AI Assistant on [Current Date]
//

import SwiftUI
import CoreData
import CoreLocation

struct BucketListLinkView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let memory: Memory
    @Binding var selectedBucketListItem: BucketListItem?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BucketListItem.name, ascending: true)],
        animation: .default
    )
    private var allBucketListItems: FetchedResults<BucketListItem>
    
    @State private var searchText = ""
    @State private var showingNearbyOnly = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Suchfeld und Filter
                VStack(spacing: 12) {
                    POISearchBar(text: $searchText, placeholder: "POI suchen...")
                    
                    HStack {
                        Toggle("Nur in der Nähe", isOn: $showingNearbyOnly)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(filteredItems.count) POIs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // POI Liste
                List {
                    if filteredItems.isEmpty {
                        ContentUnavailableView(
                            "Keine POIs gefunden",
                            systemImage: "magnifyingglass",
                            description: Text("Versuche eine andere Suche oder erstelle ein neues Bucket List Item.")
                        )
                    } else {
                        ForEach(filteredItems, id: \.objectID) { item in
                            BucketListLinkRowView(
                                item: item,
                                memory: memory,
                                isSelected: selectedBucketListItem?.objectID == item.objectID,
                                onSelect: {
                                    selectedBucketListItem = item
                                    dismiss()
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("POI verknüpfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ohne Verknüpfung") {
                        selectedBucketListItem = nil
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredItems: [BucketListItem] {
        var items = Array(allBucketListItems)
        
        // Suchtext Filter
        if !searchText.isEmpty {
            items = items.filter { item in
                let name = item.name?.lowercased() ?? ""
                let country = item.country?.lowercased() ?? ""
                let region = item.region?.lowercased() ?? ""
                let searchLower = searchText.lowercased()
                
                return name.contains(searchLower) || 
                       country.contains(searchLower) || 
                       region.contains(searchLower)
            }
        }
        
        // Nähe Filter
        if showingNearbyOnly, memory.latitude != 0.0, memory.longitude != 0.0 {
            let memoryLocation = CLLocation(latitude: memory.latitude, longitude: memory.longitude)
            items = items.filter { item in
                if item.latitude1 == 0.0 && item.longitude1 == 0.0 {
                    return false
                }
                let itemLocation = CLLocation(latitude: item.latitude1, longitude: item.longitude1)
                let distance = memoryLocation.distance(from: itemLocation) / 1000.0 // km
                return distance <= 50.0 // 50km Radius
            }
        }
        
        // Nach Entfernung sortieren, wenn Memory-Standort verfügbar
        if memory.latitude != 0.0, memory.longitude != 0.0 {
            let memoryLocation = CLLocation(latitude: memory.latitude, longitude: memory.longitude)
            items = items.sorted { item1, item2 in
                let location1 = CLLocation(latitude: item1.latitude1, longitude: item1.longitude1)
                let location2 = CLLocation(latitude: item2.latitude1, longitude: item2.longitude1)
                let distance1 = memoryLocation.distance(from: location1)
                let distance2 = memoryLocation.distance(from: location2)
                return distance1 < distance2
            }
        }
        
        return items
    }
}

struct BucketListLinkRowView: View {
    let item: BucketListItem
    let memory: Memory
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Moderner Mini-Pin
            ZStack {
                // Pin-Form
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .frame(width: 30, height: 30)
                    
                    Triangle()
                        .frame(width: 7, height: 4)
                        .offset(y: 17)
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
                .shadow(color: colorForType(item.type ?? "").opacity(0.3), radius: 3, x: 0, y: 1.5)
                .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 0.75)
                
                // Glasmorphism-Overlay
                RoundedRectangle(cornerRadius: 8)
                    .frame(width: 30, height: 30)
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "Unbekannt")
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Land
                    if let country = item.country, !country.isEmpty {
                        Text(country)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Region
                    if let region = item.region, !region.isEmpty {
                        Text("• \(region)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Entfernung
                if let distance = distanceText {
                    Text(distance)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Auswahl Indikator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    private var distanceText: String? {
        guard memory.latitude != 0.0, memory.longitude != 0.0,
              item.latitude1 != 0.0, item.longitude1 != 0.0 else {
            return nil
        }
        
        let memoryLocation = CLLocation(latitude: memory.latitude, longitude: memory.longitude)
        let itemLocation = CLLocation(latitude: item.latitude1, longitude: item.longitude1)
        let distance = memoryLocation.distance(from: itemLocation) / 1000.0 // km
        
        if distance < 1.0 {
            return String(format: "%.0f m", distance * 1000)
        } else {
            return String(format: "%.1f km", distance)
        }
    }
    
    // MARK: - Helper Methods (gleich wie in BucketListRowView)
    
    private func iconForType(_ typeString: String) -> String {
        guard let type = BucketListType(rawValue: typeString) else {
            return "star.fill"
        }
        
        switch type {
        case .nationalpark: return "tree.fill"
        case .stadt: return "building.2.fill"
        case .spot: return "camera.fill"
        case .bauwerk: return "building.columns.fill"
        case .wanderung: return "figure.walk"
        case .radtour: return "bicycle"
        case .traumstrasse: return "road.lanes"
        case .sonstiges: return "star.fill"
        }
    }
    
    private func colorForType(_ typeString: String) -> Color {
        guard let type = BucketListType(rawValue: typeString) else {
            return .gray
        }
        
        switch type {
        case .nationalpark: return .green
        case .stadt: return .blue
        case .spot: return .orange
        case .bauwerk: return .brown
        case .wanderung: return .mint
        case .radtour: return .cyan
        case .traumstrasse: return .purple
        case .sonstiges: return .gray
        }
    }
}

struct POISearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let memory = Memory(context: context)
    memory.title = "Test Memory"
    memory.latitude = 52.5163
    memory.longitude = 13.3777
    
    return BucketListLinkView(
        memory: memory,
        selectedBucketListItem: .constant(nil)
    )
    .environment(\.managedObjectContext, context)
} 