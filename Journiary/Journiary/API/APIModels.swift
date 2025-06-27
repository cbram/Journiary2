//
//  APIModels.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation

// MARK: - Generic GraphQL Models

/// Allgemeine GraphQL-Antwortstruktur
struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

struct GraphQLError: Decodable {
    let message: String
    let locations: [GraphQLErrorLocation]?
    let path: [String]?
}

struct GraphQLErrorLocation: Decodable {
    let line: Int
    let column: Int
}

// MARK: - Authentication Models

struct LoginData: Decodable {
    let login: LoginResponse
}

struct LoginResponse: Decodable {
    let token: String
    let user: User
}

struct RegisterData: Decodable {
    let register: User
}

struct MeData: Decodable {
    let me: User
}

struct User: Decodable, Identifiable {
    let id: String
    let username: String
    let email: String
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - MinIO Models

struct PresignedUrlData: Decodable {
    let getPresignedUploadUrl: PresignedUrlResponse
}

struct PresignedUrlResponse: Decodable {
    let url: String
    let objectName: String
}

struct DownloadUrlData: Decodable {
    let getPresignedDownloadUrl: String
} 