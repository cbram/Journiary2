# Supabase-Integration Implementierungsplan

## Projektübersicht

Das Ziel ist es, die bestehende iOS Journiary-App mit Supabase zu synchronisieren, um alle Daten auf dem Server verfügbar zu machen. Wir beginnen mit der Trip-Entity als Muster für die weitere Implementierung.

## Architekturdiagramm

```
iOS App (SwiftUI) → CoreData (Lokale Persistierung)
       ↓
SupabaseManager → Supabase (Remote Backend)
       ↓
TripSyncService → trips Table (PostgreSQL)
       ↓
Sync Strategy (Last Write Wins, Timestamp-based, Conflict Resolution)
       ↓
Bidirectional Sync (Upload: CoreData → Supabase, Download: Supabase → CoreData)
```

## Implementierungsphasen

### Phase 1: Grundlagen-Setup

#### 1.1 Supabase-Projekt einrichten
- **Aufgabe**: Neues Supabase-Projekt erstellen
- **Schritte**:
  - Supabase Dashboard aufrufen
  - Neues Projekt erstellen
  - PostgreSQL-Datenbank konfigurieren
  - API-Keys und URLs notieren
  - Row Level Security (RLS) aktivieren

#### 1.2 Swift-Client Integration
```swift
// Package Dependencies hinzufügen
dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
]
```

#### 1.3 Konfiguration
- **Supabase-Credentials** in iOS-App konfigurieren
- **Environment-basierte Konfiguration** für Development/Production
- **Info.plist** Einträge für API-Keys

### Phase 2: Datenbank-Schema

#### 2.1 Trip-Tabelle in Supabase erstellen
```sql
CREATE TABLE trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    trip_description TEXT,
    cover_image_url TEXT,
    travel_companions TEXT,
    visited_countries TEXT,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT false,
    total_distance DOUBLE PRECISION DEFAULT 0.0,
    gps_tracking_enabled BOOLEAN DEFAULT true,
    
    -- Sync-Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sync_version INTEGER DEFAULT 1,
    
    -- Für spätere User-Integration
    user_id UUID REFERENCES auth.users(id)
);

-- Trigger für updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_trips_updated_at BEFORE UPDATE
    ON trips FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### 2.2 RLS-Policies
```sql
-- RLS aktivieren
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;

-- Nur eigene Trips sehen
CREATE POLICY "Users can view own trips" ON trips
    FOR SELECT USING (auth.uid() = user_id);

-- Nur eigene Trips bearbeiten
CREATE POLICY "Users can insert own trips" ON trips
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own trips" ON trips
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own trips" ON trips
    FOR DELETE USING (auth.uid() = user_id);
```

### Phase 3: Swift-Services Implementation

#### 3.1 SupabaseManager
```swift
import Foundation
import Supabase

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    private let supabase: SupabaseClient
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private init() {
        // Konfiguration aus Environment
        guard let url = URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "") else {
            fatalError("Supabase URL nicht konfiguriert")
        }
        
        guard let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] else {
            fatalError("Supabase Anon Key nicht konfiguriert")
        }
        
        supabase = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )
    }
    
    // CRUD-Operationen für Trips
    func fetchTrips() async throws -> [SupabaseTrip] {
        let response: [SupabaseTrip] = try await supabase
            .from("trips")
            .select()
            .execute()
            .value
        return response
    }
    
    func createTrip(_ trip: SupabaseTrip) async throws -> SupabaseTrip {
        let response: SupabaseTrip = try await supabase
            .from("trips")
            .insert(trip)
            .select()
            .single()
            .execute()
            .value
        return response
    }
    
    func updateTrip(_ trip: SupabaseTrip) async throws -> SupabaseTrip {
        let response: SupabaseTrip = try await supabase
            .from("trips")
            .update(trip)
            .eq("id", value: trip.id)
            .select()
            .single()
            .execute()
            .value
        return response
    }
    
    func deleteTrip(id: UUID) async throws {
        try await supabase
            .from("trips")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
```

#### 3.2 SupabaseTrip Model
```swift
import Foundation

struct SupabaseTrip: Codable, Identifiable {
    let id: UUID
    let name: String
    let tripDescription: String?
    let coverImageUrl: String?
    let travelCompanions: String?
    let visitedCountries: String?
    let startDate: Date
    let endDate: Date?
    let isActive: Bool
    let totalDistance: Double
    let gpsTrackingEnabled: Bool
    let createdAt: Date
    let updatedAt: Date
    let syncVersion: Int
    let userId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case tripDescription = "trip_description"
        case coverImageUrl = "cover_image_url"
        case travelCompanions = "travel_companions"
        case visitedCountries = "visited_countries"
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case totalDistance = "total_distance"
        case gpsTrackingEnabled = "gps_tracking_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case syncVersion = "sync_version"
        case userId = "user_id"
    }
}
```

#### 3.3 TripSyncService
```swift
import Foundation
import CoreData

