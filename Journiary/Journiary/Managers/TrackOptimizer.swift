//
//  TrackOptimizer.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import Foundation
import CoreLocation
import CoreData

// MARK: - Track Optimization Algorithms

/// Intelligente Punkteauswahl für GPS-Tracks
/// Basierend auf bewährten Algorithmen aus Open-GPX-Tracker und anderen GPS-Tools
class TrackOptimizer {
    
    // MARK: - Configuration
    
    struct OptimizationSettings {
        /// Maximale Abweichung von der ursprünglichen Route in Metern
        let maxDeviation: Double
        
        /// Minimaler Abstand zwischen Punkten in Metern
        let minDistance: Double
        
        /// Maximaler Abstand zwischen Punkten in Metern (verhindert zu große Lücken)
        let maxDistance: Double
        
        /// Geschwindigkeitsabhängiger Faktor für Punktdichte
        let speedFactor: Double
        
        /// Winkel-Threshold für Richtungsänderungen (in Grad)
        let angleThreshold: Double
        
        /// Zeitbasierte Mindestdistanz (Sekunden)
        let minTimeInterval: TimeInterval
        
        // MARK: - Basierend auf GPX-Analyse optimierte Einstellungen
        
        static let level1 = OptimizationSettings(
            maxDeviation: 5.0,
            minDistance: 30.0,
            maxDistance: 250.0,
            speedFactor: 0.5,
            angleThreshold: 15.0,
            minTimeInterval: 20.0
        )
        static let level2 = OptimizationSettings(
            maxDeviation: 10.0,
            minDistance: 50.0,
            maxDistance: 500.0,
            speedFactor: 1.2,
            angleThreshold: 25.0,
            minTimeInterval: 30.0
        )
        static let level3 = OptimizationSettings(
            maxDeviation: 20.0,
            minDistance: 100.0,
            maxDistance: 800.0,
            speedFactor: 2.0,
            angleThreshold: 35.0,
            minTimeInterval: 60.0
        )
        // Neue Stufe zwischen 28 und 87 km/h
        static let level4 = OptimizationSettings(
            maxDeviation: 25.0,
            minDistance: 150.0,
            maxDistance: 1000.0,
            speedFactor: 2.5,
            angleThreshold: 40.0,
            minTimeInterval: 90.0
        )
        static let level5 = OptimizationSettings(
            maxDeviation: 30.0,
            minDistance: 200.0,
            maxDistance: 1200.0,
            speedFactor: 3.0,
            angleThreshold: 45.0,
            minTimeInterval: 120.0
        )
    }
    
    // MARK: - Douglas-Peucker Algorithm (vereinfacht)
    
    /// Vereinfachter Douglas-Peucker Algorithmus für GPS-Tracks
    static func douglasPeucker(points: [CLLocation], epsilon: Double) -> [CLLocation] {
        guard points.count > 2 else { return points }
        
        // Finde den Punkt mit der größten Distanz zur Linie zwischen Start und Ende
        let startPoint = points.first!
        let endPoint = points.last!
        
        var maxDistance: Double = 0
        var maxIndex = 0
        
        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistance(point: points[i], lineStart: startPoint, lineEnd: endPoint)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        // Wenn die maximale Distanz größer als epsilon ist, teile rekursiv auf
        if maxDistance > epsilon {
            let leftPart = douglasPeucker(points: Array(points[0...maxIndex]), epsilon: epsilon)
            let rightPart = douglasPeucker(points: Array(points[maxIndex..<points.count]), epsilon: epsilon)
            
            // Kombiniere die Ergebnisse (ohne doppelten Mittelpunkt)
            return leftPart + Array(rightPart.dropFirst())
        } else {
            // Alle Punkte sind innerhalb des Toleranzbereichs, behalte nur Start und Ende
            return [startPoint, endPoint]
        }
    }
    
    /// Berechne die senkrechte Distanz von einem Punkt zu einer Linie
    private static func perpendicularDistance(point: CLLocation, lineStart: CLLocation, lineEnd: CLLocation) -> Double {
        let x0 = point.coordinate.latitude
        let y0 = point.coordinate.longitude
        let x1 = lineStart.coordinate.latitude
        let y1 = lineStart.coordinate.longitude
        let x2 = lineEnd.coordinate.latitude
        let y2 = lineEnd.coordinate.longitude
        
        let dx = x2 - x1
        let dy = y2 - y1
        
        if dx == 0 && dy == 0 {
            // Start und End sind gleich, gib Distanz zu einem der Punkte zurück
            return point.distance(from: lineStart)
        }
        
        let t = ((x0 - x1) * dx + (y0 - y1) * dy) / (dx * dx + dy * dy)
        
        let closestPoint: CLLocation
        if t < 0 {
            closestPoint = lineStart
        } else if t > 1 {
            closestPoint = lineEnd
        } else {
            let projectedLat = x1 + t * dx
            let projectedLon = y1 + t * dy
            closestPoint = CLLocation(latitude: projectedLat, longitude: projectedLon)
        }
        
        return point.distance(from: closestPoint)
    }
    
