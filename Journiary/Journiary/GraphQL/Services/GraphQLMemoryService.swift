import Foundation
import Combine

//  GraphQLMemoryService.swift
//  Enthält CRUD-Operationen für Memories via GraphQL API

class GraphQLMemoryService {
    private let client = ApolloClientManager.shared
    
    // Memories für Trip abrufen (wenn benötigt)
    func getMemories(tripId: String? = nil) -> AnyPublisher<[MemoryDTO], GraphQLError> {
        var variables: [String: Any] = [:]
        if let id = tripId { variables["tripId"] = id }
        return client.fetch(query: GetMemoriesQuery.self, variables: variables, cachePolicy: .networkOnly)
            .map { resp in
                resp.memories.compactMap { memData -> MemoryDTO? in
                    MemoryDTO.from(graphQL: memData)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // Memory erstellen
    func createMemory(input dto: MemoryDTO) -> AnyPublisher<MemoryDTO, GraphQLError> {
        let variables: [String: Any] = ["input": dto.toGraphQLInput()]
        return client.perform(mutation: CreateMemoryMutation.self, variables: variables)
            .tryMap { resp -> MemoryDTO in
                guard let mem = resp.createMemory else {
                    throw GraphQLError.serverError("Leere createMemory Response")
                }
                guard let dto = MemoryDTO.from(graphQL: mem) else {
                    throw GraphQLError.serverError("Parsing-Fehler createMemory")
                }
                return dto
            }
            .mapError { err in err as? GraphQLError ?? .networkError(err.localizedDescription) }
            .eraseToAnyPublisher()
    }
} 