enum SyncStatus {
    case idle
    case syncing
    case success
    case failed(Error)
}

class TripSyncService: ObservableObject {
    private let supabaseManager = SupabaseManager.shared
    private let context: NSManagedObjectContext
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var syncProgress: Double = 0.0
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.lastSyncDate = UserDefaults.standard.object(forKey: "LastTripSyncDate") as? Date
    }
    
    // Bidirektionale Synchronisation
    func syncTrips() async {
        await MainActor.run {
            syncStatus = .syncing
            syncProgress = 0.0
        }
        
        do {
            // Phase 1: Upload lokale Änderungen
            await MainActor.run { syncProgress = 0.2 }
            try await uploadLocalChanges()
            
            // Phase 2: Download Remote-Änderungen
            await MainActor.run { syncProgress = 0.6 }
            try await downloadRemoteChanges()
            
            // Phase 3: Conflict Resolution
            await MainActor.run { syncProgress = 0.8 }
            try await resolveConflicts()
            
            // Phase 4: Cleanup
            await MainActor.run { syncProgress = 1.0 }
            await cleanup()
            
            await MainActor.run {
                syncStatus = .success
                lastSyncDate = Date()
                UserDefaults.standard.set(lastSyncDate, forKey: "LastTripSyncDate")
            }
        } catch {
            await MainActor.run {
                syncStatus = .failed(error)
            }
        }
    }
    
    private func uploadLocalChanges() async throws {
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == YES")
        
        let tripsToUpload = try context.fetch(request)
        
        for trip in tripsToUpload {
            let supabaseTrip = trip.toSupabaseTrip()
            
            if trip.supabaseID == nil {
                // Neue Reise erstellen
                let createdTrip = try await supabaseManager.createTrip(supabaseTrip)
                trip.supabaseID = createdTrip.id
                trip.syncVersion = createdTrip.syncVersion
            } else {
                // Bestehende Reise aktualisieren
                let updatedTrip = try await supabaseManager.updateTrip(supabaseTrip)
                trip.syncVersion = updatedTrip.syncVersion
            }
            
            trip.needsSync = false
            trip.lastSyncDate = Date()
        }
        
        try context.save()
    }
    
    private func downloadRemoteChanges() async throws {
        let remoteTrips = try await supabaseManager.fetchTrips()
        
        for remoteTrip in remoteTrips {
            let request: NSFetchRequest<Trip> = Trip.fetchRequest()
            request.predicate = NSPredicate(format: "supabaseID == %@", remoteTrip.id as CVarArg)
            
            let existingTrips = try context.fetch(request)
            
            if let existingTrip = existingTrips.first {
                // Prüfe ob Remote-Version neuer ist
                if remoteTrip.syncVersion > existingTrip.syncVersion {
                    existingTrip.updateFromSupabase(remoteTrip)
                }
            } else {
                // Neue Remote-Reise erstellen
                let newTrip = Trip(context: context)
                newTrip.updateFromSupabase(remoteTrip)
                newTrip.supabaseID = remoteTrip.id
                newTrip.needsSync = false
                newTrip.lastSyncDate = Date()
            }
        }
        
        try context.save()
    }
    
    private func resolveConflicts() async throws {
        // Implement conflict resolution logic
        // Für jetzt: Last Write Wins basierend auf updated_at
    }
    
    private func cleanup() async {
        // Sync-Metadaten bereinigen
        // Alte Sync-Logs entfernen
    }
}
```

### Phase 4: CoreData-Erweiterungen

#### 4.1 Trip-Entity um Sync-Metadaten erweitern
```swift
// Trip+CoreDataClass.swift
import Foundation
import CoreData

