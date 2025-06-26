//
//  GPXImporter.swift
//  Journiary
//
//  Created by AI Assistant on 25.06.25.
//

import Foundation
import CoreLocation
import CoreData

/// GPX-Importer für das Laden und Analysieren von GPX-Dateien
class GPXImporter {
    
    // MARK: - GPX-Datenstrukturen
    
    struct GPXTrackData {
        let name: String
        let creator: String?
        let trackType: String?
        let trackPoints: [TrackPoint]
        let waypoints: [Waypoint]
        let metadata: GPXMetadata
        
        struct TrackPoint {
            let latitude: Double
            let longitude: Double
            let elevation: Double?
            let timestamp: Date?
            let speed: Double?
        }
        
        struct Waypoint {
            let latitude: Double
            let longitude: Double
            let name: String?
            let description: String?
            let timestamp: Date?
        }
        
        struct GPXMetadata {
            let name: String?
            let description: String?
            let time: Date?
        }
    }
    
    struct TrackStatistics {
        let totalDistance: Double
        let totalDuration: TimeInterval
        let averageSpeed: Double
        let maxSpeed: Double
        let elevationGain: Double
        let elevationLoss: Double
        let minElevation: Double
        let maxElevation: Double
        let totalPoints: Int
        let startTime: Date?
        let endTime: Date?
    }
    
    // MARK: - Import-Funktionen
    
    /// Importiert eine GPX-Datei aus Data
    static func importGPXData(_ data: Data) -> Result<GPXTrackData, GPXImportError> {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            return .failure(.invalidEncoding)
        }
        
