//
//  GPSDebugView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import CoreLocation

struct GPSDebugView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedLogType: DebugLogType?
    @State private var showingShareSheet = false
    @State private var debugExportText = ""
    @State private var refreshTimer: Timer?
    @State private var showingClearConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                // Status-Sektion
                Section("GPS Debug Status") {
                    statusRow(
                        icon: "power",
                        title: "Debug-Modus",
                        value: locationManager.isDebugModeEnabled ? "Aktiviert" : "Deaktiviert",
                        color: locationManager.isDebugModeEnabled ? .green : .gray
                    )
                    
                    statusRow(
                        icon: "bell.fill",
                        title: "Push-Benachrichtigungen",
                        value: locationManager.enableDebugNotifications ? "Aktiviert" : "Deaktiviert",
                        color: locationManager.enableDebugNotifications ? .green : .gray
                    )
                    
                    statusRow(
                        icon: "location.fill",
                        title: "Standortberechtigung",
                        value: authorizationStatusText,
                        color: authorizationStatusColor
                    )
                    
                    statusRow(
                        icon: "moon.fill",
                        title: "Background-Updates",
                        value: "\(locationManager.backgroundUpdateCount)",
                        color: .blue
                    )
                    
                    if let lastUpdate = locationManager.lastBackgroundUpdate {
                        statusRow(
                            icon: "clock.fill",
                            title: "Letztes Background-Update",
                            value: formatDate(lastUpdate),
                            color: .blue
                        )
                    }
                    
                    if let currentLocation = locationManager.currentLocation {
                        statusRow(
                            icon: "globe",
                            title: "Aktuelle Position",
                            value: String(format: "%.6f, %.6f", locale: Locale(identifier: "en_US_POSIX"), currentLocation.coordinate.latitude, currentLocation.coordinate.longitude),
                            color: .green
                        )
                        
                        statusRow(
                            icon: "target",
                            title: "Genauigkeit",
                            value: String(format: "%.1f m", currentLocation.horizontalAccuracy),
                            color: currentLocation.horizontalAccuracy < 20 ? .green : currentLocation.horizontalAccuracy < 50 ? .orange : .red
                        )
                        
                        statusRow(
                            icon: "speedometer",
                            title: "Geschwindigkeit",
                            value: String(format: "%.1f km/h", max(0, currentLocation.speed * 3.6)),
                            color: .blue
                        )
                        
                        statusRow(
                            icon: "mountain.2.fill",
                            title: "Höhe",
                            value: String(format: "%.1f m", currentLocation.altitude),
                            color: .blue
                        )
                    }
                    
                    statusRow(
                        icon: "battery.100",
                        title: "Akkustand",
                        value: {
                            UIDevice.current.isBatteryMonitoringEnabled = true
                            let batteryLevel = UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel : 0.0
                            return String(format: "%.0f%%", batteryLevel * 100)
                        }(),
                        color: {
                            UIDevice.current.isBatteryMonitoringEnabled = true
                            let batteryLevel = UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel : 0.0
                            return batteryLevel > 0.2 ? .green : .red
                        }()
                    )
                }
                
                // Schnelle Aktionen
                Section("Aktionen") {
                    Button(action: {
                        locationManager.toggleDebugMode()
                    }) {
                        HStack {
                            Image(systemName: locationManager.isDebugModeEnabled ? "power" : "power")
                                .foregroundColor(locationManager.isDebugModeEnabled ? .red : .green)
                            Text(locationManager.isDebugModeEnabled ? "Debug-Modus deaktivieren" : "Debug-Modus aktivieren")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        locationManager.toggleDebugNotifications()
                    }) {
                        HStack {
                            Image(systemName: locationManager.enableDebugNotifications ? "bell.slash.fill" : "bell.fill")
                                .foregroundColor(locationManager.enableDebugNotifications ? .red : .green)
                            Text(locationManager.enableDebugNotifications ? "Benachrichtigungen deaktivieren" : "Benachrichtigungen aktivieren")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    
                    Button(action: exportLogs) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("Debug-Logs exportieren (\(locationManager.debugLogs.count))")
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        showingClearConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Logs löschen")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
                
                // Log-Filter
                Section("Log-Filter") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            FilterButton(
                                title: "Alle",
                                isSelected: selectedLogType == nil,
                                color: .blue
                            ) {
                                selectedLogType = nil
                            }
                            
                            ForEach(DebugLogType.allCases, id: \.self) { logType in
                                FilterButton(
                                    title: logType.rawValue.capitalized,
                                    isSelected: selectedLogType == logType,
                                    color: logType.color,
                                    icon: logType.icon
                                ) {
                                    selectedLogType = selectedLogType == logType ? nil : logType
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .listRowInsets(EdgeInsets())
                
                // Debug-Logs
                Section("Debug-Logs (\(filteredLogs.count))") {
                    if filteredLogs.isEmpty {
                        Text("Keine Logs vorhanden")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(filteredLogs) { log in
                            DebugLogRow(log: log)
                        }
                    }
                }
            }
            .navigationTitle("GPS Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Logs manuell neu laden / UI refreshen
                        // Die UI wird automatisch durch @EnvironmentObject aktualisiert
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .alert("Logs löschen", isPresented: $showingClearConfirmation) {
                Button("Löschen", role: .destructive) {
                    locationManager.clearDebugLogs()
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Möchtest du alle Debug-Logs löschen?")
            }
            .sheet(isPresented: $showingShareSheet) {
                DebugShareSheet(activityItems: [debugExportText])
            }
            .onAppear {
                // Auto-Refresh alle 2 Sekunden wenn Debug-Modus aktiv
                startAutoRefresh()
            }
            .onDisappear {
                stopAutoRefresh()
            }
        }
    }
    
    private var filteredLogs: [DebugLogEntry] {
        if let selectedType = selectedLogType {
            return locationManager.debugLogs.filter { $0.type == selectedType }
        }
        return locationManager.debugLogs
    }
    
    private var authorizationStatusText: String {
        switch locationManager.authorizationStatus {
        case .notDetermined: return "Nicht festgelegt"
        case .denied: return "Verweigert"
        case .restricted: return "Eingeschränkt"
        case .authorizedWhenInUse: return "Bei App-Nutzung"
        case .authorizedAlways: return "Immer"
        @unknown default: return "Unbekannt"
        }
    }
    
    private var authorizationStatusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways: return .green
        case .authorizedWhenInUse: return .orange
        case .denied, .restricted: return .red
        case .notDetermined: return .yellow
        @unknown default: return .gray
        }
    }
    
    private func statusRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func exportLogs() {
        print("🔍 GPSDebugView: Starte Export...")
        debugExportText = locationManager.exportDebugLogs()
        
        print("🔍 GPSDebugView: Export-Text erhalten, Länge: \(debugExportText.count)")
        
        if debugExportText.isEmpty {
            print("⚠️ GPSDebugView: Export-Text ist leer!")
            debugExportText = "=== FEHLER ===\nKeine Debug-Logs gefunden oder Export fehlgeschlagen.\nLogs in LocationManager: \(locationManager.debugLogs.count)\nDebug-Modus aktiv: \(locationManager.isDebugModeEnabled)"
        }
        
        showingShareSheet = true
        print("🔍 GPSDebugView: Share Sheet wird angezeigt")
    }
    
    private func startAutoRefresh() {
        guard locationManager.isDebugModeEnabled else { return }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            // UI wird automatisch durch @Published Properties des LocationManagers aktualisiert
            // Timer dient nur zur regelmäßigen Überprüfung
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let icon: String?
    let action: () -> Void
    
    init(title: String, isSelected: Bool, color: Color, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.color = color
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DebugLogRow: View {
    let log: DebugLogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: log.type.icon)
                    .foregroundColor(log.type.color)
                    .frame(width: 16)
                
                Text(log.message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(formatTime(log.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                // App-Status
                HStack(spacing: 2) {
                    Circle()
                        .fill(log.appState == "Background" ? Color.purple : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(log.appState)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Koordinaten (falls vorhanden)
                if let coord = log.coordinate {
                    Text("📍 " + String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), coord.latitude) + ", " + String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), coord.longitude))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if coord.accuracy > 0 {
                        Text("±\(String(format: "%.0f", coord.accuracy))m")
                            .font(.caption2)
                            .foregroundColor(coord.accuracy < 20 ? .green : coord.accuracy < 50 ? .orange : .red)
                    }
                }
                
                Spacer()
                
                // Akkustand
                Text("🔋\(String(format: "%.0f", log.batteryLevel * 100))%")
                    .font(.caption2)
                    .foregroundColor(log.batteryLevel > 0.2 ? .secondary : .red)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// Share Sheet für Export
struct DebugShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let locationManager = LocationManager(context: context)
    
    return GPSDebugView()
        .environmentObject(locationManager)
} 