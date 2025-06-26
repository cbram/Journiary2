//
//  GPXExportView.swift
//  Journiary
//
//  Created by AI Assistant on 09.06.25.
//

import SwiftUI
import CoreData

struct GPXExportView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // Export-Optionen
    @State private var includeExtensions = true
    @State private var includeWaypoints = false
    @State private var selectedTrackType = "walking"
    @State private var selectedCompression = GPXExporter.ExportOptions.CompressionLevel.none
    @State private var customFileName = ""
    
    // Status
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var shareableFileURL: URL?
    @State private var exportedGPXContent: String?
    @State private var showingShareSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    private let trackTypes = [
        ("walking", "🚶 Zu Fuß", "Wandern/Spazieren"),
        ("cycling", "🚴 Fahrrad", "Radfahren"),
        ("driving", "🚗 Auto", "Autofahrt"),
        ("running", "🏃 Laufen", "Joggen/Laufen"),
        ("motorcycle", "🏍️ Motorrad", "Motorradfahrt"),
        ("sailing", "⛵ Segeln", "Segeltour"),
        ("skiing", "⛷️ Ski", "Skifahren"),
        ("generic", "📍 Allgemein", "Allgemeiner Track")
    ]
    
    private var routePoints: [RoutePoint] {
        guard let points = trip.routePoints?.allObjects as? [RoutePoint] else { return [] }
        return points.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
    }
    
    private var memories: [Memory] {
        guard let memories = trip.memories?.allObjects as? [Memory] else { return [] }
        return memories.filter { $0.latitude != 0.0 && $0.longitude != 0.0 }
    }
    
    private var generatedFileName: String {
        if !customFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return GPXExporter.generateFileName(for: trip)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Track-Informationen
                trackInfoSection
                
                // Export-Optionen
                exportOptionsSection
                
                // Dateinamen-Anpassung
                fileNameSection
                
                // Vorschau der Kompression
                if selectedCompression != .none {
                    compressionPreviewSection
                }
                
                // Export-Button
                exportButtonSection
            }
            .navigationTitle("GPX Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .disabled(isExporting)
            .alert(alertTitle, isPresented: $showingAlert) {
                if exportedFileURL != nil {
                    Button("Teilen") {
                        createShareableFile()
                    }
                    Button("OK") {}
                } else {
                    Button("OK") {}
                }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let shareURL = shareableFileURL {
                                                ActivityViewController(activityItems: [shareURL])
                        .onAppear {
                            print("📤 Share Sheet öffnet sich für temporäre Datei: \(shareURL.path)")
                        }
                        .onDisappear {
                            cleanupShareableFile()
                        }
                } else {
                    Text("Keine Datei zum Teilen verfügbar")
                        .padding()
                        .onAppear {
                            print("❌ Share Sheet: Keine gültige temporäre Datei-URL")
                        }
                }
            }
        }
    }
    
    // MARK: - View Sections
    
    private var trackInfoSection: some View {
        Section {
            HStack {
                Image(systemName: "map")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name ?? "Unbenannte Reise")
                        .font(.headline)
                    Text("\(routePoints.count) GPS-Punkte")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let startDate = trip.startDate {
                        Text(startDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f km", trip.totalDistance / 1000))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if memories.count > 0 {
                        Text("\(memories.count) Erinnerungen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Track-Informationen")
        }
    }
    
    private var exportOptionsSection: some View {
        Section {
            // Aktivität auswählen
            Picker("Aktivität", selection: $selectedTrackType) {
                ForEach(trackTypes, id: \.0) { type in
                    HStack {
                        Text(type.1)
                        Text("(\(type.2))")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .tag(type.0)
                }
            }
            .pickerStyle(.menu)
            
            // Erweiterte Daten einbeziehen
            Toggle("Geschwindigkeits- und Höhendaten", isOn: $includeExtensions)
            
            // Waypoints/Erinnerungen einbeziehen
            Toggle("Erinnerungen als Waypoints (\(memories.count))", isOn: $includeWaypoints)
                .disabled(memories.isEmpty)
            
            // Kompression auswählen
            Picker("Kompression", selection: $selectedCompression) {
                Text("Keine (alle Punkte)").tag(GPXExporter.ExportOptions.CompressionLevel.none)
                Text("Leicht (5m Toleranz)").tag(GPXExporter.ExportOptions.CompressionLevel.light)
                Text("Mittel (10m Toleranz)").tag(GPXExporter.ExportOptions.CompressionLevel.medium)
                Text("Stark (20m Toleranz)").tag(GPXExporter.ExportOptions.CompressionLevel.aggressive)
            }
            .pickerStyle(.menu)
            
        } header: {
            Text("Export-Optionen")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if includeExtensions {
                    Text("• Geschwindigkeit, Höhendaten und Track-Statistiken werden einbezogen")
                }
                if includeWaypoints && !memories.isEmpty {
                    Text("• \(memories.count) Erinnerungen werden als Waypoints exportiert")
                }
                if selectedCompression != .none {
                    Text("• Track wird mit \(selectedCompression.tolerance)m Toleranz optimiert")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    private var fileNameSection: some View {
        Section {
            TextField("Dateiname (optional)", text: $customFileName)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Text("Wird gespeichert als:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(generatedFileName).gpx")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Dateiname")
        } footer: {
            Text("Falls leer, wird automatisch ein Name generiert: Reisename + Datum")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var compressionPreviewSection: some View {
        Section {
            let estimatedPoints = estimateCompressedPointCount()
            let reduction = ((Double(routePoints.count - estimatedPoints) / Double(routePoints.count)) * 100)
            
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Geschätzte Reduzierung")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(routePoints.count) → \(estimatedPoints) Punkte")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("-\(String(format: "%.0f", reduction))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
        } header: {
            Text("Kompression Vorschau")
        } footer: {
            Text("Dies ist eine Schätzung. Die tatsächliche Reduzierung kann abweichen.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var exportButtonSection: some View {
        Section {
            Button(action: exportGPX) {
                HStack {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(isExporting ? "Exportiere..." : "GPX-Datei erstellen")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(routePoints.isEmpty || isExporting)
            .buttonStyle(.borderedProminent)
        } footer: {
            if routePoints.isEmpty {
                Text("Keine GPS-Punkte zum Exportieren verfügbar.")
                    .foregroundColor(.red)
                    .font(.caption)
            } else {
                Text("Die GPX-Datei wird in der Dateien-App gespeichert und kann von dort geteilt werden.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func estimateCompressedPointCount() -> Int {
        // Grobe Schätzung basierend auf Kompression-Level
        switch selectedCompression {
        case .none:
            return routePoints.count
        case .light:
            return Int(Double(routePoints.count) * 0.8)  // ~20% Reduzierung
        case .medium:
            return Int(Double(routePoints.count) * 0.6)  // ~40% Reduzierung
        case .aggressive:
            return Int(Double(routePoints.count) * 0.4)  // ~60% Reduzierung
        }
    }
    
    private func exportGPX() {
        guard !routePoints.isEmpty else {
            showAlert(title: "Fehler", message: "Keine GPS-Punkte zum Exportieren verfügbar.")
            return
        }
        
        print("🚀 Starte GPX-Export für Reise: \(trip.name ?? "Unbenannt")")
        print("📊 \(routePoints.count) GPS-Punkte verfügbar")
        
        isExporting = true
        
        Task {
            // Export-Optionen konfigurieren
            let options = GPXExporter.ExportOptions(
                includeExtensions: includeExtensions,
                includeWaypoints: includeWaypoints,
                trackType: selectedTrackType,
                creator: "Journiary",
                compressionLevel: selectedCompression
            )
            
            // GPX-Content generieren
            guard let gpxContent = GPXExporter.exportTrip(trip, options: options) else {
                await MainActor.run {
                    isExporting = false
                    showAlert(title: "Fehler", message: "Fehler beim Generieren der GPX-Datei. Bitte überprüfen Sie die GPS-Daten.")
                }
                return
            }
            
            // In Datei speichern
            guard let fileURL = GPXExporter.saveGPXToFile(gpxContent: gpxContent, fileName: generatedFileName) else {
                await MainActor.run {
                    isExporting = false
                    showAlert(title: "Fehler", message: "Fehler beim Speichern der GPX-Datei. Bitte überprüfen Sie die App-Berechtigungen.")
                }
                return
            }
            
            await MainActor.run {
                isExporting = false
                exportedFileURL = fileURL
                exportedGPXContent = gpxContent // Speichere Content für späteren Share
                showAlert(
                    title: "Export erfolgreich",
                    message: "GPX-Datei '\(generatedFileName).gpx' wurde erfolgreich erstellt.\n\nSpeicherort: Dateien-App → Journiary\n\nDateigröße: \((gpxContent.data(using: .utf8)?.count ?? 0) / 1024)KB"
                )
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
    
    private func createShareableFile() {
        guard let gpxContent = exportedGPXContent else {
            return
        }
        
        // Erstelle temporäre Datei
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = "\(generatedFileName)_share.gpx"
        let tempFileURL = tempDir.appendingPathComponent(tempFileName)
        
        do {
            // Lösche alte temporäre Datei falls vorhanden
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
            }
            
            // Schreibe neue temporäre Datei
            try gpxContent.write(to: tempFileURL, atomically: true, encoding: .utf8)
            
            // Verifiziere dass die Datei erstellt wurde
            guard FileManager.default.fileExists(atPath: tempFileURL.path) else {
                showAlert(title: "Fehler", message: "Temporäre Datei konnte nicht erstellt werden.")
                return
            }
            
            shareableFileURL = tempFileURL
            showingShareSheet = true
            
        } catch {
            showAlert(title: "Fehler", message: "Fehler beim Vorbereiten der Datei zum Teilen: \(error.localizedDescription)")
        }
    }
    
    private func cleanupShareableFile() {
        guard let shareURL = shareableFileURL else { return }
        
        do {
            try FileManager.default.removeItem(at: shareURL)
        } catch {
            // Fehler beim Löschen ignorieren
        }
        
        shareableFileURL = nil
    }
}

// MARK: - Shared Components Note
// ActivityViewController is now in SharedUIComponents.swift

// MARK: - Preview

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    let trip = Trip(context: context)
    trip.name = "Wanderung im Park"
    trip.startDate = Date().addingTimeInterval(-3600)
    trip.totalDistance = 5000.0
    
    // Einige RoutePoints hinzufügen
    for i in 0..<100 {
        let point = RoutePoint(context: context)
        point.latitude = 52.5200 + Double(i) * 0.001
        point.longitude = 13.4050 + Double(i) * 0.001
        point.timestamp = Date().addingTimeInterval(Double(i * 30))
        point.altitude = 50.0 + Double(i) * 0.5
        point.speed = 1.4
        point.trip = trip
    }
    
    return GPXExportView(trip: trip)
        .environment(\.managedObjectContext, context)
} 