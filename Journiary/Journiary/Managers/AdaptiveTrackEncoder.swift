//
//  AdaptiveTrackEncoder.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import Foundation
import CoreLocation
import CoreData

// MARK: - Movement Pattern Analysis

enum MovementPattern: String, CaseIterable {
    case straightHighSpeed = "straight_high_speed"      // Autobahn, Fernzug
    case urbanMixed = "urban_mixed"                     // Stadtverkehr mit Stops
    case irregularLowSpeed = "irregular_low_speed"      // Wandern, komplexe Navigation
    case pauseHeavy = "pause_heavy"                     // Viele Stops/Pausen
    case highwayWithExits = "highway_with_exits"        // Autobahn mit Abfahrten
    
    var displayName: String {
        switch self {
        case .straightHighSpeed: return "Geradeaus (hohe Geschwindigkeit)"
        case .urbanMixed: return "Stadtverkehr (gemischt)"
        case .irregularLowSpeed: return "Unregelmäßig (niedrige Geschwindigkeit)"
        case .pauseHeavy: return "Viele Pausen"
        case .highwayWithExits: return "Autobahn mit Abfahrten"
        }
    }
    
    var optimalCompressionMethod: CompressionMethod {
        switch self {
        case .straightHighSpeed:
            return .polylineEncoding
        case .urbanMixed:
            return .hybridVectorPoints
        case .irregularLowSpeed:
            return .optimizedPoints
        case .pauseHeavy:
            return .waypointBased
        case .highwayWithExits:
            return .segmentedPolyline
        }
    }
}

enum CompressionMethod: String, CaseIterable, Codable {
    case polylineEncoding = "polyline"           // Google-style encoded polylines
    case hybridVectorPoints = "hybrid"           // Vektoren + wichtige Punkte
    case optimizedPoints = "points"              // Optimierte Punkt-Speicherung
    case waypointBased = "waypoints"             // Waypoints + Verbindungslinien
    case segmentedPolyline = "segmented"         // Mehrere Polyline-Segmente
    
    var expectedCompressionRatio: Double {
        switch self {
        case .polylineEncoding: return 0.15        // 85% Kompression
        case .hybridVectorPoints: return 0.35      // 65% Kompression
        case .optimizedPoints: return 0.60         // 40% Kompression
        case .waypointBased: return 0.25           // 75% Kompression
        case .segmentedPolyline: return 0.20       // 80% Kompression
        }
    }
}

// MARK: - Segment Analysis Results

struct SegmentCharacteristics {
    let movementPattern: MovementPattern
    let averageSpeed: Double
    let maxSpeed: Double
    let speedVariance: Double
    let directionChanges: Int
    let pauseCount: Int
    let totalDistance: Double
    let duration: TimeInterval
    let gpsAccuracy: Double
    let elevationChange: Double
    let straightLineRatio: Double  // Verhältnis gerade/gekrümmt
    
    var transportationMode: String {
        switch (averageSpeed, maxSpeed) {
        case (0..<3, _): return "walking"
        case (3..<15, _): return "cycling"
        case (15..<50, _): return "urban_driving"
        case (50..<90, _): return "highway"
        case (90..., _): return "high_speed_rail"
        default: return "unknown"
        }
    }
}

// MARK: - Encoded Track Data

struct EncodedTrackData: Codable {
    let method: CompressionMethod
    let data: Data
    let metadata: TrackMetadata
    let originalPointCount: Int
    let compressionRatio: Double
    let qualityLevel: String
    
    struct TrackMetadata: Codable {
        let encodingVersion: String
        let startLatitude: Double
        let startLongitude: Double
        let endLatitude: Double
        let endLongitude: Double
        let boundingBox: BoundingBox
        let keyWaypoints: [Waypoint]
        let encodingParametersJSON: String // JSON String statt [String: Any]
        
        struct BoundingBox: Codable {
            let minLatitude: Double
            let maxLatitude: Double
            let minLongitude: Double
            let maxLongitude: Double
        }
        
        struct Waypoint: Codable {
            let latitude: Double
            let longitude: Double
            let timestamp: Date
            let type: String // "start", "end", "turn", "pause"
            
            init(coordinate: CLLocationCoordinate2D, timestamp: Date, type: String) {
                self.latitude = coordinate.latitude
                self.longitude = coordinate.longitude
                self.timestamp = timestamp
                self.type = type
            }
            
