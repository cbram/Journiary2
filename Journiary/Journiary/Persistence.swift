//
//  Persistence.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController(inMemory: true) // Temporär für Supabase-Integration

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
        
        // Weitere Beispiel-Erinnerung
        let memory2 = Memory(context: viewContext)
        memory2.title = "Reichstag"
        memory2.text = "Besichtigung des deutschen Bundestags mit toller Aussicht von der Kuppel."
        memory2.timestamp = Date().addingTimeInterval(-2400)
        memory2.latitude = 52.5186
        memory2.longitude = 13.3762
        memory2.locationName = "Berlin, Deutschland"
        memory2.trip = trip

        // Tags erstellen
        let tagCategory = TagCategory(context: viewContext)
        tagCategory.name = "Aktivitäten"
        tagCategory.displayName = "Aktivitäten"
        tagCategory.emoji = "🎯"
        tagCategory.color = "blue"
        tagCategory.isSystemCategory = true
        tagCategory.sortOrder = 0
        tagCategory.createdAt = Date()

        let tag1 = Tag(context: viewContext)
        tag1.name = "sightseeing"
        tag1.normalizedName = "sightseeing"
        tag1.displayName = "Sightseeing"
        tag1.emoji = "🏛️"
        tag1.color = "blue"
        tag1.isSystemTag = true
        tag1.usageCount = 2
        tag1.createdAt = Date()
        tag1.lastUsedAt = Date()
        tag1.category = tagCategory

        // Tags zu Memories hinzufügen
        memory1.addToTags(tag1)
        memory2.addToTags(tag1)

        // GPX Track erstellen
        let gpxTrack = GPXTrack(context: viewContext)
        gpxTrack.name = "Berlin Tour"
        gpxTrack.originalFilename = "berlin_tour.gpx"
        gpxTrack.totalDistance = 5420.0
        gpxTrack.totalDuration = 7200.0 // 2 Stunden
        gpxTrack.averageSpeed = 0.75 // km/h
        gpxTrack.maxSpeed = 1.2
        gpxTrack.elevationGain = 15.0
        gpxTrack.elevationLoss = 12.0
        gpxTrack.totalPoints = 245
        gpxTrack.startTime = Date().addingTimeInterval(-7200)
        gpxTrack.endTime = Date()
        gpxTrack.creator = "Journiary"
        gpxTrack.trackType = "walking"
        gpxTrack.importedAt = Date()

        // GPX Points erstellen
        for i in 0..<10 {
            let routePoint = RoutePoint(context: viewContext)
            routePoint.latitude = 52.5163 + Double(i) * 0.001
            routePoint.longitude = 13.3777 + Double(i) * 0.001
            routePoint.timestamp = Date().addingTimeInterval(-Double(i * 300))
            routePoint.altitude = 45.0 + Double(i)
            routePoint.speed = 0.8
            routePoint.trip = trip
            routePoint.gpxTrack = gpxTrack
        }

        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to terminate with a crash log.
            // In a shipping application, you should not use this method.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Journiary")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // MARK: - Erweiterte CoreData-Konfiguration für Supabase-Sync
        
        // CoreData Migration Configuration
        if let storeDescription = container.persistentStoreDescriptions.first {
            // Aktiviere automatische Migration
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
            
            // CloudKit Konfiguration
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Migration Optionen
            storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }

        // MARK: - Migration und Error-Handling
        
        container.loadPersistentStores(completionHandler: { [weak container] (storeDescription, error) in
            if let error = error as NSError? {
                // CRITICAL: Besseres Error-Handling für Production
                print("❌ CRITICAL: Core Data Store konnte nicht geladen werden: \(error)")
                
                // Development: Schema-Migration-Fehler
                if error.code == 134110 { // Schema-Migrationsfehler
                    print("🔧 Schema-Migration-Fehler erkannt")
                    print("💡 Lösung: Simulator → Device → Erase All Content and Settings")
                    print("⚠️ Oder App deinstallieren und neu installieren")
                }
                
                // Für jetzt: Direkter Fehler für klare Diagnose
                fatalError("CoreData Fehler: \(error.localizedDescription)\nCode: \(error.code)")
            } else {
                print("✅ Core Data Store erfolgreich geladen")
                
                // Sync-Setup für bestehende Daten
                Self.initializeSyncAttributesIfNeeded(container: container)
            }
        })
        
        // Automatisches Speichern aktivieren
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Store Reset für Development
    
    private static func performStoreReset(container: NSPersistentContainer?) {
        print("🔄 Führe CoreData Store-Reset durch...")
        
        guard let container = container,
              let storeURL = container.persistentStoreDescriptions.first?.url else {
            print("⚠️ Store-URL nicht gefunden")
            return
        }
        
        do {
            // Store-Dateien löschen
            let fileManager = FileManager.default
            
            if fileManager.fileExists(atPath: storeURL.path) {
                try fileManager.removeItem(at: storeURL)
                print("✅ Store-Datei gelöscht: \(storeURL.path)")
            }
            
            // Zusätzliche SQLite-Dateien löschen
            let walURL = storeURL.appendingPathExtension("wal")
            let shmURL = storeURL.appendingPathExtension("shm")
            
            if fileManager.fileExists(atPath: walURL.path) {
                try fileManager.removeItem(at: walURL)
            }
            
            if fileManager.fileExists(atPath: shmURL.path) {
                try fileManager.removeItem(at: shmURL)
            }
            
            // Store neu laden
            container.loadPersistentStores { _, error in
                if let error = error {
                    print("⚠️ Fehler beim Neu-Laden des Stores: \(error)")
                } else {
                    print("✅ Store erfolgreich zurückgesetzt und neu geladen")
                    Self.initializeSyncAttributesIfNeeded(container: container)
                }
            }
            
        } catch {
            print("⚠️ Fehler beim Store-Reset: \(error)")
        }
    }
    
    // MARK: - Sync-Attribute Initialisierung
    
    private static func initializeSyncAttributesIfNeeded(container: NSPersistentContainer?) {
        guard let container = container else { return }
        let context = container.viewContext
        
        // Prüfe ob bereits Sync-Attribute initialisiert wurden
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let trips = try context.fetch(request)
            
            if let firstTrip = trips.first, firstTrip.createdAt == nil {
                print("🔧 Initialisiere Sync-Attribute für bestehende Daten...")
                SyncSetupManager.initializeSyncForExistingData(context: context)
            } else {
                print("ℹ️ Sync-Attribute bereits initialisiert")
            }
            
        } catch {
            print("⚠️ Fehler beim Prüfen der Sync-Attribute: \(error)")
        }
    }
}

