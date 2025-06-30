//
//  AddMemoryView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import PhotosUI
import CoreData
import MapKit
import ImageIO
import CoreLocation
import AVFoundation

enum LocationMode: String, CaseIterable {
    case current = "GPS"
    case manual = "Manuell"
    case map = "Karte"
    case photo = "Foto"
    
    var icon: String {
        switch self {
        case .current: return "location.fill"
        case .manual: return "pencil"
        case .map: return "map"
        case .photo: return "photo"
        }
    }
    
    var fullDescription: String {
        switch self {
        case .current: return "Aktueller Standort"
        case .manual: return "Manuell eingeben"
        case .map: return "Aus Karte wählen"
        case .photo: return "Aus Foto extrahieren"
        }
    }
}

// MARK: - Camera functionality now uses native iOS UIImagePickerController
// All legacy camera code has been removed and replaced with NativeMediaPickerView

// MARK: - Native Camera Integration (using UIImagePickerController)

struct AddMemoryView: View {
    @Binding var selectedTab: Int
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var title = ""
    @State private var text = ""
    @State private var selectedDate = Date()
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDataArray: [Data] = []
    @State private var mediaItems: [MediaItem] = []
    @State private var currentLocationName = "Standort wird ermittelt..."
    @State private var showingImagePicker = false
    @State private var showingCamera = false

    @State private var showingMediaSourceDialog = false
    
    // Neue Standort-Variablen
    @State private var locationMode: LocationMode = .current
    @State private var manualLocationName = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedLocationName = ""
    @State private var showingMapPicker = false
    
    // Foto-Standort-Variablen
    @State private var showingPhotoLocationPicker = false
    @State private var photoSelectedCoordinate: CLLocationCoordinate2D?
    @State private var photoSelectedLocationName = ""
    @State private var showingPhotoPickerForLocation = false
    @State private var selectedPhotosForLocation: [PhotosPickerItem] = []
    @State private var showingMapEditorForPhoto = false
    @State private var showingNoGPSAlert = false
    
    // EXIF-Datenextraktion - neue Variablen
    @State private var extractedPhotoInfo: [PhotoExifInfo] = []
    @State private var showingExifSuggestions = false
    @State private var selectedExifDate: Date?
    @State private var selectedExifLocation: CLLocationCoordinate2D?
    @State private var selectedExifLocationName: String?
    
    // Tagging-Variablen
    @State private var showingTagSelection = false
    @State private var selectedTags: Set<Tag> = []
    
    // POI-Verknüpfung
    @State private var selectedBucketListItem: BucketListItem?
    @State private var showingPOISelection = false
    @State private var tempPOIMemory: Memory?
    
    // Wetter-Variablen
    @StateObject private var weatherManager = WeatherManager()
    @State private var weatherData: WeatherData?
    
    // Unified Media Import
    @State private var showingUnifiedImport = false
    @State private var importedGPXTrack: GPXTrack?
    @State private var showingGPXTrackDetail = false
    @State private var showingGPXImportError = false
    @State private var gpxImportErrorMessage = ""
    @State private var showingGPXImporter = false

    // GPX Naming States (neu hinzugefügt)
    @State private var showingGPXNaming = false
    @State private var pendingGPXData: Data?
    @State private var pendingGPXFilename: String = ""
    @State private var pendingTrackData: GPXImporter.GPXTrackData?
    @State private var gpxTrackName = ""
    @State private var selectedTrackType = "wandern"
    
