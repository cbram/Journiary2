//
//  MapView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import MapKit
import CoreData



struct MapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var mapCache = MapCacheManager.shared
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050), // Berlin
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    ))
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)],
        animation: .default
    )
    private var allTrips: FetchedResults<Trip>
    
    @State private var showingLocationPermissionAlert = false
    @State private var showingOfflineMapSettings = false
    
    // Erweiterte Track-Editier-Funktionen
    @State private var isEditingTrack = false
    @State private var selectedRoutePoint: RoutePoint?
    @State private var showingRoutePointEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var routePointToDelete: RoutePoint?
    @State private var showingTrackTools = false
    
    // Neue Drag & Drop Funktionalität
    @State private var isDraggingPoint = false
    @State private var draggedPoint: RoutePoint?
    @State private var dragOffset: CGSize = .zero
    @State private var lastMapTapLocation: CGPoint = .zero
    @State private var mapViewSize: CGSize = CGSize(width: 390, height: 844)

    // Neuer Punkt zwischen zwei bestehenden einfügen
    @State private var selectedPointsForInsertion: Set<RoutePoint> = []
    @State private var isSelectingPointsForInsertion = false
    
    // Optimierte Track-Daten
    @State private var sortedRoutePoints: [RoutePoint] = []
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    
    // Track-Edit-Modus (vereinfacht)
    @State private var isTrackEditMode = false
    
    // Hilfe-View
    @State private var showingHelpView = false
    
    // Debug-View
    @State private var showingDebugView = false
    
    // Kartenwahl (wird jetzt aus UserDefaults gelesen)
    @State private var selectedMapType: MapType = UserDefaults.standard.selectedMapType
    
    var tripToEdit: Trip? = nil
    
    var body: some View {
        ZStack {
            mapContent
            
            VStack {
                // Track-Edit-Banner
                if isTrackEditMode {
                    trackEditBanner
                }
                

                
                // Download Progress Banner
                if mapCache.isDownloadingMaps {
                    downloadProgressView
                }
                
                // Tracking Status Banner (nur im normalen Modus)
                if locationManager.isTracking && !isTrackEditMode {
                    trackingStatusView
                }
                
                Spacer()
                
                // Attribution für OSM-basierte Karten
                if selectedMapType.requiresAttribution {
                    attributionView
                }
                
                // Control Buttons
                if isTrackEditMode {
                    trackEditControlButtons
                } else {
                    standardControlButtons
                }
            }
        }
        .navigationTitle("Karte")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(content: buildToolbarContent)
        .sheet(isPresented: $showingOfflineMapSettings) {
            OfflineMapCacheView()
        }
        .sheet(isPresented: $showingRoutePointEditor) {
            if let selectedPoint = selectedRoutePoint {
                RoutePointEditorView(routePoint: selectedPoint) { action in
                    handleRoutePointAction(action, for: selectedPoint)
                }
            }
        }
        .sheet(isPresented: $showingTrackTools) {
            TrackToolsView(
                routePoints: sortedRoutePoints,
                onAddPoint: addNewRoutePoint,
                onDeletePoints: deleteMultipleRoutePoints,
                onOptimizeTrack: optimizeTrack
            )
        }
        .sheet(isPresented: $showingHelpView) {
            TrackEditHelpView()
        }
        .sheet(isPresented: $showingDebugView) {
            GPSDebugView()
                .environmentObject(locationManager)
        }
        .alert("Routenpunkt löschen", isPresented: $showingDeleteConfirmation) {
            Button("Löschen", role: .destructive) {
                if let point = routePointToDelete {
                    deleteRoutePoint(point)
                }
                routePointToDelete = nil
            }
            Button("Abbrechen", role: .cancel) {
                routePointToDelete = nil
            }
        } message: {
            Text("Möchtest du diesen Routenpunkt wirklich löschen?")
        }
        .onChange(of: selectedRoutePoint) { _, newValue in
            if newValue == nil {
                draggedPoint = nil
                isDraggingPoint = false
            }
        }
        .onAppear {
            // Aktuelle Kartenwahl aus UserDefaults laden
            selectedMapType = UserDefaults.standard.selectedMapType
            
            // Routenpunkte initial laden
            updateRouteData()
            
            // Standortberechtigung prüfen und anfordern
            // Reduzierte Logs für MapView
            // print("🔄 DEBUG: MapView erscheint - prüfe Standortberechtigung")
            checkLocationPermission()
            
            // MARK: - Debug & Diagnose
            
            performStartupDiagnostic()
        }
        .onDisappear {
            // Beim Verlassen des Views den Cache leeren, um bei der Rückkehr frische Daten zu laden
            sortedRoutePoints = []
            routeCoordinates = []
        }
        .onReceive(NotificationCenter.default.publisher(for: .mapTypeChanged)) { _ in
            // Kartenwahl aus UserDefaults neu laden wenn sie im Profil geändert wurde
            selectedMapType = UserDefaults.standard.selectedMapType
        }
        .alert("GPS-Tracking unterbrochen", isPresented: .constant(locationManager.hasUnexpectedTermination)) {
            Button("Fortsetzen") {
                locationManager.manualRecoveryAccepted()
            }
            Button("Beenden") {
                locationManager.manualRecoveryDeclined()
            }
        } message: {
            if let lastSession = locationManager.lastTrackingSession {
                Text("Das GPS-Tracking wurde unerwartet unterbrochen. Letzte Aufzeichnung: \(lastSession.formatted(date: .abbreviated, time: .shortened)). Möchtest du das Tracking fortsetzen?")
            } else {
                Text("Das GPS-Tracking wurde unerwartet unterbrochen. Möchtest du das Tracking fortsetzen?")
            }
        }
        .alert("Standortberechtigung erforderlich", isPresented: $showingLocationPermissionAlert) {
            Button("Einstellungen") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Erneut versuchen") {
                print("🔄 DEBUG: Benutzer möchte erneut versuchen")
                checkLocationPermission()
            }
            Button("Abbrechen", role: .cancel) { 
                print("🔄 DEBUG: Benutzer hat Berechtigung abgebrochen")
            }
        } message: {
            Text(locationPermissionMessage)
        }
    }
    
    // MARK: - Map Style Configuration
    
    private var currentMapStyle: MapStyle {
        return selectedMapType.mapStyle
    }
    
    private var locationPermissionMessage: String {
        let currentStatus = locationManager.authorizationStatus
        let backgroundNeeded = locationManager.enableBackgroundTracking
        
        switch currentStatus {
        case .notDetermined:
            return "Die App benötigt Zugriff auf deinen Standort, um GPS-Tracking zu ermöglichen."
        case .denied:
            return "Der Standortzugriff wurde verweigert. Bitte aktiviere ihn in den iOS-Einstellungen unter Datenschutz > Standortdienste > Journiary."
        case .restricted:
            return "Der Standortzugriff ist durch Einschränkungen blockiert."
        case .authorizedWhenInUse:
            if backgroundNeeded {
                return "Für vollständiges GPS-Tracking im Hintergrund benötigt die App 'Immer' Standortberechtigung. Bitte wähle in den Einstellungen 'Immer zulassen'."
            } else {
                return "Standortberechtigung ist verfügbar, aber es gibt ein technisches Problem."
            }
        case .authorizedAlways:
            return "Standortberechtigung ist verfügbar, aber es gibt ein technisches Problem."
        @unknown default:
            return "Unbekannter Berechtigungsstatus. Bitte kontaktiere den Support."
        }
    }
    
    // MARK: - UI-Komponenten
    
    private var mapContent: some View {
        Group {
            if selectedMapType.isOSMType {
                // OSM MapView (UIKit-basiert)
                OSMMapView(
                    region: $region,
                    routePoints: sortedRoutePoints,
                    selectedRoutePoint: selectedRoutePoint,
                    isTrackEditMode: isTrackEditMode,
                    mapType: selectedMapType,
                    onPointTap: { point in handlePointTap(point) },
                    onPointDrag: { point, value in handlePointDrag(point, value) },
                    onPointDragEnd: { point, value in handlePointDragEnd(point, value) }
                )
            } else {
                // Standard SwiftUI Map
                Map(position: $mapPosition) {
                    UserAnnotation()
                    
                    // Rote Linie zwischen den Route-Punkten (optimiert)
                    if !routeCoordinates.isEmpty {
                        MapPolyline(coordinates: routeCoordinates)
                        .stroke(Color.red, lineWidth: isTrackEditMode ? 4 : 3)
                    }
                    
                    // Route-Punkte mit verbesserter Interaktion (optimiert)
                    if isTrackEditMode {
                        ForEach(sortedRoutePoints, id: \.objectID) { point in
                            Annotation("", coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)) {
                                InteractiveRoutePointView(
                                    point: point,
                                    isSelected: selectedRoutePoint?.objectID == point.objectID,
                                    isSelectedForInsertion: selectedPointsForInsertion.contains(point),
                                    isTrackEditMode: isTrackEditMode,
                                    isSelectingForInsertion: isSelectingPointsForInsertion,
                                    onTap: { handlePointTap(point) },
                                    onDragChanged: { value in handlePointDrag(point, value) },
                                    onDragEnded: { value in handlePointDragEnd(point, value) }
                                )
                            }
                        }
                    }
                }
                .mapStyle(currentMapStyle)
                .mapControlVisibility(.hidden)
            }
        }

        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        mapViewSize = geometry.size
                        print("🔄 DEBUG: Map-View Größe: \(mapViewSize)")
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        mapViewSize = newSize
                        print("🔄 DEBUG: Map-View Größe geändert: \(mapViewSize)")
                    }
            }
        )
        .onMapCameraChange(frequency: .onEnd) { context in
            if !selectedMapType.isOSMType {
                region = context.region
            }
        }
    }


    
    // MARK: - Attribution View
    
    private var attributionView: some View {
        HStack {
            Spacer()
            
            Text(selectedMapType.attributionText)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.trailing, 16)
                .padding(.bottom, 8)
        }
    }
    
    // MARK: - Track-Edit UI-Komponenten
    
    private var trackEditBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.orange)
                Text("Track bearbeiten")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(sortedRoutePoints.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Punkte")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                if selectedRoutePoint != nil {
                    VStack {
                        Text("1")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Ausgewählt")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                if isSelectingPointsForInsertion {
                    VStack {
                        Text("\(selectedPointsForInsertion.count)/2")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Für Einfügen")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                VStack {
                    Text(String(format: "%.1f km", calculateTotalDistance()))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Distanz")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.9))
        .cornerRadius(15)
        .padding(.horizontal)
    }
    
    private var trackEditControlButtons: some View {
        HStack(spacing: 20) {
            // Neuen Punkt hinzufügen
            Button(action: {
                togglePointInsertion()
            }) {
                Image(systemName: isSelectingPointsForInsertion ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(isSelectingPointsForInsertion ? 
                               (selectedPointsForInsertion.count == 2 ? Color.green : Color.orange) : 
                               Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            
            Spacer()
            
            // Punkt löschen
            Button(action: {
                deleteSelectedPoint()
            }) {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(selectedRoutePoint != nil ? Color.red : Color.gray)
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            .disabled(selectedRoutePoint == nil)
            
            Spacer()
            
            // Hilfe-Button
            Button(action: {
                showingHelpView = true
            }) {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.gray.opacity(0.7))
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            
            Spacer()
            
            // Fertig-Button
            Button(action: {
                exitTrackEditMode()
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.green)
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
        }
        .padding()
    }
    
    private var standardControlButtons: some View {
        HStack {
            // Aktuelle Position zentrieren
            Button(action: centerOnCurrentLocation) {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
            
            Spacer()
            
            // Track-Tools Button (nur wenn Punkte vorhanden und nicht im Edit-Modus)
            if !sortedRoutePoints.isEmpty && !isTrackEditMode {
                Button(action: enterTrackEditMode) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.orange)
                        .clipShape(Circle())
                        .shadow(radius: 3)
                }
            }
        }
        .padding()
    }

    // MARK: - Original UI-Komponenten
    

    

    
    // MARK: - Track-Edit Funktionen
    
    private func enterTrackEditMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isTrackEditMode = true
            selectedRoutePoint = nil
            isSelectingPointsForInsertion = false
            selectedPointsForInsertion.removeAll()
        }
    }
    
    private func exitTrackEditMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isTrackEditMode = false
            selectedRoutePoint = nil
            isSelectingPointsForInsertion = false
            selectedPointsForInsertion.removeAll()
        }
    }
    
    private func togglePointInsertion() {
        if isSelectingPointsForInsertion {
            // Bestätigen - neuen Punkt zwischen ausgewählten einfügen
            confirmPointInsertion()
        } else {
            // Aktivieren - Punkt-Auswahl-Modus starten
            withAnimation(.easeInOut(duration: 0.2)) {
                isSelectingPointsForInsertion = true
                selectedRoutePoint = nil
                selectedPointsForInsertion.removeAll()
            }
        }
    }
    
    private func deleteSelectedPoint() {
        guard let selectedPoint = selectedRoutePoint else { return }
        
        routePointToDelete = selectedPoint
        showingDeleteConfirmation = true
    }

    // MARK: - Interaktions-Handler
    
    private func handlePointTap(_ point: RoutePoint) {
        if isTrackEditMode {
            if isSelectingPointsForInsertion {
                // Punkt-Auswahl für Einfügen-Modus
                handlePointSelectionForInsertion(point)
            } else {
                // Normaler Track-Edit-Modus: Punkt auswählen/deselektieren
                withAnimation(.easeInOut(duration: 0.2)) {
                    if selectedRoutePoint?.objectID == point.objectID {
                        selectedRoutePoint = nil
                    } else {
                        selectedRoutePoint = point
                    }
                }
            }
        } else {
            // Im normalen Modus: Track-Edit-Modus aktivieren und Punkt auswählen
            enterTrackEditMode()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedRoutePoint = point
            }
        }
    }
    
    private func handlePointDrag(_ point: RoutePoint, _ value: DragGesture.Value) {
        guard isTrackEditMode else { return }
        
        isDraggingPoint = true
        draggedPoint = point
        
        // Punkt automatisch auswählen wenn nicht bereits ausgewählt
        if selectedRoutePoint?.objectID != point.objectID {
            selectedRoutePoint = point
        }
    }
    
    private func handlePointDragEnd(_ point: RoutePoint, _ value: DragGesture.Value) {
        defer {
            isDraggingPoint = false
            draggedPoint = nil
        }
        
        guard isTrackEditMode && isDraggingPoint else { return }
        
        let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
        
                 // Mindestabstand für Verschiebung - sehr niedrig für bessere Responsivität
         guard dragDistance > 3 else { return }
        
                 // Verbesserte Koordinaten-Umrechnung basierend auf tatsächlicher Map-Größe und Zoom-Level
         let screenWidth = max(mapViewSize.width, 200) // Fallback für sehr kleine Screens
         let screenHeight = max(mapViewSize.height, 200)
         
         // Berechne Koordinaten-Delta basierend auf aktuellem Map-Bereich
         let latDeltaPerPixel = region.span.latitudeDelta / Double(screenHeight)
         let lonDeltaPerPixel = region.span.longitudeDelta / Double(screenWidth)
        
        let latDelta = -Double(value.translation.height) * latDeltaPerPixel
        let lonDelta = Double(value.translation.width) * lonDeltaPerPixel
        
        let newLatitude = point.latitude + latDelta
        let newLongitude = point.longitude + lonDelta
        
        // Koordinaten validieren
        guard newLatitude >= -85 && newLatitude <= 85 && 
              newLongitude >= -180 && newLongitude <= 180 else {
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.error)
            return
        }
        
        // Koordinaten aktualisieren
        updateRoutePointCoordinates(point, latitude: newLatitude, longitude: newLongitude)
        
        // Erfolgs-Feedback
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)
    }
    

    
    private func handleBackgroundTap() {
        // Auswahl aufheben wenn auf leeren Bereich getappt wird
        if selectedRoutePoint != nil {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedRoutePoint = nil
            }
        }
    }
    
    private func handlePointSelectionForInsertion(_ point: RoutePoint) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedPointsForInsertion.contains(point) {
                // Punkt deselektieren
                selectedPointsForInsertion.remove(point)
            } else if selectedPointsForInsertion.count < 2 {
                // Punkt zur Auswahl hinzufügen
                selectedPointsForInsertion.insert(point)
                
                // Haptic feedback
                let haptic = UIImpactFeedbackGenerator(style: .light)
                haptic.impactOccurred()
            } else {
                // Bereits 2 Punkte ausgewählt - ersetze einen
                selectedPointsForInsertion.removeAll()
                selectedPointsForInsertion.insert(point)
            }
        }
    }
    
    private func confirmPointInsertion() {
        guard selectedPointsForInsertion.count == 2 else { return }
        
        let points = Array(selectedPointsForInsertion)
        let sortedRoutePoints = self.sortedRoutePoints // Greife auf die sortierte Liste zu
        
        // Finde die Indizes der ausgewählten Punkte
        guard let index1 = sortedRoutePoints.firstIndex(where: { $0.objectID == points[0].objectID }),
              let index2 = sortedRoutePoints.firstIndex(where: { $0.objectID == points[1].objectID }) else {
            return
        }
        
        // Prüfe ob die Punkte benachbart sind
        let minIndex = min(index1, index2)
        let maxIndex = max(index1, index2)
        
        guard maxIndex - minIndex == 1 else {
             // Haptic feedback für Fehler
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.error)
            return
        }
        
        // Berechne Position zwischen den beiden Punkten
        let point1 = sortedRoutePoints[minIndex]
        let point2 = sortedRoutePoints[maxIndex]
        
        let midLatitude = (point1.latitude + point2.latitude) / 2.0
        let midLongitude = (point1.longitude + point2.longitude) / 2.0
        let midAltitude = (point1.altitude + point2.altitude) / 2.0
        
        // Erstelle neuen Punkt
        let newRoutePoint = RoutePoint(context: viewContext)
        newRoutePoint.latitude = midLatitude
        newRoutePoint.longitude = midLongitude
        newRoutePoint.altitude = midAltitude
        newRoutePoint.speed = 0.0
        newRoutePoint.timestamp = Date(timeInterval: 1, since: point1.timestamp ?? Date())
        
        // Aktiver Reise zuordnen
        if let activeTrip = tripToEdit ?? allTrips.first {
            newRoutePoint.trip = activeTrip
        }
        
        do {
            try viewContext.save()
            
            // Routen-Daten aktualisieren
            updateRouteData()
            
            // Neuen Punkt direkt auswählen und Einfügen-Modus beenden
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedRoutePoint = newRoutePoint
                isSelectingPointsForInsertion = false
                selectedPointsForInsertion.removeAll()
            }
            
            // Haptic feedback
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.success)
            
        } catch {
            // Error haptic feedback
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.error)
        }
    }
    

    
    // MARK: - Track-Editier Banner
    

    
    // MARK: - Track-Editier-Tools
    

    

    
    private var downloadProgressView: some View {
        VStack(spacing: 8) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Karten werden heruntergeladen...")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(mapCache.downloadProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            ProgressView(value: mapCache.downloadProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .background(Color.white.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding()
        .background(Color.blue.opacity(0.8))
        .cornerRadius(15)
        .padding(.horizontal)
    }
    
    private var trackingStatusView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
                Text("Tracking aktiv")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Recovery-Indikator
                if locationManager.lastTrackingSession != nil {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.orange)
                }
                
                // Background-Tracking Indikator
                if locationManager.enableBackgroundTracking && 
                   locationManager.authorizationStatus == .authorizedAlways {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.blue)
                } else if locationManager.enableBackgroundTracking {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
            }
            
            // Recovery-Hinweis
            if locationManager.lastTrackingSession != nil {
                Text("Session wiederhergestellt")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            // Status-Text für Background-Tracking
            if locationManager.enableBackgroundTracking {
                if locationManager.authorizationStatus == .authorizedAlways {
                    Text("Background-Tracking aktiv")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("'Immer' Berechtigung für Background benötigt")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            HStack(spacing: 20) {
                VStack {
                    Text(String(format: "%d km", Int(locationManager.totalDistance / 1000)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Distanz")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                if locationManager.automaticOptimizationEnabled {
                    VStack {
                        Text(locationManager.currentAutomaticOptimization)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Optimierungslevel")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                if let trip = locationManager.currentTrip,
                   let startDate = trip.startDate {
                    VStack {
                        Text(formatDuration(from: startDate))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Zeit")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(15)
        .padding(.horizontal)
    }
    
    private var activeTrip: Trip? {
        tripToEdit ?? allTrips.first
    }
    
    // MARK: - Daten-Management (Optimiert)
    
    private func updateRouteData() {
        guard let activeTrip = tripToEdit ?? allTrips.first,
              let points = activeTrip.routePoints?.allObjects as? [RoutePoint] else {
            if !sortedRoutePoints.isEmpty {
                sortedRoutePoints = []
                routeCoordinates = []
            }
            return
        }

        let sorted = points.sorted { $0.timestamp ?? Date() < $1.timestamp ?? Date() }
        
        // Aktualisiere nur, wenn sich wirklich etwas geändert hat
        if sorted.map({$0.objectID}) != sortedRoutePoints.map({$0.objectID}) || routeCoordinates.isEmpty {
            sortedRoutePoints = sorted
            routeCoordinates = sorted.map { .init(latitude: $0.latitude, longitude: $0.longitude) }
            setRegionToFitTrack()
        }
        // Distanz nach jedem Laden neu berechnen
        recalculateTripDistance(activeTrip)
    }
    
    // MARK: - Track-Editier-Funktionen
    
    private func toggleTrackEditing() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isEditingTrack.toggle()
            if !isEditingTrack {
                selectedRoutePoint = nil
            }
        }
    }
    
    private func handleRoutePointAction(_ action: RoutePointAction, for point: RoutePoint) {
        switch action {
        case .delete:
            routePointToDelete = point
            showingDeleteConfirmation = true
        case .moveToCurrentLocation:
            moveRoutePointToCurrentLocation(point)
        case .updateCoordinates(let latitude, let longitude):
            updateRoutePointCoordinates(point, latitude: latitude, longitude: longitude)
        }
        selectedRoutePoint = nil
        showingRoutePointEditor = false
    }
    
    private func deleteRoutePoint(_ point: RoutePoint) {
        viewContext.delete(point)
        
        do {
            try viewContext.save()
            
            // Routen-Daten aktualisieren
            updateRouteData()
            
            // Distanz der aktiven Reise neu berechnen
            if let activeTrip = tripToEdit ?? allTrips.first {
                recalculateTripDistance(activeTrip)
            }
        } catch {
            // Error haptic feedback
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.error)
        }
    }
    
    private func deleteMultipleRoutePoints(_ indices: [Int]) {
        let pointsToDelete = indices.compactMap { index in
            index < sortedRoutePoints.count ? sortedRoutePoints[index] : nil
        }
        
        for point in pointsToDelete {
            viewContext.delete(point)
        }
        
        do {
            try viewContext.save()
            
            // Routen-Daten aktualisieren
            updateRouteData()
            
            // Distanz der aktiven Reise neu berechnen
            if let activeTrip = tripToEdit ?? allTrips.first {
                recalculateTripDistance(activeTrip)
            }
        } catch {
            // Error haptic feedback
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.error)
        }
    }
    
    private func addNewRoutePoint(at coordinate: CLLocationCoordinate2D, at index: Int?) {
        guard let activeTrip = tripToEdit ?? allTrips.first else { return }
        
        let newPoint = RoutePoint(context: viewContext)
        newPoint.latitude = coordinate.latitude
        newPoint.longitude = coordinate.longitude
        newPoint.timestamp = Date()
        newPoint.altitude = 0.0
        newPoint.speed = 0.0
        newPoint.trip = activeTrip
        
        do {
            try viewContext.save()
            
            // Routen-Daten aktualisieren
            updateRouteData()
            
            // Distanz der aktiven Reise neu berechnen
            recalculateTripDistance(activeTrip)
        } catch {
            // Error haptic feedback
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.error)
        }
    }
    
    private func moveRoutePointToCurrentLocation(_ point: RoutePoint) {
        guard let currentLocation = locationManager.currentLocation else { return }
        
        point.latitude = currentLocation.coordinate.latitude
        point.longitude = currentLocation.coordinate.longitude
        point.altitude = currentLocation.altitude
        
        do {
            try viewContext.save()
            
            // Routen-Daten aktualisieren
            updateRouteData()
            
            // Distanz der aktiven Reise neu berechnen
            if let activeTrip = tripToEdit ?? allTrips.first {
                recalculateTripDistance(activeTrip)
            }
        } catch {
            // Error haptic feedback
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.error)
        }
    }
    
    private func updateRoutePointCoordinates(_ point: RoutePoint, latitude: Double, longitude: Double) {
        point.latitude = latitude
        point.longitude = longitude
        
        do {
            try viewContext.save()
            
            // Routen-Daten aktualisieren (nur Koordinaten, kein Neusortieren nötig)
            if let index = sortedRoutePoints.firstIndex(where: { $0.objectID == point.objectID }) {
                routeCoordinates[index] = .init(latitude: latitude, longitude: longitude)
            }
            
            // Distanz der aktiven Reise neu berechnen
            if let activeTrip = tripToEdit ?? allTrips.first {
                recalculateTripDistance(activeTrip)
            }
        } catch {
            // Error haptic feedback
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.error)
        }
    }
    
    private func optimizeTrack() {
        guard sortedRoutePoints.count >= 3 else { return }
        
        // Bestimme Optimierungseinstellungen basierend auf Transportmittel
        // Da transportationMode noch nicht im Core Data Model vorhanden ist, verwenden wir "level2" als Default
        let settings = TrackOptimizer.OptimizationSettings.level2
        
        // Führe Optimierung durch
        let optimizedPoints = TrackOptimizer.optimizeExistingTrack(
            routePoints: sortedRoutePoints,
            settings: settings
        )
        
        // Lösche alle Punkte, die nicht in der optimierten Liste sind
        let optimizedObjectIDs = Set(optimizedPoints.map { $0.objectID })
        let pointsToDelete = sortedRoutePoints.filter { !optimizedObjectIDs.contains($0.objectID) }
        
        for point in pointsToDelete {
            viewContext.delete(point)
        }
        
        do {
            try viewContext.save()
            
            // Routen-Daten aktualisieren
            updateRouteData()
            
            // Erfolgs-Feedback
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.success)
            
        } catch {
            // Error haptic feedback
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.error)
        }
    }
    
    private func smoothTrack() {
        guard sortedRoutePoints.count >= 5 else { return }
        
        // Einfache Glättung: Ersetze jeden Punkt (außer ersten und letzten) 
        // durch den Durchschnitt seiner Nachbarn
        let pointsToSmooth = sortedRoutePoints.dropFirst().dropLast()
        
        for (index, point) in pointsToSmooth.enumerated() {
            let actualIndex = index + 1 // wegen dropFirst()
            let prevPoint = sortedRoutePoints[actualIndex - 1]
            let nextPoint = sortedRoutePoints[actualIndex + 1]
            
            // Berechne Durchschnitt der Koordinaten
            let smoothedLatitude = (prevPoint.latitude + point.latitude + nextPoint.latitude) / 3.0
            let smoothedLongitude = (prevPoint.longitude + point.longitude + nextPoint.longitude) / 3.0
            
            point.latitude = smoothedLatitude
            point.longitude = smoothedLongitude
        }
        
        do {
            try viewContext.save()
            
            // Routen-Daten aktualisieren
            updateRouteData()
            
            // Distanz der aktiven Reise neu berechnen
            if let activeTrip = tripToEdit ?? allTrips.first {
                recalculateTripDistance(activeTrip)
            }
        } catch {
            // Error haptic feedback
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.error)
        }
    }
    
    private func calculateTotalDistance() -> Double {
        guard sortedRoutePoints.count > 1 else { return 0.0 }
        
        var totalDistance: Double = 0.0
        
        for i in 1..<sortedRoutePoints.count {
            let prevPoint = sortedRoutePoints[i-1]
            let currentPoint = sortedRoutePoints[i]
            
            let prevLocation = CLLocation(latitude: prevPoint.latitude, longitude: prevPoint.longitude)
            let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
            
            totalDistance += currentLocation.distance(from: prevLocation)
        }
        
        return totalDistance / 1000.0 // In Kilometern
    }
    
    private func recalculateTripDistance(_ trip: Trip) {
        guard let points = trip.routePoints?.allObjects as? [RoutePoint],
              points.count > 1 else {
            trip.totalDistance = 0.0
            return
        }

        let sortedPoints = points.sorted { $0.timestamp ?? Date() < $1.timestamp ?? Date() }
        var totalDistance: Double = 0.0

        for i in 1..<sortedPoints.count {
            let prevPoint = sortedPoints[i-1]
            let currentPoint = sortedPoints[i]
            let prevLocation = CLLocation(latitude: prevPoint.latitude, longitude: prevPoint.longitude)
            let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
            totalDistance += currentLocation.distance(from: prevLocation)
        }

        trip.totalDistance = totalDistance
        
        do {
            try viewContext.save()
            viewContext.refreshAllObjects()
        } catch {
            // Error haptic feedback
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.error)
        }
    }
    
    // MARK: - Existing Functions
    
    private func checkLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestLocationPermission()
        case .denied, .restricted:
            showingLocationPermissionAlert = true
        case .authorizedWhenInUse:
            if locationManager.enableBackgroundTracking {
                // Kurz warten bevor Always-Berechtigung angefordert wird
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.locationManager.requestAlwaysAuthorization()
                }
            }
            // Daten aktualisieren, falls sich in der Zwischenzeit etwas geändert hat
            updateRouteData()
        case .authorizedAlways:
            // Daten aktualisieren, falls sich in der Zwischenzeit etwas geändert hat
            updateRouteData()
        @unknown default:
            break
        }
    }
    
    private func centerOnCurrentLocation() {
        if let location = locationManager.currentLocation {
            withAnimation(.easeInOut(duration: 0.5)) {
                let newRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                region = newRegion
                mapPosition = .region(newRegion)
            }
        }
    }
    
    private func toggleTracking() {
        guard locationManager.enableBackgroundTracking ? 
            locationManager.authorizationStatus == .authorizedAlways :
            (locationManager.authorizationStatus == .authorizedWhenInUse || 
             locationManager.authorizationStatus == .authorizedAlways) else {
            showingLocationPermissionAlert = true
            return
        }
        
        if locationManager.isTracking {
            locationManager.stopTrackingProtected(userInitiated: true, reason: "Benutzer Toggle")
        } else {
            // Hier würden wir normalerweise einen Dialog zeigen, um Reisename und Transportart zu wählen
            // Für jetzt verwenden wir Standardwerte
            locationManager.startTrackingProtected(tripName: "Neue Reise", userInitiated: true)
        }
    }
    
    private func formatDuration(from startDate: Date) -> String {
        let duration = Date().timeIntervalSince(startDate)
        let days = Int(duration) / 86400
        let hours = (Int(duration) % 86400) / 3600
        
        if days > 0 {
            return String(format: "%dd %dh", days, hours)
        } else {
            return String(format: "%dh", hours)
        }
    }
    
    // MARK: - Debug & Diagnose
    
    private func performStartupDiagnostic() {
        // Reduzierte GPS-Diagnose (nur bei kritischen Zuständen)
        if !locationManager.isTracking && locationManager.authorizationStatus != .authorizedAlways {
            print("📍 GPS-Status: \(locationManager.authorizationStatus), Tracking: \(locationManager.isTracking)")
        }
        
        // Reduzierte Diagnose-Ausgaben (alle anderen Checks auskommentiert)
        /*
        // LocationServices Check auf Background Thread
        DispatchQueue.global(qos: .utility).async {
            let locationServicesEnabled = CLLocationManager.locationServicesEnabled()
            DispatchQueue.main.async {
                print("⚙️ CLLocationManager configured: \(locationServicesEnabled)")
            }
        }
        
        print("💾 UserDefaults Background: \(UserDefaults.standard.object(forKey: "enableBackgroundTracking") ?? "nicht gesetzt")")
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel : 0.0
        print("🔋 Device Battery Level: \(String(format: "%.0f%%", batteryLevel * 100))")
        
        // Recovery-Status
        print("🔄 Recovery-Status:")
        print("  - Unexpected Termination: \(locationManager.hasUnexpectedTermination)")
        print("  - Last Tracking Session: \(locationManager.lastTrackingSession?.description ?? "none")")
        
        // Background-Status
        let isTrackingActive = UserDefaults.standard.bool(forKey: "recovery_isTrackingActive")
        let currentTripID = UserDefaults.standard.string(forKey: "recovery_currentTripID")
        let lastHeartbeat = UserDefaults.standard.object(forKey: "recovery_lastHeartbeat") as? Date
        
        print("💾 Recovery-Daten:")
        print("  - Tracking Active Flag: \(isTrackingActive)")
        print("  - Current Trip ID: \(currentTripID ?? "none")")
        print("  - Last Heartbeat: \(lastHeartbeat?.description ?? "none")")
        
        if let currentLocation = locationManager.currentLocation {
            print("📍 Aktuelle Position: \(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)")
            print("📍 Genauigkeit: \(currentLocation.horizontalAccuracy)m")
        } else {
            print("📍 Keine aktuelle Position verfügbar")
        }
        
        // Teste Berechtigung
        let buttonShouldBeEnabled = (locationManager.authorizationStatus == .authorizedWhenInUse || 
                                   locationManager.authorizationStatus == .authorizedAlways)
        print("🔘 Button sollte aktiviert sein: \(buttonShouldBeEnabled)")
        
        // Teste Background-Berechtigung
        if locationManager.enableBackgroundTracking {
            let hasAlwaysPermission = locationManager.authorizationStatus == .authorizedAlways
            print("🌙 Always-Berechtigung für Background: \(hasAlwaysPermission)")
        }
        
        // Background Modes Check
        if let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] {
            print("📲 Background Modes: \(backgroundModes)")
        }
        */
    }
    
    // MARK: - Recovery Testing (Debug only)
    
    private func simulateCrash() {
        guard locationManager.isDebugModeEnabled else { return }
        
        if locationManager.isTracking {
            // Setze Recovery-Flags als ob App abgestürzt wäre
            UserDefaults.standard.set(true, forKey: "recovery_isTrackingActive")
            if let trip = locationManager.currentTrip {
                UserDefaults.standard.set(trip.id?.uuidString, forKey: "recovery_currentTripID")
            }
            UserDefaults.standard.set(locationManager.totalDistance, forKey: "recovery_totalDistanceAtLastSave")
            UserDefaults.standard.set(Date().addingTimeInterval(-120), forKey: "recovery_lastHeartbeat") // 2 Minuten alt
            UserDefaults.standard.set(false, forKey: "recovery_appTerminationFlag") // Keine saubere Beendigung
            
            if let startDate = locationManager.currentTrip?.startDate {
                UserDefaults.standard.set(startDate, forKey: "recovery_trackingStartTime")
            }
            
            // Simuliere Tracking-Stop
            locationManager.stopTracking()
            
            // Force Recovery-Check
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.locationManager.checkForCrashRecovery()
            }
        } else {
            print("🧪 TEST: Kein aktives Tracking - starte erst Tracking")
        }
    }
    
    private func clearRecoveryTestData() {
        guard locationManager.isDebugModeEnabled else { return }
        
        UserDefaults.standard.removeObject(forKey: "recovery_isTrackingActive")
        UserDefaults.standard.removeObject(forKey: "recovery_currentTripID")
        UserDefaults.standard.removeObject(forKey: "recovery_lastKnownLocation")
        UserDefaults.standard.removeObject(forKey: "recovery_lastHeartbeat")
        UserDefaults.standard.removeObject(forKey: "recovery_appTerminationFlag")
        UserDefaults.standard.removeObject(forKey: "recovery_trackingStartTime")
        UserDefaults.standard.removeObject(forKey: "recovery_totalDistanceAtLastSave")
        
        locationManager.hasUnexpectedTermination = false
        locationManager.lastTrackingSession = nil
    }
    
    // MARK: - Toolbar Content Builder
    
    @ToolbarContentBuilder
    private func buildToolbarContent() -> some ToolbarContent {
        // Debug-Button (nur wenn Debug-Modus aktiviert)
        if locationManager.isDebugModeEnabled {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingDebugView = true
                }) {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(.orange)
                }
            }
            
            // Recovery-Test-Button (nur für Debug)
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Simulate Crash") {
                        simulateCrash()
                    }
                    Button("Force Recovery Check") {
                        locationManager.checkForCrashRecovery()
                    }
                    Button("Clear Recovery Data") {
                        clearRecoveryTestData()
                    }
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }
        }
        
        // Offline-Karten Button
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                showingOfflineMapSettings = true
            }) {
                Image(systemName: mapCache.cachedRegions.isEmpty ? "square.and.arrow.down" : "checkmark.circle.fill")
                    .foregroundColor(mapCache.cachedRegions.isEmpty ? .blue : .green)
            }
        }
    }
    
    // Setzt die Map-Region so, dass der gesamte Track sichtbar ist
    private func setRegionToFitTrack() {
        guard !routeCoordinates.isEmpty else { return }
        var minLat = routeCoordinates.first!.latitude
        var maxLat = routeCoordinates.first!.latitude
        var minLon = routeCoordinates.first!.longitude
        var maxLon = routeCoordinates.first!.longitude

        for coord in routeCoordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.3),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.3)
        )
        let region = MKCoordinateRegion(center: center, span: span)
        self.region = region
        self.mapPosition = .region(region)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let locationManager = LocationManager(context: context)
    
    return MapView()
        .environmentObject(locationManager)
        .environment(\.managedObjectContext, context)
} 