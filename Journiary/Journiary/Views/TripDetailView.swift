//
//  TripDetailView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import CoreData
import MapKit

struct TripDetailView: View {
    let trip: Trip
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingShareSheet = false
    @State private var showingDeleteAlert = false
    @State private var tripToEdit: Trip?
    @State private var showingEndTripAlert = false
    @State private var gpxFileURL: URL?
    @State private var showingExportAlert = false
    @State private var exportMessage = ""
    @State private var showingGPXExportView = false
    
    // Neue State-Variablen für die Kartenansicht
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showingFullscreenMap = false
    @State private var showMapEditView = false
    @State private var showingMemoriesSheet = false
    @State private var randomMemories: [Memory] = []
    @State private var selectedMemoryForFocus: Memory?
    
    @State private var showingStopTrackingAlert = false
    @State private var pendingEndTrip = false
    
    private var routePoints: [RoutePoint] {
        guard let points = trip.routePoints?.allObjects as? [RoutePoint] else { 
            return [] 
        }
        return points.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
    }
    
    private var memories: [Memory] {
        guard let memories = trip.memories?.allObjects as? [Memory] else { 
            return [] 
        }
        return memories.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
    }
    
    // MARK: - Aktivitäts-Statistiken Properties
    
    private var hasGPXActivities: Bool {
        return memoriesWithGPXTracks.count > 0
    }
    
    private var memoriesWithGPXTracks: [Memory] {
        return memories.filter { $0.gpxTrack != nil }
    }
    
    private var activityStatistics: [ActivityStatistic] {
        var stats: [String: ActivityStatistic] = [:]
        
        for memory in memoriesWithGPXTracks {
            guard let gpxTrack = memory.gpxTrack else { continue }
            let activityType = gpxTrack.trackType ?? "sonstiges"
            
            if var existingStat = stats[activityType] {
                existingStat.count += 1
                existingStat.totalDistance += gpxTrack.totalDistance
                existingStat.totalElevationGain += gpxTrack.elevationGain
                existingStat.totalElevationLoss += gpxTrack.elevationLoss
                existingStat.totalDuration += gpxTrack.totalDuration
                stats[activityType] = existingStat
            } else {
                stats[activityType] = ActivityStatistic(
                    activityType: activityType,
                    count: 1,
                    totalDistance: gpxTrack.totalDistance,
                    totalElevationGain: gpxTrack.elevationGain,
                    totalElevationLoss: gpxTrack.elevationLoss,
                    totalDuration: gpxTrack.totalDuration
                )
            }
        }
        
        return Array(stats.values).sorted { $0.totalDistance > $1.totalDistance }
    }
    
