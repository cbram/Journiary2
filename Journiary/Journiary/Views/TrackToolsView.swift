//
//  TrackToolsView.swift
//  Journiary
//
//  Created by AI Assistant on 09.06.25.
//

import SwiftUI
import CoreLocation

struct TrackToolsView: View {
    let routePoints: [RoutePoint]
    let onAddPoint: (CLLocationCoordinate2D, Int?) -> Void
    let onDeletePoints: ([Int]) -> Void
    let onOptimizeTrack: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndices: Set<Int> = []
    @State private var isSelectionMode = false
    @State private var showingAddPointView = false
    @State private var newPointLatitude = ""
    @State private var newPointLongitude = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if routePoints.isEmpty {
                    emptyStateView
                } else {
                    trackPointsList
                }
            }
            .navigationTitle("Track-Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !routePoints.isEmpty {
                        Button(isSelectionMode ? "Fertig" : "Auswählen") {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedIndices.removeAll()
                            }
                        }
                        
                        Menu {
                            Button("Punkt hinzufügen", systemImage: "plus") {
                                showingAddPointView = true
                            }
                            
                            Button("Track optimieren", systemImage: "wand.and.stars") {
                                onOptimizeTrack()
                                dismiss()
                            }
                            .disabled(routePoints.count < 3)
                            
                            if !selectedIndices.isEmpty {
                                Button("Ausgewählte löschen (\(selectedIndices.count))", systemImage: "trash", role: .destructive) {
                                    onDeletePoints(Array(selectedIndices))
                                    selectedIndices.removeAll()
                                    isSelectionMode = false
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddPointView) {
                addPointSheet
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Keine Routenpunkte")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Starte das GPS-Tracking, um Routenpunkte zu sammeln.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var trackPointsList: some View {
        List {
            Section {
                ForEach(Array(routePoints.enumerated()), id: \.offset) { index, point in
                    HStack {
                        if isSelectionMode {
                            Button(action: {
                                if selectedIndices.contains(index) {
                                    selectedIndices.remove(index)
                                } else {
                                    selectedIndices.insert(index)
                                }
                            }) {
                                Image(systemName: selectedIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedIndices.contains(index) ? .blue : .gray)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Punkt \(index + 1)")
                                .font(.headline)
                            
                            Text("Lat: " + String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), point.latitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Lng: " + String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), point.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let timestamp = point.timestamp {
                                Text(timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if point.speed > 0 {
                            VStack(alignment: .trailing) {
                                Text("\(point.speed * 3.6, specifier: "%.1f") km/h")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Text("\(point.altitude, specifier: "%.0f") m")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                HStack {
                    Text("Routenpunkte (\(routePoints.count))")
                    Spacer()
                    if isSelectionMode && !selectedIndices.isEmpty {
                        Text("\(selectedIndices.count) ausgewählt")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    private var addPointSheet: some View {
        NavigationView {
            Form {
                Section("Neue Koordinaten") {
                    HStack {
                        Text("Breitengrad:")
                        TextField("z.B. 52.520008", text: $newPointLatitude)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Längengrad:")
                        TextField("z.B. 13.404954", text: $newPointLongitude)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section {
                    Button("Punkt hinzufügen") {
                        if let lat = Double(newPointLatitude), 
                           let lng = Double(newPointLongitude) {
                            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                            onAddPoint(coordinate, nil)
                            showingAddPointView = false
                            newPointLatitude = ""
                            newPointLongitude = ""
                        }
                    }
                    .disabled(!isValidNewPointCoordinates)
                }
            }
            .navigationTitle("Punkt hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        showingAddPointView = false
                        newPointLatitude = ""
                        newPointLongitude = ""
                    }
                }
            }
        }
    }
    
    private var isValidNewPointCoordinates: Bool {
        guard let lat = Double(newPointLatitude), 
              let lng = Double(newPointLongitude) else { return false }
        return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
    }
} 