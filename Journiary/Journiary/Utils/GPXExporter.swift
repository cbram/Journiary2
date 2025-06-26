//
//  GPXExporter.swift
//  Journiary
//
//  Created by AI Assistant on 09.06.25.
//

import Foundation
import CoreLocation
import CoreData

/// GPX-Exporter für GPS-Tracks mit vollständiger GPX 1.1 Standard-Konformität
class GPXExporter {
    
    // MARK: - Export-Optionen
    
    struct ExportOptions {
        var includeExtensions: Bool = true      // Geschwindigkeits- und weitere Daten einbeziehen
        var includeWaypoints: Bool = false      // Waypoints (z.B. Memories) einbeziehen
        var trackType: String = "walking"       // Track-Typ (walking, cycling, driving, etc.)
        var creator: String = "Journiary"       // Software-Name
        var compressionLevel: CompressionLevel = .none
        
        enum CompressionLevel {
            case none           // Alle Punkte exportieren
            case light          // Leichte Optimierung (Douglas-Peucker mit 5m Toleranz)
            case medium         // Mittlere Optimierung (Douglas-Peucker mit 10m Toleranz)
            case aggressive     // Starke Optimierung (Douglas-Peucker mit 20m Toleranz)
            
            var tolerance: Double {
                switch self {
                case .none: return 0.0
                case .light: return 5.0
                case .medium: return 10.0
                case .aggressive: return 20.0
                }
            }
        }
    }
    
    // MARK: - Export-Funktionen
    
    /// Exportiert eine gesamte Reise als GPX-Datei
    static func exportTrip(_ trip: Trip, options: ExportOptions = ExportOptions()) -> String? {
        guard let routePoints = trip.routePoints?.allObjects as? [RoutePoint],
              !routePoints.isEmpty else {
            print("❌ Keine Routenpunkte für Export gefunden")
            print("📊 Trip: \(trip.name ?? "Unbenannt"), RoutePoints: \(trip.routePoints?.count ?? 0)")
            return nil
        }
        
        // Nur bei Debug-Modus loggen um Performance zu verbessern
        #if DEBUG
        print("✅ \(routePoints.count) RoutePoints gefunden für Trip: \(trip.name ?? "Unbenannt")")
        #endif
        
        let sortedPoints = routePoints.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        
        // Validierung der ersten paar Punkte (nur bei Debug)
        #if DEBUG
        let samplePoints = Array(sortedPoints.prefix(3))
        for (index, point) in samplePoints.enumerated() {
            print("📍 Punkt \(index): lat=\(point.latitude), lon=\(point.longitude), time=\(point.timestamp?.description ?? "nil")")
        }
        #endif
        
        // Optional: Punkte komprimieren
        let pointsToExport: [RoutePoint]
        if options.compressionLevel != .none {
            pointsToExport = compressRoutePoints(sortedPoints, tolerance: options.compressionLevel.tolerance)
            #if DEBUG
            print("🗜️ Komprimiert: \(sortedPoints.count) → \(pointsToExport.count) Punkte")
            #endif
        } else {
            pointsToExport = sortedPoints
            #if DEBUG
            print("📦 Verwende alle \(pointsToExport.count) Punkte ohne Komprimierung")
            #endif
        }
        
        let gpxContent = generateGPXContent(
            trip: trip,
            routePoints: pointsToExport,
            options: options
        )
        
        #if DEBUG
        print("✅ GPX-Content erfolgreich generiert (\(gpxContent.count) Zeichen)")
        #endif
        
        return gpxContent
    }
    
    /// Exportiert ein einzelnes Track-Segment als GPX
    static func exportTrackSegment(_ segment: TrackSegment, options: ExportOptions = ExportOptions()) -> String? {
        guard let trip = segment.trip,
              let routePoints = segment.originalPoints?.allObjects as? [RoutePoint],
              !routePoints.isEmpty else {
            print("❌ Keine Routenpunkte im Segment gefunden")
            return nil
        }
        
        let sortedPoints = routePoints.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        
        return generateGPXContent(
            trip: trip,
            routePoints: sortedPoints,
            options: options,
            segmentName: "Segment \(segment.id?.uuidString.prefix(8) ?? "Unknown")"
        )
    }
    
    /// Exportiert nur ausgewählte RoutePoints als GPX
    static func exportRoutePoints(_ routePoints: [RoutePoint], tripName: String, options: ExportOptions = ExportOptions()) -> String? {
        guard !routePoints.isEmpty else {
            print("❌ Keine Routenpunkte für Export ausgewählt")
            return nil
        }
        
        let sortedPoints = routePoints.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        
        // Erstelle temporäres Trip-Objekt für Metadaten
        let startDate = sortedPoints.first?.timestamp ?? Date()
        let endDate = sortedPoints.last?.timestamp ?? Date()
        
        return generateGPXContentForPoints(
            routePoints: sortedPoints,
            tripName: tripName,
            startDate: startDate,
            endDate: endDate,
            options: options
        )
    }
    
