//
//  MemoryDetailView.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import SwiftUI
import CoreData
import MapKit

struct MemoryDetailView: View {
    @ObservedObject var memory: Memory
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var syncManager = SyncManager.shared
    @ObservedObject private var mediaSyncCoordinator = MediaSyncCoordinator.shared
    
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var showingMediaPicker = false
    @State private var showingMediaSyncOptions = false
    @State private var showingShareSheet = false
    
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private var mediaItems: [MediaItem] {
        memory.mediaItems?.allObjects as? [MediaItem] ?? []
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Mediengalerie
                if !mediaItems.isEmpty {
                    mediaGallery
                }
                
                // Inhalt
                contentSection
                
                // Standort
                if memory.latitude != 0 && memory.longitude != 0 {
                    locationSection
                }
                
                // Tags
                if let tags = memory.tags, tags.count > 0 {
                    tagSection
                }
            }
            .padding()
        }
        .navigationTitle(memory.title ?? "Erinnerung")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            toolbarItems
        }
        .onAppear {
            setupMapRegion()
        }
        .sheet(isPresented: $showingEditView) {
            NavigationView {
                EditMemoryView(memory: memory)
            }
        }
        .sheet(isPresented: $showingMediaPicker) {
            NativeMediaPickerView(memory: memory)
        }
        .alert("Erinnerung löschen", isPresented: $showingDeleteAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                deleteMemory()
            }
        } message: {
            Text("Möchtest du diese Erinnerung wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.")
        }
        .actionSheet(isPresented: $showingMediaSyncOptions) {
            ActionSheet(
                title: Text("Mediensynchronisierung"),
                message: Text("Wähle eine Option für die Synchronisierung der Mediendateien dieser Erinnerung."),
                buttons: [
                    .default(Text("Alle Medien herunterladen")) {
                        downloadMedia()
                    },
                    .default(Text("Alle Medien hochladen")) {
                        uploadMedia()
                    },
                    .destructive(Text("Lokale Mediendaten löschen")) {
                        clearLocalMediaData()
                    },
                    .cancel()
                ]
            )
        }
    }
    
    // MARK: - View Components
    
    private var mediaGallery: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(mediaItems.sorted(by: { $0.order < $1.order })) { mediaItem in
                    mediaItemView(for: mediaItem)
                        .frame(width: 200, height: 200)
                        .cornerRadius(10)
                }
                
                // Hinzufügen-Button
                Button(action: {
                    showingMediaPicker = true
                }) {
                    VStack {
                        Image(systemName: "plus.circle")
                            .font(.largeTitle)
                        Text("Hinzufügen")
                            .font(.caption)
                    }
                    .frame(width: 100, height: 200)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                }
            }
        }
        .frame(height: 200)
    }
    
    private func mediaItemView(for mediaItem: MediaItem) -> some View {
        Group {
            if mediaItem.mediaData != nil {
                // Lokale Daten vorhanden
                if mediaItem.mediaType == "photo", let imageData = mediaItem.mediaData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Video oder anderer Medientyp
                    ZStack {
                        Color.gray.opacity(0.5)
                        VStack {
                            Image(systemName: mediaItem.mediaType == "video" ? "film" : "doc")
                                .font(.largeTitle)
                            Text(mediaItem.filename ?? "Unbekannt")
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            } else if mediaItem.objectName != nil {
                // Nur im Backend vorhanden
                ZStack {
                    Color.gray.opacity(0.3)
                    VStack {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.largeTitle)
                        Text("Tippen zum Herunterladen")
                            .font(.caption)
                    }
                }
                .onTapGesture {
                    downloadMediaItem(mediaItem)
                }
            } else {
                // Weder lokal noch im Backend vorhanden
                ZStack {
                    Color.red.opacity(0.3)
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                        Text("Nicht verfügbar")
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(memory.title ?? "Unbenannte Erinnerung")
                .font(.title)
                .fontWeight(.bold)
            
            if let timestamp = memory.timestamp {
                Text(dateFormatter.string(from: timestamp))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let text = memory.text, !text.isEmpty {
                Text(text)
                    .padding(.top, 4)
            }
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Standort")
                .font(.headline)
            
            if let locationName = memory.locationName, !locationName.isEmpty {
                Text(locationName)
                    .font(.subheadline)
            }
            
            Map(coordinateRegion: $mapRegion, annotationItems: [MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: memory.latitude, longitude: memory.longitude))]) { annotation in
                MapMarker(coordinate: annotation.coordinate, tint: .red)
            }
            .frame(height: 200)
            .cornerRadius(10)
        }
    }
    
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(memory.tagArray) { tag in
                    TagChip(tag: tag)
                }
            }
        }
    }
    
    // MARK: - Toolbar Items
    
    private var toolbarItems: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingEditView = true
                    }) {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        showingMediaPicker = true
                    }) {
                        Label("Medien hinzufügen", systemImage: "photo.on.rectangle")
                    }
                    
                    Button(action: {
                        showingShareSheet = true
                    }) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                    
                    if settings.storageMode != .cloudKit && settings.syncEnabled {
                        Button(action: {
                            showingMediaSyncOptions = true
                        }) {
                            Label("Medien synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        Label("Löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            
            // Sync Status Toolbar Item
            if settings.storageMode != .cloudKit && settings.syncEnabled && mediaSyncCoordinator.isSyncing {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func setupMapRegion() {
        if memory.latitude != 0 && memory.longitude != 0 {
            let coordinate = CLLocationCoordinate2D(latitude: memory.latitude, longitude: memory.longitude)
            mapRegion = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        }
    }
    
    private func deleteMemory() {
        viewContext.delete(memory)
        try? viewContext.save()
        dismiss()
    }
    
    private func downloadMedia() {
        Task {
            do {
                try await mediaSyncCoordinator.syncMediaForMemory(memory)
            } catch {
                print("❌ Fehler beim Herunterladen der Mediendateien: \(error)")
            }
        }
    }
    
    private func uploadMedia() {
        Task {
            do {
                try await mediaSyncCoordinator.syncMediaForMemory(memory)
            } catch {
                print("❌ Fehler beim Hochladen der Mediendateien: \(error)")
            }
        }
    }
    
    private func clearLocalMediaData() {
        // Persistenz-Controller abrufen
        let persistenceController = PersistenceController.shared
        
        // MediaItems abrufen und lokale Daten löschen
        persistenceController.performBackgroundTask { context in
            let memoryInContext = try? context.existingObject(with: memory.objectID) as? Memory
            guard let memory = memoryInContext else { return }
            
            guard let mediaItems = memory.mediaItems?.allObjects as? [MediaItem], !mediaItems.isEmpty else {
                return
            }
            
            for mediaItem in mediaItems {
                // Prüfe, ob das MediaItem einen objectName hat (also im Backend gespeichert ist)
                if let objectName = mediaItem.objectName, !objectName.isEmpty {
                    // Lokale Daten löschen
                    mediaItem.mediaData = nil
                }
            }
            
            // Änderungen speichern
            if context.hasChanges {
                try? context.save()
            }
        }
    }
    
    private func downloadMediaItem(_ mediaItem: MediaItem) {
        Task {
            do {
                // Persistenz-Controller abrufen
                let persistenceController = PersistenceController.shared
                
                // MediaItem herunterladen
                try await persistenceController.performBackgroundTask { context in
                    let mediaItemInContext = try context.existingObject(with: mediaItem.objectID) as! MediaItem
                    
                    guard let objectName = mediaItemInContext.objectName, !objectName.isEmpty else {
                        return
                    }
                    
                    // Daten herunterladen
                    let data = try await MediaSyncManager.shared.downloadMedia(objectName: objectName)
                    
                    // Daten im MediaItem speichern
                    mediaItemInContext.mediaData = data
                    
                    // Änderungen speichern
                    if context.hasChanges {
                        try context.save()
                    }
                }
            } catch {
                print("❌ Fehler beim Herunterladen des MediaItems: \(error)")
            }
        }
    }
}

// MARK: - Helper Structs

struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct MemoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let fetchRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
        let memories = try? context.fetch(fetchRequest)
        
        return Group {
            if let memory = memories?.first {
                NavigationView {
                    MemoryDetailView(memory: memory)
                }
            } else {
                Text("Keine Erinnerungen gefunden")
            }
        }
    }
} 