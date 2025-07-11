import Foundation
import SwiftUI
import Network
import os.log
import CoreData

/// Verwaltet automatische Sync-Trigger für verschiedene App-Lifecycle-Events.
/// 
/// Diese Klasse implementiert Phase 5.2 und 10.3 des Implementierungsplans:
/// "Automatische Trigger: Automatisches Starten eines Sync-Zyklus beim App-Start 
/// und potenziell bei anderen wichtigen Lebenszyklus-Events der App."
/// 
/// Phase 10.3: Intelligente Sync-Trigger mit kontextbasierter Strategie-Auswahl
@MainActor
final class SyncTriggerManager: ObservableObject {
    
    // MARK: - Properties
    
    private let syncManager = SyncManager.shared
    private let logger = Logger(subsystem: "com.journiary.syncTrigger", category: "SyncTriggerManager")
    
    /// Toast-Manager für visuelles Feedback (Phase 5.3)
    weak var toastManager: SyncToastManager?
    
    /// Zeitstempel des letzten Sync-Versuchs
    @Published var lastSyncAttempt: Date?
    
    /// Aktueller Sync-Status
    @Published var isSyncing: Bool = false
    
    /// Fehler des letzten Sync-Versuchs
    @Published var lastSyncError: String?
    
    // MARK: - Phase 10.3: Intelligente Trigger-Konfiguration
    
    /// Konfigurierbare Trigger-Bedingungen
    @Published var triggerConditions: [TriggerCondition] = []
    
    /// Monitoring-Status
    @Published var isMonitoring: Bool = false
    
    /// Anhängige Datenänderungs-Counter
    private var pendingDataChanges: Int = 0
    
    /// Debounce-Timer für Datenänderungs-Sync
    private var dataChangeDebounceTimer: Timer?
    
    /// Background-Task-Identifier
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Bestehende Properties
    
    /// Netzwerkmonitor für Verbindungsänderungen
    private var networkMonitor: NWPathMonitor?
    private var monitorQueue: DispatchQueue?
    
    /// Timer für periodische Synchronisation
    private var periodicSyncTimer: Timer?
    
    /// Minimum-Intervall zwischen Sync-Versuchen (in Sekunden)
    private let minimumSyncInterval: TimeInterval = 60 // 1 Minute
    
    /// Intervall für periodische Synchronisation (in Sekunden)
    private let periodicSyncInterval: TimeInterval = 300 // 5 Minuten
    
    /// Verzögerung für App-Start-Sync (in Sekunden)
    private let startupSyncDelay: TimeInterval = 2.0
    
    /// Verzögerung für Foreground-Sync (in Sekunden)
    private let foregroundSyncDelay: TimeInterval = 1.0
    
    // MARK: - Phase 10.3: Neue Strukturen
    
    /// Trigger-Bedingung für intelligente Synchronisation
    struct TriggerCondition: Identifiable {
        let id = UUID()
        let type: TriggerType
        let isEnabled: Bool
        let threshold: Double
        let description: String
    }
    
    /// Verfügbare Trigger-Typen
    enum TriggerType: CaseIterable {
        case networkChange
        case appLaunch
        case appBackground
        case dataChange
        case timeInterval
        case userAction
        
        var displayName: String {
            switch self {
            case .networkChange: return "Netzwerkänderungen"
            case .appLaunch: return "App-Start"
            case .appBackground: return "App-Hintergrund"
            case .dataChange: return "Datenänderungen"
            case .timeInterval: return "Zeitintervall"
            case .userAction: return "Benutzeraktionen"
            }
        }
    }
    
    /// Intelligente Sync-Strategien
    enum SyncStrategy {
        case minimal    // Nur kritische Änderungen
        case standard   // Normale Synchronisation
        case full       // Vollständige Synchronisation
        
