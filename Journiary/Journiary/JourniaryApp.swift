//
//  JourniaryApp.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import CoreData
import BackgroundTasks
import UIKit

// MARK: - App Delegate for Background Task Registration

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Konfiguriere die Hintergrundsynchronisierung
        configureBackgroundSync()
        
        // Initialisiere den Netzwerkmonitor
        _ = NetworkMonitor.shared
        
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Speichere alle ausstehenden Änderungen
        PersistenceController.shared.saveContext()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }
    
    // Registriere Background-Tasks
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.journiary.sync", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    // Plane Background-Refresh
    func scheduleAppRefresh() {
        let settings = AppSettings.shared
        
        // Nur planen, wenn autoSync aktiviert ist
        guard settings.storageMode != .cloudKit && settings.syncEnabled && settings.autoSync else {
            return
        }
        
        let request = BGAppRefreshTaskRequest(identifier: "com.journiary.sync")
        
        // Minimaler Zeitabstand für die Synchronisierung
        let syncInterval: TimeInterval
        switch settings.syncInterval {
        case .hourly:
            syncInterval = 60 * 60
        case .daily:
            syncInterval = 24 * 60 * 60
        case .weekly:
            syncInterval = 7 * 24 * 60 * 60
        }
        
        // Frühester Ausführungszeitpunkt
        request.earliestBeginDate = Date(timeIntervalSinceNow: syncInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("❌ Fehler beim Planen des Background-Tasks: \(error)")
        }
    }
    
    // Führe Background-Sync aus
    func handleAppRefresh(task: BGAppRefreshTask) {
        // Plane den nächsten Refresh
        scheduleAppRefresh()
        
        // Führe Synchronisierung aus
        let syncManager = SyncManager.shared
        
        // Erstelle einen Task für die Synchronisierung
        let syncTask = Task {
            do {
                try await syncManager.performSync()
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ Fehler bei der Hintergrund-Synchronisierung: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
        
        // Setze eine Abbruchbedingung
        task.expirationHandler = {
            syncTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Speichere alle ausstehenden Änderungen
        PersistenceController.shared.saveContext()
        
        // Plane die Hintergrundsynchronisierung
        BackgroundSyncService.shared.scheduleBackgroundSync()
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Prüfe, ob eine Synchronisierung notwendig ist
        if AppSettings.shared.syncEnabled && AppSettings.shared.syncAutomatically {
            BackgroundSyncService.shared.startManualBackgroundSync { _ in }
        }
    }
}

@main
struct JourniaryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var offlineQueue = OfflineQueue.shared
    @StateObject private var conflictResolver = ConflictResolver.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(settings)
                .environmentObject(networkMonitor)
                .environmentObject(offlineQueue)
                .environmentObject(conflictResolver)
                .overlay(
                    VStack {
                        NetworkStatusView()
                        Spacer()
                    }
                )
                .withSyncStatus() // Fügt den Sync-Status-Overlay hinzu
                .toolbar {
                    // Sync-Status in der Toolbar anzeigen, wenn nicht im CloudKit-Modus
                    if settings.storageMode != .cloudKit && settings.syncEnabled {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            SyncStatusToolbarView()
                        }
                    }
                }
                .onAppear {
                    // Initialisiere die Synchronisierung, wenn autoSync aktiviert ist
                    if settings.storageMode != .cloudKit && settings.syncEnabled && settings.autoSync {
                        Task {
                            try? await SyncManager.shared.performSync()
                        }
                    }
                }
        }
    }
}
