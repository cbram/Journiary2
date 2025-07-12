//
//  Trip+SupabaseSync.swift
//  Journiary
//
//  Created by Supabase Integration on 08.06.25.
//

import Foundation
import CoreData

// MARK: - Trip Supabase Sync Extensions

extension Trip {
    
    // MARK: - Sync-Metadaten Properties
    // Diese Properties werden automatisch von CoreData generiert
    // da sie im .xcdatamodeld definiert sind
    
    // MARK: - Conversion to Supabase
    
    func toSupabaseTrip() -> SupabaseTrip {
        return SupabaseTrip(
            id: supabaseID ?? UUID(),
            name: name ?? "Unbenannte Reise",
            tripDescription: tripDescription,
            coverImageUrl: coverImageUrl,
            travelCompanions: travelCompanions,
            visitedCountries: visitedCountries,
            startDate: startDate ?? Date(),
            endDate: endDate,
            isActive: isActive,
            totalDistance: totalDistance,
            gpsTrackingEnabled: gpsTrackingEnabled,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            syncVersion: Int(syncVersion),
            userId: nil // Erstmal ohne User-Management
        )
    }
    
    func toSupabaseTripInsert() -> SupabaseTripInsert {
        return SupabaseTripInsert(
            name: name ?? "Unbenannte Reise",
            tripDescription: tripDescription,
            coverImageUrl: coverImageUrl,
            travelCompanions: travelCompanions,
            visitedCountries: visitedCountries,
            startDate: startDate ?? Date(),
            endDate: endDate,
            isActive: isActive,
            totalDistance: totalDistance,
            gpsTrackingEnabled: gpsTrackingEnabled,
            userId: nil // Erstmal ohne User-Management
        )
    }
    
    // MARK: - Update from Supabase
    
    func updateFromSupabase(_ supabaseTrip: SupabaseTrip) {
        self.name = supabaseTrip.name
        self.tripDescription = supabaseTrip.tripDescription
        self.coverImageUrl = supabaseTrip.coverImageUrl
        self.travelCompanions = supabaseTrip.travelCompanions
        self.visitedCountries = supabaseTrip.visitedCountries
        self.startDate = supabaseTrip.startDate
        self.endDate = supabaseTrip.endDate
        self.isActive = supabaseTrip.isActive
        self.totalDistance = supabaseTrip.totalDistance
        self.gpsTrackingEnabled = supabaseTrip.gpsTrackingEnabled
        self.syncVersion = Int32(supabaseTrip.syncVersion)
        self.updatedAt = supabaseTrip.updatedAt
        self.createdAt = supabaseTrip.createdAt
        self.supabaseID = supabaseTrip.id
        self.needsSync = false
        self.lastSyncDate = Date()
    }
    
    // MARK: - Sync Management
    
    func markForSync() {
        self.needsSync = true
        self.updatedAt = Date()
    }
    
    func markSynced() {
        self.needsSync = false
        self.lastSyncDate = Date()
    }
    
    func incrementSyncVersion() {
        self.syncVersion += 1
        self.updatedAt = Date()
    }
    
    // MARK: - Conflict Resolution
    
    func isNewerThan(_ supabaseTrip: SupabaseTrip) -> Bool {
        guard let localUpdatedAt = self.updatedAt else { return false }
        return localUpdatedAt > supabaseTrip.updatedAt
    }
    
    func hasConflictWith(_ supabaseTrip: SupabaseTrip) -> Bool {
        // Konflikt wenn beide Versionen nach der letzten Sync geändert wurden
        guard let lastSync = self.lastSyncDate else { return false }
        
        let localChangedAfterSync = self.updatedAt ?? Date.distantPast > lastSync
        let remoteChangedAfterSync = supabaseTrip.updatedAt > lastSync
        
        return localChangedAfterSync && remoteChangedAfterSync
    }
    
    // MARK: - Validation
    
    func isValidForSync() -> Bool {
        guard let name = self.name, !name.isEmpty else { return false }
        guard self.startDate != nil else { return false }
        return true
    }
    
    // MARK: - Debug Information
    
    func syncDebugInfo() -> String {
        return """
        Trip Sync Debug Info:
        - Name: \(name ?? "nil")
        - Supabase ID: \(supabaseID?.uuidString ?? "nil")
        - Sync Version: \(syncVersion)
        - Needs Sync: \(needsSync)
        - Last Sync: \(lastSyncDate?.formatted() ?? "nie")
        - Updated At: \(updatedAt?.formatted() ?? "nil")
        """
    }
}

// MARK: - Trip CoreData Setup Helper

extension Trip {
    
    static func setupSyncAttributes(in context: NSManagedObjectContext) {
        // Hilfsmethode für Setup von Sync-Attributen bei bestehenden Trips
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        
        do {
            let existingTrips = try context.fetch(request)
            
            for trip in existingTrips {
                // Sync-Metadaten initialisieren falls nicht vorhanden
                if trip.createdAt == nil {
                    trip.createdAt = Date()
                }
                if trip.updatedAt == nil {
                    trip.updatedAt = Date()
                }
                if trip.syncVersion == 0 {
                    trip.syncVersion = 1
                }
                // Neue Trips markieren für Initial-Sync
                if trip.supabaseID == nil {
                    trip.needsSync = true
                }
            }
            
            try context.save()
            print("✅ Sync-Attribute für \(existingTrips.count) Trips initialisiert")
            
        } catch {
            print("⚠️ Fehler beim Setup der Sync-Attribute: \(error)")
        }
    }
} 