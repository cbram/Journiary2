//
//  GraphQLMediaService.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine
import UIKit

/// GraphQL Media Service - Demo Mode Implementation
/// Vereinfachte Version die ohne komplexe Apollo Code-Generation funktioniert
class GraphQLMediaService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var uploadProgress: [String: Double] = [:]
    @Published var downloadProgress: [String: Double] = [:]
    @Published var isUploading = false
    @Published var isDownloading = false
    
    // MARK: - Private Properties
    
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Demo Mode
    
    private var isDemoMode: Bool {
        return AppSettings.shared.backendURL.contains("localhost") ||
               AppSettings.shared.backendURL.contains("127.0.0.1")
    }
    
    // MARK: - Media Upload
    
    /// MediaItem hochladen (vereinfacht für Demo)
    /// - Parameters:
    ///   - data: Datei-Daten
    ///   - filename: Dateiname
    ///   - mimeType: MIME-Type
    ///   - memoryId: Optional Memory ID
    /// - Returns: Publisher mit MediaItemDTO
    func uploadMedia(
        data: Data,
        filename: String,
        mimeType: String,
        memoryId: String? = nil
    ) -> AnyPublisher<MediaItemDTO, GraphQLError> {
        
        if isDemoMode {
            return createDemoMediaItem(
                filename: filename,
                mimeType: mimeType,
                fileSize: data.count,
                memoryId: memoryId
            )
        }
        
        // Echte Implementation würde hier stehen
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    /// UIImage hochladen
    /// - Parameters:
    ///   - image: UIImage
    ///   - filename: Dateiname
    ///   - quality: JPEG Qualität (0.0 - 1.0)
    ///   - memoryId: Optional Memory ID
    /// - Returns: Publisher mit MediaItemDTO
    func uploadImage(
        _ image: UIImage,
        filename: String,
        quality: CGFloat = 0.8,
        memoryId: String? = nil
    ) -> AnyPublisher<MediaItemDTO, GraphQLError> {
        
        guard let imageData = image.jpegData(compressionQuality: quality) else {
            return Fail(error: GraphQLError.unknown("Bild konnte nicht konvertiert werden"))
                .eraseToAnyPublisher()
        }
        
        let mimeType = "image/jpeg"
        let finalFilename = filename.hasSuffix(".jpg") ? filename : "\(filename).jpg"
        
        return uploadMedia(
            data: imageData,
            filename: finalFilename,
            mimeType: mimeType,
            memoryId: memoryId
        )
    }
    
    // MARK: - Media Download
    
    /// MediaItem herunterladen
    /// - Parameter mediaItem: MediaItemDTO
    /// - Returns: Publisher mit Datei-Daten
    func downloadMedia(mediaItem: MediaItemDTO) -> AnyPublisher<Data, GraphQLError> {
        
        if isDemoMode {
            return createDemoImageData()
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    // MARK: - Delete Operations
    
    /// MediaItem löschen
    /// - Parameter id: MediaItem ID
    /// - Returns: Publisher mit Bool (Erfolg)
    func deleteMediaItem(id: String) -> AnyPublisher<Bool, GraphQLError> {
        
        if isDemoMode {
            return Just(true)
                .setFailureType(to: GraphQLError.self)
                .eraseToAnyPublisher()
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    // MARK: - Demo Mode Implementations
    
    private func createDemoMediaItem(
        filename: String,
        mimeType: String,
        fileSize: Int,
        memoryId: String? = nil
    ) -> AnyPublisher<MediaItemDTO, GraphQLError> {
        
        return Future { promise in
            // Simuliere Upload-Delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: DispatchWorkItem {
                // Demo MediaItem erstellen
                let mediaItem = MediaItemDTO(
                    id: UUID().uuidString,
                    filename: filename,
                    mimeType: mimeType,
                    fileSize: fileSize,
                    duration: mimeType.contains("video") ? 30.0 : nil,
                    memoryId: memoryId,
                    userId: "demo-user",
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                promise(.success(mediaItem))
            })
        }
        .eraseToAnyPublisher()
    }
    
    private func createDemoImageData() -> AnyPublisher<Data, GraphQLError> {
        return Future { promise in
            // Erstelle ein einfaches Demo-Bild
            let size = CGSize(width: 100, height: 100)
            UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
            
            UIColor.blue.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let imageData = image?.jpegData(compressionQuality: 0.8) {
                promise(.success(imageData))
            } else {
                promise(.failure(.unknown("Demo-Bild konnte nicht erstellt werden")))
            }
        }
        .eraseToAnyPublisher()
    }
}

 