//
//  CloudKitSharingService.swift
//  Journiary
//
//  Created by Assistant on 06.11.25.
//

import Foundation
import CloudKit
import CoreData

/// CloudKit Sharing Service für User Discovery und CKShare Management
/// Implementiert CloudKit-natives Sharing parallel zum Backend-Sharing
@MainActor
class CloudKitSharingService: ObservableObject {
    
    static let shared = CloudKitSharingService()
    
    @Published var isAvailable = false
    @Published var canDiscoverUsers = false
    @Published var sharedTrips: [SharedTripInfo] = []
    @Published var errorMessage: String?
    
    private let container = CKContainer.default()
    private let database = CKContainer.default().privateCloudDatabase
    private let sharedDatabase = CKContainer.default().sharedCloudDatabase
    private let context = EnhancedPersistenceController.shared.viewContext
    
    private init() {
        Task {
            await checkCloudKitAvailability()
        }
    }
    
    // MARK: - CloudKit Availability
    
    /// Prüft ob CloudKit verfügbar ist
    func checkCloudKitAvailability() async {
        do {
            let status = try await container.accountStatus()
            isAvailable = (status == .available)
            
            if !isAvailable {
                errorMessage = "iCloud Account nicht verfügbar: \(accountStatusDescription(status))"
            }
        } catch {
            isAvailable = false
            errorMessage = "CloudKit Status Check fehlgeschlagen: \(error.localizedDescription)"
        }
    }
    