        return parseGPXString(xmlString)
    }
    
    /// Importiert eine GPX-Datei von einer URL
    static func importGPXFile(from url: URL) -> Result<GPXTrackData, GPXImportError> {
        do {
            let data = try Data(contentsOf: url)
            return importGPXData(data)
        } catch {
            return .failure(.fileError(error))
        }
    }
    
    // MARK: - GPX-Parsing
    
    private static func parseGPXString(_ xmlString: String) -> Result<GPXTrackData, GPXImportError> {
        do {
            let parser = GPXParser()
            let trackData = try parser.parse(xmlString)
            return .success(trackData)
        } catch let error as GPXImportError {
            return .failure(error)
        } catch {
            return .failure(.parsingError(error.localizedDescription))
        }
    }
    
    // MARK: - Statistik-Berechnung
    
    /// Berechnet detaillierte Statistiken für einen GPS-Track
    static func calculateStatistics(for trackData: GPXTrackData) -> TrackStatistics {
        let points = trackData.trackPoints
        
        guard !points.isEmpty else {
            return TrackStatistics(
                totalDistance: 0, totalDuration: 0, averageSpeed: 0, maxSpeed: 0,
                elevationGain: 0, elevationLoss: 0, minElevation: 0, maxElevation: 0,
                totalPoints: 0, startTime: nil, endTime: nil
            )
        }
        
        // Distanz berechnen
        var totalDistance: Double = 0
        var maxSpeed: Double = 0
        var elevationGain: Double = 0
        var elevationLoss: Double = 0
        var minElevation: Double = Double.greatestFiniteMagnitude
        var maxElevation: Double = -Double.greatestFiniteMagnitude
        
        var previousPoint: GPXTrackData.TrackPoint?
        
        for point in points {
            // Elevation-Statistiken
            if let elevation = point.elevation {
                minElevation = min(minElevation, elevation)
                maxElevation = max(maxElevation, elevation)
                
                if let prevPoint = previousPoint,
                   let prevElevation = prevPoint.elevation {
                    let elevationDiff = elevation - prevElevation
                    if elevationDiff > 0 {
                        elevationGain += elevationDiff
                    } else {
                        elevationLoss -= elevationDiff
                    }
                }
            }
            
            // Distanz und Geschwindigkeit
            if let prevPoint = previousPoint {
                let prevLocation = CLLocation(
                    latitude: prevPoint.latitude,
                    longitude: prevPoint.longitude
                )
                let currentLocation = CLLocation(
                    latitude: point.latitude,
                    longitude: point.longitude
                )
                
                totalDistance += currentLocation.distance(from: prevLocation)
                
                if let speed = point.speed {
                    maxSpeed = max(maxSpeed, speed)
                }
            }
            
            previousPoint = point
        }
        
        // Zeit-Statistiken
        let timestampedPoints = points.compactMap { $0.timestamp }
        let startTime = timestampedPoints.min()
        let endTime = timestampedPoints.max()
        let totalDuration = (endTime?.timeIntervalSince(startTime ?? Date())) ?? 0
        
        // Durchschnittsgeschwindigkeit
        let averageSpeed = totalDuration > 0 ? (totalDistance / totalDuration) : 0
        
        // Elevation-Fallback falls keine Daten
        if minElevation == Double.greatestFiniteMagnitude {
            minElevation = 0
        }
        if maxElevation == -Double.greatestFiniteMagnitude {
            maxElevation = 0
        }
        
        return TrackStatistics(
            totalDistance: totalDistance,
            totalDuration: totalDuration,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            minElevation: minElevation,
            maxElevation: maxElevation,
            totalPoints: points.count,
            startTime: startTime,
            endTime: endTime
        )
    }
    
    // MARK: - Core Data Integration
    
    /// Erstellt einen GPXTrack in Core Data aus den importierten Daten
    static func createGPXTrack(
        from trackData: GPXTrackData,
        originalData: Data,
        filename: String,
        customTrackType: String? = nil,
        in context: NSManagedObjectContext
    ) -> GPXTrack {
        let gpxTrack = GPXTrack(context: context)
        gpxTrack.id = UUID()
        gpxTrack.name = trackData.name
        gpxTrack.originalFilename = filename
        gpxTrack.gpxData = originalData
        gpxTrack.creator = trackData.creator
        gpxTrack.trackType = customTrackType ?? trackData.trackType
        gpxTrack.importedAt = Date()
        
        // Statistiken berechnen und speichern
        let stats = calculateStatistics(for: trackData)
        gpxTrack.totalDistance = stats.totalDistance
        gpxTrack.totalDuration = stats.totalDuration
        gpxTrack.averageSpeed = stats.averageSpeed
        gpxTrack.maxSpeed = stats.maxSpeed
        gpxTrack.elevationGain = stats.elevationGain
        gpxTrack.elevationLoss = stats.elevationLoss
        gpxTrack.minElevation = stats.minElevation
        gpxTrack.maxElevation = stats.maxElevation
        gpxTrack.totalPoints = Int32(stats.totalPoints)
        gpxTrack.startTime = stats.startTime
        gpxTrack.endTime = stats.endTime
        
        // TrackPoints als RoutePoints erstellen
        for (index, point) in trackData.trackPoints.enumerated() {
            let routePoint = RoutePoint(context: context)
            routePoint.latitude = point.latitude
            routePoint.longitude = point.longitude
            routePoint.altitude = point.elevation ?? 0.0
            routePoint.timestamp = point.timestamp ?? Date().addingTimeInterval(TimeInterval(index))
            routePoint.speed = point.speed ?? 0.0
            routePoint.gpxTrack = gpxTrack
        }
        
        return gpxTrack
    }
    
    // MARK: - Hilfsfunktionen
    
    /// Generiert eine Vorschau-Beschreibung für einen Track
    static func generateTrackPreview(for trackData: GPXTrackData) -> String {
        let stats = calculateStatistics(for: trackData)
        
        let distanceKm = stats.totalDistance / 1000.0
        let durationString = formatDuration(stats.totalDuration)
        let avgSpeedKmh = stats.averageSpeed * 3.6
        
        var preview = "📍 \(stats.totalPoints) GPS-Punkte\n"
        preview += "📏 \(String(format: "%.2f", distanceKm)) km\n"
        
        if stats.totalDuration > 0 {
            preview += "⏱️ \(durationString)\n"
            preview += "🚀 ⌀ \(String(format: "%.1f", avgSpeedKmh)) km/h\n"
        }
        
        if stats.elevationGain > 0 {
            preview += "📈 +\(String(format: "%.0f", stats.elevationGain))m ↗️\n"
        }
        
        if stats.elevationLoss > 0 {
            preview += "📉 -\(String(format: "%.0f", stats.elevationLoss))m ↘️\n"
        }
        
        return preview.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
}

// MARK: - GPX-Parser

