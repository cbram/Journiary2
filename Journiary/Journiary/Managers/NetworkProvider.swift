//
//  NetworkProvider.swift
//  Journiary
//
//  Created by Gemini on 08.06.25.
//

import Foundation
import Apollo
import ApolloAPI
import JourniaryAPI

class NetworkProvider {
    
    private(set) var apollo: ApolloClient
    
    // MARK: - Singleton Instance
    
    static let shared = NetworkProvider()
    
    // MARK: - Public Methods
    
    public func resetClient() {
        self.apollo = NetworkProvider.createClient()
        print("ApolloClient wurde zurückgesetzt und neu initialisiert.")
    }
    
    // MARK: - Initialization
    
    private init() {
        self.apollo = NetworkProvider.createClient()
    }
    
    // MARK: - Private Factory
    
    static func getBackendURL() -> String {
        // Priority:
        // 1. Manual override from UserDefaults (highest priority)
        if let userURL = UserDefaults.standard.string(forKey: "backendURL"), !userURL.isEmpty {
            print("Verwende benutzerdefinierte URL aus UserDefaults: \(userURL)")
            return userURL
        }
        
        // 2. Configuration from plist (Debug vs. Production)
        guard let path = Bundle.main.path(forResource: "Configuration", ofType: "plist"),
              let configDict = NSDictionary(contentsOfFile: path) as? [String: String] else {
            fatalError("Configuration.plist nicht gefunden oder fehlerhaft. Stellen Sie sicher, dass die Datei zum Target gehört.")
        }
        
        #if DEBUG
        let key = "backendURL_debug"
        #else
        let key = "backendURL_production"
        #endif
        
        guard let urlFromConfig = configDict[key] else {
            fatalError("'\(key)' nicht in Configuration.plist gefunden.")
        }
        
        print("Verwende URL aus Konfiguration ('\(key)'): \(urlFromConfig)")
        return urlFromConfig
    }
    
    private static func createClient() -> ApolloClient {
        let store = ApolloStore()
        
        let backendURLString = getBackendURL()
        
        guard let url = URL(string: backendURLString) else {
            fatalError("Ungültige Backend-URL: \(backendURLString)")
        }
        
        print("ApolloClient wird mit URL initialisiert: \(url)")

        let client = URLSessionClient()
        let provider = NetworkInterceptorProvider(store: store, client: client)
        let transport = RequestChainNetworkTransport(
            interceptorProvider: provider,
            endpointURL: url
        )
        
        return ApolloClient(networkTransport: transport, store: store)
    }

    // MARK: - Trip Mutations

    func createTrip(input: TripInput) async throws -> CreateTripMutation.Data.CreateTrip {
        let mutation = CreateTripMutation(input: input)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CreateTripMutation.Data.CreateTrip, Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 1, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed"]))
                        return
                    }
                    
                    guard let trip = graphQLResult.data?.createTrip else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create trip, no data received."]))
                        return
                    }
                    continuation.resume(returning: trip)
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateTrip(id: String, input: TripInput) async throws -> UpdateTripMutation.Data.UpdateTrip {
        let updateInput = input.toUpdateTripInput()
        let mutation = UpdateTripMutation(id: id, input: updateInput)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UpdateTripMutation.Data.UpdateTrip, Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 2, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed"]))
                        return
                    }
                    
                    guard let trip = graphQLResult.data?.updateTrip else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to update trip, no data received."]))
                        return
                    }
                    continuation.resume(returning: trip)
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteTrip(id: String) async throws -> String {
        let mutation = DeleteTripMutation(id: id)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 3, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for deleteTrip"]))
                        return
                    }
                    
                    // The 'deleteTrip' mutation returns a boolean for success.
                    // If successful, we return the original ID.
                    guard let success = graphQLResult.data?.deleteTrip, success else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to delete trip, server returned failure."]))
                        return
                    }
                    continuation.resume(returning: id)
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Memory Mutations

    func createMemory(input: MemoryInput) async throws -> (id: String, updatedAt: DateTime) {
        fatalError("Codegen not yet successful")
        // let mutation = CreateMemoryMutation(input: input)
        // ...
    }

    func updateMemory(id: String, input: UpdateMemoryInput) async throws -> (id: String, updatedAt: DateTime) {
        fatalError("Codegen not yet successful")
        // let mutation = UpdateMemoryMutation(id: id, input: input)
        // ...
    }

    func deleteMemory(id: String) async throws -> String {
        fatalError("Codegen not yet successful")
        // let mutation = DeleteMemoryMutation(id: id)
        // ...
    }

    func sync(lastSyncedAt: Date?) async throws -> SyncQuery.Data.Sync {
        // SyncQuery expects DateTime! (required), so we provide a default timestamp for first sync
        let lastSyncDateTime: DateTime = lastSyncedAt.map { dateToDateTime($0) } ?? dateToDateTime(Date.distantPast)
        let query = SyncQuery(lastSyncedAt: lastSyncDateTime)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SyncQuery.Data.Sync, Error>) in
            apollo.fetch(query: query, cachePolicy: .fetchIgnoringCacheData) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 4, userInfo: [NSLocalizedDescriptionKey: "GraphQL query failed for sync"]))
                        return
                    }
                    
                    guard let syncData = graphQLResult.data?.sync else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to sync, no data received."]))
                        return
                    }
                    continuation.resume(returning: syncData)
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func dateToDateTime(_ date: Date) -> DateTime {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

extension JourniaryAPI.TripInput {
    func toUpdateTripInput() -> JourniaryAPI.UpdateTripInput {
        return JourniaryAPI.UpdateTripInput(
            name: .some(self.name),
            tripDescription: self.tripDescription,
            travelCompanions: self.travelCompanions,
            visitedCountries: self.visitedCountries,
            startDate: .some(self.startDate),
            endDate: self.endDate,
            isActive: self.isActive,
            totalDistance: self.totalDistance,
            gpsTrackingEnabled: self.gpsTrackingEnabled
        )
    }
} 