    // MARK: - Intelligent Point Selection
    
    ///
    /// GPS-Optimierungslevel und ihre Geschwindigkeitsbereiche:
    ///
    /// | Level   | Typische Nutzung         | km/h-Bereich   |
    /// |---------|-------------------------|----------------|
    /// | Level 1 | Zu Fuß                  | 0 - 10         |
    /// | Level 2 | Fahrrad                 | 11 - 28        |
    /// | Level 3 | Innerorts (PKW)         | 29 - 60        |
    /// | Level 4 | Außerorts (PKW/LKW)     | 61 - 87        |
    /// | Level 5 | Schnell (Zug, Flugzeug) | ab 88          |
    ///
    
    /// Liefert die passenden Optimierungs-Settings anhand der Geschwindigkeit (in km/h)
    static func settingsForSpeed(_ speedKmh: Double) -> OptimizationSettings {
        switch speedKmh {
        case 0...10:
            return OptimizationSettings.level1
        case 11...28:
            return OptimizationSettings.level2
        case 29...60:
            return OptimizationSettings.level3
        case 61...87:
            return OptimizationSettings.level4
        default:
            return OptimizationSettings.level5
        }
    }
    
    /// Hauptfunktion für intelligente Punkteauswahl (basierend auf GPX-Analyse)
    /// Diese Version nutzt die Geschwindigkeit zur Level-Bestimmung
    static func shouldSavePointAutoLevel(
        newLocation: CLLocation,
        lastSavedLocation: CLLocation?,
        previousLocation: CLLocation?
    ) -> Bool {
        let speedKmh = max(newLocation.speed, 0) * 3.6
        let settings = settingsForSpeed(speedKmh)
        return shouldSavePoint(
            newLocation: newLocation,
            lastSavedLocation: lastSavedLocation,
            previousLocation: previousLocation,
            settings: settings
        )
    }
    
    /// Hauptfunktion für intelligente Punkteauswahl (basierend auf GPX-Analyse)
    static func shouldSavePoint(
        newLocation: CLLocation,
        lastSavedLocation: CLLocation?,
        previousLocation: CLLocation?,
        settings: OptimizationSettings
    ) -> Bool {
        
        guard let lastSaved = lastSavedLocation else {
            // Ersten Punkt immer speichern
            return true
        }
        
        // 1. GPS-Genauigkeit prüfen (frühe Überprüfung)
        if newLocation.horizontalAccuracy > 100.0 || newLocation.horizontalAccuracy < 0 {
            return false // Schlechte GPS-Genauigkeit -> verwerfen
        }
        
        let distance = newLocation.distance(from: lastSaved)
        let timeInterval = newLocation.timestamp.timeIntervalSince(lastSaved.timestamp)
        let speed = max(newLocation.speed, 0) * 3.6 // Umrechnung m/s -> km/h
        
        // 2. Zeitbasierte Prüfung (GPX-Pattern: 30s/60s)
        if timeInterval < settings.minTimeInterval {
            return false
        }
        
        // 3. Geschwindigkeitsabhängige Mindestdistanz (GPX-Erkenntnis: 3,8x bei hoher Geschwindigkeit)
        var adaptiveMinDistance = settings.minDistance
        
        if speed > 50.0 {
            // Hohe Geschwindigkeit: größere Abstände (wie in GPX-Analyse)
            adaptiveMinDistance *= (1.0 + (speed - 50.0) / 50.0 * settings.speedFactor)
        } else if speed < 20.0 {
            // Niedrige Geschwindigkeit: kleinere Abstände
            adaptiveMinDistance *= 0.6
        }
        
        // 4. Minimale Distanz prüfen
        if distance < adaptiveMinDistance {
            return false
        }
        
        // 5. Maximale Distanz prüfen (verhindert zu große Lücken)
        if distance > settings.maxDistance {
            return true
        }
        
        // 6. Richtungsänderung prüfen (GPX-Erkenntnis: weniger Punkte bei Geradeausfahrt)
        if let previous = previousLocation {
            let angleChange = calculateAngleChange(from: previous, via: lastSaved, to: newLocation)
            
            // Bei signifikanten Richtungsänderungen: Punkt auf jeden Fall speichern
            if angleChange > settings.angleThreshold {
                return true
            }
            
            // Bei Geradeausfahrt: größere Abstände erlauben (GPX-Pattern)
            if angleChange <= 5.0 && distance < adaptiveMinDistance * 1.5 {
                return false
            }
        }
        
        // 7. Erweiterte GPS-Genauigkeitsprüfung
        if newLocation.horizontalAccuracy > 30.0 {
            // Mittlere GPS-Genauigkeit -> nur bei größeren Distanzen speichern
            return distance > adaptiveMinDistance * 1.5
        }
        
        // 8. Höhenänderung berücksichtigen (zusätzlicher Faktor)
        if abs(newLocation.altitude - lastSaved.altitude) > 10.0 {
            // Signifikante Höhenänderung -> eher speichern
            return distance > adaptiveMinDistance * 0.8
        }
        
        return true
    }
    
