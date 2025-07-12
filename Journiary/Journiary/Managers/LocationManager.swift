//
//  LocationManager.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import Foundation
import CoreLocation
import CoreData
import SwiftUI
import UserNotifications
import BackgroundTasks

enum TrackingAccuracy: String, CaseIterable {
    case hundredMeters = "hundredMeters"
    case twoFiftyMeters = "twoFiftyMeters"
    case kilometer = "kilometer"
    case reduced = "reduced"
    
    var displayName: String {
        switch self {
        case .hundredMeters: return "100 Meter"
        case .twoFiftyMeters: return "250 Meter"
        case .kilometer: return "1 Kilometer"
        case .reduced: return "Reduziert (Batterieschonend)"
        }
    }
    
    var coreLocationAccuracy: CLLocationAccuracy {
        switch self {
        case .hundredMeters: return kCLLocationAccuracyHundredMeters
        case .twoFiftyMeters: return 250.0 // Custom Accuracy
        case .kilometer: return kCLLocationAccuracyKilometer
        case .reduced: return kCLLocationAccuracyReduced
        }
    }
    
    var recommendedDistanceFilter: CLLocationDistance {
        switch self {
        case .hundredMeters: return 50.0
        case .twoFiftyMeters: return 125.0
        case .kilometer: return 100.0
        case .reduced: return 200.0
        }
    }
    
    var batteryImpact: String {
        switch self {
        case .hundredMeters: return "Mittel"
        case .twoFiftyMeters: return "Mittel-Niedrig"
        case .kilometer: return "Niedrig"
        case .reduced: return "Sehr niedrig"
        }
    }
}

// MARK: - Debug-Datenstrukturen

struct DebugLogEntry: Codable, Identifiable {
    var id = UUID()
    let timestamp: Date
    let message: String
    let type: DebugLogType
    let coordinate: DebugCoordinate?
    let appState: String
    let batteryLevel: Float
    
    struct DebugCoordinate: Codable {
        let latitude: Double
        let longitude: Double
        let accuracy: Double
        let speed: Double
        let altitude: Double
    }
}

enum DebugLogType: String, Codable, CaseIterable {
    case locationUpdate = "location"
    case trackingStart = "start"
    case trackingStop = "stop"
    case background = "background"
    case foreground = "foreground"
    case permission = "permission"
    case error = "error"
    case info = "info"
    case warning = "warning"
    
    var icon: String {
        switch self {
        case .locationUpdate: return "location.fill"
        case .trackingStart: return "play.fill"
        case .trackingStop: return "stop.fill"
        case .background: return "moon.fill"
        case .foreground: return "sun.max.fill"
        case .permission: return "lock.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .locationUpdate: return .blue
        case .trackingStart: return .green
        case .trackingStop: return .red
        case .background: return .purple
        case .foreground: return .orange
        case .permission: return .yellow
        case .error: return .red
        case .info: return .gray
        case .warning: return .orange
        }
    }
}

// MARK: - LocationManager with GPS Tracking Recovery
/**
 * GPS Tracking Recovery System - Robuste Logik für unterbrechungsfreies GPS-Tracking
 * 
 * Features:
 * 1. **Crash Detection**: Erkennt unerwartete App-Beendigungen durch Heartbeat-System
 * 2. **Automatic Recovery**: Automatische Wiederherstellung bei Background-Berechtigung
 * 3. **Manual Recovery**: Benutzer-Dialog für manuelle Wiederherstellung
 * 4. **Persistent State**: Tracking-Status wird persistent gespeichert
 * 5. **Background Monitoring**: Significant Location Changes für Background-Tracking
 * 6. **Background Tasks**: Verlängerte Background-Ausführung für kritische Operationen
 * 
 * Recovery-Ablauf:
 * 1. App-Start → checkForCrashRecovery()
 * 2. Heartbeat-Check (< 5 min) + Clean Termination Flag
 * 3. Bei Crash: attemptTrackingRecovery()
 * 4. Trip-Suche über gespeicherte Trip-ID
 * 5. Automatische oder manuelle Recovery
 * 6. Wiederherstellung des Tracking-Status
 * 
 * Test-Möglichkeiten (Debug-Modus):
 * - "Simulate Crash": Simuliert App-Crash für Tests
 * - "Force Recovery Check": Manuelle Recovery-Prüfung
 * - "Clear Recovery Data": Löschung der Recovery-Daten
 */
class LocationManager: NSObject, ObservableObject {
    // Singleton-Instanz für maximale Zuverlässigkeit
    static var shared: LocationManager!
    
    private let locationManager = CLLocationManager()
    private let context: NSManagedObjectContext
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published var currentTrip: Trip?
    @Published var totalDistance: Double = 0.0
    @Published var currentSpeed: Double = 0.0
    
    // Neue Einstellungen
    @Published var trackingAccuracy: TrackingAccuracy = .hundredMeters
    @Published var customDistanceFilter: Double = 10.0
    @Published var useRecommendedSettings: Bool = true
    @Published var enableBackgroundTracking: Bool = true
    @Published var enableEnhancedBackgroundTracking: Bool = true
    
    // Track-Optimierung
    @Published var enableIntelligentPointSelection: Bool = true
    @Published var automaticOptimizationEnabled: Bool = true
    @Published var optimizationLevel: TrackOptimizer.OptimizationSettings = .level2
    private var lastSavedLocation: CLLocation?
    private var previousLocation: CLLocation?
    private var currentAutoOptimizationLevel: TrackOptimizer.OptimizationSettings = .level2
    
    // Hybrid Storage Management  
    @Published var enableHybridStorage: Bool = true
    private var trackStorageManager: TrackStorageManager?
    private var currentLiveSegment: TrackSegment?
    
    // Debug-Eigenschaften
    @Published var isDebugModeEnabled: Bool = false
    @Published var debugLogs: [DebugLogEntry] = []
    @Published var lastBackgroundUpdate: Date?
    @Published var backgroundUpdateCount: Int = 0
    @Published var enableDebugNotifications: Bool = false
    
    // MARK: - Recovery & Persistence
    @Published var hasUnexpectedTermination: Bool = false
    @Published var lastTrackingSession: Date?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTaskTimeoutTimer: Timer? // Timer für automatisches Beenden
    private var isMonitoringSignificantChanges = false
    
    // Erweiterte Background-Tracking-Redundanz
    private var isMonitoringVisits = false
    private var currentRegion: CLCircularRegion?
    private var lastMovementCheck: Date = Date()
    private var backgroundTaskRotationTimer: Timer?
    private var periodicalLocationCheckTimer: Timer?
    
    private var lastLocation: CLLocation?
    private let maxDebugLogs = 1000 // Maximale Anzahl von Debug-Logs im Speicher
    
    // Debug-Timer für periodische Logs
    private var debugTimer: Timer?
    
    // Recovery-spezifische Keys für UserDefaults
    private struct RecoveryKeys {
        static let isTrackingActive = "recovery_isTrackingActive"
        static let currentTripID = "recovery_currentTripID"
        static let lastKnownLocation = "recovery_lastKnownLocation"
        static let lastHeartbeat = "recovery_lastHeartbeat"
        static let appTerminationFlag = "recovery_appTerminationFlag"
        static let trackingStartTime = "recovery_trackingStartTime"
        static let totalDistanceAtLastSave = "recovery_totalDistanceAtLastSave"
        static let lastMovementTime = "recovery_lastMovementTime"  // Neu
    }
    
    // MARK: - Tracking State Protection (Robustheit gegen ungewolltes Beenden)
    
    private var trackingStartedByUser: Bool = false  // Neue Variable zur Verfolgung der Benutzerabsicht
    private var lastTrackingStateChange: Date = Date()
    private var autoStopProtectionActive: Bool = true  // Schutz gegen automatisches Stoppen
    
    // Zusätzliche Eigenschaften für Robustheit
    @Published var trackingProtectionLevel: TrackingProtectionLevel = .high
    
    enum TrackingProtectionLevel {
        case low, medium, high
        
        var description: String {
            switch self {
            case .low: return "Niedrig"
            case .medium: return "Mittel"
            case .high: return "Hoch"
            }
        }
    }
    
    // Watchdog-Timer für Location-Update-Überwachung
    private var watchdogTimer: Timer?
    private let watchdogInterval: TimeInterval = 600 // 10 Minuten
    private let watchdogTimeout: TimeInterval = 900 // 15 Minuten ohne Update
    
    init(context: NSManagedObjectContext) {
        self.context = context
        super.init()
        // LocationManager initialisiert (Log reduziert)
        // Singleton-Initialisierung
        if LocationManager.shared == nil {
            LocationManager.shared = self
        }
        requestLocationPermission()
        
        // Initialisiere TrackStorageManager asynchron
        Task { @MainActor in
            self.trackStorageManager = TrackStorageManager(context: context)
        }
        
        // Recovery-Logik ZUERST ausführen
        checkForCrashRecovery()
        
        loadSettings()
        loadDebugSettings()
        setupLocationManager()
        setupBackgroundTaskHandling()
        
        // App-Lifecycle-Notifications
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(appDidEnterBackground), 
            name: UIApplication.didEnterBackgroundNotification, 
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(appWillEnterForeground), 
            name: UIApplication.willEnterForegroundNotification, 
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        // Debug-Logs laden
        loadDebugLogs()
        
        // Benachrichtigungen anfordern
        requestNotificationPermission()
        
        // Heartbeat starten
        startHeartbeat()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        debugTimer?.invalidate()
        backgroundTaskRotationTimer?.invalidate()
        periodicalLocationCheckTimer?.invalidate()
        endBackgroundTask()
        
        // Region Monitoring cleanup
        if let region = currentRegion {
            locationManager.stopMonitoring(for: region)
        }
    }
    
