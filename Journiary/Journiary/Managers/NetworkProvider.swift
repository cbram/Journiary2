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
        let mutation = CreateMemoryMutation(input: input)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(id: String, updatedAt: DateTime), Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 5, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for createMemory"]))
                        return
                    }
                    
                    guard let memory = graphQLResult.data?.createMemory else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to create memory, no data received."]))
                        return
                    }
                    continuation.resume(returning: (id: memory.id, updatedAt: memory.updatedAt))
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateMemory(id: String, input: UpdateMemoryInput) async throws -> (id: String, updatedAt: DateTime) {
        let mutation = UpdateMemoryMutation(id: id, input: input)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(id: String, updatedAt: DateTime), Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 6, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for updateMemory"]))
                        return
                    }
                    
                    guard let memory = graphQLResult.data?.updateMemory else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to update memory, no data received."]))
                        return
                    }
                    continuation.resume(returning: (id: memory.id, updatedAt: memory.updatedAt))
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteMemory(id: String) async throws -> String {
        let mutation = DeleteMemoryMutation(id: id)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 7, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for deleteMemory"]))
                        return
                    }
                    
                    // The 'deleteMemory' mutation returns a boolean for success.
                    // If successful, we return the original ID.
                    guard let success = graphQLResult.data?.deleteMemory, success else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to delete memory, server returned failure."]))
                        return
                    }
                    continuation.resume(returning: id)
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
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

    // MARK: - MediaItem Mutations

    func createMediaItem(input: MediaItemInput) async throws -> (id: String, updatedAt: DateTime) {
        let mutation = CreateMediaItemMutation(input: input)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(id: String, updatedAt: DateTime), Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 8, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for createMediaItem"]))
                        return
                    }
                    
                    guard let mediaItem = graphQLResult.data?.createMediaItem else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to create media item, no data received."]))
                        return
                    }
                    continuation.resume(returning: (id: mediaItem.id, updatedAt: mediaItem.updatedAt))
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteMediaItem(id: String) async throws -> String {
        let mutation = DeleteMediaItemMutation(id: id)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 9, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for deleteMediaItem"]))
                        return
                    }
                    
                    guard let success = graphQLResult.data?.deleteMediaItem, success else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 9, userInfo: [NSLocalizedDescriptionKey: "Failed to delete media item, server returned failure."]))
                        return
                    }
                    continuation.resume(returning: id)
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - GPXTrack Mutations

    func createGPXTrack(input: GPXTrackInput) async throws -> (id: String, updatedAt: DateTime) {
        let mutation = CreateGPXTrackMutation(input: input)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(id: String, updatedAt: DateTime), Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 10, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for createGPXTrack"]))
                        return
                    }
                    
                    guard let gpxTrack = graphQLResult.data?.createGpxTrack else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 10, userInfo: [NSLocalizedDescriptionKey: "Failed to create GPX track, no data received."]))
                        return
                    }
                    continuation.resume(returning: (id: gpxTrack.id, updatedAt: gpxTrack.updatedAt))
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteGPXTrack(id: String) async throws -> String {
        let mutation = DeleteGPXTrackMutation(id: id)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 11, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for deleteGPXTrack"]))
                        return
                    }
                    
                    guard let success = graphQLResult.data?.deleteGpxTrack, success else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to delete GPX track, server returned failure."]))
                        return
                    }
                    continuation.resume(returning: id)
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - File Synchronization Methods

    func generateBatchUploadUrls(uploadRequests: [JourniaryAPI.UploadRequest], expiresIn: Int? = nil) async throws -> GenerateBatchUploadUrlsMutation.Data.GenerateBatchUploadUrls {
        let mutation = GenerateBatchUploadUrlsMutation(
            uploadRequests: uploadRequests, 
            expiresIn: expiresIn != nil ? GraphQLNullable.some(expiresIn!) : GraphQLNullable.none
        )
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GenerateBatchUploadUrlsMutation.Data.GenerateBatchUploadUrls, Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 12, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for generateBatchUploadUrls"]))
                        return
                    }
                    
                    guard let uploadData = graphQLResult.data?.generateBatchUploadUrls else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 12, userInfo: [NSLocalizedDescriptionKey: "Failed to generate batch upload URLs, no data received."]))
                        return
                    }
                    continuation.resume(returning: uploadData)
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func generateBatchDownloadUrls(mediaItemIds: [String]? = nil, gpxTrackIds: [String]? = nil, expiresIn: Int? = nil) async throws -> GenerateBatchDownloadUrlsQuery.Data.GenerateBatchDownloadUrls {
        let query = GenerateBatchDownloadUrlsQuery(
            mediaItemIds: mediaItemIds != nil ? GraphQLNullable.some(mediaItemIds!.map { JourniaryAPI.ID($0) }) : GraphQLNullable.none,
            gpxTrackIds: gpxTrackIds != nil ? GraphQLNullable.some(gpxTrackIds!.map { JourniaryAPI.ID($0) }) : GraphQLNullable.none,
            expiresIn: expiresIn != nil ? GraphQLNullable.some(expiresIn!) : GraphQLNullable.none
        )
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GenerateBatchDownloadUrlsQuery.Data.GenerateBatchDownloadUrls, Error>) in
            apollo.fetch(query: query, cachePolicy: .fetchIgnoringCacheData) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 13, userInfo: [NSLocalizedDescriptionKey: "GraphQL query failed for generateBatchDownloadUrls"]))
                        return
                    }
                    
                    guard let downloadData = graphQLResult.data?.generateBatchDownloadUrls else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 13, userInfo: [NSLocalizedDescriptionKey: "Failed to generate batch download URLs, no data received."]))
                        return
                    }
                    continuation.resume(returning: downloadData)
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func markFileUploadComplete(entityId: String, entityType: String, objectName: String) async throws -> Bool {
        let mutation = MarkFileUploadCompleteMutation(entityId: JourniaryAPI.ID(entityId), entityType: entityType, objectName: objectName)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 14, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for markFileUploadComplete"]))
                        return
                    }
                    
                    guard let success = graphQLResult.data?.markFileUploadComplete else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 14, userInfo: [NSLocalizedDescriptionKey: "Failed to mark file upload complete, no data received."]))
                        return
                    }
                    continuation.resume(returning: success)
                    
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