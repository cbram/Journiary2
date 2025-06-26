//
//  BucketListFilterView.swift
//  Journiary
//
//  Created by AI Assistant on [Current Date]
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

struct BucketListFilterView: View {
    @ObservedObject var filterManager: BucketListFilterManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingDistanceInfo = false
    @State private var locationCancellable: Any?
    
    var body: some View {
        let locationAvailable = LocationManager.shared?.currentLocation != nil
        NavigationView {
            Form {
                // Land Filter
                Section("Land filtern") {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        
                        Picker("Land", selection: $filterManager.selectedCountry) {
                            Text("Alle Länder").tag(nil as String?)
                            
                            ForEach(filterManager.availableCountries, id: \.self) { country in
                                Text(country).tag(country as String?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    if filterManager.selectedCountry != nil {
                        HStack {
                            Text("Aktiv: \(filterManager.selectedCountry!)")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Reset") {
                                filterManager.selectedCountry = nil
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                
                // Art Filter
                Section("Art filtern") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 10) {
                        ForEach(BucketListType.allCases, id: \.self) { type in
                            FilterChip(
                                title: type.displayName,
                                icon: iconForType(type),
                                isSelected: filterManager.selectedTypes.contains(type),
                                action: {
                                    filterManager.toggleType(type)
                                }
                            )
                        }
                    }
                    
                    if !filterManager.selectedTypes.isEmpty {
                        HStack {
                            Text("Aktiv: \(filterManager.selectedTypes.count) Typ(en)")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Alle Reset") {
                                filterManager.selectedTypes.removeAll()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                
                // Entfernung Filter
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.circle")
                                .foregroundColor(.green)
                            Text("Entfernung zur aktuellen Position")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: { showingDistanceInfo = true }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Toggle("Entfernungsfilter aktivieren", isOn: $filterManager.useDistanceFilter)
                            .onChange(of: filterManager.useDistanceFilter) { oldValue, newValue in
                                print("[UI] useDistanceFilter wurde geändert: \(oldValue) → \(newValue)")
                                filterManager.applyFilters()
                            }
                        
                        if filterManager.useDistanceFilter {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Maximale Entfernung:")
                                    Spacer()
                                    Text("\(Int(filterManager.maxDistance)) km")
                                        .fontWeight(.medium)
                                }
                                
                                Slider(
                                    value: $filterManager.maxDistance,
                                    in: 1...500,
                                    step: 1
                                ) {
                                    Text("Entfernung")
                                } minimumValueLabel: {
                                    Text("1km")
                                        .font(.caption)
                                } maximumValueLabel: {
                                    Text("500km")
                                        .font(.caption)
                                }
                                .tint(.green)
                                
                                if !locationAvailable {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(.orange)
                                        Text("Standort nicht verfügbar")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Entfernungsfilter")
                } footer: {
                    if filterManager.useDistanceFilter && locationAvailable {
                        Text("Zeigt nur Orte innerhalb von \(Int(filterManager.maxDistance)) km von Ihrem aktuellen Standort an.")
                            .font(.caption)
                    }
                }
                
                // Status Filter
                Section("Status filtern") {
                    HStack {
                        FilterChip(
                            title: "Offen",
                            icon: "circle",
                            isSelected: filterManager.showOpenItems,
                            action: {
                                filterManager.showOpenItems.toggle()
                            }
                        )
                        
                        FilterChip(
                            title: "Erledigt",
                            icon: "checkmark.circle.fill",
                            isSelected: filterManager.showCompletedItems,
                            action: {
                                filterManager.showCompletedItems.toggle()
                            }
                        )
                    }
                }
                
                // Statistiken
                Section("Aktuelle Auswahl") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "list.number")
                                .foregroundColor(.blue)
                            Text("Gefilterte Ergebnisse:")
                            Spacer()
                            Text("\(filterManager.filteredCount)")
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundColor(.gray)
                            Text("Gesamt:")
                            Spacer()
                            Text("\(filterManager.totalCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        filterManager.resetAllFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Entfernungsfilter", isPresented: $showingDistanceInfo) {
                Button("OK") { }
            } message: {
                Text("Der Entfernungsfilter zeigt nur Bucket-List-Items an, die sich innerhalb der gewählten Entfernung zu Ihrem aktuellen Standort befinden. Für präzise Ergebnisse benötigt die App Zugriff auf Ihren Standort.")
            }
        }
        .onAppear {
            // Automatisches Reagieren auf Standortänderungen
            locationCancellable = LocationManager.shared?.$currentLocation.sink { _ in
                if filterManager.useDistanceFilter {
                    filterManager.applyFilters()
                }
            }
        }
        .onDisappear {
            // Clean up Combine Subscription
            if let cancellable = locationCancellable as? AnyCancellable {
                cancellable.cancel()
            }
        }
    }
    
    private func iconForType(_ type: BucketListType) -> String {
        switch type {
        case .nationalpark:
            return "tree.fill"
        case .stadt:
            return "building.2.fill"
        case .spot:
            return "camera.fill"
        case .bauwerk:
            return "building.columns.fill"
        case .wanderung:
            return "figure.walk"
        case .radtour:
            return "bicycle"
        case .traumstrasse:
            return "road.lanes"
        case .sonstiges:
            return "star.fill"
        }
    }
}

#Preview {
    BucketListFilterView(
        filterManager: BucketListFilterManager(
            context: PersistenceController.preview.container.viewContext
        )
    )
} 