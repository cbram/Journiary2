//
//  CreateTripView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import PhotosUI
import CoreData
import CoreLocation

struct CreateTripView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager
    
    // 🔄 SYNC-SERVICE für automatische Synchronisation
    @StateObject private var syncService: TripSyncService
    
    // Bestehende Reise zum Editieren (optional)
    let existingTrip: Trip?
    
    // Formular-Felder
    @State private var tripName = ""
    @State private var tripDescription = ""

    @State private var startDate = Date()
    @State private var endDate: Date?
    @State private var hasEndDate = false
    @State private var travelCompanions = ""
    @State private var gpsTrackingEnabled = true
    
    // Titelfoto
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var showingCoverImagePicker = false
    @State private var showingCamera = false
    
    // Besuchte Länder (werden automatisch aus GPS-Daten ermittelt)
    @State private var visitedCountries: Set<String> = []
    @State private var isLoadingCountries = false
    
    // Validierung
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var showingGPSWarning = false
    
    var isEditing: Bool {
        existingTrip != nil
    }
    
    init(existingTrip: Trip? = nil) {
        self.existingTrip = existingTrip
        
        // 🔄 SYNC-SERVICE initialisieren
        let context = PersistenceController.shared.container.viewContext
        self._syncService = StateObject(wrappedValue: TripSyncService(context: context))
        
        // Bei Bearbeitung die bestehenden Werte laden
        if let trip = existingTrip {
            _tripName = State(initialValue: trip.name ?? "")
            _tripDescription = State(initialValue: trip.tripDescription ?? "")

            _startDate = State(initialValue: trip.startDate ?? Date())
            _endDate = State(initialValue: trip.endDate)
            _hasEndDate = State(initialValue: trip.endDate != nil)
            _travelCompanions = State(initialValue: trip.travelCompanions ?? "")
            _coverImageData = State(initialValue: trip.coverImageData)
            _gpsTrackingEnabled = State(initialValue: trip.gpsTrackingEnabled)
            
            if let countries = trip.visitedCountries, !countries.isEmpty {
                _visitedCountries = State(initialValue: Set(countries.components(separatedBy: ", ")))
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Grundinformationen
                Section("Reiseinformationen") {
                    TextField("Reisename", text: $tripName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Beschreibung (optional)", text: $tripDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                    

                }
                
                // Reisedaten
                Section("Reisedaten") {
                    DatePicker("Startdatum", selection: $startDate, displayedComponents: [.date])
                    
                    Toggle("Enddatum festlegen", isOn: $hasEndDate)
                    
                    if hasEndDate {
                        DatePicker("Enddatum", selection: Binding(
                            get: { endDate ?? startDate.addingTimeInterval(86400) },
                            set: { endDate = $0 }
                        ), displayedComponents: [.date])
                        .disabled(!hasEndDate)
                    }
                }
                
                // Titelfoto
                Section("Titelfoto") {
                    coverPhotoSection
                }
                
                // Reisebegleiter
                Section("Reisebegleiter") {
                    TextField("Namen der Reisebegleiter (optional)", text: $travelCompanions)
                        .textInputAutocapitalization(.words)
                    
                    if !travelCompanions.isEmpty {
                        Text("Tipp: Mehrere Namen durch Komma trennen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // GPS-Tracking
                Section("GPS-Tracking") {
                    gpsTrackingSection
                }
                
                // Besuchte Länder
                Section("Besuchte Länder") {
                    visitedCountriesSection
                }
            }
            .navigationTitle(isEditing ? "Reise bearbeiten" : "Neue Reise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Speichern" : "Erstellen") {
                        saveTrip()
                    }
                    .fontWeight(.semibold)
                    .disabled(tripName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Ungültige Eingabe", isPresented: $showingValidationAlert) {
                Button("OK") { }
            } message: {
                Text(validationMessage)
            }
            .alert("GPS-Tracking deaktiviert", isPresented: $showingGPSWarning) {
                Button("Trotzdem speichern") {
                    saveTripWithoutGPS()
                }
                Button("Abbrechen", role: .cancel) { }
                Button("GPS aktivieren") {
                    gpsTrackingEnabled = true
                    saveTripWithoutGPS()
                }
            } message: {
                Text("Diese Reise ist als aktiv markiert, aber GPS-Tracking ist deaktiviert. Ohne GPS-Tracking können keine Routenpunkte aufgezeichnet werden.")
            }
            .task {
                if isEditing {
                    await loadVisitedCountriesFromMemories()
                }
            }
        }
    }
    
    private var coverPhotoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageData = coverImageData,
               let uiImage = UIImage(data: imageData) {
                // Vorschau des ausgewählten Fotos
                HStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading) {
                        Text("Titelfoto ausgewählt")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Button("Ändern") {
                            showingCoverImagePicker = true
                        }
                        .font(.caption)
                    }
                    
                    Spacer()
                    
                    Button("Entfernen", systemImage: "trash") {
                        coverImageData = nil
                        selectedCoverPhoto = nil
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
            } else {
                // Foto auswählen
                VStack(spacing: 8) {
                    Button("Titelfoto auswählen") {
                        showingCoverImagePicker = true
                    }
                    .buttonStyle(.bordered)
                    
                    Text("Optional: Ein Foto, das Ihre Reise repräsentiert")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .photosPicker(isPresented: $showingCoverImagePicker, selection: $selectedCoverPhoto, matching: .images)
        .onChange(of: selectedCoverPhoto) { oldValue, newValue in
            loadCoverPhoto()
        }
    }
    
    private var gpsTrackingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("GPS-Tracking aktivieren", isOn: $gpsTrackingEnabled)
            
            VStack(alignment: .leading, spacing: 4) {
                if gpsTrackingEnabled {
                    Label("Route wird automatisch aufgezeichnet", systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("Ihre Position wird während der Reise verfolgt und als Route gespeichert.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Label("Keine Routenaufzeichnung", systemImage: "location.slash")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("Ohne GPS-Tracking können keine Routenpunkte aufgezeichnet werden.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Standortzugriff verweigert", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("Bitte aktivieren Sie den Standortzugriff in den Einstellungen, um GPS-Tracking zu verwenden.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
    
    private var visitedCountriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingCountries {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Länder werden aus GPS-Daten ermittelt...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if visitedCountries.isEmpty {
                if isEditing {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keine Länder gefunden")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Aus Erinnerungen laden") {
                            Task {
                                await loadVisitedCountriesFromMemories()
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                } else {
                    Text("Länder werden automatisch aus GPS-Daten der Erinnerungen ermittelt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(Array(visitedCountries.sorted()), id: \.self) { country in
                    Label(country, systemImage: "location.fill")
                        .font(.subheadline)
                }
            }
        }
    }
    
    // MARK: - Functions
    
    private func loadCoverPhoto() {
        guard let selectedCoverPhoto else { return }
        
        Task {
            do {
                if let data = try await selectedCoverPhoto.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        self.coverImageData = data
                    }
                }
            } catch {
                print("Fehler beim Laden des Titelfotos: \(error)")
            }
        }
    }
    
    private func loadVisitedCountriesFromMemories() async {
        guard let trip = existingTrip else { return }
        
        await MainActor.run {
            isLoadingCountries = true
        }
        
        let countries = await locationManager.getVisitedCountries(for: trip)
        
        await MainActor.run {
            self.visitedCountries = countries
            isLoadingCountries = false
        }
    }
    
    private func validateInput() -> Bool {
        let name = tripName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if name.isEmpty {
            validationMessage = "Bitte geben Sie einen Namen für die Reise ein."
            return false
        }
        
        if hasEndDate, let end = endDate, end < startDate {
            validationMessage = "Das Enddatum muss nach dem Startdatum liegen."
            return false
        }
        
        return true
    }
    
    private func saveTrip() {
        guard validateInput() else {
            showingValidationAlert = true
            return
        }
        
        // GPS-Tracking Warnung für aktive Reisen ohne GPS
        if !hasEndDate && !gpsTrackingEnabled {
            showingGPSWarning = true
            return
        }
        
        saveTripWithoutGPS()
    }
    
    private func saveTripWithoutGPS() {
        let trip: Trip
        
        if let existingTrip = existingTrip {
            // Bestehende Reise bearbeiten
            trip = existingTrip
        } else {
            // Neue Reise erstellen
            trip = Trip(context: viewContext)
        }
        
        // Werte setzen
        trip.name = tripName.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.tripDescription = tripDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : tripDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        trip.startDate = startDate
        trip.endDate = hasEndDate ? endDate : nil
        trip.travelCompanions = travelCompanions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : travelCompanions.trimmingCharacters(in: .whitespacesAndNewlines)
        trip.coverImageData = coverImageData
        trip.gpsTrackingEnabled = gpsTrackingEnabled
        
        // Besuchte Länder als kommagetrennte Liste speichern
        if !visitedCountries.isEmpty {
            trip.visitedCountries = visitedCountries.sorted().joined(separator: ", ")
        }
        
        // Neue Reise: zusätzliche Standardwerte
        if existingTrip == nil {
            // Eine neue Reise ist nur dann beendet (isActive = false), wenn ein Enddatum angegeben wurde
            trip.isActive = !hasEndDate
            trip.totalDistance = 0.0
            
            // 🔄 SYNC-ATTRIBUTE für neue Reisen setzen
            trip.needsSync = true
            trip.createdAt = Date()
            trip.updatedAt = Date()
            trip.syncVersion = 1
            trip.supabaseID = nil // Wird beim Upload gesetzt
        } else {
            // Bei bestehenden Reisen: isActive basierend auf Enddatum aktualisieren
            trip.isActive = !hasEndDate
            
            // 🔄 SYNC-ATTRIBUTE für bearbeitete Reisen aktualisieren
            trip.needsSync = true
            trip.updatedAt = Date()
            trip.syncVersion = (trip.syncVersion > 0) ? trip.syncVersion + 1 : 1
        }
        
        // Speichern
        do {
            try viewContext.save()
            print("Reise '\(trip.name ?? "")' erfolgreich \(isEditing ? "bearbeitet" : "erstellt")")
            
            // 🔄 AUTOMATISCHE SYNCHRONISATION nach dem Speichern
            Task {
                await syncService.performIncrementalSync()
            }
            
            dismiss()
        } catch {
            print("Fehler beim Speichern der Reise: \(error)")
            validationMessage = "Fehler beim Speichern der Reise. Bitte versuchen Sie es erneut."
            showingValidationAlert = true
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let locationManager = LocationManager(context: context)
    
    return CreateTripView()
        .environmentObject(locationManager)
        .environment(\.managedObjectContext, context)
}

// Preview für Bearbeitung
#Preview("Edit Trip") {
    let context = PersistenceController.preview.container.viewContext
    let locationManager = LocationManager(context: context)
    
    let trip = Trip(context: context)
    trip.name = "Beispielreise nach Paris"
    trip.tripDescription = "Eine wunderbare Reise in die Stadt der Liebe"
    trip.startDate = Date().addingTimeInterval(-86400 * 7)
    trip.endDate = Date().addingTimeInterval(-86400 * 3)

    trip.travelCompanions = "Max Mustermann, Anna Schmidt"
    trip.visitedCountries = "Deutschland, Frankreich"
    
    return CreateTripView(existingTrip: trip)
        .environmentObject(locationManager)
        .environment(\.managedObjectContext, context)
} 