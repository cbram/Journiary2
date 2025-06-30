import XCTest
import CoreData
@testable import Journiary

final class TripDTOMappingTests: XCTestCase {
    
    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // In-Memory Core Data Stack für Tests
        container = NSPersistentContainer(name: "Journiary")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data Fehler: \(error)")
            }
        }
        
        context = container.viewContext
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Core Data → TripDTO Tests
    
    func testCoreDataToTripDTO_AllFieldsMapping() throws {
        // Given: Core Data Trip mit allen Feldern
        let coreDataTrip = Trip(context: context)
        let tripId = UUID()
        coreDataTrip.id = tripId
        coreDataTrip.name = "Island Rundreise"
        coreDataTrip.tripDescription = "Spektakuläre Reise durch Island"
        coreDataTrip.travelCompanions = "Anna, Max"
        coreDataTrip.visitedCountries = "Island, Grönland"
        coreDataTrip.startDate = Date(timeIntervalSince1970: 1640995200) // 2022-01-01
        coreDataTrip.endDate = Date(timeIntervalSince1970: 1641081600) // 2022-01-02
        coreDataTrip.isActive = true
        coreDataTrip.totalDistance = 2500.0 // in Metern
        coreDataTrip.gpsTrackingEnabled = false
        
        // Owner hinzufügen für Multi-User Kompatibilität
        let owner = User(context: context)
        owner.id = UUID()
        owner.username = "testuser"
        owner.email = "test@example.com"
        owner.firstName = "Test"
        owner.lastName = "User"
        owner.isCurrentUser = true
        coreDataTrip.owner = owner
        
        // When: Core Data → TripDTO
        let tripDTO = TripDTO.from(coreData: coreDataTrip)
        
        // Then: Alle Felder korrekt gemappt
        XCTAssertNotNil(tripDTO)
        XCTAssertEqual(tripDTO?.id, tripId.uuidString)
        XCTAssertEqual(tripDTO?.name, "Island Rundreise")
        XCTAssertEqual(tripDTO?.tripDescription, "Spektakuläre Reise durch Island")
        XCTAssertEqual(tripDTO?.travelCompanions, "Anna, Max")
        XCTAssertEqual(tripDTO?.visitedCountries, "Island, Grönland")
        XCTAssertEqual(tripDTO?.startDate, Date(timeIntervalSince1970: 1640995200))
        XCTAssertEqual(tripDTO?.endDate, Date(timeIntervalSince1970: 1641081600))
        XCTAssertEqual(tripDTO?.isActive, true)
        XCTAssertEqual(tripDTO?.totalDistance, 2500.0)
        XCTAssertEqual(tripDTO?.gpsTrackingEnabled, false)
        XCTAssertNotNil(tripDTO?.createdAt)
        XCTAssertNotNil(tripDTO?.updatedAt)
    }
    
    func testCoreDataToTripDTO_MinimalFields() throws {
        // Given: Core Data Trip mit nur required fields
        let coreDataTrip = Trip(context: context)
        let tripId = UUID()
        coreDataTrip.id = tripId
        coreDataTrip.name = "Minimal Trip"
        
        // Owner auch bei minimalen Tests hinzufügen
        let owner = User(context: context)
        owner.id = UUID()
        owner.username = "minimal_user"
        owner.email = "minimal@example.com"
        owner.firstName = "Minimal"
        owner.lastName = "User"
        owner.isCurrentUser = true
        coreDataTrip.owner = owner
        
        // When: Core Data → TripDTO
        let tripDTO = TripDTO.from(coreData: coreDataTrip)
        
        // Then: Required fields gemappt, optional fields nil
        XCTAssertNotNil(tripDTO)
        XCTAssertEqual(tripDTO?.id, tripId.uuidString)
        XCTAssertEqual(tripDTO?.name, "Minimal Trip")
        XCTAssertNil(tripDTO?.tripDescription)
        XCTAssertNil(tripDTO?.travelCompanions)
        XCTAssertNil(tripDTO?.visitedCountries)
        XCTAssertNil(tripDTO?.startDate)
        XCTAssertNil(tripDTO?.endDate)
    }
    
    func testCoreDataToTripDTO_InvalidData() throws {
        // Given: Core Data Trip ohne required fields
        let coreDataTrip = Trip(context: context)
        // Kein id oder name gesetzt
        
        // When: Core Data → TripDTO
        let tripDTO = TripDTO.from(coreData: coreDataTrip)
        
        // Then: nil zurückgegeben
        XCTAssertNil(tripDTO)
    }
    
    // MARK: - TripDTO → Core Data Tests
    
    func testTripDTOToCoreData_AllFieldsMapping() throws {
        // Given: TripDTO mit allen Feldern
        let tripDTO = TripDTO(
            id: UUID().uuidString,
            name: "Norwegen Abenteuer",
            tripDescription: "Fjorde und Nordlichter",
            coverImageObjectName: "cover-image.jpg",
            coverImageUrl: "https://example.com/cover.jpg",
            travelCompanions: "Lisa, Tom",
            visitedCountries: "Norwegen, Schweden",
            startDate: Date(timeIntervalSince1970: 1640995200),
            endDate: Date(timeIntervalSince1970: 1641081600),
            isActive: false,
            totalDistance: 3200.0,
            gpsTrackingEnabled: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When: TripDTO → Core Data
        let coreDataTrip = tripDTO.toCoreData(context: context)
        
        // Then: Alle Felder korrekt gemappt
        XCTAssertEqual(coreDataTrip.id?.uuidString, tripDTO.id)
        XCTAssertEqual(coreDataTrip.name, "Norwegen Abenteuer")
        XCTAssertEqual(coreDataTrip.tripDescription, "Fjorde und Nordlichter")
        XCTAssertEqual(coreDataTrip.travelCompanions, "Lisa, Tom")
        XCTAssertEqual(coreDataTrip.visitedCountries, "Norwegen, Schweden")
        XCTAssertEqual(coreDataTrip.startDate, Date(timeIntervalSince1970: 1640995200))
        XCTAssertEqual(coreDataTrip.endDate, Date(timeIntervalSince1970: 1641081600))
        XCTAssertEqual(coreDataTrip.isActive, false)
        XCTAssertEqual(coreDataTrip.totalDistance, 3200.0)
        XCTAssertEqual(coreDataTrip.gpsTrackingEnabled, true)
    }
    
    func testTripDTOToCoreData_UpdateExisting() throws {
        // Given: Existierender Core Data Trip
        let existingTrip = Trip(context: context)
        let tripId = UUID()
        existingTrip.id = tripId
        existingTrip.name = "Alter Name"
        existingTrip.isActive = false
        
        try context.save()
        
        // When: TripDTO mit gleicher ID zu Core Data
        let tripDTO = TripDTO(
            id: tripId.uuidString,
            name: "Neuer Name",
            tripDescription: "Neue Beschreibung",
            coverImageObjectName: nil,
            coverImageUrl: nil,
            travelCompanions: nil,
            visitedCountries: nil,
            startDate: Date(),
            endDate: nil,
            isActive: true,
            totalDistance: 1000.0,
            gpsTrackingEnabled: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let updatedTrip = tripDTO.toCoreData(context: context)
        
        // Then: Existierender Trip wurde aktualisiert
        XCTAssertEqual(updatedTrip, existingTrip) // Gleiche Instanz
        XCTAssertEqual(updatedTrip.name, "Neuer Name")
        XCTAssertEqual(updatedTrip.tripDescription, "Neue Beschreibung")
        XCTAssertEqual(updatedTrip.isActive, true)
        XCTAssertEqual(updatedTrip.totalDistance, 1000.0)
        XCTAssertEqual(updatedTrip.gpsTrackingEnabled, true)
    }
    
    // MARK: - GraphQL Input Generation Tests
    
    func testToGraphQLCreateInput_AllFields() throws {
        // Given: TripDTO mit allen Feldern
        let tripDTO = TripDTO(
            id: UUID().uuidString,
            name: "Deutschland Tour",
            tripDescription: "Schöne Städte besuchen",
            coverImageObjectName: nil,
            coverImageUrl: nil,
            travelCompanions: "Familie Schmidt",
            visitedCountries: "Deutschland, Österreich",
            startDate: Date(timeIntervalSince1970: 1640995200),
            endDate: Date(timeIntervalSince1970: 1641081600),
            isActive: true,
            totalDistance: 1500.0,
            gpsTrackingEnabled: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When: GraphQL Create Input generieren
        let input = tripDTO.toGraphQLCreateInput()
        
        // Then: Alle required und optional Felder korrekt
        XCTAssertEqual(input["name"] as? String, "Deutschland Tour")
        XCTAssertEqual(input["tripDescription"] as? String, "Schöne Städte besuchen")
        XCTAssertEqual(input["travelCompanions"] as? String, "Familie Schmidt")
        XCTAssertEqual(input["visitedCountries"] as? String, "Deutschland, Österreich")
        XCTAssertEqual(input["isActive"] as? Bool, true)
        XCTAssertEqual(input["totalDistance"] as? Double, 1500.0)
        XCTAssertEqual(input["gpsTrackingEnabled"] as? Bool, false)
        XCTAssertNotNil(input["startDate"] as? String)
        XCTAssertNotNil(input["endDate"] as? String)
    }
    
    func testToGraphQLCreateInput_MinimalFields() throws {
        // Given: TripDTO mit nur required fields
        let tripDTO = TripDTO(
            id: UUID().uuidString,
            name: "Minimal Trip",
            tripDescription: nil,
            coverImageObjectName: nil,
            coverImageUrl: nil,
            travelCompanions: nil,
            visitedCountries: nil,
            startDate: nil, // Kein startDate
            endDate: nil,
            isActive: false,
            totalDistance: 0.0,
            gpsTrackingEnabled: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When: GraphQL Create Input generieren
        let input = tripDTO.toGraphQLCreateInput()
        
        // Then: Required fields vorhanden, startDate automatisch gesetzt
        XCTAssertEqual(input["name"] as? String, "Minimal Trip")
        XCTAssertEqual(input["isActive"] as? Bool, false)
        XCTAssertEqual(input["totalDistance"] as? Double, 0.0)
        XCTAssertEqual(input["gpsTrackingEnabled"] as? Bool, true)
        XCTAssertNotNil(input["startDate"] as? String) // Fallback auf aktuelles Datum
        XCTAssertNil(input["tripDescription"])
        XCTAssertNil(input["endDate"])
    }
    
    func testToGraphQLUpdateInput() throws {
        // Given: TripDTO für Update
        let tripDTO = TripDTO(
            id: UUID().uuidString,
            name: "Updated Trip",
            tripDescription: "Updated description",
            coverImageObjectName: nil,
            coverImageUrl: nil,
            travelCompanions: "Updated companions",
            visitedCountries: nil,
            startDate: Date(timeIntervalSince1970: 1640995200),
            endDate: nil,
            isActive: false,
            totalDistance: 2000.0,
            gpsTrackingEnabled: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When: GraphQL Update Input generieren
        let input = tripDTO.toGraphQLUpdateInput()
        
        // Then: Alle Felder für Update vorhanden
        XCTAssertEqual(input["name"] as? String, "Updated Trip")
        XCTAssertEqual(input["tripDescription"] as? String, "Updated description")
        XCTAssertEqual(input["travelCompanions"] as? String, "Updated companions")
        XCTAssertEqual(input["isActive"] as? Bool, false)
        XCTAssertEqual(input["totalDistance"] as? Double, 2000.0)
        XCTAssertEqual(input["gpsTrackingEnabled"] as? Bool, false)
        XCTAssertNotNil(input["startDate"] as? String)
        XCTAssertNil(input["visitedCountries"]) // nil Werte nicht in Update Input
    }
    
    // MARK: - GraphQL Response Parsing Tests
    
    func testFromGraphQLResponse_AllFields() throws {
        // Given: GraphQL Response mit allen Feldern
        let dateFormatter = ISO8601DateFormatter()
        let startDateString = dateFormatter.string(from: Date(timeIntervalSince1970: 1640995200))
        let endDateString = dateFormatter.string(from: Date(timeIntervalSince1970: 1641081600))
        let createdAtString = dateFormatter.string(from: Date())
        let updatedAtString = dateFormatter.string(from: Date())
        
        let graphQLResponse: [String: Any] = [
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "name": "GraphQL Trip",
            "tripDescription": "From GraphQL",
            "coverImageObjectName": "cover.jpg",
            "coverImageUrl": "https://example.com/cover.jpg",
            "travelCompanions": "GraphQL Users",
            "visitedCountries": "GraphQL Land",
            "startDate": startDateString,
            "endDate": endDateString,
            "isActive": true,
            "totalDistance": 5000.0,
            "gpsTrackingEnabled": false,
            "createdAt": createdAtString,
            "updatedAt": updatedAtString
        ]
        
        // When: GraphQL Response → TripDTO
        let tripDTO = TripDTO.from(graphQL: graphQLResponse)
        
        // Then: Alle Felder korrekt geparst
        XCTAssertNotNil(tripDTO)
        XCTAssertEqual(tripDTO?.id, "123e4567-e89b-12d3-a456-426614174000")
        XCTAssertEqual(tripDTO?.name, "GraphQL Trip")
        XCTAssertEqual(tripDTO?.tripDescription, "From GraphQL")
        XCTAssertEqual(tripDTO?.coverImageObjectName, "cover.jpg")
        XCTAssertEqual(tripDTO?.coverImageUrl, "https://example.com/cover.jpg")
        XCTAssertEqual(tripDTO?.travelCompanions, "GraphQL Users")
        XCTAssertEqual(tripDTO?.visitedCountries, "GraphQL Land")
        XCTAssertEqual(tripDTO?.startDate, Date(timeIntervalSince1970: 1640995200))
        XCTAssertEqual(tripDTO?.endDate, Date(timeIntervalSince1970: 1641081600))
        XCTAssertEqual(tripDTO?.isActive, true)
        XCTAssertEqual(tripDTO?.totalDistance, 5000.0)
        XCTAssertEqual(tripDTO?.gpsTrackingEnabled, false)
        XCTAssertNotNil(tripDTO?.createdAt)
        XCTAssertNotNil(tripDTO?.updatedAt)
    }
    
    func testFromGraphQLResponse_MinimalFields() throws {
        // Given: GraphQL Response mit nur required fields
        let graphQLResponse: [String: Any] = [
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "name": "Minimal GraphQL Trip"
        ]
        
        // When: GraphQL Response → TripDTO
        let tripDTO = TripDTO.from(graphQL: graphQLResponse)
        
        // Then: Required fields vorhanden, optional mit defaults
        XCTAssertNotNil(tripDTO)
        XCTAssertEqual(tripDTO?.id, "123e4567-e89b-12d3-a456-426614174000")
        XCTAssertEqual(tripDTO?.name, "Minimal GraphQL Trip")
        XCTAssertNil(tripDTO?.tripDescription)
        XCTAssertEqual(tripDTO?.isActive, false) // Default
        XCTAssertEqual(tripDTO?.totalDistance, 0.0) // Default
        XCTAssertEqual(tripDTO?.gpsTrackingEnabled, true) // Default
    }
    
    func testFromGraphQLResponse_InvalidData() throws {
        // Given: GraphQL Response ohne required fields
        let graphQLResponse: [String: Any] = [
            "tripDescription": "Missing required fields"
        ]
        
        // When: GraphQL Response → TripDTO
        let tripDTO = TripDTO.from(graphQL: graphQLResponse)
        
        // Then: nil zurückgegeben
        XCTAssertNil(tripDTO)
    }
    
    // MARK: - Roundtrip Tests
    
    func testRoundtrip_CoreDataToGraphQLToCoreData() throws {
        // Given: Core Data Trip
        let originalTrip = Trip(context: context)
        let tripId = UUID()
        originalTrip.id = tripId
        originalTrip.name = "Roundtrip Test"
        originalTrip.tripDescription = "Test Beschreibung"
        originalTrip.startDate = Date(timeIntervalSince1970: 1640995200)
        originalTrip.isActive = true
        originalTrip.totalDistance = 1500.0
        originalTrip.gpsTrackingEnabled = false
        
        // When: Core Data → TripDTO → GraphQL → TripDTO → Core Data
        let tripDTO1 = TripDTO.from(coreData: originalTrip)
        XCTAssertNotNil(tripDTO1)
        
        let graphQLInput = tripDTO1!.toGraphQLCreateInput()
        XCTAssertNotNil(graphQLInput)
        
        // Simuliere GraphQL Response (würde normalerweise vom Backend kommen)
        let graphQLResponse: [String: Any] = [
            "id": tripDTO1!.id,
            "name": graphQLInput["name"] as! String,
            "tripDescription": graphQLInput["tripDescription"] as? String,
            "startDate": graphQLInput["startDate"] as! String,
            "isActive": graphQLInput["isActive"] as! Bool,
            "totalDistance": graphQLInput["totalDistance"] as! Double,
            "gpsTrackingEnabled": graphQLInput["gpsTrackingEnabled"] as! Bool
        ]
        
        let tripDTO2 = TripDTO.from(graphQL: graphQLResponse)
        XCTAssertNotNil(tripDTO2)
        
        let newContext = container.newBackgroundContext()
        let finalTrip = tripDTO2!.toCoreData(context: newContext)
        
        // Then: Daten bleiben konsistent
        XCTAssertEqual(finalTrip.name, originalTrip.name)
        XCTAssertEqual(finalTrip.tripDescription, originalTrip.tripDescription)
        XCTAssertEqual(finalTrip.isActive, originalTrip.isActive)
        XCTAssertEqual(finalTrip.totalDistance, originalTrip.totalDistance)
        XCTAssertEqual(finalTrip.gpsTrackingEnabled, originalTrip.gpsTrackingEnabled)
    }
    
    // MARK: - Date Formatting Tests
    
    func testDateFormatting_ISO8601() throws {
        // Given: TripDTO mit Datum
        let testDate = Date(timeIntervalSince1970: 1640995200) // 2022-01-01 00:00:00 UTC
        let tripDTO = TripDTO(
            id: UUID().uuidString,
            name: "Date Test",
            tripDescription: nil,
            coverImageObjectName: nil,
            coverImageUrl: nil,
            travelCompanions: nil,
            visitedCountries: nil,
            startDate: testDate,
            endDate: nil,
            isActive: false,
            totalDistance: 0.0,
            gpsTrackingEnabled: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When: GraphQL Input generieren
        let input = tripDTO.toGraphQLCreateInput()
        
        // Then: Datum als ISO8601 String
        let startDateString = input["startDate"] as? String
        XCTAssertNotNil(startDateString)
        
        let formatter = ISO8601DateFormatter()
        let parsedDate = formatter.date(from: startDateString!)
        XCTAssertEqual(parsedDate, testDate)
    }
} 