@objc(Trip)
public class Trip: NSManagedObject {
    
    // Konvertierung zu Supabase-Format
    func toSupabaseTrip() -> SupabaseTrip {
        return SupabaseTrip(
            id: supabaseID ?? UUID(),
            name: name ?? "",
            tripDescription: tripDescription,
            coverImageUrl: coverImageUrl,
            travelCompanions: travelCompanions,
            visitedCountries: visitedCountries,
            startDate: startDate ?? Date(),
            endDate: endDate,
            isActive: isActive,
            totalDistance: totalDistance,
            gpsTrackingEnabled: gpsTrackingEnabled,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            syncVersion: Int(syncVersion),
            userId: nil // Wird später mit User-Management gesetzt
        )
    }
    
    // Update von Supabase-Daten
    func updateFromSupabase(_ supabaseTrip: SupabaseTrip) {
        self.name = supabaseTrip.name
        self.tripDescription = supabaseTrip.tripDescription
        self.coverImageUrl = supabaseTrip.coverImageUrl
        self.travelCompanions = supabaseTrip.travelCompanions
        self.visitedCountries = supabaseTrip.visitedCountries
        self.startDate = supabaseTrip.startDate
        self.endDate = supabaseTrip.endDate
        self.isActive = supabaseTrip.isActive
        self.totalDistance = supabaseTrip.totalDistance
        self.gpsTrackingEnabled = supabaseTrip.gpsTrackingEnabled
        self.syncVersion = Int32(supabaseTrip.syncVersion)
        self.updatedAt = supabaseTrip.updatedAt
        self.supabaseID = supabaseTrip.id
    }
}

// Trip+CoreDataProperties.swift
extension Trip {
    @NSManaged public var syncVersion: Int32
    @NSManaged public var lastSyncDate: Date?
    @NSManaged public var needsSync: Bool
    @NSManaged public var supabaseID: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var coverImageUrl: String?
}
```

#### 4.2 CoreData Model Update
```xml
<!-- Neue Attribute für Trip Entity in Journiary.xcdatamodeld -->
<attribute name="syncVersion" optional="YES" attributeType="Integer 32" defaultValueString="1" usesScalarValueType="YES"/>
<attribute name="lastSyncDate" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
<attribute name="needsSync" optional="YES" attributeType="Boolean" defaultValueString="NO" usesScalarValueType="YES"/>
<attribute name="supabaseID" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
<attribute name="createdAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
<attribute name="updatedAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
<attribute name="coverImageUrl" optional="YES" attributeType="String"/>
```

### Phase 5: Synchronisationsstrategie

#### 5.1 Conflict Resolution
- **Last Write Wins**: Timestamp-basierte Auflösung
- **Merge-Strategien** für verschiedene Attribute
- **User-Feedback** bei kritischen Konflikten

#### 5.2 Sync-Phasen
1. **Upload-Phase**: Lokale Änderungen → Supabase
2. **Download-Phase**: Supabase → Lokale Daten
3. **Conflict-Resolution**: Konflikte auflösen
4. **Cleanup**: Sync-Metadaten aktualisieren

### Phase 6: UI-Integration

#### 6.1 TripView Erweiterungen
```swift
struct TripView: View {
    @StateObject private var syncService: TripSyncService
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        self._syncService = StateObject(wrappedValue: TripSyncService(context: context))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Sync-Status anzeigen
                SyncStatusView(
                    status: syncService.syncStatus,
                    lastSync: syncService.lastSyncDate,
                    progress: syncService.syncProgress
                )
                
