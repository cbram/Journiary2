//
//  CoreDataExtensions+Performance.swift
//  Journiary
//
//  Created by TravelCompanion AI on 28.12.24.
//

import Foundation
import CoreData

// MARK: - Performance Optimized Multi-User Fetch Requests

extension NSFetchRequest where ResultType == Trip {
    
    /// High-Performance User Trips Query mit Prefetching
    static func userTripsOptimized(for user: User, includeShared: Bool = true) -> NSFetchRequest<Trip> {
        let request = NSFetchRequest<Trip>(entityName: "Trip")
        
        // Predicate basierend auf includeShared
        if includeShared {
            request.predicate = NSPredicate(format: "owner == %@ OR ANY members == %@", user, user)
        } else {
            request.predicate = NSPredicate(format: "owner == %@", user)
        }
        
        // Performance Optimizations
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Trip.startDate, ascending: false),
            NSSortDescriptor(keyPath: \Trip.name, ascending: true)
        ]
        
        // Prefetch Related Objects für bessere Performance
        request.relationshipKeyPathsForPrefetching = [
            "owner", "members", "memories", "memories.creator", "memories.tags"
        ]
        
        // Fetch Batching für Memory Efficiency
        request.fetchBatchSize = 20
        
        // Performance Hints
        request.returnsObjectsAsFaults = false
        request.includesSubentities = false
        
        return request
    }
    
    /// Active User Trips mit Memory Optimization
    static func activeUserTrips(for user: User) -> NSFetchRequest<Trip> {
        let request = userTripsOptimized(for: user)
        
        // Zusätzliches Predicate für aktive Trips
        let userPredicate = request.predicate!
        let activePredicate = NSPredicate(format: "isActive == YES")
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [userPredicate, activePredicate])
        
        // Kleinere Batch Size für aktive Trips
        request.fetchBatchSize = 10
        
        return request
    }
    
    /// Recent User Trips mit Limit
    static func recentUserTrips(for user: User, limit: Int = 10) -> NSFetchRequest<Trip> {
        let request = userTripsOptimized(for: user)
        request.fetchLimit = limit
        
        // Sortierung nach Datum (neueste zuerst)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)
        ]
        
        return request
    }
    
    /// Trip Statistics Query für Dashboard
    static func tripStatistics(for user: User) -> NSFetchRequest<Trip> {
        let request = NSFetchRequest<Trip>(entityName: "Trip")
        request.predicate = NSPredicate(format: "owner == %@", user)
        
        // Nur benötigte Properties für Statistics
        request.propertiesToFetch = [
            "totalDistance", "startDate", "endDate", "isActive"
        ]
        request.resultType = .dictionaryResultType
        
        return request
    }
}

extension NSFetchRequest where ResultType == Memory {
    
    /// High-Performance User Memories mit Batch Fetching
    static func userMemoriesOptimized(for user: User, includeShared: Bool = true) -> NSFetchRequest<Memory> {
        let request = NSFetchRequest<Memory>(entityName: "Memory")
        
        if includeShared {
            request.predicate = NSPredicate(format: "creator == %@ OR trip.owner == %@ OR ANY trip.members == %@", user, user, user)
        } else {
            request.predicate = NSPredicate(format: "creator == %@", user)
        }
        
        // Performance Optimizations
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)
        ]
        
        // Prefetch für bessere Performance
        request.relationshipKeyPathsForPrefetching = [
            "creator", "trip", "trip.owner", "mediaItems", "tags", "tags.creator"
        ]
        
        request.fetchBatchSize = 25
        request.returnsObjectsAsFaults = false
        
        return request
    }
    
    /// Memories für specific Trip mit User Access Check
    static func memoriesForTrip(_ trip: Trip, user: User) -> NSFetchRequest<Memory> {
        let request = NSFetchRequest<Memory>(entityName: "Memory")
        
        // Prüfe User Access zum Trip
        let tripAccessPredicate = NSPredicate(format: "trip.owner == %@ OR ANY trip.members == %@", user, user)
        let tripPredicate = NSPredicate(format: "trip == %@", trip)
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [tripPredicate, tripAccessPredicate])
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)
        ]
        
        // Spezifisches Prefetching für Trip Memories
        request.relationshipKeyPathsForPrefetching = [
            "creator", "mediaItems", "tags"
        ]
        
        request.fetchBatchSize = 15
        
        return request
    }
    
    /// Recent Memories für Dashboard
    static func recentMemories(for user: User, limit: Int = 20) -> NSFetchRequest<Memory> {
        let request = userMemoriesOptimized(for: user)
        request.fetchLimit = limit
        
        // Nur neueste
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)
        ]
        
        return request
    }
    
    /// Memory Search mit Full-Text Search Vorbereitung
    static func searchMemories(for user: User, searchText: String) -> NSFetchRequest<Memory> {
        let request = userMemoriesOptimized(for: user)
        
        // Search Predicate
        let searchPredicate = NSPredicate(format: "title CONTAINS[cd] %@ OR text CONTAINS[cd] %@", searchText, searchText)
        let userPredicate = request.predicate!
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [userPredicate, searchPredicate])
        
        // Relevance Sorting (neueste zuerst)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)
        ]
        
        return request
    }
}

