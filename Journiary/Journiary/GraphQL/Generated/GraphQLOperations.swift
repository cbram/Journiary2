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
        let displayName: String?
        let initials: String?
        let createdAt: String
        let updatedAt: String
    }
    
    struct Trip: Codable {
        let id: String
        let name: String
        let tripDescription: String?
        let coverImageObjectName: String?
        let coverImageUrl: String?
        let travelCompanions: String?
        let visitedCountries: String?
        let startDate: String?
        let endDate: String?
        let isActive: Bool
        let totalDistance: Double
        let gpsTrackingEnabled: Bool
        let createdAt: String
        let updatedAt: String
    }
    
    struct Memory: Codable {
        let id: String
        let title: String
        let content: String?
        let date: String
        let latitude: Double?
        let longitude: Double?
        let address: String?
        let tripId: String
        let userId: String
        let createdAt: String
        let updatedAt: String
        let mediaItems: [MediaItem]?
        let tags: [Tag]?
    }
    
    struct MediaItem: Codable {
        let id: String
        let filename: String
        let originalFilename: String?
        let mimeType: String
        let fileSize: Int?
        let width: Int?
        let height: Int?
        let duration: Double?
        let s3Key: String
        let s3Bucket: String
        let thumbnailS3Key: String?
        let memoryId: String?
        let tripId: String?
        let userId: String
        let createdAt: String
        let updatedAt: String
    }
    
    struct Tag: Codable {
        let id: String
        let name: String
        let color: String?
        let categoryId: String?
        let userId: String
        let createdAt: String
        let updatedAt: String
    }
    
    struct TagCategory: Codable {
        let id: String
        let name: String
        let color: String?
        let icon: String?
        let userId: String
        let createdAt: String
        let updatedAt: String
        let tags: [Tag]?
    }
    
    struct RoutePoint: Codable {
        let id: String
        let latitude: Double
        let longitude: Double
        let altitude: Double?
        let accuracy: Double?
        let timestamp: String
        let speed: Double?
        let heading: Double?
        let tripId: String
        let userId: String
        let createdAt: String
        let updatedAt: String
    }
}

// MARK: - Input Types

struct TripInput: Codable {
    let name: String
    let tripDescription: String?
    let coverImageObjectName: String?
    let travelCompanions: String?
    let visitedCountries: String?
    let startDate: String
    let endDate: String?
    let isActive: Bool
    let totalDistance: Double
    let gpsTrackingEnabled: Bool
}

struct UpdateTripInput: Codable {
    let name: String?
    let tripDescription: String?
    let coverImageObjectName: String?
    let travelCompanions: String?
    let visitedCountries: String?
    let startDate: String?
    let endDate: String?
    let isActive: Bool?
    let totalDistance: Double?
    let gpsTrackingEnabled: Bool?
}

struct MemoryInput: Codable {
    let title: String
    let content: String?
    let date: String
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let tripId: String
}

struct UpdateMemoryInput: Codable {
    let title: String?
    let content: String?
    let date: String?
    let latitude: Double?
    let longitude: Double?
    let address: String?
}

struct MediaItemInput: Codable {
    let filename: String
    let originalFilename: String?
    let mimeType: String
    let fileSize: Int?
    let width: Int?
    let height: Int?
    let duration: Double?
    let s3Key: String
    let s3Bucket: String
    let thumbnailS3Key: String?
    let memoryId: String?
    let tripId: String?
}

struct TagInput: Codable {
    let name: String
    let color: String?
    let categoryId: String?
}

struct UpdateTagInput: Codable {
    let name: String?
    let color: String?
    let categoryId: String?
}

struct TagCategoryInput: Codable {
    let name: String
    let color: String?
    let icon: String?
}

struct UpdateTagCategoryInput: Codable {
    let name: String?
    let color: String?
    let icon: String?
}

struct UserInput: Codable {
    let username: String
    let email: String
    let password: String
    let firstName: String?
    let lastName: String?
}

struct UpdateUserInput: Codable {
    let username: String?
    let email: String?
    let firstName: String?
    let lastName: String?
}

// MARK: - Response Types

