//
//  GPXDebugTestView.swift
//  Journiary
//
//  Created by AI Assistant on 10.06.25.
//

import SwiftUI
import CoreData

struct GPXDebugTestView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)],
        animation: .default
    )
    private var allTrips: FetchedResults<Trip>
    
    @State private var debugMessages: [String] = []
    @State private var isTestRunning = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Test-Button
                Button(action: runDebugTest) {
                    HStack {
                        if isTestRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.circle")
                        }
                        Text(isTestRunning ? "Test läuft..." : "GPX Export Test starten")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTestRunning || allTrips.isEmpty)
                
                if allTrips.isEmpty {
                    Text("Keine Reisen für Test verfügbar")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                // Debug-Ausgabe
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(debugMessages.enumerated()), id: \.offset) { index, message in
                            Text(message)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    message.contains("❌") ? Color.red.opacity(0.1) :
                                    message.contains("✅") ? Color.green.opacity(0.1) :
                                    message.contains("📁") ? Color.blue.opacity(0.1) :
                                    Color(.systemGray6)
                                )
                                .cornerRadius(4)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                
                Spacer()
            }
            .padding()
            .navigationTitle("GPX Debug Test")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        debugMessages.removeAll()
                    }
                    .disabled(debugMessages.isEmpty)
                }
            }
        }
    }
    
    private func runDebugTest() {
        guard let firstTrip = allTrips.first else {
            addDebugMessage("❌ Keine Reise für Test verfügbar")
            return
        }
        
        isTestRunning = true
        debugMessages.removeAll()
        
        Task {
            await performDebugTest(trip: firstTrip)
            await MainActor.run {
                isTestRunning = false
            }
        }
    }
    
    @MainActor
    private func performDebugTest(trip: Trip) async {
        addDebugMessage("🚀 Starte Debug-Test für: \(trip.name ?? "Unbenannte Reise")")
        
        // 1. Trip-Informationen prüfen
        addDebugMessage("📊 Trip-Info:")
        addDebugMessage("  - Name: \(trip.name ?? "nil")")
        addDebugMessage("  - Start: \(trip.startDate?.description ?? "nil")")
        addDebugMessage("  - RoutePoints: \(trip.routePoints?.count ?? 0)")
        addDebugMessage("  - Memories: \(trip.memories?.count ?? 0)")
        
        // 2. RoutePoints validieren
        guard let routePoints = trip.routePoints?.allObjects as? [RoutePoint],
              !routePoints.isEmpty else {
            addDebugMessage("❌ Keine RoutePoints gefunden!")
            return
        }
        
        let sortedPoints = routePoints.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        addDebugMessage("✅ \(sortedPoints.count) RoutePoints gefunden")
        
        // Beispiel-Punkte zeigen
        let samplePoints = Array(sortedPoints.prefix(3))
        for (index, point) in samplePoints.enumerated() {
            addDebugMessage("📍 Punkt \(index): lat=\(String(format: "%.6f", point.latitude)), lon=\(String(format: "%.6f", point.longitude))")
        }
        
        // 3. Ordner-Struktur prüfen
        await checkDirectoryStructure()
        
        // 4. GPX-Export testen
        await testGPXExport(trip: trip)
        
        addDebugMessage("🏁 Debug-Test abgeschlossen")
    }
    
    @MainActor
    private func checkDirectoryStructure() async {
        addDebugMessage("📁 Prüfe Ordner-Struktur:")
        
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        addDebugMessage("  - Documents: \(documentsPath.path)")
        
        let journiaryFolder = documentsPath.appendingPathComponent("Journiary")
        let journiaryExists = fileManager.fileExists(atPath: journiaryFolder.path)
        
        addDebugMessage("  - Journiary-Ordner existiert: \(journiaryExists)")
        if !journiaryExists {
            addDebugMessage("  - Versuche Journiary-Ordner zu erstellen...")
            do {
                try fileManager.createDirectory(at: journiaryFolder, withIntermediateDirectories: true, attributes: nil)
                addDebugMessage("  ✅ Journiary-Ordner erstellt")
            } catch {
                addDebugMessage("  ❌ Fehler beim Erstellen: \(error.localizedDescription)")
            }
        }
        
        // Dateien im Journiary-Ordner auflisten
        do {
            let files = try fileManager.contentsOfDirectory(atPath: journiaryFolder.path)
            addDebugMessage("  - Dateien im Journiary-Ordner: \(files.count)")
            for file in files.prefix(5) {
                addDebugMessage("    • \(file)")
            }
        } catch {
            addDebugMessage("  ❌ Kann Ordnerinhalt nicht lesen: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func testGPXExport(trip: Trip) async {
        addDebugMessage("🧪 Teste GPX-Export:")
        
        let options = GPXExporter.ExportOptions(
            includeExtensions: true,
            includeWaypoints: false,
            trackType: "walking",
            creator: "Journiary-Debug",
            compressionLevel: .none
        )
        
        guard let gpxContent = GPXExporter.exportTrip(trip, options: options) else {
            addDebugMessage("❌ GPX-Content-Generierung fehlgeschlagen")
            return
        }
        
        addDebugMessage("✅ GPX-Content generiert (\(gpxContent.count) Zeichen)")
        addDebugMessage("📄 Erste 200 Zeichen:")
        addDebugMessage(String(gpxContent.prefix(200)))
        
        // Test-Speicherung
        let testFileName = "DEBUG_TEST_\(Date().timeIntervalSince1970)"
        guard let fileURL = GPXExporter.saveGPXToFile(gpxContent: gpxContent, fileName: testFileName) else {
            addDebugMessage("❌ Datei-Speicherung fehlgeschlagen")
            return
        }
        
        addDebugMessage("✅ Test-Datei gespeichert: \(fileURL.lastPathComponent)")
        
        // Datei-Eigenschaften prüfen
        let fileManager = FileManager.default
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            addDebugMessage("📏 Dateigröße: \(fileSize) Bytes")
            
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            addDebugMessage("📖 Datei erfolgreich lesbar: \(content.count) Zeichen")
            
        } catch {
            addDebugMessage("❌ Fehler beim Lesen der gespeicherten Datei: \(error.localizedDescription)")
        }
    }
    
    private func addDebugMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugMessages.append("[\(timestamp)] \(message)")
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    let trip = Trip(context: context)
    trip.name = "Test Reise"
    trip.startDate = Date()
    
    // Test RoutePoints hinzufügen
    for i in 0..<10 {
        let point = RoutePoint(context: context)
        point.latitude = 52.5200 + Double(i) * 0.001
        point.longitude = 13.4050 + Double(i) * 0.001
        point.timestamp = Date().addingTimeInterval(Double(i * 30))
        point.altitude = 50.0
        point.speed = 1.4
        point.trip = trip
    }
    
    return GPXDebugTestView()
        .environment(\.managedObjectContext, context)
} 