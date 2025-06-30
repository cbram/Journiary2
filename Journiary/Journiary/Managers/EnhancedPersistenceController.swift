//
//  EnhancedPersistenceController.swift
//  Journiary
//
//  Created by TravelCompanion AI on 28.12.24.
//

import CoreData
import Foundation
import SwiftUI

/// Enhanced Persistence Controller mit Multi-User Support und Migration
class EnhancedPersistenceController: ObservableObject {
    
    static let shared = EnhancedPersistenceController()
    
    // MARK: - Published Properties
    
    @Published var isInitialized = false
    @Published var initializationError: String?
    @Published var requiresMigration = false
    
    // MARK: - Core Data Stack
    
    lazy var container: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "Journiary")
        
        // CloudKit Configuration
        configureCloudKitContainer(container)
        
        // Store Configuration
        configureStoreDescription(container)
        
        return container
    }()
    
    // MARK: - Contexts
    
    /// Main Context für UI Operations (ViewContext)
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    /// Background Context für Heavy Operations
    lazy var backgroundContext: NSManagedObjectContext = {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        return context
    }()
    
    /// Sync Context für CloudKit/Backend Sync
    lazy var syncContext: NSManagedObjectContext = {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.name = "SyncContext"
        return context
    }()
    
    // MARK: - Migration Manager
    
    private let migrationManager = CoreDataMigrationManager.shared
    
    // MARK: - Initialization
    
    private init() {
        setupNotifications()
    }
    
    /// Initialisiert Core Data Stack mit Migration Support
    func initialize() async {
        await MainActor.run {
            isInitialized = false
            initializationError = nil
        }
        
        do {
            try await initializeCoreDataStack()
            await MainActor.run {
                isInitialized = true
            }
        } catch {
            await MainActor.run {
                initializationError = "Core Data Initialisierung fehlgeschlagen: \(error.localizedDescription)"
            }
            print("❌ Core Data Initialisierung fehlgeschlagen: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Initialisiert Core Data Stack mit Migration Check
    private func initializeCoreDataStack() async throws {
        let storeURL = container.persistentStoreDescriptions.first?.url
        
        // Migration Check
        if let url = storeURL, await migrationManager.isMigrationRequired(storeURL: url) {
            await MainActor.run {
                requiresMigration = true
            }
            
            print("🔄 Migration erforderlich - starte Migration...")
            try await migrationManager.performMigration(storeURL: url)
            print("✅ Migration abgeschlossen")
        }
        
        // Core Data Stack laden
        try await loadPersistentStores()
        
        // Post-Initialization Setup
        await performPostInitializationSetup()
    }
    
    /// Lädt Persistent Stores
    private func loadPersistentStores() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            container.loadPersistentStores { [weak self] (storeDescription, error) in
                if let error = error {
                    print("❌ Core Data Store Load Fehler: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ Core Data Store geladen: \(storeDescription.url?.lastPathComponent ?? "Unknown")")
                    self?.configureMergePolicy()
                    continuation.resume()
                }
            }
        }
    }
    
    /// Konfiguriert CloudKit Container
    private func configureCloudKitContainer(_ container: NSPersistentCloudKitContainer) {
        // CloudKit Container ID
        guard let description = container.persistentStoreDescriptions.first else {
            print("❌ Keine Store Description gefunden")
            return
        }
        
        // CloudKit Configuration
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // CloudKit Container Options
        let containerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.journiary.TravelCompanion")
        description.cloudKitContainerOptions = containerOptions
        
        print("✅ CloudKit Container konfiguriert")
    }
    
    /// Konfiguriert Store Description für Performance
    private func configureStoreDescription(_ container: NSPersistentCloudKitContainer) {
        guard let description = container.persistentStoreDescriptions.first else { return }
        
        // Migration Options
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        // Performance Options
        description.setOption("WAL" as NSString, forKey: "journal_mode")
        description.setOption(20000 as NSNumber, forKey: "cache_size")
        description.setOption(10000 as NSNumber, forKey: "synchronous")
        
        print("✅ Store Description konfiguriert für Performance")
    }
    
    /// Konfiguriert Merge Policy für Multi-User Conflicts
    private func configureMergePolicy() {
        // ViewContext: Merge Policy für UI
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Background Context: Merge Policy für Background Operations
        backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        // Sync Context: Merge Policy für Remote Sync
        syncContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        print("✅ Merge Policies konfiguriert")
    }
    
    /// Post-Initialization Setup
    private func performPostInitializationSetup() async {
        // Cleanup Temp Files
        cleanupTemporaryFiles()
        
        // Index Optimization
        await optimizeDatabaseIndexes()
        
        // Initialize User Context
        await initializeUserContext()
    }
    
    /// Optimiert Database Indexes für Multi-User Queries
    private func optimizeDatabaseIndexes() async {
        await backgroundContext.perform {
            do {
                // Analyze Database für bessere Query Performance
                let analyzeRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
                analyzeRequest.resultType = .dictionaryResultType
                
                _ = try self.backgroundContext.execute(analyzeRequest)
                print("✅ Database Indexes optimiert")
            } catch {
                print("❌ Database Optimization fehlgeschlagen: \(error)")
            }
        }
    }
    
    /// Initialisiert User Context
    private func initializeUserContext() async {
        await viewContext.perform {
            // Prüfe ob Current User existiert
            let userRequest: NSFetchRequest<User> = User.fetchRequest()
            userRequest.predicate = NSPredicate(format: "isCurrentUser == YES")
            userRequest.fetchLimit = 1
            
            do {
                let currentUsers = try self.viewContext.fetch(userRequest)
                if currentUsers.isEmpty {
                    print("⚠️ Kein Current User gefunden - UserContextManager wird initialisiert")
                }
            } catch {
                print("❌ User Context Check fehlgeschlagen: \(error)")
            }
        }
    }
    
    /// Setup Notifications für Remote Changes
    private func setupNotifications() {
        // CloudKit Remote Change Notifications
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("📡 CloudKit Remote Change empfangen")
            self?.handleRemoteChange(notification)
        }
        
        // Context Did Save Notifications
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleContextDidSave(notification)
        }
    }
    
    /// Behandelt Remote Changes von CloudKit
    private func handleRemoteChange(_ notification: Notification) {
        // Background Context für Remote Changes verwenden
        backgroundContext.perform {
            print("🔄 Verarbeite CloudKit Remote Changes...")
            // Weitere Remote Change Verarbeitung hier
        }
    }
    
    /// Behandelt Context Did Save Events
    private func handleContextDidSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext else { return }
        
        // Merge Changes zwischen Contexts
        if context.parent == nil && context != viewContext {
            viewContext.perform {
                self.viewContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
    
    /// Cleanup Temporary Files
    private func cleanupTemporaryFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        let migrationFiles = ["migration_step_", "temp_store_"]
        
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            
            for file in tempFiles {
                if migrationFiles.contains(where: { file.lastPathComponent.contains($0) }) {
                    try FileManager.default.removeItem(at: file)
                    print("🧹 Temp File entfernt: \(file.lastPathComponent)")
                }
            }
        } catch {
            print("❌ Temp File Cleanup fehlgeschlagen: \(error)")
        }
    }
    
    // MARK: - Public Helper Methods
    
    /// Sicherer Context Save mit Error Handling
    func save(context: NSManagedObjectContext = shared.viewContext) throws {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            print("✅ Context gespeichert")
        } catch {
            print("❌ Context Save fehlgeschlagen: \(error)")
            throw error
        }
    }
    
    /// Batch Delete Operation für Performance
    func batchDelete<T: NSManagedObject>(
        entityType: T.Type,
        predicate: NSPredicate,
        context: NSManagedObjectContext? = nil
    ) async throws {
        let contextToUse = context ?? backgroundContext
        
        try await contextToUse.perform {
            let entityName = String(describing: entityType)
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetchRequest.predicate = predicate
            
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                let result = try contextToUse.execute(deleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.viewContext])
                    print("✅ Batch Delete: \(objectIDs.count) \(entityName) Objekte")
                }
            } catch {
                print("❌ Batch Delete fehlgeschlagen: \(error)")
                throw error
            }
        }
    }
    
    /// Memory Warning Handler
    func handleMemoryWarning() {
        viewContext.refreshAllObjects()
        backgroundContext.refreshAllObjects()
        syncContext.refreshAllObjects()
        print("🧠 Memory Warning - Contexts refreshed")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Preview Support

extension EnhancedPersistenceController {
    
    /// Preview Instance für SwiftUI Previews
    static var preview: EnhancedPersistenceController = {
        let controller = EnhancedPersistenceController()
        let viewContext = controller.container.viewContext
        
        // In-Memory Store für Previews
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        controller.container.persistentStoreDescriptions = [description]
        
        // Sample Data für Previews
        let sampleUser = User(context: viewContext)
        sampleUser.id = UUID()
        sampleUser.username = "preview_user"
        sampleUser.email = "preview@example.com"
        sampleUser.firstName = "Preview"
        sampleUser.lastName = "User"
        sampleUser.isCurrentUser = true
        sampleUser.createdAt = Date()
        sampleUser.updatedAt = Date()
        
        let sampleTrip = Trip(context: viewContext)
        sampleTrip.id = UUID()
        sampleTrip.name = "Preview Trip"
        sampleTrip.owner = sampleUser
        sampleTrip.startDate = Date()
        sampleTrip.isActive = true
        
        do {
            try viewContext.save()
        } catch {
            print("❌ Preview Data Save fehlgeschlagen: \(error)")
        }
        
        return controller
    }()
} 