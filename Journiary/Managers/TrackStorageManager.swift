//
//  TrackStorageManager.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import Foundation
import CoreLocation
import CoreData
import BackgroundTasks
import UIKit

// MARK: - Track Storage Configuration

struct TrackStorageConfig {
    static let segmentSizeThreshold = 500          // Punkte pro Segment
    static let compressionDelayHours = 24.0        // Stunden bis zur Kompression
    static let archiveDelayDays = 30.0             // Tage bis zur Archivierung
    static let maxMemorySegments = 5               // Max. Segmente im Memory
    static let backgroundCompressionInterval = 3600.0 // Sekunden zwischen Background-Jobs
    
    // Qualitätsstufen
    enum QualityLevel: String, CaseIterable {
        case full = "full"           // Volle Auflösung
        case high = "high"           // 80% der Originalpunkte
        case medium = "medium"       // 50% der Originalpunkte  
        case low = "low"             // 25% der Originalpunkte
        case archive = "archive"     // Minimale Auflösung für Langzeitspeicherung
        
        var retentionFactor: Double {
            switch self {
            case .full: return 1.0
            case .high: return 0.8
            case .medium: return 0.5
            case .low: return 0.25
            case .archive: return 0.1
            }
        }
    }
}

// MARK: - Segment Status

enum SegmentStatus: String {
    case live = "live"               // Aktuell aufgezeichnet
    case recent = "recent"           // Kürzlich beendet (<24h)
    case compressed = "compressed"   // Komprimiert gespeichert
    case archived = "archived"       // Langzeitarchiviert
    case synced = "synced"          // Mit Cloud synchronisiert
}

// MARK: - Track Storage Manager

@MainActor
class TrackStorageManager: ObservableObject {
    
    private let context: NSManagedObjectContext
    private let encoder = AdaptiveTrackEncoder()
    private let decoder = AdaptiveTrackDecoder()
    
    @Published var isCompressing = false
    @Published var compressionProgress: Double = 0.0
    @Published var storageStatistics = StorageStatistics()
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var compressionTimer: Timer?
    
    struct StorageStatistics {
        var totalSegments: Int = 0
        var compressedSegments: Int = 0
        var originalDataSize: Int64 = 0
        var compressedDataSize: Int64 = 0
        var compressionRatio: Double = 0.0
        var averageCompressionTime: TimeInterval = 0.0
        
        var savedSpace: Int64 {
            originalDataSize - compressedDataSize
        }
        
        var savedSpaceFormatted: String {
            ByteCountFormatter.string(fromByteCount: savedSpace, countStyle: .file)
        }
    }
    
    init(context: NSManagedObjectContext) {
        self.context = context
        setupBackgroundProcessing()
        loadStorageStatistics()
        
        print("✅ TrackStorageManager initialisiert")
    }
    
    // MARK: - Public Interface
    
    /// Startet eine neue Live-Tracking-Session
    func startLiveSegment(for trip: Trip) -> TrackSegment {
        let segment = TrackSegment(context: context)
        segment.id = UUID()
        segment.trip = trip
        segment.segmentType = SegmentStatus.live.rawValue
        segment.startDate = Date()
        segment.isCompressed = false
        segment.qualityLevel = TrackStorageConfig.QualityLevel.full.rawValue
        segment.originalPointCount = 0
        segment.compressionRatio = 1.0
        
        do {
            try context.save()
            print("🟢 Live-Segment gestartet für Trip: \(trip.name ?? "Unbenannt")")
        } catch {
            print("❌ Fehler beim Erstellen des Live-Segments: \(error)")
        }
        
        return segment
    }
    
    /// Fügt einen RoutePoint zum aktuellen Live-Segment hinzu
    func addPointToLiveSegment(_ point: RoutePoint, segment: TrackSegment) {
        point.trackSegment = segment
        segment.originalPointCount += 1
        
        // Update segment metadata
        updateSegmentMetadata(segment)
        
        // Prüfe ob Segment-Grenze erreicht
        if segment.originalPointCount >= TrackStorageConfig.segmentSizeThreshold {
            closeLiveSegment(segment)
        }
        
        do {
            try context.save()
        } catch {
            print("❌ Fehler beim Hinzufügen des Points zum Segment: \(error)")
        }
    }
    
