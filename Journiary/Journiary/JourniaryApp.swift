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
    let persistenceController = EnhancedPersistenceController.shared
    
    // MARK: - Managers
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var appSettings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(authManager)
                .environmentObject(appSettings)
                .handleErrors() // Globales Error Handling für die gesamte App
                .onAppear {
                    // Initial Setup
                    setupApp()
                }
        }
    }
    
    // MARK: - Setup
    
    private func setupApp() {
        print("✅ Travel Companion App gestartet")
        
        // DEBUG: Auskommentiert - Storage Mode Reset
        // #if DEBUG
        // // Für Debug/Development: Storage Mode zurücksetzen um neuen Flow zu testen
        // UserDefaults.standard.removeObject(forKey: "StorageMode")
        // print("🔧 DEBUG: Storage Mode zurückgesetzt für Test des neuen Flows")
        // #endif
        
        let isFirstLaunch = UserDefaults.standard.string(forKey: "StorageMode") == nil
        
        if isFirstLaunch {
            print("🆕 Erstmaliger App-Start - Storage Mode Selection wird angezeigt")
        } else {
            print("📱 Storage Mode: \(appSettings.storageMode.displayName)")
            
            if appSettings.shouldUseBackend {
                print("🔐 Backend-Authentifizierung erforderlich")
                if authManager.isAuthenticated {
                    print("✅ Benutzer bereits authentifiziert: \(authManager.currentUser?.displayName ?? "Unbekannt")")
                } else {
                    print("❌ Benutzer nicht authentifiziert - Login erforderlich")
                }
            } else {
                print("☁️ CloudKit-Modus - Keine Authentifizierung erforderlich")
            }
        }
    }
}
