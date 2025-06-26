//
//  PolylineEncoder.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import Foundation
import CoreLocation

// MARK: - Google Polyline Encoding Implementation
// Basierend auf dem Google Polyline Algorithm für maximale Kompatibilität

class PolylineEncoder {
    
    // MARK: - Encoding
    
    /// Konvertiert RoutePoints zu einem Google Polyline String
    static func encode(_ points: [RoutePoint]) -> String {
        guard !points.isEmpty else { return "" }
        
        let coordinates = points.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        
        return encodeCoordinates(coordinates)
    }
    
    /// Konvertiert CLLocationCoordinate2D Array zu Polyline String
    static func encodeCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard !coordinates.isEmpty else { return "" }
        
        var encoded = ""
        var previousLat = 0
        var previousLng = 0
        
        for coordinate in coordinates {
            let lat = Int(round(coordinate.latitude * 1e5))
            let lng = Int(round(coordinate.longitude * 1e5))
            
            // Delta encoding (Differenz zum vorherigen Punkt)
            let deltaLat = lat - previousLat
            let deltaLng = lng - previousLng
            
            // Encode deltas
            encoded += encodeInteger(deltaLat)
            encoded += encodeInteger(deltaLng)
            
            previousLat = lat
            previousLng = lng
        }
        
        return encoded
    }
    
    /// Konvertiert Polyline String zurück zu Koordinaten
    static func decode(_ polyline: String) -> [CLLocationCoordinate2D] {
        guard !polyline.isEmpty else { return [] }
        
        var coordinates: [CLLocationCoordinate2D] = []
        var index = polyline.startIndex
        var lat = 0
        var lng = 0
        
        while index < polyline.endIndex {
            // Decode latitude delta
            let (deltaLat, newIndex1) = decodeInteger(from: polyline, startingAt: index)
            lat += deltaLat
            
            // Decode longitude delta
            let (deltaLng, newIndex2) = decodeInteger(from: polyline, startingAt: newIndex1)
            lng += deltaLng
            
            // Konvertiere zurück zu Dezimalgrad
            let coordinate = CLLocationCoordinate2D(
                latitude: Double(lat) / 1e5,
                longitude: Double(lng) / 1e5
            )
            coordinates.append(coordinate)
            
            index = newIndex2
        }
        
        return coordinates
    }
    
    // MARK: - Integer Encoding/Decoding
    
    private static func encodeInteger(_ value: Int) -> String {
        var result = ""
        var num = value < 0 ? ~(value << 1) : (value << 1)
        
        while num >= 0x20 {
            result += String(Character(UnicodeScalar((0x20 | (num & 0x1F)) + 63)!))
            num >>= 5
        }
        
        result += String(Character(UnicodeScalar(num + 63)!))
        return result
    }
    
    private static func decodeInteger(from polyline: String, startingAt index: String.Index) -> (Int, String.Index) {
        var currentIndex = index
        var shift = 0
        var result = 0
        var byte: Int
        
        repeat {
            guard currentIndex < polyline.endIndex else { break }
            
            let char = polyline[currentIndex]
            byte = Int(char.asciiValue!) - 63
            result |= (byte & 0x1F) << shift
            shift += 5
            currentIndex = polyline.index(after: currentIndex)
        } while byte >= 0x20
        
        let finalResult = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        return (finalResult, currentIndex)
    }
}

// MARK: - Extended Polyline Data Structure
// Für Journiary-spezifische Erweiterungen

struct ExtendedPolylineData: Codable {
    let polyline: String
    let metadata: PolylineMetadata
    var version: String = "1.0"
    
    struct PolylineMetadata: Codable {
        let originalPointCount: Int
        let totalDistance: Double
        let averageSpeed: Double
        let maxSpeed: Double
        let startTime: Date
        let endTime: Date
        let keyWaypoints: [KeyWaypoint]
        
        struct KeyWaypoint: Codable {
            let index: Int              // Index im dekodiereten Array
            let importance: Double      // 0-1, wichtigkeit
            let type: String           // "start", "end", "turn", "pause"
            let timestamp: Date
            let additionalData: [String: String]? // Flexibel für zukünftige Erweiterungen
        }
    }
    
    /// Konvertiert RoutePoints zu ExtendedPolylineData
    static func from(routePoints: [RoutePoint]) -> ExtendedPolylineData? {
        guard !routePoints.isEmpty else { return nil }
        
        let sortedPoints = routePoints.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        
        // Erzeuge Polyline
        let polyline = PolylineEncoder.encode(sortedPoints)
        
        // Berechne Metadaten
        let speeds = sortedPoints.map { $0.speed }
        let averageSpeed = speeds.reduce(0, +) / Double(speeds.count)
        let maxSpeed = speeds.max() ?? 0
        
        var totalDistance: Double = 0
        for i in 1..<sortedPoints.count {
            let p1 = CLLocation(latitude: sortedPoints[i-1].latitude, longitude: sortedPoints[i-1].longitude)
            let p2 = CLLocation(latitude: sortedPoints[i].latitude, longitude: sortedPoints[i].longitude)
            totalDistance += p1.distance(from: p2)
        }
        
        // Identifiziere wichtige Wegpunkte
        let keyWaypoints = identifyKeyWaypoints(sortedPoints)
        
        let metadata = PolylineMetadata(
            originalPointCount: sortedPoints.count,
            totalDistance: totalDistance,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            startTime: sortedPoints.first?.timestamp ?? Date(),
            endTime: sortedPoints.last?.timestamp ?? Date(),
            keyWaypoints: keyWaypoints
        )
        
        return ExtendedPolylineData(polyline: polyline, metadata: metadata)
    }
    