        var description: String {
            switch self {
            case .minimal: return "Minimal"
            case .standard: return "Standard"
            case .full: return "Vollständig"
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        setupDefaultTriggerConditions()
        setupNetworkMonitoring()
        logger.info("SyncTriggerManager initialisiert mit intelligenten Triggern")
    }
    
    deinit {
        // Direkte Cleanup-Operationen ohne Task (nicht MainActor-isoliert)
        periodicSyncTimer?.invalidate()
        periodicSyncTimer = nil
        networkMonitor?.cancel()
        networkMonitor = nil
        monitorQueue = nil
        
        // MainActor-isolierte Operationen werden asynchron aufgerufen
        Task { @MainActor in
            if isMonitoring {
                stopIntelligentMonitoring()
            }
            endBackgroundTask()
            logger.info("SyncTriggerManager bereinigt")
        }
    }
    
    // MARK: - Phase 10.3: Intelligente Trigger-Methoden
    
    /// Startet intelligentes Monitoring
    func startIntelligentMonitoring() {
        guard !isMonitoring else {
            logger.debug("Intelligentes Monitoring läuft bereits")
            return
        }
        
        isMonitoring = true
        
        // Starte verschiedene Monitoring-Komponenten
        startDataChangeMonitoring()
        
        logger.info("Intelligentes Sync-Monitoring gestartet")
    }
    
    /// Stoppt intelligentes Monitoring
    func stopIntelligentMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        // Stoppe Data Change Monitoring
        stopDataChangeMonitoring()
        
        // Bereinige Debounce-Timer
        dataChangeDebounceTimer?.invalidate()
        dataChangeDebounceTimer = nil
        
        logger.info("Intelligentes Sync-Monitoring gestoppt")
    }
    
    /// Konfiguriert Standard-Trigger-Bedingungen
    private func setupDefaultTriggerConditions() {
        triggerConditions = [
            TriggerCondition(
                type: .networkChange,
                isEnabled: true,
                threshold: 0.0,
                description: "Sync bei Netzwerkänderungen"
            ),
            TriggerCondition(
                type: .appLaunch,
                isEnabled: true,
                threshold: 0.0,
                description: "Sync beim App-Start"
            ),
            TriggerCondition(
                type: .appBackground,
                isEnabled: true,
                threshold: 0.0,
                description: "Sync beim Verlassen der App"
            ),
            TriggerCondition(
                type: .dataChange,
                isEnabled: true,
                threshold: 5.0,
                description: "Sync nach 5 Datenänderungen"
            ),
            TriggerCondition(
                type: .timeInterval,
                isEnabled: true,
                threshold: 300.0,
                description: "Sync alle 5 Minuten"
            ),
            TriggerCondition(
                type: .userAction,
                isEnabled: true,
                threshold: 0.0,
                description: "Sync bei wichtigen Benutzeraktionen"
            )
        ]
    }
    
    /// Startet Core Data Change Monitoring
    private func startDataChangeMonitoring() {
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleDataChange(notification)
            }
        }
        
