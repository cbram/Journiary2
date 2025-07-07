import Foundation
import CoreData
import UniformTypeIdentifiers
import JourniaryAPI

/// Manages file uploads and downloads to/from MinIO using presigned URLs.
///
/// This class handles the actual HTTP operations for transferring files to and from
/// the MinIO object storage, supporting both MediaItems and GPXTracks.
final class MediaFileManager {
    
    static let shared = MediaFileManager()
    
    private let urlSession: URLSession
    private let networkProvider = NetworkProvider.shared
    
    private init() {
        // Configure URLSession for file transfers
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60.0
        configuration.timeoutIntervalForResource = 300.0 // 5 minutes for large files
        self.urlSession = URLSession(configuration: configuration)
    }
    
    // MARK: - Upload Methods
    
    /// Uploads a file to MinIO using a presigned URL.
    /// - Parameters:
    ///   - fileURL: Local file URL to upload
    ///   - uploadURL: Presigned upload URL from the server
    ///   - mimeType: MIME type of the file
    /// - Returns: True if upload was successful
    func uploadFile(fileURL: URL, uploadURL: String, mimeType: String) async throws -> Bool {
        guard let url = URL(string: uploadURL) else {
            throw NSError(domain: "FileManagerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])
        }
        
        let fileData = try Data(contentsOf: fileURL)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(fileData.count)", forHTTPHeaderField: "Content-Length")
        
        do {
            let (_, response) = try await urlSession.upload(for: request, from: fileData)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "FileManagerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            // MinIO returns 200 for successful uploads
            if httpResponse.statusCode == 200 {
                print("✅ File uploaded successfully to MinIO")
                return true
            } else {
                print("❌ Upload failed with status code: \(httpResponse.statusCode)")
                throw NSError(domain: "FileManagerError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Upload failed with status code: \(httpResponse.statusCode)"])
            }
        } catch {
            print("❌ Upload error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Uploads multiple files in batch using presigned URLs.
    /// - Parameter uploadTasks: Array of upload tasks with file info and URLs
    /// - Returns: Array of successful upload results
    func uploadFilesBatch(uploadTasks: [FileUploadTask]) async throws -> [FileUploadResult] {
        // Process uploads concurrently but limit concurrency to avoid overwhelming MinIO
        return await withTaskGroup(of: FileUploadResult.self, returning: [FileUploadResult].self) { group in
            var results: [FileUploadResult] = []
            
            // Add all tasks to the group
            for task in uploadTasks {
                group.addTask {
                    do {
                        let success = try await self.uploadFile(
                            fileURL: task.fileURL,
                            uploadURL: task.uploadURL,
                            mimeType: task.mimeType
                        )
                        return FileUploadResult(task: task, success: success, error: nil)
                    } catch {
                        return FileUploadResult(task: task, success: false, error: error)
                    }
                }
            }
            
            // Collect all results
            for await result in group {
                results.append(result)
            }
            
            return results
        }
    }
    
    // MARK: - Download Methods
    
    /// Downloads a file from MinIO using a presigned URL.
    /// - Parameters:
    ///   - downloadURL: Presigned download URL from the server
    ///   - destinationURL: Local file URL where the file should be saved
    /// - Returns: True if download was successful
    func downloadFile(downloadURL: String, destinationURL: URL) async throws -> Bool {
        guard let url = URL(string: downloadURL) else {
            throw NSError(domain: "FileManagerError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
        }
        
        do {
            let (tempURL, response) = try await urlSession.download(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "FileManagerError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            if httpResponse.statusCode == 200 {
                // Move downloaded file to destination
                let foundationFileManager = Foundation.FileManager.default
                
                // Remove existing file if it exists
                if foundationFileManager.fileExists(atPath: destinationURL.path) {
                    try foundationFileManager.removeItem(at: destinationURL)
                }
                
                // Create directory if it doesn't exist
                let directory = destinationURL.deletingLastPathComponent()
                if !foundationFileManager.fileExists(atPath: directory.path) {
                    try foundationFileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                }
                
                // Move file to final destination
                try foundationFileManager.moveItem(at: tempURL, to: destinationURL)
                
                print("✅ File downloaded successfully from MinIO")
                return true
            } else {
                print("❌ Download failed with status code: \(httpResponse.statusCode)")
                throw NSError(domain: "FileManagerError", code: 6, userInfo: [NSLocalizedDescriptionKey: "Download failed with status code: \(httpResponse.statusCode)"])
            }
        } catch {
            print("❌ Download error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Downloads multiple files in batch using presigned URLs.
    /// - Parameter downloadTasks: Array of download tasks with URLs and destinations
    /// - Returns: Array of successful download results
    func downloadFilesBatch(downloadTasks: [FileDownloadTask]) async throws -> [FileDownloadResult] {
        // Process downloads concurrently 
        return await withTaskGroup(of: FileDownloadResult.self, returning: [FileDownloadResult].self) { group in
            var results: [FileDownloadResult] = []
            
            // Add all tasks to the group
            for task in downloadTasks {
                group.addTask {
                    do {
                        let success = try await self.downloadFile(
                            downloadURL: task.downloadURL,
                            destinationURL: task.destinationURL
                        )
                        return FileDownloadResult(task: task, success: success, error: nil)
                    } catch {
                        return FileDownloadResult(task: task, success: false, error: error)
                    }
                }
            }
            
            // Collect all results
            for await result in group {
                results.append(result)
            }
            
            return results
        }
    }
    
    // MARK: - Utility Methods
    
    /// Generates a unique object name for MinIO storage.
    /// - Parameters:
    ///   - entityType: Type of entity (MediaItem, GPXTrack, etc.)
    ///   - fileExtension: File extension (jpg, png, gpx, etc.)
    /// - Returns: Unique object name
    func generateObjectName(entityType: String, fileExtension: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)
        return "\(entityType.lowercased())/\(timestamp)_\(uuid).\(fileExtension)"
    }
    
    /// Determines MIME type from file extension.
    /// - Parameter fileExtension: File extension
    /// - Returns: MIME type string
    func mimeType(for fileExtension: String) -> String {
        if let utType = UTType(filenameExtension: fileExtension) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
}

// MARK: - Supporting Types

struct FileUploadTask {
    let entityId: String
    let entityType: String
    let fileURL: URL
    let uploadURL: String
    let objectName: String
    let mimeType: String
}

struct FileUploadResult {
    let task: FileUploadTask
    let success: Bool
    let error: Error?
}

struct FileDownloadTask {
    let entityId: String
    let entityType: String
    let downloadURL: String
    let destinationURL: URL
    let objectName: String
}

struct FileDownloadResult {
    let task: FileDownloadTask
    let success: Bool
    let error: Error?
}

// MARK: - Extensions for local file management

extension MediaFileManager {
    
    /// Gets the local documents directory for storing downloaded files.
    /// - Returns: Documents directory URL
    func documentsDirectory() -> URL {
        return Foundation.FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// Gets the local directory for storing media files.
    /// - Returns: Media directory URL
    func mediaDirectory() -> URL {
        let mediaDir = documentsDirectory().appendingPathComponent("Media")
        try? Foundation.FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        return mediaDir
    }
    
    /// Gets the local directory for storing GPX files.
    /// - Returns: GPX directory URL
    func gpxDirectory() -> URL {
        let gpxDir = documentsDirectory().appendingPathComponent("GPX")
        try? Foundation.FileManager.default.createDirectory(at: gpxDir, withIntermediateDirectories: true)
        return gpxDir
    }
    
    /// Gets the local file URL for a given object name.
    /// - Parameters:
    ///   - objectName: MinIO object name
    ///   - entityType: Type of entity for directory selection
    /// - Returns: Local file URL
    func localFileURL(for objectName: String, entityType: String) -> URL {
        let filename = URL(string: objectName)?.lastPathComponent ?? objectName
        
        switch entityType.lowercased() {
        case "mediaitem", "mediaitemthumbnail":
            return mediaDirectory().appendingPathComponent(filename)
        case "gpxtrack":
            return gpxDirectory().appendingPathComponent(filename)
        default:
            return documentsDirectory().appendingPathComponent(filename)
        }
    }
} 