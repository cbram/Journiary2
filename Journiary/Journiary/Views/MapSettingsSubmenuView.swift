import SwiftUI

struct MapSettingsSubmenuView: View {
    @Binding var selectedMapType: MapType
    @ObservedObject var mapCache: MapCacheManager
    @Binding var showingOfflineMapSettings: Bool
    @Binding var showingTracesTrackSettings: Bool
    
    @AppStorage("tomorrowIOAPIKey") private var tomorrowIOAPIKey: String = ""
    @State private var showingAPIKeyAlert = false

    var body: some View {
        List {
            // Kartenstil
            HStack {
                Image(systemName: "map.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                Text("Kartenstil")
                    .font(.body)
                Spacer()
                Menu {
                    ForEach(MapType.allCases) { mapType in
                        Button(action: {
                            selectedMapType = mapType
                            UserDefaults.standard.selectedMapType = mapType
                        }) {
                            HStack {
                                Image(systemName: mapType.iconName)
                                Text(mapType.rawValue)
                                if selectedMapType == mapType {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedMapType.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)

            // Offline-Karten
            Button(action: {
                showingOfflineMapSettings = true
            }) {
                SettingsRowNavigable(
                    title: "Offline-Karten",
                    icon: "square.and.arrow.down.fill",
                    status: mapCache.cachedRegions.isEmpty ? "Keine" : "\(mapCache.cachedRegions.count) Regionen"
                )
            }

            // TracesTrack Karten
            Button(action: {
                showingTracesTrackSettings = true
            }) {
                HStack {
                    Image(systemName: "map.fill")
                        .font(.title3)
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TracesTrack Karten")
                            .font(.body)
                            .foregroundColor(.primary)
                        Text("Topo & Vector Karten konfigurieren")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Wetter API
            Button(action: {
                showingAPIKeyAlert = true
            }) {
                HStack {
                    Image(systemName: "cloud.sun.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tomorrow.io Wetter API")
                            .font(.body)
                            .foregroundColor(.primary)
                        Text(tomorrowIOAPIKey.isEmpty ? "Nicht konfiguriert (Demo-Wetter)" : "Konfiguriert")
                            .font(.caption)
                            .foregroundColor(tomorrowIOAPIKey.isEmpty ? .orange : .green)
                    }
                    Spacer()
                    Image(systemName: "key.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Karten & Offlinekarten")
        .alert("Tomorrow.io API-Key", isPresented: $showingAPIKeyAlert) {
            TextField("API-Key eingeben", text: $tomorrowIOAPIKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            
            Button("Speichern") {
                // API-Key wird automatisch durch @AppStorage gespeichert
            }
            
            Button("Löschen", role: .destructive) {
                tomorrowIOAPIKey = ""
            }
            
            Button("Abbrechen", role: .cancel) { }
            
            Button("API-Key erhalten") {
                if let url = URL(string: "https://www.tomorrow.io/weather-api/") {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Geben Sie Ihren Tomorrow.io API-Key ein um echte Wetterdaten zu erhalten. Ohne API-Key werden Demo-Wetterdaten verwendet.\n\nKostenloser API-Key: 500 Aufrufe/Tag\nRegistrierung unter: tomorrow.io/weather-api")
        }
    }
} 