    var body: some View {
        let main = Group {
            if trip.isFault || trip.managedObjectContext == nil {
                unavailableTripView
            } else {
                tripContentView
            }
        }
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .onAppear(perform: onAppearAction)
        
        return main
            .sheet(item: $tripToEdit) { trip in
                CreateTripView(existingTrip: trip)
                    .environmentObject(locationManager)
            }
            .sheet(isPresented: $showingGPXExportView) {
                GPXExportView(trip: trip)
            }
            .alert("Reise beenden", isPresented: $showingEndTripAlert) {
                Button("Beenden", role: .destructive) {
                    pendingEndTrip = true
                    endTrip()
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Möchtest du diese Reise wirklich beenden? Das GPS-Tracking wird gestoppt.")
            }
            .alert("GPS-Tracking beenden?", isPresented: $showingStopTrackingAlert) {
                Button("Ja", role: .destructive) {
                    stopTrackingForTrip()
                }
                Button("Nein", role: .cancel) {
                    pendingEndTrip = false
                }
            } message: {
                Text("Möchtest du das GPS-Tracking für diese Reise jetzt stoppen? (Empfohlen)")
            }
            .alert("Reise löschen", isPresented: $showingDeleteAlert) {
                Button("Löschen", role: .destructive) {
                    deleteTrip()
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Möchtest du diese Reise wirklich löschen? Alle zugehörigen Routenpunkte und Erinnerungen werden ebenfalls gelöscht.")
            }
            .alert(isPresented: $showingExportAlert) {
                Alert(
                    title: Text("Export Status"),
                    message: Text(exportMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheetWrapper(fileURL: $gpxFileURL, onDismiss: cleanupTemporaryShareFile)
            }
            .sheet(isPresented: $showingFullscreenMap) {
                TripTrackMapView(trip: trip, routePoints: routePoints)
            }
            .sheet(item: $selectedMemoryForFocus) { memory in
                NavigationView {
                    MemoriesView(trip: trip, focusedMemory: memory)
                }
            }
            .sheet(isPresented: $showMapEditView) {
                MapView(tripToEdit: trip)
            }
            .sheet(isPresented: $showingMemoriesSheet) {
                NavigationView {
                    MemoriesView(trip: trip, oldestFirst: true)
                }
            }
    }
    
    private var unavailableTripView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("Reise nicht verfügbar")
                .font(.headline)
            Text("Diese Reise konnte nicht geladen werden. Möglicherweise wurde sie von einem anderen Gerät gelöscht oder geändert.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Schließen") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                if trip.isActive {
                    Button("Reise beenden", systemImage: "stop.circle") {
                        showingEndTripAlert = true
                    }
                }
                Button("Reise bearbeiten", systemImage: "pencil") {
                    tripToEdit = trip
                }
                Button("GPX exportieren", systemImage: "square.and.arrow.up") {
                    showingGPXExportView = true
                }
                .disabled(routePoints.isEmpty)
                Button("Track bearbeiten", systemImage: "wrench.and.screwdriver") {
                    showMapEditView = true
                }
                Button("Reise löschen", systemImage: "trash", role: .destructive) {
                    showingDeleteAlert = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    private func onAppearAction() {
        if !trip.isActive && !routePoints.isEmpty {
            setupMapRegion()
        }
        let allMems = memories
        if allMems.count > 4 {
            randomMemories = Array(allMems.shuffled().prefix(4))
        } else {
            randomMemories = allMems.shuffled()
        }
    }
    
    private var tripContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header mit Trip-Info
                tripHeaderSection
                
                // Route-Informationen
                if !routePoints.isEmpty {
                    routeInfoSection
                }
                
                // Erinnerungen
                if !memories.isEmpty {
                    memoriesSection
                }
                
                // Statistiken
                statisticsSection
                
                // Aktivitäts-Statistiken (neue Sektion)
                if hasGPXActivities {
                    activityStatisticsSection
                }
                
                // Export-Optionen
                exportSection
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal)
        }
        .padding(.horizontal)
    }
    
    private var tripHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Titelfoto (größer und prominenter angezeigt)
            if let coverImageData = trip.coverImageData,
               let uiImage = UIImage(data: coverImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        ZStack(alignment: .topTrailing) {
                            // Farbverlauf für bessere Lesbarkeit des unteren Titels
                            VStack {
                                Spacer()
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.black.opacity(0.6), .clear]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                                .frame(height: 100)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                            // Inhalte (Titel und Aktiv-Badge)
                            VStack {
                                // Aktiv-Badge oben rechts
                                if trip.isActive {
                                    HStack {
                                        Spacer()
                                        Text("Aktiv")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(Color.green)
                                            .cornerRadius(12)
                                            .shadow(radius: 2)
                                            .padding([.top, .trailing])
                                    }
                                }
                                
                                Spacer()
                                
                                // Titel unten links
                                HStack {
                                    Text(trip.name ?? "Unbenannte Reise")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                    Spacer()
                                }
                                .padding([.leading, .bottom])
                            }
                        }
                    )
            }
            
            // Reise-Informationen unterhalb des Fotos (kompakt dargestellt)
            VStack(alignment: .leading, spacing: 12) {
                // Beschreibung
                if let description = trip.tripDescription, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                // Datum und Dauer
                if let startDate = trip.startDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start: \(formatGermanDate(startDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let endDate = trip.endDate {
                            Text("Ende: \(formatGermanDate(endDate))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            let duration = endDate.timeIntervalSince(startDate)
                            Text("Dauer: \(formatDuration(duration))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Reisebegleiter und besuchte Länder in einer Zeile (falls vorhanden)
                HStack(alignment: .top, spacing: 20) {
                    // Reisebegleiter
                    if let companions = trip.travelCompanions, !companions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Reisebegleiter", systemImage: "person.2.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(companions)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Besuchte Länder
                    if let countries = trip.visitedCountries, !countries.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Besuchte Länder", systemImage: "globe")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            let countryList = countries.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                            if countryList.count <= 3 {
                                ForEach(countryList, id: \.self) { country in
                                    Text("\(CountryHelper.flag(for: country)) \(country)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                let firstTwo = countryList.prefix(2)
                                ForEach(Array(firstTwo), id: \.self) { country in
                                    Text("\(CountryHelper.flag(for: country)) \(country)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text("+\(countryList.count - 2) weitere")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.top, trip.coverImageData != nil ? 8 : 0)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistiken")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Distanz",
                    value: String(format: "%.1f km", (trip.isActive ? locationManager.totalDistance : trip.totalDistance) / 1000),
                    icon: "ruler"
                )
                
                StatCard(
                    title: "Routenpunkte",
                    value: "\(routePoints.count)",
                    icon: "location"
                )
                
                StatCard(
                    title: "Erinnerungen",
                    value: "\(memories.count)",
                    icon: "photo"
                )
                
                StatCard(
                    title: "GPS-Tracking",
                    value: trip.gpsTrackingEnabled ? "Aktiviert" : "Deaktiviert",
                    icon: trip.gpsTrackingEnabled ? "location.fill" : "location.slash",
                    color: trip.gpsTrackingEnabled ? .green : .orange
                )
                

            }
        }
    }
    
    private var activityStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Aktivitäts-Statistiken")
                .font(.headline)
            
            Text("\(memoriesWithGPXTracks.count) Aktivitäten mit GPS-Tracks")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Aktivitätskarten pro Typ
            ForEach(activityStatistics, id: \.activityType) { stat in
                ActivityStatisticCard(statistic: stat)
            }
        }
    }
    
    private var routeInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Route")
                    .font(.headline)
                Spacer()
                Button("Karte anzeigen") {
                    setupMapRegion()
                    showingFullscreenMap = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                .opacity(routePoints.count > 1 ? 1 : 0)
            }

            // Die Logik wird vereinfacht: Die Kartenvorschau wird angezeigt, sobald mehr als ein Routenpunkt vorhanden ist,
            // unabhängig davon, ob die Reise aktiv ist oder nicht.
            if routePoints.count > 1 {
                // Kartenvorschau für alle Reisen mit einer Route
                trackMapPreview
            } else if !routePoints.isEmpty {
                // Für Reisen mit nur einem Punkt (dem Startpunkt) wird eine spezielle Ansicht gezeigt.
                VStack(spacing: 8) {
                    if let firstPoint = routePoints.first {
                        RoutePointRow(
                            title: "Startpunkt",
                            point: firstPoint,
                            icon: "location.circle.fill",
                            color: .green
                        )
                    }
                    Text("Das GPS-Tracking ist aktiv. Weitere Routenpunkte werden hinzugefügt, sobald du dich bewegst.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var trackMapPreview: some View {
        Group {
            if #available(iOS 17.0, *) {
                Map {
                    // Track als Polyline
                    if routePoints.count > 1 {
                        MapPolyline(coordinates: routePoints.map { 
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) 
                        })
                        .stroke(Color.orange, lineWidth: 3)
                    }
                    
                    // Start- und Endpunkt
                    if let firstPoint = routePoints.first {
                        Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: firstPoint.latitude, longitude: firstPoint.longitude)) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                    }
                    
                    if let lastPoint = routePoints.last, routePoints.count > 1 {
                        Annotation("Ziel", coordinate: CLLocationCoordinate2D(latitude: lastPoint.latitude, longitude: lastPoint.longitude)) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                    }
                }
                .mapStyle(.standard)
            } else {
                // Fallback für iOS 16 und älter
                Map(coordinateRegion: .constant(mapRegion))
            }
        }
        .frame(height: 200)
        .cornerRadius(12)
        .onTapGesture {
            setupMapRegion()
            showingFullscreenMap = true
        }
        .onAppear {
            setupMapRegion()
        }
    }
    
    private var memoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Erinnerungen (\(memories.count))")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(randomMemories, id: \.objectID) { memory in
                    Button(action: {
                        selectedMemoryForFocus = memory
                    }) {
                        MemoryPreviewCard(memory: memory)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if memories.count > 4 {
                Button("Alle \(memories.count) Erinnerungen anzeigen") {
                    showingMemoriesSheet = true
                }
                .font(.caption)
            }
        }
    }
    
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export")
                .font(.headline)
            
            VStack(spacing: 12) {
                ExportOptionRow(
                    title: "GPX-Datei exportieren",
                    description: "Speichere die Route als GPX-Datei für andere GPS-Apps",
                    icon: "square.and.arrow.up",
                    action: exportGPX,
                    isEnabled: !routePoints.isEmpty
                )
                
                ExportOptionRow(
                    title: "Route teilen",
                    description: "Teile die GPX-Datei mit anderen Apps oder Personen",
                    icon: "square.and.arrow.up.on.square",
                    action: shareGPX,
                    isEnabled: !routePoints.isEmpty
                )
            }
        }
    }
    
