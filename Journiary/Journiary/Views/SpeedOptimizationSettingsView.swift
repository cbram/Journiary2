//
//  SpeedOptimizationSettingsView.swift
//  Journiary
//
//  Created by Christian Bram on 11.06.25.
//

import SwiftUI

struct SpeedOptimizationSettingsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var automaticOptimization: Bool
    @State private var selectedOptimizationLevel: OptimizationLevelType
    @State private var customSpeedThresholds = SpeedThresholds()
    @State private var showingCustomSettings = false
    
    // Predefined speed thresholds
    struct SpeedThresholds {
        var walkingMax: Double = 20.0
        var cyclingMax: Double = 35.0
        var mopedMax: Double = 60.0
        var drivingMax: Double = 87.0
        // Above drivingMax is considered highway
    }
    
    enum OptimizationLevelType: String, CaseIterable {
        case automatic = "Automatisch"
        case conservative = "Konservativ"
        case balanced = "Ausgewogen"
        case aggressive = "Aggressiv"
        case highway = "Highway"
        case custom = "Benutzerdefiniert"
        
        var description: String {
            switch self {
            case .automatic:
                return "Wählt automatisch basierend auf der Geschwindigkeit die optimale Einstellung"
            case .conservative:
                return "Hohe Genauigkeit, mehr Punkte (≤20 km/h)"
            case .balanced:
                return "Gute Balance zwischen Genauigkeit und Speicher (20-50 km/h)"
            case .aggressive:
                return "Weniger Punkte, geringere Genauigkeit (50-80 km/h)"
            case .highway:
                return "Minimale Punkte für sehr schnelle Fahrten (>80 km/h)"
            case .custom:
                return "Eigene Geschwindigkeitsbereiche definieren"
            }
        }
        
        var icon: String {
            switch self {
            case .automatic: return "gearshape.2"
            case .conservative: return "figure.walk"
            case .balanced: return "bicycle"
            case .aggressive: return "car"
            case .highway: return "road.lanes"
            case .custom: return "slider.horizontal.3"
            }
        }
        
        var optimizationSettings: TrackOptimizer.OptimizationSettings {
            switch self {
            case .automatic, .conservative: return .level1
            case .balanced: return .level2
            case .aggressive: return .level3
            case .highway: return .level5
            case .custom: return .level2 // fallback
            }
        }
    }
    
    init() {
        // Initialize with default values - will be updated in onAppear
        _automaticOptimization = State(initialValue: true)
        _selectedOptimizationLevel = State(initialValue: .automatic)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Current Status
                    currentStatusSection
                    
                    // Optimization Mode Selection
                    optimizationModeSection
                    
                    // Speed Thresholds (if automatic)
                    if automaticOptimization {
                        speedThresholdsSection
                    }
                    
                    // Manual Level Selection (if not automatic)
                    if !automaticOptimization {
                        manualLevelSection
                    }
                    
                    // Custom Settings (if custom selected)
                    if selectedOptimizationLevel == .custom {
                        customSettingsSection
                    }
                    
                    // Preview Section
                    previewSection
                }
                .padding()
            }
            .navigationTitle("Track-Optimierung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Initialize values from locationManager when view appears
            automaticOptimization = locationManager.automaticOptimizationEnabled
            
            // Load custom speed thresholds from UserDefaults (immer laden)
            customSpeedThresholds.walkingMax = UserDefaults.standard.object(forKey: "customWalkingMax") as? Double ?? 20.0
            customSpeedThresholds.cyclingMax = UserDefaults.standard.object(forKey: "customCyclingMax") as? Double ?? 35.0
            customSpeedThresholds.mopedMax = UserDefaults.standard.object(forKey: "customMopedMax") as? Double ?? 60.0
            customSpeedThresholds.drivingMax = UserDefaults.standard.object(forKey: "customDrivingMax") as? Double ?? 87.0
            
            // Load the saved optimization level first 
            if let savedLevel = UserDefaults.standard.string(forKey: "speedOptimizationLevel") {
                switch savedLevel {
                case "automatic": selectedOptimizationLevel = .automatic
                case "conservative": selectedOptimizationLevel = .conservative
                case "balanced": selectedOptimizationLevel = .balanced
                case "aggressive": selectedOptimizationLevel = .aggressive
                case "highway": selectedOptimizationLevel = .highway
                case "custom": selectedOptimizationLevel = .custom
                default: selectedOptimizationLevel = .automatic
                }
                print("🔧 Speed Optimization Level geladen: \(savedLevel)")
            } else if locationManager.automaticOptimizationEnabled {
                selectedOptimizationLevel = .automatic
            } else {
                // Map current settings to optimization level als Fallback
                switch locationManager.optimizationLevel.maxDeviation {
                case 5.0: selectedOptimizationLevel = .conservative
                case 10.0: selectedOptimizationLevel = .balanced
                case 20.0: selectedOptimizationLevel = .aggressive
                case 30.0: selectedOptimizationLevel = .highway
                default: selectedOptimizationLevel = .balanced
                }
            }
            
            print("🔧 Speed Thresholds geladen - Walking: \(customSpeedThresholds.walkingMax), Cycling: \(customSpeedThresholds.cyclingMax), Moped: \(customSpeedThresholds.mopedMax), Driving: \(customSpeedThresholds.drivingMax)")
        }
        .sheet(isPresented: $showingCustomSettings) {
            SpeedThresholdCustomizationView(speedThresholds: $customSpeedThresholds)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "speedometer")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Geschwindigkeitsbasierte Track-Optimierung")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Passe die GPS-Punkteaufzeichnung basierend auf deiner Geschwindigkeit an, um die optimale Balance zwischen Genauigkeit und Speicherplatz zu finden.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var currentStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aktueller Status")
                .font(.headline)
            
            HStack {
                Image(systemName: automaticOptimization ? "gearshape.2.fill" : "hand.raised.fill")
                    .foregroundColor(automaticOptimization ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(automaticOptimization ? "Automatische Optimierung" : "Manuelle Einstellung")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(automaticOptimization ? 
                         "Aktuell: \(locationManager.currentAutomaticOptimization)" :
                         selectedOptimizationLevel.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private var optimizationModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Optimierungsmodus")
                .font(.headline)
            
            VStack(spacing: 12) {
                Toggle("Automatische Geschwindigkeitsoptimierung", isOn: $automaticOptimization)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                if automaticOptimization {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Intelligente Anpassung")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Die App wählt automatisch die beste Einstellung basierend auf deiner aktuellen Geschwindigkeit.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
    }
    
    private var speedThresholdsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Geschwindigkeitsbereiche")
                .font(.headline)
            
            VStack(spacing: 16) {
                SpeedThresholdRow(
                    icon: "1.circle.fill",
                    title: "Lvl 1",
                    range: "0 - \(Int(customSpeedThresholds.walkingMax)) km/h",
                    optimization: "Sehr hoch",
                    color: .green
                )
                SpeedThresholdRow(
                    icon: "2.circle.fill",
                    title: "Lvl 2",
                    range: "\(Int(customSpeedThresholds.walkingMax)) - \(Int(customSpeedThresholds.cyclingMax)) km/h",
                    optimization: "Hoch",
                    color: .blue
                )
                SpeedThresholdRow(
                    icon: "3.circle.fill",
                    title: "Lvl 3",
                    range: "\(Int(customSpeedThresholds.cyclingMax)) - \(Int(customSpeedThresholds.mopedMax)) km/h",
                    optimization: "Mittel",
                    color: .orange
                )
                SpeedThresholdRow(
                    icon: "4.circle.fill",
                    title: "Lvl 4",
                    range: "\(Int(customSpeedThresholds.mopedMax)) - \(Int(customSpeedThresholds.drivingMax)) km/h",
                    optimization: "Niedrig",
                    color: .purple
                )
                SpeedThresholdRow(
                    icon: "5.circle.fill",
                    title: "Lvl 5",
                    range: "> \(Int(customSpeedThresholds.drivingMax)) km/h",
                    optimization: "Minimal",
                    color: .red
                )
            }
            
            Button(action: {
                showingCustomSettings.toggle()
            }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.blue)
                    
                    Text("Geschwindigkeitsbereiche anpassen")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var manualLevelSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manuelle Optimierungsstufe")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(OptimizationLevelType.allCases.filter { $0 != .automatic }, id: \.self) { level in
                    OptimizationLevelButton(
                        level: level,
                        isSelected: selectedOptimizationLevel == level
                    ) {
                        selectedOptimizationLevel = level
                    }
                }
            }
        }
    }
    
    private var customSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Benutzerdefinierte Einstellungen")
                .font(.headline)
            
            VStack(spacing: 12) {
                SpeedRangeSlider(
                    title: "Zu Fuß Obergrenze",
                    value: $customSpeedThresholds.walkingMax,
                    range: 5...30,
                    unit: "km/h"
                )
                
                SpeedRangeSlider(
                    title: "Fahrrad Obergrenze",
                    value: $customSpeedThresholds.cyclingMax,
                    range: 25...70,
                    unit: "km/h"
                )
                
                SpeedRangeSlider(
                    title: "Roller/Moped Obergrenze",
                    value: $customSpeedThresholds.mopedMax,
                    range: 35...90,
                    unit: "km/h"
                )
                
                SpeedRangeSlider(
                    title: "Auto Obergrenze",
                    value: $customSpeedThresholds.drivingMax,
                    range: 60...120,
                    unit: "km/h"
                )
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vorschau der Einstellungen")
                .font(.headline)
            
            let settings = getPreviewSettings()
            
            VStack(spacing: 8) {
                PreviewRow(title: "Max. Abweichung", value: "\(Int(settings.maxDeviation)) m")
                PreviewRow(title: "Min. Distanz", value: "\(Int(settings.minDistance)) m")
                PreviewRow(title: "Max. Distanz", value: "\(Int(settings.maxDistance)) m")
                PreviewRow(title: "Winkel-Threshold", value: "\(Int(settings.angleThreshold))°")
                PreviewRow(title: "Min. Zeitintervall", value: "\(Int(settings.minTimeInterval)) s")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    private func getPreviewSettings() -> TrackOptimizer.OptimizationSettings {
        if automaticOptimization {
            return .level2 // Show level2 as example for automatic
        } else {
            return selectedOptimizationLevel.optimizationSettings
        }
    }
    
    private func saveSettings() {
        // Erst alle Einstellungen setzen
        locationManager.automaticOptimizationEnabled = automaticOptimization
        
        if !automaticOptimization {
            locationManager.optimizationLevel = selectedOptimizationLevel.optimizationSettings
        }
        
        // Speichere das gewählte Speed Optimization Level
        UserDefaults.standard.set(selectedOptimizationLevel.rawValue.lowercased(), forKey: "speedOptimizationLevel")
        
        // Speichere custom speed thresholds immer (auch wenn nicht custom, für zukünftige Verwendung)
        UserDefaults.standard.set(customSpeedThresholds.walkingMax, forKey: "customWalkingMax")
        UserDefaults.standard.set(customSpeedThresholds.cyclingMax, forKey: "customCyclingMax")
        UserDefaults.standard.set(customSpeedThresholds.mopedMax, forKey: "customMopedMax")
        UserDefaults.standard.set(customSpeedThresholds.drivingMax, forKey: "customDrivingMax")
        
        print("🔧 Speed Settings gespeichert - Level: \(selectedOptimizationLevel.rawValue), Automatic: \(automaticOptimization)")
        print("🔧 Speed Thresholds gespeichert - Walking: \(customSpeedThresholds.walkingMax), Cycling: \(customSpeedThresholds.cyclingMax), Moped: \(customSpeedThresholds.mopedMax), Driving: \(customSpeedThresholds.drivingMax)")
        
        // Einmal speichern am Ende
        locationManager.saveSettings()
    }
}

// MARK: - Supporting Views

struct SpeedThresholdRow: View {
    let icon: String
    let title: String
    let range: String
    let optimization: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(range)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(optimization)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.2))
                .cornerRadius(6)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct OptimizationLevelButton: View {
    let level: SpeedOptimizationSettingsView.OptimizationLevelType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: level.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SpeedRangeSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(value)) \(unit)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range, step: 1) {
                Text(title)
            }
            .tint(.blue)
        }
    }
}

