//
//  CoreDataExtensions.swift
//  Journiary
//
//  Created by Assistant on 06.11.25.
//

import Foundation
import CoreData
import SwiftUI

// MARK: - RoutePoint Extensions
// Note: RoutePoint already conforms to Identifiable via Core Data

// MARK: - Memory Extensions

extension Memory {
    var tagArray: [Tag] {
        return (tags?.allObjects as? [Tag])?.sorted { $0.name ?? "" < $1.name ?? "" } ?? []
    }
    
    func hasTag(_ tag: Tag) -> Bool {
        return tags?.contains(tag) ?? false
    }
    
    // Core Data generiert addToTags und removeFromTags automatisch
    
    // MARK: - BucketListItem Relationship
    
    /// Verknüpft diese Erinnerung mit einem Bucket List Item
    func linkToBucketListItem(_ item: BucketListItem) {
        self.bucketListItem = item
    }
    
    /// Entfernt die Verknüpfung zu einem Bucket List Item
    func unlinkFromBucketListItem() {
        self.bucketListItem = nil
    }
    
    /// Prüft ob diese Erinnerung mit einem Bucket List Item verknüpft ist
    var isLinkedToBucketList: Bool {
        return bucketListItem != nil
    }
    
    // MARK: - Weather Data
    
    /// Speichert Wetterdaten als JSON String
    func setWeatherData(_ weatherData: WeatherData) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(WeatherInfo(
            temperature: weatherData.temperature,
            condition: weatherData.weatherCondition.rawValue,
            locationName: weatherData.locationName
        )) {
            self.weatherJSON = String(data: encoded, encoding: .utf8)
        }
    }
    
    /// Lädt Wetterdaten aus JSON String
    var weatherData: WeatherData? {
        guard let weatherJSON = weatherJSON,
              let data = weatherJSON.data(using: .utf8) else { return nil }
        
        let decoder = JSONDecoder()
        if let weatherInfo = try? decoder.decode(WeatherInfo.self, from: data) {
            return WeatherData(
                temperature: weatherInfo.temperature,
                weatherCondition: WeatherCondition(rawValue: weatherInfo.condition) ?? .unknown,
                locationName: weatherInfo.locationName ?? self.locationName ?? "Unbekannt"
            )
        }
        return nil
    }
    
    /// Prüft ob Wetterdaten vorhanden sind
    var hasWeatherData: Bool {
        return weatherData != nil
    }
    
    // MARK: - GPX Track Integration
    
    /// Prüft ob diese Memory einen GPX-Track hat
    var hasGPXTrack: Bool {
        return gpxTrack != nil
    }
    
    /// Fügt einen GPX-Track zu dieser Memory hinzu
    func attachGPXTrack(_ track: GPXTrack) {
        self.gpxTrack = track
        track.memory = self
    }
    
    /// Entfernt den GPX-Track von dieser Memory
    func removeGPXTrack() {
        if let track = self.gpxTrack {
            track.memory = nil
            self.gpxTrack = nil
        }
    }
    
    /// Generiert eine kurze Beschreibung des GPX-Tracks
    var gpxTrackSummary: String? {
        guard let track = gpxTrack else { return nil }
        
        let distanceKm = track.totalDistance / 1000.0
        let durationFormatted = formatTrackDuration(track.totalDuration)
        
        if track.totalDuration > 0 {
            return "\(String(format: "%.1f", distanceKm)) km • \(durationFormatted)"
        } else {
            return "\(String(format: "%.1f", distanceKm)) km • 📍 \(track.totalPoints) Punkte"
        }
    }
    
    private func formatTrackDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
}

// MARK: - Weather Data Structures

private struct WeatherInfo: Codable {
    let temperature: Double
    let condition: String
    let locationName: String?
}

// MARK: - BucketListItem Extensions

