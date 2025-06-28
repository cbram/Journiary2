//
//  TripDTO.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import CoreData

/// Trip Data Transfer Object - Vereinfachte Version ohne Apollo
/// Für Datenübertragung zwischen Core Data und Demo GraphQL Service
struct TripDTO {
    let id: String
    let name: String
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
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
}

// MARK: - Core Data Conversion

extension TripDTO {
    /// Core Data Trip zu TripDTO konvertieren
    /// - Parameter coreDataTrip: Core Data Trip Entity
    /// - Returns: TripDTO oder nil
    static func from(coreData coreDataTrip: Trip) -> TripDTO? {
        guard let id = coreDataTrip.id?.uuidString,
              let name = coreDataTrip.name else {
            return nil
        }
        
        return TripDTO(
            id: id,
            name: name,
            description: coreDataTrip.tripDescription,
            startDate: coreDataTrip.startDate,
            endDate: coreDataTrip.endDate,
            isActive: coreDataTrip.isActive,
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
        if let uuidID = UUID(uuidString: id) {
            request.predicate = NSPredicate(format: "id == %@", uuidID as CVarArg)
        } else {
            request.predicate = NSPredicate(format: "name == %@", name)
        }
        
        let trip: Trip
        if let existingTrip = try? context.fetch(request).first {
            trip = existingTrip
        } else {
            trip = Trip(context: context)
            trip.id = UUID(uuidString: id) ?? UUID()
        }
        
        // Daten aktualisieren
        trip.name = name
        trip.tripDescription = description
        trip.startDate = startDate
        trip.endDate = endDate
        trip.isActive = isActive
        
        return trip
    }
}

// MARK: - GraphQL Conversion

extension TripDTO {
    /// Erstellt GraphQL TripInput Dictionary
    /// - Returns: Dictionary für GraphQL TripInput
    func toGraphQLInput() -> [String: Any] {
        var input: [String: Any] = [
            "name": name
        ]
        
        if let description = description {
            input["description"] = description
        }
        
        if let startDate = startDate {
            input["startDate"] = ISO8601DateFormatter().string(from: startDate)
        }
        
        if let endDate = endDate {
            input["endDate"] = ISO8601DateFormatter().string(from: endDate)
        }
        
        return input
    }
    
    /// Erstellt GraphQL UpdateTripInput Dictionary
    /// - Returns: Dictionary für GraphQL UpdateTripInput
    func toGraphQLUpdateInput() -> [String: Any] {
        var input: [String: Any] = [:]
        
        input["name"] = name
        
        if let description = description {
            input["description"] = description
        } else {
            input["description"] = NSNull()
        }
        
        if let startDate = startDate {
            input["startDate"] = ISO8601DateFormatter().string(from: startDate)
        } else {
            input["startDate"] = NSNull()
        }
        
        if let endDate = endDate {
            input["endDate"] = ISO8601DateFormatter().string(from: endDate)
        } else {
            input["endDate"] = NSNull()
        }
        
        return input
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