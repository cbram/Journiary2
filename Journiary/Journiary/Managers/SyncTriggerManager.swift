import Foundation
import SwiftUI
import Network
import os.log

/// Verwaltet automatische Sync-Trigger für verschiedene App-Lifecycle-Events.
/// 
/// Diese Klasse implementiert Phase 5.2 des Implementierungsplans:
/// "Automatische Trigger: Automatisches Starten eines Sync-Zyklus beim App-Start 
/// und potenziell bei anderen wichtigen Lebenszyklus-Events der App."
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
    
    // MARK: - Initialization
    
    init() {
        setupNetworkMonitoring()
        logger.info("SyncTriggerManager initialisiert")
    }
    
    deinit {
        // Direkte Cleanup-Operationen ohne Task
        periodicSyncTimer?.invalidate()
        periodicSyncTimer = nil
        networkMonitor?.cancel()
        networkMonitor = nil
        monitorQueue = nil
        logger.info("SyncTriggerManager bereinigt")
    }
    
    // MARK: - Public Methods
    
    /// Triggert Synchronisation beim App-Start
    func triggerStartupSync() {
        logger.info("App-Start-Sync wird ausgelöst")
        
        // Verzögere den Sync leicht, um der App Zeit zum vollständigen Start zu geben
        Task {
            try await Task.sleep(nanoseconds: UInt64(startupSyncDelay * 1_000_000_000))
            
            await performSyncWithThrottle(reason: "App-Start")
            startPeriodicSync()
        }
    }
    
    /// Triggert Synchronisation nach erfolgreicher Authentifizierung
    func triggerAuthenticationSync() {
        logger.info("Authentifizierungs-Sync wird ausgelöst")
        
        Task {
            await performSyncWithThrottle(reason: "Authentifizierung")
            startPeriodicSync()
        }
    }
    
    /// Behandelt App-Lifecycle-Änderungen
    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        logger.info("Scene-Phase geändert zu: \(String(describing: newPhase))")
        
        switch newPhase {
        case .active:
            // App ist in den Vordergrund gekommen
            Task {
                try await Task.sleep(nanoseconds: UInt64(foregroundSyncDelay * 1_000_000_000))
                await performSyncWithThrottle(reason: "App-Vordergrund")
                startPeriodicSync()
            }
            
        case .background:
            // App ist in den Hintergrund gegangen
            stopPeriodicSync()
            
        case .inactive:
            // App ist inaktiv (z.B. während Unterbrechungen)
            // Keine Aktion erforderlich
            break
            
        @unknown default:
            logger.warning("Unbekannte Scene-Phase: \(String(describing: newPhase))")
        }
    }
    
    /// Startet periodische Synchronisation
    func startPeriodicSync() {
        guard periodicSyncTimer == nil else {
            logger.debug("Periodische Synchronisation läuft bereits")
            return
        }
        
        logger.info("Periodische Synchronisation wird gestartet (Intervall: \(self.periodicSyncInterval)s)")
        
        periodicSyncTimer = Timer.scheduledTimer(withTimeInterval: periodicSyncInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.performSyncWithThrottle(reason: "Periodisch")
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
        networkMonitor = NWPathMonitor()
        monitorQueue = DispatchQueue(label: "NetworkMonitor")
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkChange(path)
            }
        }
        
        networkMonitor?.start(queue: monitorQueue!)
        logger.info("Netzwerküberwachung wurde eingerichtet")
    }
    
    /// Behandelt Netzwerkänderungen
    private func handleNetworkChange(_ path: NWPath) {
        let isConnected = path.status == .satisfied
        logger.info("Netzwerkstatus geändert: \(isConnected ? "Verbunden" : "Nicht verbunden")")
        
        if isConnected {
            // Phase 5.3: Toast für Netzwerk-Wiederherstellung
            toastManager?.showNetworkRestored()
            
            // Netzwerk ist verfügbar - triggere Sync nach kurzer Verzögerung
            Task {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 Sekunden warten
                await performSyncWithThrottle(reason: "Netzwerk-Wiederherstellung")
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