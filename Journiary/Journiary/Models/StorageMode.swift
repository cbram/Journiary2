//
//  StorageMode.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation

enum StorageMode: String, CaseIterable, Identifiable {
    case cloudKit = "cloudkit"
    case backend = "backend"
    case hybrid = "hybrid"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cloudKit:
            return "CloudKit"
        case .backend:
            return "Backend Server"
        case .hybrid:
            return "Hybrid (CloudKit + Backend)"
        }
    }
    
    var description: String {
        switch self {
        case .cloudKit:
            return "Speichert alle Daten in CloudKit (Apple ID erforderlich)"
        case .backend:
            return "Speichert alle Daten auf eigenem Backend Server"
        case .hybrid:
            return "Synchronisiert zwischen CloudKit und Backend Server"
        }
    }
    
    var iconName: String {
        switch self {
        case .cloudKit:
            return "icloud.fill"
        case .backend:
            return "server.rack"
        case .hybrid:
            return "arrow.triangle.2.circlepath"
        }
    }
    
    static var `default`: StorageMode {
        return .cloudKit
    }
} 