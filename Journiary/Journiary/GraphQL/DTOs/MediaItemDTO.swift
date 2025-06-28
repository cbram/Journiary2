//
//  MediaItemDTO.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import CoreData

/// MediaItem Data Transfer Object - Vereinfachte Version ohne Apollo
/// Für Datenübertragung zwischen Core Data und Demo GraphQL Service
struct MediaItemDTO {
    let id: String
    let filename: String
    let mimeType: String
    let fileSize: Int
    let width: Int?
    let height: Int?
    let duration: Double?
    let memoryId: String?
    // tripId entfernt - MediaItem hat keine direkte Trip-Beziehung
    let userId: String
    let createdAt: Date
    let updatedAt: Date
    
    // MARK: - Computed Properties
    
    /// Prüft ob es sich um ein Bild handelt
    var isImage: Bool {
        return mimeType.hasPrefix("image/")
    }
    
    /// Prüft ob es sich um ein Video handelt
    var isVideo: Bool {
        return mimeType.hasPrefix("video/")
    }
    
    /// Formatierte Dateigröße
    var formattedFileSize: String {
        let bytes = fileSize
        
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
    
    /// Formatierte Dauer für Videos
    var formattedDuration: String? {
        guard let duration = duration, duration > 0 else { return nil }
        
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Initializers
    
    /// Standard Initializer für alle Properties
    init(
        id: String,
        filename: String,
        mimeType: String,
        fileSize: Int,
        width: Int? = nil,
        height: Int? = nil,
        duration: Double? = nil,
        memoryId: String? = nil,
        userId: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.duration = duration
        self.memoryId = memoryId
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Core Data Integration
    
    /// Erstelle MediaItemDTO aus Core Data MediaItem
    init?(from coreDataMedia: MediaItem) {
        // Da Core Data MediaItem kein id hat, generieren wir eine
        let id = UUID().uuidString
        guard let filename = coreDataMedia.filename else {
            return nil
        }
        
        self.id = id
        self.filename = filename
        // Best-guess für MIME Type basierend auf Dateiendung
        if let ext = filename.split(separator: ".").last?.lowercased() {
            switch ext {
            case "jpg", "jpeg":
                self.mimeType = "image/jpeg"
            case "png":
                self.mimeType = "image/png"
            case "mov", "mp4":
                self.mimeType = "video/mp4"
            default:
                self.mimeType = "application/octet-stream"
            }
        } else {
            self.mimeType = "application/octet-stream"
        }
        
        self.fileSize = Int(coreDataMedia.filesize)
        self.width = nil // Core Data hat keine width/height
        self.height = nil
        self.duration = coreDataMedia.duration > 0 ? coreDataMedia.duration : nil
        // Memory ID extrahieren  
        if let memory = coreDataMedia.memory {
            self.memoryId = memory.objectID.uriRepresentation().absoluteString
        } else {
            self.memoryId = nil
        }
        self.userId = "demo-user" // Demo Mode
        self.createdAt = coreDataMedia.timestamp ?? Date()
        self.updatedAt = Date()
    }
    
    /// Speichere in Core Data (für Demo Mode)
    func toCoreData(context: NSManagedObjectContext) throws -> MediaItem {
        // Prüfe ob MediaItem bereits existiert
        let request: NSFetchRequest<MediaItem> = MediaItem.fetchRequest()
        if let uuidID = UUID(uuidString: id) {
            request.predicate = NSPredicate(format: "id == %@", uuidID as CVarArg)
        } else {
            request.predicate = NSPredicate(format: "filename == %@", filename)
        }
        
        let mediaItem: MediaItem
        if let existingMedia = try? context.fetch(request).first {
            mediaItem = existingMedia
        } else {
            mediaItem = MediaItem(context: context)
            // MediaItem hat kein id Property in Core Data
        }
        
        // Daten aktualisieren
        mediaItem.filename = filename
        mediaItem.filesize = Int64(fileSize)
        mediaItem.timestamp = createdAt
        
        if let duration = duration {
            mediaItem.duration = duration
        }
        
        // Media Type setzen
        if isImage {
            mediaItem.mediaType = "photo"
        } else if isVideo {
            mediaItem.mediaType = "video"
        }
        
        return mediaItem
    }
}

// MARK: - Response DTOs

/// Presigned Upload URL DTO für Demo Mode
struct PresignedUploadURLDTO {
    let uploadUrl: String
    let fields: [String: String]
    let key: String
    
    init(uploadUrl: String, fields: [String: String] = [:], key: String) {
        self.uploadUrl = uploadUrl
        self.fields = fields
        self.key = key
    }
}

/// Presigned Download URL DTO für Demo Mode
struct PresignedDownloadURLDTO {
    let downloadUrl: String
    let expiresAt: Date
    
    init(downloadUrl: String, expiresAt: Date = Date().addingTimeInterval(3600)) {
        self.downloadUrl = downloadUrl
        self.expiresAt = expiresAt
    }
}

// MARK: - MIME Type Helper

extension MediaItemDTO {
    /// MIME Type aus Datei-Extension ermitteln
    /// - Parameter filename: Dateiname
    /// - Returns: MIME Type String
    static func mimeType(for filename: String) -> String {
        let pathExtension = (filename as NSString).pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "pdf":
            return "application/pdf"
        default:
            return "application/octet-stream"
        }
    }
} 