    // MARK: - GPX-Generierung
    
    private static func generateGPXContent(
        trip: Trip,
        routePoints: [RoutePoint],
        options: ExportOptions,
        segmentName: String? = nil
    ) -> String {
        let dateFormatter = ISO8601DateFormatter()
        let creationTime = dateFormatter.string(from: trip.startDate ?? Date())
        let trackName = segmentName ?? trip.name ?? "Unbenannte Reise"
        
        // Berechne Track-Statistiken
        let stats = calculateTrackStatistics(routePoints)
        
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="\(options.creator)" 
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"
             xmlns="http://www.topografix.com/GPX/1/1" 
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <metadata>
            <name>\(trackName)</name>
            <desc>\(trip.tripDescription ?? "Exportiert mit \(options.creator)")</desc>
            <time>\(creationTime)</time>
        """
        
        // Erweiterte Metadaten
        if options.includeExtensions {
            gpx += """
            <extensions>
              <total_distance>\(String(format: "%.2f", stats.totalDistance))</total_distance>
              <total_points>\(routePoints.count)</total_points>
              <avg_speed>\(String(format: "%.2f", stats.averageSpeed))</avg_speed>
              <max_speed>\(String(format: "%.2f", stats.maxSpeed))</max_speed>
              <elevation_gain>\(String(format: "%.1f", stats.elevationGain))</elevation_gain>
              <elevation_loss>\(String(format: "%.1f", stats.elevationLoss))</elevation_loss>
            </extensions>
        """
        }
        
        gpx += """
          </metadata>
        """
        
        // Waypoints (z.B. für Memories)
        if options.includeWaypoints, let memories = trip.memories?.allObjects as? [Memory] {
            for memory in memories {
                if memory.latitude != 0.0 && memory.longitude != 0.0 {
                    let timestamp = dateFormatter.string(from: memory.timestamp ?? Date())
                    gpx += """
                      <wpt lat="\(memory.latitude)" lon="\(memory.longitude)">
            <name>\(memory.title ?? "Memory")</name>
            <desc>\(memory.text ?? "")</desc>
            <time>\(timestamp)</time>
          </wpt>
        """
                }
            }
        }
        
        // Track-Daten
        gpx += """
          <trk>
            <name>\(trackName)</name>
            <type>\(options.trackType)</type>
            <trkseg>
        """
        
        // Track-Punkte hinzufügen
        for point in routePoints {
            let timestamp = dateFormatter.string(from: point.timestamp ?? Date())
            
            gpx += """
              <trkpt lat=\"\(String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), point.latitude))\" lon=\"\(String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), point.longitude))\">
                <ele>\(String(format: "%.1f", point.altitude))</ele>
                <time>\(timestamp)</time>
"""
            
            // Erweiterte Daten
            if options.includeExtensions {
                gpx += """
                <extensions>
                  <speed>\(String(format: "%.2f", point.speed))</speed>
                </extensions>
        """
            }
            
            gpx += "              </trkpt>\n"
        }
        
        gpx += """
            </trkseg>
          </trk>
        </gpx>
        """
        
        return gpx
    }
    
    private static func generateGPXContentForPoints(
        routePoints: [RoutePoint],
        tripName: String,
        startDate: Date,
        endDate: Date,
        options: ExportOptions
    ) -> String {
        let dateFormatter = ISO8601DateFormatter()
        let creationTime = dateFormatter.string(from: startDate)
        
        // Berechne Track-Statistiken
        let stats = calculateTrackStatistics(routePoints)
        
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="\(options.creator)" 
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"
             xmlns="http://www.topografix.com/GPX/1/1" 
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <metadata>
            <name>\(tripName)</name>
            <desc>GPS-Track exportiert mit \(options.creator)</desc>
            <time>\(creationTime)</time>
        """
        
        if options.includeExtensions {
            gpx += """
            <extensions>
              <total_distance>\(String(format: "%.2f", stats.totalDistance))</total_distance>
              <total_points>\(routePoints.count)</total_points>
              <avg_speed>\(String(format: "%.2f", stats.averageSpeed))</avg_speed>
              <max_speed>\(String(format: "%.2f", stats.maxSpeed))</max_speed>
              <elevation_gain>\(String(format: "%.1f", stats.elevationGain))</elevation_gain>
              <elevation_loss>\(String(format: "%.1f", stats.elevationLoss))</elevation_loss>
            </extensions>
        """
        }
        
        gpx += """
          </metadata>
          <trk>
            <name>\(tripName)</name>
            <type>\(options.trackType)</type>
            <trkseg>
        """
        
        // Track-Punkte hinzufügen
        for point in routePoints {
            let timestamp = dateFormatter.string(from: point.timestamp ?? Date())
            
            gpx += """
              <trkpt lat=\"\(String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), point.latitude))\" lon=\"\(String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), point.longitude))\">
                <ele>\(String(format: "%.1f", point.altitude))</ele>
                <time>\(timestamp)</time>
"""
            
            if options.includeExtensions {
                gpx += """
                <extensions>
                  <speed>\(String(format: "%.2f", point.speed))</speed>
                </extensions>
        """
            }
            
            gpx += "              </trkpt>\n"
        }
        
        gpx += """
            </trkseg>
          </trk>
        </gpx>
        """
        
        return gpx
    }
    
