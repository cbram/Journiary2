//
//  CoreDataMigrationManager.swift
//  Journiary
//
//  Created by TravelCompanion AI on 28.12.24.
//

import Foundation
import CoreData
import SwiftUI

/// Core Data Migration Manager für Multi-User Schema Updates
/// Behandelt Lightweight Migration und Legacy-Daten Assignment
@MainActor
class CoreDataMigrationManager: ObservableObject {
    
    static let shared = CoreDataMigrationManager()
    
    // MARK: - Published Properties
    
    @Published var migrationInProgress = false
    @Published var migrationProgress: Double = 0.0
    @Published var migrationStatus: String = ""
    @Published var migrationError: String?
    @Published var migrationCompleted = false
    
    // MARK: - Private Properties
    
    private let modelName = "Journiary"
    private var migrationStep = 0
    private var totalMigrationSteps = 5
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Überprüft ob Migration erforderlich ist
    /// - Parameter storeURL: URL des Core Data Stores
    /// - Returns: true wenn Migration erforderlich ist
    func isMigrationRequired(storeURL: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            // Neuer Store - keine Migration erforderlich
            return false
        }
        
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType, 
                at: storeURL, 
                options: nil
            )
            
            guard let currentModel = managedObjectModel() else {
                print("❌ Konnte aktuelles Datenmodell nicht laden")
                return false
            }
            
            return !currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        } catch {
            print("❌ Fehler beim Überprüfen der Migration: \(error)")
            return false
        }
    }
    
    /// Führt Migration durch
    func performMigration(storeURL: URL) async throws {
        migrationInProgress = true
        migrationProgress = 0.0
        migrationError = nil
        migrationStep = 0
        updateMigrationStatus("Migration wird gestartet...")
        
        defer {
            migrationInProgress = false
        }
        
        do {
            try await assignLegacyDataToDefaultUser(storeURL: storeURL)
            migrationCompleted = true
            updateMigrationStatus("✅ Migration erfolgreich abgeschlossen")
        } catch {
            migrationError = "Migration fehlgeschlagen: \(error.localizedDescription)"
            updateMigrationStatus("❌ Migration fehlgeschlagen")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func assignLegacyDataToDefaultUser(storeURL: URL) async throws {
        await incrementMigrationProgress("Lade Datenbank...")
        
        guard let model = managedObjectModel() else {
            throw MigrationError.modelNotFound
        }
        
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        let options: [String: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: options
        )
        
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        
        try await context.perform {
            await self.incrementMigrationProgress("Erstelle Default User...")
            
            // Default User erstellen/finden
            let userRequest: NSFetchRequest<User> = User.fetchRequest()
            userRequest.predicate = NSPredicate(format: "username == %@", "legacy_user")
            userRequest.fetchLimit = 1
            
            let defaultUser: User
            if let existingUser = try context.fetch(userRequest).first {
                defaultUser = existingUser
            } else {
                defaultUser = User(context: context)
                defaultUser.id = UUID()
                defaultUser.username = "legacy_user"
                defaultUser.email = "legacy@user.local"
                defaultUser.firstName = "Legacy"
                defaultUser.lastName = "User"
                defaultUser.isCurrentUser = true
                defaultUser.createdAt = Date()
                defaultUser.updatedAt = Date()
            }
            
            await self.incrementMigrationProgress("Weise Legacy-Trips zu...")
            
            // Legacy Trips zuweisen
            let orphanTripsRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
            orphanTripsRequest.predicate = NSPredicate(format: "owner == nil")
            let orphanTrips = try context.fetch(orphanTripsRequest)
            
            for trip in orphanTrips {
                trip.owner = defaultUser
            }
            
            await self.incrementMigrationProgress("Weise Legacy-Memories zu...")
            
            // Legacy Memories zuweisen
            let orphanMemoriesRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
            orphanMemoriesRequest.predicate = NSPredicate(format: "creator == nil")
            let orphanMemories = try context.fetch(orphanMemoriesRequest)
            
            for memory in orphanMemories {
                memory.creator = defaultUser
            }
            
            await self.incrementMigrationProgress("Speichere Änderungen...")
            
            try context.save()
            print("✅ Legacy-Daten Migration: \(orphanTrips.count) Trips, \(orphanMemories.count) Memories")
        }
        
        coordinator.remove(store)
    }
    
    private func managedObjectModel() -> NSManagedObjectModel? {
        return NSManagedObjectModel.mergedModel(from: [Bundle.main])
    }
    
    private func incrementMigrationProgress(_ status: String) async {
        await MainActor.run {
            migrationStep += 1
            migrationProgress = Double(migrationStep) / Double(totalMigrationSteps)
            updateMigrationStatus(status)
        }
    }
    
    private func updateMigrationStatus(_ status: String) {
        migrationStatus = status
        print("🔄 Migration: \(status)")
    }
}

// MARK: - Migration Errors

private enum MigrationError: LocalizedError {
    case modelNotFound
    case migrationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Das Datenmodell konnte nicht geladen werden."
        case .migrationFailed(let reason):
            return "Migration fehlgeschlagen: \(reason)"
        }
    }
}

// MARK: - SwiftUI Integration

/// SwiftUI View für Migration Progress
struct MigrationProgressView: View {
    @StateObject private var migrationManager = CoreDataMigrationManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            // Migration Icon
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(migrationManager.migrationInProgress ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: migrationManager.migrationInProgress)
            
            VStack(spacing: 12) {
                Text("Datenbank wird aktualisiert")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(migrationManager.migrationStatus)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Progress Bar
            VStack(spacing: 8) {
                ProgressView(value: migrationManager.migrationProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                
                Text("\(Int(migrationManager.migrationProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Error Message
            if let errorMessage = migrationManager.migrationError {
                Text("⚠️ \(errorMessage)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text("Bitte warten Sie, während Ihre Daten für Multi-User Support aktualisiert werden...")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
} 