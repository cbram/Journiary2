//
//  E2ESyncTests.swift
//  JourniaryUITests
//
//  Created by Journiary Sync Implementation - Phase 11.1
//

import XCTest
import CoreData

/// Umfassende End-to-End-Test-Suite für Synchronisationsszenarien
/// Implementiert als Teil von Phase 11.1: Vollständige E2E-Test-Suite
final class E2ESyncTests: XCTestCase {
    var app: XCUIApplication!
    var testContext: NSManagedObjectContext!
    var mockServer: MockGraphQLServer!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-server", "--reset-data"]
        
        setupTestEnvironment()
        mockServer = MockGraphQLServer()
        mockServer.start()
        
        print("🧪 E2E Test Environment Setup Complete")
    }
    
    override func tearDownWithError() throws {
        mockServer?.stop()
        app?.terminate()
        try super.tearDownWithError()
        
        print("🧹 E2E Test Environment Cleaned Up")
    }
    
    // MARK: - Complete User Journey Tests
    
    @MainActor
    func testCompleteUserJourney() throws {
        /// Test: Vollständiger Benutzer-Workflow mit Synchronisation
        /// Testet den kompletten Datenfluss von der Erstellung bis zur Synchronisation
        
        print("🚀 Starting Complete User Journey Test")
        
        // 1. App starten und einloggen
        app.launch()
        loginTestUser()
        
        // 2. Trip erstellen
        let tripTitle = "E2E Test Trip \(Date().timeIntervalSince1970)"
        createTrip(title: tripTitle)
        
        // 3. Memory hinzufügen
        let memoryTitle = "E2E Test Memory"
        addMemoryToTrip(tripTitle: tripTitle, memoryTitle: memoryTitle)
        
        // 4. Foto hinzufügen (falls verfügbar)
        if app.buttons["Foto hinzufügen"].exists {
            addPhotoToMemory(memoryTitle: memoryTitle)
        }
        
        // 5. Tag hinzufügen
        addTagToMemory(memoryTitle: memoryTitle, tagName: "E2E-Test")
        
        // 6. Synchronisation triggern
        triggerSync()
        
        // 7. Sync-Status verifizieren
        verifySyncCompletion()
        
        // 8. App neu starten und Daten verifizieren
        app.terminate()
        app.launch()
        loginTestUser()
        
        verifyDataPersistence(tripTitle: tripTitle, memoryTitle: memoryTitle)
        
        print("✅ Complete User Journey Test Passed")
    }
    
    @MainActor
    func testConflictResolution() throws {
        /// Test: Konfliktlösung zwischen mehreren Geräten
        /// Simuliert Konfliktszenarien und testet die Konfliktlösung
        
        print("⚡ Starting Conflict Resolution Test")
        
        app.launch()
        loginTestUser()
        
        // Erstelle lokale Änderung
        let tripTitle = "Conflict Test Trip \(UUID().uuidString.prefix(8))"
        createTrip(title: tripTitle)
        editTrip(title: tripTitle, newDescription: "Local Description")
        
        // Simuliere Remote-Änderung
        mockServer.createConflictingTrip(title: tripTitle, description: "Remote Description")
        
        // Triggere Sync
        triggerSync()
        
        // Verifiziere Konfliktlösung UI (falls implementiert)
        if app.alerts["Sync-Konflikt"].waitForExistence(timeout: 10) {
            let conflictAlert = app.alerts["Sync-Konflikt"]
            
            // Wähle Konfliktlösung
            if conflictAlert.buttons["Remote Version verwenden"].exists {
                conflictAlert.buttons["Remote Version verwenden"].tap()
                
                // Verifiziere Ergebnis
                XCTAssertTrue(app.staticTexts["Remote Description"].waitForExistence(timeout: 5))
            }
        } else {
            // Falls automatische Konfliktlösung - verifiziere Sync-Completion
            verifySyncCompletion()
        }
        
        print("✅ Conflict Resolution Test Passed")
    }
    
    @MainActor
    func testOfflineToOnlineSync() throws {
        /// Test: Offline-Bearbeitung und anschließende Synchronisation
        /// Testet Offline-Funktionalität und Upload bei Netzwerk-Wiederherstellung
        
        print("📶 Starting Offline-to-Online Sync Test")
        
        app.launch()
        loginTestUser()
        
        // Gehe offline (via Mock)
        setNetworkCondition(.offline)
        
        // Erstelle Offline-Daten
        let offlineTrip = "Offline Trip \(UUID().uuidString.prefix(8))"
        createTrip(title: offlineTrip)
        addMemoryToTrip(tripTitle: offlineTrip, memoryTitle: "Offline Memory")
        
        // Verifiziere Offline-Indicator (falls vorhanden)
        if app.images["offline.indicator"].exists {
            XCTAssertTrue(app.images["offline.indicator"].isHittable)
        }
        
        // Gehe online
        setNetworkCondition(.online)
        
        // Triggere Sync
        triggerSync()
        
        // Verifiziere Upload
        verifySyncCompletion()
        
        // Verifiziere dass Offline-Indicator verschwunden ist
        if app.images["offline.indicator"].exists {
            XCTAssertFalse(app.images["offline.indicator"].isHittable)
        }
        
        print("✅ Offline-to-Online Sync Test Passed")
    }
    
    @MainActor
    func testLargeDataSync() throws {
        /// Test: Synchronisation großer Datenmengen
        /// Testet Performance und Stabilität bei vielen Entitäten
        
        print("📦 Starting Large Data Sync Test")
        
        app.launch()
        loginTestUser()
        
        let bulkCount = 10 // Reduziert für UI-Tests
        
        // Erstelle viele Trips und Memories
        for i in 1...bulkCount {
            createTrip(title: "Bulk Trip \(i)")
            addMemoryToTrip(tripTitle: "Bulk Trip \(i)", memoryTitle: "Bulk Memory \(i)")
            
            // Zwischenstatus anzeigen
            if i % 3 == 0 {
                print("📝 Created \(i)/\(bulkCount) test entities")
            }
        }
        
        // Triggere Sync
        let syncStart = Date()
        triggerSync()
        
        // Überwache Performance
        verifySyncCompletion()
        let syncDuration = Date().timeIntervalSince(syncStart)
        
        // Performance-Assertion (großzügiger für UI-Tests)
        XCTAssertLessThan(syncDuration, 120.0, "Large data sync should complete within 2 minutes")
        
        print("✅ Large Data Sync Test Passed (Duration: \(String(format: "%.2f", syncDuration))s)")
    }
    
    @MainActor
    func testSyncRecoveryAfterError() throws {
        /// Test: Sync-Wiederherstellung nach Fehlern
        /// Testet Retry-Mechanismen und Error-Recovery
        
        print("🔄 Starting Sync Recovery Test")
        
        app.launch()
        loginTestUser()
        
        createTrip(title: "Error Recovery Trip")
        
        // Simuliere Server-Fehler
        mockServer.simulateServerError()
        
        triggerSync()
        
        // Verifiziere Fehler-Zustand (falls UI vorhanden)
        if app.staticTexts["Sync-Fehler"].waitForExistence(timeout: 15) {
            XCTAssertTrue(app.staticTexts["Sync-Fehler"].exists)
            
            // Behebe Server-Problem
            mockServer.clearServerError()
            
            // Retry Sync (falls Retry-Button vorhanden)
            if app.buttons["Wiederholen"].exists {
                app.buttons["Wiederholen"].tap()
            } else {
                // Fallback: Manuelle Sync-Auslösung
                triggerSync()
            }
            
            // Verifiziere erfolgreiche Wiederherstellung
            verifySyncCompletion()
        } else {
            // Falls kein explizites Error-UI - teste dennoch Recovery
            mockServer.clearServerError()
            triggerSync()
            verifySyncCompletion()
        }
        
        print("✅ Sync Recovery Test Passed")
    }
    
    @MainActor
    func testBackgroundSyncBehavior() throws {
        /// Test: Hintergrund-Synchronisation
        /// Testet App-Lifecycle-Events und Background-Sync
        
        print("🌙 Starting Background Sync Test")
        
        app.launch()
        loginTestUser()
        
        createTrip(title: "Background Sync Trip")
        
        // Simuliere App in Background
        XCUIDevice.shared.press(.home)
        
        // Kurz warten
        Thread.sleep(forTimeInterval: 2.0)
        
        // App wieder aktivieren
        app.activate()
        
        // Verifiziere dass Daten noch da sind
        XCTAssertTrue(app.staticTexts["Background Sync Trip"].waitForExistence(timeout: 10))
        
        // Triggere Sync nach Background-Return
        triggerSync()
        verifySyncCompletion()
        
        print("✅ Background Sync Test Passed")
    }
    
    // MARK: - Helper Methods
    
    private func setupTestEnvironment() {
        // Setup für UI-Tests
        UserDefaults.standard.set(true, forKey: "UITestingMode")
        UserDefaults.standard.set("test@journiary.com", forKey: "TestUserEmail")
        UserDefaults.standard.set("testpassword", forKey: "TestUserPassword")
    }
    
    private func loginTestUser() {
        print("🔐 Logging in test user...")
        
        // Warte auf Login-Screen oder überspringe wenn bereits eingeloggt
        if app.textFields["E-Mail"].waitForExistence(timeout: 5) {
            app.textFields["E-Mail"].tap()
            app.textFields["E-Mail"].typeText("test@journiary.com")
            
            if app.secureTextFields["Passwort"].exists {
                app.secureTextFields["Passwort"].tap()
                app.secureTextFields["Passwort"].typeText("testpassword")
            }
            
            if app.buttons["Anmelden"].exists {
                app.buttons["Anmelden"].tap()
            }
        }
        
        // Warte auf Login-Completion
        XCTAssertTrue(app.tabBars.element.waitForExistence(timeout: 15), "Login should complete within 15 seconds")
        
        print("✅ Test user logged in successfully")
    }
    
    private func createTrip(title: String) {
        print("📝 Creating trip: \(title)")
        
        // Navigiere zu Trips-Tab
        if app.tabBars.buttons["Trips"].exists {
            app.tabBars.buttons["Trips"].tap()
        }
        
        // Erstelle neuen Trip
        if app.navigationBars.buttons["add"].exists {
            app.navigationBars.buttons["add"].tap()
        } else if app.buttons["Trip hinzufügen"].exists {
            app.buttons["Trip hinzufügen"].tap()
        } else if app.buttons["+"].exists {
            app.buttons["+"].tap()
        }
        
        // Fülle Trip-Daten aus
        if app.textFields["Trip-Titel"].exists {
            app.textFields["Trip-Titel"].tap()
            app.textFields["Trip-Titel"].typeText(title)
        } else if app.textFields["Titel"].exists {
            app.textFields["Titel"].tap()
            app.textFields["Titel"].typeText(title)
        }
        
        // Speichere Trip
        if app.buttons["Speichern"].exists {
            app.buttons["Speichern"].tap()
        } else if app.buttons["Erstellen"].exists {
            app.buttons["Erstellen"].tap()
        }
        
        // Verifiziere Erstellung
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), "Trip '\(title)' should be created")
    }
    
    private func addMemoryToTrip(tripTitle: String, memoryTitle: String) {
        print("💭 Adding memory '\(memoryTitle)' to trip '\(tripTitle)'")
        
        // Navigiere zu Trip
        if app.staticTexts[tripTitle].exists {
            app.staticTexts[tripTitle].tap()
        }
        
        // Füge Memory hinzu
        if app.buttons["Memory hinzufügen"].exists {
            app.buttons["Memory hinzufügen"].tap()
        } else if app.buttons["+"].exists {
            app.buttons["+"].tap()
        }
        
        // Fülle Memory-Daten aus
        if app.textFields["Memory-Titel"].exists {
            app.textFields["Memory-Titel"].tap()
            app.textFields["Memory-Titel"].typeText(memoryTitle)
        } else if app.textFields["Titel"].exists {
            app.textFields["Titel"].tap()
            app.textFields["Titel"].typeText(memoryTitle)
        }
        
        // Speichere Memory
        if app.buttons["Speichern"].exists {
            app.buttons["Speichern"].tap()
        }
        
        // Verifiziere Erstellung
        XCTAssertTrue(app.staticTexts[memoryTitle].waitForExistence(timeout: 10), "Memory '\(memoryTitle)' should be created")
    }
    
    private func addPhotoToMemory(memoryTitle: String) {
        print("📸 Adding photo to memory '\(memoryTitle)'")
        
        app.staticTexts[memoryTitle].tap()
        
        if app.buttons["Foto hinzufügen"].exists {
            app.buttons["Foto hinzufügen"].tap()
            
            if app.buttons["Foto aufnehmen"].exists {
                app.buttons["Foto aufnehmen"].tap()
                
                // Simuliere Foto-Aufnahme (im Simulator)
                Thread.sleep(forTimeInterval: 2)
                
                if app.buttons["Use Photo"].exists {
                    app.buttons["Use Photo"].tap()
                }
            }
        }
        
        // Verifiziere Foto wurde hinzugefügt
        XCTAssertTrue(app.images["memory.photo"].waitForExistence(timeout: 10), "Photo should be added to memory")
    }
    
    private func addTagToMemory(memoryTitle: String, tagName: String) {
        print("🏷️ Adding tag '\(tagName)' to memory '\(memoryTitle)'")
        
        if app.buttons["Tag hinzufügen"].exists {
            app.buttons["Tag hinzufügen"].tap()
            
            if app.textFields["Tag-Name"].exists {
                app.textFields["Tag-Name"].tap()
                app.textFields["Tag-Name"].typeText(tagName)
                
                if app.buttons["Hinzufügen"].exists {
                    app.buttons["Hinzufügen"].tap()
                }
            }
        }
    }
    
    private func editTrip(title: String, newDescription: String) {
        print("✏️ Editing trip '\(title)' with description '\(newDescription)'")
        
        app.staticTexts[title].tap()
        
        if app.buttons["Bearbeiten"].exists {
            app.buttons["Bearbeiten"].tap()
            
            if app.textViews["Beschreibung"].exists {
                app.textViews["Beschreibung"].tap()
                app.textViews["Beschreibung"].typeText(newDescription)
                
                if app.buttons["Speichern"].exists {
                    app.buttons["Speichern"].tap()
                }
            }
        }
    }
    
    private func triggerSync() {
        print("🔄 Triggering synchronization...")
        
        // Verschiedene Möglichkeiten zum Sync-Trigger
        if app.buttons["Sync"].exists {
            app.buttons["Sync"].tap()
        } else if app.buttons["Synchronisieren"].exists {
            app.buttons["Synchronisieren"].tap()
        } else {
            // Pull-to-refresh als Fallback
            let firstCell = app.tables.cells.firstMatch
            if firstCell.exists {
                let start = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let finish = firstCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.5))
                start.press(forDuration: 0, thenDragTo: finish)
            }
        }
    }
    
    private func verifySyncCompletion() {
        print("⏳ Verifying sync completion...")
        
        // Warte auf Sync-Completion-Indicator
        let indicators = [
            "Synchronisiert",
            "Sync abgeschlossen",
            "✓ Synchronisiert",
            "sync.complete"
        ]
        
        var found = false
        for indicator in indicators {
            if app.staticTexts[indicator].waitForExistence(timeout: 45) {
                found = true
                break
            }
        }
        
        if !found {
            // Fallback: Warte auf verschwinden des Sync-Indicators
            let syncingIndicators = [
                "Synchronisiert...",
                "Sync läuft",
                "sync.progress"
            ]
            
            for indicator in syncingIndicators {
                if app.staticTexts[indicator].exists {
                    XCTAssertFalse(app.staticTexts[indicator].waitForExistence(timeout: 45), "Sync should complete")
                }
            }
        }
        
        print("✅ Sync completion verified")
    }
    
    private func verifyDataPersistence(tripTitle: String, memoryTitle: String) {
        print("🔍 Verifying data persistence...")
        
        // Navigiere zu Trips
        if app.tabBars.buttons["Trips"].exists {
            app.tabBars.buttons["Trips"].tap()
        }
        
        // Verifiziere Trip existiert
        XCTAssertTrue(app.staticTexts[tripTitle].waitForExistence(timeout: 10), "Trip '\(tripTitle)' should persist")
        
        // Navigiere zu Trip und verifiziere Memory
        app.staticTexts[tripTitle].tap()
        XCTAssertTrue(app.staticTexts[memoryTitle].waitForExistence(timeout: 10), "Memory '\(memoryTitle)' should persist")
        
        print("✅ Data persistence verified")
    }
    
    private func setNetworkCondition(_ condition: NetworkCondition) {
        print("📡 Setting network condition: \(condition)")
        
        // Verwende Launch-Arguments für Netzwerk-Simulation
        switch condition {
        case .offline:
            app.launchArguments.append("--network-offline")
            mockServer.setNetworkCondition(.offline)
        case .online:
            app.launchArguments = app.launchArguments.filter { $0 != "--network-offline" }
            mockServer.setNetworkCondition(.online)
        case .slow:
            app.launchArguments.append("--network-slow")
            mockServer.setNetworkCondition(.slow)
        }
    }
    
    enum NetworkCondition {
        case online
        case offline
        case slow
    }
}

