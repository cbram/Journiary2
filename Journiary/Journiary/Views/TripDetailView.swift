import SwiftUI
import CoreData
import MapKit
import Combine

struct ActivityStatistic {
    var activityType: String
    var count: Int
    var totalDistance: Double
    var totalElevationGain: Double
    var totalElevationLoss: Double
    var totalDuration: Double
}

struct TripDetailView: View {
    let trip: Trip
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingShareSheet = false
    @State private var showingDeleteAlert = false
    @State private var tripToEdit: Trip?
    @State private var showingEndTripAlert = false
    @State private var gpxFileURL: URL?
    @State private var showingExportAlert = false
    @State private var exportMessage = ""
    @State private var showingGPXExportView = false
    
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showingFullscreenMap = false
    @State private var showMapEditView = false
    @State private var showingMemoriesSheet = false
    @State private var randomMemories: [Memory] = []
    @State private var selectedMemoryForFocus: Memory?
    
    @State private var showingStopTrackingAlert = false
    @State private var pendingEndTrip = false
    
    // Combine
    @State private var cancellables = Set<AnyCancellable>()
    
    private var routePoints: [RoutePoint] {
        guard let points = trip.routePoints?.allObjects as? [RoutePoint] else { return [] }
        return points.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
    }
    
    private var memories: [Memory] {
        guard let memories = trip.memories?.allObjects as? [Memory] else { return [] }
        return memories.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
    }
    
    private var hasGPXActivities: Bool {
        return memoriesWithGPXTracks.count > 0
    }
    
    private var memoriesWithGPXTracks: [Memory] {
        return memories.filter { $0.gpxTrack != nil }
    }
    
    private var activityStatistics: [ActivityStatistic] {
        var stats: [String: ActivityStatistic] = [:]
        for memory in memoriesWithGPXTracks {
            guard let gpxTrack = memory.gpxTrack else { continue }
            let activityType = gpxTrack.trackType ?? "sonstiges"
            if var existingStat = stats[activityType] {
                existingStat.count += 1
                existingStat.totalDistance += gpxTrack.totalDistance
                existingStat.totalElevationGain += gpxTrack.elevationGain
                existingStat.totalElevationLoss += gpxTrack.elevationLoss
                existingStat.totalDuration += gpxTrack.totalDuration
                stats[activityType] = existingStat
            } else {
                stats[activityType] = ActivityStatistic(activityType: activityType, count: 1, totalDistance: gpxTrack.totalDistance, totalElevationGain: gpxTrack.elevationGain, totalElevationLoss: gpxTrack.elevationLoss, totalDuration: gpxTrack.totalDuration)
            }
        }
        return Array(stats.values).sorted { $0.totalDistance > $1.totalDistance }
    }
    
    var body: some View {
        if trip.isFault || trip.managedObjectContext == nil {
            unavailableTripView
        } else {
            tripContentView
        }
    }

    private var tripContentView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                tripHeader
                if !routePoints.isEmpty { mapSection }
                if !memories.isEmpty { memoriesSection }
                if hasGPXActivities { activityStatisticsSection }
                
                InviteUserView(tripId: trip.id?.uuidString ?? "")
                    .padding(.horizontal)

