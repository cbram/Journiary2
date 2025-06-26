//
//  RoutePointEditorView.swift
//  Journiary
//
//  Created by AI Assistant on 09.06.25.
//

import SwiftUI
import CoreLocation

enum RoutePointAction {
    case delete
    case moveToCurrentLocation
    case updateCoordinates(latitude: Double, longitude: Double)
}

struct RoutePointEditorView: View {
    let routePoint: RoutePoint
    let onAction: (RoutePointAction) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var latitude: String
    @State private var longitude: String
    @State private var showingDeleteAlert = false
    
    init(routePoint: RoutePoint, onAction: @escaping (RoutePointAction) -> Void) {
        self.routePoint = routePoint
        self.onAction = onAction
        _latitude = State(initialValue: String(format: "%.6f", routePoint.latitude))
        _longitude = State(initialValue: String(format: "%.6f", routePoint.longitude))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Koordinaten") {
                    HStack {
                        Text("Breitengrad:")
                        Spacer()
                        TextField("Breitengrad", text: $latitude)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Längengrad:")
                        Spacer()
                        TextField("Längengrad", text: $longitude)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Zusätzliche Informationen") {
                    HStack {
                        Text("Höhe:")
                        Spacer()
                        Text(String(format: "%.1f m", routePoint.altitude))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Geschwindigkeit:")
                        Spacer()
                        Text(String(format: "%.1f km/h", routePoint.speed * 3.6))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Zeitstempel:")
                        Spacer()
                        Text(routePoint.timestamp?.formatted(date: .abbreviated, time: .standard) ?? "Unbekannt")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Aktionen") {
                    Button("Zu aktueller Position verschieben", systemImage: "location.fill") {
                        onAction(.moveToCurrentLocation)
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    
                    Button("Koordinaten aktualisieren", systemImage: "checkmark.circle") {
                        if let lat = Double(latitude), let lng = Double(longitude) {
                            onAction(.updateCoordinates(latitude: lat, longitude: lng))
                            dismiss()
                        }
                    }
                    .foregroundColor(.green)
                    .disabled(!isValidCoordinates)
                    
                    Button("Punkt löschen", systemImage: "trash", role: .destructive) {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Routenpunkt bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .alert("Punkt löschen", isPresented: $showingDeleteAlert) {
                Button("Löschen", role: .destructive) {
                    onAction(.delete)
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Möchtest du diesen Routenpunkt wirklich löschen?")
            }
        }
    }
    
    private var isValidCoordinates: Bool {
        guard let lat = Double(latitude), let lng = Double(longitude) else { return false }
        return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
    }
} 