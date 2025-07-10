import Foundation
import CoreData

class SyncDependencyResolver {
    enum EntityType: String, CaseIterable {
        case tagCategory = "TagCategory"
        case tag = "Tag"
        case bucketListItem = "BucketListItem"
        case trip = "Trip"
        case memory = "Memory"
        case mediaItem = "MediaItem"
        case gpxTrack = "GPXTrack"
        
        var syncOrder: Int {
            switch self {
            case .tagCategory: return 1
            case .tag: return 2
            case .bucketListItem: return 3
            case .trip: return 4
            case .memory: return 5
            case .mediaItem: return 6
            case .gpxTrack: return 7
            }
        }
        
        var dependencies: [EntityType] {
            switch self {
            case .tagCategory: return []
            case .tag: return [.tagCategory]
            case .bucketListItem: return []
            case .trip: return []
            case .memory: return [.trip]
            case .mediaItem: return [.memory]
            case .gpxTrack: return [.memory]
            }
        }
    }
    
    /// Bestimmt die korrekte Sync-Reihenfolge basierend auf Dependencies
    func resolveSyncOrder() -> [EntityType] {
        return EntityType.allCases.sorted { $0.syncOrder < $1.syncOrder }
    }
    
    /// Ermittelt die Abhängigkeiten für einen bestimmten Entity-Typ
    func getDependencies(for entityType: EntityType) -> [EntityType] {
        return entityType.dependencies
    }
    
    /// Validiert alle Abhängigkeiten für einen Entity-Typ vor der Synchronisation
    /// - Parameters:
    ///   - entityType: Der Entity-Typ, dessen Abhängigkeiten validiert werden sollen
    ///   - context: Der NSManagedObjectContext für die Validierung
    /// - Throws: SyncError.dependencyNotMet wenn eine Abhängigkeit nicht erfüllt ist
    func validateDependencies(for entityType: EntityType, in context: NSManagedObjectContext) async throws {
        print("🔍 Validiere Abhängigkeiten für \(entityType.rawValue)...")
        
        for dependency in entityType.dependencies {
            let hasUnresolvedDependencies = try await checkUnresolvedDependencies(
                type: dependency,
                context: context
            )
            
            if hasUnresolvedDependencies {
                let error = SyncError.dependencyNotMet(
                    entity: entityType.rawValue,
                    dependency: dependency.rawValue
                )
                print("❌ Abhängigkeit nicht erfüllt: \(entityType.rawValue) benötigt \(dependency.rawValue)")
                throw error
            }
        }
        
        print("✅ Alle Abhängigkeiten für \(entityType.rawValue) erfüllt")
    }
    
    /// Prüft, ob es unaufgelöste Abhängigkeiten für einen Entity-Typ gibt
    /// - Parameters:
    ///   - type: Der Entity-Typ, der geprüft werden soll
    ///   - context: Der NSManagedObjectContext für die Prüfung
    /// - Returns: true wenn es unaufgelöste Abhängigkeiten gibt, false sonst
    /// - Throws: Core Data Fehler bei Problemen mit der Datenbankabfrage
    private func checkUnresolvedDependencies(type: EntityType, context: NSManagedObjectContext) async throws -> Bool {
        return try await context.perform {
            let fetchRequest = self.createFetchRequest(for: type)
            fetchRequest.predicate = NSPredicate(format: "serverId == nil")
            fetchRequest.fetchLimit = 1
            
            let count = try context.count(for: fetchRequest)
            print("📊 Unaufgelöste \(type.rawValue) Entitäten: \(count)")
            return count > 0
        }
    }
    
    /// Erstellt einen NSFetchRequest für den angegebenen Entity-Typ
    /// - Parameter type: Der Entity-Typ, für den der FetchRequest erstellt werden soll
    /// - Returns: NSFetchRequest für den Entity-Typ
    private func createFetchRequest(for type: EntityType) -> NSFetchRequest<NSManagedObject> {
        return NSFetchRequest<NSManagedObject>(entityName: type.rawValue)
    }
} 