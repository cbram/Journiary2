import Foundation

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
    
    func resolveSyncOrder() -> [EntityType] {
        return EntityType.allCases.sorted { $0.syncOrder < $1.syncOrder }
    }
    
    func getDependencies(for entityType: EntityType) -> [EntityType] {
        return entityType.dependencies
    }
} 