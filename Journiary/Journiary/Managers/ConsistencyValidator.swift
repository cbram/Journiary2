import Foundation
import CoreData

/// Konsistenz-Validator für die Überprüfung der Datenintegrität
/// Prüft Beziehungen zwischen Entitäten und erkennt Inkonsistenzen
class ConsistencyValidator {
    
    // MARK: - Public Methods
    
    /// Führt eine grundlegende Konsistenzprüfung durch
    /// - Parameter context: Der Core Data Context für die Validierung
    /// - Returns: Array von gefundenen Problemen als String-Beschreibungen
    /// - Throws: Fehler bei Core Data Operationen
    func validateBasicConsistency(context: NSManagedObjectContext) async throws -> [String] {
        var issues: [String] = []
        
        // Prüfe Memory-Trip-Beziehungen
        let memoryIssues = try await validateMemoryTripRelationships(context: context)
        issues.append(contentsOf: memoryIssues)
        
        // Prüfe MediaItem-Memory-Beziehungen
        let mediaIssues = try await validateMediaItemMemoryRelationships(context: context)
        issues.append(contentsOf: mediaIssues)
        
        return issues
    }
    
    // MARK: - Private Methods
    
    /// Validiert die Beziehungen zwischen Memory und Trip Entitäten
    /// - Parameter context: Der Core Data Context
    /// - Returns: Array von gefundenen Problemen
    /// - Throws: Fehler bei Core Data Operationen
    private func validateMemoryTripRelationships(context: NSManagedObjectContext) async throws -> [String] {
        return try await context.perform {
            var issues: [String] = []
            
            let memoryRequest = Memory.fetchRequest()
            memoryRequest.predicate = NSPredicate(format: "trip == nil")
            
            let memoriesWithoutTrip = try context.fetch(memoryRequest)
            for memory in memoriesWithoutTrip {
                issues.append("Memory ohne Trip: \(memory.serverId ?? "unknown")")
            }
            
            return issues
        }
    }
    
    /// Validiert die Beziehungen zwischen MediaItem und Memory Entitäten
    /// - Parameter context: Der Core Data Context
    /// - Returns: Array von gefundenen Problemen
    /// - Throws: Fehler bei Core Data Operationen
    private func validateMediaItemMemoryRelationships(context: NSManagedObjectContext) async throws -> [String] {
        return try await context.perform {
            var issues: [String] = []
            
            let mediaRequest = MediaItem.fetchRequest()
            mediaRequest.predicate = NSPredicate(format: "memory == nil")
            
            let mediaWithoutMemory = try context.fetch(mediaRequest)
            for media in mediaWithoutMemory {
                issues.append("MediaItem ohne Memory: \(media.serverId ?? "unknown")")
            }
            
            return issues
        }
    }
} 