    private func accountStatusDescription(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "Verfügbar"
        case .noAccount:
            return "Kein iCloud Account"
        case .restricted:
            return "Account eingeschränkt"
        case .couldNotDetermine:
            return "Status nicht ermittelbar"
        case .temporarilyUnavailable:
            return "Temporär nicht verfügbar"
        @unknown default:
            return "Unbekannter Status"
        }
    }
    
    // MARK: - User Discovery (Simplified)
    
    /// Prüft ob User Discovery möglich ist
    func checkUserDiscovery() async {
        // Vereinfachte Implementierung - in Produktivcode würde hier
        // die korrekte CloudKit User Discovery API verwendet werden
        canDiscoverUsers = isAvailable
    }
    
    /// Findet aktuelle User Identity (vereinfacht)
    func fetchCurrentUserIdentity() async -> String? {
        guard isAvailable else { return nil }
        
        do {
            // Vereinfachte Implementierung
            let recordID = try await container.userRecordID()
            return recordID.recordName
        } catch {
            errorMessage = "Current User Identity Fetch fehlgeschlagen: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Trip Sharing (Simplified)
    
    /// Teilt einen Trip via CloudKit Share (vereinfacht)
    func shareTrip(_ trip: Trip) async -> Bool {
        guard isAvailable else {
            errorMessage = "CloudKit nicht verfügbar"
            return false
        }
        
        do {
            // Finde CKRecord für Trip
            guard let tripRecord = try await findTripRecord(for: trip) else {
                errorMessage = "Trip CKRecord nicht gefunden"
                return false
            }
            
            // Erstelle CKShare
            let share = CKShare(rootRecord: tripRecord)
            share[CKShare.SystemFieldKey.title] = trip.name as CKRecordValue?
            share[CKShare.SystemFieldKey.shareType] = "Trip" as CKRecordValue?
            
            // Speichere Share (vereinfachte API)
            let recordsToSave = [tripRecord, share]
            try await database.modifyRecords(saving: recordsToSave, deleting: [])
            
            // Update Trip mit Share Information
            trip.cloudKitShareURL = share.url?.absoluteString
            trip.isSharedViaCloudKit = true
            
            try context.save()
            
            await loadSharedTrips()
            return true
        } catch {
            errorMessage = "Trip Sharing fehlgeschlagen: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Akzeptiert einen geteilten Trip (vereinfacht)
    func acceptShare(from url: URL) async -> Bool {
        do {
            let metadata = try await container.shareMetadata(for: url)
            
            // Akzeptiere Share
            let _ = try await container.accept(metadata)
            
            // Lade geteilte Trips neu
            await loadSharedTrips()
            return true
        } catch {
            errorMessage = "Share Akzeptierung fehlgeschlagen: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Entfernt Share von Trip
    func removeShare(from trip: Trip) async -> Bool {
        guard let shareURL = trip.cloudKitShareURL,
              let _ = URL(string: shareURL) else {
            errorMessage = "Share URL nicht verfügbar"
            return false
        }
        
        do {
            // Vereinfachte Implementierung - entferne Share Information
            trip.cloudKitShareURL = nil
            trip.isSharedViaCloudKit = false
            
            try context.save()
            
            await loadSharedTrips()
            return true
        } catch {
            errorMessage = "Share Entfernung fehlgeschlagen: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Lädt alle geteilten Trips (vereinfacht)
    func loadSharedTrips() async {
        do {
            let query = CKQuery(recordType: "CD_Trip", predicate: NSPredicate(format: "share != nil"))
            let (matchResults, _) = try await database.records(matching: query)
            
            var sharedTripsInfo: [SharedTripInfo] = []
            
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    let tripInfo = SharedTripInfo(
                        tripName: record["name"] as? String ?? "Unbekannter Trip",
                        shareURL: nil, // Vereinfacht
                        participantCount: 1, // Vereinfacht
                        ownerName: "CloudKit User" // Vereinfacht
                    )
                    sharedTripsInfo.append(tripInfo)
                case .failure(let error):
                    print("❌ Fehler beim Laden von shared Trip: \(error)")
                }
            }
            
            sharedTrips = sharedTripsInfo
        } catch {
            errorMessage = "Shared Trips laden fehlgeschlagen: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Memory Sharing (Simplified)
    
    /// Teilt eine Memory via CloudKit Share (vereinfacht)
    func shareMemory(_ memory: Memory) async -> Bool {
        guard isAvailable else {
            errorMessage = "CloudKit nicht verfügbar"
            return false
        }
        
        do {
            // Finde CKRecord für Memory
            guard let memoryRecord = try await findMemoryRecord(for: memory) else {
                errorMessage = "Memory CKRecord nicht gefunden"
                return false
            }
            
            // Erstelle CKShare
            let share = CKShare(rootRecord: memoryRecord)
            share[CKShare.SystemFieldKey.title] = memory.title as CKRecordValue?
            share[CKShare.SystemFieldKey.shareType] = "Memory" as CKRecordValue?
            
            // Speichere Share (vereinfacht)
            let recordsToSave = [memoryRecord, share]
            try await database.modifyRecords(saving: recordsToSave, deleting: [])
            
            // Update Memory mit Share Information
            memory.cloudKitShareURL = share.url?.absoluteString
            memory.isSharedViaCloudKit = true
            
            try context.save()
            return true
        } catch {
            errorMessage = "Memory Sharing fehlgeschlagen: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    /// Findet CKRecord für Trip
    private func findTripRecord(for trip: Trip) async throws -> CKRecord? {
        guard let tripId = trip.id else { return nil }
        
        let query = CKQuery(recordType: "CD_Trip", predicate: NSPredicate(format: "CD_id == %@", tripId as CVarArg))
        let (matchResults, _) = try await database.records(matching: query, resultsLimit: 1)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                return record
            case .failure(let error):
                print("❌ Trip Record Fehler: \(error)")
            }
        }
        
        return nil
    }
    
    /// Findet CKRecord für Memory
    private func findMemoryRecord(for memory: Memory) async throws -> CKRecord? {
        // Vereinfachte Implementierung - verwende eine alternative Suche
        guard let title = memory.title else { return nil }
        
        let query = CKQuery(recordType: "CD_Memory", predicate: NSPredicate(format: "title == %@", title))
        let (matchResults, _) = try await database.records(matching: query, resultsLimit: 1)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                return record
            case .failure(let error):
                print("❌ Memory Record Fehler: \(error)")
            }
        }
        
        return nil
    }
    

    
    /// Holt aktuellen User
    private func getCurrentUser() async throws -> User? {
        let userRequest: NSFetchRequest<User> = User.fetchRequest()
        userRequest.predicate = NSPredicate(format: "isCurrentUser == YES")
        userRequest.fetchLimit = 1
        
        return try context.fetch(userRequest).first
    }
}

// MARK: - Supporting Types

struct SharedTripInfo: Identifiable {
    let id = UUID()
    let tripName: String
    let shareURL: URL?
    let participantCount: Int
    let ownerName: String
}

// MARK: - CloudKit Extensions

extension CKShare.ParticipantPermission {
    var displayName: String {
        switch self {
        case .unknown:
            return "Unbekannt"
        case .none:
            return "Keine"
        case .readOnly:
            return "Nur lesen"
        case .readWrite:
            return "Lesen & Schreiben"
        @unknown default:
            return "Unbekannt"
        }
    }
}

 