//
//  TripView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import CoreData
import CoreLocation

struct TripView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var showingCreateTripSheet = false
    @State private var tripToEdit: Trip?
    @State private var currentLocationName = "Standort wird ermittelt..."
    @State private var tripForGPXExport: Trip?
    @State private var showingTrackExportManager = false
    @State private var showMergeSheet = false
    @State private var tripToMerge: Trip?
    @State private var mergeError: String?
    @State private var refreshID = UUID()
    @State private var showingStatisticsSheet = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)],
        animation: .default
    )
    private var allTrips: FetchedResults<Trip>
    
    var activeTrip: Trip? {
        allTrips.first { $0.isActive }
    }
    
    var recentTrips: [Trip] {
        Array(allTrips.filter { !$0.isActive }.prefix(5))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Aktuelle Reise oder Start Button
                    if allTrips.isEmpty {
                        startTripCard
                    }
                    // NEU: Alle Reisen anzeigen
                    if !allTrips.isEmpty {
                        VStack(alignment: .center, spacing: 0) {
                            ForEach(allTrips, id: \.objectID) { trip in
                                NavigationLink {
                                    TripDetailView(trip: trip)
                                        .environmentObject(locationManager)
                                } label: {
                                    TripCardView(trip: trip)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle("Reisen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Neue Reise erstellen", systemImage: "plus.circle") {
                            showingCreateTripSheet = true
                        }
                        Divider()
                        Button("Track Export Manager", systemImage: "square.and.arrow.up") {
                            showingTrackExportManager = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await syncAndUpdateLocation()
            }
        }
        .id(refreshID)
        .sheet(isPresented: $showingCreateTripSheet) {
            CreateTripView()
                .environmentObject(locationManager)
        }
        .sheet(item: $tripToEdit) { trip in
            CreateTripView(existingTrip: trip)
                .environmentObject(locationManager)
        }
        .sheet(item: $tripForGPXExport) { trip in
            GPXExportView(trip: trip)
        }
        .sheet(isPresented: $showingTrackExportManager) {
            TrackExportManagerView()
        }
        .sheet(isPresented: $showingStatisticsSheet) {
            StatisticsSheetView(
                allTrips: Array(allTrips),
                totalDistance: totalDistance,
                uniqueLocationsCount: uniqueLocationsCount,
                totalTravelDays: totalTravelDays
            )
        }
        .task {
            await updateCurrentLocation()
            
            // Automatisches Starten des GPS-Trackings für aktive Reisen
            if let activeTrip = activeTrip, 
               activeTrip.gpsTrackingEnabled && 
               !locationManager.isTracking {
                locationManager.startTracking(for: activeTrip)
            }
        }
    }
    
    private var startTripCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Neue Reise starten")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(currentLocationName)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Reise beginnen") {
                showingCreateTripSheet = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var totalDistance: Double {
        allTrips.reduce(0) { $0 + $1.totalDistance }
    }
    
    private var uniqueLocationsCount: Int {
        let memories = allTrips.flatMap { trip in
            (trip.memories?.allObjects as? [Memory]) ?? []
        }
        let uniqueLocations = Set(memories.compactMap { $0.locationName })
        return uniqueLocations.count
    }
    
    private var totalTravelDays: Int {
        let dates = allTrips.compactMap { trip -> Set<String>? in
            guard let start = trip.startDate,
                  let end = trip.endDate else { return nil }
            
            let calendar = Calendar.current
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            var dates = Set<String>()
            var currentDate = start
            
            while currentDate <= end {
                dates.insert(dateFormatter.string(from: currentDate))
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? end
            }
            
            return dates
        }
        
        let allDates = dates.reduce(Set<String>()) { $0.union($1) }
        return allDates.count
    }
    
    private func formatDuration(from startDate: Date) -> String {
        let duration = Date().timeIntervalSince(startDate)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
    
    @MainActor
    private func syncAndUpdateLocation() async {
        print("TripView: Initiating sync and location update...")
        // Sync zuerst ausführen
        await SyncManager.shared.sync()
        // Dann Location aktualisieren
        await updateCurrentLocation()
        print("TripView: Sync and location update completed.")
    }
    
    @MainActor
    private func updateCurrentLocation() async {
        currentLocationName = await locationManager.getCurrentLocationName()
    }
}

struct TripStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

struct TripCardView: View {
    let trip: Trip
    
    // Berechnet die Länder in der Reihenfolge des ersten Besuchs
    private var orderedCountryFlags: [String] {
        guard let countries = trip.visitedCountries, !countries.isEmpty else { return [] }
        
        let countryList = countries.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        // Da RoutePoint und Memory keine country Property haben, verwenden wir die Reihenfolge aus visitedCountries
        // und sortieren alphabetisch als Fallback
        let sortedCountries = countryList.sorted()
        
        return sortedCountries.map { CountryHelper.flag(for: $0) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                if let coverImageData = trip.coverImageData, let uiImage = UIImage(data: coverImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 180)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 180)
                        .overlay(
                            Image(systemName: "figure.walk")
                                .font(.system(size: 48))
                                .foregroundColor(.blue)
                        )
                }
                if trip.isActive {
                    Text("Aktiv")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(8)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name ?? "Unbenannte Reise")
                    .font(.headline)
                    .lineLimit(2)
                if let description = trip.tripDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                if !trip.isActive, !orderedCountryFlags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(orderedCountryFlags.prefix(6), id: \.self) { flag in
                            Text(flag)
                                .font(.subheadline)
                        }
                        if orderedCountryFlags.count > 6 {
                            Text("+\(orderedCountryFlags.count - 6)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                if !trip.isActive, let startDate = trip.startDate, let endDate = trip.endDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(formatGermanDate(startDate)) - \(formatGermanDate(endDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 12) {
                        if let startDate = trip.startDate {
                            Label(formatGermanDate(startDate), systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if !orderedCountryFlags.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(orderedCountryFlags.prefix(3), id: \.self) { flag in
                                    Text(flag)
                                        .font(.caption)
                                }
                                if orderedCountryFlags.count > 3 {
                                    Text("+\(orderedCountryFlags.count - 3)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                HStack(spacing: 16) {
                    Label("\(Int(trip.totalDistance / 1000)) km", systemImage: "ruler")
                        .font(.caption2)
                        .foregroundColor(.primary)
                    if let duration = tripDuration {
                        Label(duration, systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                    if trip.gpsTrackingEnabled {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding([.horizontal, .bottom], 12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
    }
    
    private var tripDuration: String? {
        guard let start = trip.startDate, let end = trip.endDate else { return nil }
        let duration = end.timeIntervalSince(start)
        let days = Int(duration / 86400)
        let hours = Int(duration.truncatingRemainder(dividingBy: 86400)) / 3600
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            let minutes = Int(duration / 60)
            return "\(minutes)m"
        }
    }
    
    private func formatGermanDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct StatisticsSheetView: View {
    let allTrips: [Trip]
    let totalDistance: Double
    let uniqueLocationsCount: Int
    let totalTravelDays: Int
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Statistiken")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    TripStatCard(title: "Gesamtreisen", value: "\(allTrips.count)", icon: "location.fill")
                    TripStatCard(title: "Gesamtdistanz", value: String(format: "%.1f km", totalDistance / 1000), icon: "ruler.fill")
                    TripStatCard(title: "Besuchte Orte", value: "\(uniqueLocationsCount)", icon: "mappin.and.ellipse")
                    TripStatCard(title: "Reise-Tage", value: "\(totalTravelDays)", icon: "calendar.badge.clock")
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Statistiken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let locationManager = LocationManager(context: context)
    
    return TripView()
        .environmentObject(locationManager)
        .environment(\.managedObjectContext, context)
} 