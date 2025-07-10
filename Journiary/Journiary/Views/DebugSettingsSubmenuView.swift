import SwiftUI

struct DebugSettingsSubmenuView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showingGPSDebugView: Bool
    @State private var showingSyncPerformanceView = false

    var body: some View {
        List {
            // Debug-Modus Schalter
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
            
            // Sync Performance & Debug Monitoring
            Section("Sync Debugging & Performance") {
                NavigationLink(destination: SyncDebugDashboard()) {
                    HStack {
                        Image(systemName: "externaldrive.badge.checkmark")
                            .font(.title3)
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        Text("Sync Debug Dashboard")
                            .font(.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                NavigationLink(destination: SyncPerformanceView()) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Sync Performance")
                            .font(.body)
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
        .navigationTitle("Debug & Entwicklung")
    }

    private func formatDebugDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
} 