                Spacer()
            }
        }
        .navigationTitle(trip.name ?? "Reisedetails")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .onAppear(perform: onAppearAction)
        .sheet(item: $tripToEdit) { trip in
            CreateTripView(existingTrip: trip)
                .environmentObject(locationManager)
        }
        .sheet(isPresented: $showingGPXExportView) { GPXExportView(trip: trip) }
        .alert("Reise beenden", isPresented: $showingEndTripAlert, actions: {
            Button("Beenden", role: .destructive) {
                pendingEndTrip = true
                endTrip()
            }
            Button("Abbrechen", role: .cancel) { }
        }, message: { Text("Möchtest du diese Reise wirklich beenden? Das GPS-Tracking wird gestoppt.") })
        .alert("GPS-Tracking beenden?", isPresented: $showingStopTrackingAlert, actions: {
            Button("Ja", role: .destructive) { stopTrackingForTrip() }
            Button("Nein", role: .cancel) { pendingEndTrip = false }
        }, message: { Text("Möchtest du das GPS-Tracking für diese Reise jetzt stoppen? (Empfohlen)") })
        .alert("Reise löschen", isPresented: $showingDeleteAlert, actions: {
            Button("Löschen", role: .destructive) { deleteTrip() }
            Button("Abbrechen", role: .cancel) { }
        }, message: { Text("Möchtest du diese Reise wirklich löschen? Alle zugehörigen Routenpunkte und Erinnerungen werden ebenfalls gelöscht.") })
        .alert(isPresented: $showingExportAlert) {
            Alert(title: Text("Export Status"), message: Text(exportMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showingShareSheet) { ShareSheetWrapper(fileURL: $gpxFileURL, onDismiss: cleanupTemporaryShareFile) }
        .sheet(isPresented: $showingFullscreenMap) { TripTrackMapView(trip: trip) }
        .sheet(item: $selectedMemoryForFocus) { memory in NavigationView { MemoriesView(trip: trip, focusedMemory: memory) } }
        .sheet(isPresented: $showMapEditView) { MapView(tripToEdit: trip) }
        .sheet(isPresented: $showingMemoriesSheet) { NavigationView { MemoriesView(trip: trip, oldestFirst: true) } }
    }
    
    // HIER BEGINNEN DIE HELPER-VIEWS UND METHODEN, DIE VORHER "NOT IN SCOPE" WAREN
    
    private var unavailableTripView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("Reise nicht verfügbar")
                .font(.headline)
            Text("Diese Reise konnte nicht geladen werden. Möglicherweise wurde sie von einem anderen Gerät gelöscht oder geändert.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Schließen") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                if trip.isActive {
                    Button("Reise beenden", systemImage: "stop.circle") {
                        showingEndTripAlert = true
                    }
                }
                Button("Reise bearbeiten", systemImage: "pencil") {
                    tripToEdit = trip
                }
                Button("GPX exportieren", systemImage: "square.and.arrow.up") {
                    showingGPXExportView = true
                }
                .disabled(routePoints.isEmpty)
                Button("Track bearbeiten", systemImage: "wrench.and.screwdriver") {
                    showMapEditView = true
                }
                Button("Reise löschen", systemImage: "trash", role: .destructive) {
                    showingDeleteAlert = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    private func onAppearAction() {
        if !trip.isActive && !routePoints.isEmpty {
            setupMapRegion()
        }
        let allMems = memories
        if allMems.count > 4 {
            randomMemories = Array(allMems.shuffled().prefix(4))
        } else {
            randomMemories = allMems.shuffled()
        }
    }
    
    private func endTrip() {
        // ... Logik ...
    }
    
    private func stopTrackingForTrip() {
        // ... Logik ...
    }
    
    private func deleteTrip() {
        // Sicherheits-Check: Trip muss im Context vorhanden sein
        guard let tripID = trip.id?.uuidString else {
            print("❌ Trip hat keine gültige ID – Löschvorgang abgebrochen")
            // Trotzdem versuchen, das Trip lokal zu löschen
            let context = viewContext
            context.delete(trip)
            try? context.save()
            dismiss()
            return
        }
        
        let settings = AppSettings.shared
        let context = viewContext
        
        // 1. Versuche ggf. Backend-Löschung (falls Backend aktiviert)
        if settings.shouldUseBackend {
            let service = GraphQLTripService()
            service.deleteTrip(id: tripID)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("❌ Backend-Löschung fehlgeschlagen: \(error.localizedDescription)")
                    }
                    // Unabhängig vom Backend: Trip lokal entfernen
                    context.delete(trip)
                    try? context.save()
                    dismiss()
                }, receiveValue: { success in
                    print("✅ Backend-Löschung: \(success ? "erfolgreich" : "fehlgeschlagen")")
                })
                .store(in: &cancellables)
        } else {
            // Nur lokal löschen
            context.delete(trip)
            do {
                try context.save()
                print("✅ Trip lokal gelöscht")
            } catch {
                print("❌ Fehler beim lokalen Löschen: \(error)")
            }
            dismiss()
        }
    }
    
    private func cleanupTemporaryShareFile() {
        // ... Logik ...
    }
    
    private func setupMapRegion() {
        // ... Logik ...
    }
    
    // ... WEITERE HELPER VIEWS WIE tripHeader, mapSection etc. ...
    // (Annahme: diese sind in der Originaldatei vorhanden)
    private var tripHeader: some View { Text("Platzhalter für Header") }
    private var mapSection: some View { Text("Platzhalter für Map") }
    private var memoriesSection: some View { Text("Platzhalter für Memories") }
    private var activityStatisticsSection: some View { Text("Platzhalter für Stats") }
}

struct ActivityStatisticCard: View {
    let statistic: ActivityStatistic
    var body: some View { Text("ActivityStatisticCard") }
}

struct ShareSheetWrapper: UIViewControllerRepresentable {
    @Binding var fileURL: URL?
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        guard let url = fileURL else { return UIActivityViewController(activityItems: [], applicationActivities: nil) }
        return UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ShareSheetWrapper
        init(_ parent: ShareSheetWrapper) {
            self.parent = parent
        }
    }
}