    /// Berechne Winkeländerung zwischen drei aufeinanderfolgenden Punkten
    private static func calculateAngleChange(from p1: CLLocation, via p2: CLLocation, to p3: CLLocation) -> Double {
        let bearing1 = p1.bearing(to: p2)
        let bearing2 = p2.bearing(to: p3)
        
        var angleDiff = abs(bearing2 - bearing1)
        if angleDiff > 180 {
            angleDiff = 360 - angleDiff
        }
        
        return angleDiff
    }
    
    // MARK: - Post-Processing Optimization
    
    /// Optimiere einen bestehenden Track nachträglich
    static func optimizeExistingTrack(routePoints: [RoutePoint], settings: OptimizationSettings) -> [RoutePoint] {
        guard routePoints.count > 2 else { return routePoints }
        
        // Konvertiere zu CLLocation Array
        let locations = routePoints.compactMap { point -> CLLocation? in
            guard let timestamp = point.timestamp else { return nil }
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                altitude: point.altitude,
                horizontalAccuracy: 5.0,
                verticalAccuracy: 5.0,
                timestamp: timestamp
            )
            return location
        }
        
        // Anwenden des Douglas-Peucker Algorithmus
        let optimizedLocations = douglasPeucker(points: locations, epsilon: settings.maxDeviation)
        
        // Erstelle Mapping von optimierten Locations zu ursprünglichen RoutePoints
        var optimizedRoutePoints: [RoutePoint] = []
        
        for optimizedLocation in optimizedLocations {
            // Finde den entsprechenden RoutePoint
            if let matchingPoint = routePoints.first(where: { point in
                abs(point.latitude - optimizedLocation.coordinate.latitude) < 0.0001 &&
                abs(point.longitude - optimizedLocation.coordinate.longitude) < 0.0001
            }) {
                optimizedRoutePoints.append(matchingPoint)
            }
        }
        
        return optimizedRoutePoints
    }
    
    // MARK: - Transportation Mode Specific Settings
    
    /// Hole optimale Einstellungen basierend auf Transportmittel (GPX-Analyse-optimiert)
    static func settingsForTransportation(_ mode: String?) -> OptimizationSettings {
        guard let mode = mode?.lowercased() else { return .level2 }
        switch mode {
        case "walking", "hiking", "zu fuß":
            return .level1  // Viele Punkte für genaue Tracks
        case "cycling", "bicycle", "bike", "fahrrad":
            return .level2     // Ausgewogen für mittlere Geschwindigkeiten
        case "car", "auto", "driving":
            return .level3   // Weniger Punkte für Autofahrten
        case "highway", "außerorts":
            return .level4   // Neue Stufe für außerorts
        case "train", "bus", "airplane", "zug", "flugzeug":
            return .level5      // Sehr wenige Punkte für hohe Geschwindigkeiten
        default:
            return .level2
        }
    }
    
    // MARK: - Track Statistics
    
    /// Berechne Statistiken über die Track-Optimierung
    static func calculateOptimizationStats(
        originalPoints: [RoutePoint],
        optimizedPoints: [RoutePoint]
    ) -> (reductionPercentage: Double, savedPoints: Int, originalDistance: Double, optimizedDistance: Double) {
        
        let originalCount = originalPoints.count
        let optimizedCount = optimizedPoints.count
        let savedPoints = originalCount - optimizedCount
        let reductionPercentage = originalCount > 0 ? Double(savedPoints) / Double(originalCount) * 100.0 : 0.0
        
        let originalDistance = calculateTotalDistance(points: originalPoints)
        let optimizedDistance = calculateTotalDistance(points: optimizedPoints)
        
        return (reductionPercentage, savedPoints, originalDistance, optimizedDistance)
    }
    
    /// Berechne Gesamtdistanz von RoutePoints
    private static func calculateTotalDistance(points: [RoutePoint]) -> Double {
        guard points.count > 1 else { return 0.0 }
        
        var totalDistance: Double = 0.0
        
        for i in 1..<points.count {
            let prevPoint = points[i-1]
            let currentPoint = points[i]
            
            let prevLocation = CLLocation(latitude: prevPoint.latitude, longitude: prevPoint.longitude)
            let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
            
            totalDistance += currentLocation.distance(from: prevLocation)
        }
        
        return totalDistance
    }
} 