//
//  MediaSyncManager.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import CoreData
import UIKit

/// Status eines Medien-Uploads
enum MediaUploadStatus {
    case pending
    case uploading(progress: Double)
    case completed(objectName: String)
    case failed(error: Error)
}

/// Status eines Medien-Downloads
enum MediaDownloadStatus {
    case pending
    case downloading(progress: Double)
    case completed(data: Data)
    case failed(error: Error)
}

/// Manager für die Synchronisierung von Mediendateien
class MediaSyncManager {
    static let shared = MediaSyncManager()
    
    private let minioClient = MinIOClient.shared
    private let settings = AppSettings.shared
    
    private init() {}
    
    /// Synchronisiert alle MediaItems für eine Memory
    /// - Parameters:
    ///   - memory: Die Memory, deren MediaItems synchronisiert werden sollen
    ///   - context: Der NSManagedObjectContext
    ///   - progressHandler: Ein Handler für Fortschrittsupdates
    /// - Returns: Ein Array der synchronisierten MediaItems
    func syncMediaItemsForMemory(_ memory: Memory, context: NSManagedObjectContext, progressHandler: ((Double) -> Void)? = nil) async throws -> [MediaItem] {
        guard let mediaItems = memory.mediaItems?.allObjects as? [MediaItem], !mediaItems.isEmpty else {
            return []
        }
        
        var synchronizedMediaItems: [MediaItem] = []
        let totalItems = mediaItems.count
        
        for (index, mediaItem) in mediaItems.enumerated() {
            // Fortschritt aktualisieren
            let progress = Double(index) / Double(totalItems)
            progressHandler?(progress)
            
            do {
                // Prüfe, ob wir hochladen oder herunterladen müssen
                if let mediaData = mediaItem.mediaData, mediaData.count > 0, mediaItem.objectName == nil || mediaItem.objectName?.isEmpty == true {
                    // MediaItem hat Daten, aber keinen objectName -> hochladen
                    try await uploadMediaItem(mediaItem, context: context)
                } else if mediaItem.mediaData == nil || mediaItem.mediaData?.count == 0, let objectName = mediaItem.objectName, !objectName.isEmpty {
                    // MediaItem hat keinen Daten, aber einen objectName -> herunterladen
                    try await downloadMediaItem(mediaItem, context: context)
                }
                
                synchronizedMediaItems.append(mediaItem)
            } catch {
                print("❌ Fehler bei der Synchronisierung von MediaItem \(mediaItem.objectID): \(error)")
                // Wir werfen den Fehler nicht weiter, sondern machen mit dem nächsten MediaItem weiter
            }
        }
        
        // Fortschritt abschließen
        progressHandler?(1.0)
        
        return synchronizedMediaItems
    }
    
    /// Lädt alle MediaItems für eine Memory herunter
    /// - Parameters:
    ///   - memory: Die Memory, deren MediaItems heruntergeladen werden sollen
    ///   - context: Der NSManagedObjectContext
    ///   - progressHandler: Ein Handler für Fortschrittsupdates
    /// - Returns: Ein Array der heruntergeladenen MediaItems
    func downloadMediaItemsForMemory(_ memory: Memory, context: NSManagedObjectContext, progressHandler: ((Double) -> Void)? = nil) async throws -> [MediaItem] {
        guard let mediaItems = memory.mediaItems?.allObjects as? [MediaItem], !mediaItems.isEmpty else {
            return []
        }
        
        var downloadedMediaItems: [MediaItem] = []
        let totalItems = mediaItems.count
        
        // Filtere MediaItems, die heruntergeladen werden müssen
        let itemsToDownload = mediaItems.filter { mediaItem in
            return (mediaItem.mediaData == nil || mediaItem.mediaData?.count == 0) && mediaItem.objectName != nil && !mediaItem.objectName!.isEmpty
        }
        
        if itemsToDownload.isEmpty {
            progressHandler?(1.0)
            return []
        }
        
        for (index, mediaItem) in itemsToDownload.enumerated() {
            // Fortschritt aktualisieren
            let progress = Double(index) / Double(totalItems)
            progressHandler?(progress)
            
            do {
                // MediaItem herunterladen
                try await downloadMediaItem(mediaItem, context: context)
                downloadedMediaItems.append(mediaItem)
            } catch {
                print("❌ Fehler beim Herunterladen von MediaItem \(mediaItem.objectID): \(error)")
                // Wir werfen den Fehler nicht weiter, sondern machen mit dem nächsten MediaItem weiter
            }
        }
        
        // Fortschritt abschließen
        progressHandler?(1.0)
        
        return downloadedMediaItems
    }
    