            var coordinate: CLLocationCoordinate2D {
                CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
        }
    }
}

// MARK: - Adaptive Track Encoder

class AdaptiveTrackEncoder {
    private let segmentDurationThreshold: TimeInterval = 3600 // 1 Stunde
    private let segmentDistanceThreshold: Double = 10000      // 10 km
    private let minPointsForCompression = 10
    
    // MARK: - Main Encoding Function
    
    func encodeSegment(_ points: [RoutePoint]) -> EncodedTrackData? {
        guard points.count >= minPointsForCompression else {
            // Zu wenig Punkte - keine Kompression
            return encodeAsOptimizedPoints(points, qualityLevel: "full")
        }
        
        let characteristics = analyzeSegment(points)
        let method = characteristics.movementPattern.optimalCompressionMethod
        
        print("📊 Segment-Analyse: \(characteristics.movementPattern.displayName)")
        print("🔄 Gewählte Methode: \(method.rawValue)")
        print("📈 Erwartete Kompression: \(Int((1.0 - method.expectedCompressionRatio) * 100))%")
        
        switch method {
        case .polylineEncoding:
            return encodeAsPolyline(points)
        case .hybridVectorPoints:
            return encodeAsHybridVectorPoints(points)
        case .optimizedPoints:
            return encodeAsOptimizedPoints(points, qualityLevel: "optimized")
        case .waypointBased:
            return encodeAsWaypointBased(points)
        case .segmentedPolyline:
            return encodeAsSegmentedPolyline(points)
        }
    }
    
    // MARK: - Segment Analysis
    
    private func analyzeSegment(_ points: [RoutePoint]) -> SegmentCharacteristics {
        guard points.count >= 2 else {
            return SegmentCharacteristics(
                movementPattern: .irregularLowSpeed,
                averageSpeed: 0, maxSpeed: 0, speedVariance: 0,
                directionChanges: 0, pauseCount: 0, totalDistance: 0,
                duration: 0, gpsAccuracy: 5.0, elevationChange: 0,
                straightLineRatio: 0
            )
        }
        
        let sortedPoints = points.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        
        // Geschwindigkeitsanalyse
        let speeds = sortedPoints.map { $0.speed }
        let averageSpeed = speeds.reduce(0, +) / Double(speeds.count)
        let maxSpeed = speeds.max() ?? 0
        let speedVariance = calculateVariance(speeds)
        
        // Richtungsänderungen
        let directionChanges = calculateDirectionChanges(sortedPoints)
        
        // Pausen (Geschwindigkeit < 1 km/h für >30s)
        let pauseCount = calculatePauseCount(sortedPoints)
        
        // Distanz und Dauer
        let totalDistance = calculateTotalDistance(sortedPoints)
        let duration = (sortedPoints.last?.timestamp ?? Date()).timeIntervalSince(sortedPoints.first?.timestamp ?? Date())
        
        // GPS-Genauigkeit (geschätzt)
        let gpsAccuracy = estimateGPSAccuracy(sortedPoints)
        
        // Höhenänderung
        let elevationChange = calculateElevationChange(sortedPoints)
        
        // Verhältnis gerade/gekrümmt
        let straightLineRatio = calculateStraightLineRatio(sortedPoints)
        
        // Pattern-Erkennung
        let movementPattern = classifyMovementPattern(
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            speedVariance: speedVariance,
            directionChanges: directionChanges,
            pauseCount: pauseCount,
            straightLineRatio: straightLineRatio,
            duration: duration
        )
        
        return SegmentCharacteristics(
            movementPattern: movementPattern,
            averageSpeed: averageSpeed * 3.6, // m/s zu km/h
            maxSpeed: maxSpeed * 3.6,
            speedVariance: speedVariance,
            directionChanges: directionChanges,
            pauseCount: pauseCount,
            totalDistance: totalDistance,
            duration: duration,
            gpsAccuracy: gpsAccuracy,
            elevationChange: elevationChange,
            straightLineRatio: straightLineRatio
        )
    }
    
