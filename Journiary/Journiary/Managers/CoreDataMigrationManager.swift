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
    func isMigrationRequired(storeURL: URL) async -> Bool {
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
        
        // Schritt 1: Erstelle Standard-User für Legacy-Daten
        await incrementMigrationProgress("Erstelle Standard-User für Legacy-Daten...")
        
        let defaultUser: User = try await context.perform {
            // Prüfe ob bereits User existieren
            let existingUsersRequest: NSFetchRequest<User> = User.fetchRequest()
            let existingUsers = try context.fetch(existingUsersRequest)
            
            if let firstUser = existingUsers.first {
                // Verwende existierenden User
                return firstUser
            } else {
                // Erstelle neuen User nur wenn gar keine existieren
                let newUser = User(context: context)
                newUser.id = UUID()
                newUser.username = "system_admin"
                newUser.email = "admin@system.local"
                newUser.firstName = "System"
                newUser.lastName = "Administrator"
                newUser.isCurrentUser = true
                newUser.createdAt = Date()
                newUser.updatedAt = Date()
                return newUser
            }
        }
        
        await incrementMigrationProgress("Verwende User: \(defaultUser.displayName)")
        
        // Schritt 2: Migriere Legacy-Daten
        await incrementMigrationProgress("Migriere Legacy-Daten...")
        
        let migrationCounts = try await context.perform {
            var counts = [String: Int]()
            
            // Legacy Trips zuweisen
            let orphanTripsRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
            orphanTripsRequest.predicate = NSPredicate(format: "owner == nil")
            let orphanTrips = try context.fetch(orphanTripsRequest)
            
            for trip in orphanTrips {
                trip.owner = defaultUser
            }
            counts["Trips"] = orphanTrips.count
            
            // Legacy Memories zuweisen
            let orphanMemoriesRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
            orphanMemoriesRequest.predicate = NSPredicate(format: "creator == nil")
            let orphanMemories = try context.fetch(orphanMemoriesRequest)
            
            for memory in orphanMemories {
                memory.creator = defaultUser
            }
            counts["Memories"] = orphanMemories.count
            
            // Legacy MediaItems zuweisen
            let orphanMediaRequest: NSFetchRequest<MediaItem> = MediaItem.fetchRequest()
            orphanMediaRequest.predicate = NSPredicate(format: "uploader == nil")
            let orphanMedia = try context.fetch(orphanMediaRequest)
            
            for mediaItem in orphanMedia {
                mediaItem.uploader = defaultUser
            }
            counts["MediaItems"] = orphanMedia.count
            
            // Legacy BucketListItems zuweisen
            let orphanBucketRequest: NSFetchRequest<BucketListItem> = BucketListItem.fetchRequest()
            orphanBucketRequest.predicate = NSPredicate(format: "creator == nil")
            let orphanBucketItems = try context.fetch(orphanBucketRequest)
            
            for bucketItem in orphanBucketItems {
                bucketItem.creator = defaultUser
            }
            counts["BucketListItems"] = orphanBucketItems.count
            
            // Legacy Tags zuweisen
            let orphanTagsRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            orphanTagsRequest.predicate = NSPredicate(format: "creator == nil")
            let orphanTags = try context.fetch(orphanTagsRequest)
            
            for tag in orphanTags {
                tag.creator = defaultUser
            }
            counts["Tags"] = orphanTags.count
            
            return counts
        }
        
        // Schritt 3: Speichere Änderungen
        await incrementMigrationProgress("Speichere Änderungen...")
        try await context.perform {
            try context.save()
        }
        
        // Migrations-Zusammenfassung loggen
        let summary = migrationCounts.map { "\($0.value) \($0.key)" }.joined(separator: ", ")
        print("✅ Legacy-Daten Migration erfolgreich: \(summary)")
        print("👤 Zugewiesen an User: \(defaultUser.displayName) (\(defaultUser.email ?? "N/A"))")
        
        try coordinator.remove(store)
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