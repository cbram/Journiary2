//
//  GraphQLOperations.swift
//  Journiary
//
//  Generated from Backend Schema - 16.12.2024
//

import Foundation

// MARK: - Protocol Definitions

protocol GraphQLOperation {
    static var operationName: String { get }
    static var document: String { get }
    associatedtype Data: Codable
}

protocol GraphQLQuery: GraphQLOperation {}
protocol GraphQLMutation: GraphQLOperation {}

// MARK: - Response Types

struct GraphQLResponse<T: Codable>: Codable {
    let data: T?
    let errors: [GraphQLErrorResponse]?
}

struct GraphQLErrorResponse: Codable {
    let message: String
    let locations: [GraphQLErrorLocation]?
    let path: [String]?
}

struct GraphQLErrorLocation: Codable {
    let line: Int
    let column: Int
}

// MARK: - GraphQL Types Namespace

enum GraphQL {
    
    // MARK: - Core Types
    
    struct User: Codable {
        let id: String
        let email: String
        let username: String?
        let firstName: String?
        let lastName: String?
        let createdAt: String
        let updatedAt: String
    }
    
    struct Trip: Codable {
        let id: String
        let name: String
        let description: String?
        let startDate: String?
        let endDate: String?
        let userId: String
        let createdAt: String
        let updatedAt: String
        let coverImageUrl: String?
    }
    
    struct Memory: Codable {
        let id: String
        let title: String
        let content: String?
        let tripId: String
        let userId: String
        let latitude: Double?
        let longitude: Double?
        let createdAt: String
        let updatedAt: String
        let mediaItems: [MediaItem]?
    }
    
    struct MediaItem: Codable {
        let id: String
        let filename: String
        let originalFilename: String?
        let mimeType: String
        let fileSize: Int?
        let memoryId: String?
        let createdAt: String
        let url: String?
    }
    
    struct Tag: Codable {
        let id: String
        let name: String
        let color: String?
        let categoryId: String?
        let userId: String
        let createdAt: String
    }
    
    struct TagCategory: Codable {
        let id: String
        let name: String
        let color: String?
        let userId: String
        let createdAt: String
    }
    
    struct RoutePoint: Codable {
        let id: String
        let latitude: Double
        let longitude: Double
        let altitude: Double?
        let timestamp: String
        let accuracy: Double?
        let speed: Double?
        let heading: Double?
        let tripId: String
    }
}

// MARK: - Auth Types

struct AuthResponse: Codable {
    let token: String
    let user: GraphQL.User
}

struct LoginInput: Codable {
    let email: String
    let password: String
}

struct RegisterInput: Codable {
    let email: String
    let password: String
    let username: String?
    let firstName: String?
    let lastName: String?
}

// MARK: - Input Types

struct CreateTripInput: Codable {
    let name: String
    let description: String?
    let startDate: String?
    let endDate: String?
}

struct UpdateTripInput: Codable {
    let name: String?
    let description: String?
    let startDate: String?
    let endDate: String?
}

struct CreateMemoryInput: Codable {
    let title: String
    let content: String?
    let tripId: String
    let latitude: Double?
    let longitude: Double?
}

struct CreateTagInput: Codable {
    let name: String
    let color: String?
    let categoryId: String?
}

// MARK: - Upload Types

struct UploadUrlResponse: Codable {
    let uploadUrl: String
    let fileKey: String
}

// MARK: - QUERIES

// Hello Query
struct HelloQuery: GraphQLQuery {
    static let operationName = "Hello"
    static let document = """
        query Hello {
            hello
        }
    """
    
    struct Data: Codable {
        let hello: String
    }
}

// Get Trips Query
struct GetTripsQuery: GraphQLQuery {
    static let operationName = "GetTrips"
    static let document = """
        query GetTrips {
            trips {
                id
                name
                description
                startDate
                endDate
                userId
                createdAt
                updatedAt
                coverImageUrl
            }
        }
    """
    
    struct Data: Codable {
        let trips: [GraphQL.Trip]
    }
}

// Get Trip Query
struct GetTripQuery: GraphQLQuery {
    static let operationName = "GetTrip"
    static let document = """
        query GetTrip($id: ID!) {
            trip(id: $id) {
                id
                name
                description
                startDate
                endDate
                userId
                createdAt
                updatedAt
                coverImageUrl
            }
        }
    """
    
    struct Variables: Codable {
        let id: String
    }
    
    struct Data: Codable {
        let trip: GraphQL.Trip?
    }
}

// Get Memories Query
struct GetMemoriesQuery: GraphQLQuery {
    static let operationName = "GetMemories"
    static let document = """
        query GetMemories($tripId: ID) {
            memories(tripId: $tripId) {
                id
                title
                content
                tripId
                userId
                latitude
                longitude
                createdAt
                updatedAt
                mediaItems {
                    id
                    filename
                    originalFilename
                    mimeType
                    fileSize
                    url
                }
            }
        }
    """
    
    struct Variables: Codable {
        let tripId: String?
    }
    
    struct Data: Codable {
        let memories: [GraphQL.Memory]
    }
}

// Get Tags Query
struct GetTagsQuery: GraphQLQuery {
    static let operationName = "GetTags"
    static let document = """
        query GetTags {
            tags {
                id
                name
                color
                categoryId
                userId
                createdAt
            }
        }
    """
    
