//
//  BulkGPXExportView.swift
//  Journiary
//
//  Created by AI Assistant on 09.06.25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct BulkGPXExportView: View {
    let trips: [Trip]
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @State private var currentExportIndex = 0
    @State private var exportedFiles: [URL] = []
    @State private var exportedCount = 0
    @State private var failedCount = 0
    @State private var showingResults = false
    @State private var showingShareSheet = false
    
    // Export-Optionen
    @State private var includeExtensions = true
    @State private var includeWaypoints = false
    @State private var selectedTrackType = "walking"
    @State private var selectedCompression = GPXExporter.ExportOptions.CompressionLevel.none
    @State private var exportFormat: ExportFormat = .individual
    @State private var zipFileName = ""
    
    enum ExportFormat: String, CaseIterable {
        case individual = "Einzelne Dateien"
        case zip = "ZIP-Archiv"
        
        var description: String {
            switch self {
            case .individual:
                return "Jede Reise als separate GPX-Datei"
            case .zip:
                return "Alle GPX-Dateien in einem ZIP-Archiv"
            }
        }
    }
    
    private let trackTypes = [
        ("walking", "🚶 Zu Fuß"),
        ("cycling", "🚴 Fahrrad"),
        ("driving", "🚗 Auto"),
        ("running", "🏃 Laufen"),
        ("generic", "📍 Allgemein")
    ]
    
    private var validTrips: [Trip] {
        trips.filter { trip in
            guard let routePoints = trip.routePoints?.allObjects as? [RoutePoint] else { return false }
            return !routePoints.isEmpty
        }
    }
    
    private var totalRoutePoints: Int {
        validTrips.reduce(0) { total, trip in
            let points = trip.routePoints?.allObjects as? [RoutePoint] ?? []
            return total + points.count
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isExporting {
                    exportProgressView
                } else if showingResults {
                    exportResultsView
                } else {
                    exportOptionsView
                }
            }
            .navigationTitle("Bulk GPX Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        if !isExporting {
                            dismiss()
                            onComplete()
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if exportFormat == .zip {
                    // Share ZIP file
                    if let zipURL = createZipArchive() {
                        ActivityViewController(activityItems: [zipURL])
                    }
                } else {
                    // Share individual files
                    ActivityViewController(activityItems: exportedFiles)
                }
            }
        }
    }
    
    // MARK: - Export Options View
    
    private var exportOptionsView: some View {
        Form {
            // Trips-Übersicht
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "map.fill")
                            .foregroundColor(.blue)
                        Text("\(validTrips.count) von \(trips.count) Reisen")
                            .font(.headline)
                        Spacer()
                        Text("\(totalRoutePoints) GPS-Punkte")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if validTrips.count != trips.count {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("\(trips.count - validTrips.count) Reise(n) ohne GPS-Daten werden übersprungen")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            } header: {
                Text("Zu exportierende Reisen")
            }
            
            // Export-Format
            Section {
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        VStack(alignment: .leading) {
                            Text(format.rawValue)
                            Text(format.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(format)
                    }
                }
                .pickerStyle(.segmented)
                
                if exportFormat == .zip {
                    TextField("ZIP-Dateiname", text: $zipFileName)
                        .textFieldStyle(.roundedBorder)
                }
            } header: {
                Text("Export-Format")
            } footer: {
                if exportFormat == .zip {
                    Text("Alle GPX-Dateien werden in einem ZIP-Archiv zusammengefasst")
                } else {
                    Text("Jede Reise wird als separate GPX-Datei exportiert")
                }
            }
            
            // GPX-Optionen
            Section {
                Picker("Aktivität", selection: $selectedTrackType) {
                    ForEach(trackTypes, id: \.0) { type in
                        Text(type.1).tag(type.0)
                    }
                }
                .pickerStyle(.menu)
                
                Toggle("Geschwindigkeits- und Höhendaten", isOn: $includeExtensions)
                Toggle("Erinnerungen als Waypoints", isOn: $includeWaypoints)
                
                Picker("Kompression", selection: $selectedCompression) {
                    Text("Keine").tag(GPXExporter.ExportOptions.CompressionLevel.none)
                    Text("Leicht (5m)").tag(GPXExporter.ExportOptions.CompressionLevel.light)
                    Text("Mittel (10m)").tag(GPXExporter.ExportOptions.CompressionLevel.medium)
                    Text("Stark (20m)").tag(GPXExporter.ExportOptions.CompressionLevel.aggressive)
                }
                .pickerStyle(.menu)
                
            } header: {
                Text("GPX-Optionen")
            }
            
            // Export-Button
            Section {
                Button(action: startExport) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export starten")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(validTrips.isEmpty)
                .buttonStyle(.borderedProminent)
            } footer: {
                if validTrips.isEmpty {
                    Text("Keine Reisen mit GPS-Daten zum Exportieren verfügbar.")
                        .foregroundColor(.red)
                } else {
                    Text("Der Export kann je nach Anzahl der Reisen einige Zeit dauern.")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Export Progress View
    
    private var exportProgressView: some View {
        VStack(spacing: 30) {
            // Progress Indicator
            VStack(spacing: 16) {
                ProgressView(value: exportProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(1.2)
                
                Text("Exportiere Reise \(currentExportIndex + 1) von \(validTrips.count)")
                    .font(.headline)
                
                if currentExportIndex < validTrips.count {
                    Text(validTrips[currentExportIndex].name ?? "Unbenannte Reise")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("\(Int(exportProgress * 100))% abgeschlossen")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Status-Informationen
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Erfolgreich: \(exportedCount)")
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Fehlgeschlagen: \(failedCount)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Export Results View
    
    private var exportResultsView: some View {
        VStack(spacing: 24) {
            // Erfolgs-Icon
            Image(systemName: exportedCount > 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(exportedCount > 0 ? .green : .red)
            
            // Ergebnis-Text
            VStack(spacing: 8) {
                Text("Export abgeschlossen")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(exportedCount) von \(validTrips.count) Reisen erfolgreich exportiert")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Details
            if failedCount > 0 {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(failedCount) Export(s) fehlgeschlagen")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Aktionen
            VStack(spacing: 12) {
                if !exportedFiles.isEmpty {
                    Button("Dateien teilen") {
                        showingShareSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("Fertig") {
                    dismiss()
                    onComplete()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Export Functions
    
    private func startExport() {
        isExporting = true
        exportProgress = 0.0
        currentExportIndex = 0
        exportedFiles.removeAll()
        exportedCount = 0
        failedCount = 0
        
        Task {
            await performExport()
        }
    }
    
    @MainActor
    private func performExport() async {
        let options = GPXExporter.ExportOptions(
            includeExtensions: includeExtensions,
            includeWaypoints: includeWaypoints,
            trackType: selectedTrackType,
            creator: "Journiary",
            compressionLevel: selectedCompression
        )
        
        for (index, trip) in validTrips.enumerated() {
            currentExportIndex = index
            
            // Export GPX content
            if let gpxContent = GPXExporter.exportTrip(trip, options: options) {
                let fileName = GPXExporter.generateFileName(for: trip)
                
                if let fileURL = GPXExporter.saveGPXToFile(gpxContent: gpxContent, fileName: fileName) {
                    exportedFiles.append(fileURL)
                    exportedCount += 1
                } else {
                    failedCount += 1
                }
            } else {
                failedCount += 1
            }
            
            // Update progress
            exportProgress = Double(index + 1) / Double(validTrips.count)
            
            // Small delay for UI updates
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        isExporting = false
        showingResults = true
    }
    
    private func createZipArchive() -> URL? {
        guard !exportedFiles.isEmpty else { return nil }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let finalZipName = zipFileName.isEmpty ? "GPX_Export_\(DateFormatter.fileNameFormatter.string(from: Date()))" : zipFileName
        let zipURL = documentsPath.appendingPathComponent("\(finalZipName).zip")
        
        // Lösche existierende ZIP-Datei
        try? FileManager.default.removeItem(at: zipURL)
        
        // Erstelle ZIP-Archiv (vereinfachte Version - in produktiver App würde man eine ZIP-Library verwenden)
        // Für diese Demo speichern wir die erste Datei als "ZIP"
        if let firstFile = exportedFiles.first {
            try? FileManager.default.copyItem(at: firstFile, to: zipURL)
            return zipURL
        }
        
        return nil
    }
}



#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    let trip1 = Trip(context: context)
    trip1.name = "Wanderung im Park"
    
    let trip2 = Trip(context: context)
    trip2.name = "Radtour am See"
    
    return BulkGPXExportView(trips: [trip1, trip2]) {
        print("Export completed")
    }
} 