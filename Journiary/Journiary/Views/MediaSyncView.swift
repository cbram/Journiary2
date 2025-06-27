//
//  MediaSyncView.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import SwiftUI
import CoreData

struct MediaSyncView: View {
    @ObservedObject private var mediaSyncCoordinator = MediaSyncCoordinator.shared
    @ObservedObject private var settings = AppSettings.shared
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedTrip: Trip?
    @State private var showingTripPicker = false
    @State private var showingMemoryPicker = false
    @State private var showingClearCacheAlert = false
    
    @State private var trips = [Trip]()
    @State private var memories = [Memory]()
    
    var body: some View {
        Form {
            // Status-Sektion
            Section(header: Text("Synchronisierungsstatus")) {
                if mediaSyncCoordinator.isSyncing {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text(mediaSyncCoordinator.currentOperation ?? "Synchronisiere...")
                            .padding(.leading, 8)
                    }
                    
                    ProgressView(value: mediaSyncCoordinator.syncProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                } else if let error = mediaSyncCoordinator.lastError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fehler bei der letzten Synchronisierung:")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                } else {
                    Text("Bereit zur Synchronisierung")
                        .foregroundColor(.secondary)
                }
            }
            
            // Aktionen-Sektion
            Section(header: Text("Aktionen")) {
                Button(action: {
                    showingTripPicker = true
                }) {
                    Label("Reise synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(mediaSyncCoordinator.isSyncing)
                
                Button(action: {
                    showingMemoryPicker = true
                }) {
                    Label("Erinnerung synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(mediaSyncCoordinator.isSyncing)
                
                Button(action: {
                    showingClearCacheAlert = true
                }) {
                    Label("Lokalen Medien-Cache leeren", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .disabled(mediaSyncCoordinator.isSyncing)
            }
            
            // Einstellungen-Sektion
            Section(header: Text("Einstellungen")) {
                Toggle("Medien automatisch herunterladen", isOn: $settings.autoDownloadMedia)
                
                if settings.autoDownloadMedia {
                    Toggle("Nur über WLAN Medien herunterladen", isOn: $settings.downloadMediaOnWifiOnly)
                }
                
                Toggle("Medien automatisch hochladen", isOn: $settings.autoUploadMedia)
                
                if settings.autoUploadMedia {
                    Toggle("Nur über WLAN Medien hochladen", isOn: $settings.uploadMediaOnWifiOnly)
                }
                
                Toggle("Lokale Medien nach Upload löschen", isOn: $settings.deleteLocalMediaAfterUpload)
                    .disabled(!settings.autoUploadMedia)
                
                Toggle("Medien bei Bedarf herunterladen", isOn: $settings.downloadMediaOnDemand)
            }
        }
        .navigationTitle("Mediensynchronisierung")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadTripsAndMemories()
        }
        .sheet(isPresented: $showingTripPicker) {
            NavigationView {
                List(trips) { trip in
                    Button(action: {
                        selectedTrip = trip
                        showingTripPicker = false
                        syncMediaForTrip(trip)
                    }) {
                        VStack(alignment: .leading) {
                            Text(trip.name ?? "Unbenannte Reise")
                                .font(.headline)
                            if let startDate = trip.startDate {
                                Text(startDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("Reise auswählen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Abbrechen") {
                            showingTripPicker = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingMemoryPicker) {
            NavigationView {
                List(memories) { memory in
                    Button(action: {
                        showingMemoryPicker = false
                        syncMediaForMemory(memory)
                    }) {
                        VStack(alignment: .leading) {
                            Text(memory.title ?? "Unbenannte Erinnerung")
                                .font(.headline)
                            if let timestamp = memory.timestamp {
                                Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("Erinnerung auswählen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Abbrechen") {
                            showingMemoryPicker = false
                        }
                    }
                }
            }
        }
        .alert("Medien-Cache leeren", isPresented: $showingClearCacheAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                clearMediaCache()
            }
        } message: {
            Text("Möchtest du wirklich alle lokal gespeicherten Mediendaten löschen? Die Medien bleiben im Backend gespeichert und können bei Bedarf wieder heruntergeladen werden.")
        }
    }
    
    // MARK: - Actions
    
    private func loadTripsAndMemories() {
        let tripFetchRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
        tripFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)]
        
        let memoryFetchRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
        memoryFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)]
        
        do {
            trips = try viewContext.fetch(tripFetchRequest)
            memories = try viewContext.fetch(memoryFetchRequest)
        } catch {
            print("❌ Fehler beim Laden der Reisen und Erinnerungen: \(error)")
        }
    }
    
    private func syncMediaForTrip(_ trip: Trip) {
        Task {
            do {
                try await mediaSyncCoordinator.syncMediaForTrip(trip)
            } catch {
                print("❌ Fehler beim Synchronisieren der Mediendateien für Reise: \(error)")
            }
        }
    }
    
    private func syncMediaForMemory(_ memory: Memory) {
        Task {
            do {
                try await mediaSyncCoordinator.syncMediaForMemory(memory)
            } catch {
                print("❌ Fehler beim Synchronisieren der Mediendateien für Erinnerung: \(error)")
            }
        }
    }
    
    private func clearMediaCache() {
        Task {
            do {
                try await mediaSyncCoordinator.clearAllLocalMediaData()
            } catch {
                print("❌ Fehler beim Löschen des Medien-Caches: \(error)")
            }
        }
    }
}

struct MediaSyncView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MediaSyncView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
} 