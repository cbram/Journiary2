//
//  ErrorHandler.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine
import SwiftUI

/// Zentraler Error Handler für benutzerfreundliche Fehlerbehandlung
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: UserFriendlyError?
    @Published var isRetrying = false
    
    private var retryAction: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Fehler benutzerfreundlich behandeln
    func handle(_ error: Error, retryAction: (() -> Void)? = nil) {
        let userFriendlyError = convertToUserFriendlyError(error)
        
        DispatchQueue.main.async { [weak self] in
            self?.currentError = userFriendlyError
            self?.retryAction = retryAction
        }
        
        // Analytics/Logging könnte hier hinzugefügt werden
        logError(error, userFriendlyError: userFriendlyError)
    }
    
    /// Retry-Aktion ausführen
    func retry() {
        guard let retryAction = retryAction else { return }
        
        isRetrying = true
        
        // Kurze Verzögerung für bessere UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isRetrying = false
            self?.currentError = nil
            retryAction()
        }
    }
    
    /// Fehler-Alert schließen
    func dismissError() {
        currentError = nil
        retryAction = nil
    }
    
    // MARK: - Private Methods
    
    private func convertToUserFriendlyError(_ error: Error) -> UserFriendlyError {
        // GraphQL Errors
        if let graphQLError = error as? GraphQLError {
            return handleGraphQLError(graphQLError)
        }
        
        // Network Errors
        if let urlError = error as? URLError {
            return handleURLError(urlError)
        }
        
        // User Service Errors
        if let userServiceError = error as? UserServiceError {
            return handleUserServiceError(userServiceError)
        }
        
        // Fallback für unbekannte Fehler
        return UserFriendlyError(
            title: "Unbekannter Fehler",
            message: error.localizedDescription,
            category: .unknown,
            severity: .medium,
            canRetry: true
        )
    }
    
    private func handleGraphQLError(_ error: GraphQLError) -> UserFriendlyError {
        switch error {
        case .networkError(let message):
            return UserFriendlyError(
                title: "Verbindungsfehler",
                message: NetworkMonitor.shared.isConnected ? 
                    "Der Server ist momentan nicht erreichbar. Bitte versuchen Sie es später erneut." :
                    "Keine Internetverbindung. Bitte prüfen Sie Ihre Netzwerkeinstellungen.",
                category: .network,
                severity: .high,
                canRetry: true,
                technicalDetails: message
            )
            
        case .authenticationRequired:
            return UserFriendlyError(
                title: "Anmeldung erforderlich",
                message: "Ihre Sitzung ist abgelaufen. Bitte melden Sie sich erneut an.",
                category: .authentication,
                severity: .high,
                canRetry: false
            )
            
        case .serverError(let message):
            return UserFriendlyError(
                title: "Server-Problem",
                message: isBackendOffline(message) ? 
                    "Der Server ist momentan offline. Bitte versuchen Sie es in einigen Minuten erneut." :
                    "Es ist ein Problem auf dem Server aufgetreten. Bitte versuchen Sie es erneut.",
                category: .server,
                severity: .high,
                canRetry: true,
                technicalDetails: message
            )
            
        case .invalidInput(let message):
            return UserFriendlyError(
                title: "Ungültige Eingabe",
                message: "Die eingegebenen Daten sind nicht gültig. Bitte prüfen Sie Ihre Eingaben.",
                category: .validation,
                severity: .medium,
                canRetry: false,
                technicalDetails: message
            )
            
        case .notFound(let message):
            return UserFriendlyError(
                title: "Nicht gefunden",
                message: "Die angeforderten Daten konnten nicht gefunden werden.",
                category: .validation,
                severity: .medium,
                canRetry: false,
                technicalDetails: message
            )
            
        case .cacheError(let message):
            return UserFriendlyError(
                title: "Cache-Problem",
                message: "Es gab ein Problem mit dem lokalen Speicher. Die App wird versuchen, die Daten neu zu laden.",
                category: .cache,
                severity: .low,
                canRetry: true,
                technicalDetails: message
            )
            
        case .parseError(let message):
            return UserFriendlyError(
                title: "Daten-Problem",
                message: "Die empfangenen Daten konnten nicht verarbeitet werden. Bitte versuchen Sie es erneut.",
                category: .parsing,
                severity: .medium,
                canRetry: true,
                technicalDetails: message
            )
            
        case .unknown(let message):
            return UserFriendlyError(
                title: "Unerwarteter Fehler",
                message: "Es ist ein unerwarteter Fehler aufgetreten. Bitte versuchen Sie es erneut.",
                category: .unknown,
                severity: .medium,
                canRetry: true,
                technicalDetails: message
            )
        }
    }
    
    private func handleURLError(_ error: URLError) -> UserFriendlyError {
        switch error.code {
        case .notConnectedToInternet:
            return UserFriendlyError(
                title: "Keine Internetverbindung",
                message: "Bitte prüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.",
                category: .network,
                severity: .high,
                canRetry: true
            )
            
        case .timedOut:
            return UserFriendlyError(
                title: "Zeitüberschreitung",
                message: "Die Verbindung hat zu lange gedauert. Bitte versuchen Sie es erneut.",
                category: .network,
                severity: .medium,
                canRetry: true
            )
            
        case .cannotFindHost, .cannotConnectToHost:
            return UserFriendlyError(
                title: "Server nicht erreichbar",
                message: "Der Server ist momentan nicht erreichbar. Bitte versuchen Sie es später erneut.",
                category: .network,
                severity: .high,
                canRetry: true
            )
            
        case .networkConnectionLost:
            return UserFriendlyError(
                title: "Verbindung unterbrochen",
                message: "Die Netzwerkverbindung wurde unterbrochen. Bitte versuchen Sie es erneut.",
                category: .network,
                severity: .medium,
                canRetry: true
            )
            
        default:
            return UserFriendlyError(
                title: "Netzwerkfehler",
                message: "Es gab ein Problem mit der Netzwerkverbindung. Bitte versuchen Sie es erneut.",
                category: .network,
                severity: .medium,
                canRetry: true,
                technicalDetails: error.localizedDescription
            )
        }
    }
    
    private func handleUserServiceError(_ error: UserServiceError) -> UserFriendlyError {
        switch error {
        case .noInternetConnection:
            return UserFriendlyError(
                title: "Keine Internetverbindung",
                message: "Bitte prüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.",
                category: .network,
                severity: .high,
                canRetry: true
            )
            
        case .timeout:
            return UserFriendlyError(
                title: "Zeitüberschreitung",
                message: "Die Anfrage hat zu lange gedauert. Bitte versuchen Sie es erneut.",
                category: .network,
                severity: .medium,
                canRetry: true
            )
            
        case .unauthorized:
            return UserFriendlyError(
                title: "Anmeldung fehlgeschlagen",
                message: "Die Anmeldedaten sind nicht korrekt. Bitte prüfen Sie E-Mail und Passwort.",
                category: .authentication,
                severity: .high,
                canRetry: false
            )
            
        case .serverError(let code):
            return UserFriendlyError(
                title: "Server-Problem",
                message: "Der Server hat einen Fehler zurückgegeben (Code: \(code)). Bitte versuchen Sie es später erneut.",
                category: .server,
                severity: .high,
                canRetry: true
            )
            
        case .graphqlError(let message):
            return UserFriendlyError(
                title: "Anfrage-Fehler",
                message: message.contains("User not found") ? 
                    "Benutzer nicht gefunden. Bitte prüfen Sie Ihre Anmeldedaten." :
                    message,
                category: .server,
                severity: .medium,
                canRetry: false,
                technicalDetails: message
            )
            
        default:
            return UserFriendlyError(
                title: "Unbekannter Fehler",
                message: error.localizedDescription,
                category: .unknown,
                severity: .medium,
                canRetry: true
            )
        }
    }
    
    private func isBackendOffline(_ message: String) -> Bool {
        let offlineKeywords = [
            "connection refused",
            "could not connect",
            "server not found",
            "nicht erreichbar",
            "offline"
        ]
        
        let lowercaseMessage = message.lowercased()
        return offlineKeywords.contains { lowercaseMessage.contains($0) }
    }
    
    private func logError(_ originalError: Error, userFriendlyError: UserFriendlyError) {
        print("🚨 Error handled by ErrorHandler:")
        print("📋 Original: \(originalError)")
        print("👤 User-Friendly: \(userFriendlyError.title) - \(userFriendlyError.message)")
        print("🏷️ Category: \(userFriendlyError.category)")
        print("⚠️ Severity: \(userFriendlyError.severity)")
        print("🔄 Can Retry: \(userFriendlyError.canRetry)")
        
        // Hier könnten Analytics/Crash-Reporting Services integriert werden
        // z.B. Firebase Crashlytics, Sentry, etc.
    }
}

