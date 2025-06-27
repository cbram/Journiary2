//
//  APIClient.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation

/// Fehlertypen, die bei API-Anfragen auftreten können
enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case unauthorized
    case serverError(Int)
    case unknownError
    case noData
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Ungültige URL"
        case .networkError(let error):
            return "Netzwerkfehler: \(error.localizedDescription)"
        case .invalidResponse:
            return "Ungültige Antwort vom Server"
        case .decodingError(let error):
            return "Fehler beim Dekodieren der Daten: \(error.localizedDescription)"
        case .unauthorized:
            return "Nicht autorisiert. Bitte melde dich erneut an."
        case .serverError(let code):
            return "Serverfehler: \(code)"
        case .unknownError:
            return "Unbekannter Fehler"
        case .noData:
            return "Keine Daten empfangen"
        }
    }
}

/// Hauptklasse für die Kommunikation mit dem GraphQL-Backend
class APIClient {
    static let shared = APIClient()
    
    private init() {}
    
    private var serverURL: URL? {
        URL(string: AppSettings.shared.backendURL)
    }
    
    private var authToken: String? {
        AppSettings.shared.authToken
    }
    
    // MARK: - Helper Methods
    
    private func createRequest(query: String, variables: [String: Any]? = nil) -> URLRequest? {
        guard let url = serverURL else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = ["query": query]
        if let variables = variables {
            body["variables"] = variables
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            return request
        } catch {
            print("❌ Fehler beim Erstellen der Request: \(error)")
            return nil
        }
    }
    
    private func performRequest<T: Decodable>(query: String, variables: [String: Any]? = nil) async throws -> T {
        guard let request = createRequest(query: query, variables: variables) else {
            throw APIError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                // Erfolgreiche Antwort
                break
            case 401:
                throw APIError.unauthorized
            case 400...499:
                print("⚠️ Client-Fehler: \(httpResponse.statusCode)")
                break // Wir versuchen trotzdem zu parsen, da GraphQL Fehler im Body zurückgibt
            case 500...599:
                throw APIError.serverError(httpResponse.statusCode)
            default:
                throw APIError.unknownError
            }
            
            if AppSettings.shared.verboseLogging {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📥 API-Antwort: \(jsonString)")
                }
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            
            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Authentication
    
    /// Meldet einen Benutzer an
    /// - Parameters:
    ///   - email: E-Mail-Adresse des Benutzers
    ///   - password: Passwort des Benutzers
    /// - Returns: Die Antwort des Servers mit Token und Benutzer
    func login(email: String, password: String) async throws -> LoginResponse {
        let query = """
        mutation Login($email: String!, $password: String!) {
          login(input: { email: $email, password: $password }) {
            token
            user {
              id
              email
              createdAt
              updatedAt
            }
          }
        }
        """
        
        let variables: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        let response: GraphQLResponse<LoginData> = try await performRequest(query: query, variables: variables)
        
        if let errors = response.errors, !errors.isEmpty {
            throw APIError.serverError(400)
        }
        
        guard let loginData = response.data?.login else {
            throw APIError.noData
        }
        
        // Token speichern
        AppSettings.shared.authToken = loginData.token
        
        return loginData
    }
    
    /// Registriert einen neuen Benutzer
    /// - Parameters:
    ///   - email: E-Mail-Adresse des Benutzers
    ///   - password: Passwort des Benutzers
    /// - Returns: Die Antwort des Servers mit dem erstellten Benutzer
    func register(email: String, password: String) async throws -> User {
        let query = """
        mutation Register($email: String!, $password: String!) {
          register(input: { email: $email, password: $password }) {
            id
            email
            createdAt
            updatedAt
          }
        }
        """
        
        let variables: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        let response: GraphQLResponse<RegisterData> = try await performRequest(query: query, variables: variables)
        
        if let errors = response.errors, !errors.isEmpty {
            throw APIError.serverError(400)
        }
        
        guard let user = response.data?.register else {
            throw APIError.noData
        }
        
        return user
    }
    
    // MARK: - MinIO Presigned URLs
    
    /// Generiert eine vorzeichnete URL für den Upload einer Datei
    /// - Parameters:
    ///   - filename: Name der Datei
    ///   - contentType: MIME-Typ der Datei
    /// - Returns: Die vorzeichnete URL und den Objektnamen
    func getPresignedUploadURL(filename: String, contentType: String) async throws -> PresignedUrlResponse {
        let query = """
        mutation GetPresignedUploadUrl($filename: String!, $contentType: String!) {
          getPresignedUploadUrl(filename: $filename, contentType: $contentType) {
            url
            objectName
          }
        }
        """
        
        let variables: [String: Any] = [
            "filename": filename,
            "contentType": contentType
        ]
        
        let response: GraphQLResponse<PresignedUrlData> = try await performRequest(query: query, variables: variables)
        
        if let errors = response.errors, !errors.isEmpty {
            throw APIError.serverError(400)
        }
        
        guard let presignedUrl = response.data?.getPresignedUploadUrl else {
            throw APIError.noData
        }
        
        return presignedUrl
    }
    
    /// Generiert eine vorzeichnete URL für den Download einer Datei
    /// - Parameter objectName: Name des Objekts in MinIO
    /// - Returns: Die vorzeichnete URL
    func getPresignedDownloadURL(objectName: String) async throws -> String {
        let query = """
        query GetPresignedDownloadUrl($objectName: String!) {
          getPresignedDownloadUrl(objectName: $objectName)
        }
        """
        
        let variables: [String: Any] = [
            "objectName": objectName
        ]
        
        let response: GraphQLResponse<DownloadUrlData> = try await performRequest(query: query, variables: variables)
        
        if let errors = response.errors, !errors.isEmpty {
            throw APIError.serverError(400)
        }
        
        guard let url = response.data?.getPresignedDownloadUrl else {
            throw APIError.noData
        }
        
        return url
    }
}

// MARK: - Response Models

/// Allgemeine GraphQL-Antwortstruktur
struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

struct GraphQLError: Decodable {
    let message: String
    let locations: [GraphQLErrorLocation]?
    let path: [String]?
}

struct GraphQLErrorLocation: Decodable {
    let line: Int
    let column: Int
}

// Auth-Response-Modelle
struct LoginData: Decodable {
    let login: LoginResponse
}

struct LoginResponse: Decodable {
    let token: String
    let user: User
}

struct RegisterData: Decodable {
    let register: User
}

struct User: Decodable {
    let id: String
    let email: String
    let createdAt: Date
    let updatedAt: Date
}

// MinIO-Response-Modelle
struct PresignedUrlData: Decodable {
    let getPresignedUploadUrl: PresignedUrlResponse
}

struct PresignedUrlResponse: Decodable {
    let url: String
    let objectName: String
}

struct DownloadUrlData: Decodable {
    let getPresignedDownloadUrl: String
} 