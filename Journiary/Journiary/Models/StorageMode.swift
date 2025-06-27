//
//  StorageMode.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation

/// Definiert die verschiedenen Speichermodi für die App
enum StorageMode: String, CaseIterable, Identifiable {
    /// Daten werden ausschließlich in iCloud/CloudKit gespeichert
    case cloudKit = "iCloud"
    
    /// Daten werden ausschließlich im selbst gehosteten Backend gespeichert
    case selfHosted = "Self-Hosted"
    
    /// Daten werden sowohl in CloudKit als auch im selbst gehosteten Backend gespeichert
    case hybrid = "Hybrid"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .cloudKit:
            return "Daten werden in Apple iCloud gespeichert"
        case .selfHosted:
            return "Daten werden auf deinem eigenen Server gespeichert"
        case .hybrid:
            return "Daten werden sowohl in iCloud als auch auf deinem Server gespeichert"
        }
    }
    
    var icon: String {
        switch self {
        case .cloudKit:
            return "icloud"
        case .selfHosted:
            return "server.rack"
        case .hybrid:
            return "arrow.triangle.2.circlepath"
        }
    }
} 