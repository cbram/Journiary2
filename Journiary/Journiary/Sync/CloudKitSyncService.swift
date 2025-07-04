//
//  CloudKitSyncService.swift
//  Journiary
//
//  Synchronisiert Core Data mit CloudKit.
//  Aktueller Stand: Minimal-Stub, um die neue SyncCoordinator-Logik zu kompilieren.
//  Die echte Implementierung erfolgt in den nächsten Schritten.
//

import Foundation
import Combine
import CloudKit
import CoreData
import os

/// Fehler, die beim CloudKit-Sync auftreten können
enum CloudKitSyncError: LocalizedError {
    case notAvailable(String)
    case failed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable(let msg):
            return "CloudKit nicht verfügbar: \(msg)"
        case .failed(let msg):
            return "CloudKit-Sync fehlgeschlagen: \(msg)"
        case .unknown(let msg):
            return "Unbekannter CloudKit-Fehler: \(msg)"
        }
    }
}

/// Minimaler Service, der einen Full-Sync mit CloudKit ausführt.
/// Die API ist bewusst analog zu `GraphQLSyncService`, damit der `SyncCoordinator`
/// sie polymorph nutzen kann.
final class CloudKitSyncService: ObservableObject {

    @Published var isSyncing = false
    @Published var progress: Double = 0.0
    @Published var lastSyncDate: Date?
    @Published var syncError: CloudKitSyncError?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - CloudKit Properties
    private let container = CKContainer.default()
    private let database = CKContainer.default().privateCloudDatabase
    private let context = EnhancedPersistenceController.shared.syncContext
    private let logger = Logger(subsystem: "com.journiary.sync", category: "cloudkit")

