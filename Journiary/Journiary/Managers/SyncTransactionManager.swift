import Foundation
import CoreData

/// Transaction-Manager für atomare Core Data Operationen während der Synchronisation
/// Gewährleistet Datenintegrität und ermöglicht sichere Rollback-Mechanismen
class SyncTransactionManager {
    
    // MARK: - Properties
    
    private let persistenceController = PersistenceController.shared
    
    // MARK: - Public Methods
    
    /// Führt eine atomare Transaktion aus ohne explizite Rollback-Behandlung
    /// - Parameter operation: Die auszuführende Operation mit dem bereitgestellten Context
    /// - Returns: Das Ergebnis der Operation
    /// - Throws: Fehler aus der Operation oder beim Speichern
    func performTransaction<T>(
        operation: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = persistenceController.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return try await context.perform {
            let result = try operation(context)
            
            if context.hasChanges {
                try context.save()
            }
            
            return result
        }
    }
    
    /// Führt eine atomare Transaktion mit expliziter Rollback-Behandlung aus
    /// - Parameter operation: Die auszuführende Operation mit dem bereitgestellten Context
    /// - Returns: Das Ergebnis der Operation
    /// - Throws: Fehler aus der Operation oder beim Speichern
    func performTransactionWithRollback<T>(
        operation: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = persistenceController.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return try await context.perform {
            do {
                let result = try operation(context)
                
                if context.hasChanges {
                    try context.save()
                }
                
                return result
            } catch {
                // Rollback bei Fehler
                context.rollback()
                throw error
            }
        }
    }
} 