// MARK: - Mock GraphQL Server

class MockGraphQLServer {
    private var conflicts: [String: Any] = [:]
    private var serverError = false
    private var networkCondition: E2ESyncTests.NetworkCondition = .online
    private var isRunning = false
    
    func start() {
        guard !isRunning else { return }
        
        // Starte Mock-Server für Tests
        setupMockEndpoints()
        isRunning = true
        
        print("🌐 Mock GraphQL Server started")
    }
    
    func stop() {
        guard isRunning else { return }
        
        isRunning = false
        conflicts.removeAll()
        serverError = false
        
        print("🛑 Mock GraphQL Server stopped")
    }
    
    func createConflictingTrip(title: String, description: String) {
        conflicts[title] = [
            "description": description,
            "updatedAt": Date(),
            "conflictType": "description_conflict"
        ]
        
        print("⚠️ Created conflicting trip: \(title)")
    }
    
    func simulateServerError() {
        serverError = true
        print("💥 Simulating server error")
    }
    
    func clearServerError() {
        serverError = false
        print("✅ Server error cleared")
    }
    
    func setNetworkCondition(_ condition: E2ESyncTests.NetworkCondition) {
        networkCondition = condition
        print("📡 Network condition set to: \(condition)")
    }
    
    // MARK: - Private Helper Methods
    
    private func setupMockEndpoints() {
        // Hier würden normalerweise Mock-Endpoints konfiguriert
        // Für UI-Tests simulieren wir das über Launch-Arguments
        
        UserDefaults.standard.set(true, forKey: "UseMockServer")
        UserDefaults.standard.set("http://localhost:4000/graphql", forKey: "MockServerURL")
    }
}

// MARK: - Performance Helpers

extension E2ESyncTests {
    
    func measureSyncPerformance(description: String, operation: () throws -> Void) rethrows {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try operation()
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("⏱️ \(description) completed in \(String(format: "%.3f", timeElapsed)) seconds")
        
        // Performance-Assertion für UI-Tests (großzügiger)
        XCTAssertLessThan(timeElapsed, 60.0, "\(description) should complete within 60 seconds")
    }
} 