struct PreviewRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Speed Threshold Customization View

struct SpeedThresholdCustomizationView: View {
    @Binding var speedThresholds: SpeedOptimizationSettingsView.SpeedThresholds
    @Environment(\.dismiss) private var dismiss
    
    @State private var localThresholds: SpeedOptimizationSettingsView.SpeedThresholds
    
    init(speedThresholds: Binding<SpeedOptimizationSettingsView.SpeedThresholds>) {
        self._speedThresholds = speedThresholds
        self._localThresholds = State(initialValue: speedThresholds.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(spacing: 16) {
                        Text("Passe die Geschwindigkeitsbereiche für die automatische Optimierung an. Diese Werte bestimmen, ab welchen Geschwindigkeiten unterschiedliche Optimierungseinstellungen verwendet werden.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        Image(systemName: "speedometer")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Geschwindigkeitsbereiche")
                }
                
                Section {
                    SpeedThresholdSlider(
                        title: "Zu Fuß (Lvl 1)",
                        subtitle: "0 - \(Int(localThresholds.walkingMax)) km/h",
                        value: $localThresholds.walkingMax,
                        range: 5...30,
                        color: .green,
                        icon: "figure.walk"
                    )
                    SpeedThresholdSlider(
                        title: "Fahrrad (Lvl 2)",
                        subtitle: "\(Int(localThresholds.walkingMax)) - \(Int(localThresholds.cyclingMax)) km/h",
                        value: $localThresholds.cyclingMax,
                        range: max(25, localThresholds.walkingMax + 5)...70,
                        color: .blue,
                        icon: "bicycle"
                    )
                    SpeedThresholdSlider(
                        title: "Roller/Moped (Lvl 3)",
                        subtitle: "\(Int(localThresholds.cyclingMax)) - \(Int(localThresholds.mopedMax)) km/h",
                        value: $localThresholds.mopedMax,
                        range: max(35, localThresholds.cyclingMax + 5)...90,
                        color: .orange,
                        icon: "scooter"
                    )
                    SpeedThresholdSlider(
                        title: "Auto (Lvl 4)",
                        subtitle: "\(Int(localThresholds.mopedMax)) - \(Int(localThresholds.drivingMax)) km/h",
                        value: $localThresholds.drivingMax,
                        range: max(60, localThresholds.mopedMax + 5)...120,
                        color: .purple,
                        icon: "car"
                    )
                    HStack {
                        Image(systemName: "road.lanes")
                            .foregroundColor(.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Autobahn (Lvl 5)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("> \(Int(localThresholds.drivingMax)) km/h")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("Lvl 5")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(6)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Bereiche")
                } footer: {
                    Text("Die Werte müssen aufsteigend sein: Zu Fuß < Fahrrad < Roller/Moped < Auto. Die Autobahn-Einstellung greift automatisch bei Geschwindigkeiten über der Auto-Obergrenze.")
                }
                
                Section {
                    Button("Standard wiederherstellen") {
                        localThresholds = SpeedOptimizationSettingsView.SpeedThresholds()
                    }
                    .foregroundColor(.blue)
                } footer: {
                    Text("Setzt die Werte auf die Standardeinstellungen zurück: Zu Fuß 20 km/h, Fahrrad 35 km/h, Auto 87 km/h")
                }
            }
            .navigationTitle("Geschwindigkeitsbereiche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        speedThresholds = localThresholds
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct SpeedThresholdSlider: View {
    let title: String
    let subtitle: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(Int(value)) km/h")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            Slider(value: $value, in: range, step: 1) {
                Text(title)
            }
            .tint(color)
        }
        .padding(.vertical, 4)
    }
} 