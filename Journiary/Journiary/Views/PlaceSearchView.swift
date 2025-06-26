import SwiftUI

struct PlaceSearchView: View {
    @ObservedObject var placesManager: PlacesManager
    @State var searchQuery: String
    var searchCountry: String? = nil
    let onPlaceSelected: (PlaceSearchResult) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Suchfeld
                SearchBar(text: $searchText, onSearchButtonClicked: {
                    print("[PlaceSearchView] Suche ausgelöst: query=\(searchText), country=\(searchCountry ?? "-")")
                    Task {
                        await placesManager.searchPlaces(query: searchText, country: searchCountry)
                    }
                })
                .padding(.horizontal)
                
                // Ländereingabe für Nominatim
                if UserDefaults.standard.string(forKey: "PlaceProvider") == "Nominatim" {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        TextField("Land (english)", text: Binding(
                            get: { searchCountry ?? "" },
                            set: { newValue in
                                // searchCountry ist let, daher Workaround über UserDefaults
                                UserDefaults.standard.set(newValue, forKey: "PlaceSearchCountry")
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                }
                
                if placesManager.isSearching {
                    Spacer()
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Suche nach Orten...")
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                    Spacer()
                } else if placesManager.searchResults.isEmpty && searchText.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Geben Sie einen Ortsnamen ein")
                            .foregroundColor(.secondary)
                            .padding(.top)
                        Text("z.B. \"Neuschwanstein\", \"Berlin\", \"Yellowstone National Park\"")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                } else if placesManager.searchResults.isEmpty && !searchText.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: "location.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Keine Orte gefunden")
                            .foregroundColor(.secondary)
                            .padding(.top)
                        Text("Versuchen Sie es mit einem anderen Suchbegriff")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(placesManager.searchResults) { place in
                        PlaceRowView(place: place) {
                            onPlaceSelected(place)
                        }
                    }
                }
                
                if let errorMessage = placesManager.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .foregroundColor(.orange)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle("Ort suchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                searchText = searchQuery
                print("[PlaceSearchView] onAppear: query=\(searchQuery), country=\(searchCountry ?? "-")")
                if !searchQuery.isEmpty {
                    Task {
                        await placesManager.searchPlaces(query: searchQuery, country: searchCountry)
                    }
                }
            }
        }
    }
}

struct PlaceRowView: View {
    let place: PlaceSearchResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(place.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "location")
                        .foregroundColor(.blue)
                }
                
                Text(place.formattedAddress)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text("📍 \(String(format: "%.4f", place.latitude)), \(String(format: "%.4f", place.longitude))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let placeType = place.placeType {
                        Text(localizedPlaceType(placeType))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func localizedPlaceType(_ type: String) -> String {
        switch type.lowercased() {
        case "park", "national_park":
            return "Park"
        case "locality":
            return "Ort"
        case "tourist_attraction":
            return "Spot"
        case "museum":
            return "Museum"
        case "restaurant":
            return "Restaurant"
        case "lodging":
            return "Unterkunft"
        case "natural_feature":
            return "Naturgebiet"
        default:
            return type.capitalized
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            TextField("Ort eingeben...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    onSearchButtonClicked()
                }
            
            Button("Suchen", action: onSearchButtonClicked)
                .disabled(text.isEmpty)
        }
    }
} 