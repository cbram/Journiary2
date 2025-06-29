//
//  GraphQLSyncService.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine
import CoreData

/// GraphQL Sync Service - Demo Mode Implementation
/// Vereinfachte Synchronisation zwischen Core Data und Backend
class GraphQLSyncService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0.0
    @Published var lastSyncDate: Date?
    @Published var syncError: GraphQLError?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let context = PersistenceController.shared.container.viewContext
    
    // Services
    private let userService = GraphQLUserService()
    private let tripService = GraphQLTripService()
    private let mediaService = GraphQLMediaService()
    
    // MARK: - Demo Mode
    
    private var isDemoMode: Bool {
        return AppSettings.shared.backendURL.contains("localhost") ||
               AppSettings.shared.backendURL.contains("127.0.0.1")
    }
    
    // MARK: - Full Sync Operations
    
    /// Vollständige Synchronisation durchführen
    /// - Returns: Publisher mit Bool (Erfolg)
    func performFullSync() -> AnyPublisher<Bool, GraphQLError> {
        
        if isDemoMode {
            return performDemoSync()
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    /// Nur Upload durchführen (lokale Änderungen zum Server)
    /// - Returns: Publisher mit Bool (Erfolg)
    func uploadChanges() -> AnyPublisher<Bool, GraphQLError> {
        
        if isDemoMode {
            return simulateUpload()
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    /// Nur Download durchführen (Server-Änderungen zu lokal)
    /// - Returns: Publisher mit Bool (Erfolg)
    func downloadChanges() -> AnyPublisher<Bool, GraphQLError> {
        
        if isDemoMode {
            return simulateDownload()
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    // MARK: - Conflict Resolution
    
    /// Konflikte auflösen
    /// - Parameter strategy: Auflösungsstrategie
    /// - Returns: Publisher mit Bool (Erfolg)
    func resolveConflicts(strategy: ConflictResolutionStrategy = .serverWins) -> AnyPublisher<Bool, GraphQLError> {
        
        if isDemoMode {
            return Just(true)
                .setFailureType(to: GraphQLError.self)
                .delay(for: .seconds(1), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        
        return Fail(error: GraphQLError.networkError("Backend nicht verfügbar"))
            .eraseToAnyPublisher()
    }
    
    // MARK: - Background Sync
    
    /// Hintergrund-Synchronisation starten
    func startBackgroundSync() {
        guard !isSyncing else { return }
        
        Timer.publish(every: 300, on: .main, in: .common) // Alle 5 Minuten
            .autoconnect()
            .sink { [weak self] _ in
                self?.performQuietSync()
            }
            .store(in: &cancellables)
    }
    
    /// Stille Synchronisation (ohne UI Updates)
    private func performQuietSync() {
        guard !isSyncing else { return }
        
        uploadChanges()
            .sink(
                receiveCompletion: { _ in
                    // Fehler ignorieren bei stiller Sync
                },
                receiveValue: { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.lastSyncDate = Date()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Demo Mode Implementations
    
    private func performDemoSync() -> AnyPublisher<Bool, GraphQLError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown("Service nicht verfügbar")))
                return
            }
            
            DispatchQueue.main.async {
                self.isSyncing = true
                self.syncProgress = 0.0
                self.syncError = nil
            }
            
            // Simuliere Sync-Schritte
            self.simulateSyncSteps { success in
                DispatchQueue.main.async {
                    self.isSyncing = false
                    self.syncProgress = success ? 1.0 : 0.0
                    self.lastSyncDate = success ? Date() : nil
                    
                    if success {
                        promise(.success(true))
                    } else {
                        let error = GraphQLError.unknown("Sync-Demo fehlgeschlagen")
                        self.syncError = error
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func simulateSyncSteps(completion: @escaping (Bool) -> Void) {
        let steps = [
            "Verbindung prüfen...",
            "Trips hochladen...",
            "Memories synchronisieren...",
            "Media-Dateien abgleichen...",
            "Konflikte auflösen...",
            "Synchronisation abschließen..."
        ]
        
        var currentStep = 0
        
        func executeNextStep() {
            guard currentStep < steps.count else {
                completion(true)
                return
            }
            
            let progress = Double(currentStep) / Double(steps.count)
            
            DispatchQueue.main.async {
                self.syncProgress = progress
            }
            
            // Simuliere Verarbeitungszeit
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                currentStep += 1
                executeNextStep()
            }
        }
        
        executeNextStep()
    }
    
    private func simulateUpload() -> AnyPublisher<Bool, GraphQLError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown("Service nicht verfügbar")))
                return
            }
            
            DispatchQueue.main.async {
                self.isSyncing = true
                self.syncProgress = 0.0
            }
            
            // Simuliere Upload
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.isSyncing = false
                self.syncProgress = 1.0
                self.lastSyncDate = Date()
                promise(.success(true))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func simulateDownload() -> AnyPublisher<Bool, GraphQLError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.unknown("Service nicht verfügbar")))
                return
            }
            
            DispatchQueue.main.async {
                self.isSyncing = true
                self.syncProgress = 0.0
            }
            
            // Simuliere Download
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.isSyncing = false
                self.syncProgress = 1.0
                self.lastSyncDate = Date()
                promise(.success(true))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Conflict Resolution Strategy

enum ConflictResolutionStrategy {
    case serverWins      // Server-Version gewinnt
    case clientWins      // Client-Version gewinnt
    case manual          // Manuelle Auflösung erforderlich
    case merge           // Automatisches Merging
}

// MARK: - Sync Status

struct SyncStatus {
    let isActive: Bool
    let progress: Double
    let currentStep: String?
    let lastSyncDate: Date?
    let error: GraphQLError?
    
    var isComplete: Bool {
        return !isActive && progress >= 1.0
    }
    
    var hasError: Bool {
        return error != nil
    }
} 