    private func classifyMovementPattern(
        averageSpeed: Double,
        maxSpeed: Double,
        speedVariance: Double,
        directionChanges: Int,
        pauseCount: Int,
        straightLineRatio: Double,
        duration: TimeInterval
    ) -> MovementPattern {
        let avgSpeedKmh = averageSpeed * 3.6
        let maxSpeedKmh = maxSpeed * 3.6
        
        // Viele Pausen
        if Double(pauseCount) > duration / 600 { // Mehr als eine Pause pro 10 Minuten
            return .pauseHeavy
        }
        
        // Hohe Geschwindigkeit + gerade Strecke
        if avgSpeedKmh > 60 && straightLineRatio > 0.8 && directionChanges < 5 {
            return .straightHighSpeed
        }
        
        // Autobahn mit Abfahrten
        if avgSpeedKmh > 50 && maxSpeedKmh > 80 && directionChanges > 3 && directionChanges < 15 {
            return .highwayWithExits
        }
        
        // Stadtverkehr
        if avgSpeedKmh > 15 && avgSpeedKmh < 50 && speedVariance > 100 {
            return .urbanMixed
        }
        
        // Langsam und unregelmäßig (Wandern)
        return .irregularLowSpeed
    }
    
    // MARK: - Helper Functions für Analyse
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count - 1)
    }
    
    private func calculateDirectionChanges(_ points: [RoutePoint]) -> Int {
        guard points.count >= 3 else { return 0 }
        
        var changes = 0
        for i in 1..<(points.count - 1) {
            let p1 = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
            let p2 = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            let p3 = CLLocation(latitude: points[i+1].latitude, longitude: points[i+1].longitude)
            
            let bearing1 = p1.bearing(to: p2)
            let bearing2 = p2.bearing(to: p3)
            let angleDiff = abs(bearing1 - bearing2)
            
            if angleDiff > 15 && angleDiff < 345 { // Mindestens 15° Änderung
                changes += 1
            }
        }
        
        return changes
    }
    
    private func calculatePauseCount(_ points: [RoutePoint]) -> Int {
        var pauseCount = 0
        var inPause = false
        
        for point in points {
            let isStationary = point.speed < 0.28 // < 1 km/h
            
            if isStationary && !inPause {
                pauseCount += 1
                inPause = true
            } else if !isStationary {
                inPause = false
            }
        }
        
        return pauseCount
    }
    
    private func calculateTotalDistance(_ points: [RoutePoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        
        var totalDistance: Double = 0
        for i in 1..<points.count {
            let p1 = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
            let p2 = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            totalDistance += p1.distance(from: p2)
        }
        
        return totalDistance
    }
    
    private func estimateGPSAccuracy(_ points: [RoutePoint]) -> Double {
        // Vereinfachte Schätzung basierend auf Geschwindigkeitsvariation
        let speeds = points.map { $0.speed }
        let speedVariance = calculateVariance(speeds)
        
        // Hohe Varianz deutet auf schlechte GPS-Qualität hin
        return min(15.0, max(3.0, speedVariance / 10))
    }
    
    private func calculateElevationChange(_ points: [RoutePoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        
        let minAltitude = points.map { $0.altitude }.min() ?? 0
        let maxAltitude = points.map { $0.altitude }.max() ?? 0
        
        return maxAltitude - minAltitude
    }
    
    private func calculateStraightLineRatio(_ points: [RoutePoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        
        let start = CLLocation(latitude: points.first!.latitude, longitude: points.first!.longitude)
        let end = CLLocation(latitude: points.last!.latitude, longitude: points.last!.longitude)
        let straightLineDistance = start.distance(from: end)
        let actualDistance = calculateTotalDistance(points)
        
        return actualDistance > 0 ? min(1.0, straightLineDistance / actualDistance) : 0
    }
}

// MARK: - Concrete Encoding Implementations

extension AdaptiveTrackEncoder {
    
    /// Google Polyline Encoding - Optimal für gerade Autobahnstrecken
    private func encodeAsPolyline(_ points: [RoutePoint]) -> EncodedTrackData? {
        guard let extendedData = ExtendedPolylineData.from(routePoints: points) else { return nil }
        
        do {
            let encodedData = try JSONEncoder().encode(extendedData)
            
            let metadata = createTrackMetadata(
                points: points,
                method: .polylineEncoding,
                extendedData: extendedData
            )
            
            return EncodedTrackData(
                method: .polylineEncoding,
                data: encodedData,
                metadata: metadata,
                originalPointCount: points.count,
                compressionRatio: extendedData.compressionRatio,
                qualityLevel: "polyline_optimized"
            )
        } catch {
            print("❌ Fehler beim Polyline-Encoding: \(error)")
            return nil
        }
    }
    
    /// Hybrid Vector + Points - Für Stadtverkehr mit Kurven und Geradeaus-Abschnitten
    private func encodeAsHybridVectorPoints(_ points: [RoutePoint]) -> EncodedTrackData? {
        let segments = segmentByMovementType(points)
        var hybridData = HybridEncodedData()
        
        for segment in segments {
            switch segment.type {
            case .straight:
                // Verwende Polyline für gerade Abschnitte
                if let polylineData = ExtendedPolylineData.from(routePoints: segment.points) {
                    hybridData.segments.append(.polyline(polylineData))
                }
            case .curved, .mixed:
                // Verwende optimierte Punkte für Kurven
                let optimizedPoints = optimizePointsForCurves(segment.points)
                hybridData.segments.append(.points(optimizedPoints))
            }
        }
        
        do {
            let encodedData = try JSONEncoder().encode(hybridData)
            let metadata = createTrackMetadata(points: points, method: .hybridVectorPoints)
            
            let estimatedRoutePointSize = 50 // bytes
            let originalSize = points.count * estimatedRoutePointSize
            let compressionRatio = Double(encodedData.count) / Double(originalSize)
            
            return EncodedTrackData(
                method: .hybridVectorPoints,
                data: encodedData,
                metadata: metadata,
                originalPointCount: points.count,
                compressionRatio: compressionRatio,
                qualityLevel: "hybrid_adaptive"
            )
        } catch {
            print("❌ Fehler beim Hybrid-Encoding: \(error)")
            return nil
        }
    }
    
    /// Optimierte Punkt-Speicherung - Für unregelmäßige Bewegungen (Wandern)
    private func encodeAsOptimizedPoints(_ points: [RoutePoint], qualityLevel: String) -> EncodedTrackData? {
        let retentionFactor: Double
        switch qualityLevel {
        case "full": retentionFactor = 1.0
        case "high": retentionFactor = 0.8
        case "medium": retentionFactor = 0.5
        case "low": retentionFactor = 0.25
        default: retentionFactor = 0.8
        }
        
        let optimizedPoints = intelligentPointSelection(points, retentionFactor: retentionFactor)
        let optimizedData = OptimizedPointsData.from(points: optimizedPoints)
        
        do {
            let encodedData = try JSONEncoder().encode(optimizedData)
            let metadata = createTrackMetadata(points: points, method: .optimizedPoints)
            
            let compressionRatio = Double(optimizedPoints.count) / Double(points.count)
            
            return EncodedTrackData(
                method: .optimizedPoints,
                data: encodedData,
                metadata: metadata,
                originalPointCount: points.count,
                compressionRatio: compressionRatio,
                qualityLevel: qualityLevel
            )
        } catch {
            print("❌ Fehler beim Optimized Points Encoding: \(error)")
            return nil
        }
    }
    
    /// Waypoint-basierte Encoding - Für Routen mit vielen Pausen
    private func encodeAsWaypointBased(_ points: [RoutePoint]) -> EncodedTrackData? {
        let waypoints = extractWaypoints(from: points)
        let waypointData = WaypointBasedData(waypoints: waypoints)
        
        do {
            let encodedData = try JSONEncoder().encode(waypointData)
            let metadata = createTrackMetadata(points: points, method: .waypointBased)
            
            let estimatedRoutePointSize = 50 // bytes
            let originalSize = points.count * estimatedRoutePointSize
            let compressionRatio = Double(encodedData.count) / Double(originalSize)
            
            return EncodedTrackData(
                method: .waypointBased,
                data: encodedData,
                metadata: metadata,
                originalPointCount: points.count,
                compressionRatio: compressionRatio,
                qualityLevel: "waypoint_optimized"
            )
        } catch {
            print("❌ Fehler beim Waypoint-Based Encoding: \(error)")
            return nil
        }
    }
    
    /// Segmentierte Polylines - Für Autobahn mit Abfahrten
    private func encodeAsSegmentedPolyline(_ points: [RoutePoint]) -> EncodedTrackData? {
        let segments = detectHighwaySegments(points)
        var segmentedData = SegmentedPolylineData()
        
        for segment in segments {
            if let polylineData = ExtendedPolylineData.from(routePoints: segment.points) {
                segmentedData.polylineSegments.append(SegmentedPolylineData.Segment(
                    polyline: polylineData,
                    type: segment.type,
                    priority: segment.priority
                ))
            }
        }
        
        do {
            let encodedData = try JSONEncoder().encode(segmentedData)
            let metadata = createTrackMetadata(points: points, method: .segmentedPolyline)
            
            let estimatedRoutePointSize = 50 // bytes
            let originalSize = points.count * estimatedRoutePointSize
            let compressionRatio = Double(encodedData.count) / Double(originalSize)
            
            return EncodedTrackData(
                method: .segmentedPolyline,
                data: encodedData,
                metadata: metadata,
                originalPointCount: points.count,
                compressionRatio: compressionRatio,
                qualityLevel: "segmented_highway"
            )
        } catch {
            print("❌ Fehler beim Segmented Polyline Encoding: \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Methods für spezielle Encoding-Strategien
    
    private func segmentByMovementType(_ points: [RoutePoint]) -> [MovementSegment] {
        var segments: [MovementSegment] = []
        var currentSegment: [RoutePoint] = []
        var currentType: MovementSegmentType = .mixed
        
        for i in 0..<points.count {
            let segmentType = determineLocalMovementType(points, around: i)
            
            if segmentType != currentType && !currentSegment.isEmpty {
                segments.append(MovementSegment(type: currentType, points: currentSegment))
                currentSegment = []
            }
            
            currentType = segmentType
            currentSegment.append(points[i])
        }
        
        if !currentSegment.isEmpty {
            segments.append(MovementSegment(type: currentType, points: currentSegment))
        }
        
        return segments
    }
    
    private func determineLocalMovementType(_ points: [RoutePoint], around index: Int) -> MovementSegmentType {
        let windowSize = 5
        let startIndex = max(0, index - windowSize)
        let endIndex = min(points.count - 1, index + windowSize)
        
        guard endIndex > startIndex + 2 else { return .mixed }
        
        let windowPoints = Array(points[startIndex...endIndex])
        let characteristics = analyzeSegment(windowPoints)
        
        if characteristics.straightLineRatio > 0.9 && characteristics.averageSpeed > 50 {
            return .straight
        } else if characteristics.directionChanges > windowPoints.count / 3 {
            return .curved
        } else {
            return .mixed
        }
    }
    
    private func optimizePointsForCurves(_ points: [RoutePoint]) -> [OptimizedPoint] {
        return points.compactMap { point in
            OptimizedPoint(
                latitude: point.latitude,
                longitude: point.longitude,
                timestamp: point.timestamp ?? Date(),
                speed: point.speed,
                altitude: point.altitude,
                importance: calculatePointImportance(point, in: points)
            )
        }
    }
    
    private func calculatePointImportance(_ point: RoutePoint, in points: [RoutePoint]) -> Double {
        // Vereinfachte Wichtigkeitsberechnung
        // In einer vollständigen Implementierung würde hier eine komplexere Analyse stattfinden
        let speedChange = abs(point.speed - (points.first?.speed ?? point.speed))
        let importance = min(1.0, speedChange / 10.0) // Normalisiert
        return max(0.1, importance) // Minimum importance
    }
    
    private func intelligentPointSelection(_ points: [RoutePoint], retentionFactor: Double) -> [RoutePoint] {
        let targetCount = Int(Double(points.count) * retentionFactor)
        guard targetCount < points.count else { return points }
        
        // Verwende Douglas-Peucker ähnlichen Algorithmus
        let sorted = points.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        
        // Behalte immer Start und Ende
        var selected: Set<Int> = [0, sorted.count - 1]
        
        // Füge wichtige Punkte hinzu basierend auf Richtungsänderungen
        for i in 1..<(sorted.count - 1) {
            if calculatePointImportance(sorted[i], in: sorted) > 0.7 {
                selected.insert(i)
            }
        }
        
        // Fülle auf bis targetCount erreicht ist
        let step = max(1, sorted.count / targetCount)
        for i in stride(from: 0, to: sorted.count, by: step) {
            selected.insert(i)
        }
        
        return selected.sorted().map { sorted[$0] }
    }
    
    private func extractWaypoints(from points: [RoutePoint]) -> [WaypointData] {
        var waypoints: [WaypointData] = []
        
        // Start- und Endpunkt
        if let start = points.first {
            waypoints.append(WaypointData(
                coordinate: CLLocationCoordinate2D(latitude: start.latitude, longitude: start.longitude),
                timestamp: start.timestamp ?? Date(),
                type: "start",
                speed: start.speed,
                altitude: start.altitude
            ))
        }
        
        // Pausen und wichtige Punkte
        // TODO: Implementiere Pause-Detection und wichtige Wegpunkt-Erkennung
        
        if let end = points.last, points.count > 1 {
            waypoints.append(WaypointData(
                coordinate: CLLocationCoordinate2D(latitude: end.latitude, longitude: end.longitude),
                timestamp: end.timestamp ?? Date(),
                type: "end",
                speed: end.speed,
                altitude: end.altitude
            ))
        }
        
        return waypoints
    }
    
    private func detectHighwaySegments(_ points: [RoutePoint]) -> [HighwaySegment] {
        // TODO: Implementiere Autobahn-Segment-Erkennung
        return [HighwaySegment(points: points, type: "highway", priority: 1.0)]
    }
    
    private func createTrackMetadata(
        points: [RoutePoint], 
        method: CompressionMethod, 
        extendedData: ExtendedPolylineData? = nil
    ) -> EncodedTrackData.TrackMetadata {
        
        let sortedPoints = points.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        
        let startCoord = CLLocationCoordinate2D(
            latitude: sortedPoints.first?.latitude ?? 0,
            longitude: sortedPoints.first?.longitude ?? 0
        )
        
        let endCoord = CLLocationCoordinate2D(
            latitude: sortedPoints.last?.latitude ?? 0,
            longitude: sortedPoints.last?.longitude ?? 0
        )
        
        // Berechne Bounding Box
        let lats = sortedPoints.map { $0.latitude }
        let lngs = sortedPoints.map { $0.longitude }
        
        let boundingBox = EncodedTrackData.TrackMetadata.BoundingBox(
            minLatitude: lats.min() ?? 0,
            maxLatitude: lats.max() ?? 0,
            minLongitude: lngs.min() ?? 0,
            maxLongitude: lngs.max() ?? 0
        )
        
        // Konvertiere wichtige Punkte
        let keyWaypoints = extendedData?.metadata.keyWaypoints.map { kw in
            EncodedTrackData.TrackMetadata.Waypoint(
                coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), // Wird aus Index berechnet
                timestamp: kw.timestamp,
                type: kw.type
            )
        } ?? []
        
        // Erstelle encodingParameters als JSON String
        let encodingParameters: [String: Any] = [
            "method": method.rawValue,
            "pointCount": points.count,
            "compressionLevel": "adaptive"
        ]
        
        let encodingParametersJSON: String
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: encodingParameters)
            encodingParametersJSON = String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            encodingParametersJSON = "{}"
        }
        
        return EncodedTrackData.TrackMetadata(
            encodingVersion: "1.0",
            startLatitude: startCoord.latitude,
            startLongitude: startCoord.longitude,
            endLatitude: endCoord.latitude,
            endLongitude: endCoord.longitude,
            boundingBox: boundingBox,
            keyWaypoints: keyWaypoints,
            encodingParametersJSON: encodingParametersJSON
        )
    }
}

// MARK: - Supporting Data Structures

enum MovementSegmentType {
    case straight, curved, mixed
}

struct MovementSegment {
    let type: MovementSegmentType
    let points: [RoutePoint]
}

struct OptimizedPoint: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let speed: Double
    let altitude: Double
    let importance: Double
}

struct HybridEncodedData: Codable {
    var segments: [HybridSegment] = []
    
    enum HybridSegment: Codable {
        case polyline(ExtendedPolylineData)
        case points([OptimizedPoint])
    }
}

struct OptimizedPointsData: Codable {
    let points: [OptimizedPoint]
    var version: String = "1.0"
    
    static func from(points: [RoutePoint]) -> OptimizedPointsData {
        let optimizedPoints = points.map { point in
            OptimizedPoint(
                latitude: point.latitude,
                longitude: point.longitude,
                timestamp: point.timestamp ?? Date(),
                speed: point.speed,
                altitude: point.altitude,
                importance: 1.0
            )
        }
        
        return OptimizedPointsData(points: optimizedPoints)
    }
}

struct WaypointData: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let type: String
    let speed: Double
    let altitude: Double
    
    init(coordinate: CLLocationCoordinate2D, timestamp: Date, type: String, speed: Double, altitude: Double) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.timestamp = timestamp
        self.type = type
        self.speed = speed
        self.altitude = altitude
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct WaypointBasedData: Codable {
    let waypoints: [WaypointData]
    var version: String = "1.0"
}

struct HighwaySegment {
    let points: [RoutePoint]
    let type: String
    let priority: Double
}

struct SegmentedPolylineData: Codable {
    var polylineSegments: [Segment] = []
    
    struct Segment: Codable {
        let polyline: ExtendedPolylineData
        let type: String
        let priority: Double
    }
} 