    private let trackTypes = [
        ("wandern", "🚶 Wandern", "Zu Fuß gehen"),
        ("radfahren", "🚴 Radfahren", "Mit dem Fahrrad"),
        ("autofahrt", "🚗 Autofahrt", "Mit dem Auto"),
        ("laufen", "🏃 Laufen", "Joggen/Laufen"),
        ("motorradfahrt", "🏍️ Motorradfahrt", "Mit dem Motorrad"),
        ("segeln", "⛵ Segeln", "Mit dem Boot"),
        ("skifahren", "⛷️ Skifahren", "Auf Skiern"),
        ("sonstiges", "📍 Sonstiges", "Andere Aktivität")
    ]

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)],
        animation: .default
    )
    private var allTrips: FetchedResults<Trip>
    
    var activeTrip: Trip? {
        allTrips.first { $0.isActive }
    }
    
    // Berechnet den finalen Standortnamen basierend auf dem Modus
    private var finalLocationName: String {
        switch locationMode {
        case .current:
            return currentLocationName
        case .manual:
            return manualLocationName.isEmpty ? "Kein Standort eingegeben" : manualLocationName
        case .map:
            return selectedLocationName.isEmpty ? "Kein Standort ausgewählt" : selectedLocationName
        case .photo:
            return photoSelectedLocationName.isEmpty ? "Kein Standort aus Foto extrahiert" : photoSelectedLocationName
        }
    }
    
    // Berechnet die finalen Koordinaten basierend auf dem Modus
    private var finalCoordinate: CLLocationCoordinate2D? {
        switch locationMode {
        case .current:
            return locationManager.currentLocation?.coordinate
        case .manual:
            return nil // Bei manueller Eingabe keine Koordinaten
        case .map:
            return selectedCoordinate
        case .photo:
            return photoSelectedCoordinate
        }
    }
    
    @State private var showingManualLocationSheet = false
    @State private var isProcessingMedia = false
    @State private var mediaProcessingProgress: Double = 0.0
    @State private var isEditMode = false
    
    var body: some View {
        contentView
            .sheet(isPresented: $showingMapPicker) {
                mapPickerSheet
            }
            .photosPicker(isPresented: $showingPhotoPickerForLocation, selection: $selectedPhotosForLocation, maxSelectionCount: 1, matching: .images)
            .onChange(of: selectedPhotosForLocation) { _, newValue in
                handlePhotoSelection(newValue)
            }
            .sheet(isPresented: $showingMapEditorForPhoto) {
                photoMapEditorSheet
            }
            .sheet(isPresented: $showingGPXNaming) {
                gpxNamingSheet
            }
            .alert("Keine GPS-Daten", isPresented: $showingNoGPSAlert) {
                Button("OK") { }
            } message: {
                Text("Das ausgewählte Foto enthält keine GPS-Daten. Bitte wählen Sie ein anderes Foto oder verwenden Sie einen anderen Standortmodus.")
            }
    }
    
    private var contentView: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // EXIF-Vorschläge Banner
                    if !extractedPhotoInfo.isEmpty {
                        exifSuggestionsView
                    }
                    
                    // Standort-Auswahl
                    locationSection
                    
                    // Titel-Eingabe
                    titleSection
                    
                    // Datum und Uhrzeit
                    dateTimeSection
                    
                    // Text-Eingabe
                    textSection
                    
                    // Media-Bereich (Einheitlicher Import)
                    mediaSection
                    
                    // Tags-Sektion
                    tagSection
                    
                    // POI Verknüpfung Sektion
                    poiLinkSection
                    
                    // Speichern Button
                    saveButton
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Erinnerung hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        resetAllFields()
                        selectedTab = 0
                    }
                }
            }
            .task {
                await updateCurrentLocation()
                await loadWeatherData()
            }
            .onAppear {
                // Beim erstmaligen Erscheinen des Views sicherstellen, dass EXIF-Daten zurückgesetzt sind
                if !extractedPhotoInfo.isEmpty {
                    extractedPhotoInfo.removeAll()
                    selectedExifDate = nil
                    selectedExifLocation = nil
                    selectedExifLocationName = nil
                }
            }
        }
    }
    
    private var mapPickerSheet: some View {
        SimpleMapPickerView(
            selectedCoordinate: $selectedCoordinate,
            selectedLocationName: $selectedLocationName,
            initialLocation: locationManager.currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050)
        )
        .environmentObject(locationManager)
        .environment(\.managedObjectContext, viewContext)
    }
    
    private var photoMapEditorSheet: some View {
        Group {
            if let coordinate = photoSelectedCoordinate {
                PhotoMapEditorForLocationView(
                    coordinate: $photoSelectedCoordinate,
                    locationName: $photoSelectedLocationName,
                    initialCoordinate: coordinate
                )
            }
        }
    }
    
    // MARK: - GPX Naming Sheet
    
    private var gpxNamingSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("GPX-Track konfigurieren")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Gib dem importierten GPS-Track einen Namen und wähle die Aktivität:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Track-Name")
                            .font(.headline)
                        
                        TextField("Track-Name eingeben", text: $gpxTrackName)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aktivität")
                            .font(.headline)
                        
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
                    }
                    
                    if !pendingGPXFilename.isEmpty {
                        Text("Ursprünglicher Dateiname: \(pendingGPXFilename)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button("Track importieren") {
                        confirmGPXImport()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(gpxTrackName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .frame(maxWidth: .infinity)
                    
                    Button("Abbrechen") {
                        cancelGPXImport()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .navigationTitle("GPX-Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        confirmGPXImport()
                    }
                    .disabled(gpxTrackName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        cancelGPXImport()
                    }
                }
            }
        }
    }
    
    private func handlePhotoSelection(_ newValue: [PhotosPickerItem]) {
        if let firstPhoto = newValue.first {
            loadPhotoForLocationExtraction(firstPhoto)
            selectedPhotosForLocation.removeAll()
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Standort")
                .font(.headline)
            
            // Verbesserte Modus-Auswahl mit einzelnen Buttons
            HStack(spacing: 12) {
                ForEach(LocationMode.allCases, id: \.self) { mode in
                    Button(action: {
                        if mode == .map {
                            // Bei Karte-Modus: Sofort Map Picker öffnen
                            withAnimation(.easeInOut(duration: 0.2)) {
                                locationMode = mode
                            }
                            showingMapPicker = true
                        } else if mode == .photo {
                            // Bei Foto-Modus: Direkt Fotogalerie öffnen
                            withAnimation(.easeInOut(duration: 0.2)) {
                                locationMode = mode
                            }
                            showingPhotoPickerForLocation = true
                        } else {
                            // Bei anderen Modi: Normal umschalten
                            withAnimation(.easeInOut(duration: 0.2)) {
                                locationMode = mode
                            }
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.title2)
                                .foregroundColor(locationMode == mode ? .white : .blue)
                            
                            Text(mode.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(locationMode == mode ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(locationMode == mode ? Color.blue : Color(.systemGray6))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Spezifische UI je nach Modus
            Group {
                switch locationMode {
                case .current:
                    currentLocationView
                case .manual:
                    manualLocationView
                case .map:
                    mapLocationView
                case .photo:
                    photoLocationView
                }
            }
            .animation(.easeInOut(duration: 0.3), value: locationMode)
            
            // Aktive Reise Info
            if let trip = activeTrip {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.green)
                    Text("Aktive Reise: \(trip.name ?? "Unbenannt")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var currentLocationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("GPS-Standort")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(currentLocationName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Aktualisieren") {
                    Task {
                        await updateCurrentLocation()
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            if currentLocationName.contains("Fehler") || currentLocationName.contains("nicht verfügbar") {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Standortdienste aktivieren oder anderen Modus wählen")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    private var manualLocationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pencil")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Standort eingeben")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            TextField("z.B. Berlin, Deutschland", text: $manualLocationName)
                .textFieldStyle(.roundedBorder)
            
            Text("Tipp: Gib Ort, Stadt oder Adresse ein")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var mapLocationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aus Karte wählen")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(selectedLocationName.isEmpty ? "Noch kein Standort gewählt" : selectedLocationName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Button(action: {
                showingMapPicker = true
            }) {
                HStack {
                    Image(systemName: "map.circle.fill")
                    Text(selectedCoordinate == nil ? "Standort wählen" : "Standort ändern")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            
            if let coordinate = selectedCoordinate {
                HStack {
                    Image(systemName: "location.circle")
                        .foregroundColor(.blue)
                    Text("Lat: \(coordinate.latitude, specifier: "%.6f"), Lng: \(coordinate.longitude, specifier: "%.6f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var photoLocationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aus Foto extrahieren")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(photoSelectedLocationName.isEmpty ? "Noch kein Foto ausgewählt" : photoSelectedLocationName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Button(action: {
                showingPhotoPickerForLocation = true
            }) {
                HStack {
                    Image(systemName: "photo.circle.fill")
                    Text(photoSelectedCoordinate == nil ? "Foto auswählen" : "Anderes Foto wählen")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            
            if let coordinate = photoSelectedCoordinate {
                HStack {
                    Image(systemName: "location.circle")
                        .foregroundColor(.blue)
                    Text("Lat: \(coordinate.latitude, specifier: "%.6f"), Lng: \(coordinate.longitude, specifier: "%.6f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("💡 Wähle ein Foto mit GPS-Daten aus deiner Galerie")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Titel")
                .font(.headline)
            
            TextField("z.B. Schöner Ausblick", text: $title)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal, 4)
    }
    
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Datum und Uhrzeit")
                .font(.headline)
            
            DatePicker(
                "Wann war das?",
                selection: $selectedDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .environment(\.locale, Locale(identifier: "de_DE"))
            
            // Formatiertes Datum in Deutsch anzeigen
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text(selectedDate.germanFormattedCompact)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                
                Spacer()
            }
            .padding(.top, 4)
            
            // Wetter-Sektion
            weatherSection
        }
        .padding(.horizontal, 4)
    }
    
    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let weather = weatherData {
                HStack(spacing: 8) {
                    Image(systemName: weather.weatherCondition.icon)
                        .foregroundColor(weather.weatherCondition.color)
                        .font(.title3)
                    
                    Text(weather.temperatureString)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(weather.weatherCondition.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Aktualisieren") {
                        Task {
                            await loadWeatherData()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            } else if weatherManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Wetterdaten werden geladen...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                Button("Wetterdaten laden") {
                    Task {
                        await loadWeatherData()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.vertical, 4)
            }
        }
    }
    
    private var textSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Beschreibung")
                .font(.headline)
            
            TextEditor(text: $text)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
        .padding(.horizontal, 4)
    }
    

    
    // Normale horizontale Scroll-Ansicht
    private var normalModeMediaScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Neue MediaItems
                ForEach(Array(mediaItems.enumerated()), id: \.offset) { index, mediaItem in
                    if let thumbnail = mediaItem.thumbnail {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            // Video-Indikator
                            if mediaItem.isVideo {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Image(systemName: "play.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.6), in: Circle())
                                        Spacer()
                                        if let duration = mediaItem.formattedDuration {
                                            Text(duration)
                                                .font(.caption2)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.black.opacity(0.6))
                                                .cornerRadius(4)
                                        }
                                    }
                                    .padding(4)
                                }
                            }
                            
                            // Löschen-Button (oben rechts)
                            VStack {
                                HStack {
                                    Spacer()
                                    Button {
                                        removeMediaItem(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.red)
                                            .background(Color.white, in: Circle())
                                    }
                                }
                                Spacer()
                            }
                            .padding(4)
                            
                            // Drehen-Button (unten rechts, nur für Fotos)
                            if mediaItem.isPhoto {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Button {
                                            rotateMediaItem(at: index)
                                        } label: {
                                            Image(systemName: "rotate.right")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .frame(width: 24, height: 24)
                                                .background(Color.black.opacity(0.7))
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                                .padding(4)
                            }
                        }
                    }
                }
                
                // Legacy Foto-Thumbnails (für Kompatibilität)
                ForEach(Array(photoDataArray.enumerated()), id: \.offset) { index, photoData in
                    if let uiImage = UIImage(data: photoData) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            // Löschen-Button (oben rechts)
                            VStack {
                                HStack {
                                    Spacer()
                                    Button {
                                        removePhoto(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.red)
                                            .background(Color.white, in: Circle())
                                    }
                                }
                                Spacer()
                            }
                            .padding(4)
                            
                            // Drehen-Button (unten rechts)
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Button {
                                        rotatePhoto(at: index)
                                    } label: {
                                        Image(systemName: "rotate.right")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .frame(width: 24, height: 24)
                                            .background(Color.black.opacity(0.7))
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .padding(4)
                        }
                    }
                }
                
                // Plus-Button als letztes Thumbnail (nur wenn noch Platz ist)
                if (photoDataArray.count + mediaItems.count) < 10 {
                    Button {
                        showMediaSourceSelection()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            Text("Hinzufügen")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .frame(width: 100, height: 100)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                                .blendMode(.overlay)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 2) // Kleiner Padding für die Schatten
        }
    }
    
    // Grid-Layout für Edit-Modus mit Drag-and-Drop
    private var editModeMediaGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MediaItems Liste
            if !mediaItems.isEmpty {
                Text("Medien")
                    .font(.headline)
                
                List {
                    ForEach(Array(mediaItems.enumerated()), id: \.offset) { index, mediaItem in
                        if let thumbnail = mediaItem.thumbnail {
                            HStack(spacing: 12) {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mediaItem.filename ?? "Unbenannt")
                                        .font(.headline)
                                        .lineLimit(1)
                                    
                                    Text(mediaItem.mediaTypeEnum?.displayName ?? "Medium")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if let duration = mediaItem.formattedDuration {
                                        Text(duration)
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Spacer()
                                
                                if mediaItem.isPhoto {
                                    Button {
                                        rotateMediaItem(at: index)
                                    } label: {
                                        Image(systemName: "rotate.right")
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                Button {
                                    removeMediaItem(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onMove(perform: moveMediaItems)
                    .onDelete { indexSet in
                        for index in indexSet {
                            removeMediaItem(at: index)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .frame(maxHeight: min(CGFloat(mediaItems.count * 80), 200))
            }
            
            // Legacy Photos Liste
            if !photoDataArray.isEmpty {
                Text("Fotos")
                    .font(.headline)
                
                List {
                    ForEach(Array(photoDataArray.enumerated()), id: \.offset) { index, photoData in
                        if let uiImage = UIImage(data: photoData) {
                            HStack(spacing: 12) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                VStack(alignment: .leading) {
                                    Text("Foto \(index + 1)")
                                        .font(.headline)
                                    Text("Legacy Foto")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    rotatePhoto(at: index)
                                } label: {
                                    Image(systemName: "rotate.right")
                                        .foregroundColor(.blue)
                                }
                                
                                Button {
                                    removePhoto(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onMove(perform: movePhotos)
                    .onDelete { indexSet in
                        for index in indexSet {
                            removePhoto(at: index)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .frame(maxHeight: min(CGFloat(photoDataArray.count * 80), 200))
            }
        }
        .padding(.horizontal, 2)
    }
    
    // MARK: - Unified Media Section
    
    private var unifiedMediaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Medien")
                .font(.headline)
            
            // Media-Import-Optionen
            HStack(spacing: 16) {
                // Foto/Video-Import
                Button {
                    showingMediaSourceDialog = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        Text("Foto/Video")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                
                // GPX-Import
                Button {
                    showingGPXImporter = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "location.north.line")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("GPS-Track")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                }
            }
            
            // Angehängte Medien anzeigen
            if hasAttachedMedia {
                attachedMediaView
            }
            
            // GPX-Track anzeigen (wenn importiert)
            if let gpxTrack = importedGPXTrack {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image("GPX_Thumb")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gpxTrack.name ?? "GPX Track")
                                .font(.headline)
                            
                            if let summary = createGPXSummary(for: gpxTrack) {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            removeGPXTrack()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
            }
        }
        .fileImporter(
            isPresented: $showingGPXImporter,
            allowedContentTypes: [
                .init(filenameExtension: "gpx")!,
                .xml,
                .data,
                .item
            ],
            allowsMultipleSelection: false
        ) { result in
            handleGPXImport(result)
        }
        .alert("GPX-Import Fehler", isPresented: $showingGPXImportError) {
            Button("OK") { }
        } message: {
            Text(gpxImportErrorMessage)
        }
        .sheet(isPresented: $showingGPXTrackDetail) {
            if let gpxTrack = importedGPXTrack {
                GPXTrackDetailView(gpxTrack: gpxTrack)
            }
        }
    }
    
    private var hasAttachedMedia: Bool {
        !photoDataArray.isEmpty || !mediaItems.isEmpty
    }
    
    private var attachedMediaView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Angehängte Medien")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Aktuelle MediaItems (neue Struktur)
            if !mediaItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(mediaItems.enumerated()), id: \.offset) { index, mediaItem in
                            attachedMediaCell(mediaItem: mediaItem, index: index)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Legacy PhotoDataArray (Migration Support)
            if !photoDataArray.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(photoDataArray.enumerated()), id: \.offset) { index, photoData in
                            legacyPhotoCell(photoData: photoData, index: index)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    private func attachedMediaCell(mediaItem: MediaItem, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            // Media-Thumbnail
            if let thumbnail = mediaItem.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )
            }
            
            // Media-Typ-Indikator
            VStack {
                Spacer()
                HStack {
                    if mediaItem.isVideo {
                        Label("Video", systemImage: "play.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(4)
            }
            
            // Entfernen-Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        removeMediaItem(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                            .background(Color.white, in: Circle())
                    }
                }
                Spacer()
            }
            .padding(4)
        }
    }
    
    private func legacyPhotoCell(photoData: Data, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Legacy-Indikator
            VStack {
                Spacer()
                HStack {
                    Text("Legacy")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(4)
                    Spacer()
                }
                .padding(4)
            }
            
            // Entfernen-Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        removePhoto(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                            .background(Color.white, in: Circle())
                    }
                }
                Spacer()
            }
            .padding(4)
        }
    }
    
    private func legacyGPXTrackView(_ gpxTrack: GPXTrack) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GPS-Track (Legacy)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "location.square")
                    .font(.title2)
                    .foregroundColor(.orange)
                    .frame(width: 50, height: 50)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(gpxTrack.name ?? "GPX Track")
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let summary = createGPXSummary(for: gpxTrack) {
                        Text(summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Details") {
                        showingGPXTrackDetail = true
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Entfernen") {
                        removeGPXTrack()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Media Section
    
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Medien")
                    .font(.headline)
                
                Spacer()
                
                Button("Hinzufügen") {
                    showingUnifiedImport = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            // Angehängte Medien anzeigen
            if hasAttachedMedia {
                attachedMediaView
            }
            
            // GPX-Track-Sektion 
            if let gpxTrack = importedGPXTrack {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image("GPX_Thumb")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gpxTrack.name ?? "GPX Track")
                                .font(.headline)
                            
                            if let summary = createGPXSummary(for: gpxTrack) {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Details") {
                            showingGPXTrackDetail = true
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                        
                        Button(action: {
                            removeGPXTrack()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .sheet(isPresented: $showingUnifiedImport) {
            MediaSourceSelectionView(
                isPresented: $showingUnifiedImport,
                showingImagePicker: $showingImagePicker,
                showingCamera: $showingCamera,
                showingGPXImporter: $showingGPXImporter
            )
        }
        .sheet(isPresented: $showingGPXTrackDetail) {
            if let gpxTrack = importedGPXTrack {
                GPXTrackDetailView(gpxTrack: gpxTrack)
            }
        }
        .alert("GPX-Import Fehler", isPresented: $showingGPXImportError) {
            Button("OK") { }
        } message: {
            Text(gpxImportErrorMessage)
        }
        .fileImporter(
            isPresented: $showingGPXImporter,
            allowedContentTypes: [
                .init(filenameExtension: "gpx")!,
                .xml,
                .data,
                .item
            ],
            allowsMultipleSelection: false
        ) { result in
            handleGPXImport(result)
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotos, maxSelectionCount: 10 - (photoDataArray.count + mediaItems.count), matching: .images)
        .onChange(of: selectedPhotos) {
            Task {
                await loadSelectedPhotos()
            }
        }
        .sheet(isPresented: $showingCamera) {
            NativeMediaPickerView { mediaItem in
                mediaItems.append(mediaItem)
                showingCamera = false
            }
        }
    }
    
    // MARK: - Media Handling
    
    private func addMediaFromData(_ data: Data, filename: String, isVideo: Bool) {
        // Erstelle MediaItem
        let mediaItem = MediaItem(context: viewContext)
        mediaItem.filename = filename
        mediaItem.mediaData = data
        mediaItem.timestamp = Date()
        mediaItem.mediaType = isVideo ? "video" : "photo"
        
        // Thumbnail generieren
        if isVideo {
            // Video-Thumbnail-Generierung würde hier implementiert
            if let videoThumbnail = UIImage(systemName: "video")?.pngData() {
                mediaItem.thumbnailData = videoThumbnail
            }
        } else {
            // Für Fotos ist das Original oft das Thumbnail
            mediaItem.thumbnailData = data
        }
        
        // EXIF-Daten für Fotos extrahieren
        if !isVideo {
            let exifInfo = PhotoExifExtractor.extractExifData(from: data)
            if exifInfo.hasValidData {
                extractedPhotoInfo.append(exifInfo)
            }
        }
        
        mediaItems.append(mediaItem)
    }
    
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
            
            if selectedTags.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Keine Tags ausgewählt")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Tags hinzufügen") {
                        showingTagSelection = true
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(selectedTags), id: \.objectID) { tag in
                        TagChip(tag: tag, isSelected: true) {
                            selectedTags.remove(tag)
                        }
                    }
                }
                
                Button("Tags bearbeiten") {
                    showingTagSelection = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingTagSelection) {
            TagSelectionViewForCreation(selectedTags: $selectedTags, viewContext: viewContext)
        }
    }
    
    private var poiLinkSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("POI Verknüpfung")
                .font(.headline)
            
            if let bucketListItem = selectedBucketListItem {
                // Ausgewähltes POI anzeigen
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Verknüpft mit:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Ändern") {
                            if tempPOIMemory == nil {
                                tempPOIMemory = createTemporaryMemory()
                            }
                            showingPOISelection = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        Button("Entfernen") {
                            selectedBucketListItem = nil
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    
                    // POI Info
                    HStack(spacing: 12) {
                        Image(systemName: iconForBucketListType(bucketListItem.type ?? ""))
                            .font(.title2)
                            .foregroundColor(colorForBucketListType(bucketListItem.type ?? ""))
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(colorForBucketListType(bucketListItem.type ?? "").opacity(0.1))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bucketListItem.name ?? "Unbekannt")
                                .font(.headline)
                                .lineLimit(1)
                            
                            if let country = bucketListItem.country {
                                Text(country)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
            } else {
                // Kein POI ausgewählt
                VStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Keine POI-Verknüpfung")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("POI verknüpfen") {
                        if tempPOIMemory == nil {
                            tempPOIMemory = createTemporaryMemory()
                        }
                        showingPOISelection = true
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingPOISelection, onDismiss: {
            // Nach dem Schließen: temporäres Memory löschen, falls nicht übernommen
            if let temp = tempPOIMemory {
                viewContext.delete(temp)
                tempPOIMemory = nil
            }
        }) {
            if let tempMemory = tempPOIMemory {
                BucketListLinkView(
                    memory: tempMemory,
                    selectedBucketListItem: $selectedBucketListItem
                )
                .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    private var saveButton: some View {
        Button("Erinnerung speichern") {
            saveMemory()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(title.isEmpty)
        .frame(maxWidth: .infinity)
    }
    
    private func loadSelectedPhotos() async {
        for photoItem in selectedPhotos {
            if let data = try? await photoItem.loadTransferable(type: Data.self) {
                // EXIF-Daten extrahieren bevor das Bild komprimiert wird
                let exifInfo = PhotoExifExtractor.extractExifData(from: data)
                if exifInfo.hasValidData {
                    // Standortname asynchron ermitteln für GPS-Koordinaten
                    if let coordinate = exifInfo.coordinate {
                        Task {
                            let locationName = await PhotoExifExtractor.getLocationName(for: coordinate)
                            await MainActor.run {
                                if let index = extractedPhotoInfo.firstIndex(where: { $0.id == exifInfo.id }) {
                                    extractedPhotoInfo[index].locationName = locationName
                                }
                            }
                        }
                    }
                    
                    await MainActor.run {
                        extractedPhotoInfo.append(exifInfo)
                    }
                }
                
                // Foto komprimieren für CloudKit-Kompatibilität
                if let compressedData = compressImageForCloudKit(data) {
                    photoDataArray.append(compressedData)
                }
            }
        }
        selectedPhotos.removeAll()
    }
    
    // MARK: - Photo Location Extraction
    
    private func loadPhotoForLocationExtraction(_ item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data {
                        let exifInfo = PhotoExifExtractor.extractExifData(from: data)
                        
                        if let coordinate = exifInfo.coordinate {
                            photoSelectedCoordinate = coordinate
                            
                            // Standortname laden und dann Karte öffnen
                            Task {
                                let locationName = await PhotoExifExtractor.getLocationName(for: coordinate)
                                await MainActor.run {
                                    photoSelectedLocationName = locationName
                                    showingMapEditorForPhoto = true
                                }
                            }
                        } else {
                            // Keine GPS-Daten gefunden
                            showingNoGPSAlert = true
                        }
                    }
                case .failure(let error):
                    print("Fehler beim Laden des Fotos für Standortextraktion: \(error)")
                    showingNoGPSAlert = true
                }
            }
        }
    }
    
    // MARK: - CloudKit Photo Optimization
    
    private func compressImageForCloudKit(_ imageData: Data) -> Data? {
        guard let uiImage = UIImage(data: imageData) else { return nil }
        
        // CloudKit Binary Limit: 1MB per Field
        let maxSizeBytes = 800 * 1024 // 800KB Sicherheit
        
        // Maximale Bildgrößen für gute Performance
        let maxWidth: CGFloat = 1200
        let maxHeight: CGFloat = 1200
        
        // Bild skalieren falls zu groß
        let scaledImage = resizeImage(uiImage, maxWidth: maxWidth, maxHeight: maxHeight)
        
        // Komprimierung mit angepasster Qualität
        var quality: CGFloat = 0.9
        var compressedData = scaledImage.jpegData(compressionQuality: quality)
        
        // Qualität reduzieren bis Größe unter Limit
        while let data = compressedData, data.count > maxSizeBytes && quality > 0.1 {
            quality -= 0.1
            compressedData = scaledImage.jpegData(compressionQuality: quality)
        }
        
        return compressedData
    }
    
    private func resizeImage(_ image: UIImage, maxWidth: CGFloat, maxHeight: CGFloat) -> UIImage {
        let currentSize = image.size
        
        // Berechne neues Seitenverhältnis
        let widthRatio = maxWidth / currentSize.width
        let heightRatio = maxHeight / currentSize.height
        let scaleFactor = min(widthRatio, heightRatio, 1.0) // Nicht vergrößern
        
        let newSize = CGSize(
            width: currentSize.width * scaleFactor,
            height: currentSize.height * scaleFactor
        )
        
        // Bild neu zeichnen
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
    
    private func removePhoto(at index: Int) {
        _ = withAnimation(.easeInOut(duration: 0.2)) {
            photoDataArray.remove(at: index)
        }
    }
    
    private func removeMediaItem(at index: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            let removedItem = mediaItems.remove(at: index)
            print("🗑️ \(removedItem.mediaTypeEnum?.displayName ?? "Medium") entfernt")
            print("   Verbleibende Medien: \(mediaItems.count)")
        }
    }
    
    private func showMediaSourceSelection() {
        showingMediaSourceDialog = true
    }
    
    private func saveMemory() {
        let memory = Memory(context: viewContext)
        memory.title = title
        memory.text = text
        memory.timestamp = selectedDate
        
        // WICHTIG: Creator zuweisen bei neuen Memories!
        if let currentUser = UserContextManager.shared.currentUser {
            memory.creator = currentUser
            print("✅ Neue Memory mit Creator erstellt: \(currentUser.displayName)")
        } else {
            print("⚠️ Warnung: Neue Memory ohne Creator erstellt - kein aktueller User gefunden")
        }
        
        // Standort hinzufügen
        if let coordinate = finalCoordinate {
            memory.latitude = coordinate.latitude
            memory.longitude = coordinate.longitude
        } else if locationMode == .manual {
            // Bei manueller Eingabe keine Koordinaten setzen (bleiben 0.0)
            memory.latitude = 0.0
            memory.longitude = 0.0
        }
        memory.locationName = finalLocationName
        
        // Mit aktiver Reise verknüpfen
        memory.trip = activeTrip
        
        // Tags hinzufügen
        for tag in selectedTags {
            memory.addToTags(tag)
            tag.usageCount += 1
            tag.lastUsedAt = Date()
        }
        
        // POI Verknüpfung hinzufügen
        if let bucketListItem = selectedBucketListItem {
            memory.linkToBucketListItem(bucketListItem)
        }
        
        // Wetterdaten hinzufügen
        if let weather = weatherData {
            memory.setWeatherData(weather)
        }
        
        // GPX-Track hinzufügen (wenn importiert)
        if let gpxTrack = importedGPXTrack {
            memory.attachGPXTrack(gpxTrack)
            print("✅ GPX-Track '\(gpxTrack.name ?? "Unbekannt")' mit Memory verknüpft")
        }
        
        // Medien hinzufügen (Fotos und Videos)
        var totalMediaSize = 0
        
        // Neue MediaItems korrekt zu Memory hinzufügen und persistieren
        for (index, mediaItem) in mediaItems.enumerated() {
            // Erstelle eine neue MediaItem-Instanz in diesem Kontext
            let newMediaItem = MediaItem(context: viewContext)
            newMediaItem.mediaData = mediaItem.mediaData
            newMediaItem.thumbnailData = mediaItem.thumbnailData
            newMediaItem.mediaType = mediaItem.mediaType
            newMediaItem.filename = mediaItem.filename
            newMediaItem.filesize = mediaItem.filesize
            newMediaItem.duration = mediaItem.duration
            newMediaItem.timestamp = mediaItem.timestamp ?? Date()
            newMediaItem.order = Int16(photoDataArray.count + index) // Nach Legacy Fotos
            newMediaItem.memory = memory
            
            if let mediaData = newMediaItem.mediaData {
                totalMediaSize += mediaData.count
                print("✅ \(newMediaItem.mediaTypeEnum?.displayName ?? "Medium") hinzugefügt: \(mediaData.count / 1024)KB")
            } else {
                print("⚠️ Warning: MediaItem ohne Daten hinzugefügt")
            }
        }
        
        // Legacy Fotos auch noch unterstützen (falls vorhanden)
        for (index, photoData) in photoDataArray.enumerated() {
            let photo = Photo(context: viewContext)
            photo.imageData = photoData
            photo.timestamp = Date()
            photo.order = Int16(index)
            photo.memory = memory
            
            totalMediaSize += photoData.count
            print("✅ Legacy Foto \(index + 1): \(photoData.count / 1024)KB")
        }
        
        print("📊 Gesamtgröße aller Medien: \(totalMediaSize / 1024)KB für Erinnerung: \(title)")
        print("📝 Speichere: \(photoDataArray.count) Legacy Fotos + \(mediaItems.count) MediaItems")
        
        do {
            try viewContext.save()
            print("✅ Erinnerung erfolgreich gespeichert mit \(photoDataArray.count) Legacy Fotos und \(mediaItems.count) MediaItems")
            
            // Alle Felder zurücksetzen
            resetAllFields()
            
            // Direkt zur Timeline View (MemoriesView) wechseln
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = 0
                }
            }
        } catch {
            print("❌ Fehler beim Speichern der Erinnerung: \(error)")
            if let nsError = error as NSError? {
                print("NSError Details:")
                print("Domain: \(nsError.domain)")
                print("Code: \(nsError.code)")
                print("UserInfo: \(nsError.userInfo)")
            }
        }
    }
    
    @MainActor
    private func updateCurrentLocation() async {
        currentLocationName = await locationManager.getCurrentLocationName()
    }
    
    // MARK: - Helper Functions
    
    private func iconForBucketListType(_ typeString: String) -> String {
        guard let type = BucketListType(rawValue: typeString) else {
            return "star.fill"
        }
        
        switch type {
        case .nationalpark: return "tree.fill"
        case .stadt: return "building.2.fill"
        case .spot: return "camera.fill"
        case .bauwerk: return "building.columns.fill"
        case .wanderung: return "figure.walk"
        case .radtour: return "bicycle"
        case .traumstrasse: return "road.lanes"
        case .sonstiges: return "star.fill"
        }
    }
    
    private func colorForBucketListType(_ typeString: String) -> Color {
        guard let type = BucketListType(rawValue: typeString) else {
            return .gray
        }
        
        switch type {
        case .nationalpark: return .green
        case .stadt: return .blue
        case .spot: return .orange
        case .bauwerk: return .brown
        case .wanderung: return .mint
        case .radtour: return .cyan
        case .traumstrasse: return .purple
        case .sonstiges: return .gray
        }
    }
    
    private func createTemporaryMemory() -> Memory? {
        let tempMemory = Memory(context: viewContext)
        tempMemory.title = title
        tempMemory.text = text
        tempMemory.timestamp = selectedDate
        tempMemory.locationName = finalLocationName
        
        // WICHTIG: Auch temporäre Memories brauchen einen Creator!
        if let currentUser = UserContextManager.shared.currentUser {
            tempMemory.creator = currentUser
            print("✅ Temporäre Memory mit Creator erstellt: \(currentUser.displayName)")
        } else {
            print("⚠️ Warnung: Temporäre Memory ohne Creator erstellt")
        }
        
        if let coordinate = finalCoordinate {
            tempMemory.latitude = coordinate.latitude
            tempMemory.longitude = coordinate.longitude
        }
        
        // Bereits ausgewählte Tags hinzufügen
        for tag in selectedTags {
            tempMemory.addToTags(tag)
        }
        
        return tempMemory
    }
    
    // MARK: - Reset Functions
    
    private func resetAllFields() {
        // Basis-Felder zurücksetzen
        title = ""
        text = ""
        selectedDate = Date()
        photoDataArray.removeAll()
        selectedPhotos.removeAll()
        mediaItems.removeAll()
        
        // Tags zurücksetzen
        selectedTags.removeAll()
        
        // POI Verknüpfung zurücksetzen
        selectedBucketListItem = nil
        
        // Wetterdaten zurücksetzen
        weatherData = nil
        
        // GPX-Track zurücksetzen
        importedGPXTrack = nil
        
        // GPX-Naming-Variablen zurücksetzen
        resetGPXImportState()
        
        // EXIF-Daten zurücksetzen
        extractedPhotoInfo.removeAll()
        selectedExifDate = nil
        selectedExifLocation = nil
        selectedExifLocationName = nil
        
        // Standort-Felder zurücksetzen
        locationMode = .current
        manualLocationName = ""
        selectedCoordinate = nil
        selectedLocationName = ""
        
        // Foto-Standort-Variablen zurücksetzen
        photoSelectedCoordinate = nil
        photoSelectedLocationName = ""
        selectedPhotosForLocation.removeAll()
        
        // Aktuellen Standort neu laden
        Task {
            await updateCurrentLocation()
            await loadWeatherData()
        }
    }
    
    // MARK: - Weather Functions
    
    private func loadWeatherData() async {
        // Bestimme den zu verwendenden Ortsnamen
        let locationName = finalLocationName.isEmpty ? "Aktueller Standort" : finalLocationName
        
        guard let coordinate = finalCoordinate else {
            // Keine Koordinaten verfügbar, verwende Demo-Wetter
            let demoWeather = weatherManager.createDemoWeatherData(for: locationName)
            await MainActor.run {
                weatherData = demoWeather
            }
            return
        }
        
        // Koordinaten verfügbar, lade Wetterdaten
        await weatherManager.fetchWeatherData(for: coordinate, locationName: locationName)
        
        await MainActor.run {
            weatherData = weatherManager.currentWeather
        }
    }
    
    // MARK: - EXIF-Vorschläge UI
    
    private var exifSuggestionsView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Foto-Informationen gefunden")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button("Ausblenden") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        extractedPhotoInfo.removeAll()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            Text("Foto-Metadaten gefunden. Übernehmen?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVStack(spacing: 8) {
                ForEach(Array(extractedPhotoInfo.enumerated()), id: \.offset) { index, photoInfo in
                    ExifSuggestionCard(
                        photoInfo: photoInfo,
                        index: index,
                        onApplyDate: { date in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = date
                            }
                        },
                        onApplyLocation: { coordinate, locationName in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                locationMode = .manual
                                selectedCoordinate = coordinate
                                selectedLocationName = locationName
                                manualLocationName = locationName
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 4)
    }
    
    private func rotatePhoto(at index: Int) {
        guard index < photoDataArray.count,
              let originalImage = UIImage(data: photoDataArray[index]) else {
            print("Fehler: Foto konnte nicht geladen werden")
            return
        }
        
        let rotatedImage = rotateUIImage(originalImage)
        
        if let rotatedData = rotatedImage.jpegData(compressionQuality: 0.8) {
            withAnimation(.easeInOut(duration: 0.3)) {
                photoDataArray[index] = rotatedData
            }
            print("✅ Foto \(index + 1) erfolgreich rotiert")
        } else {
            print("❌ Fehler beim Konvertieren des rotierten Fotos")
        }
    }
    
    private func rotateMediaItem(at index: Int) {
        guard index < mediaItems.count else {
            print("Fehler: Index außerhalb des Bereichs")
            return
        }
        
        let mediaItem = mediaItems[index]
        guard mediaItem.isPhoto,
              let imageData = mediaItem.mediaData,
              let originalImage = UIImage(data: imageData) else {
            print("Fehler: MediaItem-Foto konnte nicht geladen werden")
            return
        }
        
        let rotatedImage = rotateUIImage(originalImage)
        
        if let rotatedData = rotatedImage.jpegData(compressionQuality: 0.8) {
            withAnimation(.easeInOut(duration: 0.3)) {
                // Update MediaItem Data
                mediaItem.mediaData = rotatedData
                mediaItem.filesize = Int64(rotatedData.count)
                
                // Update Thumbnail
                let thumbnailSize = CGSize(width: 200, height: 200)
                let thumbnail = rotatedImage.resizedToFit(size: thumbnailSize)
                if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) {
                    mediaItem.thumbnailData = thumbnailData
                }
                
                // Trigger UI Update
                mediaItems[index] = mediaItem
            }
            print("✅ MediaItem-Foto \(index + 1) erfolgreich rotiert")
        } else {
            print("❌ Fehler beim Konvertieren des rotierten MediaItem-Fotos")
        }
    }
    
    private func rotateUIImage(_ image: UIImage) -> UIImage {
        // Rotiere das Bild um 90 Grad im Uhrzeigersinn
        let rotatedImage = image.rotate(radians: CGFloat.pi / 2)
        return rotatedImage
    }
    
    // MARK: - Move Functions
    
    private func moveMediaItems(from source: IndexSet, to destination: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            mediaItems.move(fromOffsets: source, toOffset: destination)
        }
    }
    
    private func movePhotos(from source: IndexSet, to destination: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            photoDataArray.move(fromOffsets: source, toOffset: destination)
        }
    }
}

// MARK: - Simple Map Picker View

struct SimpleMapPickerView: View {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var selectedLocationName: String
    let initialLocation: CLLocationCoordinate2D
    
    @Environment(\.dismiss) private var dismiss
    @State private var tempCoordinate: CLLocationCoordinate2D
    @State private var mapPosition: MapCameraPosition
    
    init(selectedCoordinate: Binding<CLLocationCoordinate2D?>, selectedLocationName: Binding<String>, initialLocation: CLLocationCoordinate2D) {
        self._selectedCoordinate = selectedCoordinate
        self._selectedLocationName = selectedLocationName
        self.initialLocation = initialLocation
        
        let startLocation = selectedCoordinate.wrappedValue ?? initialLocation
        _tempCoordinate = State(initialValue: startLocation)
        _mapPosition = State(initialValue: .region(MKCoordinateRegion(
            center: startLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }
    
    var body: some View {
        NavigationView {
            Map(position: $mapPosition) {
                UserAnnotation()
                
                Annotation("Ausgewählter Standort", coordinate: tempCoordinate) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        )
                        .shadow(radius: 3)
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                tempCoordinate = context.region.center
            }
            .navigationTitle("Standort wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Verwenden") {
                        selectedCoordinate = tempCoordinate
                        selectedLocationName = "Ausgewählter Standort"
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let locationManager = LocationManager(context: context)
    
    AddMemoryView(selectedTab: .constant(2))
        .environmentObject(locationManager)
        .environment(\.managedObjectContext, context)
}

// MARK: - Photo Map Editor For Location View (Simplified)

struct PhotoMapEditorForLocationView: View {
    @Binding var coordinate: CLLocationCoordinate2D?
    @Binding var locationName: String
    let initialCoordinate: CLLocationCoordinate2D
    
    @Environment(\.dismiss) private var dismiss
    @State private var mapPosition: MapCameraPosition
    @State private var tempCoordinate: CLLocationCoordinate2D
    @State private var isLoadingLocationName = false
    
    // GPS Track für aktive Reise anzeigen
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)],
        animation: .default
    )
    private var allTrips: FetchedResults<Trip>
    
    private var routePoints: [RoutePoint] {
        guard let activeTrip = allTrips.first(where: { $0.isActive }),
              let points = activeTrip.routePoints?.allObjects as? [RoutePoint] else {
            return []
        }
        return points.sorted { $0.timestamp ?? Date() < $1.timestamp ?? Date() }
    }
    
    init(coordinate: Binding<CLLocationCoordinate2D?>, locationName: Binding<String>, initialCoordinate: CLLocationCoordinate2D) {
        self._coordinate = coordinate
        self._locationName = locationName
        self.initialCoordinate = initialCoordinate
        
        _mapPosition = State(initialValue: .region(MKCoordinateRegion(
            center: initialCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005) // Näher herangezoomt
        )))
        _tempCoordinate = State(initialValue: initialCoordinate)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Vereinfachte Karte
                photoMapView
                
                // Info-Bereich
                infoSection
            }
            .navigationTitle("Position bestätigen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Verwenden") {
                        coordinate = tempCoordinate
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            await updateLocationName(for: tempCoordinate)
        }
        .onChange(of: tempCoordinate.latitude) { _, _ in
            updateLocationNameDebounced()
        }
        .onChange(of: tempCoordinate.longitude) { _, _ in
            updateLocationNameDebounced()
        }
    }
    
    private var photoMapView: some View {
        Map(position: $mapPosition) {
            UserAnnotation()
            
            // GPS Track der aktiven Reise anzeigen
            if routePoints.count > 1 {
                MapPolyline(coordinates: routePoints.map { 
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) 
                })
                .stroke(Color.blue, lineWidth: 3)
            }
            
            // GPS Track Punkte anzeigen
            ForEach(routePoints, id: \.objectID) { point in
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }
            
            // Foto-Position
            Annotation("Foto-Position", coordinate: tempCoordinate) {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(radius: 3)
            }
        }
        .onMapCameraChange(frequency: .continuous) { context in
            tempCoordinate = context.region.center
        }
    }
    
    private var infoSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "photo.circle.fill")
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("GPS-Position aus Foto")
                        .font(.headline)
                    
                    if isLoadingLocationName {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Lade Standortname...")
                                .font(.subheadline)
                        }
                    } else {
                        Text(locationName.isEmpty ? "Unbekannter Standort" : locationName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text("Lat: \(tempCoordinate.latitude, specifier: "%.6f"), Lng: \(tempCoordinate.longitude, specifier: "%.6f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: 4) {
                Text("💡 Bewege die Karte, um die Position bei Bedarf anzupassen")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if !routePoints.isEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text("Aktueller GPS-Track (\(routePoints.count) Punkte)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func updateLocationNameDebounced() {
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await updateLocationName(for: tempCoordinate)
        }
    }
    
    @MainActor
    private func updateLocationName(for coordinate: CLLocationCoordinate2D) async {
        isLoadingLocationName = true
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            if let placemark = placemarks.first {
                var components: [String] = []
                
                if let locality = placemark.locality {
                    components.append(locality)
                }
                if let country = placemark.country {
                    components.append(country)
                }
                
                if components.isEmpty, let name = placemark.name {
                    components.append(name)
                }
                
                locationName = components.joined(separator: ", ")
                if locationName.isEmpty {
                    locationName = "Unbekannter Standort"
                }
            } else {
                locationName = "Unbekannter Standort"
            }
        } catch {
            print("Geocoding Fehler: \(error.localizedDescription)")
            locationName = "Standortname nicht verfügbar"
        }
        
        isLoadingLocationName = false
    }
}

// MARK: - GPX Import Functions

extension AddMemoryView {
    func handleGPXImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { 
                print("❌ Keine URL aus File Importer erhalten")
                return 
            }
            
            print("🔍 Versuche GPX-Import von: \(url.path)")
            
            // Security-Scoped Resource für Sandboxing
            let hasAccess = url.startAccessingSecurityScopedResource()
            
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                // Überprüfe, ob die Datei lesbar ist
                guard url.isFileURL else {
                    print("❌ URL ist keine Datei-URL: \(url)")
                    return
                }
                
                guard FileManager.default.fileExists(atPath: url.path) else {
                    print("❌ Datei existiert nicht: \(url.path)")
                    return
                }
                
                // Versuche Datei zu lesen
                let data = try Data(contentsOf: url)
                let filename = url.lastPathComponent
                
                print("✅ GPX-Datei gelesen: \(filename), Größe: \(data.count) bytes")
                
                // GPX-Daten importieren
                let importResult = GPXImporter.importGPXData(data)
                
                switch importResult {
                case .success(let trackData):
                    print("✅ GPX-Daten erfolgreich geparst: \(trackData.trackPoints.count) Punkte")
                    
                    // Naming-Sheet vorbereiten und anzeigen
                    DispatchQueue.main.async {
                        self.prepareGPXNaming(data: data, filename: filename, trackData: trackData)
                    }
                    
                case .failure(let importError):
                    print("❌ Fehler beim GPX-Import: \(importError)")
                    
                    DispatchQueue.main.async {
                        self.gpxImportErrorMessage = "Die GPX-Datei konnte nicht verarbeitet werden:\n\n\(importError.localizedDescription)"
                        self.showingGPXImportError = true
                    }
                    
                    // Detaillierte Fehleranalyse
                    if let dataString = String(data: data.prefix(500), encoding: .utf8) {
                        print("🔍 Erste 500 Zeichen der Datei:")
                        print(dataString)
                    }
                }
                
            } catch let fileError as NSError {
                print("❌ Fehler beim Laden der GPX-Datei:")
                print("   Domain: \(fileError.domain)")
                print("   Code: \(fileError.code)")
                print("   Description: \(fileError.localizedDescription)")
                print("   UserInfo: \(fileError.userInfo)")
                
                // Spezifische Behandlung für Berechtigungsfehler
                DispatchQueue.main.async {
                    if fileError.domain == NSCocoaErrorDomain && fileError.code == NSFileReadNoPermissionError {
                        self.gpxImportErrorMessage = """
                        Berechtigung verweigert für GPX-Datei.
                        
                        💡 Lösungsvorschläge:
                        • Kopiere die Datei nach iCloud Drive
                        • Verwende 'Auf meinem iPhone' > 'Dateien'
                        • Prüfe, ob die Datei nicht schreibgeschützt ist
                        
                        Technischer Fehler: \(fileError.localizedDescription)
                        """
                    } else {
                        self.gpxImportErrorMessage = """
                        Fehler beim Laden der GPX-Datei:
                        
                        \(fileError.localizedDescription)
                        
                        Code: \(fileError.code)
                        """
                    }
                    self.showingGPXImportError = true
                }
            }
            
        case .failure(let error):
            print("❌ Fehler beim Datei-Import: \(error.localizedDescription)")
            
            DispatchQueue.main.async {
                self.gpxImportErrorMessage = """
                Fehler beim Öffnen des Datei-Browsers:
                
                \(error.localizedDescription)
                
                Versuche es erneut oder wähle eine andere Datei.
                """
                self.showingGPXImportError = true
            }
        }
    }
    
    func createGPXSummary(for gpxTrack: GPXTrack) -> String? {
        let distanceKm = gpxTrack.totalDistance / 1000.0
        let points = gpxTrack.totalPoints
        
        var components: [String] = []
        
        // Distanz
        components.append("\(String(format: "%.1f", distanceKm)) km")
        
        // Dauer
        if gpxTrack.totalDuration > 0 {
            let hours = Int(gpxTrack.totalDuration) / 3600
            let minutes = Int(gpxTrack.totalDuration) % 3600 / 60
            
            if hours > 0 {
                components.append("\(hours)h \(minutes)min")
            } else {
                components.append("\(minutes)min")
            }
        }
        
        // GPS-Punkte
        components.append("📍 \(points) Punkte")
        
        return components.joined(separator: " • ")
    }
    
    func removeGPXTrack() {
        if let gpxTrack = importedGPXTrack {
            viewContext.delete(gpxTrack)
            try? viewContext.save()
        }
        
        importedGPXTrack = nil
    }
    
    // MARK: - GPX Naming Helper Functions
    
    private func confirmGPXImport() {
        guard let trackData = pendingTrackData,
              let data = pendingGPXData else {
            print("❌ Fehler: Keine GPX-Daten zum Import vorhanden")
            return
        }
        
        let finalTrackName = gpxTrackName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            // GPX-Track mit benutzerdefiniertem Namen und Typ erstellen
            let gpxTrack = GPXImporter.createGPXTrack(
                from: trackData,
                originalData: data,
                filename: pendingGPXFilename,
                customTrackType: selectedTrackType,
                in: viewContext
            )
            
            // Benutzerdefinierten Namen setzen
            gpxTrack.name = finalTrackName
            
            // Core Data speichern
            try viewContext.save()
            
            // GPX-Track der Memory zuweisen
            self.importedGPXTrack = gpxTrack
            
            print("✅ GPX-Track erfolgreich mit Name '\(finalTrackName)' importiert")
            
            // Sheet schließen und Daten zurücksetzen
            resetGPXImportState()
            
        } catch {
            print("❌ Fehler beim Erstellen des GPX-Tracks: \(error)")
            self.gpxImportErrorMessage = "Fehler beim Speichern des GPX-Tracks:\n\(error.localizedDescription)"
            self.showingGPXImportError = true
            resetGPXImportState()
        }
    }
    
    private func cancelGPXImport() {
        resetGPXImportState()
    }
    
    private func resetGPXImportState() {
        showingGPXNaming = false
        pendingGPXData = nil
        pendingGPXFilename = ""
        pendingTrackData = nil
        gpxTrackName = ""
        selectedTrackType = "wandern"
    }
    
    private func prepareGPXNaming(data: Data, filename: String, trackData: GPXImporter.GPXTrackData) {
        pendingGPXData = data
        pendingGPXFilename = filename
        pendingTrackData = trackData
        
        // Ersten 15 Zeichen des Dateinamens als Default verwenden (ohne .gpx Extension)
        let nameWithoutExtension = filename.replacingOccurrences(of: ".gpx", with: "", options: .caseInsensitive)
        let defaultName = String(nameWithoutExtension.prefix(15))
        gpxTrackName = defaultName
        
        showingGPXNaming = true
    }
}

// MARK: - Camera functionality now uses native iOS UIImagePickerController
// All legacy camera code has been removed and replaced with NativeMediaPickerView

