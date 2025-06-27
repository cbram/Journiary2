//
//  TripDTO.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import CoreData

/// Data Transfer Object für Trip-Entitäten
struct TripDTO: Codable, Identifiable {
    let id: String
    let name: String
    let startDate: Date
    let endDate: Date?
    let isActive: Bool
    let totalDistance: Double
    let locationCount: Int?
    let userId: String?
    
    // GraphQL Queries
    static let allTripsQuery = """
    query GetAllTrips {
      trips {
        id
        name
        startDate
        endDate
        isActive
        totalDistance
        locationCount
        userId
      }
    }
    """
    
    static let tripByIdQuery = """
    query GetTripById($id: String!) {
      trip(id: $id) {
        id
        name
        startDate
        endDate
        isActive
        totalDistance
        locationCount
        userId
      }
    }
    """
    
    static let createTripMutation = """
    mutation CreateTrip($input: TripInput!) {
      createTrip(input: $input) {
        id
        name
        startDate
        endDate
        isActive
        totalDistance
        locationCount
        userId
      }
    }
    """
    
    static let updateTripMutation = """
    mutation UpdateTrip($id: String!, $input: UpdateTripInput!) {
      updateTrip(id: $id, input: $input) {
        id
        name
        startDate
        endDate
        isActive
        totalDistance
        locationCount
        userId
      }
    }
    """
    
    // Konvertierung von Core Data zu DTO
    static func fromCoreData(_ trip: Trip) -> TripDTO {
        return TripDTO(
            id: trip.id?.uuidString ?? UUID().uuidString,
            name: trip.name ?? "Unbenannte Reise",
            startDate: trip.startDate ?? Date(),
            endDate: trip.endDate,
            isActive: trip.isActive,
            totalDistance: trip.totalDistance,
            locationCount: trip.routePoints?.count ?? 0,
            userId: nil // Wird später im Backend gesetzt
        )
    }
    
    // Konvertierung von DTO zu Core Data
    func createCoreDataObject(context: NSManagedObjectContext) -> Trip {
        let trip = Trip(context: context)
        updateCoreData(trip, context: context)
        return trip
    }
    
    // Aktualisiert ein bestehendes Core Data Objekt mit den Werten aus dem DTO
    func updateCoreData(_ trip: Trip, context: NSManagedObjectContext) {
        // ID setzen, wenn nicht vorhanden
        if trip.id == nil {
            trip.id = UUID(uuidString: id)
        }
        
        trip.name = name
        trip.startDate = startDate
        trip.endDate = endDate
        trip.isActive = isActive
        trip.totalDistance = totalDistance
        
        // Weitere Eigenschaften werden separat synchronisiert
    }
    
    // Konvertiert das DTO in ein Dictionary für GraphQL Mutationen
    func toInputDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "startDate": startDate.timeIntervalSince1970,
            "isActive": isActive,
            "totalDistance": totalDistance
        ]
        
        if let endDate = endDate {
            dict["endDate"] = endDate.timeIntervalSince1970
        }
        
        if let locationCount = locationCount {
            dict["locationCount"] = locationCount
        }
        
        if let userId = userId {
            dict["userId"] = userId
        }
        
        return dict
    }
    
    /// GraphQL-Mutation zum Löschen einer Reise
    static let deleteTripMutation = """
    mutation DeleteTrip($id: ID!) {
      deleteTrip(id: $id)
    }
    """
} 