                // Bestehende Trip-Liste
                ScrollView {
                    VStack(spacing: 20) {
                        if !allTrips.isEmpty {
                            VStack(alignment: .center, spacing: 0) {
                                ForEach(allTrips, id: \.objectID) { trip in
                                    NavigationLink {
                                        TripDetailView(trip: trip)
                                            .environmentObject(locationManager)
                                    } label: {
                                        TripCardView(trip: trip)
                                            .overlay(
                                                // Sync-Indikator
                                                syncIndicator(for: trip),
                                                alignment: .topTrailing
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    Task {
                        await syncService.syncTrips()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Sync")
                    }
                }
                .disabled(syncService.syncStatus == .syncing)
            }
        }
        .onAppear {
            // Automatische Synchronisation beim App-Start
            Task {
                await syncService.syncTrips()
            }
        }
    }
    
    @ViewBuilder
    private func syncIndicator(for trip: Trip) -> some View {
        if trip.needsSync {
            Image(systemName: "icloud.and.arrow.up")
                .foregroundColor(.orange)
                .font(.caption)
                .padding(4)
                .background(Color.white.opacity(0.8))
                .clipShape(Circle())
        }
    }
}
```

#### 6.2 Sync-Status UI
```swift
struct SyncStatusView: View {
    let status: SyncStatus
    let lastSync: Date?
    let progress: Double
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading) {
                Text(statusText)
                    .font(.caption)
                
                if let lastSync = lastSync {
                    Text("Letzte Sync: \(lastSync, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if case .syncing = status {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(statusBackgroundColor)
        .cornerRadius(8)
    }
    
    private var statusIcon: String {
        switch status {
        case .idle: return "icloud"
        case .syncing: return "icloud.and.arrow.up.and.down"
        case .success: return "checkmark.icloud"
        case .failed: return "exclamationmark.icloud"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .idle: return .gray
        case .syncing: return .blue
        case .success: return .green
        case .failed: return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .idle: return "Bereit für Synchronisation"
        case .syncing: return "Synchronisiere..."
        case .success: return "Erfolgreich synchronisiert"
        case .failed(let error): return "Sync-Fehler: \(error.localizedDescription)"
        }
    }
    
    private var statusBackgroundColor: Color {
        switch status {
        case .idle: return Color.gray.opacity(0.1)
        case .syncing: return Color.blue.opacity(0.1)
        case .success: return Color.green.opacity(0.1)
        case .failed: return Color.red.opacity(0.1)
        }
    }
}
```

### Phase 7: Error-Handling & Offline-Support

#### 7.1 Umfassendes Error-Handling
```swift
enum SyncError: Error, LocalizedError {
    case networkUnavailable
    case authenticationFailed
    case conflictResolutionFailed
    case dataCorruption
    case rateLimitExceeded
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Netzwerkverbindung nicht verfügbar"
        case .authenticationFailed:
            return "Authentifizierung fehlgeschlagen"
        case .conflictResolutionFailed:
            return "Konfliktauflösung fehlgeschlagen"
        case .dataCorruption:
            return "Datenintegritätsfehler"
        case .rateLimitExceeded:
            return "Zu viele Anfragen - bitte warten"
        case .serverError(let message):
            return "Server-Fehler: \(message)"
        }
    }
}
```

#### 7.2 Offline-Unterstützung
```swift
class OfflineManager: ObservableObject {
    @Published var isOnline = true
    private var networkMonitor: NWPathMonitor?
    
    func startMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor?.start(queue: queue)
    }
    
    func stopMonitoring() {
        networkMonitor?.cancel()
    }
}
```

### Phase 8: Testing & Validation

#### 8.1 Unit-Tests
```swift
import XCTest
@testable import Journiary

class TripSyncServiceTests: XCTestCase {
    var syncService: TripSyncService!
    var mockContext: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        // Setup test context
        mockContext = PersistenceController.preview.container.viewContext
        syncService = TripSyncService(context: mockContext)
    }
    
    func testBidirectionalSync() async throws {
        // Test Upload/Download-Zyklen
        let trip = Trip(context: mockContext)
        trip.name = "Test Trip"
        trip.needsSync = true
        
        await syncService.syncTrips()
        
        XCTAssertFalse(trip.needsSync)
        XCTAssertNotNil(trip.supabaseID)
    }
    
    func testConflictResolution() async throws {
        // Test verschiedene Konflikt-Szenarien
    }
    
    func testOfflineSupport() async throws {
        // Test Offline-Verhalten
    }
}
```

#### 8.2 Integration-Tests
- **End-to-End Sync-Tests** zwischen iOS und Supabase
- **Performance-Tests** für große Datenmengen
- **Stress-Tests** für Concurrent-Access

### Phase 9: Produktionsreife Features

#### 9.1 Image-Storage
```swift
class ImageSyncService {
    private let supabase = SupabaseManager.shared
    
