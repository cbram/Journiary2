//
//  CoreDataExtensions.swift
//  Journiary
//
//  Created by Assistant on 06.11.25.
//

import Foundation
import CoreData
import SwiftUI
import JourniaryAPI

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

// MARK: - Synchronizable Protocol for String-based entities

protocol StringSynchronizable {
    var serverId: String? { get set }
    var synchronizationStatus: SyncStatus { get set }
    func toGraphQLInput() -> Any
}

// MARK: - Tag Synchronizable Extension

extension Tag: StringSynchronizable {
    var serverId: String? {
        get { return self.serverID }
        set { self.serverID = newValue }
    }
    
    var synchronizationStatus: SyncStatus {
        get {
            if let statusString = self.syncStatus, let statusValue = Int16(statusString) {
                return SyncStatus(rawValue: statusValue) ?? .inSync
            }
            return .inSync
        }
        set {
            self.syncStatus = String(newValue.rawValue)
        }
    }
    
    func toGraphQLInput() -> Any {
        func dateToDateTime(_ date: Date) -> DateTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: date)
        }
        
        if let _ = self.serverId {
            // For updates, use UpdateTagInput - nur name, color, categoryId
            return UpdateTagInput(
                name: self.name.map { GraphQLNullable<String>.some($0) } ?? .none,
                color: self.color.map { GraphQLNullable<String>.some($0) } ?? .none,
                categoryId: self.category?.serverId.map { GraphQLNullable<String>.some($0) } ?? .none
            )
        } else {
            // For creates, use TagInput
            return TagInput(
                name: self.name ?? "Unnamed Tag",
                emoji: self.emoji.map { GraphQLNullable<String>.some($0) } ?? .none,
                color: self.color.map { GraphQLNullable<String>.some($0) } ?? .none,
                tagDescription: GraphQLNullable<String>.none,
                categoryId: self.category?.serverId.map { GraphQLNullable<String>.some($0) } ?? .none
            )
        }
    }
}

// MARK: - TagCategory Synchronizable Extension

extension TagCategory: StringSynchronizable {
    var serverId: String? {
        get { return self.serverID }
        set { self.serverID = newValue }
    }
    
    var synchronizationStatus: SyncStatus {
        get {
            if let statusString = self.syncStatus, let statusValue = Int16(statusString) {
                return SyncStatus(rawValue: statusValue) ?? .inSync
            }
            return .inSync
        }
        set {
            self.syncStatus = String(newValue.rawValue)
        }
    }
    
    func toGraphQLInput() -> Any {
        func dateToDateTime(_ date: Date) -> DateTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: date)
        }
        
        if let _ = self.serverId {
            // For updates, use UpdateTagCategoryInput - name, color, icon (using emoji)
            return UpdateTagCategoryInput(
                name: self.name.map { GraphQLNullable<String>.some($0) } ?? .none,
                color: self.color.map { GraphQLNullable<String>.some($0) } ?? .none,
                icon: self.emoji.map { GraphQLNullable<String>.some($0) } ?? .none
            )
        } else {
            // For creates, use TagCategoryInput - name, emoji, color
            return TagCategoryInput(
                name: self.name ?? "Unnamed Category",
                emoji: self.emoji.map { GraphQLNullable<String>.some($0) } ?? .none,
                color: self.color.map { GraphQLNullable<String>.some($0) } ?? .none
            )
        }
    }
}

// MARK: - BucketListItem Synchronizable Extension

extension BucketListItem: StringSynchronizable {
    var serverId: String? {
        get { return self.serverID }
        set { self.serverID = newValue }
    }
    
    var synchronizationStatus: SyncStatus {
        get {
            if let statusString = self.syncStatus, let statusValue = Int16(statusString) {
                return SyncStatus(rawValue: statusValue) ?? .inSync
            }
            return .inSync
        }
        set {
            self.syncStatus = String(newValue.rawValue)
        }
    }
    
    func toGraphQLInput() -> Any {
        func dateToDateTime(_ date: Date) -> DateTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: date)
        }
        
        // Note: Both create and update use the same BucketListItemInput
        return BucketListItemInput(
            name: self.name ?? "Unnamed Item",
            country: self.country.map { GraphQLNullable<String>.some($0) } ?? .none,
            region: self.region.map { GraphQLNullable<String>.some($0) } ?? .none,
            type: self.type.map { GraphQLNullable<String>.some($0) } ?? .none,
            latitude1: GraphQLNullable<Double>.some(self.latitude1),
            longitude1: GraphQLNullable<Double>.some(self.longitude1),
            latitude2: GraphQLNullable<Double>.some(self.latitude2),
            longitude2: GraphQLNullable<Double>.some(self.longitude2),
            isDone: GraphQLNullable<Bool>.some(self.isDone)
        )
    }
}

// MARK: - RoutePoint Synchronizable Extension

extension RoutePoint: StringSynchronizable {
    var serverId: String? {
        get { return self.serverID }
        set { self.serverID = newValue }
    }
    
    var synchronizationStatus: SyncStatus {
        get {
            if let statusString = self.syncStatus, let statusValue = Int16(statusString) {
                return SyncStatus(rawValue: statusValue) ?? .inSync
            }
            return .inSync
        }
        set {
            self.syncStatus = String(newValue.rawValue)
        }
    }
    
    func toGraphQLInput() -> Any {
        func dateToDateTime(_ date: Date) -> DateTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: date)
        }
        
        // For RoutePoint, we only support create for now (temporary dictionary implementation)
        return [
            "latitude": self.latitude,
            "longitude": self.longitude,
            "altitude": self.altitude,
            "timestamp": dateToDateTime(self.timestamp ?? Date()),
            "speed": self.speed,
            "tripId": self.trip?.serverId ?? ""
        ]
    }
} 