extension BucketListItem {
    /// Sortierte Array aller verknüpften Erinnerungen
    var sortedMemories: [Memory] {
        let memoryArray = memories?.allObjects as? [Memory] ?? []
        return memoryArray.sorted { 
            ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) 
        }
    }
    
    /// Anzahl der verknüpften Erinnerungen
    var memoryCount: Int {
        return memories?.count ?? 0
    }
    
    /// Prüft ob dieses POI Erinnerungen hat
    var hasMemories: Bool {
        return memoryCount > 0
    }
    
    /// Neueste Erinnerung für dieses POI
    var latestMemory: Memory? {
        return sortedMemories.first
    }
    
    /// Verknüpft eine Erinnerung mit diesem POI
    func addMemory(_ memory: Memory) {
        memory.linkToBucketListItem(self)
    }
    
    /// Entfernt eine Erinnerung von diesem POI
    func removeMemory(_ memory: Memory) {
        memory.unlinkFromBucketListItem()
    }
}

// MARK: - Tag Extensions

extension Tag {
    var colorValue: Color {
        return TagColor.color(from: color ?? TagColor.defaultColor)
    }
    
    var displayText: String {
        if let emoji = emoji, !emoji.isEmpty {
            return "\(emoji) \(displayName ?? name ?? "")"
        }
        return displayName ?? name ?? ""
    }
}

// MARK: - TagCategory Extensions

extension TagCategory {
    var colorValue: Color {
        return TagColor.color(from: color ?? TagColor.defaultColor)
    }
}

// MARK: - Tag Colors

struct TagColor {
    static let defaultColor = "blue"
    static let systemColor = "gray"
    
    static let availableColors = [
        "blue", "green", "red", "orange", "purple", "pink", 
        "yellow", "indigo", "teal", "cyan", "mint", "brown"
    ]
    
    static func color(from string: String) -> Color {
        switch string {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "indigo": return .indigo
        case "teal": return .teal
        case "cyan": return .cyan
        case "mint": return .mint
        case "brown": return .brown
        default: return .blue
        }
    }
}

// MARK: - Multi-User Fetch Request Helpers (Fixed Generic Issues)

/// Trip Fetch Request Helpers
struct TripFetchRequestHelpers {
    
    /// Fetch Trips für einen bestimmten User (Owner)
    static func userTrips(for user: User) -> NSFetchRequest<Trip> {
        let request = NSFetchRequest<Trip>(entityName: "Trip")
        request.predicate = NSPredicate(format: "owner == %@", user)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Trip.startDate, ascending: false),
            NSSortDescriptor(keyPath: \Trip.name, ascending: true)
        ]
        return request
    }
    
    /// Fetch Trips wo User Owner oder Member ist
    static func accessibleTrips(for user: User) -> NSFetchRequest<Trip> {
        let request = NSFetchRequest<Trip>(entityName: "Trip")
        request.predicate = NSPredicate(format: "owner == %@ OR ANY members == %@", user, user)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Trip.startDate, ascending: false),
            NSSortDescriptor(keyPath: \Trip.name, ascending: true)
        ]
        return request
    }
    
    /// Fetch Shared Trips (User ist Member, aber nicht Owner)
    static func sharedTrips(for user: User) -> NSFetchRequest<Trip> {
        let request = NSFetchRequest<Trip>(entityName: "Trip")
        request.predicate = NSPredicate(format: "owner != %@ AND ANY members == %@", user, user)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Trip.startDate, ascending: false),
            NSSortDescriptor(keyPath: \Trip.name, ascending: true)
        ]
        return request
    }
    
    /// 🔍 DEBUGGING: Fetch Trips OHNE Owner (sollten nicht existieren!)
    static func orphanedTrips() -> NSFetchRequest<Trip> {
        let request = NSFetchRequest<Trip>(entityName: "Trip")
        request.predicate = NSPredicate(format: "owner == nil")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Trip.startDate, ascending: false),
            NSSortDescriptor(keyPath: \Trip.name, ascending: true)
        ]
        return request
    }
    
    /// 🔧 Anzahl Trips ohne Owner ermitteln
    static func countOrphanedTrips(in context: NSManagedObjectContext) -> Int {
        let request = orphanedTrips()
        return (try? context.count(for: request)) ?? 0
    }
}

/// Memory Fetch Request Helpers
struct MemoryFetchRequestHelpers {
    