struct LoginResponse: Codable {
    let token: String
    let refreshToken: String
    let user: GraphQL.User
}

struct TokenRefreshResponse: Codable {
    let token: String
    let refreshToken: String
}

struct PresignedUrlResponse: Codable {
    let uploadUrl: String
    let key: String
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

// Trip Queries
struct GetTripsQuery: GraphQLQuery {
    static let operationName = "GetTrips"
    static let document = """
        query GetTrips {
            trips {
                id
                name
                tripDescription
                coverImageObjectName
                coverImageUrl
                travelCompanions
                visitedCountries
                startDate
                endDate
                isActive
                totalDistance
                gpsTrackingEnabled
                createdAt
                updatedAt
            }
        }
    """
    
    struct Data: Codable {
        let trips: [GraphQL.Trip]
    }
}

struct GetTripQuery: GraphQLQuery {
    static let operationName = "GetTrip"
    static let document = """
        query GetTrip($id: ID!) {
            trip(id: $id) {
                id
                name
                tripDescription
                coverImageObjectName
                coverImageUrl
                travelCompanions
                visitedCountries
                startDate
                endDate
                isActive
                totalDistance
                gpsTrackingEnabled
                createdAt
                updatedAt
                memories {
                    id
                    title
                    content
                    date
                    latitude
                    longitude
                    address
                    createdAt
                    updatedAt
                }
            }
        }
    """
    
    struct Data: Codable {
        let trip: GraphQL.Trip?
    }
}

// User Queries
struct GetCurrentUserQuery: GraphQLQuery {
    static let operationName = "GetCurrentUser"
    static let document = """
        query GetCurrentUser {
            getCurrentUser {
                id
                username
                email
                firstName
                lastName
                displayName
                initials
                createdAt
                updatedAt
            }
        }
    """
    
    struct Data: Codable {
        let getCurrentUser: GraphQL.User?
    }
}

// Memory Queries
struct GetMemoriesQuery: GraphQLQuery {
    static let operationName = "GetMemories"
    static let document = """
        query GetMemories($tripId: ID) {
            memories(tripId: $tripId) {
                id
                title
                content
                date
                latitude
                longitude
                address
                tripId
                userId
                createdAt
                updatedAt
                mediaItems {
                    id
                    filename
                    originalFilename
                    mimeType
                    fileSize
                    s3Key
                    thumbnailS3Key
                    createdAt
                }
                tags {
                    id
                    name
                    color
                    categoryId
                }
            }
        }
    """
    
