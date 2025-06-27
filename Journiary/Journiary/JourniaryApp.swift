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
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
