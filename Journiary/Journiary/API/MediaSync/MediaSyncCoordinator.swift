//
//  MediaSyncCoordinator.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import CoreData
import Combine

/// Koordinator für die Synchronisierung von Mediendateien
class MediaSyncCoordinator: ObservableObject {
    static let shared = MediaSyncCoordinator()
    
    @Published var syncProgress: Double = 0.0
    @Published var currentOperation: String?
    @Published var isSyncing: Bool = false
    @Published var lastError: Error?
    
    private let mediaSyncManager = MediaSyncManager.shared
    private let settings = AppSettings.shared
    
    private var syncQueue = OperationQueue()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Konfiguriere die Operation Queue
        syncQueue.maxConcurrentOperationCount = 1
        syncQueue.qualityOfService = .utility
    }
    
    /// Synchronisiert alle Mediendateien für eine Memory
    /// - Parameter memory: Die Memory, deren Mediendateien synchronisiert werden sollen
    func syncMediaForMemory(_ memory: Memory) async throws {
        guard !isSyncing else {
            throw NSError(domain: "MediaSyncCoordinator", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Es läuft bereits eine Synchronisierung"])
        }
        
        guard settings.syncEnabled && settings.storageMode != .cloudKit else {
            throw NSError(domain: "MediaSyncCoordinator", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Synchronisierung ist nicht aktiviert oder im CloudKit-Modus"])
        }
        
        // Synchronisierung starten
        isSyncing = true
        syncProgress = 0.0
        currentOperation = "Mediendateien für \(memory.title ?? "Erinnerung") synchronisieren"
        
        do {
            // Prüfe, ob wir hochladen oder herunterladen müssen
            if settings.autoUploadMedia {
                try await uploadMediaForMemory(memory)
            }
            
            if settings.autoDownloadMedia {
                try await downloadMediaForMemory(memory)
            }
            
            // Synchronisierung erfolgreich
            isSyncing = false
            syncProgress = 1.0
            currentOperation = nil
        } catch {
            lastError = error
            isSyncing = false
            syncProgress = 0.0
            currentOperation = nil
            throw error
        }
    }
    
    /// Synchronisiert alle Mediendateien für eine Reise
    /// - Parameter trip: Die Reise, deren Mediendateien synchronisiert werden sollen
    func syncMediaForTrip(_ trip: Trip) async throws {
        guard !isSyncing else {
            throw NSError(domain: "MediaSyncCoordinator", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Es läuft bereits eine Synchronisierung"])
        }
        
        guard settings.syncEnabled && settings.storageMode != .cloudKit else {
            throw NSError(domain: "MediaSyncCoordinator", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Synchronisierung ist nicht aktiviert oder im CloudKit-Modus"])
        }
        
        // Synchronisierung starten
        isSyncing = true
        syncProgress = 0.0
        currentOperation = "Mediendateien für \(trip.name ?? "Reise") synchronisieren"
        
        do {
            // Alle Memories der Reise abrufen
            let memories = trip.memories?.allObjects as? [Memory] ?? []
            let totalMemories = memories.count
            
            if totalMemories == 0 {
                // Keine Memories, nichts zu tun
                isSyncing = false
                syncProgress = 1.0
                currentOperation = nil
                return
            }
            
            // Für jede Memory die Mediendateien synchronisieren
            for (index, memory) in memories.enumerated() {
                let baseProgress = Double(index) / Double(totalMemories)
                let memoryProgressHandler: (Double) -> Void = { progress in
                    self.syncProgress = baseProgress + (progress / Double(totalMemories))
                }
                
                currentOperation = "Mediendateien für \(memory.title ?? "Erinnerung") (\(index + 1)/\(totalMemories)) synchronisieren"
                
                // Prüfe, ob wir hochladen oder herunterladen müssen
                if settings.autoUploadMedia {
                    try await uploadMediaForMemory(memory, progressHandler: memoryProgressHandler)
                }
                
                if settings.autoDownloadMedia {
                    try await downloadMediaForMemory(memory, progressHandler: memoryProgressHandler)
                }
            }
            
            // Synchronisierung erfolgreich
            isSyncing = false
            syncProgress = 1.0
            currentOperation = nil
        } catch {
            lastError = error
            isSyncing = false
            syncProgress = 0.0
            currentOperation = nil
            throw error
        }
    }
    
    /// Lädt alle Mediendateien für eine Memory hoch
    /// - Parameters:
    ///   - memory: Die Memory, deren Mediendateien hochgeladen werden sollen
    ///   - progressHandler: Ein Handler für Fortschrittsupdates
    private func uploadMediaForMemory(_ memory: Memory, progressHandler: ((Double) -> Void)? = nil) async throws {
        // Prüfe WLAN-Einstellung
        if settings.uploadMediaOnWifiOnly {
            // Hier würden wir prüfen, ob WLAN verbunden ist
            // Für jetzt nehmen wir einfach an, dass WLAN verbunden ist
        }
        
        // Persistenz-Controller abrufen
        let persistenceController = PersistenceController.shared
        
        // MediaItems hochladen
        try await persistenceController.performBackgroundTask { context in
            let memoryInContext = try context.existingObject(with: memory.objectID) as! Memory
            
            // MediaItems hochladen
            _ = try await self.mediaSyncManager.syncMediaItemsForMemory(memoryInContext, context: context, progressHandler: progressHandler)
            
            // Änderungen speichern
            if context.hasChanges {
                try context.save()
            }
            
            // Lokale Mediendaten löschen, wenn gewünscht
            if self.settings.deleteLocalMediaAfterUpload {
                self.clearLocalMediaData(for: memoryInContext, context: context)
            }
        }
    }
    
    /// Lädt alle Mediendateien für eine Memory herunter
    /// - Parameters:
    ///   - memory: Die Memory, deren Mediendateien heruntergeladen werden sollen
    ///   - progressHandler: Ein Handler für Fortschrittsupdates
    private func downloadMediaForMemory(_ memory: Memory, progressHandler: ((Double) -> Void)? = nil) async throws {
        // Prüfe WLAN-Einstellung
        if settings.downloadMediaOnWifiOnly {
            // Hier würden wir prüfen, ob WLAN verbunden ist
            // Für jetzt nehmen wir einfach an, dass WLAN verbunden ist
        }
        
        // Persistenz-Controller abrufen
        let persistenceController = PersistenceController.shared
        
        // MediaItems herunterladen
        try await persistenceController.performBackgroundTask { context in
            let memoryInContext = try context.existingObject(with: memory.objectID) as! Memory
            
            // MediaItems herunterladen
            _ = try await self.mediaSyncManager.downloadMediaItemsForMemory(memoryInContext, context: context, progressHandler: progressHandler)
            
            // Änderungen speichern
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    /// Löscht lokale Mediendaten für eine Memory
    /// - Parameters:
    ///   - memory: Die Memory, deren Mediendaten gelöscht werden sollen
    ///   - context: Der NSManagedObjectContext
    private func clearLocalMediaData(for memory: Memory, context: NSManagedObjectContext) {
        guard let mediaItems = memory.mediaItems?.allObjects as? [MediaItem], !mediaItems.isEmpty else {
            return
        }
        
        for mediaItem in mediaItems {
            // Prüfe, ob das MediaItem einen objectName hat (also im Backend gespeichert ist)
            if let objectName = mediaItem.objectName, !objectName.isEmpty {
                // Lokale Daten löschen
                mediaItem.mediaData = nil
            }
        }
        
        // Änderungen speichern
        if context.hasChanges {
            try? context.save()
        }
    }
    
    /// Löscht alle lokalen Mediendaten
    func clearAllLocalMediaData() async throws {
        guard !isSyncing else {
            throw NSError(domain: "MediaSyncCoordinator", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Es läuft bereits eine Synchronisierung"])
        }
        
        // Operation starten
        isSyncing = true
        syncProgress = 0.0
        currentOperation = "Lokale Mediendaten löschen"
        
        do {
            // Persistenz-Controller abrufen
            let persistenceController = PersistenceController.shared
            
            // MediaItems abrufen und lokale Daten löschen
            try await persistenceController.performBackgroundTask { context in
                let fetchRequest: NSFetchRequest<MediaItem> = MediaItem.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "objectName != nil AND objectName != ''")
                
                let mediaItems = try context.fetch(fetchRequest)
                let totalItems = mediaItems.count
                
                for (index, mediaItem) in mediaItems.enumerated() {
                    // Lokale Daten löschen
                    mediaItem.mediaData = nil
                    
                    // Fortschritt aktualisieren
                    syncProgress = Double(index + 1) / Double(totalItems)
                }
                
                // Änderungen speichern
                if context.hasChanges {
                    try context.save()
                }
            }
            
            // Operation erfolgreich
            isSyncing = false
            syncProgress = 1.0
            currentOperation = nil
        } catch {
            lastError = error
            isSyncing = false
            syncProgress = 0.0
            currentOperation = nil
            throw error
        }
    }
} 