    /// Führt einen vollständigen Upload + Download durch (Stub)
    func performFullSync() -> AnyPublisher<Bool, CloudKitSyncError> {
        isSyncing = true
        progress = 0.0
        syncError = nil

        return Future<Bool, CloudKitSyncError> { promise in
            Task {
                do {
                    // 1) Upload lokale Änderungen (Trips & Memories)
                    try await self.pushLocalTrips()
                    await MainActor.run { self.progress = 0.25 }

                    try await self.pushLocalMemories()
                    await MainActor.run { self.progress = 0.5 }

                    // 2) Download Änderungen vom Server (Trips & Memories)
                    try await self.pullRemoteTrips()
                    await MainActor.run { self.progress = 0.75 }

                    try await self.pullRemoteMemories()
                    await MainActor.run {
                        self.progress = 1.0
                        self.isSyncing = false
                        self.lastSyncDate = Date()
                    }

                    promise(.success(true))
                } catch let error as CloudKitSyncError {
                    self.logger.error("CloudKitSync fehlgeschlagen: \(error.localizedDescription)")
                    await MainActor.run {
                        self.isSyncing = false
                        self.syncError = error
                    }
                    promise(.failure(error))
                } catch {
                    self.logger.error("CloudKitSync unbekannter Fehler: \(error.localizedDescription)")
                    let ckError: CloudKitSyncError = .unknown(error.localizedDescription)
                    await MainActor.run {
                        self.isSyncing = false
                        self.syncError = ckError
                    }
                    promise(.failure(ckError))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Upload Phase (Trips minimal)

    private func pushLocalTrips() async throws {
        logger.debug("Starte Upload-Phase (Trips)…")

        // Alle Trips aus Core Data laden
        let fetch: NSFetchRequest<Trip> = Trip.fetchRequest()
        let localTrips = try context.fetch(fetch)

        for trip in localTrips {
            guard let tripDTO = TripDTO.from(coreData: trip) else { continue }

            // Prüfe, ob CKRecord existiert
            let predicate = NSPredicate(format: "CD_id == %@", tripDTO.id)
            let query = CKQuery(recordType: "CD_Trip", predicate: predicate)

            let (results, _) = try await database.records(matching: query, resultsLimit: 1)

            var record: CKRecord
            if let (_, result) = results.first, case .success(let existing) = result {
                record = existing
            } else {
                record = CKRecord(recordType: "CD_Trip")
            }

            // Mappe Felder (minimal)
            record["CD_id"] = tripDTO.id as CKRecordValue
            record["name"] = tripDTO.name as CKRecordValue
            record["isActive"] = tripDTO.isActive as CKRecordValue

            if let start = tripDTO.startDate { record["startDate"] = start as CKRecordValue }
            if let end = tripDTO.endDate { record["endDate"] = end as CKRecordValue }

            // Speichere Record
            _ = try await database.save(record)
            logger.debug("✅ Trip \(tripDTO.name) an CloudKit übertragen")
        }
    }

    // MARK: - Download Phase (Trips minimal)

    private func pullRemoteTrips() async throws {
        logger.debug("Starte Download-Phase (Trips)…")

        let query = CKQuery(recordType: "CD_Trip", predicate: NSPredicate(value: true))
        var fetchedTrips: [TripDTO] = []

        let (matchResults, _) = try await database.records(matching: query)

        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                // Mappe minimal
                guard let id = record["CD_id"] as? String,
                      let name = record["name"] as? String else { continue }

                let dto = TripDTO(
                    id: id,
                    name: name,
                    tripDescription: record["tripDescription"] as? String,
                    coverImageObjectName: nil,
                    coverImageUrl: nil,
                    travelCompanions: record["travelCompanions"] as? String,
                    visitedCountries: record["visitedCountries"] as? String,
                    startDate: record["startDate"] as? Date,
                    endDate: record["endDate"] as? Date,
                    isActive: record["isActive"] as? Bool ?? false,
                    totalDistance: record["totalDistance"] as? Double ?? 0.0,
                    gpsTrackingEnabled: record["gpsTrackingEnabled"] as? Bool ?? true,
                    createdAt: record.creationDate ?? Date(),
                    updatedAt: record.modificationDate ?? Date()
                )

                fetchedTrips.append(dto)

            case .failure(let error):
                logger.error("❌ CKRecord Fehler: \(error.localizedDescription)")
            }
        }

        // Core Data aktualisieren
        context.performAndWait {
            for dto in fetchedTrips {
                _ = dto.toCoreData(context: context)
            }
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    logger.error("❌ Core Data Save nach CloudKit-Download fehlgeschlagen: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: Upload Phase Memories

    private func pushLocalMemories() async throws {
        logger.debug("Starte Upload-Phase (Memories)…")

        let fetch: NSFetchRequest<Memory> = Memory.fetchRequest()
        let localMems = try context.fetch(fetch)

        for mem in localMems {
            guard let dto = MemoryDTO.from(coreData: mem) else { continue }

            let predicate = NSPredicate(format: "CD_id == %@", dto.id)
            let query = CKQuery(recordType: "CD_Memory", predicate: predicate)

            let (results, _) = try await database.records(matching: query, resultsLimit: 1)

            var record: CKRecord
            if let (_, result) = results.first, case .success(let existing) = result {
                record = existing
            } else {
                record = CKRecord(recordType: "CD_Memory")
            }

            record["CD_id"] = dto.id as CKRecordValue
            record["title"] = dto.title as CKRecordValue
            if let content = dto.content { record["content"] = content as CKRecordValue }
            if let ts = dto.createdAt { record["timestamp"] = ts as CKRecordValue }
            if let tripId = dto.tripId { record["tripId"] = tripId as CKRecordValue }

            if let loc = dto.location {
                record["latitude"] = loc.latitude as CKRecordValue
                record["longitude"] = loc.longitude as CKRecordValue
                if let name = loc.name { record["locationName"] = name as CKRecordValue }
            }

            _ = try await database.save(record)
            logger.debug("✅ Memory \(dto.title) an CloudKit übertragen")
        }
    }

    // MARK: Download Phase Memories

    private func pullRemoteMemories() async throws {
        logger.debug("Starte Download-Phase (Memories)…")

        let query = CKQuery(recordType: "CD_Memory", predicate: NSPredicate(value: true))
        var fetched: [MemoryDTO] = []

        let (matchResults, _) = try await database.records(matching: query)

        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                guard let id = record["CD_id"] as? String,
                      let title = record["title"] as? String else { continue }

                let loc: LocationDTO? = {
                    if let lat = record["latitude"] as? Double,
                       let lon = record["longitude"] as? Double {
                        return LocationDTO(latitude: lat, longitude: lon, name: record["locationName"] as? String)
                    }
                    return nil
                }()

                let dto = MemoryDTO(
                    id: id,
                    title: title,
                    content: record["content"] as? String,
                    location: loc,
                    tripId: record["tripId"] as? String,
                    userId: "unknown",
                    createdAt: record["timestamp"] as? Date,
                    updatedAt: record.modificationDate,
                    creatorId: nil
                )

                fetched.append(dto)

            case .failure(let error):
                logger.error("❌ CKRecord Fehler Memory: \(error.localizedDescription)")
            }
        }

        context.performAndWait {
            for dto in fetched {
                _ = dto.toCoreData(context: context)
            }
            if context.hasChanges {
                try? context.save()
            }
        }
    }
} 