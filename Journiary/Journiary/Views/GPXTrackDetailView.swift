//
//  GPXTrackDetailView.swift
//  Journiary
//
//  Created by AI Assistant on 25.06.25.
//

import SwiftUI
import MapKit
import CoreData

struct GPXTrackDetailView: View {
    let gpxTrack: GPXTrack
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var region = MKCoordinateRegion()
    @State private var showingShareSheet = false
    @State private var shareableFileURL: URL?
    @State private var showingDeleteAlert = false

    
    @State private var trackPoints: [RoutePoint] = []
    
    private func loadTrackPoints() {
        guard let points = gpxTrack.trackPoints?.allObjects as? [RoutePoint] else { 
            trackPoints = []
            return 
        }
        trackPoints = points.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
    }
    

    
    private var hasElevationData: Bool {
        return trackPoints.contains { $0.altitude > 0 }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Quadratische Karte mit GPS Track
                    gpxMapView
                    
                    // Alle Statistiken
                    allStatisticsView
                    
                    // Höhenprofil (falls vorhanden)
                    if hasElevationData {
                        elevationProfileView
                    }
                }
                .padding(.bottom, 50)
            }
            .navigationTitle(gpxTrack.name ?? "GPX Track")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: shareGPX) {
                            Label("Track teilen", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Track löschen", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadTrackPoints()
            calculateMapRegion()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareableFileURL {
                                            ActivityViewController(activityItems: [url])
            }
        }
        .alert("Track löschen", isPresented: $showingDeleteAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                deleteTrack()
            }
        } message: {
            Text("Möchten Sie diesen GPX-Track wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.")
        }
    }
    
    // MARK: - Header View
    

    

    
    // MARK: - GPX Map View
    
    private var gpxMapView: some View {
        if #available(iOS 17.0, *) {
            let coordinates: [CLLocationCoordinate2D] = trackPoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            return Map(initialPosition: .region(region)) {
                if coordinates.count > 1 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(Color.orange, lineWidth: 4)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(16)
            .padding(.horizontal)
        } else {
            // Fallback für iOS 16 und älter mit korrekter Bindung
            return Map(coordinateRegion: Binding.constant(region))
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(16)
                .padding(.horizontal)
        }
    }
    

    
    // MARK: - Map View (alt)
    
    private var mapView: some View {
        VStack {
            // Modernisierte Map für bessere Kompatibilität
            if #available(iOS 17.0, *) {
                let coordinates: [CLLocationCoordinate2D] = trackPoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                Map(initialPosition: .region(region)) {
                    if coordinates.count > 1 {
                        MapPolyline(coordinates: coordinates)
                            .stroke(Color.blue, lineWidth: 3)
                    }
                }
                .overlay(
                    VStack {
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Track: \(trackPoints.count) Punkte")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                
                                if trackPoints.count > 0 {
                                    Text("Start → Ziel")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.8))
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding()
                )
                .frame(minHeight: 400)
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Fallback für iOS 16 mit einfacher Kartenansicht
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(minHeight: 400)
                    
                    VStack {
                        Image(systemName: "map")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("GPS Track")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("\(trackPoints.count) GPS-Punkte")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            
            // Karten-Informationen
            VStack(spacing: 8) {
                HStack {
                    Label("Karte zeigt \(trackPoints.count) GPS-Punkte", systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                if let startTime = gpxTrack.startTime, let endTime = gpxTrack.endTime {
                    HStack {
                        Text("Von: \(startTime, style: .date) \(startTime, style: .time)")
                        Spacer()
                        Text("Bis: \(endTime, style: .date) \(endTime, style: .time)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - All Statistics View
    
    private var allStatisticsView: some View {
        VStack(spacing: 16) {
            // Überschrift
            HStack {
                Text("Statistiken")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            
            // Grid mit allen Statistiken
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Distanz (eine Nachkommastelle)
                GPXStatCard(title: "Gesamtdistanz", value: String(format: "%.1f km", gpxTrack.totalDistance / 1000.0), icon: "map", color: .blue)
                
                // Separate Zeit-Einträge
                if gpxTrack.totalDuration > 0 {
                    GPXStatCard(title: "Gesamtzeit", value: formatDuration(gpxTrack.totalDuration), icon: "clock", color: .green)
                    
                    // Korrekte "Zeit in Bewegung" Berechnung
                    let movingTime = calculateMovingTime()
                    GPXStatCard(title: "Zeit in Bewegung", value: formatDuration(movingTime), icon: "figure.walk", color: .blue)
                }
                
                // Geschwindigkeit (korrigierte Berechnung basierend auf Zeit in Bewegung)
                let correctedAverageSpeed = calculateAverageMovingSpeed()
                if correctedAverageSpeed > 0 {
                    GPXStatCard(title: "Ø Speed", value: String(format: "%.1f km/h", correctedAverageSpeed * 3.6), icon: "speedometer", color: .orange)
                }
                
                if gpxTrack.maxSpeed > 0 {
                    GPXStatCard(title: "Max. Geschwindigkeit", value: String(format: "%.1f km/h", gpxTrack.maxSpeed * 3.6), icon: "gauge.high", color: .red)
                }
                
                // Elevation (korrigierte Berechnung)
                let correctedElevationStats = calculateCorrectedElevationStats()
                if correctedElevationStats.gain > 0 {
                    GPXStatCard(title: "Anstieg", value: String(format: "%.0f m", correctedElevationStats.gain), icon: "arrow.up.right", color: .green)
                }
                
                if correctedElevationStats.loss > 0 {
                    GPXStatCard(title: "Abstieg", value: String(format: "%.0f m", correctedElevationStats.loss), icon: "arrow.down.right", color: .red)
                }
                
                if gpxTrack.minElevation != gpxTrack.maxElevation {
                    GPXStatCard(title: "Min. Höhe", value: String(format: "%.0f m", gpxTrack.minElevation), icon: "minus", color: .gray)
                    GPXStatCard(title: "Max. Höhe", value: String(format: "%.0f m", gpxTrack.maxElevation), icon: "plus", color: .gray)
                }
                
                // GPS-Daten
                GPXStatCard(title: "GPS-Punkte", value: "\(gpxTrack.totalPoints)", icon: "location", color: .purple)
                
                // Track-Typ
                GPXStatCard(title: "Aktivität", value: gpxTrack.trackType?.capitalized ?? "Unbekannt", icon: iconForTrackType(gpxTrack.trackType), color: .green)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Statistics View (alt)
    
    private var statisticsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            // Distanz und Zeit
                                    GPXStatCard(title: "Gesamtdistanz", value: String(format: "%.2f km", gpxTrack.totalDistance / 1000.0), icon: "road", color: .blue)
            
            if gpxTrack.totalDuration > 0 {
                                        GPXStatCard(title: "Gesamtzeit", value: formatDuration(gpxTrack.totalDuration), icon: "clock", color: .green)
            }
            
            // Geschwindigkeit
            if gpxTrack.averageSpeed > 0 {
                                        GPXStatCard(title: "⌀ Geschwindigkeit", value: String(format: "%.1f km/h", gpxTrack.averageSpeed * 3.6), icon: "speedometer", color: .orange)
            }
            
            if gpxTrack.maxSpeed > 0 {
                                        GPXStatCard(title: "Max. Geschwindigkeit", value: String(format: "%.1f km/h", gpxTrack.maxSpeed * 3.6), icon: "gauge.high", color: .red)
            }
            
            // Elevation
            if gpxTrack.elevationGain > 0 {
                GPXStatCard(title: "Anstieg", value: String(format: "%.0f m", gpxTrack.elevationGain), icon: "arrow.up.right", color: .green)
            }
            
            if gpxTrack.elevationLoss > 0 {
                GPXStatCard(title: "Abstieg", value: String(format: "%.0f m", gpxTrack.elevationLoss), icon: "arrow.down.right", color: .red)
            }
            
            if gpxTrack.minElevation != gpxTrack.maxElevation {
                GPXStatCard(title: "Min. Höhe", value: String(format: "%.0f m", gpxTrack.minElevation), icon: "minus", color: .gray)
                GPXStatCard(title: "Max. Höhe", value: String(format: "%.0f m", gpxTrack.maxElevation), icon: "plus", color: .gray)
            }
            
            // GPS-Daten
            GPXStatCard(title: "GPS-Punkte", value: "\(gpxTrack.totalPoints)", icon: "location", color: .purple)
            
            if let dataSize = gpxTrack.gpxData?.count {
                GPXStatCard(title: "Dateigröße", value: ByteCountFormatter.string(fromByteCount: Int64(dataSize), countStyle: .file), icon: "doc", color: .gray)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Elevation Profile View
    
    @ViewBuilder
    private var elevationProfileView: some View {
        if hasElevationData {
            VStack(alignment: .leading, spacing: 16) {
                Text("Höhenprofil")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                
                // Vereinfachtes Höhenprofil
                ElevationChartView(trackPoints: trackPoints)
                    .frame(height: 200)
                    .padding(.horizontal)
                

            }
        } else {
            EmptyView()
        }
    }
    
    // MARK: - Helper Functions
    
    /// Gibt das passende Icon für den Track-Typ zurück
    private func iconForTrackType(_ trackType: String?) -> String {
        guard let type = trackType?.lowercased() else { return "figure.walk" }
        
        switch type {
        case "hiking", "walking", "walk":
            return "figure.walk"
        case "running", "run":
            return "figure.run"
        case "cycling", "biking", "bike":
            return "bicycle"
        case "driving", "car":
            return "car"
        case "skiing":
            return "figure.skiing.downhill"
        case "snowboarding":
            return "snowboard"
        case "swimming":
            return "figure.pool.swim"
        case "sailing":
            return "sailboat"
        case "motorcycling", "motorcycle":
            return "motorcycle"
        case "flying", "flight":
            return "airplane"
        default:
            return "figure.walk"
        }
    }
    
    /// Berechnet die "Zeit in Bewegung" unter Ausschluss von Pausen
    /// Basierend auf bewährten Algorithmen aus GPS-Tracking-Anwendungen
    private func calculateMovingTime() -> TimeInterval {
        guard !trackPoints.isEmpty else { return 0 }
        
        // Sortiere Punkte nach Zeitstempel
        let sortedPoints = trackPoints.sorted { 
            ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) 
        }
        
        guard sortedPoints.count > 1 else { return 0 }
        
        var movingTime: TimeInterval = 0
        let pauseThreshold: Double = 0.5 // 0.5 m/s ≈ 1.8 km/h - unter dieser Geschwindigkeit gilt es als Pause
        let maxSegmentTime: TimeInterval = 300 // Maximale Zeit zwischen zwei Punkten (5 Minuten)
        
        for i in 1..<sortedPoints.count {
            let currentPoint = sortedPoints[i]
            let previousPoint = sortedPoints[i-1]
            
            guard let currentTime = currentPoint.timestamp,
                  let previousTime = previousPoint.timestamp else { continue }
            
            let segmentTime = currentTime.timeIntervalSince(previousTime)
            
            // Überspringe unrealistisch lange Segmente (GPS-Ausfall, lange Pausen)
            if segmentTime > maxSegmentTime {
                continue
            }
            
            // Berechne Geschwindigkeit zwischen den Punkten
            let distance = CLLocation(
                latitude: previousPoint.latitude, 
                longitude: previousPoint.longitude
            ).distance(from: CLLocation(
                latitude: currentPoint.latitude, 
                longitude: currentPoint.longitude
            ))
            
            let segmentSpeed = segmentTime > 0 ? distance / segmentTime : 0
            
            // Nur Segmente zählen, bei denen die Geschwindigkeit über dem Pausenschwellenwert liegt
            if segmentSpeed > pauseThreshold {
                movingTime += segmentTime
            }
        }
        
        return movingTime
    }
    
    /// Berechnet die korrekte Durchschnittsgeschwindigkeit basierend auf der Zeit in Bewegung
    /// Ähnlich der Implementierung in wanderer
    private func calculateAverageMovingSpeed() -> Double {
        guard !trackPoints.isEmpty else { return 0 }
        
        let sortedPoints = trackPoints.sorted { 
            ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) 
        }
        
        guard sortedPoints.count > 1 else { return 0 }
        
        var totalMovingDistance: Double = 0
        var totalMovingTime: TimeInterval = 0
        let pauseThreshold: Double = 0.5 // 0.5 m/s ≈ 1.8 km/h
        let maxSegmentTime: TimeInterval = 300 // 5 Minuten
        
        for i in 1..<sortedPoints.count {
            let currentPoint = sortedPoints[i]
            let previousPoint = sortedPoints[i-1]
            
            guard let currentTime = currentPoint.timestamp,
                  let previousTime = previousPoint.timestamp else { continue }
            
            let segmentTime = currentTime.timeIntervalSince(previousTime)
            
            // Überspringe unrealistisch lange Segmente
            if segmentTime > maxSegmentTime {
                continue
            }
            
            // Berechne Distanz und Geschwindigkeit für dieses Segment
            let distance = CLLocation(
                latitude: previousPoint.latitude, 
                longitude: previousPoint.longitude
            ).distance(from: CLLocation(
                latitude: currentPoint.latitude, 
                longitude: currentPoint.longitude
            ))
            
            let segmentSpeed = segmentTime > 0 ? distance / segmentTime : 0
            
            // Nur Segmente mit Bewegung berücksichtigen
            if segmentSpeed > pauseThreshold {
                totalMovingDistance += distance
                totalMovingTime += segmentTime
            }
        }
        
        // Durchschnittsgeschwindigkeit = Gesamte Bewegungsdistanz / Gesamte Bewegungszeit
        return totalMovingTime > 0 ? totalMovingDistance / totalMovingTime : 0
    }
    
    /// Berechnet korrigierte Höhenstatistiken unter Berücksichtigung von GPS-Rauschen
    /// Experimentelle Version zur Angleichung an wanderer
    private func calculateCorrectedElevationStats() -> (gain: Double, loss: Double) {
        guard !trackPoints.isEmpty else { return (0, 0) }
        
        let sortedPoints = trackPoints.sorted { 
            ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) 
        }
        
        guard sortedPoints.count > 1 else { return (0, 0) }
        
        // Filter: Nur Punkte mit validen Höhendaten
        let validElevationPoints = sortedPoints.filter { $0.altitude > -100 }
        
        guard validElevationPoints.count > 1 else { return (0, 0) }
        
        // Teste verschiedene Algorithmus-Varianten
        return calculateElevationWandererStyle(validElevationPoints)
    }
    
    /// Wanderer-ähnliche Höhenberechnung - experimentell
    private func calculateElevationWandererStyle(_ points: [RoutePoint]) -> (gain: Double, loss: Double) {
        // Variante 1: Weniger aggressive Glättung (3-Punkt statt 5-Punkt)
        let smoothedElevations = smoothElevationDataLight(points)
        
        // Variante 2: Niedrigerer Schwellenwert (2.5m statt 3m)
        let elevationThreshold: Double = 2.5
        
        var totalGain: Double = 0
        var totalLoss: Double = 0
        var cumulativeChange: Double = 0
        
        for i in 1..<smoothedElevations.count {
            let elevationChange = smoothedElevations[i] - smoothedElevations[i-1]
            cumulativeChange += elevationChange
            
            // Niedrigerer Schwellenwert für wanderer-Kompatibilität
            if abs(cumulativeChange) >= elevationThreshold {
                if cumulativeChange > 0 {
                    totalGain += cumulativeChange
                } else {
                    totalLoss += abs(cumulativeChange)
                }
                cumulativeChange = 0
            }
        }
        
        // Falls noch kumulative Änderung übrig ist, auch diese berücksichtigen
        // (wanderer könnte Restbeträge anders behandeln)
        if abs(cumulativeChange) >= 1.0 { // Sehr niedrige Restschwelle
            if cumulativeChange > 0 {
                totalGain += cumulativeChange
            } else {
                totalLoss += abs(cumulativeChange)
            }
        }
        
        return (gain: totalGain, loss: totalLoss)
    }
    
    /// Leichtere Glättung (3-Punkt Moving Average)
    private func smoothElevationDataLight(_ points: [RoutePoint]) -> [Double] {
        guard points.count > 2 else { return points.map { $0.altitude } }
        
        let windowSize = min(3, points.count) // 3-Punkt statt 5-Punkt
        var smoothedElevations: [Double] = []
        
        for i in 0..<points.count {
            let startIndex = max(0, i - windowSize/2)
            let endIndex = min(points.count - 1, i + windowSize/2)
            
            var sum: Double = 0
            var count: Int = 0
            
            for j in startIndex...endIndex {
                sum += points[j].altitude
                count += 1
            }
            
            smoothedElevations.append(sum / Double(count))
        }
        
        return smoothedElevations
    }
    
    /// Glättet Höhendaten mit Moving Average zur Rauschreduktion
    private func smoothElevationData(_ points: [RoutePoint]) -> [Double] {
        guard points.count > 2 else { return points.map { $0.altitude } }
        
        let windowSize = min(5, points.count) // 5-Punkt Moving Average oder weniger bei kurzen Tracks
        var smoothedElevations: [Double] = []
        
        for i in 0..<points.count {
            let startIndex = max(0, i - windowSize/2)
            let endIndex = min(points.count - 1, i + windowSize/2)
            
            var sum: Double = 0
            var count: Int = 0
            
            for j in startIndex...endIndex {
                sum += points[j].altitude
                count += 1
            }
            
            smoothedElevations.append(sum / Double(count))
        }
        
        return smoothedElevations
    }
    
    private func calculateMapRegion() {
        guard !trackPoints.isEmpty else { return }
        
        let coordinates = trackPoints.map { 
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) 
        }
        
        let minLat = coordinates.map(\.latitude).min() ?? 0
        let maxLat = coordinates.map(\.latitude).max() ?? 0
        let minLon = coordinates.map(\.longitude).min() ?? 0
        let maxLon = coordinates.map(\.longitude).max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.01) * 1.2,
            longitudeDelta: max(maxLon - minLon, 0.01) * 1.2
        )
        
        region = MKCoordinateRegion(center: center, span: span)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
    
    private func shareGPX() {
        guard let gpxData = gpxTrack.gpxData else { return }
        
        let tempDir = FileManager.default.temporaryDirectory
        let filename = gpxTrack.originalFilename ?? "track.gpx"
        let tempFileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try gpxData.write(to: tempFileURL)
            shareableFileURL = tempFileURL
            showingShareSheet = true
        } catch {
            print("Fehler beim Erstellen der Share-Datei: \(error)")
        }
    }
    
    private func deleteTrack() {
        // Memory-Beziehung entfernen
        if let memory = gpxTrack.memory {
            memory.removeGPXTrack()
        }
        
        // Track löschen
        viewContext.delete(gpxTrack)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Löschen des GPX-Tracks: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct GPXStatisticView: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct GPXInfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct GPXStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon mit fester Höhe für einheitliche Ausrichtung
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
                .frame(height: 24) // Feste Höhe für alle Icons
                .frame(maxWidth: .infinity)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Elevation Chart View

struct ElevationChartView: View {
    let trackPoints: [RoutePoint]
    
    private var elevationData: [(distance: Double, elevation: Double)] {
        let pointsWithElevation = trackPoints.filter { $0.altitude > 0 }
        guard !pointsWithElevation.isEmpty else { return [] }
        
        // Berechne kumulative Distanz für jeden Punkt
        var cumulativeDistance: Double = 0
        var dataWithDistance: [(distance: Double, elevation: Double)] = []
        
        dataWithDistance.append((distance: 0, elevation: pointsWithElevation[0].altitude))
        
        for i in 1..<pointsWithElevation.count {
            let previousPoint = pointsWithElevation[i-1]
            let currentPoint = pointsWithElevation[i]
            
            let segmentDistance = CLLocation(
                latitude: previousPoint.latitude,
                longitude: previousPoint.longitude
            ).distance(from: CLLocation(
                latitude: currentPoint.latitude,
                longitude: currentPoint.longitude
            ))
            
            cumulativeDistance += segmentDistance
            dataWithDistance.append((distance: cumulativeDistance, elevation: currentPoint.altitude))
        }
        
        return dataWithDistance
    }
    
    private var totalTrackDistance: Double {
        guard !elevationData.isEmpty else { return 0 }
        return elevationData.last?.distance ?? 0
    }
    
    private var kmAxisLabels: some View {
        let totalDistanceKm = totalTrackDistance / 1000.0
        
        // Bestimme sinnvolle km-Intervalle basierend auf Gesamtdistanz
        let interval: Double
        if totalDistanceKm <= 2 {
            interval = 1.0 // Alle 1km
        } else if totalDistanceKm <= 10 {
            interval = 2.0 // Alle 2km
        } else if totalDistanceKm <= 30 {
            interval = 5.0 // Alle 5km
        } else {
            interval = 10.0 // Alle 10km
        }
        
        let markers = stride(from: 0.0, through: totalDistanceKm, by: interval).map { $0 }
        
        return HStack {
            ForEach(0..<markers.count, id: \.self) { index in
                let km = markers[index]
                
                HStack {
                    if index == 0 {
                        // Erster Marker: "0"
                        Text("0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if index == markers.count - 1 && abs(km - totalDistanceKm) < 0.1 {
                        // Letzter Marker: "Ziel" wenn er nahe am Ende ist
                        Text("Ziel")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        // Normale Zahlen ohne "km"
                        Text("\(String(format: km == floor(km) ? "%.0f" : "%.1f", km))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if index < markers.count - 1 {
                        Spacer()
                    }
                }
            }
            
            // Einheit "km" ganz rechts als Achsenbeschriftung
            Text("km")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 8)
    }
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                if !elevationData.isEmpty {
                    let maxElevation = elevationData.map(\.elevation).max() ?? 0
                    let minElevation = elevationData.map(\.elevation).min() ?? 0
                    let elevationRange = maxElevation - minElevation
                    
                    ZStack {
                        // Höhenprofil mit distanzbasierter X-Achse
                        Path { path in
                            let maxDistance = elevationData.last?.distance ?? 1.0
                            for (index, data) in elevationData.enumerated() {
                                let xPos = (data.distance / maxDistance) * geometry.size.width
                                let yPos = geometry.size.height - (((data.elevation - minElevation) / elevationRange) * geometry.size.height)
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: xPos, y: yPos))
                                } else {
                                    path.addLine(to: CGPoint(x: xPos, y: yPos))
                                }
                            }
                        }
                        .stroke(Color.blue, lineWidth: 2)
                        .background(
                            Path { path in
                                let maxDistance = elevationData.last?.distance ?? 1.0
                                for (index, data) in elevationData.enumerated() {
                                    let xPos = (data.distance / maxDistance) * geometry.size.width
                                    let yPos = geometry.size.height - (((data.elevation - minElevation) / elevationRange) * geometry.size.height)
                                    
                                    if index == 0 {
                                        path.move(to: CGPoint(x: xPos, y: geometry.size.height))
                                        path.addLine(to: CGPoint(x: xPos, y: yPos))
                                    } else {
                                        path.addLine(to: CGPoint(x: xPos, y: yPos))
                                    }
                                }
                                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        )
                        
                        // Y-Achse Beschriftungen
                        VStack {
                            HStack {
                                Text("\(Int(maxElevation))m")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            Spacer()
                            HStack {
                                Text("\(Int(minElevation))m")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                } else {
                    Text("Keine Höhendaten verfügbar")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // X-Achse Beschriftung mit km-Markierungen
            kmAxisLabels
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Shared Components Note
// ActivityViewController is now in SharedUIComponents.swift

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    let gpxTrack = GPXTrack(context: context)
    gpxTrack.id = UUID()
    gpxTrack.name = "Wanderung im Schwarzwald"
    gpxTrack.totalDistance = 8500.0
    gpxTrack.totalDuration = 7200.0 // 2 Stunden
    gpxTrack.averageSpeed = 1.2
    gpxTrack.maxSpeed = 2.5
    gpxTrack.elevationGain = 450.0
    gpxTrack.elevationLoss = 450.0
    gpxTrack.minElevation = 320.0
    gpxTrack.maxElevation = 770.0
    gpxTrack.totalPoints = 425
    gpxTrack.creator = "Garmin"
    gpxTrack.trackType = "hiking"
    gpxTrack.originalFilename = "schwarzwald_tour.gpx"
    gpxTrack.importedAt = Date()
    
    return GPXTrackDetailView(gpxTrack: gpxTrack)
        .environment(\.managedObjectContext, context)
} 