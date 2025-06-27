//
//  BackgroundSyncService.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import BackgroundTasks
import CoreData
import Network

class BackgroundSyncService {
    static let shared = BackgroundSyncService()
    
    private let settings = AppSettings.shared
    private let syncManager = SyncManager.shared
    private let mediaSyncCoordinator = MediaSyncCoordinator.shared
    private let networkMonitor = NWPathMonitor()
    private var isWifiConnected = false
    
    private let backgroundTaskIdentifier = "com.CHJB.Journiary.backgroundSync"
    
    private init() {
        setupNetworkMonitoring()
    }
    
    /// Registriert die Hintergrundaufgabe für die Synchronisierung
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundSync(task: task as! BGProcessingTask)
        }
    }
    
    /// Plant die nächste Hintergrundaufgabe für die Synchronisierung
    func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = settings.syncOnlyWhenCharging
        
        // Minimale Verzögerung vor der Ausführung der Aufgabe
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 Minuten
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Hintergrundsynchronisierung geplant")
        } catch {
            print("Fehler beim Planen der Hintergrundsynchronisierung: \(error)")
        }
    }
    
    /// Behandelt die Hintergrundaufgabe für die Synchronisierung
    /// - Parameter task: Die Hintergrundaufgabe
    private func handleBackgroundSync(task: BGProcessingTask) {
        // Sicherstellen, dass die App die Aufgabe abschließen kann
        task.expirationHandler = {
            // Aufräumen, wenn die Zeit abläuft
            self.syncManager.cancelSync()
            self.mediaSyncCoordinator.cancelSync()
        }
        
        // Prüfen, ob die Synchronisierung aktiviert ist
        guard settings.syncEnabled else {
            task.setTaskCompleted(success: true)
            return
        }
        
        // Prüfen, ob die WLAN-Einschränkung aktiviert ist und erfüllt wird
        if settings.syncOnlyOnWifi && !isWifiConnected {
            task.setTaskCompleted(success: true)
            return
        }
        
        // Synchronisierung starten
        performBackgroundSync { success in
            // Nächste Hintergrundaufgabe planen
            self.scheduleBackgroundSync()
            
            // Aufgabe als abgeschlossen markieren
            task.setTaskCompleted(success: success)
        }
    }
    
    /// Führt die Synchronisierung im Hintergrund aus
    /// - Parameter completion: Der Abschlusshandler mit dem Erfolg der Synchronisierung
    private func performBackgroundSync(completion: @escaping (Bool) -> Void) {
        // Erstelle einen neuen Core Data-Kontext für die Hintergrundsynchronisierung
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Synchronisiere Daten
        syncManager.syncData(context: backgroundContext) { dataSuccess in
            if dataSuccess && self.settings.syncMedia {
                // Wenn die Datensynchronisierung erfolgreich war und Mediensynchronisierung aktiviert ist
                self.mediaSyncCoordinator.syncMedia(context: backgroundContext) { mediaSuccess in
                    completion(dataSuccess && mediaSuccess)
                }
            } else {
                completion(dataSuccess)
            }
        }
    }
    
    /// Richtet die Netzwerküberwachung ein
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            self.isWifiConnected = path.usesInterfaceType(.wifi)
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    /// Startet eine manuelle Synchronisierung im Hintergrund
    /// - Parameter completion: Der Abschlusshandler mit dem Erfolg der Synchronisierung
    func startManualBackgroundSync(completion: @escaping (Bool) -> Void) {
        // Prüfen, ob die Synchronisierung aktiviert ist
        guard settings.syncEnabled else {
            completion(false)
            return
        }
        
        // Prüfen, ob die WLAN-Einschränkung aktiviert ist und erfüllt wird
        if settings.syncOnlyOnWifi && !isWifiConnected {
            completion(false)
            return
        }
        
        performBackgroundSync(completion: completion)
    }
}

// MARK: - App Delegate Extensions

extension AppDelegate {
    /// Konfiguriert die Hintergrundsynchronisierung
    func configureBackgroundSync() {
        BackgroundSyncService.shared.registerBackgroundTasks()
    }
    
    /// Wird aufgerufen, wenn die App in den Hintergrund wechselt
    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundSyncService.shared.scheduleBackgroundSync()
    }
} 