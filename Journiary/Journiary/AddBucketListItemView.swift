import SwiftUI
import CoreData
import MapKit

struct AddBucketListItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var placesManager = PlacesManager()
    
    @State private var name: String = ""
    @State private var country: String = ""
    @State private var region: String = ""
    @State private var type: BucketListType = .nationalpark
    @State private var latitude1: String = ""
    @State private var longitude1: String = ""
    @State private var latitude2: String = ""
    @State private var longitude2: String = ""
    @State private var showingPlaceSearch = false
    @State private var searchQuery: String = ""
    var editItem: BucketListItem? = nil
    
    @State private var didAppear = false
    
    @Binding var selectedTab: Int
    
    @State private var isDone: Bool = false
    @State private var completedAt: Date = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Allgemein")) {
                    TextField("Name", text: $name)
                        .onChange(of: name) { _, newValue in
                            searchQuery = newValue
                        }
                    TextField("Land (english)", text: $country)
                    TextField("Region/State", text: $region)
                    Picker("Art", selection: $type) {
                        ForEach(BucketListType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                }
                // Karte mit Marker und Icon
                if let lat = Double(latitude1), let lon = Double(longitude1), (!latitude1.isEmpty && lat != 0.0) || (!longitude1.isEmpty && lon != 0.0) {
                    Section(header: Text("Karte")) {
                        MapViewWithIcon(latitude: lat, longitude: lon, type: type)
                            .frame(height: 200)
                    }
                }
                // GPS Koordinaten
                Section(header: Text("GPS Koordinate 1 (optional)")) {
                    TextField("Breitengrad", text: $latitude1)
                        .keyboardType(.decimalPad)
                    TextField("Längengrad", text: $longitude1)
                        .keyboardType(.decimalPad)
                }
                if type == .wanderung || type == .radtour || type == .traumstrasse {
                    Section(header: Text("GPS Koordinate 2 (optional)")) {
                        TextField("Breitengrad", text: $latitude2)
                            .keyboardType(.decimalPad)
                        TextField("Längengrad", text: $longitude2)
                            .keyboardType(.decimalPad)
                    }
                }
                // Ortssuche ganz unten
                Section(header: Text("Status")) {
                    Toggle("Bereist (erledigt)", isOn: $isDone)
                    if isDone {
                        DatePicker("Bereist am", selection: $completedAt, displayedComponents: .date)
                    }
                }
                Section(header: Text("Ortssuche")) {
                    Button("🔍 Ort suchen") {
                        showingPlaceSearch = true
                    }
                    .disabled(name.isEmpty)
                    if placesManager.isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Suche läuft...")
                                .foregroundColor(.secondary)
                        }
                    }
                    if let errorMessage = placesManager.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                Button("Speichern") {
                    saveItem()
                }
                .disabled(name.isEmpty || country.isEmpty)
            }
            .navigationTitle(editItem == nil ? "Neues Bucket-List-Item" : name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        selectedTab = 0
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPlaceSearch) {
                PlaceSearchView(
                    placesManager: placesManager,
                    searchQuery: searchQuery,
                    searchCountry: country,
                    onPlaceSelected: { place in
                        selectPlace(place)
                        showingPlaceSearch = false
                    }
                )
            }
        }
        .onAppear {
            if !didAppear {
                if let item = editItem {
                    name = item.name ?? ""
                    country = item.country ?? ""
                    region = item.region ?? ""
                    type = BucketListType(rawValue: item.type ?? "") ?? .nationalpark
                    latitude1 = item.latitude1 != 0.0 ? String(item.latitude1) : ""
                    longitude1 = item.longitude1 != 0.0 ? String(item.longitude1) : ""
                    latitude2 = item.latitude2 != 0.0 ? String(item.latitude2) : ""
                    longitude2 = item.longitude2 != 0.0 ? String(item.longitude2) : ""
                    isDone = item.isDone
                    if let date = item.completedAt { completedAt = date }
                }
                didAppear = true
            }
        }
    }
    
    private func selectPlace(_ place: PlaceSearchResult) {
        name = place.name
        country = place.country
        region = place.region ?? ""
        latitude1 = String(place.latitude)
        longitude1 = String(place.longitude)
        
        // Typ nur setzen, wenn aktuell .sonstiges ausgewählt ist
        if type == .sonstiges, let placeType = place.placeType {
            switch placeType.lowercased() {
            case "park", "national_park":
                type = .nationalpark
            case "locality", "administrative_area_level_1", "administrative_area_level_2":
                type = .stadt
            case "tourist_attraction", "museum", "landmark":
                type = .spot
            case "route", "street_address":
                type = .traumstrasse
            default:
                type = .sonstiges
            }
        }
    }
    
    private func saveItem() {
        let item: BucketListItem
        if let editItem = editItem {
            item = editItem
        } else {
            item = BucketListItem(context: viewContext)
            item.id = UUID()
            item.createdAt = Date()
            item.isDone = false
        }
        item.name = name
        item.country = country
        item.region = region
        item.type = type.rawValue
        item.latitude1 = Double(latitude1) ?? 0.0
        item.longitude1 = Double(longitude1) ?? 0.0
        if let lat2 = Double(latitude2), let lon2 = Double(longitude2), !latitude2.isEmpty, !longitude2.isEmpty {
            item.latitude2 = lat2
            item.longitude2 = lon2
        }
        item.isDone = isDone
        item.completedAt = isDone ? completedAt : nil
        do {
            try viewContext.save()
            selectedTab = 0
            dismiss()
        } catch {
            print("Fehler beim Speichern: \(error.localizedDescription)")
        }
    }
}

