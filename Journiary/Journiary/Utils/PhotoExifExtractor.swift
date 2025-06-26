//
//  PhotoExifExtractor.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import SwiftUI
import CoreLocation
import ImageIO

// MARK: - EXIF-Datenstrukturen

struct PhotoExifInfo: Identifiable {
    let id = UUID()
    var captureDate: Date?
    var coordinate: CLLocationCoordinate2D?
    var locationName: String?
    
    var hasValidData: Bool {
        return captureDate != nil || coordinate != nil
    }
    
    var hasLocation: Bool {
        return coordinate != nil
    }
    
    var hasDate: Bool {
        return captureDate != nil
    }
}

// MARK: - EXIF-Extraktor Utility

class PhotoExifExtractor {
    static func extractExifData(from imageData: Data) -> PhotoExifInfo {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return PhotoExifInfo()
        }
        
        var exifInfo = PhotoExifInfo()
        
        // Datum extrahieren
        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateTimeString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            exifInfo.captureDate = formatter.date(from: dateTimeString)
        }
        
        // Alternative Datum-Quellen versuchen
        if exifInfo.captureDate == nil {
            // Versuche TIFF DateTime (manchmal anders formatiert)
            if let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
               let dateTimeString = tiffDict[kCGImagePropertyTIFFDateTime as String] as? String {
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                exifInfo.captureDate = formatter.date(from: dateTimeString)
            }
        }
        
        // GPS-Koordinaten extrahieren
        if let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let latitude = extractGPSCoordinate(from: gpsDict, for: kCGImagePropertyGPSLatitude as String, 
                                                  ref: kCGImagePropertyGPSLatitudeRef as String),
               let longitude = extractGPSCoordinate(from: gpsDict, for: kCGImagePropertyGPSLongitude as String, 
                                                   ref: kCGImagePropertyGPSLongitudeRef as String) {
                exifInfo.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
        }
        
        return exifInfo
    }
    
    private static func extractGPSCoordinate(from gpsDict: [String: Any], for key: String, ref: String) -> Double? {
        guard let coordinate = gpsDict[key] as? Double,
              let reference = gpsDict[ref] as? String else {
            return nil
        }
        
        // Süden und Westen sind negative Werte
        let multiplier = (reference == "S" || reference == "W") ? -1.0 : 1.0
        return coordinate * multiplier
    }
    
    static func getLocationName(for coordinate: CLLocationCoordinate2D) async -> String {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var components: [String] = []
                
                if let name = placemark.name, !name.isEmpty {
                    components.append(name)
                }
                if let locality = placemark.locality, !locality.isEmpty {
                    components.append(locality)
                }
                if let country = placemark.country, !country.isEmpty {
                    components.append(country)
                }
                
                return components.isEmpty ? "Unbekannter Ort" : components.joined(separator: ", ")
            }
        } catch {
            print("Geocoding Fehler: \(error.localizedDescription)")
        }
        
        return "Unbekannter Ort"
    }
}

// MARK: - UI-Komponenten

struct ExifSuggestionCard: View {
    let photoInfo: PhotoExifInfo
    let index: Int
    let onApplyDate: (Date) -> Void
    let onApplyLocation: (CLLocationCoordinate2D, String) -> Void
    
    @State private var dateApplied = false
    @State private var locationApplied = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Foto-Icon
            Image(systemName: "photo")
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                // Datum-Information (kompakt)
                if let captureDate = photoInfo.captureDate {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Aufnahme:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(captureDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dateApplied = true
                            }
                            onApplyDate(captureDate)
                            
                            // Haptic Feedback
                            let haptic = UINotificationFeedbackGenerator()
                            haptic.notificationOccurred(.success)
                        }) {
                            Image(systemName: dateApplied ? "checkmark.circle.fill" : "checkmark.circle")
                                .foregroundColor(dateApplied ? .green : .blue)
                                .font(.title3)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Standort-Information (kompakt)
                if let coordinate = photoInfo.coordinate {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Standort:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            if let locationName = photoInfo.locationName {
                                Text(locationName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                            } else {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                    Text("Lädt...")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        if photoInfo.locationName != nil {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    locationApplied = true
                                }
                                onApplyLocation(coordinate, photoInfo.locationName ?? "Unbekannter Ort")
                                
                                // Haptic Feedback
                                let haptic = UINotificationFeedbackGenerator()
                                haptic.notificationOccurred(.success)
                            }) {
                                Image(systemName: locationApplied ? "checkmark.circle.fill" : "checkmark.circle")
                                    .foregroundColor(locationApplied ? .green : .blue)
                                    .font(.title3)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct EditExifSuggestionCard: View {
    let photoInfo: PhotoExifInfo
    let index: Int
    let memory: Memory
    let onApplyDate: (Date) -> Void
    
    @State private var dateApplied = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Foto-Icon
            Image(systemName: "photo")
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                // Datum-Information (kompakt)
                if let captureDate = photoInfo.captureDate {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Aufnahme:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(captureDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            // Vergleich mit aktuellem Datum der Erinnerung (sehr kompakt)
                            if let currentTimestamp = memory.timestamp {
                                let timeDifference = abs(captureDate.timeIntervalSince(currentTimestamp))
                                if timeDifference > 300 { // Mehr als 5 Minuten Unterschied
                                    Text("Aktuell: \(currentTimestamp.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dateApplied = true
                            }
                            onApplyDate(captureDate)
                            
                            // Haptic Feedback
                            let haptic = UINotificationFeedbackGenerator()
                            haptic.notificationOccurred(.success)
                        }) {
                            Image(systemName: dateApplied ? "checkmark.circle.fill" : "checkmark.circle")
                                .foregroundColor(dateApplied ? .green : .blue)
                                .font(.title3)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // GPS-Information (sehr kompakt)
                if let coordinate = photoInfo.coordinate {
                    Text("GPS: Lat: \(coordinate.latitude, specifier: "%.3f"), Lng: \(coordinate.longitude, specifier: "%.3f") (nur Info)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
} 