    func uploadCoverImage(_ imageData: Data, tripId: UUID) async throws -> String {
        let fileName = "\(tripId)_cover.jpg"
        
        let file = File(
            name: fileName,
            data: imageData,
            fileName: fileName,
            contentType: "image/jpeg"
        )
        
        let response = try await supabase.storage
            .from("trip-images")
            .upload(path: fileName, file: file)
        
        return response.path
    }
    
    func downloadCoverImage(url: String) async throws -> Data {
        let response = try await supabase.storage
            .from("trip-images")
            .download(path: url)
        
        return response
    }
}
```

#### 9.2 Background-Sync
```swift
import BackgroundTasks

class BackgroundSyncService {
    static let identifier = "com.journiary.background-sync"
    
    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: Self.identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 Minuten
        
        try? BGTaskScheduler.shared.submit(request)
    }
    
    func performBackgroundSync() async throws {
        let context = PersistenceController.shared.container.viewContext
        let syncService = TripSyncService(context: context)
        
        await syncService.syncTrips()
    }
}
```

### Phase 10: Monitoring & Analytics

#### 10.1 Sync-Metriken
```swift
class SyncMetrics {
    static let shared = SyncMetrics()
    
    private var syncEvents: [SyncEvent] = []
    
    func recordSyncEvent(_ event: SyncEvent) {
        syncEvents.append(event)
        
        // Optional: An Analytics-Service senden
        // Analytics.track(event)
    }
    
    func getSyncStatistics() -> SyncStatistics {
        return SyncStatistics(
            totalSyncs: syncEvents.count,
            successfulSyncs: syncEvents.filter { $0.success }.count,
            averageSyncDuration: syncEvents.compactMap { $0.duration }.average(),
            lastSyncDate: syncEvents.last?.timestamp
        )
    }
}

struct SyncEvent {
    let timestamp: Date
    let success: Bool
    let duration: TimeInterval?
    let error: Error?
}

struct SyncStatistics {
    let totalSyncs: Int
    let successfulSyncs: Int
    let averageSyncDuration: TimeInterval?
    let lastSyncDate: Date?
}
```

## Konfiguration

### Environment-Variablen
```swift
// Config.swift
struct Config {
    static let supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
    static let supabaseAnonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
    static let isDebugMode = ProcessInfo.processInfo.environment["DEBUG_MODE"] == "true"
}
```

### Info.plist Einträge
```xml
<key>SUPABASE_URL</key>
<string>$(SUPABASE_URL)</string>
<key>SUPABASE_ANON_KEY</key>
<string>$(SUPABASE_ANON_KEY)</string>
```

## Deployment

### Development Setup
1. Supabase-Projekt erstellen
2. Umgebungsvariablen konfigurieren
3. Xcode-Projekt mit Supabase-Package erweitern
4. CoreData-Model aktualisieren

### Production Setup
1. Supabase-Projekt für Production konfigurieren
2. RLS-Policies aktivieren
3. Backup-Strategien implementieren
4. Monitoring einrichten

## Wartung & Updates

### Regelmäßige Aufgaben
- **Sync-Logs** überwachen
- **Performance-Metriken** auswerten
- **Error-Rates** analysieren
- **Datenbank-Backups** prüfen

### Versionierung
- **Schema-Migrationen** für Datenbank-Updates
- **App-Versioning** für Kompatibilität
- **Rollback-Strategien** für kritische Fehler

## Erweiterungen für weitere Entities

Nach erfolgreicher Trip-Integration können folgende Entities erweitert werden:

1. **Memory** - Reise-Erinnerungen
2. **MediaItem** - Fotos und Videos
3. **RoutePoint** - GPS-Tracking-Daten
4. **Tag** - Kategorisierung
5. **BucketListItem** - Wunschliste

Jede Entity folgt dem gleichen Muster:
- Supabase-Tabelle erstellen
- Swift-Model definieren
- Sync-Service implementieren
- UI-Integration
- Tests schreiben

## Fazit

Dieser Implementierungsplan stellt sicher, dass die Supabase-Integration:
- **Produktionsreif** von Anfang an ist
- **Clean Code** Prinzipien befolgt
- **Fehlerbehandlung** umfassend implementiert
- **Offline-Support** bereitstellt
- **Skalierbar** für weitere Entities ist

Die Implementierung erfolgt in kleinen, testbaren Schritten, um Compile-Probleme zu vermeiden und eine stabile Entwicklung zu gewährleisten. 