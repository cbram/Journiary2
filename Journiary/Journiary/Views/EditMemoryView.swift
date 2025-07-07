//
//  EditMemoryView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import PhotosUI
import CoreData
import ImageIO
import CoreLocation

struct EditMemoryView: View {
    let memory: Memory
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var text = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDataArray: [Data] = []
    @State private var mediaItems: [MediaItem] = []
    @State private var currentLocationName = ""
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingSuccessAlert = false
    @State private var showingMediaCapture = false
    
    // EXIF-Datenextraktion - neue Variablen
    @State private var extractedPhotoInfo: [PhotoExifInfo] = []
    @State private var selectedDate: Date = Date()
    
    // Drag & Drop States
    @State private var draggedPhotoIndex: Int?
    @State private var draggedMediaIndex: Int?
    @State private var dragOffset: CGSize = .zero
    
    // POI-Verknüpfung
    @State private var selectedBucketListItem: BucketListItem?
    @State private var showingPOISelection = false
    
    // GPX Track Variablen (neu hinzugefügt)
    @State private var attachedGPXTrack: GPXTrack?
    @State private var showingGPXImporter = false
    @State private var showingGPXTrackDetail = false
    @State private var showingGPXImportError = false
    @State private var gpxImportErrorMessage = ""
    
    // GPX Naming States
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
    
    private var totalMediaCount: Int {
        return photoDataArray.count + mediaItems.count
    }
    