    // MARK: - Recovery & Crash Detection
    
    func checkForCrashRecovery() {
        let wasTracking = UserDefaults.standard.bool(forKey: RecoveryKeys.isTrackingActive)
        let lastHeartbeat = UserDefaults.standard.object(forKey: RecoveryKeys.lastHeartbeat) as? Date
        let terminationFlag = UserDefaults.standard.bool(forKey: RecoveryKeys.appTerminationFlag)
        
        // Recovery Check ohne Debug-Output
        
        // Wenn Tracking aktiv war aber keine saubere Beendigung oder alter Heartbeat
        if wasTracking {
            let now = Date()
            let heartbeatAge = lastHeartbeat?.timeIntervalSince(now) ?? Double.infinity
            let hasRecentHeartbeat = abs(heartbeatAge) < 300 // 5 Minuten
            
            if !terminationFlag || !hasRecentHeartbeat {
                hasUnexpectedTermination = true
                attemptTrackingRecovery()
            } else {
                cleanupRecoveryData()
            }
        }
        
        // Termination-Flag für nächsten Start zurücksetzen
        UserDefaults.standard.set(false, forKey: RecoveryKeys.appTerminationFlag)
    }
    
    private func attemptTrackingRecovery() {
        guard let tripIDString = UserDefaults.standard.string(forKey: RecoveryKeys.currentTripID),
              let tripID = UUID(uuidString: tripIDString) else {
            cleanupRecoveryData()
            return
        }
        
        // Suche Trip in Core Data
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", tripID as CVarArg)
        
        do {
            let trips = try context.fetch(request)
            if let trip = trips.first {
                print("✅ Trip für Recovery gefunden: '\(trip.name ?? "Unbenannt")'")
                
                // Hole gespeicherte Tracking-Daten
                let savedDistance = UserDefaults.standard.double(forKey: RecoveryKeys.totalDistanceAtLastSave)
                let trackingStartTime = UserDefaults.standard.object(forKey: RecoveryKeys.trackingStartTime) as? Date
                
                // Recovery-Nachricht vorbereiten
                lastTrackingSession = trackingStartTime
                
                // Automatic Recovery wenn Background-Berechtigung vorhanden
                if authorizationStatus == .authorizedAlways && enableBackgroundTracking {
                    print("🔄 Automatische Recovery mit Background-Berechtigung...")
                    
                    // Tracking wiederherstellen
                    restoreTrackingSession(trip: trip, savedDistance: savedDistance)
                    
                    // Benachrichtigung senden
                    sendRecoveryNotification(tripName: trip.name ?? "Unbenannt", automatic: true)
                } else {
                    print("⚠️ Manuelle Recovery erforderlich - keine Background-Berechtigung")
                    // Benutzer muss manuell entscheiden
                    sendRecoveryNotification(tripName: trip.name ?? "Unbenannt", automatic: false)
                }
            } else {
                print("❌ Trip für Recovery nicht gefunden")
                cleanupRecoveryData()
            }
        } catch {
            print("❌ Fehler beim Laden der Trip für Recovery: \(error)")
            cleanupRecoveryData()
        }
    }
    
    private func restoreTrackingSession(trip: Trip, savedDistance: Double) {
        // Tracking-State wiederherstellen
        currentTrip = trip
        totalDistance = savedDistance
        
        // Trip als aktiv markieren
        trip.isActive = true
        
        do {
            try context.save()
        } catch {
            print("❌ Fehler beim Speichern der Recovery-Trip: \(error)")
        }
        
        // Location Manager konfigurieren
        updateLocationManagerSettings()
        
        // Enhanced Background Location Monitoring für Recovery starten
        if enableBackgroundTracking && authorizationStatus == .authorizedAlways {
            startEnhancedBackgroundLocationMonitoring()
        }
        
        // Standard Location Updates starten
        locationManager.startUpdatingLocation()
        
        // Tracking-State setzen
        isTracking = true
        
        // Recovery-Daten aktualisieren
        saveTrackingState()
        
        addDebugLog(type: .info, message: "Tracking-Session erfolgreich recovered - Trip: '\(trip.name ?? "Unbenannt")', Distanz: \(String(format: "%.1f", savedDistance/1000))km")
        
        // Debug-Timer starten
        if isDebugModeEnabled {
            startDebugTimer()
        }
        
        print("✅ Tracking-Session erfolgreich wiederhergestellt")
    }
    
    func manualRecoveryAccepted() {
        guard hasUnexpectedTermination else { return }
        
        // Versuche manuelle Recovery
        attemptTrackingRecovery()
        hasUnexpectedTermination = false
    }
    
    func manualRecoveryDeclined() {
        guard hasUnexpectedTermination else { return }
        
        print("ℹ️ Benutzer hat Recovery abgelehnt")
        cleanupRecoveryData()
        hasUnexpectedTermination = false
    }
    
    private func cleanupRecoveryData() {
        UserDefaults.standard.removeObject(forKey: RecoveryKeys.isTrackingActive)
        UserDefaults.standard.removeObject(forKey: RecoveryKeys.currentTripID)
        UserDefaults.standard.removeObject(forKey: RecoveryKeys.lastKnownLocation)
        UserDefaults.standard.removeObject(forKey: RecoveryKeys.lastHeartbeat)
        UserDefaults.standard.removeObject(forKey: RecoveryKeys.trackingStartTime)
        UserDefaults.standard.removeObject(forKey: RecoveryKeys.totalDistanceAtLastSave)
        UserDefaults.standard.removeObject(forKey: RecoveryKeys.lastMovementTime)
        hasUnexpectedTermination = false
    }
    
    private func saveTrackingState() {
        guard isTracking, let trip = currentTrip else {
            // Kein Tracking aktiv - Recovery-Daten löschen
            UserDefaults.standard.set(false, forKey: RecoveryKeys.isTrackingActive)
            return
        }
        
        UserDefaults.standard.set(true, forKey: RecoveryKeys.isTrackingActive)
        UserDefaults.standard.set(trip.id?.uuidString, forKey: RecoveryKeys.currentTripID)
        UserDefaults.standard.set(totalDistance, forKey: RecoveryKeys.totalDistanceAtLastSave)
        UserDefaults.standard.set(Date(), forKey: RecoveryKeys.lastHeartbeat)
        
        if let startDate = trip.startDate {
            UserDefaults.standard.set(startDate, forKey: RecoveryKeys.trackingStartTime)
        }
        
        if let location = currentLocation {
            let locationData = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "altitude": location.altitude,
                "timestamp": location.timestamp.timeIntervalSince1970
            ]
            UserDefaults.standard.set(locationData, forKey: RecoveryKeys.lastKnownLocation)
        }
        
