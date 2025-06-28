//
//  APIClient.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine

class APIClient: ObservableObject {
    static let shared = APIClient()
    
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isTestingConnection = false
    @Published var lastConnectionTest: ConnectionTestResult?
    
    enum APIError: LocalizedError, Equatable {
        case invalidURL
        case noInternetConnection
        case unauthorized
        case serverError(Int)
        case invalidResponse
        case decodingError
        case timeout
        case unknown(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Ungültige URL"
            case .noInternetConnection:
                return "Keine Internetverbindung"
            case .unauthorized:
                return "Anmeldedaten ungültig"
            case .serverError(let code):
                return "Server-Fehler (\(code))"
            case .invalidResponse:
                return "Ungültige Server-Antwort"
            case .decodingError:
                return "Fehler beim Verarbeiten der Daten"
            case .timeout:
                return "Zeitüberschreitung"
            case .unknown(let message):
                return "Unbekannter Fehler: \(message)"
            }
        }
    }
    
    struct ConnectionTestResult {
        let isSuccessful: Bool
        let error: APIError?
        let responseTime: TimeInterval
        let serverVersion: String?
        let timestamp: Date
        
        var statusText: String {
            if isSuccessful {
                return "Verbindung erfolgreich (\(Int(responseTime * 1000))ms)"
            } else {
                return error?.errorDescription ?? "Verbindung fehlgeschlagen"
            }
        }
    }
    
    private init() {}
    
    // MARK: - Connection Testing
    
    func testConnection(url: String, username: String, password: String) -> AnyPublisher<ConnectionTestResult, Never> {
        isTestingConnection = true
        
        let startTime = Date()
        
        return performGraphQLHealthCheck(
            baseURL: url,
            username: username,
            password: password
        )
        .map { data in
            let responseTime = Date().timeIntervalSince(startTime)
            
            // GraphQL Response prüfen
            let serverVersion: String? = nil
            var isSuccessful = false
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseData = json["data"] as? [String: Any],
               let hello = responseData["hello"] as? String,
               hello == "Hello World!" {
                isSuccessful = true
            }
            
            return ConnectionTestResult(
                isSuccessful: isSuccessful,
                error: isSuccessful ? nil : .invalidResponse,
                responseTime: responseTime,
                serverVersion: serverVersion,
                timestamp: Date()
            )
        }
        .catch { (error: APIError) in
            let responseTime = Date().timeIntervalSince(startTime)
            
            let result = ConnectionTestResult(
                isSuccessful: false,
                error: error,
                responseTime: responseTime,
                serverVersion: nil,
                timestamp: Date()
            )
            
            return Just(result).eraseToAnyPublisher()
        }
        .handleEvents(
            receiveCompletion: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isTestingConnection = false
                }
            },
            receiveCancel: { [weak self] in
                DispatchQueue.main.async {
                    self?.isTestingConnection = false
                }
            }
        )
        .receive(on: DispatchQueue.main)
        .handleEvents(receiveOutput: { [weak self] result in
            self?.lastConnectionTest = result
        })
        .eraseToAnyPublisher()
    }
    
    // MARK: - GraphQL Health Check
    
    private func performGraphQLHealthCheck(
        baseURL: String,
        username: String,
        password: String
    ) -> AnyPublisher<Data, APIError> {
        
        // URL validieren und erstellen
        guard let url = URL(string: baseURL + "/graphql") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        
        // Headers setzen
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Basic Authentication
        let credentials = "\(username):\(password)"
        if let credentialsData = credentials.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        
        // GraphQL Query Body
        let graphqlQuery = ["query": "{ hello }"]
        if let bodyData = try? JSONSerialization.data(withJSONObject: graphqlQuery) {
            request.httpBody = bodyData
        }
        
        return session.dataTaskPublisher(for: request)
            .timeout(.seconds(30), scheduler: DispatchQueue.main)
            .tryMap { data, response in
                // HTTP-Status-Code prüfen
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                // Erfolgreiche Status-Codes: 200-299
                guard 200...299 ~= httpResponse.statusCode else {
                    switch httpResponse.statusCode {
                    case 401:
                        throw APIError.unauthorized
                    case 400...499:
                        throw APIError.serverError(httpResponse.statusCode)
                    case 500...599:
                        throw APIError.serverError(httpResponse.statusCode)
                    default:
                        throw APIError.serverError(httpResponse.statusCode)
                    }
                }
                
                return data
            }
            .mapError { error in
                // Bereits ein APIError? Direkt zurückgeben
                if let apiError = error as? APIError {
                    return apiError
                }
                
                // URLError behandeln
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        return .noInternetConnection
                    case .timedOut:
                        return .timeout
                    case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                        return .noInternetConnection
                    default:
                        return .unknown(urlError.localizedDescription)
                    }
                }
                
                // Alle anderen Fehler
                return .unknown(error.localizedDescription)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Generic Request Method
    
    private func performRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        baseURL: String,
        username: String,
        password: String,
        body: Data? = nil
    ) -> AnyPublisher<T, APIError> {
        
        // URL validieren und erstellen
        guard let url = URL(string: baseURL + endpoint) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30.0
        
        // Headers setzen
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Basic Authentication
        let credentials = "\(username):\(password)"
        if let credentialsData = credentials.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }
        
        // Body hinzufügen falls vorhanden
        if let body = body {
            request.httpBody = body
        }
        
        return session.dataTaskPublisher(for: request)
            .timeout(.seconds(30), scheduler: DispatchQueue.main)
            .tryMap { data, response -> T in
                // HTTP-Status-Code prüfen
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                // Erfolgreiche Status-Codes: 200-299
                guard 200...299 ~= httpResponse.statusCode else {
                    switch httpResponse.statusCode {
                    case 401:
                        throw APIError.unauthorized
                    case 400...499:
                        throw APIError.serverError(httpResponse.statusCode)
                    case 500...599:
                        throw APIError.serverError(httpResponse.statusCode)
                    default:
                        throw APIError.serverError(httpResponse.statusCode)
                    }
                }
                
                // Für Raw Data Response (z.B. Health Check)
                if T.self == Data.self {
                    return data as! T
                }
                
                // Für JSON Response
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
            }
            .mapError { error -> APIError in
                // Bereits ein APIError? Direkt zurückgeben
                if let apiError = error as? APIError {
                    return apiError
                }
                
                // URLError behandeln
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        return .noInternetConnection
                    case .timedOut:
                        return .timeout
                    case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                        return .noInternetConnection
                    default:
                        return .unknown(urlError.localizedDescription)
                    }
                }
                
                // DecodingError behandeln
                if error is DecodingError {
                    return .decodingError
                }
                
                // Alle anderen Fehler
                return .unknown(error.localizedDescription)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - HTTP Methods
    
    enum HTTPMethod: String {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case DELETE = "DELETE"
        case PATCH = "PATCH"
    }
} 