    /// Fetch Memories für einen bestimmten User (Creator)
    static func userMemories(for user: User) -> NSFetchRequest<Memory> {
        let request = NSFetchRequest<Memory>(entityName: "Memory")
        request.predicate = NSPredicate(format: "creator == %@", user)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)
        ]
        return request
    }
    
    /// Fetch Memories in accessible Trips für User
    static func accessibleMemories(for user: User) -> NSFetchRequest<Memory> {
        let request = NSFetchRequest<Memory>(entityName: "Memory")
        request.predicate = NSPredicate(format: "trip.owner == %@ OR ANY trip.members == %@", user, user)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)
        ]
        return request
    }
    
    /// Fetch Memories für bestimmten Trip (mit User Access Check)
    static func memories(for trip: Trip, user: User) -> NSFetchRequest<Memory> {
        let request = NSFetchRequest<Memory>(entityName: "Memory")
        request.predicate = NSPredicate(format: "trip == %@ AND (trip.owner == %@ OR ANY trip.members == %@)", trip, user, user)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)
        ]
        return request
    }
}

/// Tag Fetch Request Helpers
struct TagFetchRequestHelpers {
    
    /// Fetch Tags für einen bestimmten User
    static func userTags(for user: User) -> NSFetchRequest<Tag> {
        let request = NSFetchRequest<Tag>(entityName: "Tag")
        request.predicate = NSPredicate(format: "creator == %@ OR isSystemTag == YES", user)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Tag.usageCount, ascending: false),
            NSSortDescriptor(keyPath: \Tag.name, ascending: true)
        ]
        return request
    }
    
    /// Fetch System Tags (für alle User verfügbar)
    static func systemTags() -> NSFetchRequest<Tag> {
        let request = NSFetchRequest<Tag>(entityName: "Tag")
        request.predicate = NSPredicate(format: "isSystemTag == YES")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Tag.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Tag.name, ascending: true)
        ]
        return request
    }
}

/// TagCategory Fetch Request Helpers
struct TagCategoryFetchRequestHelpers {
    
    /// Fetch Tag Categories für einen bestimmten User
    static func userTagCategories(for user: User) -> NSFetchRequest<TagCategory> {
        let request = NSFetchRequest<TagCategory>(entityName: "TagCategory")
        request.predicate = NSPredicate(format: "creator == %@ OR isSystemCategory == YES", user)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TagCategory.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \TagCategory.name, ascending: true)
        ]
        return request
    }
}

/// BucketListItem Fetch Request Helpers
struct BucketListItemFetchRequestHelpers {
    
    /// Fetch Bucket List Items für einen bestimmten User
    static func userBucketListItems(for user: User) -> NSFetchRequest<BucketListItem> {
        let request = NSFetchRequest<BucketListItem>(entityName: "BucketListItem")
        request.predicate = NSPredicate(format: "creator == %@", user)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \BucketListItem.isDone, ascending: true),
            NSSortDescriptor(keyPath: \BucketListItem.name, ascending: true)
        ]
        return request
    }
    
    /// Fetch Completed Bucket List Items für einen User
    /// Note: Erweiterte Performance-Version ist in CoreDataExtensions+Performance.swift verfügbar
    static func completedBucketListItemsBasic(for user: User) -> NSFetchRequest<BucketListItem> {
        let request = NSFetchRequest<BucketListItem>(entityName: "BucketListItem")
        request.predicate = NSPredicate(format: "creator == %@ AND isDone == YES", user)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \BucketListItem.completedAt, ascending: false)
        ]
        return request
    }
}

/// User Fetch Request Helpers
struct UserFetchRequestHelpers {
    
    /// Fetch Current User
    static func currentUser() -> NSFetchRequest<User> {
        let request = NSFetchRequest<User>(entityName: "User")
        request.predicate = NSPredicate(format: "isCurrentUser == YES")
        request.fetchLimit = 1
        return request
    }
    
