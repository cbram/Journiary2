//
//  JourniaryApp.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import BackgroundTasks
import UIKit

// MARK: - App Delegate for Background Task Registration

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Registriere Background Task Handler SOFORT beim App-Launch
        registerBackgroundTasks()
        print("✅ App Delegate: Background Tasks registriert")
        return true
    }
    
    private func registerBackgroundTasks() {
        // Background Location Task - robuster Handler
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.journiary.background-location", using: nil) { task in
            self.handleBackgroundLocationTask(task as! BGProcessingTask)
        }
        
        // Track Compression Task  
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.journiary.trackcompression", using: nil) { task in
            // Handler wird später von TrackStorageManager gesetzt
            print("🔄 Track Compression Task ausgeführt (Handler später gesetzt)")
            task.setTaskCompleted(success: true)
        }
        
        print("✅ Background Tasks registriert: background-location, trackcompression")
    }
    
    private func handleBackgroundLocationTask(_ task: BGProcessingTask) {
        print("🔄 AppDelegate: Background Location Task gestartet")
        
        task.expirationHandler = {
            print("⚠️ AppDelegate: Background Task läuft ab")
            task.setTaskCompleted(success: false)
        }
        
        // Schedule next task
        scheduleNextBackgroundTask()
        
        // Rudimentäre Background-Logik falls LocationManager nicht verfügbar
        performBasicBackgroundWork()
        
        task.setTaskCompleted(success: true)
    }
    
    private func scheduleNextBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.journiary.background-location")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 300) // 5 Minuten
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ AppDelegate: Nächster Background Task geplant")
        } catch {
            print("❌ AppDelegate: Fehler beim Planen des Background Tasks: \(error)")
        }
    }
    
    private func performBasicBackgroundWork() {
        // Grundlegende Background-Wartung ohne LocationManager
        let lastHeartbeat = Date()
        UserDefaults.standard.set(lastHeartbeat, forKey: "app_background_heartbeat")
        
        // Recovery-Daten aktualisieren falls Tracking aktiv war
        let isTrackingActive = UserDefaults.standard.bool(forKey: "recovery_isTrackingActive")
        if isTrackingActive {
            UserDefaults.standard.set(lastHeartbeat, forKey: "recovery_lastHeartbeat")
            print("✅ AppDelegate: Recovery Heartbeat aktualisiert")
        }
    }
}

@main
struct JourniaryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Der PersistenceController für Core Data.
    let persistenceController = PersistenceController.shared
    @StateObject private var locationManager: LocationManager
    @StateObject private var authService = AuthService.shared
    @StateObject private var syncTriggerManager = SyncTriggerManager()
    @StateObject private var syncToastManager = SyncToastManager()
    
    // Track app lifecycle changes
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let context = persistenceController.container.viewContext
        // Initialize LocationManager
        _locationManager = StateObject(wrappedValue: LocationManager(context: context))
    }

    var body: some Scene {
        WindowGroup {
            // Entscheidet basierend auf dem Authentifizierungsstatus, welche Ansicht gezeigt wird.
            if authService.isAuthenticated {
                ZStack {
                    ContentView()
                    
                    // Phase 5.3: Toast-System als separates Overlay
                    VStack {
                        SyncToastOverlay()
                        Spacer()
                    }
                }
                // Stellt den Core Data Context für die Haupt-App bereit.
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                // Stellt den AuthService für untergeordnete Views (z.B. für einen Logout-Button) bereit.
                .environmentObject(authService)
                .environmentObject(locationManager)
                .environmentObject(syncTriggerManager)
                .environmentObject(syncToastManager)
                    .onAppear {
                        // Phase 5.2: Automatischer Sync beim App-Start
                        if authService.isAuthenticated {
                            syncTriggerManager.triggerStartupSync()
                        }
                        
                        // Phase 5.3: Toast-Manager an SyncTriggerManager koppeln
                        syncTriggerManager.toastManager = syncToastManager
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        // Phase 5.2: Sync-Trigger bei wichtigen Lifecycle-Events
                        if authService.isAuthenticated {
                            syncTriggerManager.handleScenePhaseChange(newPhase)
                        }
                    }
                    .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                        // Phase 5.2: Sync-Management bei Authentifizierungsänderung
                        if isAuthenticated {
                            // Kurze Verzögerung um Race Conditions mit Startup-Sync zu vermeiden
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                syncTriggerManager.triggerAuthenticationSync()
                            }
                        } else {
                            syncTriggerManager.stopPeriodicSync()
                        }
                    }
            } else {
                // Zeigt die LoginView an, wenn der Benutzer nicht authentifiziert ist.
                LoginView()
                    // Stellt den AuthService für die LoginView bereit, damit diese den Status ändern kann.
                    .environmentObject(authService)
            }
        }
    }
}