    // MARK: - Statistiken
    
    private struct TrackStatistics {
        let totalDistance: Double       // in Metern
        let averageSpeed: Double        // in m/s
        let maxSpeed: Double           // in m/s
        let elevationGain: Double      // in Metern
        let elevationLoss: Double      // in Metern
        let duration: TimeInterval     // in Sekunden
    }
    
    private static func calculateTrackStatistics(_ routePoints: [RoutePoint]) -> TrackStatistics {
        guard routePoints.count > 1 else {
            return TrackStatistics(totalDistance: 0, averageSpeed: 0, maxSpeed: 0, 
                                 elevationGain: 0, elevationLoss: 0, duration: 0)
        }
        
        var totalDistance: Double = 0
        var maxSpeed: Double = 0
        var elevationGain: Double = 0
        var elevationLoss: Double = 0
        
        var previousElevation = routePoints.first?.altitude ?? 0
        
        for i in 1..<routePoints.count {
            let prevPoint = routePoints[i-1]
            let currentPoint = routePoints[i]
            
            // Distanz berechnen
            let prevLocation = CLLocation(latitude: prevPoint.latitude, longitude: prevPoint.longitude)
            let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
            totalDistance += currentLocation.distance(from: prevLocation)
            
            // Höhengewinn/-verlust berechnen
            let elevationDiff = currentPoint.altitude - previousElevation
            if elevationDiff > 0 {
                elevationGain += elevationDiff
            } else {
                elevationLoss += abs(elevationDiff)
            }
            previousElevation = currentPoint.altitude
            
            // Max-Geschwindigkeit
            maxSpeed = max(maxSpeed, currentPoint.speed)
        }
        
        // Durchschnittsgeschwindigkeit berechnen
        let startTime = routePoints.first?.timestamp ?? Date()
        let endTime = routePoints.last?.timestamp ?? Date()
        let duration = endTime.timeIntervalSince(startTime)
        let averageSpeed = duration > 0 ? totalDistance / duration : 0
        
        return TrackStatistics(
            totalDistance: totalDistance,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            duration: duration
        )
    }
    
    // MARK: - Kompression (Douglas-Peucker-Algorithmus)
    
    private static func compressRoutePoints(_ routePoints: [RoutePoint], tolerance: Double) -> [RoutePoint] {
        guard routePoints.count > 2, tolerance > 0 else { return routePoints }
        
        // Konvertiere zu CLLocation Array für Algorithmus
        let locations = routePoints.compactMap { point -> CLLocation? in
            guard let timestamp = point.timestamp else { return nil }
            return CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                altitude: point.altitude,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 5.0,
                timestamp: timestamp
            )
        }
        
        // Wende Douglas-Peucker-Algorithmus an
        let optimizedLocations = douglasPeucker(points: locations, epsilon: tolerance)
        
        // Mappe zurück zu RoutePoints
        var optimizedRoutePoints: [RoutePoint] = []
        
        for optimizedLocation in optimizedLocations {
            if let matchingPoint = routePoints.first(where: { point in
                abs(point.latitude - optimizedLocation.coordinate.latitude) < 0.000001 &&
                abs(point.longitude - optimizedLocation.coordinate.longitude) < 0.000001
            }) {
                optimizedRoutePoints.append(matchingPoint)
            }
        }
        
        print("🗜️ Track komprimiert: \(routePoints.count) → \(optimizedRoutePoints.count) Punkte (\(String(format: "%.1f", Double(optimizedRoutePoints.count) / Double(routePoints.count) * 100))%)")
        
