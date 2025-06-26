//
//  BucketListMapView.swift
//  Journiary
//
//  Created by AI Assistant on [Current Date]
//

import SwiftUI
import MapKit
import CoreData

struct BucketListMapView: View {
    let items: [BucketListItem]
    @State private var mapPosition = MapCameraPosition.automatic
    @State private var selectedItem: BucketListItem?
    @State private var showingItemDetail = false
    
    var body: some View {
        ZStack {
            mapView
            legendOverlay
        }
        .onAppear {
            updateMapRegion()
        }
        .onChange(of: items) { _, _ in
            updateMapRegion()
        }
        .sheet(isPresented: $showingItemDetail) {
            if let item = selectedItem {
                BucketListItemDetailView(item: item)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var validItems: [BucketListItem] {
        items.filter { item in
            item.latitude1 != 0.0 && item.longitude1 != 0.0
        }
    }
    
    private var mapView: some View {
        Map(position: $mapPosition) {
            ForEach(validItems, id: \.objectID) { item in
                Annotation(
                    item.name ?? "",
                    coordinate: CLLocationCoordinate2D(latitude: item.latitude1, longitude: item.longitude1)
                ) {
                    annotationView(for: item)
                }
            }
        }
    }
    
    private var legendOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                legendView
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func annotationView(for item: BucketListItem) -> some View {
        Button(action: {
            selectedItem = item
            showingItemDetail = true
        }) {
            VStack(spacing: 4) {
                // Moderner Pin mit Glasmorphism-Effekt
                ZStack {
                    // Pin-Form Hintergrund
                    ZStack {
                        // Hauptpin
                        RoundedRectangle(cornerRadius: 16)
                            .frame(width: 40, height: 40)
                        
                        // Pin-Spitze
                        Triangle()
                            .frame(width: 12, height: 8)
                            .offset(y: 24)
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
                    .shadow(color: colorForType(item.type ?? "").opacity(0.4), radius: 8, x: 0, y: 4)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    // Glasmorphism-Overlay
                    RoundedRectangle(cornerRadius: 16)
                        .frame(width: 40, height: 40)
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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
                
                // Moderner Label mit Glasmorphism
                Text(item.name ?? "")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        ZStack {
                            // Basis-Hintergrund
                            Capsule()
                                .fill(.ultraThinMaterial)
                            
                            // Glasmorphism-Highlight
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.6),
                                            .white.opacity(0.2)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
        .scaleEffect(selectedItem?.objectID == item.objectID ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedItem?.objectID == item.objectID)
    }
    
    private func updateMapRegion() {
        guard !validItems.isEmpty else { return }
        
        let coordinates = validItems.map { 
            CLLocationCoordinate2D(latitude: $0.latitude1, longitude: $0.longitude1) 
        }
        
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        let spanLat = max(abs(maxLat - minLat) * 1.3, 0.1)
        let spanLon = max(abs(maxLon - minLon) * 1.3, 0.1)
        
        withAnimation(.easeInOut(duration: 1.0)) {
            mapPosition = MapCameraPosition.region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
            ))
        }
    }
    
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
    
    // MARK: - Legend View
    
    private var legendView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Legende")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            
            ForEach(BucketListType.allCases, id: \.self) { type in
                if hasItemsOfType(type) {
                    HStack(spacing: 10) {
                        // Moderner Mini-Pin
                        ZStack {
                            // Pin-Form
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .frame(width: 20, height: 20)
                                
                                Triangle()
                                    .frame(width: 6, height: 4)
                                    .offset(y: 12)
                            }
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        colorForType(type.rawValue).opacity(0.9),
                                        colorForType(type.rawValue).opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: colorForType(type.rawValue).opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            // Glasmorphism-Overlay
                            RoundedRectangle(cornerRadius: 8)
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
                            Image(systemName: iconForType(type.rawValue))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.3), radius: 0.5, x: 0, y: 0.5)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            Text("(\(countForType(type)))")
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                // Basis-Hintergrund mit Blur
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                
                // Glasmorphism-Border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.2),
                                .clear,
                                .black.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 8)
        .frame(maxWidth: 220)
    }
    
    private func hasItemsOfType(_ type: BucketListType) -> Bool {
        validItems.contains { item in
            item.type == type.rawValue
        }
    }
    
    private func countForType(_ type: BucketListType) -> Int {
        validItems.filter { item in
            item.type == type.rawValue
        }.count
    }
}

// MARK: - Bucket List Item Detail View

struct BucketListItemDetailView: View {
    let item: BucketListItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        // Art Logo oben links
                        HStack {
                            HStack(spacing: 12) {
                                // Moderner Mini-Pin für Header
                                ZStack {
                                    // Pin-Form
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .frame(width: 32, height: 32)
                                        
                                        Triangle()
                                            .frame(width: 8, height: 5)
                                            .offset(y: 18.5)
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
                                    .shadow(color: colorForType(item.type ?? "").opacity(0.3), radius: 4, x: 0, y: 2)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                    
                                    // Glasmorphism-Overlay
                                    RoundedRectangle(cornerRadius: 10)
                                        .frame(width: 32, height: 32)
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
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayNameForType(item.type ?? ""))
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(colorForType(item.type ?? ""))
                                    
                                    Text("Bucket List Item")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if item.isDone {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        // Name und Location
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.name ?? "Unbekannt")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            // Flagge Land - Region
                            HStack(spacing: 4) {
                                if let country = item.country, !country.isEmpty {
                                    Text(CountryHelper.flag(for: country))
                                        .font(.subheadline)
                                    Text(country)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if let region = item.region, !region.isEmpty {
                                        Text("- \(region)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                } else if let region = item.region, !region.isEmpty {
                                    Text(region)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Karte
                    if item.latitude1 != 0.0 && item.longitude1 != 0.0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Standort", systemImage: "location.fill")
                                .font(.headline)
                            
                            // Karte
                            BucketListDetailMapView(
                                latitude: item.latitude1, 
                                longitude: item.longitude1, 
                                iconName: iconForType(item.type ?? ""),
                                iconColor: colorForType(item.type ?? "")
                            )
                            .frame(height: 260)
                            .cornerRadius(12)
                            
                            DetailRow(label: "Koordinaten", value: String(format: "%.6f, %.6f", locale: Locale(identifier: "en_US_POSIX"), item.latitude1, item.longitude1))
                        }
                    }
                    
                    if let createdAt = item.createdAt {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Erstellt", systemImage: "calendar")
                                .font(.headline)
                            
                            Text(createdAt, style: .date)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
    }
    
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

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct BucketListDetailMapView: View {
    let latitude: Double
    let longitude: Double
    let iconName: String
    let iconColor: Color
    
    @State private var mapPosition: MapCameraPosition
    
    init(latitude: Double, longitude: Double, iconName: String, iconColor: Color) {
        self.latitude = latitude
        self.longitude = longitude
        self.iconName = iconName
        self.iconColor = iconColor
        
        _mapPosition = State(initialValue: MapCameraPosition.region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        ))
    }
    
    var body: some View {
        Map(position: $mapPosition) {
            Annotation(
                "",
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            ) {
                // Moderner Pin für Detail-Ansicht (größer als in der Übersicht)
                ZStack {
                    // Pin-Form Hintergrund
                    ZStack {
                        // Hauptpin
                        RoundedRectangle(cornerRadius: 18)
                            .frame(width: 50, height: 50)
                        
                        // Pin-Spitze
                        Triangle()
                            .frame(width: 15, height: 10)
                            .offset(y: 30)
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                iconColor.opacity(0.9),
                                iconColor.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: iconColor.opacity(0.4), radius: 12, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                    
                    // Glasmorphism-Overlay
                    RoundedRectangle(cornerRadius: 18)
                        .frame(width: 50, height: 50)
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
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
        }
    }
}

// MARK: - Supporting Views

/// Triangle shape für den Pin-Footer
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

struct BucketListMapView_Previews: PreviewProvider {
    static var previews: some View {
        BucketListMapView(items: [])
    }
} 