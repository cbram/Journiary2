//
//  MemoriesView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import CoreData
import Foundation
import AVFoundation
import AVKit

// Kompatibilität: alter Name → neuer View
typealias ImprovedFullScreenPhotoView = FullScreenPhotoView

struct MemoriesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Optionaler Trip für die Filterung
    var trip: Trip?
    
    // Optionale Memory zum Fokussieren
    var focusedMemory: Memory?
    
    // Dynamischer FetchRequest
    @FetchRequest private var memories: FetchedResults<Memory>
    
    @State private var selectedMemoryForDetail: Memory?
    @State private var selectedMemoryForEdit: Memory?
    @State private var showingDeleteAlert = false
    @State private var memoryToDelete: Memory?
    @State private var showingProfileView = false
    @State private var showingSettingsView = false
    
    private let columns = [
        GridItem(.flexible())
    ]
    
    // MARK: - Teilen/Exportieren
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    
    // MARK: - Add Memory Sheet
    @State private var showingAddMemorySheet = false
    @State private var addMemoryTabIndex = 0
    
    var oldestFirst: Bool = false
    
    // Initializer, um den FetchRequest basierend auf dem Trip zu konfigurieren
    init(trip: Trip? = nil, focusedMemory: Memory? = nil, oldestFirst: Bool = false) {
        self.trip = trip
        self.focusedMemory = focusedMemory
        self.oldestFirst = oldestFirst
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        if let trip = trip {
            request.predicate = NSPredicate(format: "trip == %@", trip)
        }
        
        _memories = FetchRequest(fetchRequest: request, animation: .default)
    }
    
    var body: some View {
        // Der NavigationView wird nur hinzugefügt, wenn die Ansicht nicht bereits in einer ist.
        // Dies ist der Fall, wenn sie vom Tab aus aufgerufen wird.
        if trip == nil {
            NavigationView {
                content
            }
        } else {
            content
        }
    }
    
    private var content: some View {
        Group {
            if memories.isEmpty {
                emptyStateView
            } else {
                memoriesGridView
            }
        }
        .navigationTitle(trip == nil ? "Erinnerungen" : trip?.name ?? "Unbenannte Reise")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if trip == nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingSettingsView = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingProfileView = true
                    }) {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                    }
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedMemoryForDetail) { memory in
            MemoryDetailView(memory: memory)
        }
        .sheet(item: $selectedMemoryForEdit) { memory in
            EditMemoryView(memory: memory)
        }
        .alert("Erinnerung löschen", isPresented: $showingDeleteAlert) {
            Button("Löschen", role: .destructive) {
                if let memory = memoryToDelete {
                    deleteMemory(memory)
                }
            }
            Button("Abbrechen", role: .cancel) {
                memoryToDelete = nil
            }
        } message: {
            Text("Möchtest du diese Erinnerung wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.")
        }
        .onAppear {
            // MemoriesView ist aktiv
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = shareImage {
                ActivityViewController(activityItems: [image])
            }
        }
        .sheet(isPresented: $showingProfileView) {
            ProfileView()
                .environmentObject(LocationManager(context: viewContext))
        }
        .sheet(isPresented: $showingSettingsView) {
            SettingsView()
                .environmentObject(LocationManager(context: viewContext))
        }
        // Sheet zum Hinzufügen einer Erinnerung, falls kein Tab-Wechsel möglich ist
        .sheet(isPresented: $showingAddMemorySheet) {
            AddMemoryView(selectedTab: $addMemoryTabIndex)
                .environmentObject(LocationManager(context: viewContext))
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("Noch keine Erinnerungen")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(trip == nil ? "Füge deine ersten Reiseerinnerungen hinzu, indem du den Tab 'Hinzufügen' verwendest." : "Für diese Reise gibt es noch keine Erinnerungen.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if trip == nil {
                Button("Erinnerung hinzufügen") {
                    showingAddMemorySheet = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var memoriesGridView: some View {
        let sortedMemories: [Memory] = {
            if oldestFirst {
                return memories.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
            } else {
                return memories.sorted { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }
            }
        }()
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(sortedMemories, id: \ .objectID) { memory in
                        MemoryCard(memory: memory) {
                            // Sicherstellen, dass das Memory-Objekt noch gültig ist
                            guard !memory.isFault && memory.managedObjectContext != nil else {
                                return
                            }
                            selectedMemoryForDetail = memory
                        }
                        .id(memory.objectID) // ID für ScrollViewReader
                        .contextMenu {
                            Button("Bearbeiten", systemImage: "pencil") {
                                selectedMemoryForEdit = memory
                            }
                            Button("Löschen", systemImage: "trash", role: .destructive) {
                                memoryToDelete = memory
                                showingDeleteAlert = true
                            }
                        }
                    }
                    .onDelete(perform: deleteMemories)
                }
                .padding()
            }
            .onAppear {
                // Scroll zur fokussierten Memory, falls vorhanden
                if let focusedMemory = focusedMemory {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.8)) {
                            proxy.scrollTo(focusedMemory.objectID, anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Debug Functions
    
    private func debugAllMemories() {
        print("=== DEBUG: Alle Erinnerungen überprüfen ===")
        print("Anzahl Erinnerungen: \(memories.count)")
        print("Thread: \(Thread.isMainThread ? "Main" : "Background")")
        print("ViewContext: \(viewContext)")
        
        for (index, memory) in memories.enumerated() {
            print("Memory \(index + 1): \(memory.title ?? "Unbenannt")")
            print("  - Timestamp: \(memory.timestamp?.description ?? "Kein Timestamp")")
            print("  - Location: \(memory.locationName ?? "Kein Standort")")
            print("  - ObjectID: \(memory.objectID)")
            print("  - isFault: \(memory.isFault)")
            print("  - hasContext: \(memory.managedObjectContext != nil)")
            
            if let photoSet = memory.photos {
                let photoArray = photoSet.allObjects as? [Photo] ?? []
                print("  - Fotos: \(photoArray.count)")
                
                for (photoIndex, photo) in photoArray.enumerated() {
                    let hasData = photo.imageData != nil
                    let dataSize = photo.imageData?.count ?? 0
                    print("    Foto \(photoIndex + 1): hasData=\(hasData), size=\(dataSize / 1024)KB, order=\(photo.order), isFault=\(photo.isFault)")
                }
            } else {
                print("  - Fotos: 0 (photoSet ist nil)")
            }
            print("---")
        }
        print("=== Ende Debug ===")
    }
     
    private func deleteMemories(offsets: IndexSet) {
        for index in offsets {
            deleteMemory(memories[index])
        }
    }
    
    private func deleteMemory(_ memory: Memory) {
        viewContext.delete(memory)
        
        do {
            try viewContext.save()
            print("Erinnerung '\(memory.title ?? "Unbenannt")' erfolgreich gelöscht")
            memoryToDelete = nil
        } catch {
            print("Fehler beim Löschen der Erinnerung: \(error)")
        }
    }
}

struct MemoryCard: View {
    let memory: Memory
    let onTap: () -> Void
    
    @State private var primaryImage: UIImage?
    @State private var isLoadingImage = false
    @State private var photoCount = 0
    
    // Liefert alle Fotos (Legacy + MediaItems mit isPhoto)
    private var allPhotos: [(data: Data, order: Int)] {
        var photos: [(data: Data, order: Int)] = [];
        if let photoSet = memory.photos {
            let photoArray = (photoSet.allObjects as? [Photo])?.sorted { $0.order < $1.order } ?? []
            for photo in photoArray {
                if let imageData = photo.imageData {
                    photos.append((data: imageData, order: Int(photo.order)))
                }
            }
        }
        if let mediaItemSet = memory.mediaItems {
            let mediaItemArray = (mediaItemSet.allObjects as? [MediaItem])?.sorted { $0.order < $1.order } ?? []
            for mediaItem in mediaItemArray where mediaItem.isPhoto {
                if let imageData = mediaItem.mediaData {
                    photos.append((data: imageData, order: Int(mediaItem.order + 1000)))
                }
            }
        }
        return photos.sorted { $0.order < $1.order }
    }
    
    // Hilfsfunktion: Gibt true zurück, wenn keine Fotos, aber mindestens ein Video vorhanden ist
    private var hasOnlyVideos: Bool {
        // Prüfe, ob es keine Fotos gibt
        let hasPhotos: Bool = {
            if let photoSet = memory.photos, (photoSet.allObjects as? [Photo])?.isEmpty == false {
                return true
            }
            if let mediaItemSet = memory.mediaItems, (mediaItemSet.allObjects as? [MediaItem])?.contains(where: { $0.isPhoto }) == true {
                return true
            }
            return false
        }()
        // Prüfe, ob es mindestens ein Video gibt
        let hasVideos: Bool = {
            if let mediaItemSet = memory.mediaItems, (mediaItemSet.allObjects as? [MediaItem])?.contains(where: { $0.isVideo }) == true {
                return true
            }
            return false
        }()
        return !hasPhotos && hasVideos
    }
    
    // Hole Video-Thumbnails für Timeline-Darstellung bei Video-only Erinnerungen
    private var firstVideoThumbnail: UIImage? {
        guard let mediaItemSet = memory.mediaItems else { return nil }
        let mediaItemArray = (mediaItemSet.allObjects as? [MediaItem])?.sorted { $0.order < $1.order } ?? []
        
        // Suche nach dem ersten Video mit Thumbnail
        for mediaItem in mediaItemArray where mediaItem.isVideo {
            if let thumbnail = mediaItem.thumbnail {
                return thumbnail
            }
        }
        return nil
    }
    
    // Zählt alle Medien (Fotos + Videos)
    private var allMediaCount: Int {
        var count = 0
        if let photoSet = memory.photos {
            count += (photoSet.allObjects as? [Photo])?.count ?? 0
        }
        if let mediaItemSet = memory.mediaItems {
            count += (mediaItemSet.allObjects as? [MediaItem])?.count ?? 0
        }
        return count
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Foto oder Placeholder
                ZStack(alignment: .topTrailing) {
                    if let primaryImage = primaryImage {
                        ZStack {
                            Image(uiImage: primaryImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                            // Video-Indikator wenn nur Videos vorhanden sind
                            if hasOnlyVideos && firstVideoThumbnail != nil {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Image(systemName: "play.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.6), in: Circle())
                                            .font(.title2)
                                        Spacer()
                                    }
                                    .padding(8)
                                }
                            }
                        }
                    } else if isLoadingImage {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 180)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            )
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 180)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundColor(.gray)
                            )
                    }
                    // Medien-Anzahl Badge (Fotos + Videos)
                    if allMediaCount > 1 {
                        Text("\(allMediaCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(6)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.title ?? "Unbenannt")
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let locationName = memory.locationName {
                        Label(locationName, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let timestamp = memory.timestamp {
                        HStack(spacing: 8) {
                            Text(timestamp.germanFormattedDateOnly)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            // GPX-Track Indikator
                            if memory.hasGPXTrack {
                                Image(systemName: "map")
                                    .foregroundColor(.blue)
                                    .font(.caption2)
                            }
                            
                            // Wetterdaten anzeigen falls vorhanden
                            if let weather = memory.weatherData {
                                HStack(spacing: 4) {
                                    Image(systemName: weather.weatherCondition.icon)
                                        .foregroundColor(weather.weatherCondition.color)
                                        .font(.caption2)
                                    Text(weather.temperatureString)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Tags anzeigen
                    TagDisplayView(
                        memory: memory,
                        maxDisplayedTags: 3,
                        style: .compact
                    )
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            loadPrimaryImageAsync()
        }
        .onChange(of: memory.objectID) {
            loadPrimaryImageAsync()
        }
    }
    
    private func loadPrimaryImageAsync() {
        // Reset state
        primaryImage = nil
        // photoCount = allPhotos.count // Entfernt, da nicht mehr benötigt
        // Versuche zuerst ein Foto zu laden
        if let firstPhotoData = allPhotos.first?.data {
            isLoadingImage = true
            // Lade Bild asynchron im Hintergrund
            Task {
                let image = await Task.detached(priority: .userInitiated) {
                    UIImage(data: firstPhotoData)
                }.value
                await MainActor.run {
                    self.primaryImage = image
                    self.isLoadingImage = false
                }
            }
        }
        // Falls keine Fotos vorhanden, nutze Video-Thumbnail
        else if let videoThumbnail = firstVideoThumbnail {
            primaryImage = videoThumbnail
        }
    }
}

struct MemoryDetailView: View {
    let memory: Memory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedPhotoIndex = 0
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var loadedImages: [Int: UIImage] = [:]
    @State private var isLoadingPhotos = false
    @State private var showingFullScreenPhotos = false
    @State private var showingMediaCollection = false
    @State private var showingPOIDetail = false
    @State private var showingGPXTrackDetail = false
    
    // Kombiniere Legacy Photos und neue MediaItems für MemoryDetailView
    private var allPhotoData: [(data: Data, order: Int)] {
        var photos: [(data: Data, order: Int)] = []
        
        // Legacy Photos hinzufügen
        if let photoSet = memory.photos {
            let photoArray = (photoSet.allObjects as? [Photo])?.sorted { $0.order < $1.order } ?? []
            for photo in photoArray {
                if let imageData = photo.imageData {
                    photos.append((data: imageData, order: Int(photo.order)))
                }
            }
        }
        
        // MediaItems (nur Fotos) hinzufügen
        if let mediaItemSet = memory.mediaItems {
            let mediaItemArray = (mediaItemSet.allObjects as? [MediaItem])?.sorted { $0.order < $1.order } ?? []
            for mediaItem in mediaItemArray where mediaItem.isPhoto {
                if let imageData = mediaItem.mediaData {
                    photos.append((data: imageData, order: Int(mediaItem.order + 1000))) // Offset um Konflikte zu vermeiden
                }
            }
        }
        
        return photos.sorted { $0.order < $1.order }
    }
    
    // Alle MediaItems (Fotos und Videos)
    private var allMediaItems: [MediaItem] {
        guard let mediaItemSet = memory.mediaItems else { return [] }
        return (mediaItemSet.allObjects as? [MediaItem])?.sorted { $0.order < $1.order } ?? []
    }
    
    // Hat Videos
    private var hasVideos: Bool {
        return allMediaItems.contains { $0.isVideo }
    }
    
    // Legacy photos für Kompatibilität mit FullScreenPhotoView
    private var photos: [Photo] {
        guard let photoSet = memory.photos else { return [] }
        return (photoSet.allObjects as? [Photo])?.sorted { $0.order < $1.order } ?? []
    }
    
    var body: some View {
        NavigationView {
            mainContent
                .navigationTitle("Erinnerung")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .sheet(isPresented: $showingEditView) { EditMemoryView(memory: memory) }
                .alert("Erinnerung löschen", isPresented: $showingDeleteAlert) { deleteAlertButtons } message: { Text("Möchtest du diese Erinnerung wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.") }
                .onAppear { loadPhotosAsync() }
                .fullScreenCover(isPresented: $showingFullScreenPhotos) {
                    ImprovedFullScreenPhotoView(allPhotoData: allPhotoData, selectedPhotoIndex: $selectedPhotoIndex)
                }
                .sheet(isPresented: $showingPOIDetail) {
                    if let bucketListItem = memory.bucketListItem {
                        BucketListItemDetailCompactView(item: bucketListItem, selectedTab: .constant(0))
                    }
                }
                .sheet(isPresented: $showingGPXTrackDetail) {
                    if let gpxTrack = memory.gpxTrack {
                        GPXTrackDetailView(gpxTrack: gpxTrack)
                    }
                }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if memory.isFault || memory.managedObjectContext == nil {
            unavailableView
        } else {
            memoryContentView
        }
    }
    
    private var unavailableView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 50)).foregroundColor(.orange)
            Text("Erinnerung nicht verfügbar").font(.headline)
            Text("Diese Erinnerung konnte nicht geladen werden. Möglicherweise wurde sie von einem anderen Gerät gelöscht oder geändert.")
                .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            Button("Schließen") { dismiss() }.buttonStyle(.borderedProminent)
        }.padding()
    }
    
    private var memoryContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Titel
                Text(memory.title ?? "Unbenannt")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Standort und Datum
                memoryInfoSection
                
                // Foto-Galerie (Legacy Photos nur für Rückwärtskompatibilität)
                if !allPhotoData.isEmpty {
                    photoGallerySection
                }
                
                // MediaItems Sektion (Videos und weitere Medien)
                if !allMediaItems.isEmpty {
                    mediaItemsSection
                }
                
                // GPX-Track Sektion (wenn vorhanden)
                if memory.hasGPXTrack {
                    gpxTrackSection
                }
                
                // Tags
                if !memory.tagArray.isEmpty {
                    EditableTagSection(memory: memory)
                }
                
                // POI Verknüpfung
                if let bucketListItem = memory.bucketListItem {
                    poiSection(bucketListItem: bucketListItem)
                }
                
                // Beschreibung
                if let text = memory.text, !text.isEmpty {
                    Text("Beschreibung")
                        .font(.headline)
                        .padding(.top)
                    
                    Text(text)
                        .font(.body)
                }
                
                // Koordinaten (für Debug)
                if memory.latitude != 0 && memory.longitude != 0 {
                    coordinatesSection
                }
                
                Spacer(minLength: 50)
            }
            .padding()
        }
    }
    
    private var photoGallerySection: some View {
        VStack(spacing: 12) {
            // Hauptfoto mit Swipe-Funktionalität
            if !allPhotoData.isEmpty {
                TabView(selection: $selectedPhotoIndex) {
                    ForEach(Array(allPhotoData.enumerated()), id: \.offset) { index, photoData in
                        if let loadedImage = loadedImages[index] {
                            Image(uiImage: loadedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .tag(index)
                                .onTapGesture {
                                    showingFullScreenPhotos = true
                                }
                        } else if isLoadingPhotos && index == selectedPhotoIndex {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 300)
                                .overlay(
                                    ProgressView("Lädt Foto...")
                                        .progressViewStyle(CircularProgressViewStyle())
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .tag(index)
                        } else {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 300)
                                .overlay(
                                    VStack {
                                        Image(systemName: "photo")
                                            .font(.system(size: 50))
                                            .foregroundColor(.gray)
                                        Text("Foto konnte nicht geladen werden")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .tag(index)
                        }
                    }
                }
                .frame(height: 300)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            
            // Foto-Thumbnails (wenn mehr als ein Foto)
            if allPhotoData.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 8) {
                                ForEach(Array(allPhotoData.enumerated()), id: \.offset) { index, photoData in
                                    if let loadedImage = loadedImages[index] {
                                        Button {
                                            selectedPhotoIndex = index
                                        } label: {
                                            Image(uiImage: loadedImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 78, height: 78)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(selectedPhotoIndex == index ? Color.blue : Color.clear, lineWidth: 2)
                                                )
                                        }
                                    } else {
                                        Rectangle()
                                            .fill(Color(.systemGray5))
                                            .frame(width: 78, height: 78)
                                            .overlay(
                                                ProgressView()
                                                    .scaleEffect(0.5)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                    }
                }
            }
            
            // Foto-Info
            if allPhotoData.count > 1 {
                Text("\(selectedPhotoIndex + 1) von \(allPhotoData.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var mediaItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Medien")
                    .font(.headline)
                
                Spacer()
                
                Text("\(allMediaItems.count) Element\(allMediaItems.count == 1 ? "" : "e")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if allMediaItems.count > 3 {
                    Button("Alle anzeigen") {
                        showingMediaCollection = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // Grid für MediaItems
            let columns = [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ]
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(allMediaItems.prefix(6).enumerated()), id: \.element.objectID) { index, mediaItem in
                    MediaThumbnailPreview(mediaItem: mediaItem) {
                        if allMediaItems.count <= 3 {
                            // Für wenige Medien, direkt anzeigen
                            if mediaItem.isVideo {
                                // Video in Vollbild öffnen
                                showingMediaCollection = true
                            } else {
                                // Foto in Vollbild öffnen - springe zu dem MediaItem Foto
                                if let mediaItemIndex = allMediaItems.firstIndex(of: mediaItem) {
                                    selectedPhotoIndex = allPhotoData.count - allMediaItems.filter { $0.isPhoto }.count + mediaItemIndex
                                }
                                showingFullScreenPhotos = true
                            }
                        } else {
                            // Für viele Medien, zur MediaCollection navigieren
                            showingMediaCollection = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingMediaCollection) {
            MediaCollectionView(
                mediaItems: allMediaItems,
                onAddMedia: {
                    // Hier könnte Add-Funktionalität eingefügt werden
                },
                onDeleteMedia: { mediaItem in
                    memory.removeMediaItem(mediaItem)
                    do {
                        try viewContext.save()
                    } catch {
                        print("Fehler beim Löschen des MediaItems: \(error)")
                    }
                },
                onReorderMedia: { reorderedItems in
                    memory.reorderMediaItems(reorderedItems)
                    do {
                        try viewContext.save()
                    } catch {
                        print("Fehler beim Neuordnen der MediaItems: \(error)")
                    }
                }
            )
        }
    }
    
    private func loadPhotosAsync() {
        let allPhotos = allPhotoData
        guard !allPhotos.isEmpty else { return }
        
        print("🔄 DEBUG: Starte asynchrones Laden von \(allPhotos.count) Fotos (Legacy + MediaItems)")
        isLoadingPhotos = true
        
        Task {
            let tempImages = await Task.detached(priority: .userInitiated) {
                var images: [Int: UIImage] = [:]
                
                for (index, photoData) in allPhotos.enumerated() {
                    if let image = UIImage(data: photoData.data) {
                        images[index] = image
                    }
                }
                
                return images
            }.value
            
            await MainActor.run {
                self.loadedImages = tempImages
                self.isLoadingPhotos = false
                print("✅ DEBUG: Alle \(tempImages.count) Fotos erfolgreich geladen")
            }
        }
    }
    
    private var memoryInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Datum und Uhrzeit in einer Zeile: DD.MM.YYYY • HH:MM
            if let timestamp = memory.timestamp {
                HStack(spacing: 4) {
                    Text(getFormattedDate(timestamp))
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("•")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(getFormattedTime(timestamp))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Ort, Flagge und Wetter in einer Zeile
            HStack(spacing: 6) {
                // Ort (bereinigt um das Land, falls eine Flagge angezeigt wird)
                if let locationName = memory.locationName, !locationName.isEmpty {
                    let country = getCountryFromMemory()
                    let cleanedLocationName = country != nil ? removeCountryFromLocationName(locationName, country: country!) : locationName
                    
                    Text(cleanedLocationName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                // Flagge des Landes (falls verfügbar)
                if let country = getCountryFromMemory() {
                    Text(CountryHelper.flag(for: country))
                        .font(.subheadline)
                }
                
                // Trennzeichen vor Wetter (nur wenn Wetter vorhanden)
                if memory.weatherData != nil {
                    Text("•")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Wetterdaten (Icon + Temperatur, kein Text)
                if let weather = memory.weatherData {
                    HStack(spacing: 4) {
                        Image(systemName: weather.weatherCondition.icon)
                            .foregroundColor(weather.weatherCondition.color)
                            .font(.subheadline)
                        
                        Text(weather.temperatureString)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
            }
            
            // Trip-Info (falls vorhanden)
            if let trip = memory.trip {
                Label(trip.name ?? "Unbenannte Reise", 
                      systemImage: "figure.walk")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
    
    private var coordinatesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Koordinaten")
                .font(.headline)
                .padding(.top)
            
            Text("Breitengrad: \(memory.latitude, specifier: "%.6f")")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Längengrad: \(memory.longitude, specifier: "%.6f")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - GPX Track Section
    
    private var gpxTrackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GPS-Track")
                .font(.headline)
            
            if let gpxTrack = memory.gpxTrack {
                Button(action: {
                    showingGPXTrackDetail = true
                }) {
                    HStack(spacing: 12) {
                        // GPX Thumbnail
                        Image("GPX_Thumb")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gpxTrack.name ?? "GPX Track")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            if let summary = memory.gpxTrackSummary {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - POI Section
    
    private func poiSection(bucketListItem: BucketListItem) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
            Text("Verknüpftes POI")
                .font(.headline)
                .padding(.bottom, -10)
            Button(action: {
                showingPOIDetail = true
            }) {
                HStack(spacing: 14) {
                    // POI Icon
                    Image(systemName: iconForBucketListType(bucketListItem.type ?? ""))
                        .font(.title2)
                        .foregroundColor(colorForBucketListType(bucketListItem.type ?? ""))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(colorForBucketListType(bucketListItem.type ?? "").opacity(0.1))
                        )
                    VStack(alignment: .leading, spacing: 0) {
                        Text(bucketListItem.name ?? "Unbekanntes POI")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            // Land mit Flagge
                            if let country = bucketListItem.country, !country.isEmpty {
                                let flag = CountryHelper.flag(for: country)
                                Text(flag)
                                    .font(.title3)
                                    .padding(.trailing, 2)
                            }
                            // Region
                            if let region = bucketListItem.region, !region.isEmpty {
                                Text("• \(region)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        // Typ
                        Text(displayNameForBucketListType(bucketListItem.type ?? ""))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(colorForBucketListType(bucketListItem.type ?? "").opacity(0.15))
                            )
                            .foregroundColor(colorForBucketListType(bucketListItem.type ?? ""))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Helper Functions
    
    private func getFormattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
    
    private func getFormattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func getCountryFromMemory() -> String? {
        // 1. Versuche das Land aus der Bucket List Verknüpfung zu holen
        if let bucketListItem = memory.bucketListItem,
           let country = bucketListItem.country,
           !country.isEmpty {
            return country
        }
        
        // 2. Versuche das Land aus dem Ortsnamen zu extrahieren
        if let locationName = memory.locationName,
           !locationName.isEmpty {
            return extractCountryFromLocationName(locationName)
        }
        
        // 3. Falls verfügbar: Verwende Reverse Geocoding mit den Koordinaten
        // Für Performance-Gründe wird hier erstmal nil zurückgegeben
        // TODO: Implementiere asynchrones Reverse Geocoding für Koordinaten
        return nil
    }
    
    private func extractCountryFromLocationName(_ locationName: String) -> String? {
        // Typische Formate: "Stadt, Land" oder "Ort - Land" oder "Ort, Region, Land"
        let components = locationName.components(separatedBy: CharacterSet(charactersIn: ","))
        
        // Nimm den letzten Komponenten als potenzielles Land
        if let lastComponent = components.last?.trimmingCharacters(in: .whitespaces),
           !lastComponent.isEmpty {
            // Prüfe ob es ein bekanntes Land ist (über CountryHelper)
            let flag = CountryHelper.flag(for: lastComponent)
            if flag != "🏳️" { // CountryHelper gibt 🏳️ als Fallback zurück
                return lastComponent
            }
        }
        
        // Falls der letzte Komponente kein Land ist, versuche den vorletzten
        if components.count >= 2 {
            let secondToLast = components[components.count - 2].trimmingCharacters(in: .whitespaces)
            let flag = CountryHelper.flag(for: secondToLast)
            if flag != "🏳️" {
                return secondToLast
            }
        }
        
        return nil
    }
    
    private func removeCountryFromLocationName(_ locationName: String, country: String) -> String {
        // Entferne das Land aus dem Ortsnamen, falls es am Ende steht
        let components = locationName.components(separatedBy: CharacterSet(charactersIn: ","))
        
        // Filtere Komponenten, die das erkannte Land enthalten
        let filteredComponents = components.compactMap { component in
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            // Entferne den Komponenten, wenn er exakt dem Land entspricht
            return trimmed.lowercased() == country.lowercased() ? nil : trimmed
        }
        
        // Falls alle Komponenten entfernt wurden, gib den ursprünglichen Namen zurück
        if filteredComponents.isEmpty {
            return locationName
        }
        
        // Füge die verbleibenden Komponenten zusammen
        return filteredComponents.joined(separator: ", ")
    }
    
    // MARK: - Helper Functions for POI
    
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
    
    private func displayNameForBucketListType(_ typeString: String) -> String {
        guard let type = BucketListType(rawValue: typeString) else {
            return "Sonstiges"
        }
        switch type {
        case .nationalpark: return "Nationalpark"
        case .stadt: return "Stadt"
        case .spot: return "Spot"
        case .bauwerk: return "Bauwerk"
        case .wanderung: return "Wanderung"
        case .radtour: return "Radtour"
        case .traumstrasse: return "Traumstraße"
        case .sonstiges: return "Sonstiges"
        }
    }
    
    // MARK: - Functions
    
    private func shareCurrentPhoto() {
        guard !allPhotoData.isEmpty else { return }
        
        let currentPhotoData = allPhotoData[selectedPhotoIndex].data
        guard let image = UIImage(data: currentPhotoData) else { return }
        
        // Activity View Controller für Teilen
        let activityViewController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // iPad Support
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, 
                                          y: rootViewController.view.bounds.midY, 
                                          width: 0, 
                                          height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func deleteMemory() {
        viewContext.delete(memory)
        
        do {
            try viewContext.save()
            print("Erinnerung '\(memory.title ?? "Unbenannt")' erfolgreich gelöscht")
            dismiss()
        } catch {
            print("Fehler beim Löschen der Erinnerung: \(error)")
        }
    }
}

// MARK: - Helper Views für Sheet-Präsentation

struct MemoryDetailSheetView: View {
    let selectedMemory: Memory?
    let selectedMemoryID: NSManagedObjectID?
    let memories: [Memory]
    let onDismiss: () -> Void
    let onForceClose: () -> Void
    
    private func findMemory(by objectID: NSManagedObjectID) -> Memory? {
        return memories.first { $0.objectID == objectID }
    }
    
    var body: some View {
        Group {
            if let selectedMemory = selectedMemory, 
               !selectedMemory.isFault,
               selectedMemory.managedObjectContext != nil {
                // Direktes selectedMemory ist verfügbar und gültig
                MemoryDetailView(memory: selectedMemory)
                    .onAppear {
                        print("✅ DEBUG: Sheet mit direktem selectedMemory präsentiert für: \(selectedMemory.title ?? "Unbenannt")")
                    }
                    .onDisappear {
                        print("❌ DEBUG: MemoryDetailView onDisappear aufgerufen")
                        onDismiss()
                    }
            } else if let selectedMemoryID = selectedMemoryID,
                      let foundMemory = findMemory(by: selectedMemoryID) {
                // Fallback: Finde Memory über ID
                MemoryDetailView(memory: foundMemory)
                    .onAppear {
                        print("🔄 DEBUG: Sheet mit gefundenem Memory über ID präsentiert (Fallback)")
                    }
                    .onDisappear {
                        onDismiss()
                    }
            } else {
                // Fallback View wenn kein Memory verfügbar
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Erinnerung nicht verfügbar")
                        .font(.headline)
                    
                    Text("Diese Erinnerung konnte nicht geladen werden.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Schließen") {
                        onForceClose()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .onAppear {
                    print("⚠️ DEBUG: Kein gültiges Memory für Sheet gefunden!")
                }
            }
        }
    }
}

struct MemoryEditSheetView: View {
    let selectedMemory: Memory?
    let selectedMemoryID: NSManagedObjectID?
    let memories: [Memory]
    let onDismiss: () -> Void
    let onForceClose: () -> Void
    
    private func findMemory(by objectID: NSManagedObjectID) -> Memory? {
        return memories.first { $0.objectID == objectID }
    }
    
    var body: some View {
        Group {
            if let selectedMemory = selectedMemory, 
               !selectedMemory.isFault,
               selectedMemory.managedObjectContext != nil {
                EditMemoryView(memory: selectedMemory)
                    .onAppear {
                        print("✅ DEBUG: EditView mit direktem selectedMemory präsentiert")
                    }
                    .onDisappear {
                        onDismiss()
                    }
            } else if let selectedMemoryID = selectedMemoryID,
                      let foundMemory = findMemory(by: selectedMemoryID) {
                EditMemoryView(memory: foundMemory)
                    .onAppear {
                        print("🔄 DEBUG: EditView mit gefundenem Memory über ID präsentiert (Fallback)")
                    }
                    .onDisappear {
                        onDismiss()
                    }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Erinnerung nicht verfügbar")
                        .font(.headline)
                    
                    Button("Schließen") {
                        onForceClose()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .onAppear {
                    print("⚠️ DEBUG: Kein gültiges Memory für EditView gefunden!")
                }
            }
        }
    }
}

// MARK: - Verbesserte Apple-Style Zoom/Pan Gesture Handler
struct ImprovedZoomPanGestureHandler: UIViewRepresentable {
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @Binding var isZoomed: Bool
    let minScale: CGFloat
    let maxScale: CGFloat
    let containerSize: CGSize
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = true
        
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePinch))
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePan))
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleDoubleTap))
        
        doubleTapGesture.numberOfTapsRequired = 2
        
        // Verbesserte Gesture-Delegation
        pinchGesture.delegate = context.coordinator
        panGesture.delegate = context.coordinator
        doubleTapGesture.delegate = context.coordinator
        
        view.addGestureRecognizer(pinchGesture)
        view.addGestureRecognizer(panGesture)
        view.addGestureRecognizer(doubleTapGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.containerSize = containerSize
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: ImprovedZoomPanGestureHandler
        var lastScale: CGFloat = 1.0
        var lastOffset: CGSize = .zero
        var containerSize: CGSize
        
        init(_ parent: ImprovedZoomPanGestureHandler) {
            self.parent = parent
            self.containerSize = parent.containerSize
        }
        
        // MARK: - Verbesserte Gesture Delegation
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Erlaube simultane Pinch und Pan unserer eigenen Gesten
            if gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer {
                return true
            }
            
            // Blockiere andere Gesten (wie TabView) nur wenn gezoomt
            if parent.isZoomed {
                return false
            }
            
            return true
        }
        
        // Pan-Gesture nur wenn gezoomt
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer {
                return parent.scale > 1.05 // Pan nur wenn gezoomt
            }
            return true
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                lastScale = parent.scale
            case .changed:
                let newScale = min(max(lastScale * gesture.scale, parent.minScale), parent.maxScale)
                parent.scale = newScale
                parent.isZoomed = newScale > 1.05
            case .ended, .cancelled, .failed:
                // Snap-back Feature für bessere UX
                if parent.scale < 1.15 {
                    withAnimation(.easeOut(duration: 0.25)) {
                        parent.scale = 1.0
                        parent.offset = .zero
                        parent.isZoomed = false
                    }
                }
            default:
                break
            }
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard parent.scale > 1.05 else { return }
            
            switch gesture.state {
            case .began:
                lastOffset = parent.offset
            case .changed:
                let translation = gesture.translation(in: gesture.view)
                let newOffset = CGSize(
                    width: lastOffset.width + translation.x,
                    height: lastOffset.height + translation.y
                )
                parent.offset = constrainedOffset(newOffset)
            case .ended, .cancelled, .failed:
                break
            default:
                break
            }
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if parent.scale > 1.05 {
                    // Zoom out
                    parent.scale = 1.0
                    parent.offset = .zero
                    parent.isZoomed = false
                } else {
                    // Zoom in
                    parent.scale = 2.5
                    parent.isZoomed = true
                    parent.offset = .zero
                }
            }
        }
        
        private func constrainedOffset(_ proposedOffset: CGSize) -> CGSize {
            guard parent.scale > 1.0 else { return .zero }
            
            let scaledSize = CGSize(
                width: containerSize.width * parent.scale,
                height: containerSize.height * parent.scale
            )
            
            let maxOffsetX = max(0, (scaledSize.width - containerSize.width) / 2)
            let maxOffsetY = max(0, (scaledSize.height - containerSize.height) / 2)
            
            return CGSize(
                width: min(max(proposedOffset.width, -maxOffsetX), maxOffsetX),
                height: min(max(proposedOffset.height, -maxOffsetY), maxOffsetY)
            )
        }
    }
}

// MARK: - Verbesserte Apple-Style Zoomable Image View
struct AppleStyleZoomableImageViewMemories: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var isZoomed: Bool = false
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .animation(.easeOut(duration: 0.25), value: scale)
                    .animation(.easeOut(duration: 0.25), value: offset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Verbesserte Gesture-Handler
                ImprovedZoomPanGestureHandler(
                    scale: $scale,
                    offset: $offset,
                    isZoomed: $isZoomed,
                    minScale: minScale,
                    maxScale: maxScale,
                    containerSize: geometry.size
                )
            }
        }
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        // Blockiere nur TabView-Gesten, nicht unsere eigenen Zoom-Gesten
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in },
            including: isZoomed ? .all : .subviews
        )
    }
}

struct FullScreenPhotoView: View {
    let photos: [Photo]
    let loadedImages: [Int: UIImage]
    @Binding var selectedPhotoIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPhotoStates: [Int: PhotoState] = [:]
    @State private var showingToolbar = true
    
    // PhotoState beschreibt Zoom- & Pan-Zustand pro Bild
    struct PhotoState {
        var scale: CGFloat = 1.0
        var offset: CGSize = .zero
        var lastScale: CGFloat = 1.0
        var lastOffset: CGSize = .zero
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if !photos.isEmpty {
                    VStack {
                        ZStack {
                            TabView(selection: $selectedPhotoIndex) {
                                ForEach(photos.indices, id: \.self) { index in
                                    photoView(for: index)
                                        .tag(index)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                            .gesture(
                                // Globale Tap-Geste für Toolbar Toggle
                                TapGesture()
                                    .onEnded {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            showingToolbar.toggle()
                                        }
                                    }
                            )
                        }
                        
                        // Punkte (PageControl) unter dem Bild
                        if photos.count > 1 && showingToolbar {
                            HStack(spacing: 8) {
                                ForEach(0..<photos.count, id: \.self) { idx in
                                    Circle()
                                        .fill(idx == selectedPhotoIndex ? Color.white : Color.gray.opacity(0.5))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.top, 8)
                            .transition(.opacity)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showingToolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Schließen") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                    
                    ToolbarItem(placement: .principal) {
                        if photos.count > 1 {
                            Text("\(selectedPhotoIndex + 1) von \(photos.count)")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                    }
                }
            }
            .onAppear {
                // Initialisiere Photo States
                for index in photos.indices {
                    currentPhotoStates[index] = PhotoState()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    @ViewBuilder
    private func photoView(for index: Int) -> some View {
        ZStack {
            if let image = loadedImages[index] {
                ZoomableImageView(
                    image: image,
                    photoState: Binding(
                        get: { currentPhotoStates[index] ?? PhotoState() },
                        set: { currentPhotoStates[index] = $0 }
                    ),
                    isCurrentPhoto: selectedPhotoIndex == index,
                    onResetZoom: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPhotoStates[index] = PhotoState()
                        }
                    }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: selectedPhotoIndex) { oldIndex, newIndex in
            // Reset zoom when switching photos if needed
            if newIndex != index {
                // Keep zoom state for non-current photos
            }
        }
    }
}

// MARK: - ZoomableImageView

struct ZoomableImageView: View {
    let image: UIImage
    @Binding var photoState: FullScreenPhotoView.PhotoState
    let isCurrentPhoto: Bool
    let onResetZoom: () -> Void
    
    var body: some View {
        // Verwende die neue Apple-Style Implementation
        AppleStyleZoomableImageViewMemories(image: image)
    }
}

// MARK: - Kompatibilitäts-Typalias / Placeholder

// Minimalversion von MediaThumbnailPreview (Thumbnail + Tap)
struct MediaThumbnailPreview: View {
    let mediaItem: MediaItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            if let thumb = mediaItem.thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 100)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 100)
                    .overlay(
                        Image(systemName: mediaItem.isVideo ? "video" : "photo")
                            .font(.title2)
                            .foregroundColor(.white)
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .cornerRadius(12)
        .clipped()
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Beispiel-Daten erstellen
    let memory = Memory(context: context)
    memory.title = "Schöner Sonnenuntergang"
    memory.text = "Ein wunderschöner Abend am Strand mit einem atemberaubenden Sonnenuntergang."
    memory.timestamp = Date()
    memory.locationName = "Berlin, Deutschland"
    memory.latitude = 52.5200
    memory.longitude = 13.4050
    
    // Beispiel-Fotos hinzufügen
    for i in 0..<3 {
        let photo = Photo(context: context)
        photo.imageData = Data() // Dummy-Daten
        photo.timestamp = Date()
        photo.order = Int16(i)
        photo.memory = memory
    }
    
    return MemoriesView()
        .environment(\.managedObjectContext, context)
}

// MARK: - Toolbar & Alerts

@ToolbarContentBuilder
private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .navigationBarLeading) {
        Menu {
            Button("Teilen", systemImage: "square.and.arrow.up") { shareCurrentPhoto() }
                .disabled(allPhotoData.isEmpty)
            Button("Bearbeiten", systemImage: "pencil") { showingEditView = true }
            Button("Löschen", systemImage: "trash", role: .destructive) { showingDeleteAlert = true }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
    ToolbarItem(placement: .navigationBarTrailing) {
        Button("Fertig") { dismiss() }
    }
}

private var deleteAlertButtons: some View {
    Group {
        Button("Löschen", role: .destructive) { deleteMemory() }
        Button("Abbrechen", role: .cancel) { }
    }
} 