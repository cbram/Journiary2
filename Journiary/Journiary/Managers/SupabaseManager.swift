//
//  SupabaseManager.swift
//  Journiary
//
//  Created by Supabase Integration on 08.06.25.
//

import Foundation
import Supabase

class SupabaseManager: ObservableObject {
    
    static let shared = SupabaseManager()
    
    private let supabase: SupabaseClient
    
    // MARK: - Published Properties
    
    @Published var isConnected = false
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var connectionStatus: ConnectionStatus = .unknown
    
    // MARK: - Initialization
    
    init() {
        guard SupabaseConfig.validateConfiguration() else {
            fatalError("Supabase-Konfiguration ungültig")
        }
        
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.supabaseURL)!,
            supabaseKey: SupabaseConfig.supabaseAnonKey
        )
        
        Task {
            await checkConnection()
        }
    }
    
    // MARK: - Connection Management
    
    func checkConnection() async {
        do {
            let _ = try await supabase.from("trips").select("id").limit(1).execute()
            await MainActor.run {
                self.isConnected = true
                self.connectionStatus = .connected
            }
        } catch {
            await MainActor.run {
                self.isConnected = false
                self.connectionStatus = .disconnected
            }
        }
    }
    
    // MARK: - Trip Management
    
    func createTrip(_ trip: SupabaseTripInsert) async throws -> SupabaseTrip {
        guard isConnected else {
            throw SyncError.networkUnavailable
        }
        
        do {
            let createdTrip: SupabaseTrip = try await supabase
                .from("trips")
                .insert(trip)
                .select()
                .single()
                .execute()
                .value
            
            return createdTrip
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }
    
    func updateTrip(_ trip: SupabaseTrip) async throws -> SupabaseTrip {
        guard isConnected else {
            throw SyncError.networkUnavailable
        }
        
        let tripId = trip.id
        
        do {
            let updatedTrip: SupabaseTrip = try await supabase
                .from("trips")
                .update(trip)
                .eq("id", value: tripId)
                .select()
                .single()
                .execute()
                .value
            
            return updatedTrip
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }
    
    func fetchTrip(id: UUID) async throws -> SupabaseTrip {
        guard isConnected else {
            throw SyncError.networkUnavailable
        }
        
        do {
            let trip: SupabaseTrip = try await supabase
                .from("trips")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
            
            return trip
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }
    
    func fetchAllTrips() async throws -> [SupabaseTrip] {
        guard isConnected else {
            throw SyncError.networkUnavailable
        }
        
        do {
            let trips: [SupabaseTrip] = try await supabase
                .from("trips")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            return trips
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }
    
    func deleteTrip(id: UUID) async throws {
        guard isConnected else {
            throw SyncError.networkUnavailable
        }
        
        do {
            try await supabase
                .from("trips")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }
    
    // MARK: - Sync Methods
    
    func fetchTripsSince(_ date: Date) async throws -> [SupabaseTrip] {
        guard isConnected else {
            throw SyncError.networkUnavailable
        }
        
        do {
            let trips: [SupabaseTrip] = try await supabase
                .from("trips")
                .select()
                .gte("updated_at", value: date.toISOString())
                .order("updated_at", ascending: false)
                .execute()
                .value
            
            return trips
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }
    
    func fetchTripMetadata(since date: Date) async throws -> [TripSyncMetadata] {
        guard isConnected else {
            throw SyncError.networkUnavailable
        }
        
        do {
            let metadata: [TripSyncMetadata] = try await supabase
                .from("trips")
                .select("id, sync_version, updated_at")
                .gte("updated_at", value: date.toISOString())
                .execute()
                .value
            
            return metadata
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }
    
    func tripExists(id: UUID) async throws -> Bool {
        guard isConnected else {
            throw SyncError.networkUnavailable
        }
        
        do {
            let trips: [SupabaseTrip] = try await supabase
                .from("trips")
                .select("id")
                .eq("id", value: id)
                .execute()
                .value
            
            return !trips.isEmpty
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }
    
    func fetchTripSyncMetadata(id: UUID) async throws -> TripSyncMetadata {
        guard isConnected else {
            throw SyncError.networkUnavailable
        }
        
        do {
            let metadata: TripSyncMetadata = try await supabase
                .from("trips")
                .select("id, sync_version, updated_at")
                .eq("id", value: id)
                .single()
                .execute()
                .value
            
            return metadata
        } catch {
            throw SyncError.serverError(error.localizedDescription)
        }
    }
    
    func fetchTripsModifiedAfter(_ date: Date) async throws -> [SupabaseTrip] {
        return try await fetchTripsSince(date)
    }
    
    // MARK: - Helper Methods
    
    private func formatError(_ error: Error) -> String {
        // Formatiere Fehlermeldungen für bessere Benutzerfreundlichkeit
        return error.localizedDescription
    }
}

// MARK: - Connection Status

enum ConnectionStatus: Equatable {
    case unknown
    case connecting
    case connected
    case disconnected
    case error(String)
    
    var description: String {
        switch self {
        case .unknown:
            return "Unbekannt"
        case .connecting:
            return "Verbindet..."
        case .connected:
            return "Verbunden"
        case .disconnected:
            return "Getrennt"
        case .error(let message):
            return "Fehler: \(message)"
        }
    }
}

// MARK: - Extensions

extension Date {
    func toISOString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

// MARK: - Trip Sync Metadata

struct TripSyncMetadata: Codable {
    let id: UUID
    let syncVersion: Int
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case syncVersion = "sync_version"
        case updatedAt = "updated_at"
    }
} 