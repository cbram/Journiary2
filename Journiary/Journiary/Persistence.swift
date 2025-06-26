//
//  Persistence.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Beispiel-Reise erstellen
        let trip = Trip(context: viewContext)
        trip.name = "Stadtbummel Berlin"
        trip.startDate = Date().addingTimeInterval(-3600) // Vor 1 Stunde
        trip.endDate = Date().addingTimeInterval(-1800) // Vor 30 Minuten
        trip.isActive = false
        trip.totalDistance = 5420.0 // 5.42 km

        
        // Beispiel-Erinnerungen erstellen
        let memory1 = Memory(context: viewContext)
        memory1.title = "Brandenburger Tor"
        memory1.text = "Ein wunderschöner Tag am berühmten Brandenburger Tor. Das Wahrzeichen Berlins ist immer wieder beeindruckend."
        memory1.timestamp = Date().addingTimeInterval(-3000)
        memory1.latitude = 52.5163
        memory1.longitude = 13.3777
        memory1.locationName = "Berlin, Deutschland"
        memory1.trip = trip
        
        // Fotos für erste Erinnerung
        for i in 0..<2 {
            let photo = Photo(context: viewContext)
            photo.imageData = Data() // Dummy-Daten für Preview
            photo.timestamp = Date().addingTimeInterval(-3000 + Double(i * 60))
            photo.order = Int16(i)
            photo.memory = memory1
        }
        
        // MediaItems für erste Erinnerung
        let mediaItem1 = MediaItem(context: viewContext)
        mediaItem1.mediaType = MediaType.photo.rawValue
        mediaItem1.timestamp = Date().addingTimeInterval(-3000)
        mediaItem1.order = 0
        mediaItem1.filename = "Preview_Photo.jpg"
        mediaItem1.filesize = 1024
        mediaItem1.memory = memory1
        
        let memory2 = Memory(context: viewContext)
        memory2.title = "Currywurst Pause"
        memory2.text = "Die beste Currywurst der Stadt! Ein Muss für jeden Berlin-Besucher."
        memory2.timestamp = Date().addingTimeInterval(-2400)
        memory2.latitude = 52.5200
        memory2.longitude = 13.4050
        memory2.locationName = "Berlin Mitte, Deutschland"
        memory2.trip = trip
        
        // Foto für zweite Erinnerung
        let photo2 = Photo(context: viewContext)
        photo2.imageData = Data() // Dummy-Daten für Preview
        photo2.timestamp = Date().addingTimeInterval(-2400)
        photo2.order = 0
        photo2.memory = memory2
        
        // MediaItems für zweite Erinnerung
        let mediaItem2 = MediaItem(context: viewContext)
        mediaItem2.mediaType = MediaType.video.rawValue
        mediaItem2.timestamp = Date().addingTimeInterval(-2400)
        mediaItem2.order = 0
        mediaItem2.filename = "Preview_Video.mov"
        mediaItem2.filesize = 5 * 1024 * 1024 // 5MB
        mediaItem2.duration = 30.0 // 30 Sekunden
        mediaItem2.memory = memory2
        
        // Aktive Reise erstellen
        let activeTrip = Trip(context: viewContext)
        activeTrip.name = "Spaziergang im Park"
        activeTrip.startDate = Date().addingTimeInterval(-900) // Vor 15 Minuten
        activeTrip.isActive = true
        activeTrip.totalDistance = 1250.0 // 1.25 km

        
        // Routenpunkte für aktive Reise
        for i in 0..<10 {
            let routePoint = RoutePoint(context: viewContext)
            routePoint.latitude = 52.5200 + Double(i) * 0.001
            routePoint.longitude = 13.4050 + Double(i) * 0.001
            routePoint.timestamp = Date().addingTimeInterval(-900 + Double(i * 90))
            routePoint.altitude = 50.0 + Double(i) * 2.0
            routePoint.speed = 1.4 // ~5 km/h Gehgeschwindigkeit
            routePoint.trip = activeTrip
        }
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Journiary")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // CloudKit Konfiguration
        container.persistentStoreDescriptions.forEach { storeDescription in
            // Aktiviere History Tracking für CloudKit Sync
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Verbesserte Performance für große Datenmengen
            storeDescription.setOption(1000 as NSNumber, forKey: NSMigrationManagerKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("❌ CRITICAL: Core Data Store konnte nicht geladen werden: \(error)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                print("✅ Core Data Store geladen")
            }
        })
        
        // Verbesserte Threading und Sync-Konfiguration
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Performance Optimierungen
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        // CloudKit Remote Change Handling
        setupRemoteChangeHandling()
    }
    
    private func setupRemoteChangeHandling() {
        // Reagiere auf Remote Changes von CloudKit
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { notification in
            // Forciere Context Update für CloudKit Sync
            self.container.viewContext.perform {
                self.container.viewContext.refreshAllObjects()
            }
        }
    }
    
    // Hilfsfunktion für sichere Background Context Operations
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            context.undoManager = nil
            block(context)
        }
    }
    
    // Hilfsfunktion für sichere Save Operations
    func save(context: NSManagedObjectContext? = nil) {
        let targetContext = context ?? container.viewContext
        
        guard targetContext.hasChanges else {
            return
        }
        
        do {
            try targetContext.save()
        } catch {
            print("❌ ERROR: Core Data Save fehlgeschlagen: \(error)")
        }
    }
}

