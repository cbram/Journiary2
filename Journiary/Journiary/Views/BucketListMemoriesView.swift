//
//  BucketListMemoriesView.swift
//  Journiary
//
//  Created by AI Assistant on [Current Date]
//

import SwiftUI
import CoreData

struct BucketListMemoriesView: View {
    let bucketListItem: BucketListItem
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncTriggerManager: SyncTriggerManager
    
    @State private var selectedMemoryID: NSManagedObjectID?
    @State private var showingMemoryDetail = false
    @State private var showingTripTimeline = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header mit POI Info
                    headerSection
                    
                    // Erinnerungen Liste
                    memoriesSection
                }
                .padding()
            }
            .refreshable {
                await syncData()
            }
            .navigationTitle("Erinnerungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Zurück") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMemoryDetail) {
                if let id = selectedMemoryID,
                   let memory = try? viewContext.existingObject(with: id) as? Memory,
                   !memory.isFault, memory.managedObjectContext != nil {
                    MemoryDetailView(memory: memory)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Erinnerung nicht verfügbar")
                            .font(.headline)
                        Text("Diese Erinnerung konnte nicht geladen werden. Möglicherweise wurde sie gelöscht oder geändert.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Schließen") {
                            showingMemoryDetail = false
                        }
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.primary)
                        .clipShape(Capsule())
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Moderner Mini-Pin für Header
            HStack(spacing: 12) {
                // Moderner Mini-Pin für Header
                ZStack {
                    // Pin-Form
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .frame(width: 32, height: 32)
                        
                        Triangle()
                            .frame(width: 8, height: 5)
                            .offset(y: 18.5)
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                colorForType(bucketListItem.type ?? "").opacity(0.9),
                                colorForType(bucketListItem.type ?? "").opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: colorForType(bucketListItem.type ?? "").opacity(0.3), radius: 4, x: 0, y: 2)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Glasmorphism-Overlay
                    RoundedRectangle(cornerRadius: 10)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.1),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Icon
                    Image(systemName: iconForType(bucketListItem.type ?? ""))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayNameForType(bucketListItem.type ?? ""))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(colorForType(bucketListItem.type ?? ""))
                    
                    Text("Bucket List Item")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            
            // POI Name und Location Info
            VStack(alignment: .leading, spacing: 8) {
                Text(bucketListItem.name ?? "Unbekannt")
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    if let country = bucketListItem.country, !country.isEmpty {
                        Text(CountryHelper.flag(for: country))
                            .font(.subheadline)
                        Text(country)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let region = bucketListItem.region, !region.isEmpty {
                            Text("- \(region)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else if let region = bucketListItem.region, !region.isEmpty {
                        Text(region)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Status Badge
            HStack {
                if bucketListItem.isDone {
                    Label("Bereist", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.1))
                        )
                } else {
                    Label("Geplant", systemImage: "clock.fill")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.1))
                        )
                }
                
                Spacer()
                
                Text("\(bucketListItem.memoryCount) Erinnerung\(bucketListItem.memoryCount == 1 ? "" : "en")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Memories Section
    
    private var memoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if bucketListItem.sortedMemories.isEmpty {
                // Empty State
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("Noch keine Erinnerungen")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Erstelle eine Erinnerung und verknüpfe sie mit diesem POI, um sie hier zu sehen.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if !bucketListItem.isDone && bucketListItem.sortedMemories.isEmpty {
                        Button("Als besucht markieren") {
                            markAsDone()
                        }
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                // Memories List
                LazyVStack(spacing: 12) {
                    ForEach(bucketListItem.sortedMemories, id: \.objectID) { memory in
                        MemoryCard(memory: memory) {
                            selectedMemoryID = memory.objectID
                            showingMemoryDetail = true
                        }
                    }
                }
                
                // Timeline-Button unterhalb der Erinnerungen
                timelineButton
            }
        }
        .sheet(isPresented: $showingTripTimeline) {
            if let firstMemory = bucketListItem.sortedMemories.first,
               let trip = firstMemory.trip {
                NavigationView {
                    MemoriesView(trip: trip, focusedMemory: firstMemory)
                        .navigationTitle("Timeline")
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Sync Functions
    
    private func syncData() async {
        print("BucketListMemoriesView: Initiating sync...")
        // Phase 5.3: Sync über SyncTriggerManager für besseres Feedback
        await syncTriggerManager.triggerManualSync()
        print("BucketListMemoriesView: Sync completed.")
    }
    
    // MARK: - Timeline Button
    
    private var timelineButton: some View {
        Button(action: {
            showingTripTimeline = true
        }) {
            HStack(spacing: 14) {
                // Timeline Icon
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    // Reise-Info (falls verfügbar)
                    if let firstMemory = bucketListItem.sortedMemories.first,
                       let trip = firstMemory.trip {
                        Text("zur Reise: \(trip.name ?? "Unbenannte Reise")")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    } else {
                        Text("Timeline anzeigen")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
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
        .padding(.bottom, 8)
    }
    
    // MARK: - Helper Methods
    
    private func iconForType(_ typeString: String) -> String {
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
    
    private func colorForType(_ typeString: String) -> Color {
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
    
    private func displayNameForType(_ typeString: String) -> String {
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
    
    private func markAsDone() {
        bucketListItem.isDone = true
        do {
            try viewContext.save()
        } catch {
            // Fehlerbehandlung, z.B. Alert anzeigen
            print("Fehler beim Speichern: \(error)")
        }
    }
}

// MARK: - Memory Row View

struct MemoryRowView: View {
    let memory: Memory
    let onTap: () -> Void
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingImage = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: nil) { _ in
                if let thumbnailImage = thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(8)
                } else if isLoadingImage {
                    ProgressView()
                        .frame(width: 60, height: 60)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(width: 60, height: 60)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
            }
            
            // Memory Info
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title ?? "Unbenannt")
                    .font(.headline)
                    .lineLimit(2)
                
                if let locationName = memory.locationName {
                    Label(locationName, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let timestamp = memory.timestamp {
                    Text(timestamp, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Tags (wenige anzeigen)
                if !memory.tagArray.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(memory.tagArray.prefix(3), id: \.objectID) { tag in
                            if let emoji = tag.emoji, !emoji.isEmpty {
                                Text(emoji)
                                    .font(.caption)
                            } else {
                                Circle()
                                    .fill(tag.colorValue)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        
                        if memory.tagArray.count > 3 {
                            Text("+\(memory.tagArray.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Media Count Badge
            if memory.hasMedia {
                VStack(spacing: 2) {
                    Image(systemName: "photo.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("\(memory.photoCount + memory.videoCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadThumbnailAsync()
        }
    }
    
    private func loadThumbnailAsync() {
        isLoadingImage = true
        
        Task {
            // Versuche zuerst MediaItems zu laden
            if let mediaItemSet = memory.mediaItems, 
               let mediaItems = mediaItemSet.allObjects as? [MediaItem],
               let firstPhotoItem = mediaItems.first(where: { $0.isPhoto }),
               let imageData = firstPhotoItem.mediaData {
                
                await MainActor.run {
                    thumbnailImage = UIImage(data: imageData)
                    isLoadingImage = false
                }
                return
            }
            
            // Fallback auf Legacy Photos
            if let photoSet = memory.photos,
               let photos = photoSet.allObjects as? [Photo],
               let firstPhoto = photos.sorted(by: { $0.order < $1.order }).first,
               let imageData = firstPhoto.imageData {
                
                await MainActor.run {
                    thumbnailImage = UIImage(data: imageData)
                    isLoadingImage = false
                }
                return
            }
            
            await MainActor.run {
                isLoadingImage = false
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let item = BucketListItem(context: context)
    item.name = "Neuschwanstein"
    item.country = "Deutschland"
    item.region = "Bayern"
    item.type = "bauwerk"
    item.isDone = false
    
    return BucketListMemoriesView(bucketListItem: item)
        .environment(\.managedObjectContext, context)
} 