// MARK: - User Friendly Error

struct UserFriendlyError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let category: ErrorCategory
    let severity: ErrorSeverity
    let canRetry: Bool
    let technicalDetails: String?
    
    init(
        title: String,
        message: String,
        category: ErrorCategory,
        severity: ErrorSeverity,
        canRetry: Bool,
        technicalDetails: String? = nil
    ) {
        self.title = title
        self.message = message
        self.category = category
        self.severity = severity
        self.canRetry = canRetry
        self.technicalDetails = technicalDetails
    }
}

// MARK: - Error Category

enum ErrorCategory {
    case network
    case authentication
    case server
    case validation
    case cache
    case parsing
    case unknown
    
    var iconName: String {
        switch self {
        case .network:
            return "wifi.exclamationmark"
        case .authentication:
            return "person.badge.key.fill"
        case .server:
            return "server.rack"
        case .validation:
            return "exclamationmark.triangle.fill"
        case .cache:
            return "internaldrive.fill"
        case .parsing:
            return "doc.text.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .network:
            return .orange
        case .authentication:
            return .red
        case .server:
            return .red
        case .validation:
            return .yellow
        case .cache:
            return .blue
        case .parsing:
            return .purple
        case .unknown:
            return .gray
        }
    }
}

// MARK: - Error Severity

enum ErrorSeverity {
    case low
    case medium
    case high
    case critical
    
    var displayName: String {
        switch self {
        case .low:
            return "Niedrig"
        case .medium:
            return "Mittel"
        case .high:
            return "Hoch"
        case .critical:
            return "Kritisch"
        }
    }
} 