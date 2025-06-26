//
//  SettingsView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var mapCache = MapCacheManager.shared
    
    @State private var showingDeleteAlert = false
    @State private var showingOfflineMapSettings = false
    @State private var showingGPXDebugTest = false
    @State private var showingTracesTrackSettings = false
    @State private var showingGPSDebugView = false
    @State private var selectedMapType: MapType = UserDefaults.standard.selectedMapType
    @State private var googlePlacesApiKey: String = UserDefaults.standard.string(forKey: "GooglePlacesAPIKey") ?? ""
    @State private var apiKeySavedMessage: String? = nil
    @State private var placeProvider: String = UserDefaults.standard.string(forKey: "PlaceProvider") ?? "Nominatim"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Ortssuche Einstellungen
                    placeSearchSection
                    
                    // GPS & Tracking Einstellungen
                    gpsTrackingSection
                    
                    // Karten & Offline Einstellungen
                    mapSettingsSection
                    
                    // Tags Verwaltung
                    tagManagementSection
                    
                    // CloudKit Sync
                    cloudKitSection
                    
                    // Debug-Sektion
                    debugSection
                    
                    // App-Info
                    appInfoSection
                    
                    // Danger Zone
                    dangerZoneSection
                }
                .padding()
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedMapType = UserDefaults.standard.selectedMapType
        }
        .sheet(isPresented: $showingOfflineMapSettings) {
            OfflineMapCacheView()
        }
        .sheet(isPresented: $showingGPXDebugTest) {
            GPXDebugTestView()
        }
        .sheet(isPresented: $showingTracesTrackSettings) {
            TracesTrackSettingsView()
        }
        .sheet(isPresented: $showingGPSDebugView) {
            GPSDebugView()
                .environmentObject(locationManager)
        }
        .alert("Alle Daten löschen?", isPresented: $showingDeleteAlert) {
            Button("Löschen", role: .destructive) {
                deleteAllData()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle deine Reisen und Erinnerungen werden permanent gelöscht.")
        }
    }
    
    // MARK: - Settings Sections
    
    private var placeSearchSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ortssuche")
                .font(.headline)
            
            VStack(spacing: 16) {
                // Ortssuche-Anbieter Auswahl
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ortssuche-Anbieter")
                        .font(.subheadline)
                    Picker("Ortssuche-Anbieter", selection: $placeProvider) {
                        Text("Nominatim (OSM)").tag("Nominatim")
                        Text("Google Places").tag("Google")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: placeProvider) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "PlaceProvider")
                    }
                }
                
                // Google Places API-Key (nur wenn Google gewählt)
                if placeProvider == "Google" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Google Places API-Key")
                            .font(.subheadline)
                        SecureField("API-Key eingeben", text: $googlePlacesApiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("API-Key speichern") {
                            UserDefaults.standard.set(googlePlacesApiKey, forKey: "GooglePlacesAPIKey")
                            apiKeySavedMessage = "API-Key gespeichert!"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                apiKeySavedMessage = nil
                            }
                        }
                        .disabled(googlePlacesApiKey.isEmpty)
                        if let msg = apiKeySavedMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var gpsTrackingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GPS & Tracking")
                .font(.headline)
            
            VStack(spacing: 8) {
                NavigationLink {
                    GPSSettingsSubmenuView(locationManager: locationManager, viewContext: viewContext)
                } label: {
                    SettingsRowNavigable(
                        title: "GPS & Tracking",
                        icon: "location.circle.fill",
                        status: "Details"
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var mapSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Karten & Offlinekarten")
                .font(.headline)
            
            VStack(spacing: 8) {
                NavigationLink {
                    MapSettingsSubmenuView(
                        selectedMapType: $selectedMapType,
                        mapCache: mapCache,
                        showingOfflineMapSettings: $showingOfflineMapSettings,
                        showingTracesTrackSettings: $showingTracesTrackSettings
                    )
                } label: {
                    SettingsRowNavigable(
                        title: "Karten & Offlinekarten",
                        icon: "map.circle.fill",
                        status: "Details"
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var tagManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tags")
                .font(.headline)
            
            VStack(spacing: 8) {
                NavigationLink {
                    TagManagementView(viewContext: viewContext)
                } label: {
                    SettingsRowNavigable(
                        title: "Tags verwalten",
                        icon: "tag.fill",
                        status: "Alle Tags & Kategorien"
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var cloudKitSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cloud Sync")
                .font(.headline)
            
            VStack(spacing: 8) {
                SettingsRow(
                    title: "CloudKit Sync",
                    icon: "icloud.fill",
                    status: "Aktiv"
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Debug & Entwicklung")
                .font(.headline)
            
            VStack(spacing: 8) {
                NavigationLink {
                    DebugSettingsSubmenuView(locationManager: locationManager, showingGPSDebugView: $showingGPSDebugView)
                } label: {
                    SettingsRowNavigable(
                        title: "Debug & Entwicklung",
                        icon: "ladybug.fill",
                        status: "Details"
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App-Information")
                .font(.headline)
            
            VStack(spacing: 8) {
                SettingsRow(
                    title: "App-Version",
                    icon: "info.circle.fill",
                    status: "1.0.0"
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Datenverwaltung")
                .font(.headline)
            
            Button("Alle Daten löschen") {
                showingDeleteAlert = true
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func deleteAllData() {
        let context = viewContext
        
        // Alle Entities löschen
        let entityNames = ["Memory", "Trip", "Photo", "BucketListItem", "MediaItem"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("Fehler beim Löschen der Entity \(entityName): \(error)")
            }
        }
        
        // Änderungen speichern
        do {
            try context.save()
        } catch {
            print("Fehler beim Speichern: \(error)")
        }
    }
}

// MARK: - Settings Components (moved from ProfileView)

struct SettingsRow: View {
    let title: String
    let icon: String
    let status: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

struct SettingsRowNavigable: View {
    let title: String
    let icon: String
    let status: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let locationManager = LocationManager(context: context)
    
    SettingsView()
        .environmentObject(locationManager)
        .environment(\.managedObjectContext, context)
} 