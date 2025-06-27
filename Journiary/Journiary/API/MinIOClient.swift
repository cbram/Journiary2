//
//  MinIOClient.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import Combine

/// Client für die Interaktion mit dem MinIO-Server
class MinIOClient: ObservableObject {
    static let shared = MinIOClient()
    
    @Published var isConfigured: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var baseURL: URL? {
        guard let serverURL = settings.backendURL else { return nil }
        return URL(string: serverURL)
    }
    
    private var apiURL: URL? {
        guard let baseURL = baseURL else { return nil }
        return baseURL.appendingPathComponent("api")
    }
    
    private var minioURL: URL? {
        guard let baseURL = baseURL else { return nil }
        return baseURL.appendingPathComponent("minio")
    }
    
    private var accessKey: String {
        return settings.backendUsername
    }
    
    private var secretKey: String {
        return settings.backendPassword
    }
    
    private var bucketName: String {
        return "journiary"
    }
    
    enum ConnectionStatus {
        case connected
        case disconnected
        case error(Error)
    }
    
    private init() {
        // Beobachte Änderungen an den Backend-Einstellungen
        settings.$backendURL
            .combineLatest(settings.$backendUsername, settings.$backendPassword)
            .sink { [weak self] _, _, _ in
                self?.checkConfiguration()
            }
            .store(in: &cancellables)
        
        // Prüfe die Konfiguration beim Start
        checkConfiguration()
    }
    
    /// Prüft, ob der Client konfiguriert ist
    private func checkConfiguration() {
        isConfigured = baseURL != nil && !accessKey.isEmpty && !secretKey.isEmpty
        
        if isConfigured {
            checkConnection()
        } else {
            connectionStatus = .disconnected
        }
    }
    
    /// Prüft die Verbindung zum MinIO-Server
    private func checkConnection() {
        guard isConfigured, let apiURL = apiURL else {
            connectionStatus = .disconnected
            return
        }
        
        let url = apiURL.appendingPathComponent("health")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.connectionStatus = .error(error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.connectionStatus = .disconnected
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    self?.connectionStatus = .connected
                } else {
                    self?.connectionStatus = .error(NSError(domain: "MinIOClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"]))
                }
            }
        }.resume()
    }
    
    /// Lädt eine Datei auf den MinIO-Server hoch
    /// - Parameters:
    ///   - data: Die hochzuladenden Daten
    ///   - filename: Der Dateiname
    ///   - contentType: Der Content-Type der Datei
    /// - Returns: Der Objektname der hochgeladenen Datei
    func uploadFile(data: Data, filename: String, contentType: String) async throws -> String {
        guard isConfigured, let apiURL = apiURL else {
            throw NSError(domain: "MinIOClient", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Client ist nicht konfiguriert"])
        }
        
        // Generiere einen eindeutigen Objektnamen
        let objectName = "\(UUID().uuidString)-\(filename)"
        
        // Hole eine Presigned-URL zum Hochladen
        let presignedURL = try await getPresignedURL(for: objectName, operation: .upload, contentType: contentType)
        
        // Führe den Upload durch
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "MinIOClient", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Upload fehlgeschlagen"])
        }
        
        return objectName
    }
    
    /// Lädt eine Datei vom MinIO-Server herunter
    /// - Parameter objectName: Der Objektname der Datei
    /// - Returns: Die heruntergeladenen Daten
    func downloadFile(objectName: String) async throws -> Data {
        guard isConfigured, let apiURL = apiURL else {
            throw NSError(domain: "MinIOClient", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Client ist nicht konfiguriert"])
        }
        
        // Hole eine Presigned-URL zum Herunterladen
        let presignedURL = try await getPresignedURL(for: objectName, operation: .download)
        
        // Führe den Download durch
        let (data, response) = try await URLSession.shared.data(from: presignedURL)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "MinIOClient", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Download fehlgeschlagen"])
        }
        
        return data
    }
    
    /// Löscht eine Datei vom MinIO-Server
    /// - Parameter objectName: Der Objektname der Datei
    func deleteFile(objectName: String) async throws {
        guard isConfigured, let apiURL = apiURL else {
            throw NSError(domain: "MinIOClient", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Client ist nicht konfiguriert"])
        }
        
        // Hole eine Presigned-URL zum Löschen
        let presignedURL = try await getPresignedURL(for: objectName, operation: .delete)
        
        // Führe den Löschvorgang durch
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
            throw NSError(domain: "MinIOClient", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Löschen fehlgeschlagen"])
        }
    }
    
    /// Holt eine Presigned-URL für eine Operation
    /// - Parameters:
    ///   - objectName: Der Objektname der Datei
    ///   - operation: Die durchzuführende Operation
    ///   - contentType: Der Content-Type der Datei (nur für Upload relevant)
    /// - Returns: Die Presigned-URL
    private func getPresignedURL(for objectName: String, operation: PresignedURLOperation, contentType: String = "application/octet-stream") async throws -> URL {
        guard isConfigured, let apiURL = apiURL else {
            throw NSError(domain: "MinIOClient", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Client ist nicht konfiguriert"])
        }
        
        let url = apiURL.appendingPathComponent("presigned-url")
        
        // Erstelle die Request-Daten
        var requestData: [String: Any] = [
            "bucket": bucketName,
            "objectName": objectName,
            "operation": operation.rawValue
        ]
        
        if operation == .upload {
            requestData["contentType"] = contentType
        }
        
        // Erstelle die Request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
        
        // Führe die Request aus
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "MinIOClient", code: 1005, userInfo: [NSLocalizedDescriptionKey: "Fehler beim Abrufen der Presigned-URL"])
        }
        
        // Dekodiere die Antwort
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlString = json["url"] as? String,
              let presignedURL = URL(string: urlString) else {
            throw NSError(domain: "MinIOClient", code: 1006, userInfo: [NSLocalizedDescriptionKey: "Ungültige Antwort vom Server"])
        }
        
        return presignedURL
    }
    
    /// Operationen für Presigned-URLs
    enum PresignedURLOperation: String {
        case upload = "PUT"
        case download = "GET"
        case delete = "DELETE"
    }
} 