// Beispiel-Enum für die Art des Bucket-List-Items
enum BucketListType: String, CaseIterable, Identifiable {
    case nationalpark, stadt, spot, bauwerk, wanderung, radtour, traumstrasse, sonstiges
    
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .nationalpark: return "Nationalpark"
        case .stadt: return "Stadt"
        case .spot: return "Spot"
        case .bauwerk: return "Bauwerk"
        case .wanderung: return "Wanderung"
        case .radtour: return "Radtour"
        case .traumstrasse: return "Traumstraße"
        case .sonstiges: return "Sonstiges"
        }
    }
}

// MapViewWithIcon für Marker und Icon
struct MapViewWithIcon: View {
    let latitude: Double
    let longitude: Double
    let type: BucketListType
    
    @State private var mapPosition: MapCameraPosition
    
    init(latitude: Double, longitude: Double, type: BucketListType) {
        self.latitude = latitude
        self.longitude = longitude
        self.type = type
        
        _mapPosition = State(initialValue: MapCameraPosition.region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        ))
    }
    
    var body: some View {
        Map(position: $mapPosition) {
            Annotation(
                "",
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            ) {
                // Moderner Pin mit Glasmorphism-Effekt (aus BucketListMapView)
                ZStack {
                    // Pin-Form Hintergrund
                    ZStack {
                        // Hauptpin
                        RoundedRectangle(cornerRadius: 16)
                            .frame(width: 40, height: 40)
                        // Pin-Spitze
                        Triangle()
                            .frame(width: 12, height: 8)
                            .offset(y: 24)
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                colorForType(type).opacity(0.9),
                                colorForType(type).opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: colorForType(type).opacity(0.4), radius: 8, x: 0, y: 4)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    // Glasmorphism-Overlay
                    RoundedRectangle(cornerRadius: 16)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.1),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    // Icon
                    Image(systemName: iconForType(type))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
            }
        }
    }
    
    private func iconForType(_ type: BucketListType) -> String {
        switch type {
        case .nationalpark: return "tree.fill"
        case .stadt: return "building.2.fill"
        case .spot: return "camera.fill"
        case .bauwerk: return "building.columns.fill"
        case .wanderung: return "figure.walk"
        case .radtour: return "bicycle"
        case .traumstrasse: return "road.lanes"
        case .sonstiges: return "star.fill"
        }
    }
    
    private func colorForType(_ type: BucketListType) -> Color {
        switch type {
        case .nationalpark: return .green
        case .stadt: return .blue
        case .spot: return .orange
        case .bauwerk: return .brown
        case .wanderung: return .mint
        case .radtour: return .cyan
        case .traumstrasse: return .purple
        case .sonstiges: return .gray
        }
    }
}

// Kompakte Detailansicht für eine Idee
struct BucketListItemDetailCompactView: View {
    let item: BucketListItem
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showEdit = false
    @State private var showMemories = false
    @State private var isEditingStatus = false
    