    /// Lädt ein MediaItem hoch
    /// - Parameters:
    ///   - mediaItem: Das hochzuladende MediaItem
    ///   - context: Der NSManagedObjectContext
    func uploadMediaItem(_ mediaItem: MediaItem, context: NSManagedObjectContext) async throws {
        guard let mediaData = mediaItem.mediaData, mediaData.count > 0 else {
            throw NSError(domain: "MediaSyncManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Keine Mediendaten zum Hochladen vorhanden"])
        }
        
        // Wenn kein Dateiname vorhanden ist, generieren wir einen
        if mediaItem.filename == nil || mediaItem.filename?.isEmpty == true {
            mediaItem.filename = generateUniqueFilename(for: mediaItem)
        }
        
        // Content-Type bestimmen
        let contentType = determineContentType(for: mediaItem)
        
        // Datei hochladen
        let objectName = try await minioClient.uploadFile(data: mediaData, filename: mediaItem.filename!, contentType: contentType)
        
        // ObjectName im MediaItem speichern
        mediaItem.objectName = objectName
        
        // Lokale Daten löschen, wenn gewünscht
        if settings.deleteLocalMediaAfterUpload {
            mediaItem.mediaData = nil
        }
        
        // Änderungen speichern
        if context.hasChanges {
            try context.save()
        }
    }
    
    /// Lädt ein MediaItem herunter
    /// - Parameters:
    ///   - mediaItem: Das herunterzuladende MediaItem
    ///   - context: Der NSManagedObjectContext
    func downloadMediaItem(_ mediaItem: MediaItem, context: NSManagedObjectContext) async throws {
        guard let objectName = mediaItem.objectName, !objectName.isEmpty else {
            throw NSError(domain: "MediaSyncManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Kein Objektname zum Herunterladen vorhanden"])
        }
        
        // Datei herunterladen
        let data = try await downloadMedia(objectName: objectName)
        
        // Daten im MediaItem speichern
        mediaItem.mediaData = data
        
        // Änderungen speichern
        if context.hasChanges {
            try context.save()
        }
    }
    
    /// Lädt Mediendaten herunter
    /// - Parameter objectName: Der Objektname der Datei
    /// - Returns: Die heruntergeladenen Daten
    func downloadMedia(objectName: String) async throws -> Data {
        return try await minioClient.downloadFile(objectName: objectName)
    }
    
    /// Generiert einen eindeutigen Dateinamen für ein MediaItem
    /// - Parameter mediaItem: Das MediaItem
    /// - Returns: Ein eindeutiger Dateiname
    func generateUniqueFilename(for mediaItem: MediaItem) -> String {
        let uuid = UUID().uuidString
        let fileExtension = determineFileExtension(for: mediaItem)
        return "\(uuid).\(fileExtension)"
    }
    
    /// Bestimmt die Dateiendung für ein MediaItem
    /// - Parameter mediaItem: Das MediaItem
    /// - Returns: Die Dateiendung
    private func determineFileExtension(for mediaItem: MediaItem) -> String {
        if let filename = mediaItem.filename, !filename.isEmpty {
            let components = filename.components(separatedBy: ".")
            if components.count > 1, let extension = components.last {
                return `extension`
            }
        }
        
        // Fallback basierend auf dem Medientyp
        switch mediaItem.mediaType {
        case "photo":
            return "jpg"
        case "video":
            return "mp4"
        default:
            return "dat"
        }
    }
    
    /// Bestimmt den Content-Type für ein MediaItem
    /// - Parameter mediaItem: Das MediaItem
    /// - Returns: Der Content-Type
    private func determineContentType(for mediaItem: MediaItem) -> String {
        switch mediaItem.mediaType {
        case "photo":
            return "image/jpeg"
        case "video":
            return "video/mp4"
        default:
            return "application/octet-stream"
        }
    }
} 