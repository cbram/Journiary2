import XCTest
import CoreData
import CoreLocation
@testable import Journiary

@MainActor
class HybridStorageTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    var storageManager: TrackStorageManager!
    var mockGPSData: [MockGPSPoint]!
    
    override func setUpWithError() throws {
        // In-Memory Core Data Stack für Tests
        let container = NSPersistentContainer(name: "Journiary")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        context = container.viewContext
        storageManager = TrackStorageManager(context: context)
        
        // Mock GPS-Daten basierend auf GPX-Analyse laden
        mockGPSData = loadMockGPSData()
    }
    
    override func tearDownWithError() throws {
        context = nil
        storageManager = nil
        mockGPSData = nil
    }
    
    // MARK: - Mock Data Generation
    
    struct MockGPSPoint {
        let coordinate: CLLocationCoordinate2D
        let timestamp: Date
        let speed: Double // km/h
        let altitude: Double
        let scenario: GPSScenario
    }
    
    enum GPSScenario {
        case highway       // Autobahn (>80 km/h, gerade)
        case cityTraffic   // Stadtverkehr (20-50 km/h, viele Kurven)
        case walking       // Zu Fuß (<10 km/h, unregelmäßig)
        case rural         // Landstraße (50-80 km/h, mäßige Kurven)
        case pause         // Stillstand (0 km/h)
    }
    
    private func loadMockGPSData() -> [MockGPSPoint] {
        var points: [MockGPSPoint] = []
        let baseDate = Date()
        
        // Basierend auf GPX-Analyse: 8.129 Punkte, ~3.700 km
        // Verschiedene Szenarien simulieren
        
        // 1. Highway-Segment (1000 Punkte)
        points.append(contentsOf: generateHighwaySegment(
            startCoord: CLLocationCoordinate2D(latitude: 43.0, longitude: 1.0),
            pointCount: 1000,
            baseTime: baseDate
        ))
        
        // 2. Stadtverkehr-Segment (800 Punkte)
        points.append(contentsOf: generateCitySegment(
            startCoord: CLLocationCoordinate2D(latitude: 43.1, longitude: 1.1),
            pointCount: 800,
            baseTime: baseDate.addingTimeInterval(3600) // 1h später
        ))
        
        // 3. Wandern-Segment (500 Punkte)
        points.append(contentsOf: generateWalkingSegment(
            startCoord: CLLocationCoordinate2D(latitude: 43.2, longitude: 1.2),
            pointCount: 500,
            baseTime: baseDate.addingTimeInterval(7200) // 2h später
        ))
        
        // 4. Landstraße-Segment (600 Punkte)
        points.append(contentsOf: generateRuralSegment(
            startCoord: CLLocationCoordinate2D(latitude: 43.3, longitude: 1.3),
            pointCount: 600,
            baseTime: baseDate.addingTimeInterval(10800) // 3h später
        ))
        
        // 5. Pause-Segment (100 Punkte - Stillstand)
        points.append(contentsOf: generatePauseSegment(
            coord: CLLocationCoordinate2D(latitude: 43.4, longitude: 1.4),
            pointCount: 100,
            baseTime: baseDate.addingTimeInterval(14400) // 4h später
        ))
        
        return points
    }
    
    private func generateHighwaySegment(startCoord: CLLocationCoordinate2D, pointCount: Int, baseTime: Date) -> [MockGPSPoint] {
        var points: [MockGPSPoint] = []
        
        for i in 0..<pointCount {
            let progress = Double(i) / Double(pointCount)
            let time = baseTime.addingTimeInterval(Double(i) * 30) // 30s Intervalle
            
            // Gerade Strecke simulieren (geringe Koordinatenänderung)
            let coord = CLLocationCoordinate2D(
                latitude: startCoord.latitude + progress * 0.5, // ~55km Strecke
                longitude: startCoord.longitude + progress * 0.1 + sin(progress * 2) * 0.001 // Leichte Kurven
            )
            
            // Highway-typische Geschwindigkeiten (80-130 km/h)
            let speed = 80 + sin(progress * 4) * 25 + Double.random(in: -5...5)
            
            points.append(MockGPSPoint(
                coordinate: coord,
                timestamp: time,
                speed: speed,
                altitude: 200 + sin(progress * 6) * 50, // Leichte Höhenänderungen
                scenario: .highway
            ))
        }
        
        return points
    }
    
    private func generateCitySegment(startCoord: CLLocationCoordinate2D, pointCount: Int, baseTime: Date) -> [MockGPSPoint] {
        var points: [MockGPSPoint] = []
        
        for i in 0..<pointCount {
            let progress = Double(i) / Double(pointCount)
            let time = baseTime.addingTimeInterval(Double(i) * 20) // 20s Intervalle
            
            // Stadtverkehr: viele Richtungsänderungen
            let coord = CLLocationCoordinate2D(
                latitude: startCoord.latitude + sin(progress * 20) * 0.01 + progress * 0.1,
                longitude: startCoord.longitude + cos(progress * 15) * 0.015 + progress * 0.05
            )
            
            // Stadt-typische Geschwindigkeiten (0-60 km/h, viele Stopps)
            let baseSpeed = 30.0
            let stopFactor = sin(progress * 25) > 0.7 ? 0.0 : 1.0 // Ampeln/Stopps
            let speed = baseSpeed * stopFactor + Double.random(in: -10...20)
            
            points.append(MockGPSPoint(
                coordinate: coord,
                timestamp: time,
                speed: max(0, speed),
                altitude: 100 + Double.random(in: -5...5),
                scenario: .cityTraffic
            ))
        }
        
        return points
    }
    
    private func generateWalkingSegment(startCoord: CLLocationCoordinate2D, pointCount: Int, baseTime: Date) -> [MockGPSPoint] {
        var points: [MockGPSPoint] = []
        
        for i in 0..<pointCount {
            let progress = Double(i) / Double(pointCount)
            let time = baseTime.addingTimeInterval(Double(i) * 60) // 60s Intervalle
            
            // Wandern: unregelmäßige Bewegung
            let coord = CLLocationCoordinate2D(
                latitude: startCoord.latitude + sin(progress * 30) * 0.002 + progress * 0.02,
                longitude: startCoord.longitude + cos(progress * 35) * 0.003 + progress * 0.015
            )
            
            // Wandern-typische Geschwindigkeiten (2-8 km/h)
            let speed = 4 + sin(progress * 10) * 2 + Double.random(in: -1...1)
            
            points.append(MockGPSPoint(
                coordinate: coord,
                timestamp: time,
                speed: max(0, speed),
                altitude: 500 + sin(progress * 8) * 100, // Bergauf/bergab
                scenario: .walking
            ))
        }
        
        return points
    }
    
    private func generateRuralSegment(startCoord: CLLocationCoordinate2D, pointCount: Int, baseTime: Date) -> [MockGPSPoint] {
        var points: [MockGPSPoint] = []
        
        for i in 0..<pointCount {
            let progress = Double(i) / Double(pointCount)
            let time = baseTime.addingTimeInterval(Double(i) * 25) // 25s Intervalle
            
            // Landstraße: moderate Kurven
            let coord = CLLocationCoordinate2D(
                latitude: startCoord.latitude + sin(progress * 8) * 0.005 + progress * 0.3,
                longitude: startCoord.longitude + cos(progress * 6) * 0.008 + progress * 0.2
            )
            
            // Landstraße-typische Geschwindigkeiten (40-80 km/h)
            let speed = 60 + sin(progress * 12) * 15 + Double.random(in: -5...5)
            
            points.append(MockGPSPoint(
                coordinate: coord,
                timestamp: time,
                speed: max(20, speed),
                altitude: 300 + sin(progress * 4) * 80,
                scenario: .rural
            ))
        }
        
        return points
    }
    
    private func generatePauseSegment(coord: CLLocationCoordinate2D, pointCount: Int, baseTime: Date) -> [MockGPSPoint] {
        var points: [MockGPSPoint] = []
        
        for i in 0..<pointCount {
            let time = baseTime.addingTimeInterval(Double(i) * 30) // 30s Intervalle
            
            // Stillstand mit GPS-Rauschen
            let noisyCoord = CLLocationCoordinate2D(
                latitude: coord.latitude + Double.random(in: -0.0001...0.0001),
                longitude: coord.longitude + Double.random(in: -0.0001...0.0001)
            )
            
            points.append(MockGPSPoint(
                coordinate: noisyCoord,
                timestamp: time,
                speed: 0,
                altitude: 150 + Double.random(in: -2...2),
                scenario: .pause
            ))
        }
        
        return points
    }
    
    // MARK: - Core Tests
    
    func testHybridStorageCompressionEfficiency() throws {
        // Test: Verschiedene Szenarien und deren Kompressionsraten
        let scenarios: [GPSScenario] = [.highway, .cityTraffic, .walking, .rural, .pause]
        
        for scenario in scenarios {
            let points = mockGPSData.filter { $0.scenario == scenario }
            let routePoints = convertToRoutePoints(points)
            
            // Live-Segment erstellen
            let trip = createTestTrip()
            let segment = storageManager.startLiveSegment(for: trip)
            
            // Punkte hinzufügen
            for point in routePoints {
                storageManager.addPointToLiveSegment(point, segment: segment)
            }
            
            // Segment schließen und komprimieren
            storageManager.closeLiveSegment(segment)
            
            let expectation = XCTestExpectation(description: "Komprimierung für \(scenario)")
            
            Task {
                let success = await storageManager.compressSegment(segment)
                XCTAssertTrue(success, "Komprimierung sollte erfolgreich sein")
                
                // Kompressionsrate prüfen
                let compressionRatio = segment.compressionRatio
                
                switch scenario {
                case .highway:
                    XCTAssertLessThan(compressionRatio, 0.65, "Highway sollte >35% Kompression erreichen")
                case .cityTraffic:
                    XCTAssertLessThan(compressionRatio, 0.75, "Stadtverkehr sollte >25% Kompression erreichen")
                case .walking:
                    XCTAssertLessThan(compressionRatio, 0.80, "Wandern sollte >20% Kompression erreichen")
                case .rural:
                    XCTAssertLessThan(compressionRatio, 0.70, "Landstraße sollte >30% Kompression erreichen")
                case .pause:
                    XCTAssertLessThan(compressionRatio, 0.50, "Pause sollte >50% Kompression erreichen")
                }
                
                print("📊 \(scenario): \(Int((1.0 - compressionRatio) * 100))% Kompression (\(points.count) → \(Int(Double(points.count) * compressionRatio)) Punkte)")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testDataIntegrityAfterCompression() throws {
        // Test: Datenintegrität nach Komprimierung und Dekomprimierung
        let originalPoints = Array(mockGPSData.prefix(1000))
        let routePoints = convertToRoutePoints(originalPoints)
        
        let trip = createTestTrip()
        let segment = storageManager.startLiveSegment(for: trip)
        
        for point in routePoints {
            storageManager.addPointToLiveSegment(point, segment: segment)
        }
        
        storageManager.closeLiveSegment(segment)
        
        let expectation = XCTestExpectation(description: "Datenintegrität-Test")
        
        Task {
            // Komprimieren
            let success = await storageManager.compressSegment(segment)
            XCTAssertTrue(success, "Komprimierung sollte erfolgreich sein")
            
            // Rekonstruieren
            let reconstructedCoords = storageManager.reconstructPoints(from: segment)
            XCTAssertNotNil(reconstructedCoords, "Rekonstruktion sollte erfolgreich sein")
            
            // Sichere nil-Prüfung vor Verwendung
            guard let coords = reconstructedCoords, !coords.isEmpty else {
                XCTFail("Rekonstruierte Koordinaten sind nil oder leer")
                expectation.fulfill()
                return
            }
            
            // Grundlegende Integrität prüfen
            XCTAssertGreaterThan(coords.count, 0, "Rekonstruierte Punkte sollten vorhanden sein")
            
            // Start- und Endpunkt sollten identisch sein
            let originalStart = originalPoints.first!.coordinate
            let originalEnd = originalPoints.last!.coordinate
            let reconstructedStart = coords.first!
            let reconstructedEnd = coords.last!
            
            XCTAssertEqual(originalStart.latitude, reconstructedStart.latitude, accuracy: 0.0001, "Startpunkt Latitude sollte identisch sein")
            XCTAssertEqual(originalStart.longitude, reconstructedStart.longitude, accuracy: 0.0001, "Startpunkt Longitude sollte identisch sein")
            XCTAssertEqual(originalEnd.latitude, reconstructedEnd.latitude, accuracy: 0.0001, "Endpunkt Latitude sollte identisch sein")
            XCTAssertEqual(originalEnd.longitude, reconstructedEnd.longitude, accuracy: 0.0001, "Endpunkt Longitude sollte identisch sein")
            
            // Gesamtstrecke sollte ähnlich sein (max 5% Abweichung)
            let originalDistance = calculateTotalDistance(originalPoints.map { $0.coordinate })
            let reconstructedDistance = calculateTotalDistance(coords)
            let distanceError = abs(originalDistance - reconstructedDistance) / originalDistance
            
            XCTAssertLessThan(distanceError, 0.15, "Distanzabweichung sollte unter 15% liegen")
            
            print("📏 Original: \(Int(originalDistance/1000))km, Rekonstruiert: \(Int(reconstructedDistance/1000))km, Fehler: \(Int(distanceError*100))%")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testPerformanceWithLargeDatasets() throws {
        // Test: Performance mit großen Datenmengen
        let largeDataSet = Array(mockGPSData.prefix(5000)) // 5000 Punkte
        let routePoints = convertToRoutePoints(largeDataSet)
        
        let trip = createTestTrip()
        let segment = storageManager.startLiveSegment(for: trip)
        
        // Performance-Messung: Hinzufügen von Punkten
        measure {
            for point in routePoints {
                storageManager.addPointToLiveSegment(point, segment: segment)
            }
        }
        
        storageManager.closeLiveSegment(segment)
        
        let expectation = XCTestExpectation(description: "Performance-Komprimierung")
        
        Task {
            let startTime = Date()
            let success = await storageManager.compressSegment(segment)
            let compressionTime = Date().timeIntervalSince(startTime)
            
            XCTAssertTrue(success, "Komprimierung sollte erfolgreich sein")
            XCTAssertLessThan(compressionTime, 10.0, "Komprimierung sollte unter 10 Sekunden dauern")
            
            print("📈 Performance: \(compressionTime.formatted(.number.precision(.fractionLength(2))))s für \(routePoints.count) Punkte")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestTrip() -> Trip {
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.name = "Test Trip"
        trip.startDate = Date()
        trip.isActive = true
        return trip
    }
    
    private func convertToRoutePoints(_ mockPoints: [MockGPSPoint]) -> [RoutePoint] {
        return mockPoints.map { mockPoint in
            let routePoint = RoutePoint(context: context)
            routePoint.latitude = mockPoint.coordinate.latitude
            routePoint.longitude = mockPoint.coordinate.longitude
            routePoint.timestamp = mockPoint.timestamp
            routePoint.speed = mockPoint.speed / 3.6 // km/h zu m/s
            routePoint.altitude = mockPoint.altitude
            return routePoint
        }
    }
    
    private func calculateTotalDistance(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 1 else { return 0 }
        
        var totalDistance: Double = 0
        for i in 1..<coordinates.count {
            let loc1 = CLLocation(latitude: coordinates[i-1].latitude, longitude: coordinates[i-1].longitude)
            let loc2 = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            totalDistance += loc1.distance(from: loc2)
        }
        return totalDistance
    }
}

// MARK: - Real GPX Data Test (für echte GPX-Datei)

@MainActor
class RealGPXDataTests: XCTestCase {
    
    func testWithRealGPXData() throws {
        // Test mit echter GPX-Datei (falls verfügbar)
        // Nutzen Sie Ihre 8.129 Punkte Pyrenäen-GPX-Datei
        
        guard let gpxData = loadGPXTestData() else {
            print("⚠️ Keine GPX-Testdaten verfügbar - Test übersprungen")
            return
        }
        
        print("📍 Teste mit echten GPX-Daten: \(gpxData.count) Punkte")
        
        // Setup
        let container = NSPersistentContainer(name: "Journiary")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            XCTAssertNil(error, "Core Data Setup sollte erfolgreich sein")
        }
        
        let context = container.viewContext
        let storageManager = TrackStorageManager(context: context)
        
        // Trip erstellen
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.name = "GPX Test Trip"
        trip.startDate = Date()
        
        // Live-Segment starten
        let segment = storageManager.startLiveSegment(for: trip)
        
        // Punkte hinzufügen
        for gpxPoint in gpxData {
            let routePoint = RoutePoint(context: context)
            routePoint.latitude = gpxPoint.coordinate.latitude
            routePoint.longitude = gpxPoint.coordinate.longitude
            routePoint.timestamp = gpxPoint.timestamp
            routePoint.speed = gpxPoint.speed
            routePoint.altitude = gpxPoint.elevation
            
            storageManager.addPointToLiveSegment(routePoint, segment: segment)
        }
        
        // Segment schließen
        storageManager.closeLiveSegment(segment)
        
        // Performance-Test
        let expectation = XCTestExpectation(description: "Real GPX Compression")
        
        Task {
            let startTime = Date()
            let success = await storageManager.compressSegment(segment)
            let compressionTime = Date().timeIntervalSince(startTime)
            
            XCTAssertTrue(success, "Komprimierung sollte erfolgreich sein")
            
            let compressionRatio = segment.compressionRatio
            let spaceSavings = Int((1.0 - compressionRatio) * 100)
            
            print("🎯 Real GPX Results:")
            print("   - Original Punkte: \(gpxData.count)")
            print("   - Komprimierung: \(spaceSavings)%")
            print("   - Zeit: \(compressionTime.formatted(.number.precision(.fractionLength(2))))s")
            print("   - Ratio: \(compressionRatio.formatted(.number.precision(.fractionLength(3))))")
            
            // Qualitätskontrolle
            XCTAssertGreaterThan(spaceSavings, 30, "GPX-Daten sollten mindestens 30% Kompression erreichen")
            XCTAssertLessThan(compressionTime, 10.0, "Komprimierung sollte unter 10 Sekunden dauern")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    private func loadGPXTestData() -> [GPXPoint]? {
        // Hier würden Sie Ihre echte GPX-Datei laden
        // Beispiel-Implementation für Bundle-Ressource:
        
        guard let path = Bundle(for: type(of: self)).path(forResource: "pyrenees_test", ofType: "gpx"),
              let data = NSData(contentsOfFile: path) else {
            return nil
        }
        
        // GPX-Parser Implementation (vereinfacht)
        return parseGPX(data: data as Data)
    }
    
    private func parseGPX(data: Data) -> [GPXPoint]? {
        // Vereinfachter GPX-Parser
        // In einer echten Implementation würden Sie einen XML-Parser verwenden
        return nil
    }
    
    struct GPXPoint {
        let coordinate: CLLocationCoordinate2D
        let timestamp: Date
        let elevation: Double
        let speed: Double
    }
} 