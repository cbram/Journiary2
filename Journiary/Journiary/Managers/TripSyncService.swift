import Foundation
import CoreData
import Combine

// MARK: - TripSyncService

/// Service für bidirektionale Synchronisation zwischen CoreData und Supabase
/// Implementiert "Last-Write-Wins" Konfliktlösung und inkrementelle Synchronisation
@MainActor
class TripSyncService: ObservableObject {
    
    // MARK: - Properties
    
    private let supabaseManager = SupabaseManager.shared
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    @Published var syncProgress: SyncProgress = SyncProgress()
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [SyncLogEntry] = []
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.lastSyncDate = UserDefaults.standard.object(forKey: "lastTripSyncDate") as? Date
        
        // Beobachte Verbindungsstatus
        supabaseManager.$connectionStatus
            .sink { [weak self] status in
                if status == .connected {
                    Task {
                        await self?.performIncrementalSync()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Sync Methods
    
    /// Führt eine vollständige bidirektionale Synchronisation durch
    func performFullSync() async {
        print("🔄 Starte vollständige Synchronisation...")
        
        syncProgress = SyncProgress()
        syncErrors.removeAll()
        
        do {
            // Schritt 1: Upload lokaler Änderungen
            await uploadLocalChanges()
            
            // Schritt 2: Download Remote-Änderungen
            await downloadRemoteChanges()
            
            // Schritt 3: Sync-Datum aktualisieren
            updateLastSyncDate()
            
            print("✅ Vollständige Synchronisation erfolgreich abgeschlossen")
            
        } catch {
            print("❌ Fehler bei der vollständigen Synchronisation: \(error.localizedDescription)")
            addSyncError(error, operation: "Vollständige Synchronisation")
        }
    }
    
    /// Führt eine inkrementelle Synchronisation durch (nur Änderungen seit letztem Sync)
    func performIncrementalSync() async {
        guard let lastSync = lastSyncDate else {
            await performFullSync()
            return
        }
        
        print("🔄 Starte inkrementelle Synchronisation seit \(lastSync)...")
        
        syncProgress = SyncProgress()
        syncErrors.removeAll()
        
        // 🔧 Tracking für bereits verarbeitete Trips
        var processedTripIds = Set<UUID>()
        
        do {
            // Schritt 1: Upload lokaler Änderungen seit letztem Sync
            await uploadLocalChangesSince(lastSync)
            
            // Sammle IDs der gerade hochgeladenen Trips
            let uploadedTripIds = await getUploadedTripIds()
            processedTripIds.formUnion(uploadedTripIds)
            
            // Schritt 2: Download Remote-Änderungen seit letztem Sync (ohne gerade hochgeladene)
            await downloadRemoteChangesSince(lastSync, excluding: processedTripIds)
            
            // Schritt 3: Sync-Datum aktualisieren
            updateLastSyncDate()
            
            print("✅ Inkrementelle Synchronisation erfolgreich abgeschlossen")
            
        } catch {
            print("❌ Fehler bei der inkrementellen Synchronisation: \(error.localizedDescription)")
            addSyncError(error, operation: "Inkrementelle Synchronisation")
        }
    }
    
    /// Synchronisiert einen einzelnen Trip
    func syncSingleTrip(_ trip: Trip) async {
        print("🔄 Synchronisiere Trip: \(trip.name ?? "Unnamed")")
        
        do {
            let supabaseTrip = try trip.toSupabaseTrip()
            
            // Überprüfe, ob der Trip auf Supabase existiert
            let exists = try await supabaseManager.tripExists(id: trip.id!)
            
            if exists {
                // Update existierenden Trip
                await updateTripOnSupabase(trip, supabaseTrip: supabaseTrip)
            } else {
                // Erstelle neuen Trip
                await createTripOnSupabase(trip, supabaseTrip: supabaseTrip)
            }
            
            print("✅ Trip erfolgreich synchronisiert")
            
        } catch {
            print("❌ Fehler beim Synchronisieren des Trips: \(error.localizedDescription)")
            addSyncError(error, operation: "Einzelner Trip Sync")
        }
    }
    
    // MARK: - Upload Methods
    
    private func uploadLocalChanges() async {
        print("📤 Lade lokale Änderungen hoch...")
        
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == YES")
        
        do {
            let tripsToSync = try context.fetch(request)
            syncProgress.totalItems = tripsToSync.count
            
            for trip in tripsToSync {
                await uploadSingleTrip(trip)
                syncProgress.processedItems += 1
            }
            
            print("✅ \(tripsToSync.count) lokale Trips hochgeladen")
            
        } catch {
            print("❌ Fehler beim Laden lokaler Trips: \(error.localizedDescription)")
            addSyncError(error, operation: "Lokale Trips laden")
        }
    }
    
    private func uploadLocalChangesSince(_ date: Date) async {
        print("📤 Lade lokale Änderungen seit \(date) hoch...")
        
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == YES OR updatedAt > %@", date as NSDate)
        
        do {
            let tripsToSync = try context.fetch(request)
            syncProgress.totalItems = tripsToSync.count
            
            for trip in tripsToSync {
                await uploadSingleTrip(trip)
                syncProgress.processedItems += 1
            }
            
            print("✅ \(tripsToSync.count) lokale Trips seit \(date) hochgeladen")
            
        } catch {
            print("❌ Fehler beim Laden lokaler Trips seit \(date): \(error.localizedDescription)")
            addSyncError(error, operation: "Lokale Trips seit Datum laden")
        }
    }
    
    private func uploadSingleTrip(_ trip: Trip) async {
        do {
            // 🔧 Stelle sicher, dass der Trip eine UUID hat
            if trip.id == nil {
                trip.id = UUID()
                try context.save()
                print("🔧 UUID für Trip generiert: \(trip.id!)")
            }
            
            // 🖼️ Titelfoto-Upload prüfen und durchführen
            await uploadCoverImageIfNeeded(trip)
            
            let supabaseTrip = try trip.toSupabaseTrip()
            
            // Überprüfe, ob der Trip auf Supabase existiert
            let exists = try await supabaseManager.tripExists(id: trip.id!)
            
            if exists {
                await updateTripOnSupabase(trip, supabaseTrip: supabaseTrip)
            } else {
                await createTripOnSupabase(trip, supabaseTrip: supabaseTrip)
            }
            
        } catch {
            print("❌ Fehler beim Hochladen des Trips: \(error.localizedDescription)")
            addSyncError(error, operation: "Trip Upload")
        }
    }
    
    private func createTripOnSupabase(_ trip: Trip, supabaseTrip: SupabaseTrip) async {
        do {
            let createdTrip = try await supabaseManager.createTrip(supabaseTrip.toInsert())
            
            // Aktualisiere lokale Sync-Metadaten
            trip.supabaseID = createdTrip.id
            trip.syncVersion = Int32(createdTrip.syncVersion)
            trip.needsSync = false
            trip.lastSyncDate = Date()
            
            // 🔧 Speichere sofort und aktualisiere Kontext
            try context.save()
            context.refreshAllObjects()
            
            print("✅ Trip erfolgreich zu Supabase hochgeladen: \(trip.name ?? "Unnamed")")
            
        } catch {
            print("❌ Fehler beim Erstellen des Trips auf Supabase: \(error.localizedDescription)")
            addSyncError(error, operation: "Trip Erstellung")
        }
    }
    
    private func updateTripOnSupabase(_ trip: Trip, supabaseTrip: SupabaseTrip) async {
        do {
            // 🔧 Sichere UUID-Überprüfung
            guard let tripId = trip.id else {
                print("❌ Trip hat keine UUID - kann nicht aktualisiert werden")
                return
            }
            
            // Überprüfe auf Konflikte
            let remoteMetadata = try await supabaseManager.fetchTripSyncMetadata(id: tripId)
            
            if let conflict = detectConflict(localTrip: trip, remoteMetadata: remoteMetadata) {
                await resolveConflict(conflict)
                return
            }
            
            // Kein Konflikt - Update durchführen
            let updatedTrip = try await supabaseManager.updateTrip(supabaseTrip)
            
            // Aktualisiere lokale Sync-Metadaten
            trip.syncVersion = Int32(updatedTrip.syncVersion)
            trip.needsSync = false
            trip.lastSyncDate = Date()
            
            // 🔧 Speichere sofort und aktualisiere Kontext
            try context.save()
            context.refreshAllObjects()
            
            print("✅ Trip erfolgreich auf Supabase aktualisiert: \(trip.name ?? "Unnamed")")
            
        } catch {
            print("❌ Fehler beim Aktualisieren des Trips auf Supabase: \(error.localizedDescription)")
            addSyncError(error, operation: "Trip Update")
        }
    }
    
    // MARK: - Download Methods
    
    private func downloadRemoteChanges() async {
        print("📥 Lade Remote-Änderungen herunter...")
        
        do {
            let remoteTrips = try await supabaseManager.fetchAllTrips()
            
            for remoteTrip in remoteTrips {
                await processSingleRemoteTrip(remoteTrip)
            }
            
            print("✅ \(remoteTrips.count) Remote-Trips verarbeitet")
            
        } catch {
            print("❌ Fehler beim Laden der Remote-Trips: \(error.localizedDescription)")
            addSyncError(error, operation: "Remote-Trips laden")
        }
    }
    
    private func downloadRemoteChangesSince(_ date: Date, excluding processedTripIds: Set<UUID> = []) async {
        print("📥 Lade Remote-Änderungen seit \(date) herunter...")
        
        do {
            let remoteTrips = try await supabaseManager.fetchTripsModifiedAfter(date)
            
            // 🔧 Filtere bereits verarbeitete Trips aus
            let newRemoteTrips = remoteTrips.filter { !processedTripIds.contains($0.id) }
            
            print("ℹ️ \(remoteTrips.count) Remote-Trips gefunden, \(newRemoteTrips.count) davon sind neu (gefiltert: \(remoteTrips.count - newRemoteTrips.count))")
            
            for remoteTrip in newRemoteTrips {
                await processSingleRemoteTrip(remoteTrip)
            }
            
            print("✅ \(newRemoteTrips.count) Remote-Trips seit \(date) verarbeitet")
            
        } catch {
            print("❌ Fehler beim Laden der Remote-Trips seit \(date): \(error.localizedDescription)")
            addSyncError(error, operation: "Remote-Trips seit Datum laden")
        }
    }
    
    private func processSingleRemoteTrip(_ remoteTrip: SupabaseTrip) async {
        let remoteTripId = remoteTrip.id
        
        // 🔧 Suche lokalen Trip sowohl nach UUID als auch nach supabaseID
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@ OR supabaseID == %@", remoteTripId as CVarArg, remoteTripId as CVarArg)
        request.fetchLimit = 1
        
        do {
            let localTrips = try context.fetch(request)
            
            if let localTrip = localTrips.first {
                // Lokaler Trip existiert - Update oder Konflikt
                print("🔄 Lokaler Trip gefunden für Remote-Trip: \(remoteTrip.name ?? "Unnamed") (ID: \(remoteTripId), LocalID: \(localTrip.id?.uuidString ?? "nil"), LocalSupabaseID: \(localTrip.supabaseID?.uuidString ?? "nil"))")
                await updateLocalTrip(localTrip, with: remoteTrip)
            } else {
                // Lokaler Trip existiert nicht - Erstelle neuen
                print("➕ Erstelle neuen lokalen Trip: \(remoteTrip.name ?? "Unnamed") (RemoteID: \(remoteTripId))")
                await createLocalTrip(from: remoteTrip)
            }
            
        } catch {
            print("❌ Fehler beim Verarbeiten des Remote-Trips: \(error.localizedDescription)")
            addSyncError(error, operation: "Remote-Trip Verarbeitung")
        }
    }
    
    private func updateLocalTrip(_ localTrip: Trip, with remoteTrip: SupabaseTrip) async {
        // Überprüfe auf Konflikte
        if let conflict = detectConflict(localTrip: localTrip, remoteTrip: remoteTrip) {
            await resolveConflict(conflict)
            return
        }
        
        // Kein Konflikt - Update durchführen
        do {
            try localTrip.updateFromSupabase(remoteTrip)
            try context.save()
            
            // 🖼️ Titelfoto herunterladen falls nötig
            await downloadCoverImageIfNeeded(localTrip)
            
            print("✅ Lokaler Trip aktualisiert: \(localTrip.name ?? "Unnamed")")
            
        } catch {
            print("❌ Fehler beim Aktualisieren des lokalen Trips: \(error.localizedDescription)")
            addSyncError(error, operation: "Lokaler Trip Update")
        }
    }
    
    private func createLocalTrip(from remoteTrip: SupabaseTrip) async {
        do {
            let localTrip = Trip(context: context)
            try localTrip.updateFromSupabase(remoteTrip)
            
            try context.save()
            
            // 🖼️ Titelfoto herunterladen falls nötig
            await downloadCoverImageIfNeeded(localTrip)
            
            print("✅ Lokaler Trip erstellt: \(localTrip.name ?? "Unnamed")")
            
        } catch {
            print("❌ Fehler beim Erstellen des lokalen Trips: \(error.localizedDescription)")
            addSyncError(error, operation: "Lokaler Trip Erstellung")
        }
    }
    
    // MARK: - Conflict Resolution
    
    private func detectConflict(localTrip: Trip, remoteMetadata: TripSyncMetadata) -> SyncConflict? {
        guard let localUpdatedAt = localTrip.updatedAt,
              let tripId = localTrip.id else { return nil }
        
        // Überprüfe Sync-Version
        if localTrip.syncVersion != remoteMetadata.syncVersion {
            return SyncConflict(
                tripId: tripId,
                type: .versionMismatch,
                localUpdatedAt: localUpdatedAt,
                remoteUpdatedAt: remoteMetadata.updatedAt
            )
        }
        
        return nil
    }
    
    private func detectConflict(localTrip: Trip, remoteTrip: SupabaseTrip) -> SyncConflict? {
        guard let localUpdatedAt = localTrip.updatedAt,
              let tripId = localTrip.id else { return nil }
        let remoteUpdatedAt = remoteTrip.updatedAt
        
        // Überprüfe Sync-Version
        if localTrip.syncVersion != remoteTrip.syncVersion {
            return SyncConflict(
                tripId: tripId,
                type: .versionMismatch,
                localUpdatedAt: localUpdatedAt,
                remoteUpdatedAt: remoteUpdatedAt
            )
        }
        
        return nil
    }
    
    private func resolveConflict(_ conflict: SyncConflict) async {
        print("⚠️ Konflikt erkannt für Trip \(conflict.tripId)")
        
        // "Last-Write-Wins" Strategie
        if conflict.localUpdatedAt > conflict.remoteUpdatedAt {
            print("🔄 Lokale Version ist neuer - Upload wird forciert")
            await forceUploadLocalTrip(conflict.tripId)
        } else {
            print("🔄 Remote-Version ist neuer - Download wird forciert")
            await forceDownloadRemoteTrip(conflict.tripId)
        }
    }
    
    private func forceUploadLocalTrip(_ tripId: UUID) async {
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", tripId as CVarArg)
        request.fetchLimit = 1
        
        do {
            let trips = try context.fetch(request)
            if let trip = trips.first {
                await uploadSingleTrip(trip)
            }
        } catch {
            print("❌ Fehler beim Forcieren des Uploads: \(error.localizedDescription)")
        }
    }
    
    private func forceDownloadRemoteTrip(_ tripId: UUID) async {
        do {
            let remoteTrip = try await supabaseManager.fetchTrip(id: tripId)
            await processSingleRemoteTrip(remoteTrip)
        } catch {
            print("❌ Fehler beim Forcieren des Downloads: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cover Image Upload
    
    private func uploadCoverImageIfNeeded(_ trip: Trip) async {
        // Prüfe, ob ein Titelfoto vorhanden ist und hochgeladen werden muss
        guard let coverImageData = trip.coverImageData,
              !coverImageData.isEmpty else {
            return
        }
        
        // Prüfe, ob bereits eine URL vorhanden ist (vermeidet doppelte Uploads)
        if let existingURL = trip.coverImageUrl, !existingURL.isEmpty {
            print("ℹ️ Titelfoto bereits hochgeladen: \(existingURL)")
            return
        }
        
        do {
            guard let tripId = trip.id else {
                print("❌ Trip hat keine UUID - Titelfoto kann nicht hochgeladen werden")
                return
            }
            
            print("🖼️ Lade Titelfoto hoch für Trip: \(trip.name ?? "Unnamed")")
            
            // Bild zu Supabase Storage hochladen (mit Retry-Mechanismus)
            let imageURL = try await supabaseManager.uploadCoverImageWithRetry(coverImageData, tripId: tripId)
            
            // URL in Trip speichern
            trip.coverImageUrl = imageURL
            trip.needsSync = true // Markiere für erneute Synchronisation
            
            try context.save()
            
            print("✅ Titelfoto erfolgreich hochgeladen: \(imageURL)")
            
        } catch {
            print("❌ Fehler beim Hochladen des Titelfotos: \(error.localizedDescription)")
            addSyncError(error, operation: "Cover Image Upload")
        }
    }
    
    // MARK: - Cover Image Download
    
    private func downloadCoverImageIfNeeded(_ trip: Trip) async {
        // Prüfe, ob eine URL vorhanden ist, aber keine lokalen Bilddaten
        guard let coverImageURL = trip.coverImageUrl,
              !coverImageURL.isEmpty,
              trip.coverImageData == nil else {
            return
        }
        
        do {
            print("🖼️ Lade Titelfoto herunter für Trip: \(trip.name ?? "Unnamed")")
            
            let imageData = try await supabaseManager.downloadCoverImage(from: coverImageURL)
            
            // Bilddaten in Trip speichern
            trip.coverImageData = imageData
            
            try context.save()
            
            print("✅ Titelfoto erfolgreich heruntergeladen")
            
        } catch {
            print("❌ Fehler beim Herunterladen des Titelfotos: \(error.localizedDescription)")
            addSyncError(error, operation: "Cover Image Download")
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateLastSyncDate() {
        let now = Date()
        lastSyncDate = now
        UserDefaults.standard.set(now, forKey: "lastTripSyncDate")
    }
    
    /// Sammelt die IDs der Trips, die gerade hochgeladen wurden
    private func getUploadedTripIds() async -> Set<UUID> {
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.predicate = NSPredicate(format: "supabaseID != nil AND lastSyncDate != nil")
        
        do {
            let syncedTrips = try context.fetch(request)
            let recentTripIds = syncedTrips.compactMap { trip -> UUID? in
                // Nur Trips die in den letzten 30 Sekunden synchronisiert wurden
                // (verhindert false positives bei älteren Trips)
                guard let tripId = trip.id,
                      let lastSync = trip.lastSyncDate else { return nil }
                
                if Date().timeIntervalSince(lastSync) < 30 {
                    return tripId
                }
                return nil
            }
            return Set(recentTripIds)
        } catch {
            print("❌ Fehler beim Sammeln der Upload-IDs: \(error.localizedDescription)")
            return []
        }
    }
    
    private func addSyncError(_ error: Error, operation: String) {
        let syncError = SyncLogEntry(
            operation: operation,
            error: error,
            timestamp: Date()
        )
        syncErrors.append(syncError)
    }
}

// MARK: - Supporting Types

struct SyncProgress {
    var totalItems: Int = 0
    var processedItems: Int = 0
    
    var progress: Double {
        guard totalItems > 0 else { return 0 }
        return Double(processedItems) / Double(totalItems)
    }
    
    var isComplete: Bool {
        return processedItems >= totalItems && totalItems > 0
    }
}

struct SyncLogEntry {
    let operation: String
    let error: Error
    let timestamp: Date
    
    var localizedDescription: String {
        return "\(operation): \(error.localizedDescription)"
    }
}

struct SyncConflict {
    let tripId: UUID
    let type: ConflictType
    let localUpdatedAt: Date
    let remoteUpdatedAt: Date
    
    enum ConflictType {
        case versionMismatch
        case dataMismatch
    }
} 