extension NSFetchRequest where ResultType == Tag {
    
    /// User Tags mit Usage-Based Sorting
    static func userTagsOptimized(for user: User) -> NSFetchRequest<Tag> {
        let request = NSFetchRequest<Tag>(entityName: "Tag")
        request.predicate = NSPredicate(format: "(creator == %@ OR isSystemTag == YES) AND isArchived == NO", user)
        
        // Sortierung nach Usage und Alphabet
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Tag.usageCount, ascending: false),
            NSSortDescriptor(keyPath: \Tag.name, ascending: true)
        ]
        
        // Prefetch Category Information
        request.relationshipKeyPathsForPrefetching = ["category", "category.creator"]
        
        request.fetchBatchSize = 50
        request.returnsObjectsAsFaults = false
        
        return request
    }
    
    /// Popular Tags für Suggestions
    static func popularTags(for user: User, limit: Int = 10) -> NSFetchRequest<Tag> {
        let request = userTagsOptimized(for: user)
        request.fetchLimit = limit
        
        // Nur Tags mit Usage > 0
        let userPredicate = request.predicate!
        let usagePredicate = NSPredicate(format: "usageCount > 0")
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [userPredicate, usagePredicate])
        
        // Sortierung nur nach Usage
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Tag.usageCount, ascending: false)
        ]
        
        return request
    }
    
    /// Tag Statistics für Analytics
    static func tagStatistics(for user: User) -> NSFetchRequest<Tag> {
        let request = NSFetchRequest<Tag>(entityName: "Tag")
        request.predicate = NSPredicate(format: "creator == %@", user)
        
        // Nur Statistics Properties
        request.propertiesToFetch = [
            "name", "usageCount", "createdAt", "lastUsedAt"
        ]
        request.resultType = .dictionaryResultType
        
        return request
    }
}

extension NSFetchRequest where ResultType == MediaItem {
    
    /// User Media Items mit Size-Based Optimization
    static func userMediaItemsOptimized(for user: User) -> NSFetchRequest<MediaItem> {
        let request = NSFetchRequest<MediaItem>(entityName: "MediaItem")
        request.predicate = NSPredicate(format: "uploader == %@ OR memory.creator == %@ OR memory.trip.owner == %@", user, user, user)
        
        // Sortierung nach Upload Date
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \MediaItem.timestamp, ascending: false)
        ]
        
        // Media-spezifisches Prefetching
        request.relationshipKeyPathsForPrefetching = [
            "uploader", "memory", "memory.trip"
        ]
        
        // Größere Batch Size für Media
        request.fetchBatchSize = 30
        
        return request
    }
    
    /// Large Media Items für Cleanup
    static func largeMediaItems(for user: User, minimumSizeMB: Double = 10.0) -> NSFetchRequest<MediaItem> {
        let request = userMediaItemsOptimized(for: user)
        
        let minimumBytes = Int64(minimumSizeMB * 1024 * 1024)
        let sizePredicate = NSPredicate(format: "filesize >= %lld", minimumBytes)
        let userPredicate = request.predicate!
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [userPredicate, sizePredicate])
        
        // Sortierung nach Größe (größte zuerst)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \MediaItem.filesize, ascending: false)
        ]
        
        return request
    }
}

extension NSFetchRequest where ResultType == BucketListItem {
    