    /// Identifiziert wichtige Wegpunkte für bessere Rekonstruktion
    private static func identifyKeyWaypoints(_ points: [RoutePoint]) -> [PolylineMetadata.KeyWaypoint] {
        var waypoints: [PolylineMetadata.KeyWaypoint] = []
        
        // Start- und Endpunkt sind immer wichtig
        if let start = points.first {
            waypoints.append(PolylineMetadata.KeyWaypoint(
                index: 0,
                importance: 1.0,
                type: "start",
                timestamp: start.timestamp ?? Date(),
                additionalData: nil
            ))
        }
        
        if let end = points.last, points.count > 1 {
            waypoints.append(PolylineMetadata.KeyWaypoint(
                index: points.count - 1,
                importance: 1.0,
                type: "end",
                timestamp: end.timestamp ?? Date(),
                additionalData: nil
            ))
        }
        
        // Finde bedeutende Richtungsänderungen
        if points.count >= 3 {
            for i in 1..<(points.count - 1) {
                let p1 = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
                let p2 = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
                let p3 = CLLocation(latitude: points[i+1].latitude, longitude: points[i+1].longitude)
                
                let bearing1 = p1.bearing(to: p2)
                let bearing2 = p2.bearing(to: p3)
                let angleDiff = abs(bearing1 - bearing2)
                
                // Bedeutende Richtungsänderung (>30°)
                if angleDiff > 30 && angleDiff < 330 {
                    let importance = min(1.0, angleDiff / 90.0) // Normalisiert auf 0-1
                    
                    waypoints.append(PolylineMetadata.KeyWaypoint(
                        index: i,
                        importance: importance,
                        type: "turn",
                        timestamp: points[i].timestamp ?? Date(),
                        additionalData: ["angle_change": String(format: "%.1f", angleDiff)]
                    ))
                }
            }
        }
        
        // Finde Pausen (Geschwindigkeit < 1 km/h für >30s)
        var pauseStart: Int?
        for (index, point) in points.enumerated() {
            let isStationary = point.speed < 0.28 // < 1 km/h
            
            if isStationary && pauseStart == nil {
                pauseStart = index
            } else if !isStationary && pauseStart != nil {
                // Ende der Pause
                if let start = pauseStart,
                   let startTime = points[start].timestamp,
                   let endTime = point.timestamp,
                   endTime.timeIntervalSince(startTime) > 30 { // Mindestens 30s Pause
                    
                    waypoints.append(PolylineMetadata.KeyWaypoint(
                        index: start,
                        importance: 0.8,
                        type: "pause",
                        timestamp: startTime,
                        additionalData: [
                            "duration": String(format: "%.0f", endTime.timeIntervalSince(startTime)),
                            "end_index": String(index)
                        ]
                    ))
                }
                pauseStart = nil
            }
        }
        
        // Sortiere nach Index
        waypoints.sort { $0.index < $1.index }
        
        return waypoints
    }
    
    /// Rekonstruiert RoutePoints mit Enhanced Precision
    func reconstructPoints(preserveTimestamps: Bool = true) -> [CLLocationCoordinate2D] {
        let basicCoordinates = PolylineEncoder.decode(polyline)
        
        if !preserveTimestamps {
            return basicCoordinates
        }
        
        // TODO: Implementiere erweiterte Rekonstruktion mit Zeitstempel-Interpolation
        // basierend auf keyWaypoints
        
        return basicCoordinates
    }
    
    /// Berechnet die Kompressionsrate
    var compressionRatio: Double {
        let estimatedRoutePointSize = 50 // bytes
        let originalSize = metadata.originalPointCount * estimatedRoutePointSize
        let metadataSize: Int
        do {
            metadataSize = try JSONEncoder().encode(metadata).count
        } catch {
            metadataSize = 0
        }
        let compressedSize = Data(polyline.utf8).count + metadataSize
        
        return Double(compressedSize) / Double(originalSize)
    }
}

// MARK: - CLLocation Bearing Extension

extension CLLocation {
    func bearing(to destination: CLLocation) -> Double {
        let lat1 = coordinate.latitude * Double.pi / 180
        let lat2 = destination.coordinate.latitude * Double.pi / 180
        let deltaLng = (destination.coordinate.longitude - coordinate.longitude) * Double.pi / 180
        
        let y = sin(deltaLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLng)
        
        let bearing = atan2(y, x) * 180 / Double.pi
        return bearing >= 0 ? bearing : bearing + 360
    }
} 