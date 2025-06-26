//
//  TracesTrackConfig.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import Foundation

/// Konfiguration für TracesTrack Maps Integration
struct TracesTrackConfig {
    
    // MARK: - Tile Server URLs
    
    /// Basis URL für TracesTrack Topo Tiles (kostenlos für OSM Integration)
    static let topoTileBaseURL = "https://tile.tracestrack.com/topo__"
    
    /// Basis URL für TracesTrack Vector Tiles (Premium mit API Key)
    static let vectorTileBaseURL = "https://tile.tracestrack.com"
    
    // MARK: - Tile Configuration
    
    /// Maximale Zoom-Stufe für TracesTrack Tiles
    static let maxZoomLevel = 18
    
    /// Minimale Zoom-Stufe für TracesTrack Tiles
    static let minZoomLevel = 1
    
    /// User-Agent für HTTP Requests
    static let userAgent = "Journiary iOS App - OSM Integration"
    
    // MARK: - API Key Management (für Premium Features)
    
    /// API Key für TracesTrack Premium Features
    /// Hinweis: Für Demo-Zwecke leer, in Produktion aus sicherer Quelle laden
    private static var apiKey: String? {
        // In Produktion: aus Keychain oder sicherer Konfiguration laden
        return UserDefaults.standard.string(forKey: "TracesTrackAPIKey")
    }
    
    /// Prüft ob API Key verfügbar ist
    static var hasAPIKey: Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }
    
    /// Setzt den API Key (für Premium Features)
    static func setAPIKey(_ key: String?) {
        if let key = key, !key.isEmpty {
            UserDefaults.standard.set(key, forKey: "TracesTrackAPIKey")
        } else {
            UserDefaults.standard.removeObject(forKey: "TracesTrackAPIKey")
        }
    }
    
    // MARK: - URL Generation
    
    /// Generiert URL für Topo Tile
    static func topoTileURL(x: Int, y: Int, z: Int) -> URL? {
        // TracesTrack erfordert für alle Services einen API Key
        guard let key = apiKey else {
            return nil // Kein TracesTrack ohne API Key
        }
        
        let urlString = "\(topoTileBaseURL)/\(z)/\(x)/\(y).png?key=\(key)"
        return URL(string: urlString)
    }
    
    /// Generiert URL für Vector Tile (mit API Key)
    static func vectorTileURL(x: Int, y: Int, z: Int) -> URL? {
        guard let key = apiKey else {
            // Fallback auf Topo Tiles wenn kein API Key
            return topoTileURL(x: x, y: y, z: z)
        }
        
        let urlString = "\(vectorTileBaseURL)/_/\(z)/\(x)/\(y).png?key=\(key)"
        return URL(string: urlString)
    }
    
    // MARK: - Attribution & Licensing
    
    /// Attribution Text für TracesTrack
    static let attributionText = "© TracesTrack © OpenStreetMap contributors"
    
    /// Vollständige Lizenz-Information
    static let licenseInfo = """
    Diese Karten werden von TracesTrack bereitgestellt und basieren auf OpenStreetMap-Daten.
    
    TracesTrack: https://www.tracestrack.com/
    OpenStreetMap: https://www.openstreetmap.org/copyright
    
    Die OpenStreetMap-Daten stehen unter der Open Database License (ODbL).
    """
    
    // MARK: - Rate Limiting & Performance
    
    /// Maximale gleichzeitige Downloads
    static let maxConcurrentDownloads = 6
    
    /// Timeout für Tile Downloads
    static let downloadTimeout: TimeInterval = 15.0
    
    /// Retry-Anzahl bei fehlgeschlagenen Downloads
    static let maxRetryCount = 3
    
    // MARK: - Feature Availability
    
    /// Verfügbare Features basierend auf API Key
    enum Feature: CaseIterable {
        case topoMaps
        case vectorMaps
        case highResolution
        case offlineDownload
        
        var isAvailable: Bool {
            switch self {
            case .topoMaps, .vectorMaps, .highResolution, .offlineDownload:
                return TracesTrackConfig.hasAPIKey // Alle Features erfordern API Key
            }
        }
        
        var description: String {
            switch self {
            case .topoMaps:
                return "Topografische Karten"
            case .vectorMaps:
                return "Vector-basierte Karten"
            case .highResolution:
                return "Hochauflösende Tiles"
            case .offlineDownload:
                return "Offline-Download"
            }
        }
    }
    
    /// Gibt verfügbare Features zurück
    static var availableFeatures: [Feature] {
        return Feature.allCases.filter { $0.isAvailable }
    }
}

// MARK: - TracesTrack Error Types

enum TracesTrackError: LocalizedError {
    case noAPIKey
    case invalidURL
    case downloadFailed(String)
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API Key für TracesTrack Premium Features erforderlich"
        case .invalidURL:
            return "Ungültige TracesTrack URL"
        case .downloadFailed(let message):
            return "TracesTrack Download fehlgeschlagen: \(message)"
        case .rateLimitExceeded:
            return "TracesTrack Rate Limit erreicht"
        }
    }
} 