    // GPX Track vom Memory laden
    private var existingGPXTrack: GPXTrack? {
        memory.gpxTrack
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Titel-Eingabe ganz nach oben
                    titleSection
                    
                    // EXIF-Vorschläge Banner
                    if !extractedPhotoInfo.isEmpty {
                        exifSuggestionsView
                    }
                    
                    // Header
                    headerSection
                    
                    // Medien-Sektion (ohne GPX)
                    mediaSection
                    
                    // GPX Track Sektion (unter den Fotos)
                    if let gpxTrack = attachedGPXTrack ?? existingGPXTrack {
                        gpxTrackSection(gpxTrack)
                    }
                    
                    // Text-Eingabe
                    textSection
                    
                    // Tags-Sektion
                    EditableTagSection(memory: memory)
                    
                    // POI Verknüpfung Sektion
                    poiLinkSection
                    
                    // Speichern-Button
                    saveButton
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Erinnerung bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .alert("Erfolgreich gespeichert", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Deine Änderungen wurden erfolgreich gespeichert.")
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
            .sheet(isPresented: $showingGPXTrackDetail) {
                if let gpxTrack = attachedGPXTrack ?? existingGPXTrack {
                    GPXTrackDetailView(gpxTrack: gpxTrack)
                }
            }
            .sheet(isPresented: $showingGPXNaming) {
                gpxNamingSheet
            }
            .onAppear {
                loadMemoryData()
            }
            .sheet(isPresented: $showingMediaCapture) {
                NativeMediaPickerView { mediaItem in
                    mediaItems.append(mediaItem)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                
                Text(currentLocationName.isEmpty ? "Standort nicht verfügbar" : currentLocationName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let timestamp = memory.timestamp {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.gray)
                    
                    Text(timestamp.germanFormattedCompact)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Wetterdaten anzeigen falls vorhanden
                    if let weather = memory.weatherData {
                        HStack(spacing: 6) {
                            Image(systemName: weather.weatherCondition.icon)
                                .foregroundColor(weather.weatherCondition.color)
                                .font(.caption)
                            Text(weather.temperatureString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(weather.weatherCondition.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Medien (\(totalMediaCount)/10)")
                    .font(.headline)
                
                Spacer()
                
                Menu {
                    Button("Galerie") {
                        showingImagePicker = true
                    }
                    .disabled(totalMediaCount >= 10)
                    
                    Button("Kamera") {
                        showingMediaCapture = true
                    }
                    .disabled(totalMediaCount >= 10)
                    
                    Button("GPX-Track") {
                        showingGPXImporter = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus")
                            .font(.title3)
                        Text("Hinzufügen")
                            .font(.subheadline)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.bordered)
            }
            

            
            if photoDataArray.isEmpty && mediaItems.isEmpty && (attachedGPXTrack == nil && existingGPXTrack == nil) {
                // Keine Medien - Hinzufügen Button
                VStack(spacing: 12) {
                    Image(systemName: "camera.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("Medien hinzufügen")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 12) {
                        Button("Galerie") {
                            showingImagePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Kamera") {
                            showingMediaCapture = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("GPX-Track") {
                            showingGPXImporter = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 15))
            } else {
                // Medien anzeigen mit Drag & Drop
                if !photoDataArray.isEmpty || !mediaItems.isEmpty {
                    mediaGridWithDragAndDrop
                    
                    // Hinweis für Drag & Drop
                    Text("Tipp: Halte ein Medium lange gedrückt und ziehe es, um die Reihenfolge zu ändern")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotos, maxSelectionCount: 10 - (photoDataArray.count + mediaItems.count), matching: .images)
        .onChange(of: selectedPhotos) {
            Task {
                await loadSelectedPhotos()
            }
        }
    }
    
    private var mediaGridWithDragAndDrop: some View {
        VStack(spacing: 12) {
            // Legacy Photos mit Drag & Drop
            if !photoDataArray.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fotos")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 12) {
                        ForEach(Array(photoDataArray.enumerated()), id: \.offset) { index, photoData in
                            if let uiImage = UIImage(data: photoData) {
                                DraggablePhotoThumbnail(
                                    image: uiImage,
                                    index: index,
                                    isDragging: draggedPhotoIndex == index,
                                    dragOffset: draggedPhotoIndex == index ? dragOffset : .zero,
                                    onRotate: { rotatePhoto(at: index) },
                                    onDelete: { removePhoto(at: index) },
                                    onDragStart: { draggedPhotoIndex = index },
                                    onDragChange: { value in
                                        dragOffset = value.translation
                                    },
                                    onDragEnd: { value in
                                        handlePhotoDrop(from: index, with: value.translation)
                                        draggedPhotoIndex = nil
                                        dragOffset = .zero
                                    }
                                )
                                .zIndex(draggedPhotoIndex == index ? 1 : 0)
                            }
                        }
                    }
                }
            }
            
            // MediaItems mit Drag & Drop
            if !mediaItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Videos & Medien")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 12) {
                        ForEach(Array(mediaItems.enumerated()), id: \.offset) { index, mediaItem in
                            if let thumbnail = mediaItem.thumbnail {
                                DraggableMediaThumbnail(
                                    mediaItem: mediaItem,
                                    thumbnail: thumbnail,
                                    index: index,
                                    isDragging: draggedMediaIndex == index,
                                    dragOffset: draggedMediaIndex == index ? dragOffset : .zero,
                                    onRotate: mediaItem.isPhoto ? { rotateMediaItem(at: index) } : nil,
                                    onDelete: { removeMediaItem(at: index) },
                                    onDragStart: { draggedMediaIndex = index },
                                    onDragChange: { value in
                                        dragOffset = value.translation
                                    },
                                    onDragEnd: { value in
                                        handleMediaDrop(from: index, with: value.translation)
                                        draggedMediaIndex = nil
                                        dragOffset = .zero
                                    }
                                )
                                .zIndex(draggedMediaIndex == index ? 1 : 0)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 2)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Titel")
                .font(.headline)
            
            TextField("z.B. Schöner Ausblick", text: $title)
                .textFieldStyle(.roundedBorder)
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
    }
    
    private var saveButton: some View {
        Button("Änderungen speichern") {
            saveMemory()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(title.isEmpty)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Functions
    
    private func loadMemoryData() {
        title = memory.title ?? ""
        text = memory.text ?? ""
        currentLocationName = memory.locationName ?? ""
        
        // Lade bestehende POI-Verknüpfung
        selectedBucketListItem = memory.bucketListItem
        
        // Lade bestehenden GPX Track
        if let existingTrack = memory.gpxTrack {
            attachedGPXTrack = existingTrack
        }
        
        // Lade bestehende Fotos (nur Legacy Photos)
        var allPhotoData: [Data] = []
        
        // Legacy Photos hinzufügen
        if let photoSet = memory.photos {
            let photos = (photoSet.allObjects as? [Photo])?.sorted { $0.order < $1.order } ?? []
            allPhotoData.append(contentsOf: photos.compactMap { $0.imageData })
        }
        
        photoDataArray = allPhotoData
        
        // Lade bestehende MediaItems (Fotos und Videos)
        if let mediaItemSet = memory.mediaItems {
            let items = (mediaItemSet.allObjects as? [MediaItem])?.sorted { $0.order < $1.order } ?? []
            mediaItems = items
        }
    }
    
    private func loadSelectedPhotos() async {
        for photoItem in selectedPhotos {
            if let data = try? await photoItem.loadTransferable(type: Data.self) {
                // EXIF-Daten extrahieren bevor das Bild komprimiert wird
                let exifInfo = PhotoExifExtractor.extractExifData(from: data)
                if exifInfo.hasValidData {
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
    
    private func removePhoto(at index: Int) {
        _ = withAnimation(.easeInOut(duration: 0.2)) {
            photoDataArray.remove(at: index)
        }
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
    
    private func rotateUIImage(_ image: UIImage) -> UIImage {
        // Rotiere das Bild um 90 Grad im Uhrzeigersinn
        let rotatedImage = image.rotate(radians: CGFloat.pi / 2)
        return rotatedImage
    }
    
    private func saveMemory() {
        // Update Memory
        memory.title = title
        memory.text = text
        memory.timestamp = memory.timestamp // Behalte ursprünglichen Zeitstempel
        
        // WICHTIG: Sync-Status für Upload setzen bei Bearbeitung
        memory.syncStatus = .needsUpload
        memory.updatedAt = Date()
        
        // Lösche alle alten Fotos (Legacy)
        if let existingPhotos = memory.photos?.allObjects as? [Photo] {
            for photo in existingPhotos {
                viewContext.delete(photo)
            }
        }
        
        // Lösche alle alten MediaItems
        if let existingMediaItems = memory.mediaItems?.allObjects as? [MediaItem] {
            for mediaItem in existingMediaItems {
                viewContext.delete(mediaItem)
            }
        }
        
        // Füge neue Legacy Fotos hinzu
        for (index, photoData) in photoDataArray.enumerated() {
            let photo = Photo(context: viewContext)
            photo.imageData = photoData
            photo.timestamp = Date()
            photo.order = Int16(index)
            photo.memory = memory
        }
        
        // Füge neue MediaItems hinzu
        for (index, mediaItem) in mediaItems.enumerated() {
            let newMediaItem = MediaItem(context: viewContext)
            newMediaItem.mediaData = mediaItem.mediaData
            newMediaItem.thumbnailData = mediaItem.thumbnailData
            newMediaItem.mediaType = mediaItem.mediaType
            newMediaItem.filename = mediaItem.filename
            newMediaItem.filesize = mediaItem.filesize
            newMediaItem.duration = mediaItem.duration
            newMediaItem.timestamp = mediaItem.timestamp
            newMediaItem.order = Int16(photoDataArray.count + index) // Nach Legacy Fotos
            newMediaItem.memory = memory
        }
        
        // POI Verknüpfung aktualisieren
        if let bucketListItem = selectedBucketListItem {
            memory.linkToBucketListItem(bucketListItem)
        } else {
            memory.unlinkFromBucketListItem()
        }
        
        // GPX Track Verknüpfung aktualisieren
        if let gpxTrack = attachedGPXTrack {
            memory.gpxTrack = gpxTrack
            print("✅ GPX-Track '\(gpxTrack.name ?? "Unbekannt")' mit Memory verknüpft")
        }
        
        do {
            try viewContext.save()
            print("Erinnerung '\(title)' erfolgreich aktualisiert mit \(photoDataArray.count) Fotos, \(mediaItems.count) MediaItems und \(memory.gpxTrack != nil ? "1 GPX-Track" : "0 GPX-Tracks")")
            showingSuccessAlert = true
        } catch {
            print("Fehler beim Aktualisieren der Erinnerung: \(error)")
            if let nsError = error as NSError? {
                print("NSError Details:")
                print("Domain: \(nsError.domain)")
                print("Code: \(nsError.code)")
                print("UserInfo: \(nsError.userInfo)")
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
    
    // MARK: - POI Verknüpfung
    
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
        .sheet(isPresented: $showingPOISelection) {
            BucketListLinkView(
                memory: memory,
                selectedBucketListItem: $selectedBucketListItem
            )
            .environment(\.managedObjectContext, viewContext)
        }
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
            
            Text("Neues Aufnahmedatum gefunden. Erinnerung aktualisieren?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVStack(spacing: 8) {
                ForEach(Array(extractedPhotoInfo.enumerated()), id: \.offset) { index, photoInfo in
                    EditExifSuggestionCard(
                        photoInfo: photoInfo,
                        index: index,
                        memory: memory,
                        onApplyDate: { date in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = date
                                // Datum direkt in Memory übernehmen
                                memory.timestamp = date
                                do {
                                    try viewContext.save()
                                } catch {
                                    print("Fehler beim Aktualisieren des Datums: \(error)")
                                }
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
    
    private func removeMediaItem(at index: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            let removedItem = mediaItems.remove(at: index)
            print("🗑️ \(removedItem.mediaTypeEnum?.displayName ?? "Medium") entfernt")
            print("   Verbleibende Medien: \(mediaItems.count)")
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
    
    // MARK: - Drag & Drop Helper Functions
    
    private func calculateTargetIndex(for translation: CGSize, in arrayCount: Int, from currentIndex: Int) -> Int {
        // Berechne, wie viele Spalten (Zellen) das Element verschoben wurde
        let columns = 3
        let cellWidth: CGFloat = 110 // ca. Breite einer Zelle inkl. Abstand
        let rowHeight: CGFloat = 110 // ca. Höhe einer Zelle inkl. Abstand
        let deltaColumn = Int((translation.width / cellWidth).rounded())
        let deltaRow = Int((translation.height / rowHeight).rounded())
        let delta = deltaColumn + deltaRow * columns
        let newIndex = min(max(currentIndex + delta, 0), arrayCount - 1)
        return newIndex
    }
    
    private func handlePhotoDrop(from sourceIndex: Int, with translation: CGSize) {
        let dragDistance = sqrt(translation.width * translation.width + translation.height * translation.height)
        guard dragDistance > 50 else { return }
        let targetIndex = calculateTargetIndex(for: translation, in: photoDataArray.count, from: sourceIndex)
        if targetIndex != sourceIndex && targetIndex < photoDataArray.count {
            withAnimation(.easeInOut(duration: 0.3)) {
                let movedPhoto = photoDataArray.remove(at: sourceIndex)
                photoDataArray.insert(movedPhoto, at: targetIndex)
            }
        }
    }
    
    private func handleMediaDrop(from sourceIndex: Int, with translation: CGSize) {
        let dragDistance = sqrt(translation.width * translation.width + translation.height * translation.height)
        guard dragDistance > 50 else { return }
        let targetIndex = calculateTargetIndex(for: translation, in: mediaItems.count, from: sourceIndex)
        if targetIndex != sourceIndex && targetIndex < mediaItems.count {
            withAnimation(.easeInOut(duration: 0.3)) {
                let movedMedia = mediaItems.remove(at: sourceIndex)
                mediaItems.insert(movedMedia, at: targetIndex)
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
    
    // MARK: - GPX Track Functions
    
    private func gpxTrackSection(_ gpxTrack: GPXTrack) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GPS-Track")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // Gesamter Bereich klickbar mit Löschen-Button
            Button(action: {
                showingGPXTrackDetail = true
            }) {
                HStack(spacing: 16) {
                    // GPX Thumbnail mit Löschen-Button
                    ZStack(alignment: .topTrailing) {
                        Image("GPX_Thumb")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        
                        // Löschen-Button (oben rechts im Thumbnail)
                        Button {
                            removeGPXTrack()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 24, height: 24)
                                )
                        }
                        .offset(x: -6, y: 6)
                    }
                    
                    // Informationen - mittig zum Thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Spacer()
                        
                        Text(gpxTrack.name ?? "GPX Track")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        if let summary = createGPXSummary(for: gpxTrack) {
                            Text(summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func createGPXSummary(for gpxTrack: GPXTrack) -> String? {
        let distanceKm = gpxTrack.totalDistance / 1000.0
        
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
        
        return components.joined(separator: " • ")
    }
    
    private func removeGPXTrack() {
        // Bestehenden Track aus Memory entfernen
        if let existingTrack = memory.gpxTrack {
            memory.gpxTrack = nil
            viewContext.delete(existingTrack)
        }
        
        // Neuen Track entfernen
        if let newTrack = attachedGPXTrack {
            viewContext.delete(newTrack)
        }
        
        attachedGPXTrack = nil
        
        do {
            try viewContext.save()
            print("✅ GPX-Track erfolgreich entfernt")
        } catch {
            print("❌ Fehler beim Entfernen des GPX-Tracks: \(error)")
        }
    }
    
    private func handleGPXImport(_ result: Result<[URL], Error>) {
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
                }
                
            } catch let fileError as NSError {
                print("❌ Fehler beim Laden der GPX-Datei:")
                print("   Domain: \(fileError.domain)")
                print("   Code: \(fileError.code)")
                print("   Description: \(fileError.localizedDescription)")
                
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
    // MARK: - GPX Naming Helper Functions
    
    private func confirmGPXImport() {
        guard let trackData = pendingTrackData,
              let data = pendingGPXData else {
            print("❌ Fehler: Keine GPX-Daten zum Import vorhanden")
            return
        }
        
        let finalTrackName = gpxTrackName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            // Bestehenden Track entfernen (falls vorhanden)
            if let existingTrack = memory.gpxTrack {
                viewContext.delete(existingTrack)
            }
            
            // Neuen GPX-Track mit benutzerdefiniertem Namen und Typ erstellen
            let gpxTrack = GPXImporter.createGPXTrack(
                from: trackData,
                originalData: data,
                filename: pendingGPXFilename,
                customTrackType: selectedTrackType,
                in: viewContext
            )
            
            // Benutzerdefinierten Namen setzen
            gpxTrack.name = finalTrackName
            
            // Track mit Memory verknüpfen
            memory.gpxTrack = gpxTrack
            
            // Core Data speichern
            try viewContext.save()
            
            // UI aktualisieren
            self.attachedGPXTrack = gpxTrack
            
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

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Beispiel-Memory für Preview
    let memory = Memory(context: context)
    memory.title = "Test Erinnerung"
    memory.text = "Dies ist eine Test-Beschreibung"
    memory.timestamp = Date()
    memory.locationName = "Berlin, Deutschland"
    
    return EditMemoryView(memory: memory)
        .environment(\.managedObjectContext, context)
}

// MARK: - EditMemoryView_Previews

struct EditMemoryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let memory = Memory(context: context)
        memory.title = "Testmemory"
        memory.text = "Das ist eine Testbeschreibung"
        
        return EditMemoryView(memory: memory)
            .environment(\.managedObjectContext, context)
    }
}

// MARK: - Draggable Thumbnail Components

struct DraggablePhotoThumbnail: View {
    let image: UIImage
    let index: Int
    let isDragging: Bool
    let dragOffset: CGSize
    let onRotate: () -> Void
    let onDelete: () -> Void
    let onDragStart: () -> Void
    let onDragChange: (DragGesture.Value) -> Void
    let onDragEnd: (DragGesture.Value) -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Löschen-Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 24, height: 24)
                            )
                    }
                }
                Spacer()
            }
            .padding(6)
            
            // Drehen-Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        onRotate()
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
            .padding(6)
            
            // Drag-Indikator
            VStack {
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                    Spacer()
                }
                Spacer()
            }
            .padding(4)
        }
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .offset(dragOffset)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .animation(.easeInOut(duration: 0.2), value: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        onDragStart()
                    }
                    onDragChange(value)
                }
                .onEnded { value in
                    onDragEnd(value)
                }
        )
    }
}

struct DraggableMediaThumbnail: View {
    let mediaItem: MediaItem
    let thumbnail: UIImage
    let index: Int
    let isDragging: Bool
    let dragOffset: CGSize
    let onRotate: (() -> Void)?
    let onDelete: () -> Void
    let onDragStart: () -> Void
    let onDragChange: (DragGesture.Value) -> Void
    let onDragEnd: (DragGesture.Value) -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
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
            
            // Löschen-Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 24, height: 24)
                            )
                    }
                }
                Spacer()
            }
            .padding(6)
            
            // Drehen-Button (nur für Fotos)
            if let onRotate = onRotate, mediaItem.isPhoto {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            onRotate()
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
            
            // Drag-Indikator
            VStack {
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                    Spacer()
                }
                Spacer()
            }
            .padding(4)
        }
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .offset(dragOffset)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .animation(.easeInOut(duration: 0.2), value: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        onDragStart()
                    }
                    onDragChange(value)
                }
                .onEnded { value in
                    onDragEnd(value)
                }
        )
    }
}