    /// Beendet ein Live-Segment
    func closeLiveSegment(_ segment: TrackSegment) {
        segment.endDate = Date()
        segment.segmentType = SegmentStatus.recent.rawValue
        updateSegmentMetadata(segment)
        
        do {
            try context.save()
            print("🔴 Live-Segment beendet. \(segment.originalPointCount) Punkte aufgezeichnet")
            
            // Schedule compression für später
            scheduleSegmentCompression(segment)
        } catch {
            print("❌ Fehler beim Beenden des Live-Segments: \(error)")
        }
    }
    
    /// Komprimiert ein Segment sofort
    func compressSegment(_ segment: TrackSegment, qualityLevel: TrackStorageConfig.QualityLevel = .high) async -> Bool {
        guard let points = segment.originalPoints?.allObjects as? [RoutePoint],
              !points.isEmpty else {
            print("⚠️ Keine Punkte zum Komprimieren gefunden")
            return false
        }
        
        await MainActor.run {
            isCompressing = true
            compressionProgress = 0.0
        }
        
        let startTime = Date()
        
        // Analysiere und komprimiere
        let encodedData = encoder.encodeSegment(points)
        
        await MainActor.run {
            compressionProgress = 0.5
        }
        
        // Speichere komprimierte Daten
        if let encodedTrackData = encodedData {
            // Serialisiere EncodedTrackData zu Data
            do {
                let serializedData = try JSONEncoder().encode(encodedTrackData)
                segment.encodedData = serializedData
                segment.isCompressed = true
                segment.qualityLevel = qualityLevel.rawValue
                segment.segmentType = SegmentStatus.compressed.rawValue
                
                // Berechne Kompressionsrate - Realistische Schätzung der RoutePoint-Größe
                // RoutePoint: latitude(8) + longitude(8) + timestamp(8) + altitude(8) + speed(8) + overhead ≈ 50 bytes
                let estimatedRoutePointSize = 50
                let originalSize = points.count * estimatedRoutePointSize
                let compressionRatio = Double(serializedData.count) / Double(originalSize)
                segment.compressionRatio = compressionRatio
                
                await MainActor.run {
                    compressionProgress = 0.8
                }
                
                // Optional: Entferne Original-Punkte nach erfolgreicher Kompression
                if qualityLevel != .full {
                    removeOriginalPoints(from: segment, keepRatio: qualityLevel.retentionFactor)
                }
                
                try context.save()
                
                await MainActor.run {
                    compressionProgress = 1.0
                }
                
                let compressionTime = Date().timeIntervalSince(startTime)
                print("✅ Segment komprimiert: \(Int((1.0 - compressionRatio) * 100))% Speicherersparnis in \(compressionTime.formatted(.number.precision(.fractionLength(1))))s")
                
                await MainActor.run {
                    updateStorageStatistics()
                    isCompressing = false
                }
                
                return true
            } catch {
                print("❌ Fehler bei der Serialisierung der EncodedTrackData: \(error)")
            }
        }
        
        await MainActor.run {
            isCompressing = false
        }
        
        return false
    }
    
    /// Rekonstruiert Punkte aus komprimiertem Segment
    func reconstructPoints(from segment: TrackSegment) -> [CLLocationCoordinate2D]? {
        guard segment.isCompressed,
              let encodedData = segment.encodedData else {
            // Returniere Original-Punkte wenn nicht komprimiert
            if let points = segment.originalPoints?.allObjects as? [RoutePoint] {
                return points.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
                    .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            }
            return nil
        }
        
        return decoder.decodeSegment(data: encodedData, metadata: segment.metadata)
    }
    
    // MARK: - Background Processing
    
