//
//  MediaItem+Extensions.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import Foundation
import UIKit
import AVFoundation
import AVKit
import CoreData

// MARK: - MediaType Enumeration

enum MediaType: String, CaseIterable {
    case photo = "photo"
    case video = "video"
    
    var displayName: String {
        switch self {
        case .photo:
            return "Foto"
        case .video:
            return "Video"
        }
    }
    
    var iconName: String {
        switch self {
        case .photo:
            return "photo"
        case .video:
            return "video"
        }
    }
    
    var maxFileSize: Int64 {
        switch self {
        case .photo:
            return 10 * 1024 * 1024 // 10 MB
        case .video:
            return 100 * 1024 * 1024 // 100 MB
        }
    }
}

// MARK: - MediaItem Core Data Extensions

extension MediaItem {
    
    var mediaTypeEnum: MediaType? {
        get {
            guard let mediaType = mediaType else { return nil }
            return MediaType(rawValue: mediaType)
        }
        set {
            mediaType = newValue?.rawValue
        }
    }
    
    var displayName: String {
        return filename ?? "Unbenanntes Medium"
    }
    
    var formattedFileSize: String {
        let bytes = filesize
        
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
    
    var formattedDuration: String? {
        guard mediaTypeEnum == .video && duration > 0 else { return nil }
        
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var isVideo: Bool {
        return mediaTypeEnum == .video
    }
    
    var isPhoto: Bool {
        return mediaTypeEnum == .photo
    }
    
    var thumbnail: UIImage? {
        if let thumbnailData = thumbnailData {
            return UIImage(data: thumbnailData)
        }
        
        // Fallback: Erstelle Thumbnail für Fotos
        if isPhoto, let mediaData = mediaData {
            return UIImage(data: mediaData)
        }
        
        return nil
    }
    
    var fullImage: UIImage? {
        guard isPhoto, let mediaData = mediaData else { return nil }
        return UIImage(data: mediaData)
    }
    
    // MARK: - Factory Methods
    
    static func createPhoto(
        from image: UIImage,
        in context: NSManagedObjectContext,
        order: Int16 = 0
    ) -> MediaItem? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let mediaItem = MediaItem(context: context)
        mediaItem.mediaData = imageData
        mediaItem.mediaTypeEnum = .photo
        mediaItem.timestamp = Date()
        mediaItem.order = order
        mediaItem.filename = "Foto_\(Date().timeIntervalSince1970).jpg"
        mediaItem.filesize = Int64(imageData.count)
        
        // Erstelle Thumbnail
        let thumbnailImage = image.resized(to: CGSize(width: 150, height: 150))
        mediaItem.thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.7)
        
        return mediaItem
    }
    
    static func createVideo(
        from videoData: Data,
        in context: NSManagedObjectContext,
        order: Int16 = 0
    ) async -> MediaItem? {
        let mediaItem = MediaItem(context: context)
        mediaItem.mediaData = videoData
        mediaItem.mediaTypeEnum = .video
        mediaItem.timestamp = Date()
        mediaItem.order = order
        mediaItem.filename = "Video_\(Date().timeIntervalSince1970).mov"
        mediaItem.filesize = Int64(videoData.count)
        
        // Video-Dauer und Thumbnail aus Daten extrahieren
        if let (duration, thumbnail) = await extractVideoMetadata(from: videoData) {
            mediaItem.duration = duration
            mediaItem.thumbnailData = thumbnail.jpegData(compressionQuality: 0.7)
        }
        
        return mediaItem
    }
    
    // MARK: - Ultra-optimierte asynchrone Version für native Kamera
    
