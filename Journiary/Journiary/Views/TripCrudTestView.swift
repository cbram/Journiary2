//
//  TripCrudTestView.swift
//  Journiary
//
//  Created by AI Assistant on $(date).
//

import SwiftUI
import Combine

/// Test-View für Trip CRUD-Operationen
/// Ermöglicht das Testen aller Trip-Operationen ohne Demo-Mode Abhängigkeit
struct TripCrudTestView: View {
    
    // MARK: - State Properties
    
    @StateObject private var tripService = GraphQLTripService()
    
    @State private var trips: [TripDTO] = []
    @State private var selectedTrip: TripDTO?
    
    // Create Trip Form
    @State private var showCreateForm = false
    @State private var newTripName = ""
    @State private var newTripDescription = ""
    @State private var newTripStartDate = Date()
    @State private var newTripEndDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 Tage später
    
    // Update Trip Form
    @State private var showUpdateForm = false
    @State private var updateTripName = ""
    @State private var updateTripDescription = ""
    @State private var updateTripStartDate = Date()
    @State private var updateTripEndDate = Date()
    @State private var updateTripIsActive = true
    
    // UI State
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Header
                headerSection
                
                // Actions
                actionButtonsSection
                
                // Trip List
                tripListSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Trip CRUD Test")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadTrips()
            }
            .sheet(isPresented: $showCreateForm) {
                createTripFormSheet
            }
            .sheet(isPresented: $showUpdateForm) {
                updateTripFormSheet
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GraphQL Trip CRUD Operations")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Testen aller Trip-Operationen: Create, Read, Update, Delete")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let error = errorMessage {
                Text("❌ \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if let success = successMessage {
                Text("✅ \(success)")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // Reload Trips
            Button(action: loadTrips) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Trips laden")
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .disabled(isLoading)
            
            // Create Trip
            Button(action: { showCreateForm = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Trip erstellen")
                }
                .foregroundColor(.green)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            .disabled(isLoading)
            
            Spacer()
        }
    }
    
    private var tripListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trips (\(trips.count))")
                .font(.headline)
                .foregroundColor(.primary)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Lädt...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if trips.isEmpty {
                Text("Keine Trips vorhanden")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(trips) { trip in
                        tripRowView(trip: trip)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func tripRowView(trip: TripDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let description = trip.tripDescription {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Text(trip.dateRangeText)
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    HStack(spacing: 12) {
                        Label(trip.isActive ? "Aktiv" : "Inaktiv", 
                              systemImage: trip.isActive ? "checkmark.circle.fill" : "pause.circle.fill")
                            .font(.caption2)
                            .foregroundColor(trip.isActive ? .green : .orange)
                        
                        Label(trip.formattedDistance, systemImage: "location")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 8) {
                    Button(action: {
                        selectedTrip = trip
                        updateTripName = trip.name
                        updateTripDescription = trip.tripDescription ?? ""
                        updateTripStartDate = trip.startDate ?? Date()
                        updateTripEndDate = trip.endDate ?? Date()
                        updateTripIsActive = trip.isActive
                        showUpdateForm = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                    }
                    .disabled(isLoading)
                    
                    Button(action: {
                        deleteTrip(id: trip.id)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                    }
                    .disabled(isLoading)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Create Trip Form
    
    private var createTripFormSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Neuen Trip erstellen")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name*")
                            .font(.headline)
                        TextField("Trip-Name eingeben", text: $newTripName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Beschreibung")
                            .font(.headline)
                        TextField("Beschreibung (optional)", text: $newTripDescription)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Startdatum")
                            .font(.headline)
                        DatePicker("", selection: $newTripStartDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enddatum")
                            .font(.headline)
                        DatePicker("", selection: $newTripEndDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Abbrechen") {
                    showCreateForm = false
                    resetCreateForm()
                },
                trailing: Button("Erstellen") {
                    createTrip()
                }
                .disabled(newTripName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            )
        }
    }
    
    // MARK: - Update Trip Form
    
    private var updateTripFormSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Trip bearbeiten")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name*")
                            .font(.headline)
                        TextField("Trip-Name", text: $updateTripName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Beschreibung")
                            .font(.headline)
                        TextField("Beschreibung", text: $updateTripDescription)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Startdatum")
                            .font(.headline)
                        DatePicker("", selection: $updateTripStartDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enddatum")
                            .font(.headline)
                        DatePicker("", selection: $updateTripEndDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                    
                    Toggle("Aktiv", isOn: $updateTripIsActive)
                        .font(.headline)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Abbrechen") {
                    showUpdateForm = false
                },
                trailing: Button("Speichern") {
                    updateTrip()
                }
                .disabled(updateTripName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            )
        }
    }
    
    // MARK: - CRUD Operations
    
    private func loadTrips() {
        clearMessages()
        isLoading = true
        
        tripService.getTrips()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = "Fehler beim Laden: \(error.localizedDescription)"
                    }
                },
                receiveValue: { loadedTrips in
                    trips = loadedTrips
                    successMessage = "\(loadedTrips.count) Trips geladen"
                    clearMessageAfterDelay()
                }
            )
            .store(in: &cancellables)
    }
    
    private func createTrip() {
        print("🎯 CreateTrip Button gedrückt: \(newTripName)")
        clearMessages()
        isLoading = true
        
        tripService.createTrip(
            name: newTripName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: newTripDescription.isEmpty ? nil : newTripDescription,
            startDate: newTripStartDate,
            endDate: newTripEndDate
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = "Fehler beim Erstellen: \(error.localizedDescription)"
                }
            },
            receiveValue: { createdTrip in
                print("🎉 Trip erfolgreich über UI erstellt: \(createdTrip.name)")
                successMessage = "Trip '\(createdTrip.name)' erfolgreich erstellt"
                trips.insert(createdTrip, at: 0)
                showCreateForm = false
                resetCreateForm()
                clearMessageAfterDelay()
            }
        )
        .store(in: &cancellables)
    }
    
    private func updateTrip() {
        guard let trip = selectedTrip else { return }
        
        clearMessages()
        isLoading = true
        
        tripService.updateTrip(
            id: trip.id,
            name: updateTripName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: updateTripDescription.isEmpty ? nil : updateTripDescription,
            startDate: updateTripStartDate,
            endDate: updateTripEndDate,
            isActive: updateTripIsActive
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = "Fehler beim Aktualisieren: \(error.localizedDescription)"
                }
            },
            receiveValue: { updatedTrip in
                successMessage = "Trip '\(updatedTrip.name)' erfolgreich aktualisiert"
                
                // Update in list
                if let index = trips.firstIndex(where: { $0.id == updatedTrip.id }) {
                    trips[index] = updatedTrip
                }
                
                showUpdateForm = false
                selectedTrip = nil
                clearMessageAfterDelay()
            }
        )
        .store(in: &cancellables)
    }
    
    private func deleteTrip(id: String) {
        clearMessages()
        isLoading = true
        
        tripService.deleteTrip(id: id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = "Fehler beim Löschen: \(error.localizedDescription)"
                    }
                },
                receiveValue: { success in
                    if success {
                        trips.removeAll { $0.id == id }
                        successMessage = "Trip erfolgreich gelöscht"
                        clearMessageAfterDelay()
                    } else {
                        errorMessage = "Fehler beim Löschen des Trips"
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    
    private func resetCreateForm() {
        newTripName = ""
        newTripDescription = ""
        newTripStartDate = Date()
        newTripEndDate = Date().addingTimeInterval(7 * 24 * 60 * 60)
    }
    
    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    private func clearMessageAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            successMessage = nil
            errorMessage = nil
        }
    }
}

// MARK: - Preview

struct TripCrudTestView_Previews: PreviewProvider {
    static var previews: some View {
        TripCrudTestView()
    }
} 