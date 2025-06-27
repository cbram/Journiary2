//
//  SyncManager.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import CoreData
import Combine
import SwiftUI

/// Manager für die Synchronisierung zwischen lokaler Datenbank und Backend
class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    @Published var syncProgress: Double = 0
    
    private let settings = AppSettings.shared
    private let apiClient = APIClient.shared
    private let networkMonitor = NetworkMonitor.shared
    private let offlineQueue = OfflineQueue.shared
    private let conflictResolver = ConflictResolver.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var syncTask: Task<Void, Error>?
    
    private init() {
        loadLastSyncDate()
    }
    
    /// Lädt das letzte Synchronisierungsdatum aus den UserDefaults
    private func loadLastSyncDate() {
        if let date = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = date
        }
    }
    
    /// Speichert das letzte Synchronisierungsdatum in den UserDefaults
    private func saveLastSyncDate() {
        UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
        lastSyncDate = Date()
    }
    
    /// Startet die Synchronisierung
    /// - Returns: Ein Void-Task, der die Synchronisierung durchführt
    @discardableResult
    func startSync() async -> Bool {
        guard settings.syncEnabled, !isSyncing else {
            return false
        }
        
        // Prüfen, ob eine Netzwerkverbindung verfügbar ist
        guard networkMonitor.canSync() else {
            print("Keine geeignete Netzwerkverbindung für die Synchronisierung verfügbar")
            return false
        }
        
        isSyncing = true
        syncProgress = 0
        syncError = nil
        
        do {
            // Erstelle einen neuen Hintergrund-Kontext für die Synchronisierung
            let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
            backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            // Verarbeite die Offline-Warteschlange
            let queueSuccess = await processOfflineQueue(context: backgroundContext)
            
            // Wenn die Warteschlange nicht erfolgreich verarbeitet wurde, brechen wir ab
            if !queueSuccess && !offlineQueue.operations.isEmpty {
                throw SyncError.offlineQueueProcessingFailed
            }
            
            // Synchronisiere alle Entitätstypen
            try await synchronizeAllEntities(context: backgroundContext)
            
            // Speichere das letzte Synchronisierungsdatum
            saveLastSyncDate()
            
            // Synchronisierung erfolgreich abgeschlossen
            syncProgress = 1.0
            return true
        } catch {
            syncError = error
            print("Synchronisierungsfehler: \(error)")
            return false
        } finally {
            isSyncing = false
        }
    }
    
    /// Bricht die aktuelle Synchronisierung ab
    func cancelSync() {
        syncTask?.cancel()
        syncTask = nil
        isSyncing = false
    }
    
    /// Verarbeitet die Offline-Warteschlange
    /// - Parameter context: Der NSManagedObjectContext
    /// - Returns: `true`, wenn die Warteschlange erfolgreich verarbeitet wurde, sonst `false`
    private func processOfflineQueue(context: NSManagedObjectContext) async -> Bool {
        return await withCheckedContinuation { continuation in
            offlineQueue.processQueue(context: context) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    /// Synchronisiert alle Entitätstypen
    /// - Parameter context: Der NSManagedObjectContext
    private func synchronizeAllEntities(context: NSManagedObjectContext) async throws {
        // Aktualisiere den Fortschritt
        syncProgress = 0.1
        
        // Synchronisiere Benutzer
        try await synchronizeUsers(context: context)
        syncProgress = 0.2
        
        // Synchronisiere Tag-Kategorien
        try await synchronizeTagCategories(context: context)
        syncProgress = 0.3
        
        // Synchronisiere Tags
        try await synchronizeTags(context: context)
        syncProgress = 0.4
        
        // Synchronisiere Reisen
        try await synchronizeTrips(context: context)
        syncProgress = 0.5
        
        // Synchronisiere Erinnerungen
        try await synchronizeMemories(context: context)
        syncProgress = 0.7
        
        // Synchronisiere Medien
        try await synchronizeMediaItems(context: context)
        syncProgress = 0.9
        
        // Synchronisiere Bucket-List-Einträge
        try await synchronizeBucketListItems(context: context)
        syncProgress = 1.0
    }
    
    /// Synchronisiert Daten mit dem Backend
    /// - Parameter context: Der NSManagedObjectContext
    /// - Parameter completion: Der Abschlusshandler mit dem Erfolg der Synchronisierung
    func syncData(context: NSManagedObjectContext, completion: @escaping (Bool) -> Void) {
        guard settings.syncEnabled, !isSyncing else {
            completion(false)
            return
        }
        
        // Prüfen, ob eine Netzwerkverbindung verfügbar ist
        guard networkMonitor.canSync() else {
            completion(false)
            return
        }
        
        isSyncing = true
        syncProgress = 0
        syncError = nil
        
        // Verarbeite die Offline-Warteschlange
        offlineQueue.processQueue(context: context) { queueSuccess in
            // Wenn die Warteschlange nicht erfolgreich verarbeitet wurde und nicht leer ist, brechen wir ab
            if !queueSuccess && !self.offlineQueue.operations.isEmpty {
                self.syncError = SyncError.offlineQueueProcessingFailed
                self.isSyncing = false
                completion(false)
                return
            }
            
            // Erstelle einen Task für die Synchronisierung
            self.syncTask = Task {
                do {
                    // Synchronisiere alle Entitätstypen
                    try await self.synchronizeAllEntities(context: context)
                    
                    // Speichere das letzte Synchronisierungsdatum
                    self.saveLastSyncDate()
                    
                    // Synchronisierung erfolgreich abgeschlossen
                    self.syncProgress = 1.0
                    self.isSyncing = false
                    completion(true)
                } catch {
                    self.syncError = error
                    print("Synchronisierungsfehler: \(error)")
                    self.isSyncing = false
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Entity Synchronization
    
    /// Synchronisiert Benutzer
    /// - Parameter context: Der NSManagedObjectContext
    private func synchronizeUsers(context: NSManagedObjectContext) async throws {
        // Implementierung der Benutzersynchronisierung
    }
    
    /// Synchronisiert Tag-Kategorien
    /// - Parameter context: Der NSManagedObjectContext
    private func synchronizeTagCategories(context: NSManagedObjectContext) async throws {
        // Implementierung der Tag-Kategorien-Synchronisierung
    }
    
    /// Synchronisiert Tags
    /// - Parameter context: Der NSManagedObjectContext
    private func synchronizeTags(context: NSManagedObjectContext) async throws {
        // Implementierung der Tag-Synchronisierung
    }
    
    /// Synchronisiert Reisen
    /// - Parameter context: Der NSManagedObjectContext
    private func synchronizeTrips(context: NSManagedObjectContext) async throws {
        // Implementierung der Reisen-Synchronisierung
    }
    
    /// Synchronisiert Erinnerungen
    /// - Parameter context: Der NSManagedObjectContext
    private func synchronizeMemories(context: NSManagedObjectContext) async throws {
        // Implementierung der Erinnerungen-Synchronisierung
    }
    
    /// Synchronisiert Medien
    /// - Parameter context: Der NSManagedObjectContext
    private func synchronizeMediaItems(context: NSManagedObjectContext) async throws {
        // Implementierung der Medien-Synchronisierung
    }
    
    /// Synchronisiert Bucket-List-Einträge
    /// - Parameter context: Der NSManagedObjectContext
    private func synchronizeBucketListItems(context: NSManagedObjectContext) async throws {
        // Implementierung der Bucket-List-Einträge-Synchronisierung
    }
    
    // MARK: - Helper Methods
    
    /// Erkennt und löst Konflikte zwischen lokalen und Remote-Daten
    /// - Parameters:
    ///   - localEntity: Die lokale Entität
    ///   - remoteData: Die Remote-Daten
    ///   - entityType: Der Typ der Entität
    ///   - context: Der NSManagedObjectContext
    /// - Returns: Die aufgelösten Daten
    private func resolveConflicts(localEntity: NSManagedObject, remoteData: [String: Any], entityType: String, context: NSManagedObjectContext) -> [String: Any] {
        // Erkennen von Konflikten
        if let conflict = conflictResolver.detectConflict(localEntity: localEntity, remoteData: remoteData, entityType: entityType) {
            // Auflösen von Konflikten
            return conflictResolver.resolveConflict(conflict, context: context)
        }
        
        // Wenn kein Konflikt erkannt wurde, geben wir die Remote-Daten zurück
        return remoteData
    }
}

/// Fehler, die bei der Synchronisierung auftreten können
enum SyncError: Error {
    case networkError
    case authenticationError
    case serverError
    case localDatabaseError
    case offlineQueueProcessingFailed
    case mediaUploadError
    case mediaDownloadError
    case conflictResolutionError
}

/// View-Modifier für die Anzeige des Synchronisierungsstatus
struct SyncStatusModifier: ViewModifier {
    @ObservedObject private var syncManager = SyncManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if syncManager.isSyncing {
                        VStack {
                            Spacer()
                            
                            HStack {
                                Spacer()
                                
                                VStack(spacing: 10) {
                                    ProgressView(value: syncManager.syncProgress, total: 1.0)
                                        .progressViewStyle(LinearProgressViewStyle())
                                        .frame(width: 200)
                                    
                                    Text(syncManager.currentSyncOperation ?? "Synchronisiere...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 5)
                                
                                Spacer()
                            }
                            
                            Spacer().frame(height: 50)
                        }
                    }
                }
            )
    }
}

extension View {
    /// Fügt einen Overlay für den Synchronisierungsstatus hinzu
    func withSyncStatus() -> some View {
        self.modifier(SyncStatusModifier())
    }
} 