        logger.info("Core Data Änderungs-Monitoring gestartet")
    }
    
    /// Stoppt Core Data Change Monitoring
    private func stopDataChangeMonitoring() {
        NotificationCenter.default.removeObserver(self, name: .NSManagedObjectContextDidSave, object: nil)
    }
    
    /// Behandelt Core Data Änderungen mit Debouncing
    private func handleDataChange(_ notification: Notification) {
        guard shouldTriggerSync(for: .dataChange) else { return }
        
        // Inkrementiere Änderungs-Counter
        pendingDataChanges += 1
        
        // Debounce-Timer zurücksetzen
        dataChangeDebounceTimer?.invalidate()
        dataChangeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.processDataChanges()
            }
        }
        
        logger.debug("Datenänderung registriert (Gesamt: \(self.pendingDataChanges))")
    }
    
    /// Verarbeitet angesammelte Datenänderungen
    private func processDataChanges() {
        guard let threshold = getTriggerThreshold(for: .dataChange),
              Double(pendingDataChanges) >= threshold else {
            pendingDataChanges = 0
            return
        }
        
        logger.info("Datenänderungs-Threshold erreicht (\(self.pendingDataChanges) >= \(threshold))")
        
        Task {
            await triggerIntelligentSync(reason: "Datenänderungen (\(self.pendingDataChanges))")
        }
        
        pendingDataChanges = 0
    }
    
    /// Triggert intelligente Synchronisation
    private func triggerIntelligentSync(reason: String, completion: (() -> Void)? = nil) async {
        // Bestimme optimale Sync-Strategie
        let strategy = await determineSyncStrategy()
        
        logger.info("Starte intelligente Synchronisation: \(reason) (Strategie: \(strategy.description))")
        
        // Update UI
        isSyncing = true
        lastSyncAttempt = Date()
        lastSyncError = nil
        
        do {
            // Führe strategiespezifische Synchronisation durch
            try await performStrategicSync(strategy: strategy)
            
            logger.info("Intelligente Synchronisation erfolgreich: \(reason)")
            
        } catch {
            lastSyncError = error.localizedDescription
            logger.error("Intelligente Synchronisation fehlgeschlagen: \(error.localizedDescription)")
        }
        
        // Update UI
        isSyncing = false
        completion?()
    }
    
    /// Bestimmt optimale Sync-Strategie basierend auf Kontext
    private func determineSyncStrategy() async -> SyncStrategy {
        let isAuthenticated = await isUserAuthenticated()
        let hasStrongConnection = await hasStrongNetworkConnection()
        let lastSyncAge = lastSyncAttempt?.timeIntervalSinceNow ?? -Double.infinity
        let hasManyChanges = pendingDataChanges > 10
        
        // Strategielogik
        if !isAuthenticated {
            return .minimal
        }
        
        if abs(lastSyncAge) > 3600 { // Mehr als 1 Stunde
            return .full
        }
        
        if hasManyChanges || !hasStrongConnection {
            return .standard
        }
        
        return .minimal
    }
    
    /// Führt strategiespezifische Synchronisation durch
    private func performStrategicSync(strategy: SyncStrategy) async throws {
        switch strategy {
        case .minimal:
            // Nur kritische Änderungen synchronisieren
            try await syncManager.performMinimalSync()
        case .standard:
            // Standard-Synchronisation
            try await syncManager.performStandardSync()
        case .full:
            // Vollständige Synchronisation mit allen Optimierungen
            try await syncManager.syncWithOptimizedBackend()
        }
    }
    
    /// Prüft Netzwerkverbindungsqualität
    private func hasStrongNetworkConnection() async -> Bool {
        guard let monitor = networkMonitor else { 
            logger.warning("NetworkMonitor nicht verfügbar, assume starke Verbindung")
            return true // Optimistisch annehmen, dass Netzwerk verfügbar ist
        }
        
        // Direkter Zugriff auf currentPath ohne Continuation
        let currentPath = monitor.currentPath
        let isStrong = currentPath.status == .satisfied && 
                      (currentPath.usesInterfaceType(.wifi) || currentPath.usesInterfaceType(.cellular))
        
        logger.debug("Netzwerkstatus: \(isStrong ? "stark" : "schwach")")
        return isStrong
    }
    
    /// Hilfsmethoden für Trigger-Konfiguration
    private func shouldTriggerSync(for type: TriggerType) -> Bool {
        return triggerConditions.first { $0.type == type }?.isEnabled ?? false
    }
    
    private func getTriggerThreshold(for type: TriggerType) -> Double? {
        return triggerConditions.first { $0.type == type }?.threshold
    }
    
    /// Background-Task-Management
    private func startBackgroundTask() {
        endBackgroundTask() // Beende vorherigen Task falls vorhanden
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    // MARK: - Bestehende Public Methods (erweitert)
    
    /// Triggert Synchronisation beim App-Start
    func triggerStartupSync() {
        logger.info("App-Start-Sync wird ausgelöst")
        
        // Starte intelligentes Monitoring
        startIntelligentMonitoring()
        
        // Verzögere den Sync leicht, um der App Zeit zum vollständigen Start zu geben
        Task {
            try await Task.sleep(nanoseconds: UInt64(startupSyncDelay * 1_000_000_000))
            
            await triggerIntelligentSync(reason: "App-Start")
            startPeriodicSync()
        }
    }
    
    /// Triggert Synchronisation nach erfolgreicher Authentifizierung
    func triggerAuthenticationSync() {
        logger.info("Authentifizierungs-Sync wird ausgelöst")
        
        // Starte intelligentes Monitoring
        startIntelligentMonitoring()
        
        Task {
            await triggerIntelligentSync(reason: "Authentifizierung")
            startPeriodicSync()
        }
    }
    
    /// Triggert Synchronisation basierend auf Benutzeraktionen
    func triggerUserActionSync(action: String) {
        guard shouldTriggerSync(for: .userAction) else { return }
        
        logger.info("Benutzeraktion-Sync wird ausgelöst: \(action)")
        
        Task {
            await triggerIntelligentSync(reason: "Benutzeraktion: \(action)")
        }
    }
    
    /// Behandelt App-Lifecycle-Änderungen (erweitert)
    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        logger.info("Scene-Phase geändert zu: \(String(describing: newPhase))")
        
        switch newPhase {
        case .active:
            // App ist in den Vordergrund gekommen
            startIntelligentMonitoring()
            
            Task {
                try await Task.sleep(nanoseconds: UInt64(foregroundSyncDelay * 1_000_000_000))
                await triggerIntelligentSync(reason: "App-Vordergrund")
                startPeriodicSync()
            }
            
        case .background:
            // App ist in den Hintergrund gegangen
            guard shouldTriggerSync(for: .appBackground) else {
                stopPeriodicSync()
                return
            }
            
            // Starte Background-Task für Sync
            startBackgroundTask()
            
            Task {
                await triggerIntelligentSync(reason: "App-Hintergrund") {
                    self.endBackgroundTask()
                }
            }
            
            stopPeriodicSync()
            stopIntelligentMonitoring()
            
        case .inactive:
            // App ist inaktiv (z.B. während Unterbrechungen)
            // Keine Aktion erforderlich
            break
            
        @unknown default:
            logger.warning("Unbekannte Scene-Phase: \(String(describing: newPhase))")
        }
    }
    
    /// Startet periodische Synchronisation (erweitert)
    func startPeriodicSync() {
        guard periodicSyncTimer == nil else {
            logger.debug("Periodische Synchronisation läuft bereits")
            return
        }
        
        guard shouldTriggerSync(for: .timeInterval) else {
            logger.debug("Periodische Synchronisation deaktiviert")
            return
        }
        
        logger.info("Periodische Synchronisation wird gestartet (Intervall: \(self.periodicSyncInterval)s)")
        
        periodicSyncTimer = Timer.scheduledTimer(withTimeInterval: periodicSyncInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.triggerIntelligentSync(reason: "Periodisch")
            }
        }
    }
    
    /// Stoppt periodische Synchronisation
    func stopPeriodicSync() {
        periodicSyncTimer?.invalidate()
        periodicSyncTimer = nil
        logger.info("Periodische Synchronisation wurde gestoppt")
    }
    
    /// Triggert manuelle Synchronisation (für Pull-to-Refresh etc.)
    func triggerManualSync() async {
        logger.info("Manuelle Synchronisation wird ausgelöst")
        await performSync(reason: "Manuell", ignoreThrottle: true)
    }
    
    // MARK: - Private Methods
    
    /// Führt Synchronisation mit Throttling durch
    private func performSyncWithThrottle(reason: String) async {
        await performSync(reason: reason, ignoreThrottle: false)
    }
    
    /// Prüft, ob der User authentifiziert ist
    private func isUserAuthenticated() async -> Bool {
        return await MainActor.run {
            return AuthService.shared.isAuthenticated
        }
    }
    
    /// Führt Synchronisation durch
    private func performSync(reason: String, ignoreThrottle: Bool) async {
        // Prüfe, ob bereits ein Sync läuft
        guard !isSyncing else {
            logger.debug("Sync bereits in Bearbeitung, überspringe \(reason)-Sync")
            return
        }
        
        // Prüfe Authentifizierung
        guard await isUserAuthenticated() else {
            logger.debug("Sync übersprungen: Benutzer ist nicht authentifiziert (\(reason))")
            return
        }
        
        // Throttling: Verhindere zu häufige Sync-Versuche
        if !ignoreThrottle, let lastAttempt = lastSyncAttempt {
            let timeSinceLastSync = Date().timeIntervalSince(lastAttempt)
            if timeSinceLastSync < minimumSyncInterval {
                logger.debug("Zu früh für \(reason)-Sync (letzter Versuch vor \(timeSinceLastSync)s)")
                return
            }
        }
        
        logger.info("Starte \(reason)-Synchronisation")
        
        // Phase 5.3: Toast für Sync-Start (nur bei manuellen Syncs)
        if reason == "Manuell" {
            toastManager?.showSyncStarted()
        }
        
        // Update UI
        isSyncing = true
        lastSyncAttempt = Date()
        lastSyncError = nil
        
        // Führe Synchronisation durch
        await syncManager.sync(reason: reason)
        
        logger.info("\(reason)-Synchronisation erfolgreich abgeschlossen")
        
        // Phase 5.3: Toast für Sync-Erfolg (nur bei manuellen Syncs)
        if reason == "Manuell" {
            toastManager?.showSyncCompleted()
        }
        
        // Update UI
        isSyncing = false
    }
    
    /// Richtet Netzwerküberwachung ein
    private func setupNetworkMonitoring() {
        do {
            networkMonitor = NWPathMonitor()
            monitorQueue = DispatchQueue(label: "NetworkMonitor")
            
            guard let monitor = networkMonitor, let queue = monitorQueue else {
                logger.error("Fehler beim Erstellen des NetworkMonitors")
                return
            }
            
            monitor.pathUpdateHandler = { [weak self] path in
                Task { @MainActor in
                    self?.handleNetworkChange(path)
                }
            }
            
            monitor.start(queue: queue)
            logger.info("Netzwerküberwachung wurde erfolgreich eingerichtet")
        } catch {
            logger.error("Fehler beim Einrichten der Netzwerküberwachung: \(error)")
        }
    }
    
    /// Behandelt Netzwerkänderungen (erweitert)
    private func handleNetworkChange(_ path: NWPath) {
        let isConnected = path.status == .satisfied
        logger.info("Netzwerkstatus geändert: \(isConnected ? "Verbunden" : "Nicht verbunden")")
        
        if isConnected && shouldTriggerSync(for: .networkChange) {
            // Phase 5.3: Toast für Netzwerk-Wiederherstellung
            toastManager?.showNetworkRestored()
            
            // Netzwerk ist verfügbar - triggere intelligente Sync nach kurzer Verzögerung
            Task {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 Sekunden warten
                await triggerIntelligentSync(reason: "Netzwerk-Wiederherstellung")
            }
        }
    }
    
    /// Bereinigt Ressourcen
    private func cleanup() {
        stopPeriodicSync()
        networkMonitor?.cancel()
        networkMonitor = nil
        monitorQueue = nil
        logger.info("SyncTriggerManager bereinigt")
    }
}

// MARK: - Convenience Extensions

extension SyncTriggerManager {
    
    /// Prüft, ob der letzte Sync länger als ein bestimmtes Intervall zurückliegt
    func isLastSyncStale(threshold: TimeInterval = 600) -> Bool { // 10 Minuten Standard
        guard let lastSync = lastSyncAttempt else { return true }
        return Date().timeIntervalSince(lastSync) > threshold
    }
    
    /// Formatiert den Zeitstempel des letzten Sync-Versuchs
    var lastSyncFormatted: String {
        guard let lastSync = lastSyncAttempt else { return "Noch nie" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        
        return formatter.string(from: lastSync)
    }
} 