    static func createVideoAsync(
        from videoData: Data,
        in context: NSManagedObjectContext,
        order: Int16 = 0
    ) -> MediaItem? {
        let mediaItem = MediaItem(context: context)
        mediaItem.mediaData = videoData
        mediaItem.mediaTypeEnum = .video
        mediaItem.timestamp = Date()
        mediaItem.order = order
        mediaItem.filename = "Video_\(Date().timeIntervalSince1970).mov"
        mediaItem.filesize = Int64(videoData.count)
        
        // Thumbnail und Dauer werden ultra-optimiert asynchron im Hintergrund erstellt
        Task.detached(priority: .userInitiated) {  // Höhere Priorität für bessere UX
            if let (duration, thumbnail) = await extractVideoMetadataAsync(from: videoData) {
                await MainActor.run {
                    mediaItem.duration = duration
                    mediaItem.thumbnailData = thumbnail.jpegData(compressionQuality: 0.7)
                    
                    // Core Data Context speichern (thread-safe)
                    do {
                        try context.save()
                        print("✅ Video-Metadaten ultra-optimiert geladen: \(String(format: "%.1f", duration))s")
                    } catch {
                        print("❌ Fehler beim Speichern der Video-Metadaten: \(error)")
                    }
                }
            } else {
                print("⚠️ Video-Metadaten konnten nicht extrahiert werden - Video ohne Thumbnail gespeichert")
            }
        }
        
        return mediaItem
    }
    
    // MARK: - Ultra-optimierte asynchrone Video-Metadaten-Extraktion
    
