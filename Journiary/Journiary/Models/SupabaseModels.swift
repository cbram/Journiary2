//
//  SupabaseModels.swift
//  Journiary
//
//  Created by Supabase Integration on 08.06.25.
//

import Foundation

// MARK: - SupabaseTrip Model

struct SupabaseTrip: Codable, Identifiable {
    let id: UUID
    let name: String
    let tripDescription: String?
    let coverImageUrl: String?
    let travelCompanions: String?
    let visitedCountries: String?
    let startDate: Date
    let endDate: Date?
    let isActive: Bool
    let totalDistance: Double
    let gpsTrackingEnabled: Bool
    let createdAt: Date
    let updatedAt: Date
    let syncVersion: Int
    let userId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case tripDescription = "trip_description"
        case coverImageUrl = "cover_image_url"
        case travelCompanions = "travel_companions"
        case visitedCountries = "visited_countries"
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case totalDistance = "total_distance"
        case gpsTrackingEnabled = "gps_tracking_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case syncVersion = "sync_version"
        case userId = "user_id"
    }
    
    // MARK: - Initializer für neue Trips
    
    init(
        id: UUID = UUID(),
        name: String,
        tripDescription: String? = nil,
        coverImageUrl: String? = nil,
        travelCompanions: String? = nil,
        visitedCountries: String? = nil,
        startDate: Date,
        endDate: Date? = nil,
        isActive: Bool = false,
        totalDistance: Double = 0.0,
        gpsTrackingEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncVersion: Int = 1,
        userId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.tripDescription = tripDescription
        self.coverImageUrl = coverImageUrl
        self.travelCompanions = travelCompanions
        self.visitedCountries = visitedCountries
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.totalDistance = totalDistance
        self.gpsTrackingEnabled = gpsTrackingEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncVersion = syncVersion
        self.userId = userId
    }
    
    // MARK: - Conversion Methods
    
    func toInsert() -> SupabaseTripInsert {
        return SupabaseTripInsert(
            name: name,
            tripDescription: tripDescription,
            coverImageUrl: coverImageUrl,
            travelCompanions: travelCompanions,
            visitedCountries: visitedCountries,
            startDate: startDate,
            endDate: endDate,
            isActive: isActive,
            totalDistance: totalDistance,
            gpsTrackingEnabled: gpsTrackingEnabled,
            userId: userId
        )
    }
}

// MARK: - SupabaseTrip für Insert/Update

struct SupabaseTripInsert: Codable {
    let name: String
    let tripDescription: String?
    let coverImageUrl: String?
    let travelCompanions: String?
    let visitedCountries: String?
    let startDate: Date
    let endDate: Date?
    let isActive: Bool
    let totalDistance: Double
    let gpsTrackingEnabled: Bool
    let userId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case name
        case tripDescription = "trip_description"
        case coverImageUrl = "cover_image_url"
        case travelCompanions = "travel_companions"
        case visitedCountries = "visited_countries"
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case totalDistance = "total_distance"
        case gpsTrackingEnabled = "gps_tracking_enabled"
        case userId = "user_id"
    }
}

// MARK: - Sync-Status Models

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success
    case failed(String)
    
    var localizedDescription: String {
        switch self {
        case .idle:
            return "Bereit für Synchronisation"
        case .syncing:
            return "Synchronisiere..."
        case .success:
            return "Erfolgreich synchronisiert"
        case .failed(let error):
            return "Sync-Fehler: \(error)"
        }
    }
}

// MARK: - Sync-Fehler

enum SyncError: Error, LocalizedError {
    case networkUnavailable
    case invalidConfiguration
    case authenticationFailed
    case conflictResolutionFailed
    case dataCorruption
    case serverError(String)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Netzwerkverbindung nicht verfügbar"
        case .invalidConfiguration:
            return "Ungültige Supabase-Konfiguration"
        case .authenticationFailed:
            return "Authentifizierung fehlgeschlagen"
        case .conflictResolutionFailed:
            return "Konfliktauflösung fehlgeschlagen"
        case .dataCorruption:
            return "Datenintegritätsfehler"
        case .serverError(let message):
            return "Server-Fehler: \(message)"
        case .unknownError(let error):
            return "Unbekannter Fehler: \(error.localizedDescription)"
        }
    }
}

// MARK: - Sync-Event für Logging

struct SyncEvent {
    let timestamp: Date
    let operation: String
    let success: Bool
    let duration: TimeInterval?
    let error: Error?
    let itemCount: Int
    
    init(
        operation: String,
        success: Bool,
        duration: TimeInterval? = nil,
        error: Error? = nil,
        itemCount: Int = 0
    ) {
        self.timestamp = Date()
        self.operation = operation
        self.success = success
        self.duration = duration
        self.error = error
        self.itemCount = itemCount
    }
} 