import SwiftUI
import CoreLocation
import CoreData
import Charts

struct HybridStorageDemoView: View {
    @StateObject private var demoController = HybridStorageDemoController()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Test Scenarios
                    testScenariosSection
                    
                    // Results Visualization
                    if !demoController.testResults.isEmpty {
                        resultsSection
                    }
                    
                    // Live Testing
                    liveTestingSection
                }
                .padding()
            }
            .navigationTitle("Hybrid Storage Demo")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Hybrid Storage System")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Testen Sie die intelligente GPS-Komprimierung mit verschiedenen Fahrt-Szenarien")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var testScenariosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test-Szenarien")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(HybridStorageDemoController.TestScenario.allCases, id: \.self) { scenario in
                    TestScenarioCard(
                        scenario: scenario,
                        isRunning: demoController.currentlyRunning == scenario,
                        result: demoController.testResults[scenario]
                    ) {
                        Task {
                            await demoController.runTest(for: scenario)
                        }
                    }
                }
            }
            
            // Run All Tests Button
            Button(action: {
                Task {
                    await demoController.runAllTests()
                }
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Alle Tests ausführen")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(demoController.isRunning)
        }
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test-Ergebnisse")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Compression Chart
            if !demoController.testResults.isEmpty {
                compressionChart
            }
            
            // Results Table
            resultsTable
        }
    }
    
    private var compressionChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Komprimierungs-Effizienz")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Chart {
                ForEach(Array(demoController.testResults.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { scenario in
                    if let result = demoController.testResults[scenario] {
                        BarMark(
                            x: .value("Szenario", scenario.shortName),
                            y: .value("Komprimierung %", result.compressionRatio * 100)
                        )
                        .foregroundStyle(scenario.color)
                        .annotation(position: .top) {
                            Text("\(Int(result.compressionRatio * 100))%")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var resultsTable: some View {
        VStack(spacing: 8) {
            ForEach(Array(demoController.testResults.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { scenario in
                if let result = demoController.testResults[scenario] {
                    HStack {
                        Circle()
                            .fill(scenario.color)
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scenario.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(result.originalPoints) Punkte")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(result.compressionRatio * 100))% gespart")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(result.compressionRatio > 0.5 ? .green : .orange)
                            
                            Text("\(result.compressionTime.formatted(.number.precision(.fractionLength(2))))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
    
    private var liveTestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live-Testing")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                    Text("Starten Sie eine echte GPS-Aufzeichnung, um das Hybrid Storage System live zu testen")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                    Text("Beobachten Sie die Speicher-Optimierung in Echtzeit in der TrackStorageStatusView")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct TestScenarioCard: View {
    let scenario: HybridStorageDemoController.TestScenario
    let isRunning: Bool
    let result: HybridStorageDemoController.TestResult?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon
                Image(systemName: scenario.icon)
                    .font(.system(size: 24))
                    .foregroundColor(scenario.color)
                
                // Title
                Text(scenario.shortName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                
                // Status/Result
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let result = result {
                    Text("\(Int(result.compressionRatio * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(result.compressionRatio > 0.5 ? .green : .orange)
                } else {
                    Text("Testen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(scenario.color.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isRunning)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Demo Controller

@MainActor
class HybridStorageDemoController: ObservableObject {
    @Published var testResults: [TestScenario: TestResult] = [:]
    @Published var isRunning = false
    @Published var currentlyRunning: TestScenario?
    
    private let storageManager: TrackStorageManager
    private let context: NSManagedObjectContext
    
    init() {
        // Test-Context erstellen
        let container = NSPersistentContainer(name: "Journiary")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ Demo Context Setup Failed: \(error)")
            }
        }
        
        self.context = container.viewContext
        self.storageManager = TrackStorageManager(context: context)
    }
    
    enum TestScenario: String, CaseIterable {
        case highway = "highway"
        case cityTraffic = "city"
        case walking = "walking"
        case rural = "rural"
        case pause = "pause"
        
        var name: String {
            switch self {
            case .highway: return "Autobahn"
            case .cityTraffic: return "Stadtverkehr"
            case .walking: return "Zu Fuß"
            case .rural: return "Landstraße"
            case .pause: return "Pause"
            }
        }
        
        var shortName: String {
            switch self {
            case .highway: return "Autobahn"
            case .cityTraffic: return "Stadt"
            case .walking: return "Zu Fuß"
            case .rural: return "Land"
            case .pause: return "Pause"
            }
        }
        
        var icon: String {
            switch self {
            case .highway: return "road.lanes"
            case .cityTraffic: return "building.2.fill"
            case .walking: return "figure.walk"
            case .rural: return "tree.fill"
            case .pause: return "pause.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .highway: return .blue
            case .cityTraffic: return .orange
            case .walking: return .green
            case .rural: return .brown
            case .pause: return .gray
            }
        }
    }
    
    struct TestResult {
        let originalPoints: Int
        let compressedPoints: Int
        let compressionRatio: Double
        let compressionTime: TimeInterval
        let method: String
    }
    
    func runTest(for scenario: TestScenario) async {
        guard !isRunning else { return }
        
        isRunning = true
        currentlyRunning = scenario
        
        defer {
            isRunning = false
            currentlyRunning = nil
        }
        
        // Mock-Daten für das Szenario generieren
        let mockData = generateMockData(for: scenario)
        let routePoints = convertToRoutePoints(mockData)
        
        // Trip und Segment erstellen
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.name = "Demo \(scenario.name)"
        trip.startDate = Date()
        
        let segment = storageManager.startLiveSegment(for: trip)
        
        // Punkte hinzufügen
        for point in routePoints {
            storageManager.addPointToLiveSegment(point, segment: segment)
        }
        
        storageManager.closeLiveSegment(segment)
        
        // Komprimierung durchführen
        let startTime = Date()
        let success = await storageManager.compressSegment(segment)
        let compressionTime = Date().timeIntervalSince(startTime)
        
        if success {
            let result = TestResult(
                originalPoints: routePoints.count,
                compressedPoints: Int(Double(routePoints.count) * (1.0 - segment.compressionRatio)),
                compressionRatio: 1.0 - segment.compressionRatio,
                compressionTime: compressionTime,
                method: segment.metadata ?? "Unknown"
            )
            
            testResults[scenario] = result
            print("✅ \(scenario.name) Test: \(Int(result.compressionRatio * 100))% Komprimierung in \(compressionTime.formatted(.number.precision(.fractionLength(2))))s")
        } else {
            print("❌ \(scenario.name) Test failed")
        }
    }
    
    func runAllTests() async {
        for scenario in TestScenario.allCases {
            await runTest(for: scenario)
        }
    }
    
    private func generateMockData(for scenario: TestScenario) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        let baseCoord = CLLocationCoordinate2D(latitude: 50.0, longitude: 8.0)
        
        let pointCount: Int
        let movementPattern: (Int) -> (lat: Double, lon: Double)
        
        switch scenario {
        case .highway:
            pointCount = 1000
            movementPattern = { i in
                let progress = Double(i) / 1000.0
                return (
                    lat: baseCoord.latitude + progress * 0.5,
                    lon: baseCoord.longitude + progress * 0.1 + sin(progress * 2) * 0.001
                )
            }
            
        case .cityTraffic:
            pointCount = 800
            movementPattern = { i in
                let progress = Double(i) / 800.0
                return (
                    lat: baseCoord.latitude + sin(progress * 20) * 0.01 + progress * 0.1,
                    lon: baseCoord.longitude + cos(progress * 15) * 0.015 + progress * 0.05
                )
            }
            
        case .walking:
            pointCount = 500
            movementPattern = { i in
                let progress = Double(i) / 500.0
                return (
                    lat: baseCoord.latitude + sin(progress * 30) * 0.002 + progress * 0.02,
                    lon: baseCoord.longitude + cos(progress * 35) * 0.003 + progress * 0.015
                )
            }
            
        case .rural:
            pointCount = 600
            movementPattern = { i in
                let progress = Double(i) / 600.0
                return (
                    lat: baseCoord.latitude + sin(progress * 8) * 0.005 + progress * 0.3,
                    lon: baseCoord.longitude + cos(progress * 6) * 0.008 + progress * 0.2
                )
            }
            
        case .pause:
            pointCount = 200
            movementPattern = { _ in
                return (
                    lat: baseCoord.latitude + Double.random(in: -0.0001...0.0001),
                    lon: baseCoord.longitude + Double.random(in: -0.0001...0.0001)
                )
            }
        }
        
        for i in 0..<pointCount {
            let point = movementPattern(i)
            coordinates.append(CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon))
        }
        
        return coordinates
    }
    
    private func convertToRoutePoints(_ coordinates: [CLLocationCoordinate2D]) -> [RoutePoint] {
        return coordinates.enumerated().map { index, coord in
            let point = RoutePoint(context: context)
            point.latitude = coord.latitude
            point.longitude = coord.longitude
            point.timestamp = Date().addingTimeInterval(Double(index) * 30)
            point.speed = Double.random(in: 5...25) // m/s
            point.altitude = 100 + Double.random(in: -20...50)
            return point
        }
    }
}

#Preview {
    HybridStorageDemoView()
} 