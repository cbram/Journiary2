import SwiftUI

struct DebugSettingsSubmenuView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var showingGPSDebugView: Bool
    @State private var showingMultiUserDemo = false

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
            
            // 🆕 Multi-User Demo Section
            Section("Multi-User Core Data") {
                Button(action: {
                    showingMultiUserDemo = true
                }) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Multi-User Demo")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Text("Schema V2 mit User-Relationships testen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle("Debug & Entwicklung")
        .sheet(isPresented: $showingMultiUserDemo) {
            MultiUserDemoView()
        }
    }

    private func formatDebugDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
} 