    @Binding var selectedTab: Int
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Button(action: { showEdit = true }) {
                        Image(systemName: "pencil")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .sheet(isPresented: $showEdit) {
                        AddBucketListItemView(editItem: item, selectedTab: $selectedTab)
                            .environment(\.managedObjectContext, viewContext)
                    }
                }
                // Art Logo oben links
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: iconForType(type))
                            .font(.title2)
                            .foregroundColor(colorForType(type))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(colorForType(type).opacity(0.1))
                            )
                        
                        Text(displayNameForType(type))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(colorForType(type))
                    }
                    
                    Spacer()
                }
                
                // Name und Location
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.name ?? "(Kein Name)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Flagge Land - Region
                    HStack(spacing: 4) {
                        if let country = item.country, !country.isEmpty {
                            Text(CountryHelper.flag(for: country))
                                .font(.subheadline)
                            Text(country)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if let region = item.region, !region.isEmpty {
                                Text("- \(region)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else if let region = item.region, !region.isEmpty {
                            Text(region)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()
                // Karte
                if item.latitude1 != 0.0 || item.longitude1 != 0.0 {
                    MapViewWithIcon(latitude: item.latitude1, longitude: item.longitude1, type: type)
                        .frame(height: 260)
                        .cornerRadius(10)
                }
                // Koordinaten
                if item.latitude1 != 0.0 || item.longitude1 != 0.0 {
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.6f, %.6f", locale: Locale(identifier: "en_US_POSIX"), item.latitude1, item.longitude1))
                            .font(.caption)
                    }
                }
                if (item.latitude2 != 0.0 || item.longitude2 != 0.0) && (type == .wanderung || type == .radtour || type == .traumstrasse) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.6f, %.6f", locale: Locale(identifier: "en_US_POSIX"), item.latitude2, item.longitude2))
                            .font(.caption)
                    }
                }
                // Bereist-Status
                Divider()
                if item.isDone {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Bereist: ")
                            if let date = item.completedAt {
                                Text(dateFormatted(date))
                            } else {
                                Text("unbekannt")
                            }
                            Spacer()
                            
                            Button(isEditingStatus ? "Fertig" : "Bearbeiten") {
                                withAnimation {
                                    isEditingStatus.toggle()
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        if isEditingStatus {
                            Button("Status zurücksetzen") {
                                withAnimation {
                                    item.isDone = false
                                    item.completedAt = nil
                                    try? viewContext.save()
                                    isEditingStatus = false
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                } else {
                    Button {
                        withAnimation {
                            item.isDone = true
                            item.completedAt = Date()
                            try? viewContext.save()
                        }
                    } label: {
                        Label("Als bereist markieren", systemImage: "checkmark.circle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer(minLength: 12)
                // Erinnerungen Button
                if item.hasMemories {
                    Button {
                        showMemories = true
                    } label: {
                        Label("Erinnerungen anzeigen (\(item.memoryCount))", systemImage: "clock.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .sheet(isPresented: $showMemories) {
                        BucketListMemoriesView(bucketListItem: item)
                            .environment(\.managedObjectContext, viewContext)
                    }
                }
            }
            .padding()
        }
    }
    private var type: BucketListType {
        BucketListType(rawValue: item.type ?? "") ?? .sonstiges
    }
    private func iconForType(_ type: BucketListType) -> String {
        switch type {
        case .nationalpark: return "tree.fill"
        case .stadt: return "building.2.fill"
        case .spot: return "camera.fill"
        case .bauwerk: return "building.columns.fill"
        case .wanderung: return "figure.walk"
        case .radtour: return "bicycle"
        case .traumstrasse: return "road.lanes"
        case .sonstiges: return "star.fill"
        }
    }
    private func colorForType(_ type: BucketListType) -> Color {
        switch type {
        case .nationalpark: return .green
        case .stadt: return .blue
        case .spot: return .orange
        case .bauwerk: return .brown
        case .wanderung: return .mint
        case .radtour: return .cyan
        case .traumstrasse: return .purple
        case .sonstiges: return .gray
        }
    }
    private func displayNameForType(_ type: BucketListType) -> String {
        switch type {
        case .nationalpark: return "Nationalpark"
        case .stadt: return "Stadt"
        case .spot: return "Spot"
        case .bauwerk: return "Bauwerk"
        case .wanderung: return "Wanderung"
        case .radtour: return "Radtour"
        case .traumstrasse: return "Traumstraße"
        case .sonstiges: return "Sonstiges"
        }
    }
    private func dateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
} 
