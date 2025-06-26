//
//  MapCacheManager.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import Foundation
import MapKit
import SwiftUI
import CoreData

@MainActor
class MapCacheManager: ObservableObject, @unchecked Sendable {
    static let shared = MapCacheManager()
    
    @Published var isDownloadingMaps = false
    @Published var downloadProgress: Double = 0.0
    @Published var cachedRegions: [CachedRegion] = []
    @Published var totalCacheSize: Int64 = 0
    @Published var autoDownloadEnabled = true
    @Published var currentlyViewedRegion: MKCoordinateRegion?
    
    private let fileManager = FileManager.default
    nonisolated private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500 MB maximale Cache-Größe
    private let autoDownloadThreshold: Double = 2.0 // Sekunden bevor Auto-Download startet
    
    // Auto-Download Management
    private var autoDownloadTimer: Timer?
    private var viewedRegions: Set<String> = []
    private var pendingRegions: [(region: MKCoordinateRegion, priority: Int)] = []
    private var isAutoDownloading = false
    
    // Cache-Optimierung
    private let defaultZoomLevels = [10, 11, 12, 13, 14, 15] // Optimale Balance zwischen Qualität und Speicher
    private let minRegionSize = 0.005 // Minimale Region für Caching
    private let maxRegionSize = 0.2   // Maximale Region für Auto-Caching
    
    // Thread-safe Cache-Access
    private let cacheQueue = DispatchQueue(label: "mapCache", qos: .utility, attributes: .concurrent)
    
    private init() {
        // Cache-Verzeichnis erstellen
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("MapCache")
        
        createCacheDirectoryIfNeeded()
        loadCachedRegions()
        calculateTotalCacheSize()
        loadSettings()
        
        print("✅ MapCacheManager initialisiert - Auto-Download: \(autoDownloadEnabled)")
    }
    
    // MARK: - Auto-Download Management
    
    /// Registriert eine betrachtete Region für potentielles Auto-Caching
    @MainActor
    func registerViewedRegion(_ region: MKCoordinateRegion) {
        // Prüfe ob Region für Auto-Download geeignet ist
        guard autoDownloadEnabled,
              !isRegionTooSmallForCaching(region),
              !isRegionTooLargeForCaching(region),
              !isRegionAlreadyCached(region) else {
            return
        }
        
        // Region-Hash für Identifizierung
        let regionHash = getRegionHash(region)
        
        // Verhindere doppelte Downloads
        guard !viewedRegions.contains(regionHash) else { return }
        
        currentlyViewedRegion = region
        
        // Timer zurücksetzen
        autoDownloadTimer?.invalidate()
        autoDownloadTimer = Timer.scheduledTimer(withTimeInterval: autoDownloadThreshold, repeats: false) { @Sendable [weak self] _ in
            Task { @MainActor in
                await self?.startAutoDownloadForRegion(region, priority: 1)
            }
        }
    }
    
    /// Startet automatischen Download für eine Region
    private func startAutoDownloadForRegion(_ region: MKCoordinateRegion, priority: Int) async {
        let regionHash = getRegionHash(region)
        
        // Verhindere doppelte Downloads
        guard !viewedRegions.contains(regionHash),
              !isAutoDownloading else {
            return
        }
        
        viewedRegions.insert(regionHash)
        
        print("🔄 Auto-Download für Region gestartet: \(regionHash)")
        
        // Optimierte Region für Caching berechnen
        let optimizedRegion = optimizeRegionForCaching(region)
        
        await downloadMapsForRegion(
            region: optimizedRegion,
            name: "Auto-Cache \(getCurrentLocationName(optimizedRegion.center))",
            zoomLevels: getOptimalZoomLevels(for: optimizedRegion),
            isAutoDownload: true
        )
    }
    