    private func exportGPX() {
        guard !routePoints.isEmpty else {
            exportMessage = "Keine Routenpunkte zum Exportieren verfügbar."
            showingExportAlert = true
            return
        }
        
        if locationManager.shareGPXFile(for: trip) != nil {
            exportMessage = "GPX-Datei erfolgreich erstellt und in den Dokumenten gespeichert."
            showingExportAlert = true
        } else {
            exportMessage = "Fehler beim Erstellen der GPX-Datei."
            showingExportAlert = true
        }
    }
    
    private func shareGPX() {
        guard !routePoints.isEmpty else {
            print("❌ Keine RoutePoints verfügbar für Share")
            exportMessage = "Keine Routenpunkte zum Teilen verfügbar."
            showingExportAlert = true
            return
        }
        
        // Reset alte Share-URL
        gpxFileURL = nil
        
        // Erstelle GPX-Content mit dem verbesserten Exporter
        let options = GPXExporter.ExportOptions(
            includeExtensions: true,
            includeWaypoints: false,
            trackType: "walking",
            creator: "Journiary",
            compressionLevel: .none
        )
        
        // Validiere Route-Daten
        guard !routePoints.isEmpty else {
            exportMessage = "Keine Route-Daten zum Exportieren verfügbar."
            showingExportAlert = true
            return
        }
        
        guard let gpxContent = GPXExporter.exportTrip(trip, options: options) else {
            exportMessage = "Fehler beim Generieren der GPX-Datei."
            showingExportAlert = true
            return
        }
        
        // Erstelle temporäre Share-Datei
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = GPXExporter.generateFileName(for: trip)
        let tempFileURL = tempDir.appendingPathComponent("\(fileName)_share.gpx")
        
        do {
            // Lösche alte temporäre Datei falls vorhanden
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
            }
            
            // Schreibe neue temporäre Datei
            try gpxContent.write(to: tempFileURL, atomically: true, encoding: .utf8)
            
            // Verifiziere dass die Datei erstellt wurde
            guard FileManager.default.fileExists(atPath: tempFileURL.path) else {
                exportMessage = "Fehler beim Vorbereiten der Datei zum Teilen."
                showingExportAlert = true
                return
            }
            
            // Setze URL und zeige Share Sheet
            gpxFileURL = tempFileURL
            
            // Kurze Verzögerung um sicherzustellen, dass URL gesetzt ist
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showingShareSheet = true
            }
            
        } catch {
            exportMessage = "Fehler beim Vorbereiten der Datei zum Teilen: \(error.localizedDescription)"
            showingExportAlert = true
        }
    }
    
    private func deleteTrip() {
        viewContext.delete(trip)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Löschen der Reise: \(error)")
        }
    }
    
    private func endTrip() {
        trip.endDate = Date()
        trip.isActive = false
        
        // Stoppe das Tracking nicht sofort, sondern frage erst ab
        if locationManager.currentTrip?.objectID == trip.objectID && locationManager.isTracking {
            // Zeige Abfrage, ob Tracking gestoppt werden soll
            showingStopTrackingAlert = true
        } else {
            // Kein Tracking aktiv oder nicht aktuelle Reise
            saveTripEnd()
        }
    }
    
    private func stopTrackingForTrip() {
        // Stoppe das Tracking für diese Reise
        locationManager.stopTrackingProtected(userInitiated: true, reason: "Reise-Detail endTrip")
        pendingEndTrip = false
        saveTripEnd()
    }
    
    private func saveTripEnd() {
        do {
            try viewContext.save()
            print("Reise '\(trip.name ?? "Unbenannt")' erfolgreich beendet")
        } catch {
            print("Fehler beim Beenden der Reise: \(error)")
        }
        pendingEndTrip = false
    }
    
    private func cleanupTemporaryShareFile() {
        guard let shareURL = gpxFileURL,
              shareURL.path.contains("tmp"),  // Nur temporäre Dateien löschen
              FileManager.default.fileExists(atPath: shareURL.path) else { return }
        
        do {
            try FileManager.default.removeItem(at: shareURL)
        } catch {
            // Fehler beim Löschen ignorieren
        }
        
        gpxFileURL = nil
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
    
    private func formatGermanDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d. MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func setupMapRegion() {
        guard !routePoints.isEmpty else { return }
        
        let coordinates = routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.3, 0.01)
        )
        
        mapRegion = MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Shared Components Note