    /// User Bucket List mit Completion Status
    static func userBucketListOptimized(for user: User) -> NSFetchRequest<BucketListItem> {
        let request = NSFetchRequest<BucketListItem>(entityName: "BucketListItem")
        request.predicate = NSPredicate(format: "creator == %@", user)
        
        // Sortierung: Unfertige zuerst, dann nach Name
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \BucketListItem.isDone, ascending: true),
            NSSortDescriptor(keyPath: \BucketListItem.name, ascending: true)
        ]
        
        // Prefetch Related Memories
        request.relationshipKeyPathsForPrefetching = ["memories", "memories.creator"]
        
        request.fetchBatchSize = 25
        
        return request
    }
    
    /// Completed Bucket List Items für Achievement View
    static func completedBucketListItems(for user: User) -> NSFetchRequest<BucketListItem> {
        let request = userBucketListOptimized(for: user)
        
        // Nur completed Items
        let userPredicate = request.predicate!
        let completedPredicate = NSPredicate(format: "isDone == YES")
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [userPredicate, completedPredicate])
        
        // Sortierung nach Completion Date
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \BucketListItem.completedAt, ascending: false)
        ]
        
        return request
    }
}

// MARK: - Batch Operations für Performance

extension NSManagedObjectContext {
    
    /// Batch Count für User-spezifische Queries
    func batchCount<T: NSManagedObject>(for fetchRequest: NSFetchRequest<T>) async throws -> Int {
        return try await self.perform {
            return try self.count(for: fetchRequest)
        }
    }
    
    /// Batch Fetch mit Memory Management
    func batchFetch<T: NSManagedObject>(
        _ fetchRequest: NSFetchRequest<T>,
        batchSize: Int = 100
    ) async throws -> [T] {
        return try await self.perform {
            var allResults: [T] = []
            var fetchOffset = 0
            
            repeat {
                fetchRequest.fetchOffset = fetchOffset
                fetchRequest.fetchLimit = batchSize
                
                let batchResults = try self.fetch(fetchRequest)
                allResults.append(contentsOf: batchResults)
                
                fetchOffset += batchSize
                
                // Memory Management zwischen Batches
                if fetchOffset % (batchSize * 5) == 0 {
                    self.refreshAllObjects()
                }
                
            } while fetchRequest.fetchLimit == batchSize && allResults.count == fetchOffset
            
            return allResults
        }
    }
}

// MARK: - Performance Monitoring

class CoreDataPerformanceMonitor {
    
    static let shared = CoreDataPerformanceMonitor()
    
    private var queryTimes: [String: TimeInterval] = [:]
    private let queue = DispatchQueue(label: "CoreDataPerformanceMonitor", qos: .utility)
    
    private init() {}
    
    /// Misst Query Performance
    func measureQuery<T>(_ queryName: String, operation: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = try operation()
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        queue.async {
            self.queryTimes[queryName] = timeElapsed
            
            if timeElapsed > 0.5 { // Log slow queries
                print("⚠️ Slow Query: \(queryName) took \(String(format: "%.3f", timeElapsed))s")
            }
        }
        
        return result
    }
    
    /// Gibt Performance Statistics zurück
    func getPerformanceStatistics() -> [String: TimeInterval] {
        return queue.sync {
            return queryTimes
        }
    }
    
    /// Reset Statistics
    func resetStatistics() {
        queue.async {
            self.queryTimes.removeAll()
        }
    }
}

// MARK: - Performance Helper Extensions

extension NSFetchRequest {
    
    /// Optimiert FetchRequest für Production
    func optimizeForProduction() {
        self.returnsObjectsAsFaults = false
        self.includesSubentities = false
        
        if self.fetchBatchSize == 0 {
            self.fetchBatchSize = 20 // Standard Batch Size
        }
        
        // Include Property Values für bessere Performance
        self.includesPropertyValues = true
        self.includesPendingChanges = true
    }
    
    /// Fügt Standard Sort Descriptors hinzu falls keine vorhanden
    func addDefaultSortDescriptors() {
        if self.sortDescriptors?.isEmpty ?? true {
            // Fallback Sort Descriptor basierend auf Entity Name
            switch self.entityName {
            case "Trip":
                self.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
            case "Memory":
                self.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            case "Tag":
                self.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            case "BucketListItem":
                self.sortDescriptors = [NSSortDescriptor(key: "isDone", ascending: true)]
            default:
                self.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            }
        }
    }
} 