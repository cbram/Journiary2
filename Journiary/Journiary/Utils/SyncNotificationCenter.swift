import Foundation
import Combine

/// Notification-Center für Synchronisations-Events.
/// 
/// Diese Klasse implementiert Phase 5.4 des Implementierungsplans:
/// "UI-Aktualisierung: Sicherstellen, dass die Benutzeroberfläche nach einem 
/// erfolgreichen Sync-Zyklus die neuen Daten korrekt darstellt."
final class SyncNotificationCenter: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SyncNotificationCenter()
    
    // MARK: - Properties
    
    /// Publisher für Sync-Erfolg-Events
    private let syncSuccessSubject = PassthroughSubject<SyncSuccessEvent, Never>()
    
    /// Publisher für Sync-Fehler-Events
    private let syncErrorSubject = PassthroughSubject<SyncErrorEvent, Never>()
    
    /// Publisher für Sync-Start-Events
    private let syncStartSubject = PassthroughSubject<SyncStartEvent, Never>()
    
    /// Öffentlicher Publisher für Sync-Erfolg
    var syncSuccessPublisher: AnyPublisher<SyncSuccessEvent, Never> {
        syncSuccessSubject.eraseToAnyPublisher()
    }
    
    /// Öffentlicher Publisher für Sync-Fehler
    var syncErrorPublisher: AnyPublisher<SyncErrorEvent, Never> {
        syncErrorSubject.eraseToAnyPublisher()
    }
    
    /// Öffentlicher Publisher für Sync-Start
    var syncStartPublisher: AnyPublisher<SyncStartEvent, Never> {
        syncStartSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    private init() {
        // Private Initialization für Singleton
    }
    
    // MARK: - Public Methods
    
    /// Meldet einen erfolgreichen Sync-Zyklus
    func notifySyncSuccess(
        reason: String,
        timestamp: Date = Date(),
        syncedEntities: SyncedEntities = SyncedEntities()
    ) {
        let event = SyncSuccessEvent(
            reason: reason,
            timestamp: timestamp,
            syncedEntities: syncedEntities
        )
        
        print("📢 SyncNotificationCenter: Sync-Erfolg gemeldet - \(reason)")
        
        // Auf dem Main-Thread senden
        DispatchQueue.main.async {
            self.syncSuccessSubject.send(event)
        }
    }
    
    /// Meldet einen Sync-Fehler
    func notifySyncError(
        reason: String,
        error: Error,
        timestamp: Date = Date()
    ) {
        let event = SyncErrorEvent(
            reason: reason,
            error: error,
            timestamp: timestamp
        )
        
        print("📢 SyncNotificationCenter: Sync-Fehler gemeldet - \(reason): \(error.localizedDescription)")
        
        // Auf dem Main-Thread senden
        DispatchQueue.main.async {
            self.syncErrorSubject.send(event)
        }
    }
    
    /// Meldet den Start eines Sync-Zyklus
    func notifySyncStart(
        reason: String,
        timestamp: Date = Date()
    ) {
        let event = SyncStartEvent(
            reason: reason,
            timestamp: timestamp
        )
        
        print("📢 SyncNotificationCenter: Sync-Start gemeldet - \(reason)")
        
        // Auf dem Main-Thread senden
        DispatchQueue.main.async {
            self.syncStartSubject.send(event)
        }
    }
}

// MARK: - Event Structures

/// Event für erfolgreiche Synchronisation
struct SyncSuccessEvent {
    let reason: String
    let timestamp: Date
    let syncedEntities: SyncedEntities
}

/// Event für Sync-Fehler
struct SyncErrorEvent {
    let reason: String
    let error: Error
    let timestamp: Date
}

/// Event für Sync-Start
struct SyncStartEvent {
    let reason: String
    let timestamp: Date
}

/// Details über synchronisierte Entitäten
struct SyncedEntities {
    let tripsUpdated: Int
    let memoriesUpdated: Int
    let mediaItemsUpdated: Int
    let gpxTracksUpdated: Int
    let tagsUpdated: Int
    let tagCategoriesUpdated: Int
    let bucketListItemsUpdated: Int
    
    init(
        tripsUpdated: Int = 0,
        memoriesUpdated: Int = 0,
        mediaItemsUpdated: Int = 0,
        gpxTracksUpdated: Int = 0,
        tagsUpdated: Int = 0,
        tagCategoriesUpdated: Int = 0,
        bucketListItemsUpdated: Int = 0
    ) {
        self.tripsUpdated = tripsUpdated
        self.memoriesUpdated = memoriesUpdated
        self.mediaItemsUpdated = mediaItemsUpdated
        self.gpxTracksUpdated = gpxTracksUpdated
        self.tagsUpdated = tagsUpdated
        self.tagCategoriesUpdated = tagCategoriesUpdated
        self.bucketListItemsUpdated = bucketListItemsUpdated
    }
    
    /// Gesamtanzahl der synchronisierten Entitäten
    var totalUpdated: Int {
        tripsUpdated + memoriesUpdated + mediaItemsUpdated + 
        gpxTracksUpdated + tagsUpdated + tagCategoriesUpdated + 
        bucketListItemsUpdated
    }
    
    /// Prüft ob Entitäten synchronisiert wurden
    var hasUpdates: Bool {
        totalUpdated > 0
    }
}

// MARK: - Notification Namen (für legacy NotificationCenter falls nötig)

extension Notification.Name {
    static let syncDidSucceed = Notification.Name("com.journiary.sync.didSucceed")
    static let syncDidFail = Notification.Name("com.journiary.sync.didFail")
    static let syncDidStart = Notification.Name("com.journiary.sync.didStart")
} 