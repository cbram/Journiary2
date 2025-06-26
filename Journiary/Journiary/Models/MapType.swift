//
//  MapType.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import MapKit

// MARK: - Map Type Enumeration
enum MapType: String, CaseIterable, Identifiable {
    case appleStandard = "Apple Standard"
    case appleSatellite = "Apple Satellit"
    case osmStandard = "OpenStreetMap"
    case tracesTrackTopo = "TracesTrack Topo"
    case tracesTrackVector = "TracesTrack Vector"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .appleStandard:
            return "map"
        case .appleSatellite:
            return "globe.americas"
        case .osmStandard:
            return "mountain.2"
        case .tracesTrackTopo:
            return "map.fill"
        case .tracesTrackVector:
            return "map.circle.fill"
        }
    }
    
    var mapStyle: MapStyle {
        switch self {
        case .appleStandard:
            return .standard
        case .appleSatellite:
            return .hybrid
        case .osmStandard, .tracesTrackTopo, .tracesTrackVector:
            // Für OSM und TracesTrack verwenden wir vorerst Standard, da diese
            // über UIViewRepresentable mit MKMapView implementiert werden
            return .standard
        }
    }
    
    var isOSMType: Bool {
        return self == .osmStandard || self == .tracesTrackTopo || self == .tracesTrackVector
    }
    
    var displayName: String {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .appleStandard:
            return "Standard Apple Karten"
        case .appleSatellite:
            return "Apple Satellitenbilder"
        case .osmStandard:
            return "OpenStreetMap Standard"
        case .tracesTrackTopo:
            return "TracesTrack Topografische Karten (API Key erforderlich)"
        case .tracesTrackVector:
            return "TracesTrack Vector Karten (API Key erforderlich)"
        }
    }
    
    var requiresAttribution: Bool {
        return isOSMType
    }
    
    var attributionText: String {
        switch self {
        case .osmStandard:
            return "© OpenStreetMap contributors"
        case .tracesTrackTopo, .tracesTrackVector:
            return "© TracesTrack © OpenStreetMap contributors"
        case .appleStandard, .appleSatellite:
            return "© Apple"
        }
    }
}

// MARK: - UserDefaults Extension for MapType
extension UserDefaults {
    private static let selectedMapTypeKey = "selectedMapType"
    
    var selectedMapType: MapType {
        get {
            if let savedMapType = string(forKey: Self.selectedMapTypeKey),
               let mapType = MapType.allCases.first(where: { $0.rawValue == savedMapType }) {
                return mapType
            }
            return .appleStandard
        }
        set {
            set(newValue.rawValue, forKey: Self.selectedMapTypeKey)
            // Notification senden dass sich die Kartenwahl geändert hat
            NotificationCenter.default.post(name: .mapTypeChanged, object: nil)
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let mapTypeChanged = Notification.Name("mapTypeChanged")
} 