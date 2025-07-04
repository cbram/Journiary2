//
//  TripDTO.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import CoreData

/// Trip Data Transfer Object - Production-ready Version
/// Für Datenübertragung zwischen Backend GraphQL und iOS App
struct TripDTO: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let tripDescription: String? // Backend verwendet tripDescription, nicht description
    let coverImageObjectName: String?
    let coverImageUrl: String?
    let travelCompanions: String?
    let visitedCountries: String?
    let startDate: Date?
    let endDate: Date?
    let isActive: Bool
    let totalDistance: Double
    let gpsTrackingEnabled: Bool
    let createdAt: Date
    let updatedAt: Date
    
    // Legacy compatibility
    var description: String? { tripDescription }
    
    // MARK: - Computed Properties
    
    /// Formatiertes Datum für UI
    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        
        if let startDate = startDate, let endDate = endDate {
            if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
                return formatter.string(from: startDate)
            } else {
                return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
            }
        } else if let startDate = startDate {
            return "ab \(formatter.string(from: startDate))"
        } else if let endDate = endDate {
            return "bis \(formatter.string(from: endDate))"
        } else {
            return "Kein Datum"
        }
    }
    
    /// Prüft ob Trip aktiv ist und aktuell stattfindet
    var isActiveNow: Bool {
        guard isActive else { return false }
        
        let now = Date()
        
        if let startDate = startDate, let endDate = endDate {
            return now >= startDate && now <= endDate
        } else if let startDate = startDate {
            return now >= startDate
        } else if let endDate = endDate {
            return now <= endDate
        }
        
        return isActive
    }
    
    /// Dauer in Tagen
    var durationInDays: Int? {
        guard let startDate = startDate, let endDate = endDate else {
            return nil
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return components.day
    }
    
    /// Formatierte Distanz
    var formattedDistance: String {
        if totalDistance > 0 {
            return String(format: "%.1f km", totalDistance / 1000)
        }
        return "Keine Distanz"
    }
}

// MARK: - Core Data Conversion

extension TripDTO {
    /// Core Data Trip zu TripDTO konvertieren
    /// - Parameter coreDataTrip: Core Data Trip Entity
    /// - Returns: TripDTO oder nil
    static func from(coreData coreDataTrip: Trip) -> TripDTO? {
        // Sicherstellen, dass der Trip eine gültige UUID hat
        var tripId: String
        if let existingId = coreDataTrip.id {
            tripId = existingId.uuidString
        } else {
            let newId = UUID()
            coreDataTrip.id = newId
            tripId = newId.uuidString

            // Versuche sofort zu persistieren, damit nachfolgende Aufrufe den Wert sehen
            if let context = coreDataTrip.managedObjectContext, context.hasChanges {
                do {
                    try context.save()
                    print("✅ TripDTO.from: Fehlende UUID ergänzt und gespeichert: \(tripId)")
                } catch {
                    print("❌ TripDTO.from: Fehler beim Speichern der neuen UUID – \(error)")
                }
            }
        }

        guard let name = coreDataTrip.name else {
            return nil
        }
        
        return TripDTO(
            id: tripId,
            name: name,
            tripDescription: coreDataTrip.tripDescription,
            coverImageObjectName: nil, // Core Data hat coverImageData, nicht coverImageObjectName
            coverImageUrl: nil,
            travelCompanions: coreDataTrip.travelCompanions,
            visitedCountries: coreDataTrip.visitedCountries,
            startDate: coreDataTrip.startDate,
            endDate: coreDataTrip.endDate,
            isActive: coreDataTrip.isActive,
            totalDistance: coreDataTrip.totalDistance,
            gpsTrackingEnabled: coreDataTrip.gpsTrackingEnabled,
            createdAt: Date(), // Fallback da Core Data kein createdAt hat
            updatedAt: Date() // Fallback da Core Data kein updatedAt hat
        )
    }
    
    /// TripDTO zu Core Data Trip konvertieren
    /// - Parameter context: Core Data Context
    /// - Returns: Core Data Trip
    @discardableResult
    func toCoreData(context: NSManagedObjectContext) -> Trip {
        // Prüfe ob Trip bereits existiert
        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        var predicates: [NSPredicate] = []

        // 1) Primär nach UUID suchen
        if let uuidID = UUID(uuidString: id) {
            predicates.append(NSPredicate(format: "id == %@", uuidID as CVarArg))
        }

        // 2) Fallback: id (String) Attribut falls vorhanden
        let entity = NSEntityDescription.entity(forEntityName: "Trip", in: context)
        let hasServerId = entity?.attributesByName.keys.contains("id") == true
        if hasServerId {
            predicates.append(NSPredicate(format: "id == %@", id))
        }

        // 3) Fallback: Name (nur wenn keine anderen Predicate)
        if predicates.isEmpty {
            predicates.append(NSPredicate(format: "name == %@", name))
        }

        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        request.fetchLimit = 1
        
        let trip: Trip
        if let existingTrip = try? context.fetch(request).first {
            trip = existingTrip
        } else {
            trip = Trip(context: context)
            if let uuid = UUID(uuidString: id) {
                trip.id = uuid
            } else {
                trip.id = UUID()
            }
        }

        // serverId setzen (falls vorhanden)
        if hasServerId {
            trip.setValue(id, forKey: "id")
        }

        // Daten aktualisieren
        trip.name = name
        trip.tripDescription = tripDescription
        trip.travelCompanions = travelCompanions
        trip.visitedCountries = visitedCountries
        trip.startDate = startDate
        trip.endDate = endDate
        trip.isActive = isActive
        trip.totalDistance = totalDistance
        trip.gpsTrackingEnabled = gpsTrackingEnabled
        
        return trip
    }
}