        return optimizedRoutePoints
    }
    
    private static func douglasPeucker(points: [CLLocation], epsilon: Double) -> [CLLocation] {
        guard points.count > 2 else { return points }
        
        let firstPoint = points.first!
        let lastPoint = points.last!
        
        // Finde den Punkt mit der größten Distanz zur Geraden zwischen erstem und letztem Punkt
        var maxDistance: Double = 0
        var maxIndex = 0
        
        for i in 1..<(points.count - 1) {
            let distance = distanceFromPointToLine(
                point: points[i],
                lineStart: firstPoint,
                lineEnd: lastPoint
            )
            
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        // Wenn die maximale Distanz größer als epsilon ist, rekursiv vereinfachen
        if maxDistance > epsilon {
            // Rekursive Aufrufe für beide Teilstrecken
            let leftResults = douglasPeucker(
                points: Array(points[0...maxIndex]),
                epsilon: epsilon
            )
            let rightResults = douglasPeucker(
                points: Array(points[maxIndex..<points.count]),
                epsilon: epsilon
            )
            
            // Kombiniere Ergebnisse (ohne Duplikat am Verbindungspunkt)
            return leftResults + Array(rightResults.dropFirst())
        } else {
            // Vereinfache zu einer Linie zwischen erstem und letztem Punkt
            return [firstPoint, lastPoint]
        }
    }
    
    private static func distanceFromPointToLine(point: CLLocation, lineStart: CLLocation, lineEnd: CLLocation) -> Double {
        let A = point.coordinate.latitude - lineStart.coordinate.latitude
        let B = point.coordinate.longitude - lineStart.coordinate.longitude
        let C = lineEnd.coordinate.latitude - lineStart.coordinate.latitude
        let D = lineEnd.coordinate.longitude - lineStart.coordinate.longitude
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        if lenSq == 0 {
            // Linie ist ein Punkt
            return lineStart.distance(from: point)
        }
        
        let param = dot / lenSq
        
        let xx: Double
        let yy: Double
        
        if param < 0 {
            xx = lineStart.coordinate.latitude
            yy = lineStart.coordinate.longitude
        } else if param > 1 {
            xx = lineEnd.coordinate.latitude
            yy = lineEnd.coordinate.longitude
        } else {
            xx = lineStart.coordinate.latitude + param * C
            yy = lineStart.coordinate.longitude + param * D
        }
        
        let nearestPoint = CLLocation(latitude: xx, longitude: yy)
        return point.distance(from: nearestPoint)
    }
    
    // MARK: - File-Operationen
    
    /// Speichert GPX-Daten in eine Datei und gibt die URL zurück
    static func saveGPXToFile(gpxContent: String, fileName: String) -> URL? {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Erstelle Journiary-Unterordner falls er nicht existiert
        let journiaryFolder = documentsPath.appendingPathComponent("Journiary")
        
        do {
            if !fileManager.fileExists(atPath: journiaryFolder.path) {
                try fileManager.createDirectory(at: journiaryFolder, withIntermediateDirectories: true, attributes: nil)
                print("📁 Journiary-Ordner erstellt: \(journiaryFolder.path)")
            }
        } catch {
            print("❌ Fehler beim Erstellen des Journiary-Ordners: \(error)")
            // Fallback: Direkt im Documents-Ordner speichern
        }
        
        // Verwende Journiary-Ordner falls verfügbar, sonst Documents-Ordner
        let targetFolder = fileManager.fileExists(atPath: journiaryFolder.path) ? journiaryFolder : documentsPath
        let fileURL = targetFolder.appendingPathComponent("\(fileName).gpx")
        
        do {
            try gpxContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ GPX-Datei gespeichert: \(fileURL.path)")
            
            // Prüfe ob die Datei wirklich existiert
            if fileManager.fileExists(atPath: fileURL.path) {
                let fileSize = try fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
                print("📄 Dateigröße: \(fileSize) Bytes")
                return fileURL
            } else {
                print("❌ Datei wurde nicht erstellt: \(fileURL.path)")
                return nil
            }
        } catch {
            print("❌ Fehler beim Speichern der GPX-Datei: \(error)")
            print("📍 Zielordner: \(targetFolder.path)")
            print("📍 Vollständiger Pfad: \(fileURL.path)")
            return nil
        }
    }
    
    /// Erstellt eine temporäre Kopie der GPX-Datei für das Teilen
    static func createShareableGPXFile(gpxContent: String, fileName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent("\(fileName).gpx")
        
        do {
            // Lösche die alte temporäre Datei falls sie existiert
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
            }
            
            try gpxContent.write(to: tempFileURL, atomically: true, encoding: .utf8)
            print("✅ Temporäre GPX-Datei für Teilen erstellt: \(tempFileURL.path)")
            return tempFileURL
        } catch {
            print("❌ Fehler beim Erstellen der temporären GPX-Datei: \(error)")
            return nil
        }
    }
    
    /// Generiert einen sicheren Dateinamen basierend auf Trip-Name und Datum
    static func generateFileName(for trip: Trip) -> String {
        let tripName = trip.name ?? "Track"
        let date = trip.startDate ?? Date()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        
        // Bereinige den Namen von ungültigen Zeichen
        let cleanName = tripName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "*", with: "")
        
        return "\(cleanName)_\(dateFormatter.string(from: date))"
    }
}

// MARK: - Extensions

 