    private static func extractVideoMetadataAsync(from data: Data) async -> (duration: Double, thumbnail: UIImage)? {
        // Temporäre Datei erstellen (schnell, kein I/O-Block)
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        do {
            // Schnelles Schreiben der temporären Datei
            try data.write(to: tempURL)
            defer { 
                // Automatisches Cleanup
                try? FileManager.default.removeItem(at: tempURL) 
            }
            
            // Moderne async/await AVAsset-API mit Timeout-Schutz
            let asset = AVURLAsset(url: tempURL)
            
            // Parallele Ausführung mit Timeout-Schutz
            let result = try await withThrowingTaskGroup(of: (Double, UIImage?).self) { group in
                
                // Task 1: Dauer laden (mit Timeout)
                group.addTask {
                    let duration = try await withTimeout(seconds: 3.0) {
                        let durationValue = try await asset.load(.duration)
                        return CMTimeGetSeconds(durationValue)
                    }
                    return (duration, nil)
                }
                
                // Task 2: Thumbnail erstellen (mit Timeout)
                group.addTask {
                    let thumbnail = try await withTimeout(seconds: 5.0) {
                        // Prüfe Asset-Verfügbarkeit
                        guard try await asset.load(.isReadable) else {
                            throw VideoMetadataError.assetNotReadable
                        }
                        
                        // Thumbnail-Generator (optimiert)
                        let imageGenerator = AVAssetImageGenerator(asset: asset)
                        imageGenerator.appliesPreferredTrackTransform = true
                        imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
                        imageGenerator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)
                        
                        // Optimaler Zeitpunkt für Thumbnail
                        let thumbnailTime = CMTime(seconds: 0.5, preferredTimescale: 600)
                        
                        // Asynchrone Thumbnail-Generierung mit Continuation
                        return try await withCheckedThrowingContinuation { continuation in
                            imageGenerator.generateCGImageAsynchronously(for: thumbnailTime) { cgImage, actualTime, error in
                                if let cgImage = cgImage {
                                    let thumbnail = UIImage(cgImage: cgImage)
                                    continuation.resume(returning: thumbnail)
                                } else {
                                    continuation.resume(throwing: error ?? VideoMetadataError.thumbnailCreationFailed)
                                }
                            }
                        }
                    }
                    return (0.0, thumbnail)
                }
                
                // Sammle Ergebnisse
                var duration: Double = 0.0
                var thumbnail: UIImage?
                
                for try await result in group {
                    if result.0 > 0 {
                        duration = result.0
                    }
                    if let thumb = result.1 {
                        thumbnail = thumb
                    }
                }
                
                return (duration, thumbnail)
            }
            
            guard let thumbnail = result.1 else {
                print("❌ Thumbnail-Erstellung fehlgeschlagen")
                return nil
            }
            
            print("✅ Video-Metadaten ultra-optimiert extrahiert:")
            print("   Dauer: \(String(format: "%.1f", result.0))s")
            print("   Thumbnail: \(thumbnail.size)")
            
            return (result.0, thumbnail)
            
        } catch {
            print("❌ Fehler bei ultra-optimierter Video-Metadaten-Extraktion: \(error)")
            return nil
        }
    }
    
    // MARK: - Timeout-Hilfsfunktion
    
    private static func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Haupt-Operation
            group.addTask {
                try await operation()
            }
            
            // Timeout-Task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw VideoMetadataError.timeout
            }
            
            // Erstes Ergebnis gewinnt
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Fehler-Enum
    
    private enum VideoMetadataError: Error {
        case timeout
        case assetNotReadable
        case thumbnailCreationFailed
        
        var localizedDescription: String {
            switch self {
            case .timeout:
                return "Timeout bei Video-Metadaten-Extraktion"
            case .assetNotReadable:
                return "Video-Asset nicht lesbar"
            case .thumbnailCreationFailed:
                return "Thumbnail-Erstellung fehlgeschlagen"
            }
        }
    }
    
    // MARK: - Fallback asynchrone Methode (für Kompatibilität)
    
    private static func extractVideoMetadata(from data: Data) async -> (duration: Double, thumbnail: UIImage)? {
        // Moderne asynchrone Implementierung als Fallback
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        do {
            try data.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            
            let asset = AVURLAsset(url: tempURL)
            
            // Verwende moderne load(.duration) API statt deprecated duration Property
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: min(1.0, durationSeconds / 2), preferredTimescale: 600)
            
            // Verwende moderne async API statt deprecated copyCGImage
            let cgImage = try await imageGenerator.image(at: time).image
            let thumbnail = UIImage(cgImage: cgImage)
            return (durationSeconds, thumbnail)
            
        } catch {
            print("❌ Fehler bei Fallback-Video-Metadaten-Extraktion: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Debug Functions
    
    func debugDescription() -> String {
        return """
        MediaItem Debug Info:
        - ID: \(objectID)
        - Filename: \(filename ?? "Unbekannt")
        - MediaType: \(mediaType ?? "Unbekannt")
        - FileSize: \(filesize) bytes (\(formattedFileSize))
        - Duration: \(duration)s
        - Order: \(order)
        - Timestamp: \(timestamp?.formatted() ?? "Unbekannt")
        - Hat MediaData: \(mediaData != nil)
        - MediaData Größe: \(mediaData?.count ?? 0) bytes
        - Hat ThumbnailData: \(thumbnailData != nil)
        - ThumbnailData Größe: \(thumbnailData?.count ?? 0) bytes
        - IsVideo: \(isVideo)
        - IsPhoto: \(isPhoto)
        """
    }
    
    func validateData() -> [String] {
        var issues: [String] = []
        
        if mediaType == nil {
            issues.append("MediaType ist nil")
        }
        
        if mediaData == nil {
            issues.append("MediaData ist nil")
        }
        
        if isVideo && duration <= 0 {
            issues.append("Video hat keine gültige Dauer")
        }
        
        if thumbnailData == nil {
            issues.append("ThumbnailData ist nil")
        }
        
        if filename == nil || filename?.isEmpty == true {
            issues.append("Filename ist leer oder nil")
        }
        
        return issues
    }
}



// MARK: - Memory Extensions for Media

extension Memory {
    var sortedMediaItems: [MediaItem] {
        let items = mediaItems?.allObjects as? [MediaItem] ?? []
        return items.sorted { $0.order < $1.order }
    }
    
    var photoCount: Int {
        return sortedMediaItems.filter { $0.isPhoto }.count
    }
    
    var videoCount: Int {
        return sortedMediaItems.filter { $0.isVideo }.count
    }
    
    var hasMedia: Bool {
        return !(mediaItems?.allObjects.isEmpty ?? true)
    }
    
    func addMediaItem(_ item: MediaItem) {
        let currentItems = mediaItems?.allObjects as? [MediaItem] ?? []
        item.order = Int16(currentItems.count)
        
        let mutableItems = mutableSetValue(forKey: "mediaItems")
        mutableItems.add(item)
    }
    
    func removeMediaItem(_ item: MediaItem) {
        let mutableItems = mutableSetValue(forKey: "mediaItems")
        mutableItems.remove(item)
        
        // Neuordnung der verbleibenden Items
        let remaining = sortedMediaItems.filter { $0 != item }
        for (index, mediaItem) in remaining.enumerated() {
            mediaItem.order = Int16(index)
        }
    }
    
    func reorderMediaItems(_ items: [MediaItem]) {
        for (index, item) in items.enumerated() {
            item.order = Int16(index)
        }
    }
}