// StatCard is now in SharedUIComponents.swift

struct RoutePointRow: View {
    let title: String
    let point: RoutePoint
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Lat: \(point.latitude, specifier: "%.6f"), Lng: \(point.longitude, specifier: "%.6f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let timestamp = point.timestamp {
                    Text(timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

struct MemoryPreviewCard: View {
    let memory: Memory
    @State private var primaryImage: UIImage?
    @State private var isLoadingImage = false
    
    // Liefert alle Fotos (Legacy + MediaItems mit isPhoto)
    private var allPhotos: [(data: Data, order: Int)] {
        var photos: [(data: Data, order: Int)] = [];
        if let photoSet = memory.photos {
            let photoArray = (photoSet.allObjects as? [Photo])?.sorted { $0.order < $1.order } ?? []
            for photo in photoArray {
                if let imageData = photo.imageData {
                    photos.append((data: imageData, order: Int(photo.order)))
                }
            }
        }
        if let mediaItemSet = memory.mediaItems {
            let mediaItemArray = (mediaItemSet.allObjects as? [MediaItem])?.sorted { $0.order < $1.order } ?? []
            for mediaItem in mediaItemArray where mediaItem.isPhoto {
                if let imageData = mediaItem.mediaData {
                    photos.append((data: imageData, order: Int(mediaItem.order + 1000)))
                }
            }
        }
        return photos.sorted { $0.order < $1.order }
    }
    
    // Video-Thumbnail für Timeline-Darstellung bei Video-only Erinnerungen
    private var firstVideoThumbnail: UIImage? {
        guard let mediaSet = memory.mediaItems else { return nil }
        let mediaArray = (mediaSet.allObjects as? [MediaItem])?.sorted { $0.order < $1.order } ?? []
        for mediaItem in mediaArray where mediaItem.isVideo {
            if let thumbnail = mediaItem.thumbnail {
                return thumbnail
            }
        }
        return nil
    }
    
    // Medien-Anzahl
    private var allMediaCount: Int {
        var count = 0
        if let photoSet = memory.photos {
            count += (photoSet.allObjects as? [Photo])?.count ?? 0
        }
        if let mediaItemSet = memory.mediaItems {
            count += (mediaItemSet.allObjects as? [MediaItem])?.count ?? 0
        }
        return count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if let image = primaryImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 60)
                        .clipped()
                        .cornerRadius(6)
                } else if isLoadingImage {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 60)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                        .cornerRadius(6)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                        .cornerRadius(6)
                }
                if allMediaCount > 1 {
                    Text("\(allMediaCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(6)
                }
            }
            Text(memory.title ?? "Unbenannt")
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(height: 35, alignment: .top)
            // Tags anzeigen (max 2)
            if !memory.tagArray.isEmpty {
                HStack(spacing: 4) {
                    ForEach(memory.tagArray.prefix(2), id: \.objectID) { tag in
                        if let emoji = tag.emoji, !emoji.isEmpty {
                            Text(emoji)
                                .font(.caption2)
                        } else {
                            Circle()
                                .fill(tag.colorValue)
                                .frame(width: 6, height: 6)
                        }
                    }
                    if memory.tagArray.count > 2 {
                        Text("+\(memory.tagArray.count - 2)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            loadPrimaryImageAsync()
        }
        .onChange(of: memory.objectID) { _, _ in
            loadPrimaryImageAsync()
        }
    }
    
    private func loadPrimaryImageAsync() {
        primaryImage = nil
        if let firstPhotoData = allPhotos.first?.data {
            isLoadingImage = true
            Task {
                let image = await Task.detached(priority: .userInitiated) {
                    UIImage(data: firstPhotoData)
                }.value
                await MainActor.run {
                    self.primaryImage = image
                    self.isLoadingImage = false
                }
            }
        } else if let videoThumbnail = firstVideoThumbnail {
            primaryImage = videoThumbnail
        }
    }
}

struct ExportOptionRow: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
    let isEnabled: Bool
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isEnabled ? .blue : .gray)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isEnabled ? .primary : .gray)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Share Sheet Wrapper

struct ShareSheetWrapper: View {
    @Binding var fileURL: URL?
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if let url = fileURL {
                ActivityViewController(activityItems: [url])
                    .onDisappear {
                        onDismiss()
                    }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Fehler beim Teilen")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Die GPX-Datei konnte nicht vorbereitet werden.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button("Schließen") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .onAppear {
                    // Share ohne URL nicht möglich
                }
            }
        }
    }
}