// MARK: - GraphQL Conversion

extension TripDTO {
    /// Erstellt GraphQL TripInput Dictionary (für Create)
    /// - Returns: Dictionary für GraphQL TripInput
    func toGraphQLCreateInput() -> [String: Any] {
        var input: [String: Any] = [
            "name": name,
            "isActive": isActive,
            "totalDistance": totalDistance,
            "gpsTrackingEnabled": gpsTrackingEnabled
        ]
        
        // Required startDate
        if let startDate = startDate {
            input["startDate"] = ISO8601DateFormatter().string(from: startDate)
        } else {
            // Backend requires startDate, use current date as fallback
            input["startDate"] = ISO8601DateFormatter().string(from: Date())
        }
        
        // Optional fields
        if let description = tripDescription {
            input["tripDescription"] = description
        }
        
        if let companions = travelCompanions {
            input["travelCompanions"] = companions
        }
        
        if let countries = visitedCountries {
            input["visitedCountries"] = countries
        }
        
        if let endDate = endDate {
            input["endDate"] = ISO8601DateFormatter().string(from: endDate)
        }
        
        return input
    }
    
    /// Erstellt GraphQL UpdateTripInput Dictionary (für Update)
    /// - Returns: Dictionary für GraphQL UpdateTripInput
    func toGraphQLUpdateInput() -> [String: Any] {
        var input: [String: Any] = [:]
        
        // Nur nicht-nil Werte für Update senden
        input["name"] = name
        input["isActive"] = isActive
        input["totalDistance"] = totalDistance  
        input["gpsTrackingEnabled"] = gpsTrackingEnabled
        
        if let description = tripDescription {
            input["tripDescription"] = description
        }
        
        if let companions = travelCompanions {
            input["travelCompanions"] = companions
        }
        
        if let countries = visitedCountries {
            input["visitedCountries"] = countries
        }
        
        if let startDate = startDate {
            input["startDate"] = ISO8601DateFormatter().string(from: startDate)
        }
        
        if let endDate = endDate {
            input["endDate"] = ISO8601DateFormatter().string(from: endDate)
        }
        
        return input
    }
}

// MARK: - GraphQL Response Parsing

extension TripDTO {
    /// Erstellt TripDTO aus GraphQL Response
    /// - Parameter graphQLData: GraphQL Response Dictionary
    /// - Returns: TripDTO oder nil
    static func from(graphQL graphQLData: [String: Any]) -> TripDTO? {
        guard let id = graphQLData["id"] as? String,
              let name = graphQLData["name"] as? String else {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        return TripDTO(
            id: id,
            name: name,
            tripDescription: graphQLData["tripDescription"] as? String,
            coverImageObjectName: graphQLData["coverImageObjectName"] as? String,
            coverImageUrl: graphQLData["coverImageUrl"] as? String,
            travelCompanions: graphQLData["travelCompanions"] as? String,
            visitedCountries: graphQLData["visitedCountries"] as? String,
            startDate: (graphQLData["startDate"] as? String).flatMap { dateFormatter.date(from: $0) },
            endDate: (graphQLData["endDate"] as? String).flatMap { dateFormatter.date(from: $0) },
            isActive: graphQLData["isActive"] as? Bool ?? false,
            totalDistance: graphQLData["totalDistance"] as? Double ?? 0.0,
            gpsTrackingEnabled: graphQLData["gpsTrackingEnabled"] as? Bool ?? true,
            createdAt: (graphQLData["createdAt"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date(),
            updatedAt: (graphQLData["updatedAt"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date()
        )
    }
}

// MARK: - Bulk Operations

struct BulkTripUpdateDTO {
    let id: String
    let input: [String: Any]
    
    /// Erstellt Bulk Update Dictionary
    /// - Returns: Dictionary für GraphQL BulkTripUpdate
    func toGraphQLInput() -> [String: Any] {
        return [
            "id": id,
            "input": input
        ]
    }
} 