    struct Data: Codable {
        let memories: [GraphQL.Memory]
    }
}

// Tag Queries
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
                updatedAt
            }
        }
    """
    
    struct Data: Codable {
        let tags: [GraphQL.Tag]
    }
}

struct GetTagCategoriesQuery: GraphQLQuery {
    static let operationName = "GetTagCategories"
    static let document = """
        query GetTagCategories {
            tagCategories {
                id
                name
                color
                icon
                userId
                createdAt
                updatedAt
                tags {
                    id
                    name
                    color
                }
            }
        }
    """
    
    struct Data: Codable {
        let tagCategories: [GraphQL.TagCategory]
    }
}

// MARK: - MUTATIONS

// Auth Mutations
struct LoginMutation: GraphQLMutation {
    static let operationName = "Login"
    static let document = """
        mutation Login($email: String!, $password: String!) {
            login(email: $email, password: $password) {
                token
                refreshToken
                user {
                    id
                    username
                    email
                    firstName
                    lastName
                    displayName
                    initials
                    createdAt
                    updatedAt
                }
            }
        }
    """
    
    struct Data: Codable {
        let login: LoginResponse
    }
}

struct RegisterMutation: GraphQLMutation {
    static let operationName = "Register"
    static let document = """
        mutation Register($input: UserInput!) {
            register(input: $input) {
                token
                refreshToken
                user {
                    id
                    username
                    email
                    firstName
                    lastName
                    displayName
                    initials
                    createdAt
                    updatedAt
                }
            }
        }
    """
    
    struct Data: Codable {
        let register: LoginResponse
    }
}

// Trip Mutations
struct CreateTripMutation: GraphQLMutation {
    static let operationName = "CreateTrip"
    static let document = """
        mutation CreateTrip($input: TripInput!) {
            createTrip(input: $input) {
                id
                name
                tripDescription
                coverImageObjectName
                coverImageUrl
                travelCompanions
                visitedCountries
                startDate
                endDate
                isActive
                totalDistance
                gpsTrackingEnabled
                createdAt
                updatedAt
            }
        }
    """
    
    struct Data: Codable {
        let createTrip: GraphQL.Trip
    }
}

struct UpdateTripMutation: GraphQLMutation {
    static let operationName = "UpdateTrip"
    static let document = """
        mutation UpdateTrip($id: ID!, $input: UpdateTripInput!) {
            updateTrip(id: $id, input: $input) {
                id
                name
                tripDescription
                coverImageObjectName
                coverImageUrl
                travelCompanions
                visitedCountries
                startDate
                endDate
                isActive
                totalDistance
                gpsTrackingEnabled
                createdAt
                updatedAt
            }
        }
    """
    
    struct Data: Codable {
        let updateTrip: GraphQL.Trip
    }
}

struct DeleteTripMutation: GraphQLMutation {
    static let operationName = "DeleteTrip"
    static let document = """
        mutation DeleteTrip($id: ID!) {
            deleteTrip(id: $id)
        }
    """
    
    struct Data: Codable {
        let deleteTrip: Bool
    }
}

// Memory Mutations
struct CreateMemoryMutation: GraphQLMutation {
    static let operationName = "CreateMemory"
    static let document = """
        mutation CreateMemory($input: MemoryInput!) {
            createMemory(input: $input) {
                id
                title
                content
                date
                latitude
                longitude
                address
                tripId
                userId
                createdAt
                updatedAt
            }
        }
    """
    
    struct Data: Codable {
        let createMemory: GraphQL.Memory
    }
}

struct UpdateMemoryMutation: GraphQLMutation {
    static let operationName = "UpdateMemory"
    static let document = """
        mutation UpdateMemory($id: ID!, $input: UpdateMemoryInput!) {
            updateMemory(id: $id, input: $input) {
                id
                title
                content
                date
                latitude
                longitude
                address
                tripId
                userId
                createdAt
                updatedAt
            }
        }
    """
    
    struct Data: Codable {
        let updateMemory: GraphQL.Memory
    }
}

struct DeleteMemoryMutation: GraphQLMutation {
    static let operationName = "DeleteMemory"
    static let document = """
        mutation DeleteMemory($id: ID!) {
            deleteMemory(id: $id)
        }
    """
    
    struct Data: Codable {
        let deleteMemory: Bool
    }
}

// Tag Mutations
struct CreateTagMutation: GraphQLMutation {
    static let operationName = "CreateTag"
    static let document = """
        mutation CreateTag($input: TagInput!) {
            createTag(input: $input) {
                id
                name
                color
                categoryId
                userId
                createdAt
                updatedAt
            }
        }
    """
    
    struct Data: Codable {
        let createTag: GraphQL.Tag
    }
}

struct CreateTagCategoryMutation: GraphQLMutation {
    static let operationName = "CreateTagCategory"
    static let document = """
        mutation CreateTagCategory($input: TagCategoryInput!) {
            createTagCategory(input: $input) {
                id
                name
                color
                icon
                userId
                createdAt
                updatedAt
            }
        }
    """
    
    struct Data: Codable {
        let createTagCategory: GraphQL.TagCategory
    }
}

// Media Mutations
struct CreateMediaItemMutation: GraphQLMutation {
    static let operationName = "CreateMediaItem"
    static let document = """
        mutation CreateMediaItem($input: MediaItemInput!) {
            createMediaItem(input: $input) {
                id
                filename
                originalFilename
                mimeType
                fileSize
                s3Key
                s3Bucket
                thumbnailS3Key
                memoryId
                tripId
                userId
                createdAt
                updatedAt
            }
        }
    """
    
    struct Data: Codable {
        let createMediaItem: GraphQL.MediaItem
    }
} 