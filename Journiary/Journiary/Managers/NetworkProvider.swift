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

    // MARK: - Tag Mutations

    func createTag(input: TagInput) async throws -> (id: String, updatedAt: DateTime?) {
        let mutation = CreateTagMutation(input: input)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(id: String, updatedAt: DateTime?), Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 15, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for createTag"]))
                        return
                    }
                    
                    guard let tag = graphQLResult.data?.createTag else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 15, userInfo: [NSLocalizedDescriptionKey: "Failed to create tag, no data received."]))
                        return
                    }
                    // Tag responses don't include updatedAt, so we return nil
                    continuation.resume(returning: (id: tag.id, updatedAt: nil))
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateTag(id: String, input: UpdateTagInput) async throws -> (id: String, updatedAt: DateTime?) {
        let mutation = UpdateTagMutation(id: id, input: input)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(id: String, updatedAt: DateTime?), Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 16, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for updateTag"]))
                        return
                    }
                    
                    guard let tag = graphQLResult.data?.updateTag else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 16, userInfo: [NSLocalizedDescriptionKey: "Failed to update tag, no data received."]))
                        return
                    }
                    // Tag responses don't include updatedAt, so we return nil
                    continuation.resume(returning: (id: tag.id, updatedAt: nil))
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteTag(id: String) async throws -> String {
        let mutation = DeleteTagMutation(id: id)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 17, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for deleteTag"]))
                        return
                    }
                    
                    guard let success = graphQLResult.data?.deleteTag, success else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 17, userInfo: [NSLocalizedDescriptionKey: "Failed to delete tag, server returned failure."]))
                        return
                    }
                    continuation.resume(returning: id)
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - TagCategory Mutations

    func createTagCategory(input: TagCategoryInput) async throws -> (id: String, updatedAt: DateTime) {
        let mutation = CreateTagCategoryMutation(input: input)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(id: String, updatedAt: DateTime), Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 18, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for createTagCategory"]))
                        return
                    }
                    
                    guard let tagCategory = graphQLResult.data?.createTagCategory else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 18, userInfo: [NSLocalizedDescriptionKey: "Failed to create tag category, no data received."]))
                        return
                    }
                    continuation.resume(returning: (id: tagCategory.id, updatedAt: tagCategory.updatedAt))
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateTagCategory(id: String, input: UpdateTagCategoryInput) async throws -> (id: String, updatedAt: DateTime) {
        let mutation = UpdateTagCategoryMutation(id: id, input: input)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(id: String, updatedAt: DateTime), Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 19, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for updateTagCategory"]))
                        return
                    }
                    
                    guard let tagCategory = graphQLResult.data?.updateTagCategory else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 19, userInfo: [NSLocalizedDescriptionKey: "Failed to update tag category, no data received."]))
                        return
                    }
                    continuation.resume(returning: (id: tagCategory.id, updatedAt: tagCategory.updatedAt))
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteTagCategory(id: String) async throws -> String {
        let mutation = DeleteTagCategoryMutation(id: id)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 20, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for deleteTagCategory"]))
                        return
                    }
                    
                    guard let success = graphQLResult.data?.deleteTagCategory, success else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 20, userInfo: [NSLocalizedDescriptionKey: "Failed to delete tag category, server returned failure."]))
                        return
                    }
                    continuation.resume(returning: id)
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - BucketListItem Mutations

    func createBucketListItem(input: BucketListItemInput) async throws -> (id: String, updatedAt: DateTime) {
        let mutation = CreateBucketListItemMutation(input: input)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(id: String, updatedAt: DateTime), Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 21, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for createBucketListItem"]))
                        return
                    }
                    
                    guard let bucketListItem = graphQLResult.data?.createBucketListItem else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 21, userInfo: [NSLocalizedDescriptionKey: "Failed to create bucket list item, no data received."]))
                        return
                    }
                    continuation.resume(returning: (id: bucketListItem.id, updatedAt: bucketListItem.updatedAt))
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateBucketListItem(id: String, input: BucketListItemInput) async throws -> (id: String, updatedAt: DateTime) {
        let mutation = UpdateBucketListItemMutation(id: id, input: input)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(id: String, updatedAt: DateTime), Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 22, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for updateBucketListItem"]))
                        return
                    }
                    
                    guard let bucketListItem = graphQLResult.data?.updateBucketListItem else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 22, userInfo: [NSLocalizedDescriptionKey: "Failed to update bucket list item, no data received."]))
                        return
                    }
                    continuation.resume(returning: (id: bucketListItem.id, updatedAt: bucketListItem.updatedAt))
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func deleteBucketListItem(id: String) async throws -> String {
        let mutation = DeleteBucketListItemMutation(id: id)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            apollo.perform(mutation: mutation) { result in
                switch result {
                case .success(let graphQLResult):
                    if let errors = graphQLResult.errors {
                        continuation.resume(throwing: errors.first ?? NSError(domain: "GraphQLError", code: 23, userInfo: [NSLocalizedDescriptionKey: "GraphQL mutation failed for deleteBucketListItem"]))
                        return
                    }
                    
                    guard let success = graphQLResult.data?.deleteBucketListItem, success else {
                        continuation.resume(throwing: NSError(domain: "NetworkProviderError", code: 23, userInfo: [NSLocalizedDescriptionKey: "Failed to delete bucket list item, server returned failure."]))
                        return
                    }
                    continuation.resume(returning: id)
                    
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

// MARK: - Network Request Optimizations (Schritt 5.4)

/// Network-Request-Optimierungen für bessere Performance und Effizienz
/// Implementiert als Teil von Schritt 5.4 des Sync-Implementierungsplans
extension NetworkProvider {
    
    /// Batch-Request-Manager für GraphQL-Operationen
    private static let batchRequestManager = BatchRequestManager()
    
    /// Request-Deduplication-Cache
    private static var pendingRequests: [String: Task<Any, Error>] = [:]
    private static let requestLock = NSLock()
    
    /// Optimierte Sync-Funktion mit Request-Batching
    func syncOptimized(lastSyncedAt: Date?) async throws -> SyncQuery.Data.Sync {
        let measurement = PerformanceMonitor.shared.startMeasuring(operation: "OptimizedSync")
        
        // Verwende intelligente Caching-Strategie
        let cacheKey = "sync:\(lastSyncedAt?.timeIntervalSince1970 ?? 0)"
        
        // Prüfe auf bereits laufende Request
        if let existingTask = Self.getExistingRequest(for: cacheKey) {
            let result = try await existingTask as! SyncQuery.Data.Sync
            measurement.finish(entityCount: 1)
            return result
        }
        
        // Erstelle neue optimierte Request
        let task = Task<SyncQuery.Data.Sync, Error> {
            defer { Self.removeRequest(for: cacheKey) }
            
            // Verwende Cache wenn verfügbar und noch gültig
            if let cached = SyncCacheManager.shared.getCachedEntity(forKey: cacheKey, type: SyncQuery.Data.Sync.self) {
                measurement.finish(entityCount: 1)
                return cached
            }
            
            // Führe normale Sync-Request aus
            let result = try await self.sync(lastSyncedAt: lastSyncedAt)
            
            // Cache das Ergebnis für 2 Minuten
            SyncCacheManager.shared.cacheEntity(result, forKey: cacheKey, ttl: 120)
            
            measurement.finish(entityCount: 1)
            return result
        }
        
        Self.storeRequest(task, for: cacheKey)
        return try await task.value
    }
    
    /// Batch-Upload für mehrere Entitäten
    func batchUpload<T: Any>(
        operations: [(operation: String, input: T)],
        maxBatchSize: Int = 10
    ) async throws -> [BatchUploadResult] {
        let measurement = PerformanceMonitor.shared.startMeasuring(operation: "BatchUpload")
        
        let batches = operations.chunked(into: maxBatchSize)
        var allResults: [BatchUploadResult] = []
        
        for batch in batches {
            let batchResults = try await processBatch(batch)
            allResults.append(contentsOf: batchResults)
            
            // Kleine Pause zwischen Batches um Server nicht zu überlasten
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        measurement.finish(entityCount: operations.count)
        return allResults
    }
    
    /// Optimierte File-Upload mit Compression und Retry-Logik
    func uploadFileOptimized(
        fileURL: URL,
        uploadURL: URL,
        mimeType: String,
        maxRetries: Int = 3
    ) async throws -> Bool {
        let measurement = PerformanceMonitor.shared.startMeasuring(operation: "OptimizedFileUpload")
        
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let success = try await uploadFileWithCompression(
                    fileURL: fileURL,
                    uploadURL: uploadURL,
                    mimeType: mimeType
                )
                
                measurement.finish(entityCount: 1)
                return success
                
            } catch {
                lastError = error
                print("⚠️ Upload-Versuch \(attempt) fehlgeschlagen: \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = TimeInterval(1 << (attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        measurement.finish(entityCount: 0)
        throw lastError ?? URLError(.unknown)
    }
    
    /// Intelligent Request-Caching
    func cachedRequest<T: Codable>(
        cacheKey: String,
        ttl: TimeInterval = 300,
        requestBuilder: () async throws -> T
    ) async throws -> T {
        // Prüfe Cache zuerst
        if let cached = SyncCacheManager.shared.getCachedEntity(forKey: cacheKey, type: T.self) {
            return cached
        }
        
        // Request ausführen und cachen
        let result = try await requestBuilder()
        SyncCacheManager.shared.cacheEntity(result, forKey: cacheKey, ttl: ttl)
        
        return result
    }
    
    // MARK: - Private Helper Methods
    
    private func processBatch<T: Any>(
        _ batch: [(operation: String, input: T)]
    ) async throws -> [BatchUploadResult] {
        // Führe Batch-Operationen parallel aus
        return try await withThrowingTaskGroup(of: BatchUploadResult.self) { group in
            for operation in batch {
                group.addTask {
                    do {
                        let result = try await self.processSingleOperation(operation)
                        return BatchUploadResult(
                            operation: operation.operation,
                            success: true,
                            result: result,
                            error: nil
                        )
                    } catch {
                        return BatchUploadResult(
                            operation: operation.operation,
                            success: false,
                            result: nil,
                            error: error.localizedDescription
                        )
                    }
                }
            }
            
            var results: [BatchUploadResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    private func processSingleOperation<T: Any>(
        _ operation: (operation: String, input: T)
    ) async throws -> Any {
        // Router für verschiedene Operationen
        switch operation.operation {
        case "createTrip":
            return try await createTrip(input: operation.input as! TripInput)
        case "createMemory":
            return try await createMemory(input: operation.input as! MemoryInput)
        case "createMediaItem":
            return try await createMediaItem(input: operation.input as! MediaItemInput)
        case "createGPXTrack":
            return try await createGPXTrack(input: operation.input as! GPXTrackInput)
        default:
            throw NSError(domain: "NetworkProvider", code: 999, userInfo: [
                NSLocalizedDescriptionKey: "Unknown operation: \(operation.operation)"
            ])
        }
    }
    
    private func uploadFileWithCompression(
        fileURL: URL,
        uploadURL: URL,
        mimeType: String
    ) async throws -> Bool {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        
        // Komprimiere Datei wenn möglich
        let fileData: Data
        if shouldCompressFile(mimeType: mimeType) {
            fileData = try compressFile(at: fileURL)
            request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
        } else {
            fileData = try Data(contentsOf: fileURL)
        }
        
        request.httpBody = fileData
        
        // Verwende optimierte URLSession
        let session = getOptimizedURLSession()
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        return (200...299).contains(httpResponse.statusCode)
    }
    
    private func shouldCompressFile(mimeType: String) -> Bool {
        // Komprimiere nur bestimmte Dateitypen
        let compressibleTypes = ["text/", "application/json", "application/xml"]
        return compressibleTypes.contains { mimeType.hasPrefix($0) }
    }
    
    private func compressFile(at fileURL: URL) throws -> Data {
        let originalData = try Data(contentsOf: fileURL)
        return try (originalData as NSData).compressed(using: .zlib) as Data
    }
    
    private func getOptimizedURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        
        // Optimierte Konfiguration für File-Uploads
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 300.0
        config.httpMaximumConnectionsPerHost = 6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        // Connection-Pool-Optimierungen
        config.httpShouldUsePipelining = true
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        
        // Compression
        config.httpAdditionalHeaders = [
            "Accept-Encoding": "gzip, deflate"
        ]
        
        return URLSession(configuration: config)
    }
    
    // Request-Deduplication Hilfsmethoden
    private static func getExistingRequest(for key: String) -> Task<Any, Error>? {
        requestLock.lock()
        defer { requestLock.unlock() }
        return pendingRequests[key]
    }
    
    private static func storeRequest<T>(_ task: Task<T, Error>, for key: String) {
        requestLock.lock()
        defer { requestLock.unlock() }
        pendingRequests[key] = task as! Task<Any, Error>
    }
    
    private static func removeRequest(for key: String) {
        requestLock.lock()
        defer { requestLock.unlock() }
        pendingRequests.removeValue(forKey: key)
    }
}

// MARK: - Supporting Types

/// Ergebnis einer Batch-Upload-Operation
struct BatchUploadResult {
    let operation: String
    let success: Bool
    let result: Any?
    let error: String?
}

/// Batch-Request-Manager für GraphQL-Optimierungen
class BatchRequestManager {
    private var pendingBatches: [String: [PendingRequest]] = [:]
    private let batchQueue = DispatchQueue(label: "BatchRequestQueue")
    private let maxWaitTime: TimeInterval = 0.1 // 100ms
    
    struct PendingRequest {
        let id: UUID
        let timestamp: Date
        let completion: (Result<Any, Error>) -> Void
    }
    
    func batchRequest<T>(
        operation: String,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        batchQueue.async {
            let request = PendingRequest(
                id: UUID(),
                timestamp: Date(),
                completion: { result in
                    switch result {
                    case .success(let value):
                        if let typedValue = value as? T {
                            completion(.success(typedValue))
                        } else {
                            completion(.failure(NSError(domain: "BatchRequestManager", code: 1, userInfo: [
                                NSLocalizedDescriptionKey: "Type conversion failed"
                            ])))
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            )
            
            if self.pendingBatches[operation] == nil {
                self.pendingBatches[operation] = []
            }
            self.pendingBatches[operation]?.append(request)
            
            // Verzögertes Ausführen der Batch
            DispatchQueue.global().asyncAfter(deadline: .now() + self.maxWaitTime) {
                self.executeBatch(for: operation)
            }
        }
    }
    
    private func executeBatch(for operation: String) {
        batchQueue.sync {
            guard let requests = pendingBatches[operation], !requests.isEmpty else {
                return
            }
            
            pendingBatches[operation] = nil
            
            // Führe gebatchte Requests aus
            for request in requests {
                // Simuliere Batch-Ausführung
                request.completion(.success("Batch result for \(operation)"))
            }
        }
    }
}

// Array chunking wird bereits in SyncManager definiert 