import SwiftUI

struct DebugSettingsSubmenuView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showingGPSDebugView: Bool
    @State private var showingSupabaseTestView = false

    var body: some View {
        List {
            // GPS Debug-Modus Schalter
            HStack {
                Image(systemName: "ladybug.fill")
                    .font(.title3)
                    .foregroundColor(locationManager.isDebugModeEnabled ? .orange : .gray)
                    .frame(width: 24)
                Text("GPS Debug-Modus")
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { locationManager.isDebugModeEnabled },
                    set: { _ in locationManager.toggleDebugMode() }
                ))
                .labelsHidden()
            }
            .padding(.vertical, 8)

            if locationManager.isDebugModeEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Background-Updates: \(locationManager.backgroundUpdateCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let lastUpdate = locationManager.lastBackgroundUpdate {
                        Text("Letztes Update: \(formatDebugDate(lastUpdate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text("Debug-Logs: \(locationManager.debugLogs.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Button(action: {
                        showingGPSDebugView = true
                    }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundColor(.orange)
                            Text("GPS Debug-View öffnen")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            
            // Supabase Sync Test Section
            Section("Supabase Synchronisation") {
                Button(action: {
                    showingSupabaseTestView = true
                }) {
                    HStack {
                        Image(systemName: "cloud.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Supabase Sync Test")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .sheet(isPresented: $showingSupabaseTestView) {
                    SupabaseSyncTestView()
                }
            }
        }
        .navigationTitle("Debug & Entwicklung")
    }

    private func formatDebugDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
} 