    /// Fetch User by Backend ID
    static func user(withBackendId backendId: String) -> NSFetchRequest<User> {
        let request = NSFetchRequest<User>(entityName: "User")
        request.predicate = NSPredicate(format: "backendUserId == %@", backendId)
        request.fetchLimit = 1
        return request
    }
    
    /// Fetch User by Email
    static func user(withEmail email: String) -> NSFetchRequest<User> {
        let request = NSFetchRequest<User>(entityName: "User")
        request.predicate = NSPredicate(format: "email == %@", email)
        request.fetchLimit = 1
        return request
    }
}

// MARK: - Multi-User Predicate Helpers

struct UserPredicates {
    
    /// User ist Owner oder Member von Trip
    static func hasAccess(to trip: Trip, user: User) -> NSPredicate {
        return NSPredicate(format: "owner == %@ OR ANY members == %@", user, user)
    }
    
    /// Content gehört User oder ist in shared Trip
    static func isAccessible(by user: User) -> NSPredicate {
        return NSPredicate(format: "creator == %@ OR trip.owner == %@ OR ANY trip.members == %@", user, user, user)
    }
    
    /// User-spezifische oder System-Tags
    static func isAvailable(for user: User) -> NSPredicate {
        return NSPredicate(format: "creator == %@ OR isSystemTag == YES", user)
    }
    
    /// Kombinierte Predicate für komplexe Multi-User Queries
    static func userContent(for user: User, includeShared: Bool = true) -> NSPredicate {
        if includeShared {
            return NSPredicate(format: "creator == %@ OR trip.owner == %@ OR ANY trip.members == %@", user, user, user)
        } else {
            return NSPredicate(format: "creator == %@", user)
        }
    }
}

// MARK: - User Context Management

import Combine

@MainActor
class UserContextManager: ObservableObject {
    
    static let shared = UserContextManager()
    
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let context = EnhancedPersistenceController.shared.container.viewContext
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadCurrentUser()
        
        // Observe AuthManager changes
        AuthManager.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.loadCurrentUser()
                } else {
                    self?.currentUser = nil
                }
            }
            .store(in: &cancellables)
    }
    
    /// Lädt den aktuellen User aus Core Data
    func loadCurrentUser() {
        isLoading = true
        errorMessage = nil
        
        do {
            let users = try context.fetch(UserFetchRequestHelpers.currentUser())
            
            if let user = users.first {
                currentUser = user
                print("✅ Current User geladen: \(user.displayName)")
            } else {
                // Erstelle Default User falls keiner existiert
                createDefaultUser()
            }
        } catch {
            errorMessage = "Fehler beim Laden des Users: \(error.localizedDescription)"
            print("❌ User laden fehlgeschlagen: \(error)")
        }
        
        isLoading = false
    }
    
    /// Erstellt einen Default User für Migration von Legacy-Daten
    private func createDefaultUser() {
        let user = User(context: context)
        user.id = UUID()
        user.email = "legacy@user.local"
        user.username = "legacy_user"
        user.firstName = "Legacy"
        user.lastName = "User"
        user.isCurrentUser = true
        user.createdAt = Date()
        user.updatedAt = Date()
        
        do {
            try context.save()
            currentUser = user
            print("✅ Default User erstellt für Migration")
        } catch {
            errorMessage = "Fehler beim Erstellen des Default Users: \(error.localizedDescription)"
            print("❌ Default User erstellen fehlgeschlagen: \(error)")
        }
    }
    
    /// Setzt einen User als aktuellen User
    func setCurrentUser(_ user: User) {
        // Alle anderen User als nicht-aktuell markieren
        let allUsersRequest = NSFetchRequest<User>(entityName: "User")
        
        do {
            let allUsers = try context.fetch(allUsersRequest)
            for otherUser in allUsers {
                otherUser.isCurrentUser = false
            }
            
            // Neuen User als aktuell setzen
            user.isCurrentUser = true
            user.updatedAt = Date()
            
            try context.save()
            currentUser = user
            
            print("✅ Current User gewechselt zu: \(user.displayName)")
        } catch {
            errorMessage = "Fehler beim Setzen des Current Users: \(error.localizedDescription)"
            print("❌ Current User setzen fehlgeschlagen: \(error)")
        }
    }
    
    /// Migriert Legacy-Daten zu aktuellem User
    func migrateLegacyData() {
        guard let user = currentUser else {
            print("❌ Kein Current User für Migration verfügbar")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Migriere Trips ohne Owner
                let orphanTripsRequest = NSFetchRequest<Trip>(entityName: "Trip")
                orphanTripsRequest.predicate = NSPredicate(format: "owner == nil")
                let orphanTrips = try context.fetch(orphanTripsRequest)
                
                for trip in orphanTrips {
                    trip.owner = user
                }
                
                // Migriere Memories ohne Creator
                let orphanMemoriesRequest = NSFetchRequest<Memory>(entityName: "Memory")
                orphanMemoriesRequest.predicate = NSPredicate(format: "creator == nil")
                let orphanMemories = try context.fetch(orphanMemoriesRequest)
                
                for memory in orphanMemories {
                    memory.creator = user
                }
                
                // Migriere Tags ohne Creator (außer System Tags)
                let orphanTagsRequest = NSFetchRequest<Tag>(entityName: "Tag")
                orphanTagsRequest.predicate = NSPredicate(format: "creator == nil AND isSystemTag == NO")
                let orphanTags = try context.fetch(orphanTagsRequest)
                
                for tag in orphanTags {
                    tag.creator = user
                }
                
                // Migriere andere Entitäten...
                let orphanBucketListRequest = NSFetchRequest<BucketListItem>(entityName: "BucketListItem")
                orphanBucketListRequest.predicate = NSPredicate(format: "creator == nil")
                let orphanBucketListItems = try context.fetch(orphanBucketListRequest)
                
                for item in orphanBucketListItems {
                    item.creator = user
                }
                
                try context.save()
                
                await MainActor.run {
                    print("✅ Legacy-Daten erfolgreich migriert: \(orphanTrips.count) Trips, \(orphanMemories.count) Memories, \(orphanTags.count) Tags, \(orphanBucketListItems.count) Bucket List Items")
                    isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Migration fehlgeschlagen: \(error.localizedDescription)"
                    isLoading = false
                    print("❌ Legacy-Daten Migration fehlgeschlagen: \(error)")
                }
            }
        }
    }
}

