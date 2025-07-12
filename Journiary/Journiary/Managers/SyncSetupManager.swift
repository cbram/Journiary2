//
//  SyncSetupManager.swift
//  Journiary
//
//  Created by Supabase Integration on 08.06.25.
//

import Foundation
import CoreData

class SyncSetupManager {
    
    // MARK: - Setup für bestehende Daten
    
    static func initializeSyncForExistingData(context: NSManagedObjectContext) {
        print("🔧 Initialisiere Sync für bestehende Daten...")
        
        // Trips initialisieren
        initializeTripSyncAttributes(context: context)
        
        // Weitere Entities können hier hinzugefügt werden
        // initializeMemorySyncAttributes(context: context)
        // initializeMediaItemSyncAttributes(context: context)
        
        print("✅ Sync-Initialisierung abgeschlossen")
    }
    
    // MARK: - Trip Sync Initialisierung
    
    private static func initializeTripSyncAttributes(context: NSManagedObjectContext) {
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        
        do {
            let existingTrips = try context.fetch(request)
            var updatedCount = 0
            
            for trip in existingTrips {
                var needsUpdate = false
                
                // Sync-Metadaten initialisieren falls nicht vorhanden
                if trip.createdAt == nil {
                    trip.createdAt = trip.startDate ?? Date()
                    needsUpdate = true
                }
                
                if trip.updatedAt == nil {
                    trip.updatedAt = trip.startDate ?? Date()
                    needsUpdate = true
                }
                
                if trip.syncVersion == 0 {
                    trip.syncVersion = 1
                    needsUpdate = true
                }
                
                // Trips ohne Supabase-ID markieren für Initial-Sync
                if trip.supabaseID == nil {
                    trip.needsSync = true
                    needsUpdate = true
                }
                
                // Cover-Image-URL initialisieren (falls noch nicht vorhanden)
                if trip.coverImageUrl == nil && trip.coverImageData != nil {
                    // Hier könnte später die Logik für Upload hinzugefügt werden
                    trip.coverImageUrl = nil // Wird beim ersten Upload gesetzt
                    needsUpdate = true
                }
                
                if needsUpdate {
                    updatedCount += 1
                }
            }
            
            if updatedCount > 0 {
                try context.save()
                print("✅ Sync-Attribute für \(updatedCount) Trips initialisiert")
            } else {
                print("ℹ️ Alle Trips haben bereits Sync-Attribute")
            }
            
        } catch {
            print("⚠️ Fehler beim Initialisieren der Trip-Sync-Attribute: \(error)")
        }
    }
    
    // MARK: - Validation & Diagnostics
    
    static func validateSyncSetup(context: NSManagedObjectContext) {
        print("🔍 Validiere Sync-Setup...")
        
        validateTripSyncSetup(context: context)
    }
    
    private static func validateTripSyncSetup(context: NSManagedObjectContext) {
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        
        do {
            let trips = try context.fetch(request)
            
            let totalTrips = trips.count
            let tripsWithSyncAttributes = trips.filter { $0.createdAt != nil && $0.updatedAt != nil }.count
            let tripsNeedingSync = trips.filter { $0.needsSync }.count
            let tripsWithSupabaseID = trips.filter { $0.supabaseID != nil }.count
            
            print("📊 Trip Sync Status:")
            print("  - Trips gesamt: \(totalTrips)")
            print("  - Mit Sync-Attributen: \(tripsWithSyncAttributes)")
            print("  - Benötigen Sync: \(tripsNeedingSync)")
            print("  - Mit Supabase ID: \(tripsWithSupabaseID)")
            
            if tripsWithSyncAttributes == totalTrips {
                print("✅ Alle Trips haben Sync-Attribute")
            } else {
                print("⚠️ \(totalTrips - tripsWithSyncAttributes) Trips fehlen Sync-Attribute")
            }
            
        } catch {
            print("⚠️ Fehler bei der Validation: \(error)")
        }
    }
    
    // MARK: - Reset Funktionen (für Development)
    
    static func resetSyncState(context: NSManagedObjectContext) {
        print("🔄 Setze Sync-Status zurück...")
        
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        
        do {
            let trips = try context.fetch(request)
            
            for trip in trips {
                trip.supabaseID = nil
                trip.needsSync = true
                trip.lastSyncDate = nil
                trip.syncVersion = 1
            }
            
            try context.save()
            print("✅ Sync-Status für \(trips.count) Trips zurückgesetzt")
            
        } catch {
            print("⚠️ Fehler beim Zurücksetzen des Sync-Status: \(error)")
        }
    }
    
    // MARK: - Debug Information
    
    static func printSyncDebugInfo(context: NSManagedObjectContext) {
        print("🐛 Sync Debug Information:")
        
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.fetchLimit = 5 // Nur erste 5 für Debug
        
        do {
            let trips = try context.fetch(request)
            
            for trip in trips {
                print(trip.syncDebugInfo())
                print("---")
            }
            
        } catch {
            print("⚠️ Fehler beim Laden der Debug-Info: \(error)")
        }
    }
} 