    private func setupBackgroundProcessing() {
        // Timer für periodische Kompression
        compressionTimer = Timer.scheduledTimer(withTimeInterval: TrackStorageConfig.backgroundCompressionInterval, repeats: true) { _ in
            Task {
                await self.performBackgroundCompression()
            }
        }
        
        // Background Task Registration
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.journiary.trackcompression", using: nil) { task in
            self.handleBackgroundCompressionTask(task as! BGProcessingTask)
        }
    }
    
    private func performBackgroundCompression() async {
        print("🔄 Starte Background-Kompression...")
        
        // Hole Segmente die komprimiert werden sollten
        let fetchRequest: NSFetchRequest<TrackSegment> = TrackSegment.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "segmentType == %@ AND isCompressed == NO", SegmentStatus.recent.rawValue)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: true)]
        
        do {
            let segments = try context.fetch(fetchRequest)
            let now = Date()
            
            for segment in segments {
                // Komprimiere Segmente die älter als 24h sind
                if let endDate = segment.endDate,
                   now.timeIntervalSince(endDate) > TrackStorageConfig.compressionDelayHours * 3600 {
                    
                    _ = await compressSegment(segment, qualityLevel: .high)
                }
            }
            
            print("✅ Background-Kompression abgeschlossen. \(segments.count) Segmente verarbeitet")
        } catch {
            print("❌ Fehler bei Background-Kompression: \(error)")
        }
    }
    
    private func handleBackgroundCompressionTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await performBackgroundCompression()
            task.setTaskCompleted(success: true)
            
            // Schedule next background task
            scheduleBackgroundCompression()
        }
    }
    
    private func scheduleBackgroundCompression() {
        let request = BGProcessingTaskRequest(identifier: "com.journiary.trackcompression")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: TrackStorageConfig.backgroundCompressionInterval)
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    // MARK: - Helper Methods
    
    private func updateSegmentMetadata(_ segment: TrackSegment) {
        guard let points = segment.originalPoints?.allObjects as? [RoutePoint],
              !points.isEmpty else { return }
        
        let sortedPoints = points.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        
        // Berechne Statistiken
        let speeds = sortedPoints.map { $0.speed }
        let averageSpeed = speeds.reduce(0, +) / Double(speeds.count)
        let maxSpeed = speeds.max() ?? 0
        
        var totalDistance: Double = 0
        for i in 1..<sortedPoints.count {
            let p1 = CLLocation(latitude: sortedPoints[i-1].latitude, longitude: sortedPoints[i-1].longitude)
            let p2 = CLLocation(latitude: sortedPoints[i].latitude, longitude: sortedPoints[i].longitude)
            totalDistance += p1.distance(from: p2)
        }
        
        segment.distance = totalDistance
        segment.averageSpeed = averageSpeed
        segment.maxSpeed = maxSpeed
        
        if segment.startDate == nil {
            segment.startDate = sortedPoints.first?.timestamp
        }
        if segment.endDate == nil {
            segment.endDate = sortedPoints.last?.timestamp
        }
    }
    
    private func removeOriginalPoints(from segment: TrackSegment, keepRatio: Double) {
        guard let points = segment.originalPoints?.allObjects as? [RoutePoint],
              keepRatio < 1.0 else { return }
        
        let sortedPoints = points.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        let keepCount = Int(Double(sortedPoints.count) * keepRatio)
        let step = sortedPoints.count / max(1, keepCount)
        
        // Behalte jeden n-ten Punkt + Start/Ende
        var pointsToKeep = Set<RoutePoint>()
        pointsToKeep.insert(sortedPoints.first!)
        pointsToKeep.insert(sortedPoints.last!)
        
        for i in stride(from: 0, to: sortedPoints.count, by: step) {
            pointsToKeep.insert(sortedPoints[i])
        }
        
        // Lösche alle anderen Punkte
        for point in sortedPoints {
            if !pointsToKeep.contains(point) {
                context.delete(point)
            }
        }
        
        print("🗑️ \(sortedPoints.count - pointsToKeep.count) Original-Punkte entfernt. \(pointsToKeep.count) behalten.")
    }
    
    private func scheduleSegmentCompression(_ segment: TrackSegment) {
        let segmentID = segment.objectID
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + TrackStorageConfig.compressionDelayHours * 3600) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Hole das Segment über die objectID neu
                if let segment = try? self.context.existingObject(with: segmentID) as? TrackSegment {
                    _ = await self.compressSegment(segment)
                }
            }
        }
    }
    
    private func loadStorageStatistics() {
        let fetchRequest: NSFetchRequest<TrackSegment> = TrackSegment.fetchRequest()
        
        do {
            let segments = try context.fetch(fetchRequest)
            
            var stats = StorageStatistics()
            stats.totalSegments = segments.count
            stats.compressedSegments = segments.filter { $0.isCompressed }.count
            
            for segment in segments {
                let estimatedRoutePointSize = 50 // bytes
                stats.originalDataSize += Int64(Int(segment.originalPointCount) * estimatedRoutePointSize)
                if let data = segment.encodedData {
                    stats.compressedDataSize += Int64(data.count)
                }
            }
            
            if stats.originalDataSize > 0 {
                stats.compressionRatio = Double(stats.compressedDataSize) / Double(stats.originalDataSize)
            }
            
            self.storageStatistics = stats
            
        } catch {
            print("❌ Fehler beim Laden der Storage-Statistiken: \(error)")
        }
    }
    
    private func updateStorageStatistics() {
        loadStorageStatistics()
    }
    
    // MARK: - Public Query Methods
    
    /// Gibt alle Segmente für eine Reise zurück
    func getSegments(for trip: Trip) -> [TrackSegment] {
        guard let segments = trip.trackSegments?.allObjects as? [TrackSegment] else { return [] }
        return segments.sorted { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
    }
    
    /// Gibt das aktuelle Live-Segment für eine Reise zurück
    func getLiveSegment(for trip: Trip) -> TrackSegment? {
        let segments = getSegments(for: trip)
        return segments.first { $0.segmentType == SegmentStatus.live.rawValue }
    }
    
    /// Gibt Segmente zurück, die für die Komprimierung geeignet sind
    func getCompressibleSegments(olderThan date: Date) -> [TrackSegment] {
        let fetchRequest: NSFetchRequest<TrackSegment> = TrackSegment.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompressed == NO AND endDate < %@", date as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: true)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("❌ Fehler beim Holen komprimierbarer Segmente: \(error)")
            return []
        }
    }
}