// User Extensions sind bereits in User+Extensions.swift definiert

// MARK: - CloudKit Sharing Extensions

extension Trip {
    /// CloudKit Share URL für geteilte Trips
    var cloudKitShareURL: String? {
        get {
            return value(forKey: "cloudKitShareURL") as? String
        }
        set {
            setValue(newValue, forKey: "cloudKitShareURL")
        }
    }
    
    /// Indikator ob Trip via CloudKit geteilt ist
    var isSharedViaCloudKit: Bool {
        get {
            return value(forKey: "isSharedViaCloudKit") as? Bool ?? false
        }
        set {
            setValue(newValue, forKey: "isSharedViaCloudKit")
        }
    }
    
    /// Prüft ob Trip sowohl über CloudKit als auch Backend geteilt ist
    var isHybridShared: Bool {
        return isSharedViaCloudKit && (members?.count ?? 0) > 0
    }
    
    /// Sharing Status Display Text
    var sharingStatusText: String {
        if isHybridShared {
            return "CloudKit + Backend"
        } else if isSharedViaCloudKit {
            return "CloudKit"
        } else if (members?.count ?? 0) > 0 {
            return "Backend"
        } else {
            return "Nicht geteilt"
        }
    }
}

extension Memory {
    /// CloudKit Share URL für geteilte Memories
    var cloudKitShareURL: String? {
        get {
            return value(forKey: "cloudKitShareURL") as? String
        }
        set {
            setValue(newValue, forKey: "cloudKitShareURL")
        }
    }
    
    /// Indikator ob Memory via CloudKit geteilt ist
    var isSharedViaCloudKit: Bool {
        get {
            return value(forKey: "isSharedViaCloudKit") as? Bool ?? false
        }
        set {
            setValue(newValue, forKey: "isSharedViaCloudKit")
        }
    }
}