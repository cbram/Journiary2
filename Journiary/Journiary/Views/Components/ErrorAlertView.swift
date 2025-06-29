//
//  ErrorAlertView.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import SwiftUI

/// Benutzerfreundliche Error Alert View mit Retry-Funktionalität
struct ErrorAlertView: View {
    let error: UserFriendlyError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var errorHandler = ErrorHandler.shared
    @State private var showingTechnicalDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Error Content
            errorContentView
            
            // Action Buttons
            buttonSection
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(error.category.color.opacity(0.3), lineWidth: 2)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Error Content
    
    private var errorContentView: some View {
        VStack(spacing: 16) {
            // Header with Icon
            errorHeaderView
            
            // Error Message
            errorMessageView
            
            // Network Status (if network related)
            if error.category == .network {
                networkStatusView
            }
            
            // Technical Details (if available and requested)
            if showingTechnicalDetails, let technicalDetails = error.technicalDetails {
                technicalDetailsView(technicalDetails)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
    
    private var errorHeaderView: some View {
        VStack(spacing: 12) {
            // Error Icon
            Image(systemName: error.category.iconName)
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(error.category.color)
                .symbolEffect(.bounce, options: .speed(0.5))
            
            // Error Title
            Text(error.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var errorMessageView: some View {
        VStack(spacing: 8) {
            Text(error.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            // Severity Badge
            severityBadge
        }
    }
    
    private var severityBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(severityColor)
                .frame(width: 8, height: 8)
            
            Text(error.severity.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var severityColor: Color {
        switch error.severity {
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
    
    private var networkStatusView: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack(spacing: 12) {
                Image(systemName: networkMonitor.connectionType.iconName)
                    .foregroundColor(networkMonitor.isConnected ? .green : .red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Netzwerkstatus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(networkMonitor.connectionStatusText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Circle()
                    .fill(networkMonitor.isConnected ? .green : .red)
                    .frame(width: 12, height: 12)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private func technicalDetailsView(_ details: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            HStack {
                Text("Technische Details")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Ausblenden") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingTechnicalDetails = false
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            Text(details)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .textSelection(.enabled)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Button Section
    
    private var buttonSection: some View {
        VStack(spacing: 12) {
            Divider()
            
            HStack(spacing: 12) {
                // Technical Details Button (if available)
                if error.technicalDetails != nil {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingTechnicalDetails.toggle()
                        }
                    }) {
                        Image(systemName: showingTechnicalDetails ? "info.circle.fill" : "info.circle")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)
                }
                
                Spacer()
                
                // Dismiss Button
                Button("Schließen") {
                    onDismiss()
                }
                .foregroundColor(.secondary)
                
                // Retry Button (if available)
                if error.canRetry, let onRetry = onRetry {
                    Button(action: {
                        onRetry()
                    }) {
                        HStack(spacing: 6) {
                            if errorHandler.isRetrying {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.subheadline)
                            }
                            
                            Text(errorHandler.isRetrying ? "Versuche erneut..." : "Wiederholen")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(error.category.color)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(errorHandler.isRetrying)
                    .scaleEffect(errorHandler.isRetrying ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: errorHandler.isRetrying)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Error Alert Modifier

extension View {
    /// Zeigt benutzerfreundliche Error Alerts an
    func errorAlert(
        isPresented: Binding<Bool>,
        error: UserFriendlyError?,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        self.overlay(
            Group {
                if isPresented.wrappedValue, let error = error {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isPresented.wrappedValue = false
                            onDismiss?()
                        }
                    
                    ErrorAlertView(
                        error: error,
                        onRetry: onRetry,
                        onDismiss: {
                            isPresented.wrappedValue = false
                            onDismiss?()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented.wrappedValue)
        )
    }
}

// MARK: - ErrorHandler Integration Extension

extension View {
    /// Integriert den globalen ErrorHandler
    func handleErrors() -> some View {
        self
            .environmentObject(ErrorHandler.shared)
            .errorAlert(
                isPresented: .constant(ErrorHandler.shared.currentError != nil),
                error: ErrorHandler.shared.currentError,
                onRetry: {
                    ErrorHandler.shared.retry()
                },
                onDismiss: {
                    ErrorHandler.shared.dismissError()
                }
            )
    }
}

// MARK: - Preview

struct ErrorAlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Network Error
            ErrorAlertView(
                error: UserFriendlyError(
                    title: "Verbindungsfehler",
                    message: "Der Server ist momentan nicht erreichbar. Bitte versuchen Sie es später erneut.",
                    category: .network,
                    severity: .high,
                    canRetry: true,
                    technicalDetails: "Connection failed: The server is not responding"
                ),
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Network Error")
            
            // Authentication Error
            ErrorAlertView(
                error: UserFriendlyError(
                    title: "Anmeldung fehlgeschlagen",
                    message: "Die Anmeldedaten sind nicht korrekt. Bitte prüfen Sie E-Mail und Passwort.",
                    category: .authentication,
                    severity: .high,
                    canRetry: false
                ),
                onRetry: nil,
                onDismiss: {}
            )
            .previewDisplayName("Auth Error")
            
            // Server Error with Technical Details
            ErrorAlertView(
                error: UserFriendlyError(
                    title: "Server-Problem",
                    message: "Es ist ein Problem auf dem Server aufgetreten. Bitte versuchen Sie es erneut.",
                    category: .server,
                    severity: .medium,
                    canRetry: true,
                    technicalDetails: "GraphQL Error: Field 'user' is required but was not provided in the response."
                ),
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Server Error")
        }
        .padding()
        .background(Color(.systemGray5))
    }
} 