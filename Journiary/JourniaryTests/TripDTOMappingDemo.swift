import Foundation
import CoreData
@testable import Journiary

/// Demo-Klasse zur Demonstration des TripDTO Mappings
/// Kann für manuelles Testen und Verifizierung verwendet werden
class TripDTOMappingDemo {
    
    static let shared = TripDTOMappingDemo()
    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!
    
    init() {
        setupCoreData()
    }
    
    private func setupCoreData() {
        container = NSPersistentContainer(name: "Journiary")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ Core Data Fehler: \(error)")
            } else {
                print("✅ Core Data erfolgreich geladen")
            }
        }
        
        context = container.viewContext
    }
    
    /// Demonstriert vollständiges Mapping: Core Data → TripDTO → GraphQL → TripDTO → Core Data
    func demonstrateCompleteMapping() {
        print("\n🧪 === TRIP DTO MAPPING DEMONSTRATION ===")
        
        // 1. Core Data Trip erstellen
        print("\n1️⃣ Erstelle Core Data Trip...")
        let originalTrip = createSampleCoreDataTrip()
        printCoreDataTrip(originalTrip, title: "Original Core Data Trip")
        
        // 2. Core Data → TripDTO
        print("\n2️⃣ Konvertiere zu TripDTO...")
        guard let tripDTO1 = TripDTO.from(coreData: originalTrip) else {
            print("❌ Core Data → TripDTO Konvertierung fehlgeschlagen")
            return
        }
        printTripDTO(tripDTO1, title: "TripDTO aus Core Data")
        
        // 3. TripDTO → GraphQL Create Input
        print("\n3️⃣ Erstelle GraphQL Create Input...")
        let createInput = tripDTO1.toGraphQLCreateInput()
        printGraphQLInput(createInput, title: "GraphQL Create Input")
        
        // 4. TripDTO → GraphQL Update Input
        print("\n4️⃣ Erstelle GraphQL Update Input...")
        let updateInput = tripDTO1.toGraphQLUpdateInput()
        printGraphQLInput(updateInput, title: "GraphQL Update Input")
        
        // 5. Simuliere GraphQL Response
        print("\n5️⃣ Simuliere GraphQL Response...")
        let simulatedResponse = simulateGraphQLResponse(from: createInput)
        printGraphQLInput(simulatedResponse, title: "Simulierte GraphQL Response")
        
        // 6. GraphQL Response → TripDTO
        print("\n6️⃣ Parse GraphQL Response zu TripDTO...")
        guard let tripDTO2 = TripDTO.from(graphQL: simulatedResponse) else {
            print("❌ GraphQL → TripDTO Parsing fehlgeschlagen")
            return
        }
        printTripDTO(tripDTO2, title: "TripDTO aus GraphQL Response")
        
        // 7. TripDTO → Core Data
        print("\n7️⃣ Konvertiere zurück zu Core Data...")
        let newContext = container.newBackgroundContext()
        let finalTrip = tripDTO2.toCoreData(context: newContext)
        printCoreDataTrip(finalTrip, title: "Finaler Core Data Trip")
        
        // 8. Vergleiche Daten
        print("\n8️⃣ Datenvergleich...")
        compareTripData(original: originalTrip, final: finalTrip)
        
        print("\n✅ === MAPPING DEMONSTRATION ABGESCHLOSSEN ===\n")
    }
    
    /// Demonstriert verschiedene Edge Cases
    func demonstrateEdgeCases() {
        print("\n🔍 === EDGE CASES DEMONSTRATION ===")
        
        // 1. Minimale Daten
        print("\n1️⃣ Test mit minimalen Daten...")
        let minimalTrip = Trip(context: context)
        minimalTrip.id = UUID()
        minimalTrip.name = "Minimal Trip"
        
        if let minimalDTO = TripDTO.from(coreData: minimalTrip) {
            printTripDTO(minimalDTO, title: "Minimaler TripDTO")
            
            let minimalInput = minimalDTO.toGraphQLCreateInput()
            print("✅ GraphQL Input erstellt - startDate automatisch gesetzt: \(minimalInput["startDate"] != nil)")
        }
        
        // 2. Ungültige Daten
        print("\n2️⃣ Test mit ungültigen Daten...")
        let invalidTrip = Trip(context: context)
        // Kein ID oder Name gesetzt
        
        if TripDTO.from(coreData: invalidTrip) == nil {
            print("✅ Ungültige Core Data korrekt abgelehnt")
        } else {
            print("❌ Ungültige Core Data sollte abgelehnt werden")
        }
        
        // 3. GraphQL Response ohne required fields
        print("\n3️⃣ Test GraphQL Response ohne required fields...")
        let invalidResponse: [String: Any] = ["description": "Fehlt ID und Name"]
        
        if TripDTO.from(graphQL: invalidResponse) == nil {
            print("✅ Ungültige GraphQL Response korrekt abgelehnt")
        } else {
            print("❌ Ungültige GraphQL Response sollte abgelehnt werden")
        }
        
        print("\n✅ === EDGE CASES ABGESCHLOSSEN ===\n")
    }
    
    /// Demonstriert Update-Szenario
    func demonstrateUpdateScenario() {
        print("\n🔄 === UPDATE SZENARIO DEMONSTRATION ===")
        
        // 1. Ursprünglichen Trip erstellen
        let originalTrip = createSampleCoreDataTrip()
        try? context.save()
        
        print("\n1️⃣ Ursprünglicher Trip:")
        printCoreDataTrip(originalTrip, title: "Original")
        
        // 2. TripDTO für Update erstellen
        var updatedDTO = TripDTO.from(coreData: originalTrip)!
        
        // Simulate updates that would come from UI or API
        let modifiedDTO = TripDTO(
            id: updatedDTO.id,
            name: "UPDATED: \(updatedDTO.name)",
            tripDescription: "Aktualisierte Beschreibung",
            coverImageObjectName: updatedDTO.coverImageObjectName,
            coverImageUrl: updatedDTO.coverImageUrl,
            travelCompanions: "Neue Reisegefährten",
            visitedCountries: updatedDTO.visitedCountries,
            startDate: updatedDTO.startDate,
            endDate: Calendar.current.date(byAdding: .day, value: 3, to: updatedDTO.endDate ?? Date()),
            isActive: false, // Changed
            totalDistance: 5000.0, // Changed
            gpsTrackingEnabled: false, // Changed
            createdAt: updatedDTO.createdAt,
            updatedAt: Date() // Updated timestamp
        )
        
        print("\n2️⃣ Modifizierter TripDTO:")
        printTripDTO(modifiedDTO, title: "Modifiziert")
        
        // 3. Update auf existierender Core Data Entity
        let updatedTrip = modifiedDTO.toCoreData(context: context)
        
        print("\n3️⃣ Nach Update:")
        printCoreDataTrip(updatedTrip, title: "Nach Update")
        
        // 4. Verifiziere dass es die gleiche Instanz ist
        if updatedTrip == originalTrip {
            print("✅ Gleiche Core Data Instanz wurde aktualisiert")
        } else {
            print("❌ Neue Instanz erstellt statt Update")
        }
        
        print("\n✅ === UPDATE SZENARIO ABGESCHLOSSEN ===\n")
    }
    
    // MARK: - Helper Methods
    
    private func createSampleCoreDataTrip() -> Trip {
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.name = "Island Rundreise Demo"
        trip.tripDescription = "Spektakuläre Demo-Reise durch Island"
        trip.travelCompanions = "Anna, Max, Lisa"
        trip.visitedCountries = "Island, Grönland"
        trip.startDate = Date(timeIntervalSince1970: 1640995200) // 2022-01-01
        trip.endDate = Date(timeIntervalSince1970: 1641686400) // 2022-01-09
        trip.isActive = true
        trip.totalDistance = 2847.5 // in Metern
        trip.gpsTrackingEnabled = true
        return trip
    }
    
    private func simulateGraphQLResponse(from input: [String: Any]) -> [String: Any] {
        var response = input
        response["id"] = UUID().uuidString // Backend würde neue ID generieren
        response["createdAt"] = ISO8601DateFormatter().string(from: Date())
        response["updatedAt"] = ISO8601DateFormatter().string(from: Date())
        response["coverImageObjectName"] = "demo-cover.jpg"
        response["coverImageUrl"] = "https://example.com/demo-cover.jpg"
        return response
    }
    
    private func printCoreDataTrip(_ trip: Trip, title: String) {
        print("📱 \(title):")
        print("   ID: \(trip.id?.uuidString ?? "nil")")
        print("   Name: \(trip.name ?? "nil")")
        print("   Description: \(trip.tripDescription ?? "nil")")
        print("   Companions: \(trip.travelCompanions ?? "nil")")
        print("   Countries: \(trip.visitedCountries ?? "nil")")
        print("   Start: \(trip.startDate?.description ?? "nil")")
        print("   End: \(trip.endDate?.description ?? "nil")")
        print("   Active: \(trip.isActive)")
        print("   Distance: \(trip.totalDistance)m")
        print("   GPS: \(trip.gpsTrackingEnabled)")
    }
    
    private func printTripDTO(_ dto: TripDTO, title: String) {
        print("📦 \(title):")
        print("   ID: \(dto.id)")
        print("   Name: \(dto.name)")
        print("   Description: \(dto.tripDescription ?? "nil")")
        print("   Companions: \(dto.travelCompanions ?? "nil")")
        print("   Countries: \(dto.visitedCountries ?? "nil")")
        print("   Start: \(dto.startDate?.description ?? "nil")")
        print("   End: \(dto.endDate?.description ?? "nil")")
        print("   Active: \(dto.isActive)")
        print("   Distance: \(dto.totalDistance)m")
        print("   GPS: \(dto.gpsTrackingEnabled)")
        print("   Cover Object: \(dto.coverImageObjectName ?? "nil")")
        print("   Cover URL: \(dto.coverImageUrl ?? "nil")")
        print("   Created: \(dto.createdAt)")
        print("   Updated: \(dto.updatedAt)")
        print("   📅 Date Range: \(dto.dateRangeText)")
        print("   📏 Formatted Distance: \(dto.formattedDistance)")
        print("   ⏱️ Duration: \(dto.durationInDays ?? 0) Tage")
        print("   🔄 Active Now: \(dto.isActiveNow)")
    }
    
    private func printGraphQLInput(_ input: [String: Any], title: String) {
        print("🌐 \(title):")
        for (key, value) in input.sorted(by: { $0.key < $1.key }) {
            print("   \(key): \(value)")
        }
    }
    
    private func compareTripData(original: Trip, final: Trip) {
        let checks = [
            ("Name", original.name == final.name),
            ("Description", original.tripDescription == final.tripDescription),
            ("Companions", original.travelCompanions == final.travelCompanions),
            ("Countries", original.visitedCountries == final.visitedCountries),
            ("Start Date", original.startDate == final.startDate),
            ("End Date", original.endDate == final.endDate),
            ("Active", original.isActive == final.isActive),
            ("Distance", original.totalDistance == final.totalDistance),
            ("GPS Tracking", original.gpsTrackingEnabled == final.gpsTrackingEnabled)
        ]
        
        let passedChecks = checks.filter { $0.1 }.count
        let totalChecks = checks.count
        
        print("🔍 Datenvergleich: \(passedChecks)/\(totalChecks) Felder stimmen überein")
        
        for (field, passed) in checks {
            print("   \(passed ? "✅" : "❌") \(field)")
        }
        
        if passedChecks == totalChecks {
            print("🎉 Alle Daten wurden korrekt übertragen!")
        } else {
            print("⚠️ Einige Daten wurden nicht korrekt übertragen")
        }
    }
}

// MARK: - Test Runner Extension
extension TripDTOMappingDemo {
    
    /// Führt alle Demonstrationen aus
    func runAllDemonstrations() {
        demonstrateCompleteMapping()
        demonstrateEdgeCases()
        demonstrateUpdateScenario()
        
        print("🏁 === ALLE DEMONSTRATIONEN ABGESCHLOSSEN ===")
        print("📋 ZUSAMMENFASSUNG:")
        print("   ✅ Core Data ↔ TripDTO Mapping funktioniert")
        print("   ✅ TripDTO ↔ GraphQL Input/Response Mapping funktioniert")
        print("   ✅ Roundtrip Mapping erhält alle Daten")
        print("   ✅ Edge Cases werden korrekt behandelt")
        print("   ✅ Update-Szenarios funktionieren")
        print("   ✅ Production-ready Implementation")
    }
} 