// MARK: - Adaptive Track Decoder

class AdaptiveTrackDecoder {
    func decodeSegment(data: Data, metadata: String?) -> [CLLocationCoordinate2D]? {
        do {
            // Dekodiere die EncodedTrackData
            let encodedTrackData = try JSONDecoder().decode(EncodedTrackData.self, from: data)
            
            switch encodedTrackData.method {
            case .polylineEncoding:
                return decodePolyline(data: encodedTrackData.data)
            case .hybridVectorPoints:
                return decodeHybridVectorPoints(data: encodedTrackData.data)
            case .optimizedPoints:
                return decodeOptimizedPoints(data: encodedTrackData.data)
            case .waypointBased:
                return decodeWaypointBased(data: encodedTrackData.data)
            case .segmentedPolyline:
                return decodeSegmentedPolyline(data: encodedTrackData.data)
            }
        } catch {
            print("❌ Fehler beim Dekodieren der Track-Daten: \(error)")
            return nil
        }
    }
    
    private func decodePolyline(data: Data) -> [CLLocationCoordinate2D]? {
        do {
            let extendedData = try JSONDecoder().decode(ExtendedPolylineData.self, from: data)
            return PolylineEncoder.decode(extendedData.polyline)
        } catch {
            print("❌ Fehler beim Dekodieren der Polyline: \(error)")
            return nil
        }
    }
    
    private func decodeHybridVectorPoints(data: Data) -> [CLLocationCoordinate2D]? {
        do {
            let hybridData = try JSONDecoder().decode(HybridEncodedData.self, from: data)
            var allCoordinates: [CLLocationCoordinate2D] = []
            
            for segment in hybridData.segments {
                switch segment {
                case .polyline(let polylineData):
                    let coords = PolylineEncoder.decode(polylineData.polyline)
                    allCoordinates.append(contentsOf: coords)
                case .points(let optimizedPoints):
                    let coords = optimizedPoints.map { 
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) 
                    }
                    allCoordinates.append(contentsOf: coords)
                }
            }
            
            return allCoordinates.isEmpty ? nil : allCoordinates
        } catch {
            print("❌ Fehler beim Dekodieren der Hybrid Vector Points: \(error)")
            return nil
        }
    }
    
    private func decodeOptimizedPoints(data: Data) -> [CLLocationCoordinate2D]? {
        do {
            let optimizedData = try JSONDecoder().decode(OptimizedPointsData.self, from: data)
            return optimizedData.points.map { 
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) 
            }
        } catch {
            print("❌ Fehler beim Dekodieren der Optimized Points: \(error)")
            return nil
        }
    }
    
    private func decodeWaypointBased(data: Data) -> [CLLocationCoordinate2D]? {
        do {
            let waypointData = try JSONDecoder().decode(WaypointBasedData.self, from: data)
            return waypointData.waypoints.map { $0.coordinate }
        } catch {
            print("❌ Fehler beim Dekodieren der Waypoint-Based Daten: \(error)")
            return nil
        }
    }
    
    private func decodeSegmentedPolyline(data: Data) -> [CLLocationCoordinate2D]? {
        do {
            let segmentedData = try JSONDecoder().decode(SegmentedPolylineData.self, from: data)
            var allCoordinates: [CLLocationCoordinate2D] = []
            
            for segment in segmentedData.polylineSegments {
                let coords = PolylineEncoder.decode(segment.polyline.polyline)
                allCoordinates.append(contentsOf: coords)
            }
            
            return allCoordinates.isEmpty ? nil : allCoordinates
        } catch {
            print("❌ Fehler beim Dekodieren der Segmented Polyline: \(error)")
            return nil
        }
    }
} 