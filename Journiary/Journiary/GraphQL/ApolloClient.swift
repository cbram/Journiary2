//
//  ApolloClient.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine

/// Vereinfachte Demo GraphQL Client Implementation
/// Komplett ohne Apollo Dependencies - nur für Demo Mode
class ApolloClientManager: ObservableObject {
    
    static let shared = ApolloClientManager()
    
    // MARK: - Published Properties
    
    @Published var isConnected = false
    @Published var lastError: GraphQLError?
    
    // MARK: - Private Properties
    
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkConnection()
    }
    
    // MARK: - Connection Management
    
    func checkConnection() {
        // Demo Mode - immer "verbunden"
        isConnected = true
        lastError = nil
    }
    
    func clearCache() {
        // Demo - keine echte Cache zu löschen
        print("📦 Demo Cache gelöscht")
    }
    
    // MARK: - Health Check
    
    func healthCheck() -> AnyPublisher<Bool, GraphQLError> {
        return Just(true)
            .setFailureType(to: GraphQLError.self)
            .delay(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - GraphQL Error (vereinfacht)

enum GraphQLError: LocalizedError {
    case networkError(String)
    case authenticationRequired
    case invalidInput(String)
    case notFound(String)
    case serverError(String)
    case coreDataError(Error)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Netzwerk-Fehler: \(message)"
        case .authenticationRequired:
            return "Anmeldung erforderlich"
        case .invalidInput(let message):
            return "Ungültige Eingabe: \(message)"
        case .notFound(let message):
            return "Nicht gefunden: \(message)"
        case .serverError(let message):
            return "Server-Fehler: \(message)"
        case .coreDataError(let error):
            return "Datenbank-Fehler: \(error.localizedDescription)"
        case .unknown(let message):
            return "Unbekannter Fehler: \(message)"
        }
    }
    
    var localizedDescription: String {
        return errorDescription ?? "Unbekannter Fehler"
    }
} 