private class GPXParser: NSObject, XMLParserDelegate {
    private var currentElement = ""
    private var currentTrackData: GPXImporter.GPXTrackData?
    private var currentTrackPoints: [GPXImporter.GPXTrackData.TrackPoint] = []
    private var currentWaypoints: [GPXImporter.GPXTrackData.Waypoint] = []
    private var currentTrackPoint: GPXImporter.GPXTrackData.TrackPoint?
    private var currentWaypoint: GPXImporter.GPXTrackData.Waypoint?
    private var currentText = ""
    
    // Track-Metadaten
    private var trackName = ""
    private var trackCreator: String?
    private var trackType: String?
    private var metadataName: String?
    private var metadataDescription: String?
    private var metadataTime: Date?
    
    // Aktueller Track-Point-Kontext
    private var currentLatitude: Double = 0
    private var currentLongitude: Double = 0
    private var currentElevation: Double?
    private var currentTimestamp: Date?
    private var currentSpeed: Double?
    
    func parse(_ xmlString: String) throws -> GPXImporter.GPXTrackData {
        guard let data = xmlString.data(using: .utf8) else {
            throw GPXImportError.invalidEncoding
        }
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        guard parser.parse() else {
            throw GPXImportError.parsingError("XML-Parsing fehlgeschlagen")
        }
        
        guard let trackData = currentTrackData else {
            throw GPXImportError.noTrackData
        }
        
        return trackData
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""
        
        switch elementName {
        case "trkpt", "wpt":
            if let latString = attributeDict["lat"],
               let lonString = attributeDict["lon"],
               let latitude = Double(latString),
               let longitude = Double(lonString) {
                currentLatitude = latitude
                currentLongitude = longitude
                currentElevation = nil
                currentTimestamp = nil
                currentSpeed = nil
            }
        case "gpx":
            trackCreator = attributeDict["creator"]
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "name":
            if currentElement == "name" {
                if !currentTrackPoints.isEmpty || trackName.isEmpty {
                    trackName = currentText
                } else {
                    metadataName = currentText
                }
            }
        case "desc":
            metadataDescription = currentText
        case "time":
            if let date = parseDate(currentText) {
                if currentElement == "time" {
                    if currentLatitude != 0 && currentLongitude != 0 {
                        currentTimestamp = date
                    } else {
                        metadataTime = date
                    }
                }
            }
        case "ele":
            currentElevation = Double(currentText)
        case "speed":
            currentSpeed = Double(currentText)
        case "type":
            trackType = currentText
        case "trkpt":
            let trackPoint = GPXImporter.GPXTrackData.TrackPoint(
                latitude: currentLatitude,
                longitude: currentLongitude,
                elevation: currentElevation,
                timestamp: currentTimestamp,
                speed: currentSpeed
            )
            currentTrackPoints.append(trackPoint)
        case "wpt":
            let waypoint = GPXImporter.GPXTrackData.Waypoint(
                latitude: currentLatitude,
                longitude: currentLongitude,
                name: trackName.isEmpty ? nil : trackName,
                description: metadataDescription,
                timestamp: currentTimestamp
            )
            currentWaypoints.append(waypoint)
        case "gpx":
            // GPX-Parsing abgeschlossen
            let metadata = GPXImporter.GPXTrackData.GPXMetadata(
                name: metadataName,
                description: metadataDescription,
                time: metadataTime
            )
            
            currentTrackData = GPXImporter.GPXTrackData(
                name: trackName.isEmpty ? "Importierter Track" : trackName,
                creator: trackCreator,
                trackType: trackType,
                trackPoints: currentTrackPoints,
                waypoints: currentWaypoints,
                metadata: metadata
            )
        default:
            break
        }
        
        currentText = ""
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // Parser-Fehler werden durch den Hauptfehler-Mechanismus behandelt
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        
        // Fallback ohne Bruchteile von Sekunden
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        return iso8601Formatter.date(from: dateString)
    }
}

// MARK: - Error-Typen

enum GPXImportError: LocalizedError {
    case invalidEncoding
    case fileError(Error)
    case parsingError(String)
    case noTrackData
    case invalidGPXFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Die GPX-Datei hat eine ungültige Kodierung."
        case .fileError(let error):
            return "Fehler beim Lesen der Datei: \(error.localizedDescription)"
        case .parsingError(let message):
            return "Fehler beim Analysieren der GPX-Datei: \(message)"
        case .noTrackData:
            return "Keine GPS-Track-Daten in der GPX-Datei gefunden."
        case .invalidGPXFormat:
            return "Die Datei ist keine gültige GPX-Datei."
        }
    }
} 