    /// Optimiert eine Region für effizientes Caching
    private func optimizeRegionForCaching(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
        // Runde Koordinaten für bessere Cache-Effizienz
        let roundedLat = round(region.center.latitude * 100) / 100
        let roundedLon = round(region.center.longitude * 100) / 100
        
        // Optimiere Span für Standard-Tile-Größen
        let optimizedLatDelta = max(min(region.span.latitudeDelta, maxRegionSize), minRegionSize)
        let optimizedLonDelta = max(min(region.span.longitudeDelta, maxRegionSize), minRegionSize)
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: roundedLat, longitude: roundedLon),
            span: MKCoordinateSpan(latitudeDelta: optimizedLatDelta, longitudeDelta: optimizedLonDelta)
        )
    }
    
    /// Bestimmt optimale Zoom-Level basierend auf Region-Größe
    private func getOptimalZoomLevels(for region: MKCoordinateRegion) -> [Int] {
        let regionSize = max(region.span.latitudeDelta, region.span.longitudeDelta)
        
        if regionSize < 0.01 {
            // Sehr kleine Region - hohe Detail-Level
            return [12, 13, 14, 15, 16]
        } else if regionSize < 0.05 {
            // Mittlere Region - Standard-Level
            return [10, 11, 12, 13, 14, 15]
        } else {
            // Große Region - niedrigere Detail-Level
            return [8, 9, 10, 11, 12, 13]
        }
    }
    
    /// Prüft ob Region bereits gecacht ist
    private func isRegionAlreadyCached(_ region: MKCoordinateRegion) -> Bool {
        return cachedRegions.contains { cachedRegion in
            let distance = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
                .distance(from: CLLocation(latitude: cachedRegion.centerLatitude, longitude: cachedRegion.centerLongitude))
            
            // Wenn der Mittelpunkt weniger als 1km entfernt ist und die Größe ähnlich
            return distance < 1000 &&
                   abs(region.span.latitudeDelta - cachedRegion.latitudeDelta) < 0.01 &&
                   abs(region.span.longitudeDelta - cachedRegion.longitudeDelta) < 0.01
        }
    }
    
    /// Generiert Hash für Region-Identifizierung
    private func getRegionHash(_ region: MKCoordinateRegion) -> String {
        let lat = String(format: "%.3f", region.center.latitude)
        let lon = String(format: "%.3f", region.center.longitude)
        let span = String(format: "%.3f", max(region.span.latitudeDelta, region.span.longitudeDelta))
        return "\(lat)_\(lon)_\(span)"
    }
    
    /// Prüft ob Region zu klein für Caching ist
    private func isRegionTooSmallForCaching(_ region: MKCoordinateRegion) -> Bool {
        return max(region.span.latitudeDelta, region.span.longitudeDelta) < minRegionSize
    }
    
    /// Prüft ob Region zu groß für Auto-Caching ist
    private func isRegionTooLargeForCaching(_ region: MKCoordinateRegion) -> Bool {
        return max(region.span.latitudeDelta, region.span.longitudeDelta) > maxRegionSize
    }
    
    /// Versucht Standortname für Region zu ermitteln
    private func getCurrentLocationName(_ coordinate: CLLocationCoordinate2D) -> String {
        // Vereinfachte Implementierung - könnte erweitert werden mit Reverse Geocoding
        return "Lat: \(String(format: "%.2f", coordinate.latitude)), Lon: \(String(format: "%.2f", coordinate.longitude))"
    }
    
    // MARK: - Cache-Verwaltung
    
    /// Erstellt das Cache-Verzeichnis falls es nicht existiert
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Lädt die gespeicherten Cache-Regionen
    private func loadCachedRegions() {
        cacheQueue.async { @Sendable [weak self] in
            guard let self = self else { return }
            
            let regionsFile = self.cacheDirectory.appendingPathComponent("cached_regions.json")
            
            guard let data = try? Data(contentsOf: regionsFile),
                  let regions = try? JSONDecoder().decode([CachedRegion].self, from: data) else {
                DispatchQueue.main.async {
                    self.cachedRegions = []
                }
                return
            }
            
            DispatchQueue.main.async {
                self.cachedRegions = regions
            }
        }
    }
    
    /// Speichert die Cache-Regionen
    private func saveCachedRegions() {
        let regionsToSave = cachedRegions // Copy to local variable
        cacheQueue.async { @Sendable [weak self] in
            guard let self = self else { return }
            
            let regionsFile = self.cacheDirectory.appendingPathComponent("cached_regions.json")
            
            if let data = try? JSONEncoder().encode(regionsToSave) {
                try? data.write(to: regionsFile)
            }
        }
    }
    
    /// Lädt und speichert Einstellungen
    private func loadSettings() {
        autoDownloadEnabled = UserDefaults.standard.bool(forKey: "map_auto_download_enabled")
        if UserDefaults.standard.object(forKey: "map_auto_download_enabled") == nil {
            // Default-Wert beim ersten Start
            autoDownloadEnabled = true
            UserDefaults.standard.set(true, forKey: "map_auto_download_enabled")
        }
    }
    
    @MainActor
    func saveSettings() {
        UserDefaults.standard.set(autoDownloadEnabled, forKey: "map_auto_download_enabled")
    }
    
    /// Berechnet die Gesamtgröße des Caches
    private func calculateTotalCacheSize() {
        let cacheDir = cacheDirectory
        cacheQueue.async { @Sendable [weak self] in
            guard let self = self else { return }
            
            var totalSize: Int64 = 0
            let fileManager = FileManager.default
            
            if let enumerator = fileManager.enumerator(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.totalCacheSize = totalSize
            }
        }
    }
    
    // MARK: - Tile-Management für lokalen Cache
    
    /// Prüft ob eine Tile im lokalen Cache verfügbar ist
    nonisolated func isTileCached(x: Int, y: Int, z: Int) -> Bool {
        let tilePath = getTilePath(x: x, y: y, z: z)
        return FileManager.default.fileExists(atPath: tilePath.path)
    }
    
    /// Lädt eine Tile aus dem lokalen Cache
    nonisolated func getCachedTile(x: Int, y: Int, z: Int) -> Data? {
        let tilePath = getTilePath(x: x, y: y, z: z)
        return try? Data(contentsOf: tilePath)
    }
    
    /// Speichert eine Tile im lokalen Cache
    nonisolated func cacheTile(data: Data, x: Int, y: Int, z: Int) {
        let tilePath = getTilePath(x: x, y: y, z: z)
        
        cacheQueue.async { @Sendable in
            let fileManager = FileManager.default
            
            // Verzeichnis erstellen falls nötig
            try? fileManager.createDirectory(at: tilePath.deletingLastPathComponent(), withIntermediateDirectories: true)
            
            // Tile speichern
            try? data.write(to: tilePath)
        }
    }
    
    // MARK: - Karten-Download
    
    /// Lädt Karten für eine bestimmte Region herunter
    func downloadMapsForRegion(
        region: MKCoordinateRegion,
        name: String,
        zoomLevels: [Int] = [10, 11, 12, 13, 14, 15],
        isAutoDownload: Bool = false
    ) async {
        
        // Verhindere parallele Downloads
        await MainActor.run {
            guard !isDownloadingMaps else {
                print("⚠️ Download bereits aktiv - Region übersprungen")
                return
            }
            
            isDownloadingMaps = true
            isAutoDownloading = isAutoDownload
            downloadProgress = 0.0
        }
        
        let cachedRegion = CachedRegion(
            id: UUID().uuidString,
            name: name,
            centerLatitude: region.center.latitude,
            centerLongitude: region.center.longitude,
            latitudeDelta: region.span.latitudeDelta,
            longitudeDelta: region.span.longitudeDelta,
            zoomLevels: zoomLevels,
            downloadDate: Date(),
            tileCount: 0,
            sizeInBytes: 0,
            isAutoDownloaded: isAutoDownload
        )
        
        do {
            let tileCount = try await downloadTilesForRegion(region: region, zoomLevels: zoomLevels, cachedRegion: cachedRegion)
            
            cachedRegion.tileCount = tileCount
            cachedRegion.sizeInBytes = calculateRegionSize(cachedRegion)
            
            await MainActor.run {
                cachedRegions.append(cachedRegion)
                saveCachedRegions()
                calculateTotalCacheSize()
                
                // Cache-Cleanup falls nötig
                cleanupCacheIfNeeded()
            }
            
            print("✅ Karten-Download abgeschlossen für Region '\(name)': \(tileCount) Kacheln (\(formatFileSize(cachedRegion.sizeInBytes)))")
        } catch {
            print("❌ Fehler beim Download der Karten: \(error)")
        }
        
        await MainActor.run {
            isDownloadingMaps = false
            isAutoDownloading = false
        }
    }
    
    /// Lädt Karten für eine aktive Reise herunter
    func downloadMapsForTrip(_ trip: Trip) async {
        guard let routePoints = trip.routePoints?.allObjects as? [RoutePoint],
              !routePoints.isEmpty else {
            print("⚠️ Keine Routenpunkte für Reise gefunden")
            return
        }
        
        // Bounding Box der Route berechnen
        let coordinates = routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let boundingBox = calculateBoundingBox(for: coordinates)
        
        let region = MKCoordinateRegion(
            center: boundingBox.center,
            span: MKCoordinateSpan(
                latitudeDelta: boundingBox.latitudeDelta * 1.2, // 20% Puffer
                longitudeDelta: boundingBox.longitudeDelta * 1.2
            )
        )
        
        await downloadMapsForRegion(
            region: region,
            name: trip.name ?? "Reise vom \(trip.startDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unbekannt")"
        )
    }
    
    /// Lädt einzelne Kartenkacheln herunter mit verbesserter Performance
    private func downloadTilesForRegion(
        region: MKCoordinateRegion,
        zoomLevels: [Int],
        cachedRegion: CachedRegion
    ) async throws -> Int {
        
        // Thread-sichere Zähler
        let totalTiles = zoomLevels.reduce(0) { total, zoomLevel in
            let tiles = calculateTileCount(for: region, zoomLevel: zoomLevel)
            return total + tiles.count
        }
        
        print("🔄 Starte Download von \(totalTiles) Kartenkacheln...")
        
        // Atomic counter für Thread-Sicherheit
        let downloadCounter = DownloadCounter()
        
        // Verwende URLSession mit konfigurierten Limits
        let session = URLSession(configuration: .default)
        
        // Kacheln für jeden Zoom-Level herunterladen
        for zoomLevel in zoomLevels {
            let tileCoordinates = calculateTileCoordinates(for: region, zoomLevel: zoomLevel)
            
            // Batch-weise Downloads für bessere Performance
            let batchSize = 5
            for batch in tileCoordinates.chunked(into: batchSize) {
                await withTaskGroup(of: Void.self) { group in
                    for tileCoord in batch {
                        group.addTask {
                            await self.downloadSingleTile(
                                x: tileCoord.x,
                                y: tileCoord.y,
                                z: zoomLevel,
                                session: session
                            )
                            
                            // Thread-sicher den Zähler erhöhen
                            let currentCount = await downloadCounter.increment()
                            let progress = Double(currentCount) / Double(totalTiles)
                            
                            await MainActor.run {
                                self.downloadProgress = progress
                            }
                        }
                    }
                }
                
                // Kleine Pause zwischen Batches um Server nicht zu überlasten
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 Sekunden
            }
        }
        
        return totalTiles
    }
    
    /// Lädt eine einzelne Tile herunter
    private func downloadSingleTile(x: Int, y: Int, z: Int, session: URLSession) async {
        let tilePath = getTilePath(x: x, y: y, z: z)
        let fileManager = FileManager.default
        
        // Prüfen ob Kachel bereits existiert
        guard !fileManager.fileExists(atPath: tilePath.path) else { return }
        
        do {
            // OpenStreetMap Tile-Server verwenden (kostenfrei und legal)
            let tileURL = URL(string: "https://tile.openstreetmap.org/\(z)/\(x)/\(y).png")!
            
            var request = URLRequest(url: tileURL)
            request.setValue("Journiary iOS App", forHTTPHeaderField: "User-Agent") // Höflicher User-Agent
            request.timeoutInterval = 10.0
            
            let (data, response) = try await session.data(for: request)
            
            // Prüfe HTTP Response
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                
                // Verzeichnis erstellen falls nötig
                try fileManager.createDirectory(at: tilePath.deletingLastPathComponent(), withIntermediateDirectories: true)
                
                // Kachel speichern
                try data.write(to: tilePath)
            }
            
        } catch {
            // Stiller Fehler für einzelne Tiles - verhindert Spam
            // print("⚠️ Fehler beim Download der Kachel \(x),\(y),\(z): \(error)")
        }
    }
    
    // MARK: - Hilfsfunktionen
    
    /// Berechnet die Bounding Box für Koordinaten
    private func calculateBoundingBox(for coordinates: [CLLocationCoordinate2D]) -> (center: CLLocationCoordinate2D, latitudeDelta: Double, longitudeDelta: Double) {
        guard !coordinates.isEmpty else {
            return (CLLocationCoordinate2D(latitude: 0, longitude: 0), 0.1, 0.1)
        }
        
        let minLat = coordinates.map(\.latitude).min()!
        let maxLat = coordinates.map(\.latitude).max()!
        let minLon = coordinates.map(\.longitude).min()!
        let maxLon = coordinates.map(\.longitude).max()!
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        return (center, maxLat - minLat, maxLon - minLon)
    }
    
    /// Berechnet Tile-Koordinaten für eine Region
    private func calculateTileCoordinates(for region: MKCoordinateRegion, zoomLevel: Int) -> [(x: Int, y: Int)] {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        
        let minTileX = Int(floor((minLon + 180.0) / 360.0 * pow(2.0, Double(zoomLevel))))
        let maxTileX = Int(floor((maxLon + 180.0) / 360.0 * pow(2.0, Double(zoomLevel))))
        let minTileY = Int(floor((1.0 - log(tan(minLat * Double.pi / 180.0) + 1.0 / cos(minLat * Double.pi / 180.0)) / Double.pi) / 2.0 * pow(2.0, Double(zoomLevel))))
        let maxTileY = Int(floor((1.0 - log(tan(maxLat * Double.pi / 180.0) + 1.0 / cos(maxLat * Double.pi / 180.0)) / Double.pi) / 2.0 * pow(2.0, Double(zoomLevel))))
        
        var tiles: [(x: Int, y: Int)] = []
        
        for x in minTileX...maxTileX {
            for y in maxTileY...minTileY {
                tiles.append((x: x, y: y))
            }
        }
        
        return tiles
    }
    
    /// Berechnet Anzahl der Tiles für eine Region
    private func calculateTileCount(for region: MKCoordinateRegion, zoomLevel: Int) -> [(x: Int, y: Int)] {
        return calculateTileCoordinates(for: region, zoomLevel: zoomLevel)
    }
    
    /// Gibt den Pfad für eine Kartenkachel zurück
    nonisolated func getTilePath(x: Int, y: Int, z: Int) -> URL {
        return cacheDirectory
            .appendingPathComponent("\(z)")
            .appendingPathComponent("\(x)")
            .appendingPathComponent("\(y).png")
    }
    
    /// Berechnet die Größe einer gecachten Region
    private func calculateRegionSize(_ region: CachedRegion) -> Int64 {
        var totalSize: Int64 = 0
        
        for zoomLevel in region.zoomLevels {
            let zoomDir = cacheDirectory.appendingPathComponent("\(zoomLevel)")
            
            if let enumerator = fileManager.enumerator(at: zoomDir, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
        }
        
        return totalSize
    }
    
    // MARK: - Cache-Verwaltung
    
    /// Löscht eine gecachte Region
    @MainActor
    func deleteCachedRegion(_ region: CachedRegion) {
        // Kacheln der Region löschen (vereinfacht - löscht alle Kacheln der Zoom-Level)
        for zoomLevel in region.zoomLevels {
            let zoomDir = cacheDirectory.appendingPathComponent("\(zoomLevel)")
            try? fileManager.removeItem(at: zoomDir)
        }
        
        // Region aus Liste entfernen
        cachedRegions.removeAll { $0.id == region.id }
        saveCachedRegions()
        calculateTotalCacheSize()
    }
    
    /// Löscht den gesamten Cache
    @MainActor
    func clearAllCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        createCacheDirectoryIfNeeded()
        
        cachedRegions.removeAll()
        saveCachedRegions()
        totalCacheSize = 0
        viewedRegions.removeAll()
        
        // Timer stoppen
        autoDownloadTimer?.invalidate()
        autoDownloadTimer = nil
    }
    
    /// Prüft ob der Cache zu groß wird und löscht alte Einträge
    @MainActor
    func cleanupCacheIfNeeded() {
        guard totalCacheSize > maxCacheSize else { return }
        
        print("🔄 Cache-Cleanup gestartet - Aktuelle Größe: \(formatFileSize(totalCacheSize))")
        
        // Sortiere nach Datum (älteste zuerst) und bevorzuge Auto-Downloads für Löschung
        let sortedRegions = cachedRegions.sorted { left, right in
            // Auto-Downloads haben niedrigere Priorität
            if left.isAutoDownloaded != right.isAutoDownloaded {
                return left.isAutoDownloaded && !right.isAutoDownloaded
            }
            return left.downloadDate < right.downloadDate
        }
        
        // Lösche älteste Regionen bis unter dem Limit
        for region in sortedRegions {
            if totalCacheSize <= maxCacheSize * 3/4 { // Auf 75% reduzieren
                break
            }
            deleteCachedRegion(region)
            print("🗑️ Gelöschte Region: \(region.name)")
        }
        
        print("✅ Cache-Cleanup abgeschlossen - Neue Größe: \(formatFileSize(totalCacheSize))")
    }
    
    /// Formatiert Dateigröße in lesbares Format
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Lädt automatisch Karten für alle aktiven Reisen mit GPS-Daten herunter
    func downloadMapsForActiveTrips(context: NSManagedObjectContext) async {
        let fetchRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isActive == true AND gpsTrackingEnabled == true")
        
        do {
            let activeTrips = try context.fetch(fetchRequest)
            
            for trip in activeTrips {
                if let routePoints = trip.routePoints?.allObjects as? [RoutePoint],
                   !routePoints.isEmpty {
                    
                    // Prüfe ob bereits eine gecachte Region für diese Reise existiert
                    let existingRegion = await MainActor.run {
                        cachedRegions.first { region in
                            region.name.contains(trip.name ?? "")
                        }
                    }
                    
                    if existingRegion == nil {
                        print("🔄 Lade Karten für aktive Reise: \(trip.name ?? "Unbenannt")")
                        await downloadMapsForTrip(trip)
                    } else {
                        print("✅ Karten für Reise '\(trip.name ?? "Unbenannt")' bereits gecacht")
                    }
                }
            }
        } catch {
            print("❌ Fehler beim Laden aktiver Reisen: \(error)")
        }
    }
    
    /// Vorschläge für Regionen basierend auf besuchten Orten
    func getSuggestedRegions(from memories: [Memory]) -> [CachedRegion] {
        var suggestedRegions: [CachedRegion] = []
        
        // Gruppiere Memories nach Städten/Ländern
        let groupedMemories = Dictionary(grouping: memories) { memory in
            memory.locationName?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "Unbekannt"
        }
        
        for (locationName, locationMemories) in groupedMemories {
            if locationMemories.count >= 3 { // Mindestens 3 Erinnerungen pro Ort
                let coordinates = locationMemories.compactMap { memory -> CLLocationCoordinate2D? in
                    guard memory.latitude != 0 && memory.longitude != 0 else { return nil }
                    return CLLocationCoordinate2D(latitude: memory.latitude, longitude: memory.longitude)
                }
                
                if !coordinates.isEmpty {
                    let boundingBox = calculateBoundingBox(for: coordinates)
                    
                    let region = MKCoordinateRegion(
                        center: boundingBox.center,
                        span: MKCoordinateSpan(
                            latitudeDelta: max(boundingBox.latitudeDelta * 1.5, 0.01),
                            longitudeDelta: max(boundingBox.longitudeDelta * 1.5, 0.01)
                        )
                    )
                    
                    let suggestedRegion = CachedRegion(
                        id: UUID().uuidString,
                        name: "Vorschlag: \(locationName)",
                        centerLatitude: region.center.latitude,
                        centerLongitude: region.center.longitude,
                        latitudeDelta: region.span.latitudeDelta,
                        longitudeDelta: region.span.longitudeDelta,
                        zoomLevels: [10, 11, 12, 13, 14],
                        downloadDate: Date(),
                        tileCount: 0,
                        sizeInBytes: 0,
                        isAutoDownloaded: false
                    )
                    
                    suggestedRegions.append(suggestedRegion)
                }
            }
        }
        
        return suggestedRegions
    }
    
    // MARK: - Performance-Helfer
    
    /// Stoppt alle laufenden Auto-Downloads
    @MainActor
    func pauseAutoDownload() {
        autoDownloadTimer?.invalidate()
        autoDownloadTimer = nil
        print("⏸️ Auto-Download pausiert")
    }
    
    /// Setzt Auto-Download-Status zurück
    @MainActor
    func resetAutoDownload() {
        viewedRegions.removeAll()
        pendingRegions.removeAll()
        autoDownloadTimer?.invalidate()
        autoDownloadTimer = nil
        print("🔄 Auto-Download zurückgesetzt")
    }
    
    // MARK: - Thread-sicherer Download-Counter
    
    private actor DownloadCounter {
        private var count = 0
        
        func increment() -> Int {
            count += 1
            return count
        }
        
        func getValue() -> Int {
            return count
        }
    }
}

// MARK: - Datenmodelle

class CachedRegion: ObservableObject, Codable, Identifiable, @unchecked Sendable {
    let id: String
    let name: String
    let centerLatitude: Double
    let centerLongitude: Double
    let latitudeDelta: Double
    let longitudeDelta: Double
    let zoomLevels: [Int]
    let downloadDate: Date
    var tileCount: Int
    var sizeInBytes: Int64
    let isAutoDownloaded: Bool
    
    init(id: String, name: String, centerLatitude: Double, centerLongitude: Double, 
         latitudeDelta: Double, longitudeDelta: Double, zoomLevels: [Int], 
         downloadDate: Date, tileCount: Int, sizeInBytes: Int64, isAutoDownloaded: Bool = false) {
        self.id = id
        self.name = name
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
        self.zoomLevels = zoomLevels
        self.downloadDate = downloadDate
        self.tileCount = tileCount
        self.sizeInBytes = sizeInBytes
        self.isAutoDownloaded = isAutoDownloaded
    }
    
    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

// MARK: - Erweiterungen

extension Array {
    /// Teilt ein Array in Chunks der angegebenen Größe
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
} 