// MARK: - Trip Track Map View

struct TripTrackMapView: View {
    let trip: Trip
    let routePoints: [RoutePoint]
    @Environment(\.dismiss) private var dismiss
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    var body: some View {
        NavigationView {
            Group {
                if #available(iOS 17.0, *) {
                    Map {
                        // Track als Polyline
                        if routePoints.count > 1 {
                            MapPolyline(coordinates: routePoints.map { 
                                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) 
                            })
                            .stroke(Color.orange, lineWidth: 4)
                        }
                        
                        // Start- und Endpunkt
                        if let firstPoint = routePoints.first {
                            Annotation("Start", coordinate: CLLocationCoordinate2D(latitude: firstPoint.latitude, longitude: firstPoint.longitude)) {
                                VStack {
                                    Image(systemName: "flag.fill")
                                        .foregroundColor(.green)
                                        .font(.title2)
                                        .background(Circle().fill(Color.white).frame(width: 30, height: 30))
                                    Text("Start")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 4)
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        
                        if let lastPoint = routePoints.last, routePoints.count > 1 {
                            Annotation("Ziel", coordinate: CLLocationCoordinate2D(latitude: lastPoint.latitude, longitude: lastPoint.longitude)) {
                                VStack {
                                    Image(systemName: "flag.checkered")
                                        .foregroundColor(.red)
                                        .font(.title2)
                                        .background(Circle().fill(Color.white).frame(width: 30, height: 30))
                                    Text("Ziel")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 4)
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        
                        // Erinnerungen als Pins
                        ForEach(trip.memories?.allObjects as? [Memory] ?? [], id: \.objectID) { memory in
                            if memory.latitude != 0 || memory.longitude != 0 {
                                Annotation(memory.title ?? "Erinnerung", coordinate: CLLocationCoordinate2D(latitude: memory.latitude, longitude: memory.longitude)) {
                                    VStack {
                                        Image(systemName: "camera.fill")
                                            .foregroundColor(.orange)
                                            .font(.title3)
                                            .background(Circle().fill(Color.white).frame(width: 24, height: 24))
                                        if let title = memory.title, !title.isEmpty {
                                            Text(title)
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundColor(.orange)
                                                .padding(.horizontal, 3)
                                                .background(Color.white.opacity(0.8))
                                                .cornerRadius(3)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .mapStyle(.standard)
                } else {
                    // Fallback für iOS 16 und älter
                    Map(coordinateRegion: .constant(region))
                }
            }
            .navigationTitle(trip.name ?? "Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupMapRegion()
            }
        }
    }
    
    private func setupMapRegion() {
        guard !routePoints.isEmpty else { return }
        
        let coordinates = routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.3, 0.01)
        )
        
        region = MKCoordinateRegion(center: center, span: span)
    }
}

// ActivityViewController wird von GPXExportView.swift bereitgestellt

// MARK: - Activity Statistics Data Structures

struct ActivityStatistic {
    let activityType: String
    var count: Int
    var totalDistance: Double
    var totalElevationGain: Double
    var totalElevationLoss: Double
    var totalDuration: TimeInterval
    
    var displayName: String {
        switch activityType.lowercased() {
        case "wandern": return "Wandern"
        case "radfahren": return "Radfahren"
        case "autofahrt": return "Autofahrt"
        case "laufen": return "Laufen"
        case "motorradfahrt": return "Motorradfahrt"
        case "segeln": return "Segeln"
        case "skifahren": return "Skifahren"
        default: return "Sonstiges"
        }
    }
    
    var icon: String {
        switch activityType.lowercased() {
        case "wandern": return "figure.walk"
        case "radfahren": return "bicycle"
        case "autofahrt": return "car"
        case "laufen": return "figure.run"
        case "motorradfahrt": return "motorcycle"
        case "segeln": return "sailboat"
        case "skifahren": return "figure.skiing.downhill"
        default: return "figure.walk"
        }
    }
    
    var color: Color {
        switch activityType.lowercased() {
        case "wandern": return .green
        case "radfahren": return .blue
        case "autofahrt": return .red
        case "laufen": return .orange
        case "motorradfahrt": return .purple
        case "segeln": return .cyan
        case "skifahren": return .mint
        default: return .gray
        }
    }
}

struct ActivityStatisticCard: View {
    let statistic: ActivityStatistic
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header mit Icon und Name
            HStack {
                Image(systemName: statistic.icon)
                    .foregroundColor(statistic.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(statistic.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(statistic.count) Aktivität\(statistic.count == 1 ? "" : "en")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Statistiken in Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ActivityStatItem(
                    title: "Distanz",
                    value: String(format: "%.1f km", statistic.totalDistance / 1000)
                )
                
                if statistic.totalDuration > 0 {
                    ActivityStatItem(
                        title: "Zeit",
                        value: formatDuration(statistic.totalDuration)
                    )
                }
                
                if statistic.totalElevationGain > 0 {
                    ActivityStatItem(
                        title: "Anstieg",
                        value: String(format: "%.0f m", statistic.totalElevationGain)
                    )
                }
                
                if statistic.totalElevationLoss > 0 {
                    ActivityStatItem(
                        title: "Abstieg",
                        value: String(format: "%.0f m", statistic.totalElevationLoss)
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

struct ActivityStatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let locationManager = LocationManager(context: context)
    
    // Beispiel-Trip
    let trip = Trip(context: context)
    trip.name = "Wanderung im Park"
    trip.startDate = Date().addingTimeInterval(-3600)
    trip.endDate = Date()
    trip.totalDistance = 5000.0

    trip.isActive = false
    
    return NavigationView {
        TripDetailView(trip: trip)
            .environmentObject(locationManager)
    }
    .environment(\.managedObjectContext, context)
}



