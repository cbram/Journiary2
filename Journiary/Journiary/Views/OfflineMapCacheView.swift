//
//  OfflineMapCacheView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import MapKit
import CoreData

struct OfflineMapCacheView: View {
    @StateObject private var mapCache = MapCacheManager.shared
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingRegionPicker = false
    @State private var showingTripPicker = false
    @State private var showingDeleteAlert = false
    @State private var regionToDelete: CachedRegion?
    @State private var selectedTrip: Trip?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)],
        animation: .default
    )
    private var allTrips: FetchedResults<Trip>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)],
        animation: .default
    )
    private var allMemories: FetchedResults<Memory>

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Auto-Download Einstellungen
                    autoDownloadSettingsSection
                    
                    // Cache-Übersicht
                    cacheOverviewSection
                    
                    // Download-Optionen
                    downloadOptionsSection
                    
                    // Vorgeschlagene Regionen
                    if !suggestedRegions.isEmpty {
                        suggestedRegionsSection
                    }
                    
                    // Gecachte Regionen
                    if !mapCache.cachedRegions.isEmpty {
                        cachedRegionsSection
                    }
                    
                    // Cache-Verwaltung
                    cacheManagementSection
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Offline-Karten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingRegionPicker) {
                RegionPickerView { region, name in
                    Task {
                        await mapCache.downloadMapsForRegion(region: region, name: name)
                    }
                }
            }
            .sheet(isPresented: $showingTripPicker) {
                TripPickerView(trips: Array(allTrips)) { trip in
                    selectedTrip = trip
                    Task {
                        await mapCache.downloadMapsForTrip(trip)
                    }
                }
            }
            .alert("Region löschen", isPresented: $showingDeleteAlert) {
                Button("Löschen", role: .destructive) {
                    if let region = regionToDelete {
                        mapCache.deleteCachedRegion(region)
                    }
                }
                Button("Abbrechen", role: .cancel) {
                    regionToDelete = nil
                }
            } message: {
                Text("Möchten Sie diese gecachte Region wirklich löschen? Alle offline verfügbaren Karten dieser Region werden entfernt.")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var suggestedRegions: [CachedRegion] {
        mapCache.getSuggestedRegions(from: Array(allMemories))
    }
    
    // MARK: - Sections
    
    private var autoDownloadSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gear.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Auto-Download")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // Auto-Download Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatisches Caching")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Lädt Karten automatisch im Hintergrund herunter, während du sie betrachtest")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $mapCache.autoDownloadEnabled)
                        .onChange(of: mapCache.autoDownloadEnabled) { _, newValue in
                            mapCache.saveSettings()
                            if !newValue {
                                mapCache.pauseAutoDownload()
                            }
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Aktuell betrachtete Region
                if let currentRegion = mapCache.currentlyViewedRegion {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aktuelle Region")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Lat: \(String(format: "%.3f", currentRegion.center.latitude)), Lon: \(String(format: "%.3f", currentRegion.center.longitude))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if mapCache.isDownloadingMaps {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Performance-Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        mapCache.resetAutoDownload()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reset")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        mapCache.pauseAutoDownload()
                    }) {
                        HStack {
                            Image(systemName: "pause")
                            Text("Pause")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var cacheOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Cache-Übersicht")
                    .font(.headline)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                CacheStatCard(
                    title: "Regionen",
                    value: "\(mapCache.cachedRegions.count)",
                    icon: "map.fill",
                    color: .green
                )
                
                CacheStatCard(
                    title: "Speicher",
                    value: mapCache.formatFileSize(mapCache.totalCacheSize),
                    icon: "externaldrive.fill",
                    color: .blue
                )
                
                CacheStatCard(
                    title: "Auto-Cache",
                    value: "\(mapCache.cachedRegions.filter { $0.isAutoDownloaded }.count)",
                    icon: "arrow.down.circle.fill",
                    color: .orange
                )
            }
            
            // Download-Progress
            if mapCache.isDownloadingMaps {
                VStack(spacing: 8) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Karten werden heruntergeladen...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    ProgressView(value: mapCache.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    HStack {
                        Text("\(Int(mapCache.downloadProgress * 100))% abgeschlossen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Stoppen") {
                            mapCache.pauseAutoDownload()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var downloadOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Neue Region hinzufügen")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    showingRegionPicker = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading) {
                            Text("Eigene Region auswählen")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Wähle einen Bereich auf der Karte aus")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showingTripPicker = true
                }) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Region für Reise")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Basierend auf GPS-Tracks einer Reise")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                
                // Download für aktive Reisen
                Button(action: {
                    Task {
                        await mapCache.downloadMapsForActiveTrips(context: viewContext)
                    }
                }) {
                    HStack {
                        Image(systemName: "location.north.circle.fill")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading) {
                            Text("Aktive Reisen")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Karten für alle laufenden GPS-Trackings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var suggestedRegionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.circle.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                
                Text("Vorschläge")
                    .font(.headline)
                
                Spacer()
            }
            
            Text("Basierend auf deinen gespeicherten Erinnerungen")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(suggestedRegions.prefix(3), id: \.id) { suggestion in
                SuggestedRegionRow(suggestion: suggestion) {
                    Task {
                        await mapCache.downloadMapsForRegion(
                            region: suggestion.region,
                            name: suggestion.name.replacingOccurrences(of: "Vorschlag: ", with: "")
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var cachedRegionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Offline verfügbar")
                    .font(.headline)
                
                Spacer()
                
                Text("\(mapCache.cachedRegions.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            // Gruppiere nach Auto-Download und manuell
            let autoDownloaded = mapCache.cachedRegions.filter { $0.isAutoDownloaded }
            let manualDownloads = mapCache.cachedRegions.filter { !$0.isAutoDownloaded }
            
            if !manualDownloads.isEmpty {
                Text("Manuell heruntergeladen")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                ForEach(manualDownloads, id: \.id) { region in
                    CachedRegionRow(region: region) {
                        regionToDelete = region
                        showingDeleteAlert = true
                    }
                }
            }
            
            if !autoDownloaded.isEmpty {
                Text("Automatisch heruntergeladen")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                    .padding(.top, manualDownloads.isEmpty ? 0 : 8)
                
                ForEach(autoDownloaded, id: \.id) { region in
                    CachedRegionRow(region: region) {
                        regionToDelete = region
                        showingDeleteAlert = true
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var cacheManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gear.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                Text("Cache-Verwaltung")
                    .font(.headline)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Auto-Downloads löschen
                Button(action: {
                    let autoDownloads = mapCache.cachedRegions.filter { $0.isAutoDownloaded }
                    for region in autoDownloads {
                        mapCache.deleteCachedRegion(region)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading) {
                            Text("Auto-Downloads löschen")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Automatisch heruntergeladene Karten entfernen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(mapCache.cachedRegions.filter { $0.isAutoDownloaded }.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    mapCache.cleanupCacheIfNeeded()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading) {
                            Text("Cache optimieren")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Alte und nicht mehr benötigte Karten löschen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    mapCache.clearAllCache()
                }) {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading) {
                            Text("Alle Karten löschen")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Kompletten Offline-Cache leeren")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Helper Views

struct CacheStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CachedRegionRow: View {
    let region: CachedRegion
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(region.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if region.isAutoDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Text("\(region.tileCount) Kacheln • \(MapCacheManager.shared.formatFileSize(region.sizeInBytes))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Heruntergeladen: \(region.downloadDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SuggestedRegionRow: View {
    let suggestion: CachedRegion
    let onDownload: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Lat: \(String(format: "%.2f", suggestion.centerLatitude)), Lon: \(String(format: "%.2f", suggestion.centerLongitude))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Geschätzte Größe: ~\(MapCacheManager.shared.formatFileSize(Int64(suggestion.zoomLevels.count * 100 * 1024)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDownload) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Download")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Region Picker

struct RegionPickerView: View {
    let onRegionSelected: (MKCoordinateRegion, String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050), // Berlin
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))
    
    @State private var regionName = ""
    @State private var showingNameAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                Map(position: $mapPosition)
                    .overlay(
                        Rectangle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 200, height: 200)
                    )
                    .onMapCameraChange(frequency: .onEnd) { mapCameraUpdateContext in
                        region = mapCameraUpdateContext.region
                    }
                
                VStack(spacing: 12) {
                    Text("Wählen Sie die Region aus, die Sie offline verfügbar machen möchten")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("Region: \(String(format: "%.4f", region.center.latitude)), \(String(format: "%.4f", region.center.longitude))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Region herunterladen") {
                        showingNameAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
            }
            .navigationTitle("Region auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .alert("Name der Region", isPresented: $showingNameAlert) {
                TextField("Name eingeben", text: $regionName)
                Button("Herunterladen") {
                    if !regionName.isEmpty {
                        onRegionSelected(region, regionName)
                        dismiss()
                    }
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Geben Sie einen Namen für diese Region ein:")
            }
        }
    }
}

// MARK: - Trip Picker

struct TripPickerView: View {
    let trips: [Trip]
    let onTripSelected: (Trip) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(trips, id: \.objectID) { trip in
                    Button(action: {
                        onTripSelected(trip)
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.name ?? "Unbenannte Reise")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if let startDate = trip.startDate {
                                Text(startDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let routePoints = trip.routePoints?.allObjects as? [RoutePoint] {
                                Text("\(routePoints.count) Routenpunkte")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Reise auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    OfflineMapCacheView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 