        // Speichere alle aktiven Monitoring Services für Recovery
        UserDefaults.standard.set(isMonitoringSignificantChanges, forKey: "recovery_significantChangesActive")
        UserDefaults.standard.set(isMonitoringVisits, forKey: "recovery_visitsActive")
    }
    
    private func startHeartbeat() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            if self.isTracking {
                self.saveTrackingState()
            }
        }
    }
    
    @objc private func appWillTerminate() {
        print("🔄 App wird beendet - setze Termination-Flag")
        UserDefaults.standard.set(true, forKey: RecoveryKeys.appTerminationFlag)
        
        if isTracking {
            saveTrackingState()
        }
    }
    
    private func sendRecoveryNotification(tripName: String, automatic: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "GPS-Tracking unterbrochen"
        
        if automatic {
            content.body = "Das Tracking für '\(tripName)' wurde automatisch wiederhergestellt."
        } else {
            content.body = "Das Tracking für '\(tripName)' wurde unterbrochen. Öffne die App, um fortzufahren."
        }
        
        content.sound = .default
        content.categoryIdentifier = "TRACKING_RECOVERY"
        
        let request = UNNotificationRequest(
            identifier: "tracking_recovery_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Background Task Management
    
    private func setupBackgroundTaskHandling() {
        // Background Task Handler wird in AppDelegate registriert
        // Hier nur die Handler-Logik vorbereiten
        print("📋 LocationManager: Background Task Handling vorbereitet")
    }
    
    @available(iOS 13.0, *)
    private func handleBackgroundLocationTask(_ task: BGProcessingTask) {
        addDebugLog(type: .info, message: "Background Location Task gestartet")
        
        task.expirationHandler = {
            self.addDebugLog(type: .info, message: "Background Task läuft ab - beende Task")
            self.saveTrackingState()
            task.setTaskCompleted(success: false)
        }
        
        // Ausführliche Background-Wartung
        performBackgroundMaintenance()
        
        // Schedule next background task
        scheduleBackgroundLocationTask()
        
        task.setTaskCompleted(success: true)
    }
    
    private func performBackgroundMaintenance() {
        addDebugLog(type: .info, message: "Background Maintenance gestartet")
        if isTracking {
            saveTrackingState()
            checkLocationStatus()
            requestOneTimeLocationUpdate()
        }
        // Keine Recovery-Checks oder sonstige Tasks mehr bei !isTracking
        let backgroundUpdateCount = UserDefaults.standard.integer(forKey: "backgroundMaintenanceCount") + 1
        UserDefaults.standard.set(backgroundUpdateCount, forKey: "backgroundMaintenanceCount")
        UserDefaults.standard.set(Date(), forKey: "lastBackgroundMaintenance")
        addDebugLog(type: .info, message: "Background Maintenance abgeschlossen - Run #\(backgroundUpdateCount)")
    }
    
    @available(iOS 13.0, *)
    private func scheduleBackgroundLocationTask() {
        if !isTracking { return }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.journiary.background-location")
        let request = BGProcessingTaskRequest(identifier: "com.journiary.background-location")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 300) // 5 Minuten
        do {
            try BGTaskScheduler.shared.submit(request)
            addDebugLog(type: .info, message: "Background Task geplant - nächste Ausführung in 5 Minuten")
        } catch {
            addDebugLog(type: .error, message: "Fehler beim Planen des Background Tasks: \(error.localizedDescription)")
        }
    }
    
    private func beginBackgroundTask() {
        endBackgroundTask()
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "GPS-Tracking") {
            print("⚠️ Background Task läuft ab - beende Task (Expiration Handler)")
            self.endBackgroundTask()
        }
        
        if backgroundTaskID != .invalid {
            print("✅ Background Task gestartet: \(backgroundTaskID.rawValue)")
            // Timer setzen, der nach 29 Sekunden automatisch beendet
            backgroundTaskTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 29.0, repeats: false) { [weak self] _ in
                print("⏰ Background Task Timeout erreicht - beende Task automatisch")
                self?.endBackgroundTask()
            }
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            print("🔄 Background Task beendet: \(backgroundTaskID.rawValue)")
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
        // Timer immer invalidieren
        backgroundTaskTimeoutTimer?.invalidate()
        backgroundTaskTimeoutTimer = nil
    }
    
    // MARK: - Enhanced Background Location Monitoring
    
    private func startEnhancedBackgroundLocationMonitoring() {
        guard enableBackgroundTracking && authorizationStatus == .authorizedAlways else {
            print("⚠️ Enhanced Background Monitoring benötigt 'Always' Berechtigung")
            return
        }
        
        // 1. Significant Location Changes für größere Bewegungen
        startSignificantLocationChangeMonitoring()
        
        // 2. Visit Monitoring für Aufenthalte an Orten
        startVisitMonitoring()
        
        // 3. Periodische Background Task Rotation
        startBackgroundTaskRotation()
        
        // 4. Periodische Location Checks auch bei Stillstand
        startPeriodicalLocationChecks()
        
        addDebugLog(type: .info, message: "Enhanced Background Location Monitoring gestartet")
        print("✅ Enhanced Background Location Monitoring aktiviert")
    }
    
    private func stopEnhancedBackgroundLocationMonitoring() {
        stopSignificantLocationChangeMonitoring()
        stopVisitMonitoring()
        stopBackgroundTaskRotation()
        stopPeriodicalLocationChecks()
        
        addDebugLog(type: .info, message: "Enhanced Background Location Monitoring gestoppt")
        print("🔄 Enhanced Background Location Monitoring deaktiviert")
    }
    
    // MARK: - Individual Monitoring Components
    
    private func startSignificantLocationChangeMonitoring() {
        guard !isMonitoringSignificantChanges else {
            print("ℹ️ Significant Location Changes bereits aktiv")
            return
        }
        
        locationManager.startMonitoringSignificantLocationChanges()
        isMonitoringSignificantChanges = true
        
        addDebugLog(type: .info, message: "Significant Location Change Monitoring gestartet")
        print("✅ Significant Location Change Monitoring gestartet")
    }
    
    private func stopSignificantLocationChangeMonitoring() {
        guard isMonitoringSignificantChanges else { return }
        
        locationManager.stopMonitoringSignificantLocationChanges()
        isMonitoringSignificantChanges = false
        
        addDebugLog(type: .info, message: "Significant Location Change Monitoring gestoppt")
        print("🔄 Significant Location Change Monitoring gestoppt")
    }
    
    private func startVisitMonitoring() {
        guard !isMonitoringVisits else {
            print("ℹ️ Visit Monitoring bereits aktiv")
            return
        }
        
        locationManager.startMonitoringVisits()
        isMonitoringVisits = true
        
        addDebugLog(type: .info, message: "Visit Monitoring gestartet")
        print("✅ Visit Monitoring gestartet - erkennt längere Aufenthalte")
    }
    
    private func stopVisitMonitoring() {
        guard isMonitoringVisits else { return }
        
        locationManager.stopMonitoringVisits()
        isMonitoringVisits = false
        
        addDebugLog(type: .info, message: "Visit Monitoring gestoppt")
        print("🔄 Visit Monitoring gestoppt")
    }
    
    private func startBackgroundTaskRotation() {
        stopBackgroundTaskRotation()
        
        // Alle 5 Minuten neue Background Tasks starten
        backgroundTaskRotationTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { _ in
            guard self.isTracking && UIApplication.shared.applicationState == .background else { return }
            
            // Neuen Background Task starten
            self.beginBackgroundTask()
            
            // Location Status überprüfen
            self.checkLocationStatus()
            
            self.addDebugLog(type: .info, message: "Background Task rotiert - Status überprüft")
        }
        
        addDebugLog(type: .info, message: "Background Task Rotation gestartet")
        print("✅ Background Task Rotation aktiviert")
    }
    
    private func stopBackgroundTaskRotation() {
        backgroundTaskRotationTimer?.invalidate()
        backgroundTaskRotationTimer = nil
    }
    
    private func startPeriodicalLocationChecks() {
        stopPeriodicalLocationChecks()
        
        // Alle 10 Minuten Location-Check auch bei Stillstand
        periodicalLocationCheckTimer = Timer.scheduledTimer(withTimeInterval: 600.0, repeats: true) { _ in
            guard self.isTracking else { return }
            
            // Auch im Hintergrund Location anfordern
            if UIApplication.shared.applicationState == .background {
                self.requestOneTimeLocationUpdate()
            }
            
            // Bewegungscheck
            self.checkForMovement()
            
            self.addDebugLog(type: .info, message: "Periodischer Location Check ausgeführt")
        }
        
        addDebugLog(type: .info, message: "Periodische Location Checks gestartet")
        print("✅ Periodische Location Checks aktiviert")
    }
    
    private func stopPeriodicalLocationChecks() {
        periodicalLocationCheckTimer?.invalidate()
        periodicalLocationCheckTimer = nil
    }
    
    private func requestOneTimeLocationUpdate() {
        // Ein-maliges Location Update anfordern
        locationManager.requestLocation()
        
        addDebugLog(type: .info, message: "One-time Location Update angefordert")
    }
    
    private func checkForMovement() {
        guard let currentLocation = currentLocation else { return }
        
        let now = Date()
        let timeSinceLastMovement = now.timeIntervalSince(lastMovementCheck)
        
        // Speichere letzte Bewegungszeit für Recovery
        UserDefaults.standard.set(now, forKey: RecoveryKeys.lastMovementTime)
        
        if timeSinceLastMovement > 1800 { // 30 Minuten ohne Bewegung
            // Zusätzliche Maßnahmen bei längerer Inaktivität
            setupProximityRegionMonitoring(around: currentLocation)
            
            addDebugLog(type: .info, message: "Lange Inaktivität erkannt - Proximity Monitoring aktiviert")
        }
        
        lastMovementCheck = now
    }
    
    private func setupProximityRegionMonitoring(around location: CLLocation) {
        // Entferne vorherige Region
        if let region = currentRegion {
            locationManager.stopMonitoring(for: region)
        }
        
        // Neue Region um aktuelle Position (100m Radius)
        let region = CLCircularRegion(
            center: location.coordinate,
            radius: 100.0,
            identifier: "tracking_proximity_\(UUID().uuidString)"
        )
        region.notifyOnEntry = false
        region.notifyOnExit = true
        
        locationManager.startMonitoring(for: region)
        currentRegion = region
        
        addDebugLog(type: .info, message: "Proximity Region Monitoring eingerichtet - Radius: 100m")
        print("✅ Proximity Region Monitoring aktiviert für bessere Bewegungserkennung")
    }
    
    private func checkLocationStatus() {
        let appState = UIApplication.shared.applicationState == .background ? "Background" : "Foreground"
        let trackingActive = isTracking
        let significantChangesActive = isMonitoringSignificantChanges
        let visitsActive = isMonitoringVisits
        
        addDebugLog(type: .info, message: "Status Check - App: \(appState), Tracking: \(trackingActive), SigChanges: \(significantChangesActive), Visits: \(visitsActive)")
        
        // Überprüfe ob alle Services noch laufen
        if isTracking && enableBackgroundTracking && authorizationStatus == .authorizedAlways {
            if !isMonitoringSignificantChanges {
                addDebugLog(type: .error, message: "Significant Location Changes gestoppt - reaktiviere")
                startSignificantLocationChangeMonitoring()
            }
            
            if !isMonitoringVisits {
                addDebugLog(type: .error, message: "Visit Monitoring gestoppt - reaktiviere")
                startVisitMonitoring()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var authorizationStatusString: String {
        switch authorizationStatus {
        case .notDetermined: return "Nicht festgelegt"
        case .denied: return "Verweigert"
        case .restricted: return "Eingeschränkt"
        case .authorizedWhenInUse: return "Bei App-Nutzung"
        case .authorizedAlways: return "Immer"
        @unknown default: return "Unbekannt"
        }
    }
    
    // MARK: - Debug-Funktionen
    
    private func loadDebugSettings() {
        isDebugModeEnabled = UserDefaults.standard.bool(forKey: "debugModeEnabled")
        enableDebugNotifications = UserDefaults.standard.bool(forKey: "enableDebugNotifications")
        backgroundUpdateCount = UserDefaults.standard.integer(forKey: "backgroundUpdateCount")
        
        if let lastUpdateData = UserDefaults.standard.data(forKey: "lastBackgroundUpdate"),
           let lastUpdate = try? JSONDecoder().decode(Date.self, from: lastUpdateData) {
            lastBackgroundUpdate = lastUpdate
        }
    }
    
    private func saveDebugSettings() {
        UserDefaults.standard.set(isDebugModeEnabled, forKey: "debugModeEnabled")
        UserDefaults.standard.set(enableDebugNotifications, forKey: "enableDebugNotifications")
        UserDefaults.standard.set(backgroundUpdateCount, forKey: "backgroundUpdateCount")
        
        if let lastUpdate = lastBackgroundUpdate,
           let data = try? JSONEncoder().encode(lastUpdate) {
            UserDefaults.standard.set(data, forKey: "lastBackgroundUpdate")
        }
    }
    
    func toggleDebugMode() {
        isDebugModeEnabled.toggle()
        
        if isDebugModeEnabled {
            // Für den Aktivierungs-Log den Guard in addDebugLog umgehen
            addDebugLogForced(type: .info, message: "Debug-Modus aktiviert")
            startDebugTimer()
        } else {
            addDebugLogForced(type: .info, message: "Debug-Modus deaktiviert")
            stopDebugTimer()
        }
        
        saveDebugSettings()
    }
    
    func toggleDebugNotifications() {
        enableDebugNotifications.toggle()
        saveDebugSettings()
        
        if enableDebugNotifications {
            addDebugLog(type: .info, message: "Debug-Benachrichtigungen aktiviert")
            requestNotificationPermission()
        } else {
            addDebugLog(type: .info, message: "Debug-Benachrichtigungen deaktiviert")
        }
    }
    
    private func addDebugLog(type: DebugLogType, message: String, coordinate: CLLocation? = nil) {
        guard isDebugModeEnabled else { return }
        addDebugLogForced(type: type, message: message, coordinate: coordinate)
    }
    
    private func addDebugLogForced(type: DebugLogType, message: String, coordinate: CLLocation? = nil) {
        let appState = UIApplication.shared.applicationState == .background ? "Background" : 
                      UIApplication.shared.applicationState == .inactive ? "Inactive" : "Foreground"
        
        let debugCoordinate: DebugLogEntry.DebugCoordinate?
        if let coord = coordinate {
            debugCoordinate = DebugLogEntry.DebugCoordinate(
                latitude: coord.coordinate.latitude,
                longitude: coord.coordinate.longitude,
                accuracy: coord.horizontalAccuracy,
                speed: coord.speed,
                altitude: coord.altitude
            )
        } else {
            debugCoordinate = nil
        }
        
        // Battery-Level korrekt auslesen (Fix für -100% Bug)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel : 0.0
        
        let logEntry = DebugLogEntry(
            timestamp: Date(),
            message: message,
            type: type,
            coordinate: debugCoordinate,
            appState: appState,
            batteryLevel: batteryLevel
        )
        
        DispatchQueue.main.async {
            self.debugLogs.insert(logEntry, at: 0)
            
            // Logs begrenzen
            if self.debugLogs.count > self.maxDebugLogs {
                self.debugLogs = Array(self.debugLogs.prefix(self.maxDebugLogs))
            }
            
            // Background-Updates zählen
            if appState == "Background" && type == .locationUpdate {
                self.backgroundUpdateCount += 1
                self.lastBackgroundUpdate = Date()
                self.saveDebugSettings()
            }
        }
        
        // Persistente Speicherung
        saveDebugLogs()
        
        // Console-Log nur für wichtige Ereignisse
        if type == DebugLogType.error || (type == DebugLogType.info && (message.contains("initialisiert") || message.contains("Berechtigung") || message.contains("gestartet") || message.contains("beendet"))) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            print("🔍 [\(formatter.string(from: logEntry.timestamp))] [\(type.rawValue.uppercased())] \(message)")
        }
        
        // Debug-Benachrichtigung senden
        if enableDebugNotifications && appState == "Background" {
            sendDebugNotification(type: type, message: message)
        }
    }
    
    private func startDebugTimer() {
        stopDebugTimer()
        
        debugTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            if self.isTracking {
                let message = "Tracking aktiv - Distanz: \(String(format: "%.1f", self.totalDistance/1000))km"
                self.addDebugLog(type: .info, message: message, coordinate: self.currentLocation)
            }
        }
    }
    
    private func stopDebugTimer() {
        debugTimer?.invalidate()
        debugTimer = nil
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("❌ Benachrichtigungsberechtigung Fehler: \(error)")
            }
        }
    }
    
    private func sendDebugNotification(type: DebugLogType, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "GPS Debug (\(type.rawValue.capitalized))"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "debug_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func saveDebugLogs() {
        guard !debugLogs.isEmpty else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let debugFile = documentsPath.appendingPathComponent("debug_logs.json")
        
        do {
            let data = try JSONEncoder().encode(Array(debugLogs.prefix(100))) // Nur die letzten 100 Logs speichern
            try data.write(to: debugFile)
        } catch {
            print("❌ Fehler beim Speichern der Debug-Logs: \(error)")
        }
    }
    
    private func loadDebugLogs() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let debugFile = documentsPath.appendingPathComponent("debug_logs.json")
        
        guard let data = try? Data(contentsOf: debugFile),
              let logs = try? JSONDecoder().decode([DebugLogEntry].self, from: data) else {
            return
        }
        
        DispatchQueue.main.async {
            self.debugLogs = logs
        }
    }
    
    func clearDebugLogs() {
        debugLogs.removeAll()
        backgroundUpdateCount = 0
        lastBackgroundUpdate = nil
        saveDebugSettings()
        saveDebugLogs()
        
        addDebugLog(type: .info, message: "Debug-Logs gelöscht")
    }
    
    func exportDebugLogs() -> String {
        print("🔍 DEBUG: Starte Debug-Log Export...")
        print("🔍 DEBUG: Debug-Logs Anzahl: \(debugLogs.count)")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        var exportText = "=== GPS TRACKING DEBUG EXPORT ===\n"
        exportText += "Exportiert am: \(formatter.string(from: Date()))\n"
        exportText += "Debug-Modus aktiv: \(isDebugModeEnabled)\n"
        exportText += "Background-Updates: \(backgroundUpdateCount)\n"
        
        if let lastUpdate = lastBackgroundUpdate {
            exportText += "Letztes Background-Update: \(formatter.string(from: lastUpdate))\n"
        }
        
        exportText += "Tracking-Genauigkeit: \(trackingAccuracy.displayName)\n"
        exportText += "Background-Tracking: \(enableBackgroundTracking ? "Aktiviert" : "Deaktiviert")\n"
        exportText += "Standortberechtigung: \(authorizationStatusString)\n"
        exportText += "Debug-Logs total: \(debugLogs.count)\n"
        exportText += "\n=== LOGS ===\n\n"
        
        // Logs in umgekehrter chronologischer Reihenfolge (neueste zuerst)
        for (index, log) in debugLogs.enumerated() {
            exportText += "[\(formatter.string(from: log.timestamp))] "
            exportText += "[\(log.appState)] "
            exportText += "[\(log.type.rawValue.uppercased())] "
            exportText += "\(log.message)"
            
            if let coord = log.coordinate {
                exportText += " | Lat: \(String(format: "%.6f", coord.latitude))"
                exportText += " Lng: \(String(format: "%.6f", coord.longitude))"
                exportText += " Acc: \(String(format: "%.1f", coord.accuracy))m"
                exportText += " Speed: \(String(format: "%.1f", coord.speed * 3.6))km/h"
            }
            
            exportText += " | Battery: \(String(format: "%.0f", log.batteryLevel * 100))%"
            exportText += "\n"
            
            // Progress-Log alle 20 Einträge
            if (index + 1) % 20 == 0 {
                print("🔍 DEBUG: \(index + 1) Logs verarbeitet...")
            }
        }
        
        print("🔍 DEBUG: Export-Text Länge: \(exportText.count) Zeichen")
        print("🔍 DEBUG: Export fertig, erste 200 Zeichen: \(String(exportText.prefix(200)))")
        
        return exportText
    }
    
    @objc private func appDidEnterBackground() {
        addDebugLog(type: .background, message: "App in Background gewechselt")
        if isTracking {
            addDebugLog(type: .info, message: "Background-Tracking läuft - Berechtigung: \(authorizationStatusString)")
            beginBackgroundTask()
            saveTrackingState()
            if #available(iOS 13.0, *) {
                scheduleBackgroundLocationTask()
            }
        }
    }
    
    @objc private func appWillEnterForeground() {
        addDebugLog(type: .foreground, message: "App in Vordergrund gewechselt")
        if isTracking {
            addDebugLog(type: .info, message: "Tracking im Vordergrund fortgesetzt")
            endBackgroundTask()
            saveTrackingState()
        }
        if hasUnexpectedTermination {
            print("ℹ️ App im Vordergrund - Recovery-Dialog verfügbar")
            checkForCrashRecovery()
        }
    }
    
    // MARK: - Bestehende Funktionen (erweitert mit Debug-Logs)
    
    private func setupLocationManager() {
        locationManager.delegate = self
        updateLocationManagerSettings()
        authorizationStatus = locationManager.authorizationStatus
        // Empfohlen: Automatisches Pausieren deaktivieren für maximale Zuverlässigkeit
        locationManager.pausesLocationUpdatesAutomatically = false
        addDebugLog(type: .info, message: "LocationManager initialisiert")
    }
    
    func updateLocationManagerSettings() {
        locationManager.desiredAccuracy = trackingAccuracy.coreLocationAccuracy
        if useRecommendedSettings {
            locationManager.distanceFilter = trackingAccuracy.recommendedDistanceFilter
        } else {
            locationManager.distanceFilter = customDistanceFilter
        }
        // Background-Location-Updates konfigurieren (nur wenn iOS 9+)
        if #available(iOS 9.0, *) {
            locationManager.allowsBackgroundLocationUpdates = enableBackgroundTracking && 
                (authorizationStatus == .authorizedAlways)
            // Empfohlen: Automatisches Pausieren deaktivieren
            locationManager.pausesLocationUpdatesAutomatically = false
        }
        addDebugLog(type: .info, message: "LocationManager-Einstellungen aktualisiert - Genauigkeit: \(trackingAccuracy.displayName), Filter: \(locationManager.distanceFilter)m, Background: \(locationManager.allowsBackgroundLocationUpdates)")
        if #available(iOS 16.4, *) {
            locationManager.allowsBackgroundLocationUpdates = enableBackgroundTracking && (authorizationStatus == .authorizedAlways)
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = kCLDistanceFilterNone
            if #available(iOS 11.0, *) {
                locationManager.showsBackgroundLocationIndicator = enableBackgroundTracking && (authorizationStatus == .authorizedAlways)
            }
            // Empfohlen: Automatisches Pausieren deaktivieren
            locationManager.pausesLocationUpdatesAutomatically = false
        }
    }
    
    func updateSettings(accuracy: TrackingAccuracy, useRecommended: Bool, customFilter: Double = 10.0, backgroundTracking: Bool? = nil) {
        trackingAccuracy = accuracy
        useRecommendedSettings = useRecommended
        customDistanceFilter = customFilter
        
        if let backgroundTracking = backgroundTracking {
            enableBackgroundTracking = backgroundTracking
        }
        
        updateLocationManagerSettings()
        saveSettings()
    }
    
    private func loadSettings() {
        if let accuracyString = UserDefaults.standard.string(forKey: "trackingAccuracy"),
           let accuracy = TrackingAccuracy(rawValue: accuracyString) {
            trackingAccuracy = accuracy
        }
        
        useRecommendedSettings = UserDefaults.standard.object(forKey: "useRecommendedSettings") as? Bool ?? true
        customDistanceFilter = UserDefaults.standard.double(forKey: "customDistanceFilter")
        enableBackgroundTracking = UserDefaults.standard.object(forKey: "enableBackgroundTracking") as? Bool ?? true
        enableEnhancedBackgroundTracking = UserDefaults.standard.object(forKey: "enableEnhancedBackgroundTracking") as? Bool ?? true
        enableIntelligentPointSelection = UserDefaults.standard.object(forKey: "enableIntelligentPointSelection") as? Bool ?? true
        automaticOptimizationEnabled = UserDefaults.standard.object(forKey: "automaticOptimizationEnabled") as? Bool ?? true
        
        // Lade Optimierungslevel
        if let optimizationString = UserDefaults.standard.string(forKey: "optimizationLevel") {
            print("🔧 Lade gespeicherte Optimierung: \(optimizationString)")
            switch optimizationString {
            case "conservative":
                optimizationLevel = .level1
                currentAutoOptimizationLevel = .level1
            case "balanced":
                optimizationLevel = .level2
                currentAutoOptimizationLevel = .level2
            case "aggressive":
                optimizationLevel = .level3
                currentAutoOptimizationLevel = .level3
            case "express":
                optimizationLevel = .level4
                currentAutoOptimizationLevel = .level4
            case "highway":
                optimizationLevel = .level5
                currentAutoOptimizationLevel = .level5
            default:
                optimizationLevel = .level2
                currentAutoOptimizationLevel = .level2
            }
        } else {
            print("🔧 Keine gespeicherte Optimierung gefunden - verwende Balanced")
        }
        
        print("🔧 Einstellungen geladen - Automatik: \(automaticOptimizationEnabled), Level: \(optimizationLevel.maxDeviation)")
        
        if customDistanceFilter == 0 {
            customDistanceFilter = 10.0
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(trackingAccuracy.rawValue, forKey: "trackingAccuracy")
        UserDefaults.standard.set(useRecommendedSettings, forKey: "useRecommendedSettings")
        UserDefaults.standard.set(customDistanceFilter, forKey: "customDistanceFilter")
        UserDefaults.standard.set(enableBackgroundTracking, forKey: "enableBackgroundTracking")
        UserDefaults.standard.set(enableEnhancedBackgroundTracking, forKey: "enableEnhancedBackgroundTracking")
        UserDefaults.standard.set(enableIntelligentPointSelection, forKey: "enableIntelligentPointSelection")
        UserDefaults.standard.set(automaticOptimizationEnabled, forKey: "automaticOptimizationEnabled")
        
        // Speichere Optimierungslevel
        let optimizationString: String
        switch optimizationLevel.maxDeviation {
        case 5.0: optimizationString = "conservative"
        case 10.0: optimizationString = "balanced"
        case 20.0: optimizationString = "aggressive"
        case 30.0: optimizationString = "highway"
        default: optimizationString = "balanced"
        }
        UserDefaults.standard.set(optimizationString, forKey: "optimizationLevel")
        
        print("🔧 Einstellungen gespeichert - Automatik: \(automaticOptimizationEnabled), Level: \(optimizationString) (maxDeviation: \(optimizationLevel.maxDeviation))")
    }
    
    func requestLocationPermission() {
        print("requestLocationPermission() aufgerufen, Status: \(authorizationStatus)")
        // Erst "When In Use" anfordern, dann bei Bedarf "Always"
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse && enableBackgroundTracking {
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    func requestAlwaysAuthorization() {
        guard authorizationStatus == .authorizedWhenInUse else {
            print("⚠️ 'When In Use' Berechtigung erforderlich vor 'Always' Berechtigung")
            return
        }
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Protected Tracking Methods
    
    /// Sichere Tracking-Start-Methode mit Benutzerschutz
    func startTrackingProtected(tripName: String, userInitiated: Bool = true) {
        // NEU: Prüfe, ob bereits eine aktive Reise existiert
        let fetchRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "isActive == true")
            if let activeTrips = try? context.fetch(fetchRequest), let activeTrip = activeTrips.first {
                print("⚠️ Es existiert bereits eine aktive Reise: \(activeTrip.name ?? "Unbenannt") – Tracking wird fortgesetzt.")
                startTracking(for: activeTrip)
                return
            }
        
        // Verhindere doppeltes Starten
        guard !isTracking else {
            addDebugLogForced(type: .warning, message: "SCHUTZ: Tracking bereits aktiv - Ignoriere doppelten Start-Versuch")
            return
        }
        
        // Markiere als benutzerinitiiert
        trackingStartedByUser = userInitiated
        lastTrackingStateChange = Date()
        
        addDebugLogForced(type: .info, message: "SCHUTZ: Tracking-Start \(userInitiated ? "vom Benutzer" : "automatisch") initiiert")
        
        // Originale startTracking Methode aufrufen
        startTracking(tripName: tripName)
    }
    
    /// Sichere Tracking-Stop-Methode mit Benutzerschutz
    func stopTrackingProtected(userInitiated: Bool = true, reason: String = "Benutzer") {
        // Nur stoppen wenn Tracking aktiv ist
        guard isTracking else {
            addDebugLogForced(type: .warning, message: "SCHUTZ: Kein aktives Tracking - Ignoriere Stop-Versuch (Grund: \(reason))")
            return
        }
        
        // Schutz vor zu schnellen State-Änderungen
        let timeSinceLastChange = Date().timeIntervalSince(lastTrackingStateChange)
        if timeSinceLastChange < 5.0 && !userInitiated {
            addDebugLogForced(type: .warning, message: "SCHUTZ: Zu schnelle Tracking-Änderung verhindert (nur \(String(format: "%.1f", timeSinceLastChange))s seit letzter Änderung)")
            return
        }
        
        // Zusätzlicher Schutz bei automatischen Stops
        if !userInitiated && autoStopProtectionActive {
            switch trackingProtectionLevel {
            case .high:
                // Bei hohem Schutz: Automatische Stops komplett verhindern
                addDebugLogForced(type: .warning, message: "SCHUTZ: Automatischer Stop verhindert (Schutzlevel: hoch)")
                return
            case .medium:
                // Bei mittlerem Schutz: Nur bei benutzerinitiiertem Tracking erlauben
                if trackingStartedByUser {
                    addDebugLogForced(type: .warning, message: "SCHUTZ: Automatischer Stop für benutzerinitiiertes Tracking verhindert")
                    return
                }
            case .low:
                // Bei niedrigem Schutz: Warnung aber Ausführung
                addDebugLogForced(type: .warning, message: "WARNUNG: Automatischer Stop wird ausgeführt (Schutzlevel: niedrig)")
            }
        }
        
        // Log für legitime Stops
        addDebugLogForced(type: .info, message: "SCHUTZ: Tracking-Stop \(userInitiated ? "vom Benutzer" : "automatisch") - Grund: \(reason)")
        
        lastTrackingStateChange = Date()
        trackingStartedByUser = false
        
        // Originale stopTracking Methode aufrufen
        stopTracking()
    }
    
    // MARK: - Original Tracking Methods (jetzt protected)
    
    func startTracking(tripName: String) {
        // Prüfe Berechtigung - Always für Background, WhenInUse für Foreground
        let hasPermission = authorizationStatus == .authorizedAlways || 
                           (authorizationStatus == .authorizedWhenInUse && !enableBackgroundTracking)
        
        guard hasPermission else {
            addDebugLog(type: .error, message: "⚠️ Unzureichende Standortberechtigung für Tracking")
            requestLocationPermission()
            return
        }
        
        // Verhindere doppeltes Starten (zusätzliche Absicherung)
        guard !isTracking else {
            addDebugLog(type: .warning, message: "Tracking bereits aktiv - Ignoriere doppelten Start-Versuch")
            return
        }
        
        let trip = Trip(context: context)
        trip.name = tripName
        trip.startDate = Date()
        trip.endDate = nil
        trip.isActive = true
        trip.totalDistance = 0.0
        trip.gpsTrackingEnabled = true
        
        // Trip ID generieren für Recovery
        if trip.id == nil {
            trip.id = UUID()
        }
        
        // Core Data erst speichern, dann State setzen
        do {
            try context.save()
            
            // Nur bei erfolgreichem Speichern State setzen
            currentTrip = trip
            isTracking = true
            totalDistance = 0.0
            
            // Hybrid Storage: Live-Segment starten
            if enableHybridStorage {
                Task { @MainActor in
                    currentLiveSegment = trackStorageManager?.startLiveSegment(for: trip)
                }
                addDebugLog(type: .info, message: "Hybrid Storage aktiviert - Live-Segment erstellt")
            }
            
            // Background-Updates aktivieren falls möglich
            if enableBackgroundTracking && authorizationStatus == .authorizedAlways {
                if #available(iOS 9.0, *) {
                    locationManager.allowsBackgroundLocationUpdates = true
                    addDebugLog(type: .info, message: "Background-Location-Updates aktiviert")
                }
            }
            
            // Background Task starten
            beginBackgroundTask()
            
            // Location Manager starten
            locationManager.startUpdatingLocation()
            
            // Enhanced Background Location Monitoring für robustes Tracking
            if enableBackgroundTracking && authorizationStatus == .authorizedAlways {
                if enableEnhancedBackgroundTracking {
                    startEnhancedBackgroundLocationMonitoring()
                } else {
                    startSignificantLocationChangeMonitoring()
                }
            }
            
            // Background Task scheduling
            if #available(iOS 13.0, *) {
                scheduleBackgroundLocationTask()
            }
            
            // Recovery-Daten speichern
            saveTrackingState()
            
            let trackingMode = (enableBackgroundTracking && authorizationStatus == .authorizedAlways) ? 
                              "mit Background-Tracking" : "nur im Vordergrund"
            
            addDebugLog(type: .trackingStart, message: "Tracking gestartet für '\(tripName)' (\(trackingMode))")
            
            // Debug-Timer starten
            if isDebugModeEnabled {
                startDebugTimer()
            }
            
            // Watchdog starten
            startWatchdog()
            
        } catch {
            addDebugLog(type: .error, message: "Fehler beim Speichern der Reise: \(error.localizedDescription)")
            context.delete(trip)
            return
        }
    }
    
    func startTracking(for trip: Trip) {
        guard trip.gpsTrackingEnabled else {
            print("GPS-Tracking für Reise '\(trip.name ?? "")' ist deaktiviert")
            return
        }
        
        // Prüfe Berechtigung - Always für Background, WhenInUse für Foreground
        let hasPermission = authorizationStatus == .authorizedAlways || 
                           (authorizationStatus == .authorizedWhenInUse && !enableBackgroundTracking)
        
        guard hasPermission else {
            print("⚠️ Unzureichende Standortberechtigung für Tracking")
            requestLocationPermission()
            return
        }
        
        // Verhindere doppeltes Starten
        guard !isTracking else {
            print("Tracking bereits aktiv")
            return
        }
        
        // Hybrid Storage: Live-Segment starten
        if enableHybridStorage {
            Task { @MainActor in
                currentLiveSegment = trackStorageManager?.startLiveSegment(for: trip)
            }
            addDebugLog(type: .info, message: "Hybrid Storage aktiviert - Live-Segment erstellt")
        }
        
        // Background-Updates aktivieren falls möglich
        if enableBackgroundTracking && authorizationStatus == .authorizedAlways {
            if #available(iOS 9.0, *) {
                locationManager.allowsBackgroundLocationUpdates = true
                // Empfohlen: Automatisches Pausieren deaktivieren
                locationManager.pausesLocationUpdatesAutomatically = false
                print("✅ Background-Location-Updates aktiviert")
            }
        }
        
        currentTrip = trip
        isTracking = true
        totalDistance = trip.totalDistance
        
        locationManager.startUpdatingLocation()
        
        let trackingMode = (enableBackgroundTracking && authorizationStatus == .authorizedAlways) ? 
                          "mit Background-Tracking" : "nur im Vordergrund"
        print("✅ GPS-Tracking für Reise '\(trip.name ?? "")' gestartet (\(trackingMode))")
    }
    
    func stopTracking() {
        // Verhindere doppeltes Stoppen
        guard isTracking else {
            addDebugLog(type: .info, message: "Tracking bereits gestoppt - Ignoriere Stop-Anfrage")
            return
        }
        
        addDebugLogForced(type: .info, message: "TRACKING-STOP: Beginne Tracking-Beendigung...")
        
        // Background-Updates deaktivieren
        if #available(iOS 9.0, *) {
            locationManager.allowsBackgroundLocationUpdates = false
            // Empfohlen: Automatisches Pausieren deaktivieren
            locationManager.pausesLocationUpdatesAutomatically = false
            addDebugLog(type: .info, message: "Background-Location-Updates deaktiviert")
        }
        
        // Enhanced Background Location Monitoring stoppen
        stopEnhancedBackgroundLocationMonitoring()
        
        // Background Task beenden
        endBackgroundTask()
        
        // Zuerst Location Manager stoppen
        locationManager.stopUpdatingLocation()
        
        // State sofort zurücksetzen für UI-Konsistenz
        isTracking = false
        
        // Debug-Timer stoppen
        stopDebugTimer()
        
        // Hybrid Storage: Live-Segment beenden
        if enableHybridStorage, let liveSegment = currentLiveSegment {
            Task { @MainActor in
                trackStorageManager?.closeLiveSegment(liveSegment)
            }
            currentLiveSegment = nil
            addDebugLog(type: .info, message: "Hybrid Storage: Live-Segment beendet")
        }
        
        // Aktuelle Reise beenden - mit Fehlerbehandlung
        if let trip = currentTrip {
            let tripName = trip.name ?? "Unbenannt"
            let finalDistance = totalDistance
            
            trip.endDate = Date()
            trip.isActive = false
            trip.totalDistance = finalDistance
            
            do {
                try context.save()
                addDebugLog(type: .trackingStop, message: "TRACKING-STOP: Reise '\(tripName)' erfolgreich beendet - Distanz: \(String(format: "%.1f", finalDistance/1000))km")
            } catch {
                addDebugLog(type: .error, message: "FEHLER: Tracking-Stop - Fehler beim Speichern der Reise: \(error.localizedDescription)")
                // Versuche Recovery: Reise nicht als beendet markieren
                trip.isActive = true
                trip.endDate = nil
                addDebugLogForced(type: .warning, message: "RECOVERY: Reise wieder als aktiv markiert nach Speicherfehler")
            }
        } else {
            addDebugLog(type: .warning, message: "TRACKING-STOP: Keine aktive Reise gefunden beim Stoppen")
        }
        
        // Recovery-Daten löschen
        cleanupRecoveryData()
        
        // Cleanup am Ende
        currentTrip = nil
        totalDistance = 0.0
        lastLocation = nil
        
        addDebugLogForced(type: .info, message: "TRACKING-STOP: Beendigung abgeschlossen")
        
        // Watchdog stoppen
        stopWatchdog()
    }
    
    func getCurrentLocationName() async -> String {
        guard let location = currentLocation else { return "Unbekannter Ort" }
        
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let name = [placemark.locality, placemark.country]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                return name.isEmpty ? "Unbekannter Ort" : name
            }
        } catch {
            print("Geocoding Fehler: \(error)")
        }
        
        return "Unbekannter Ort"
    }
    
    // Besuchte Länder aus GPS-Daten einer Reise ermitteln
    func getVisitedCountries(for trip: Trip) async -> Set<String> {
        var countries = Set<String>()
        
        // Alle Memories der Reise abrufen
        let memories = (trip.memories?.allObjects as? [Memory]) ?? []
        
        // Für jede Memory das Land aus den Koordinaten ermitteln
        for memory in memories {
            if memory.latitude != 0 && memory.longitude != 0 {
                let location = CLLocation(latitude: memory.latitude, longitude: memory.longitude)
                
                do {
                    let geocoder = CLGeocoder()
                    let placemarks = try await geocoder.reverseGeocodeLocation(location)
                    
                    if let country = placemarks.first?.country {
                        countries.insert(country)
                    }
                } catch {
                    print("Geocoding Fehler für Memory '\(memory.title ?? "")': \(error)")
                }
            }
        }
        
        // Auch Routenpunkte berücksichtigen (für genauere Erfassung)
        let routePoints = (trip.routePoints?.allObjects as? [RoutePoint]) ?? []
        let samplePoints = Array(routePoints.prefix(10)) // Nur erste 10 Punkte für Performance
        
        for point in samplePoints {
            if point.latitude != 0 && point.longitude != 0 {
                let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
                
                do {
                    let geocoder = CLGeocoder()
                    let placemarks = try await geocoder.reverseGeocodeLocation(location)
                    
                    if let country = placemarks.first?.country {
                        countries.insert(country)
                    }
                } catch {
                    print("Geocoding Fehler für RoutePoint: \(error)")
                }
            }
        }
        
        return countries
    }
    
    // Funktion zum automatischen Aktualisieren der besuchten Länder einer Reise
    func updateVisitedCountries(for trip: Trip) async {
        let countries = await getVisitedCountries(for: trip)
        
        if !countries.isEmpty {
            await MainActor.run {
                trip.visitedCountries = countries.sorted().joined(separator: ", ")
                
                do {
                    try context.save()
                    print("Besuchte Länder für '\(trip.name ?? "Reise")' aktualisiert: \(countries.joined(separator: ", "))")
                } catch {
                    print("Fehler beim Speichern der besuchten Länder: \(error)")
                }
            }
        }
    }
    
    // GPX-Export-Funktionalität
    func exportTripAsGPX(_ trip: Trip) -> String? {
        guard let routePoints = trip.routePoints?.allObjects as? [RoutePoint],
              !routePoints.isEmpty else {
            print("Keine Routenpunkte für Export verfügbar")
            return nil
        }
        
        let sortedPoints = routePoints.sorted { 
            ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) 
        }
        
        let gpxContent = generateGPXContent(for: trip, with: sortedPoints)
        return gpxContent
    }
    
    private func generateGPXContent(for trip: Trip, with routePoints: [RoutePoint]) -> String {
        let dateFormatter = ISO8601DateFormatter()
        let creationTime = dateFormatter.string(from: trip.startDate ?? Date())
        
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Journiary" 
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"
             xmlns="http://www.topografix.com/GPX/1/1" 
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <metadata>
            <name>\(trip.name ?? "Unbenannte Reise")</name>
            <time>\(creationTime)</time>
          </metadata>
          <trk>
            <name>\(trip.name ?? "Unbenannte Reise")</name>
            <type>walking</type>
            <trkseg>
        """
        
        for point in routePoints {
            let timestamp = dateFormatter.string(from: point.timestamp ?? Date())
            
            gpx += """
              <trkpt lat="\(point.latitude)" lon="\(point.longitude)">
                <ele>\(point.altitude)</ele>
                <time>\(timestamp)</time>
            """
            
            if point.speed > 0 {
                gpx += """
                <extensions>
                  <speed>\(point.speed)</speed>
                </extensions>
            """
            }
            
            gpx += "</trkpt>\n"
        }
        
        gpx += """
            </trkseg>
          </trk>
        </gpx>
        """
        
        return gpx
    }
    
    func shareGPXFile(for trip: Trip) -> URL? {
        guard let gpxContent = exportTripAsGPX(trip) else { 
            print("❌ GPX-Content konnte nicht generiert werden")
            return nil 
        }
        
        let fileName = "\(trip.name ?? "Trip")_\(DateFormatter.fileNameFormatter.string(from: trip.startDate ?? Date()))"
        
        #if DEBUG
        print("📄 Erstelle GPX-Datei: \(fileName)")
        #endif
        
        // Verwende den verbesserten GPXExporter
        return GPXExporter.saveGPXToFile(gpxContent: gpxContent, fileName: fileName)
    }
    
    private func addRoutePoint(location: CLLocation) {
        guard let trip = currentTrip else { 
            addDebugLog(type: .error, message: "Keine aktive Reise für RoutePoint")
            return 
        }
        
        // Intelligente Punkteauswahl wenn aktiviert
        if enableIntelligentPointSelection {
            // Bestimme Optimierungseinstellungen (automatisch oder manuell)
            let settings: TrackOptimizer.OptimizationSettings
            
            if automaticOptimizationEnabled {
                settings = getAutomaticOptimizationSettings(for: location)
            } else {
                settings = optimizationLevel
            }
            
            let shouldSave = TrackOptimizer.shouldSavePoint(
                newLocation: location,
                lastSavedLocation: lastSavedLocation,
                previousLocation: previousLocation,
                settings: settings
            )
            
            if !shouldSave {
                // Punkt wird nicht gespeichert, aber für Distanzmessung verwenden
                if let lastLoc = lastLocation {
                    let distance = location.distance(from: lastLoc)
                    totalDistance += distance
                }
                lastLocation = location
                previousLocation = lastLocation
                currentSpeed = max(0, location.speed * 3.6)
                
                addDebugLog(type: .locationUpdate, message: "GPS-Update empfangen, aber Punkt übersprungen (intelligente Auswahl)", coordinate: location)
                return
            }
        }
        
        let routePoint = RoutePoint(context: context)
        routePoint.latitude = location.coordinate.latitude
        routePoint.longitude = location.coordinate.longitude
        routePoint.timestamp = location.timestamp
        routePoint.altitude = location.altitude
        routePoint.speed = max(0, location.speed)
        routePoint.trip = trip
        
        // Hybrid Storage: Punkt zum Live-Segment hinzufügen
        if enableHybridStorage, let liveSegment = currentLiveSegment {
            Task { @MainActor in
                trackStorageManager?.addPointToLiveSegment(routePoint, segment: liveSegment)
            }
        }
        
        // Distanz berechnen
        if let lastLoc = lastLocation {
            let distance = location.distance(from: lastLoc)
            totalDistance += distance
            
            addDebugLog(type: .locationUpdate, message: "RoutePoint hinzugefügt - Distanz seit letztem Punkt: \(String(format: "%.1f", distance))m", coordinate: location)
        } else {
            addDebugLog(type: .locationUpdate, message: "Erster RoutePoint der Reise", coordinate: location)
        }
        
        // Aktualisiere Tracking-Variablen
        previousLocation = lastLocation
        lastLocation = location
        lastSavedLocation = location
        currentSpeed = max(0, location.speed * 3.6) // m/s zu km/h
        
        do {
            try context.save()
            
            // Recovery-Daten nach erfolgreichem Speichern aktualisieren
            saveTrackingState()
            
        } catch {
            addDebugLog(type: .error, message: "Fehler beim Speichern des RoutePoints: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Automatische Optimierungsauswahl
    
    /// Wählt automatisch die optimalen Einstellungen basierend auf der aktuellen Geschwindigkeit
    private func getAutomaticOptimizationSettings(for location: CLLocation) -> TrackOptimizer.OptimizationSettings {
        let speedKmh = max(location.speed, 0) * 3.6 // m/s zu km/h
        
        // Benutzerdefinierte Schwellenwerte laden
        let walkingMax = UserDefaults.standard.object(forKey: "customWalkingMax") as? Double ?? 20.0
        let cyclingMax = UserDefaults.standard.object(forKey: "customCyclingMax") as? Double ?? 35.0
        let mopedMax = UserDefaults.standard.object(forKey: "customMopedMax") as? Double ?? 60.0
        let drivingMax = UserDefaults.standard.object(forKey: "customDrivingMax") as? Double ?? 87.0
        
        let newSettings: TrackOptimizer.OptimizationSettings
        if speedKmh < walkingMax {
            newSettings = .level1
            addDebugLog(type: .info, message: "Auto-Optimierung: Lvl 1 (Geschwindigkeit: \(String(format: "%.1f", speedKmh)) km/h)")
        } else if speedKmh < cyclingMax {
            newSettings = .level2
            addDebugLog(type: .info, message: "Auto-Optimierung: Lvl 2 (Geschwindigkeit: \(String(format: "%.1f", speedKmh)) km/h)")
        } else if speedKmh < mopedMax {
            newSettings = .level3
            addDebugLog(type: .info, message: "Auto-Optimierung: Lvl 3 (Geschwindigkeit: \(String(format: "%.1f", speedKmh)) km/h)")
        } else if speedKmh < drivingMax {
            newSettings = .level4
            addDebugLog(type: .info, message: "Auto-Optimierung: Lvl 4 (Geschwindigkeit: \(String(format: "%.1f", speedKmh)) km/h)")
        } else {
            newSettings = .level5
            addDebugLog(type: .info, message: "Auto-Optimierung: Lvl 5 (Geschwindigkeit: \(String(format: "%.1f", speedKmh)) km/h)")
        }
        
        // Hysterese implementieren: Wechsel nur bei deutlicher Änderung
        let currentDeviation = currentAutoOptimizationLevel.maxDeviation
        let newDeviation = newSettings.maxDeviation
        
        // Mindestens 5.0 Unterschied für Wechsel (verhindert ständiges Umschalten)
        if abs(newDeviation - currentDeviation) >= 5.0 {
            let previousLevel = optimizationLevelName(currentAutoOptimizationLevel)
            let newLevel = optimizationLevelName(newSettings)
            
            addDebugLog(type: .info, message: "Auto-Optimierung wechselt: \(previousLevel) → \(newLevel)")
            currentAutoOptimizationLevel = newSettings
            
            // Update UI
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
        
        return currentAutoOptimizationLevel
    }
    
    /// Hilfsfunktion um Namen des Optimierungslevels zu erhalten
    private func optimizationLevelName(_ settings: TrackOptimizer.OptimizationSettings) -> String {
        switch settings.maxDeviation {
        case 5.0: return "Lvl 1"
        case 10.0: return "Lvl 2"
        case 20.0: return "Lvl 3"
        case 25.0: return "Lvl 4"
        case 30.0: return "Lvl 5"
        default: return "Unbekannt"
        }
    }
    
    /// Aktuelle automatische Optimierung (für UI)
    var currentAutomaticOptimization: String {
        guard automaticOptimizationEnabled else { return "Deaktiviert" }
        return optimizationLevelName(currentAutoOptimizationLevel)
    }
    
    // MARK: - Watchdog-Mechanismus
    private func startWatchdog() {
        stopWatchdog()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: watchdogInterval, repeats: true) { [weak self] _ in
            self?.checkLocationWatchdog()
        }
    }
    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }
    private func checkLocationWatchdog() {
        guard isTracking else { return }
        let now = Date()
        let lastUpdate = lastLocation?.timestamp ?? now
        if now.timeIntervalSince(lastUpdate) > watchdogTimeout {
            addDebugLog(type: .warning, message: "Watchdog: Kein Location-Update seit 15 Minuten – Recovery wird getriggert")
            restartLocationManager()
        }
    }
    private func restartLocationManager() {
        locationManager.stopUpdatingLocation()
        locationManager.startUpdatingLocation()
        addDebugLog(type: .info, message: "LocationManager durch Watchdog neu gestartet")
    }
    
    // Nach jedem Aufruf von startUpdatingLocation()
    private func startLocationUpdatesIfNeeded() {
        locationManager.startUpdatingLocation()
        // Reduzierte Logs - nur bei Debug-Bedarf
        // print("startUpdatingLocation() aufgerufen (direkt)")
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Reduzierte Logs - nur bei wichtigen Updates (entfernt für cleanes Log)
        guard let location = locations.last else { return }
        currentLocation = location
        
        // Debug-Log für Location-Update
        let appState = UIApplication.shared.applicationState == .background ? "Background" : "Foreground"
        let updateSource = determineLocationUpdateSource(appState: appState)
        
        addDebugLog(type: .locationUpdate, message: "\(updateSource) empfangen (\(appState)) - Accuracy: \(String(format: "%.1f", location.horizontalAccuracy))m", coordinate: location)
        
        if isTracking {
            addRoutePoint(location: location)
            
            // Bewegungszeit aktualisieren bei signifikanter Bewegung
            if let lastLoc = lastLocation {
                let distance = location.distance(from: lastLoc)
                if distance > 10.0 { // Mindestens 10m Bewegung
                    lastMovementCheck = Date()
                    UserDefaults.standard.set(Date(), forKey: RecoveryKeys.lastMovementTime)
                }
            }
            
            // Background Task verlängern wenn nötig
            // if appState == "Background" {
            //     beginBackgroundTask() // ENTFERNT, um Task-Flut zu verhindern
            // }
        } else if hasUnexpectedTermination {
            // Tracking war unterbrochen - prüfe Recovery (reduzierte Logs)
            checkForCrashRecovery()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let appState = UIApplication.shared.applicationState == .background ? "Background" : "Foreground"
        
        if visit.departureDate == Date.distantFuture {
            // Ankunft an einem Ort
            addDebugLog(type: .locationUpdate, message: "Visit Started (\(appState)) - Lat: \(String(format: "%.6f", visit.coordinate.latitude)), Lng: \(String(format: "%.6f", visit.coordinate.longitude))")
        } else {
            // Verlassen eines Ortes
            addDebugLog(type: .locationUpdate, message: "Visit Ended (\(appState)) - Duration: \(String(format: "%.1f", visit.departureDate.timeIntervalSince(visit.arrivalDate)))s")
            
            // Bei Verlassen eines Ortes: One-Time Location Update anfordern
            if isTracking && appState == "Background" {
                requestOneTimeLocationUpdate()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region.identifier.hasPrefix("tracking_proximity_") {
            let appState = UIApplication.shared.applicationState == .background ? "Background" : "Foreground"
            addDebugLog(type: .locationUpdate, message: "Proximity Region verlassen (\(appState)) - Bewegung erkannt")
            
            // Bewegung erkannt - Location Update anfordern
            if isTracking && appState == "Background" {
                requestOneTimeLocationUpdate()
                lastMovementCheck = Date()
                UserDefaults.standard.set(Date(), forKey: RecoveryKeys.lastMovementTime)
            }
        }
    }
    
    private func determineLocationUpdateSource(appState: String) -> String {
        if appState == "Background" {
            if isMonitoringSignificantChanges {
                return "Significant Change"
            } else if isMonitoringVisits {
                return "Visit Monitoring"
            } else {
                return "Background Update"
            }
        } else {
            return "Standard Update"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        let previousStatus = authorizationStatus
        authorizationStatus = status
        
        // Nur bei wichtigen Änderungen loggen
        if previousStatus != status {
            print("📍 Berechtigung geändert: \(previousStatus) → \(status)")
        }
        
        addDebugLogForced(type: .permission, message: "BERECHTIGUNG: Änderung von \(previousStatus) zu \(status)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            addDebugLog(type: .permission, message: "'When In Use' oder 'Always' Berechtigung erhalten")
            updateLocationManagerSettings()
            startLocationUpdatesIfNeeded()
            // ... Rest wie gehabt ...
            
        case .denied, .restricted:
            addDebugLog(type: .permission, message: "BERECHTIGUNG: Standortberechtigung verweigert oder eingeschränkt")
            
            // WICHTIG: Kein automatisches Stoppen des Trackings bei Berechtigungsänderung
            // Das könnte zur selbstbeendenden Reise führen
            if isTracking {
                addDebugLogForced(type: .warning, message: "SCHUTZ: Tracking läuft weiter trotz Berechtigungsverlust - Benutzer muss manuell stoppen")
            } else {
                locationManager.stopUpdatingLocation()
            }
            
        case .notDetermined:
            addDebugLog(type: .permission, message: "Standortberechtigung noch nicht festgelegt")
            
        @unknown default:
            addDebugLog(type: .permission, message: "Unbekannter Standortberechtigungsstatus: \(status)")
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let errorCode = (error as NSError).code
        let errorDomain = (error as NSError).domain
        
        addDebugLogForced(type: .error, message: "LOCATION-FEHLER: \(error.localizedDescription) (Code: \(errorCode), Domain: \(errorDomain))")
        
        // Unterscheide zwischen kritischen und unkritischen Fehlern
        if errorDomain == kCLErrorDomain {
            switch errorCode {
            case CLError.locationUnknown.rawValue:
                // Temporärer Fehler - nicht kritisch, Tracking weiterführen
                addDebugLog(type: .warning, message: "SCHUTZ: Temporärer Location-Fehler - Tracking läuft weiter")
                
            case CLError.denied.rawValue:
                // Berechtigung verweigert - bereits in didChangeAuthorization behandelt
                addDebugLog(type: .warning, message: "SCHUTZ: Berechtigung verweigert - kein automatischer Tracking-Stop")
                
            case CLError.network.rawValue:
                // Netzwerkfehler - nicht kritisch für GPS
                addDebugLog(type: .warning, message: "SCHUTZ: Netzwerk-Fehler - GPS-Tracking läuft weiter")
                
            default:
                // Unbekannter Fehler - Vorsichtig bleiben, aber nicht automatisch stoppen
                addDebugLogForced(type: .error, message: "UNBEKANNTER LOCATION-FEHLER: Code \(errorCode) - Tracking läuft weiter")
            }
        }
        
        // WICHTIG: Kein automatisches Stoppen des Trackings bei Location-Fehlern
        // Das war möglicherweise die Ursache für selbstbeendende Reisen
        if isTracking {
            addDebugLogForced(type: .info, message: "SCHUTZ: Tracking bleibt trotz Location-Fehler aktiv")
        }
    }
}

extension DateFormatter {
    static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return formatter
    }()
} 