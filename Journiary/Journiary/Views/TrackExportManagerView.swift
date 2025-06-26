//
//  TrackExportManagerView.swift
//  Journiary
//
//  Created by AI Assistant on 09.06.25.
//

import SwiftUI
import CoreData

struct TrackExportManagerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)],
        animation: .default
    )
    private var allTrips: FetchedResults<Trip>
    
    @State private var selectedTrips = Set<Trip>()
    @State private var isSelectionMode = false
    @State private var showingBulkExportView = false
    @State private var tripForDetailedExport: Trip?
    @State private var searchText = ""
    @State private var filterOption: FilterOption = .all
    @State private var sortOption: SortOption = .dateDescending
    
    enum FilterOption: String, CaseIterable {
        case all = "Alle"
        case withGPS = "Mit GPS-Daten"
        case active = "Aktive"
        case completed = "Beendet"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .withGPS: return "location.fill"
            case .active: return "play.circle.fill"
            case .completed: return "checkmark.circle.fill"
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case dateDescending = "Neueste zuerst"
        case dateAscending = "Älteste zuerst"
        case nameAscending = "Name A-Z"
        case nameDescending = "Name Z-A"
        case distanceDescending = "Längste Distanz"
        case distanceAscending = "Kürzeste Distanz"
    }
    
    private var filteredAndSortedTrips: [Trip] {
        let filtered = filteredTrips
        
        switch sortOption {
        case .dateDescending:
            return filtered.sorted { ($0.startDate ?? Date.distantPast) > ($1.startDate ?? Date.distantPast) }
        case .dateAscending:
            return filtered.sorted { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
        case .nameAscending:
            return filtered.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .nameDescending:
            return filtered.sorted { ($0.name ?? "") > ($1.name ?? "") }
        case .distanceDescending:
            return filtered.sorted { $0.totalDistance > $1.totalDistance }
        case .distanceAscending:
            return filtered.sorted { $0.totalDistance < $1.totalDistance }
        }
    }
    
    private var filteredTrips: [Trip] {
        let tripsArray = Array(allTrips)
        
        let searchFiltered: [Trip]
        if searchText.isEmpty {
            searchFiltered = tripsArray
        } else {
            searchFiltered = tripsArray.filter { trip in
                (trip.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (trip.tripDescription?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (trip.visitedCountries?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        switch filterOption {
        case .all:
            return searchFiltered
        case .withGPS:
            return searchFiltered.filter { trip in
                if let routePoints = trip.routePoints?.allObjects as? [RoutePoint] {
                    return !routePoints.isEmpty
                }
                return false
            }
        case .active:
            return searchFiltered.filter { $0.isActive }
        case .completed:
            return searchFiltered.filter { !$0.isActive }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter und Such-Leiste
                filterSectionView
                
                // Trips-Liste
                if filteredAndSortedTrips.isEmpty {
                    emptyStateView
                } else {
                    tripsList
                }
            }
            .navigationTitle("Track Export Manager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if !isSelectionMode {
                            Button("Auswählen", systemImage: "checkmark.circle") {
                                isSelectionMode = true
                            }
                        } else {
                            Button("Fertig", systemImage: "xmark") {
                                isSelectionMode = false
                                selectedTrips.removeAll()
                            }
                            
                            if !selectedTrips.isEmpty {
                                Button("Alle exportieren (\(selectedTrips.count))", systemImage: "square.and.arrow.up") {
                                    showingBulkExportView = true
                                }
                            }
                            
                            Button("Alle auswählen", systemImage: "checkmark.square") {
                                selectedTrips = Set(filteredAndSortedTrips.filter { trip in
                                    if let routePoints = trip.routePoints?.allObjects as? [RoutePoint] {
                                        return !routePoints.isEmpty
                                    }
                                    return false
                                })
                            }
                            
                            Button("Auswahl aufheben", systemImage: "square") {
                                selectedTrips.removeAll()
                            }
                        }
                    } label: {
                        Image(systemName: isSelectionMode ? "ellipsis.circle.fill" : "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingBulkExportView) {
                BulkGPXExportView(trips: Array(selectedTrips)) {
                    selectedTrips.removeAll()
                    isSelectionMode = false
                }
            }
            .sheet(item: $tripForDetailedExport) { trip in
                GPXExportView(trip: trip)
            }
        }
    }
    
    // MARK: - View Components
    
    private var filterSectionView: some View {
        VStack(spacing: 12) {
            // Suchleiste
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Reisen durchsuchen...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Filter-Optionen
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        FilterChip(
                            title: option.rawValue,
                            icon: option.icon,
                            isSelected: filterOption == option,
                            count: countForFilter(option)
                        ) {
                            filterOption = option
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Sortierung
            HStack {
                Text("Sortierung:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Sortierung", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
                
                Spacer()
                
                Text("\(filteredAndSortedTrips.count) Reise(n)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var tripsList: some View {
        List {
            ForEach(filteredAndSortedTrips, id: \.objectID) { trip in
                TripExportRow(
                    trip: trip,
                    isSelected: selectedTrips.contains(trip),
                    isSelectionMode: isSelectionMode,
                    onTap: {
                        if isSelectionMode {
                            if selectedTrips.contains(trip) {
                                selectedTrips.remove(trip)
                            } else {
                                selectedTrips.insert(trip)
                            }
                        } else {
                            tripForDetailedExport = trip
                        }
                    }
                )
            }
        }
        .listStyle(.plain)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "map.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Keine Reisen gefunden")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if searchText.isEmpty {
                Text("Erstellen Sie eine neue Reise, um GPS-Tracks zu sammeln.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Keine Reisen entsprechen Ihrer Suche '\(searchText)'")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Suche zurücksetzen") {
                    searchText = ""
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Functions
    
    private func countForFilter(_ filter: FilterOption) -> Int {
        let tripsArray = Array(allTrips)
        
        switch filter {
        case .all:
            return tripsArray.count
        case .withGPS:
            return tripsArray.filter { trip in
                if let routePoints = trip.routePoints?.allObjects as? [RoutePoint] {
                    return !routePoints.isEmpty
                }
                return false
            }.count
        case .active:
            return tripsArray.filter { $0.isActive }.count
        case .completed:
            return tripsArray.filter { !$0.isActive }.count
        }
    }
}

// MARK: - Supporting Views

struct TripExportRow: View {
    let trip: Trip
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    
    private var routePoints: [RoutePoint] {
        guard let points = trip.routePoints?.allObjects as? [RoutePoint] else { return [] }
        return points
    }
    
    private var hasGPSData: Bool {
        !routePoints.isEmpty
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Auswahl-Checkbox (nur im Auswahlmodus)
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .secondary)
                        .font(.title3)
                }
                
                // Trip-Icon oder Titelfoto
                if let coverImageData = trip.coverImageData,
                   let uiImage = UIImage(data: coverImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: hasGPSData ? "location.circle.fill" : "location.slash.circle")
                        .font(.title2)
                        .foregroundColor(hasGPSData ? .green : .orange)
                        .frame(width: 50, height: 50)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Trip-Informationen
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(trip.name ?? "Unbenannte Reise")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if trip.isActive {
                            Text("AKTIV")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    if let startDate = trip.startDate {
                        Text(startDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        if hasGPSData {
                            Label("\(routePoints.count) Punkte", systemImage: "location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Label("Keine GPS-Daten", systemImage: "location.slash")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        if trip.totalDistance > 0 {
                            Label(String(format: "%.1f km", trip.totalDistance / 1000), systemImage: "ruler")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Export-Status
                VStack(alignment: .trailing, spacing: 4) {
                    if hasGPSData {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    }
                    
                    if !isSelectionMode && hasGPSData {
                        Text("Exportierbar")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    } else if !hasGPSData {
                        Text("Keine Daten")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(!hasGPSData && !isSelectionMode)
        .opacity((!hasGPSData && !isSelectionMode) ? 0.6 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    return TrackExportManagerView()
        .environment(\.managedObjectContext, context)
} 