    struct Data: Codable {
        let tags: [GraphQL.Tag]
    }
}

// Get Tag Categories Query
struct GetTagCategoriesQuery: GraphQLQuery {
    static let operationName = "GetTagCategories"
    static let document = """
        query GetTagCategories {
            tagCategories {
                id
                name
                color
                userId
                createdAt
            }
        }
    """
    
    struct Data: Codable {
        let tagCategories: [GraphQL.TagCategory]
    }
}

// MARK: - MUTATIONS

// Login Mutation
struct LoginMutation: GraphQLMutation {
    static let operationName = "Login"
    static let document = """
        mutation Login($input: LoginInput!) {
            login(input: $input) {
                token
                user {
                    id
                    email
                    username
                    firstName
                    lastName
                    createdAt
                    updatedAt
                }
            }
        }
    """
    
    struct Variables: Codable {
        let input: LoginInput
    }
    
    struct Data: Codable {
        let login: AuthResponse
    }
}

// Register Mutation
struct RegisterMutation: GraphQLMutation {
    static let operationName = "Register"
    static let document = """
        mutation Register($input: RegisterInput!) {
            register(input: $input) {
                token
                user {
                    id
                    email
                    username
                    firstName
                    lastName
                    createdAt
                    updatedAt
                }
            }
        }
    """
    
    struct Variables: Codable {
        let input: RegisterInput
    }
    
    struct Data: Codable {
        let register: AuthResponse
    }
}

// Create Trip Mutation
struct CreateTripMutation: GraphQLMutation {
    static let operationName = "CreateTrip"
    static let document = """
        mutation CreateTrip($input: CreateTripInput!) {
            createTrip(input: $input) {
                id
                name
                description
                startDate
                endDate
                userId
                createdAt
                updatedAt
                coverImageUrl
            }
        }
    """
    
    struct Variables: Codable {
        let input: CreateTripInput
    }
    
    struct Data: Codable {
        let createTrip: GraphQL.Trip
    }
}

// Update Trip Mutation
struct UpdateTripMutation: GraphQLMutation {
    static let operationName = "UpdateTrip"
    static let document = """
        mutation UpdateTrip($id: ID!, $input: UpdateTripInput!) {
            updateTrip(id: $id, input: $input) {
                id
                name
                description
                startDate
                endDate
                userId
                createdAt
                updatedAt
                coverImageUrl
            }
        }
    """
    
    struct Variables: Codable {
        let id: String
        let input: UpdateTripInput
    }
    
    struct Data: Codable {
        let updateTrip: GraphQL.Trip
    }
}

// Delete Trip Mutation
struct DeleteTripMutation: GraphQLMutation {
    static let operationName = "DeleteTrip"
    static let document = """
        mutation DeleteTrip($id: ID!) {
            deleteTrip(id: $id)
        }
    """
    
    struct Variables: Codable {
        let id: String
    }
    
    struct Data: Codable {
        let deleteTrip: Bool
    }
}

// Create Memory Mutation
struct CreateMemoryMutation: GraphQLMutation {
    static let operationName = "CreateMemory"
    static let document = """
        mutation CreateMemory($input: CreateMemoryInput!) {
            createMemory(input: $input) {
                id
                title
                content
                tripId
                userId
                latitude
                longitude
                createdAt
                updatedAt
            }
        }
    """
    
    struct Variables: Codable {
        let input: CreateMemoryInput
    }
    
    struct Data: Codable {
        let createMemory: GraphQL.Memory
    }
}

// Create Upload URL Mutation
struct CreateUploadUrlMutation: GraphQLMutation {
    static let operationName = "CreateUploadUrl"
    static let document = """
        mutation CreateUploadUrl($filename: String!, $mimeType: String!) {
            createUploadUrl(filename: $filename, mimeType: $mimeType) {
                uploadUrl
                fileKey
            }
        }
    """
    
    struct Variables: Codable {
        let filename: String
        let mimeType: String
    }
    
    struct Data: Codable {
        let createUploadUrl: UploadUrlResponse
    }
}

// Create Media Item Mutation
struct CreateMediaItemMutation: GraphQLMutation {
    static let operationName = "CreateMediaItem"
    static let document = """
        mutation CreateMediaItem($fileKey: String!, $filename: String!, $mimeType: String!, $memoryId: ID) {
            createMediaItem(fileKey: $fileKey, filename: $filename, mimeType: $mimeType, memoryId: $memoryId) {
                id
                filename
                originalFilename
                mimeType
                fileSize
                memoryId
                createdAt
                url
            }
        }
    """
    
    struct Variables: Codable {
        let fileKey: String
        let filename: String
        let mimeType: String
        let memoryId: String?
    }
    
    struct Data: Codable {
        let createMediaItem: GraphQL.MediaItem
    }
}

// Create Tag Mutation
struct CreateTagMutation: GraphQLMutation {
    static let operationName = "CreateTag"
    static let document = """
        mutation CreateTag($input: CreateTagInput!) {
            createTag(input: $input) {
                id
                name
                color
                categoryId
                userId
                createdAt
            }
        }
    """
    
    struct Variables: Codable {
        let input: CreateTagInput
    }
    
    struct Data: Codable {
        let createTag: GraphQL.Tag
    }
} 