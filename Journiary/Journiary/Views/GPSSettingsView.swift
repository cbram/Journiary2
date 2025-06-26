//
//  GPSSettingsView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI

struct GPSSettingsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedAccuracy: TrackingAccuracy
    @State private var useRecommendedSettings: Bool
    @State private var customDistanceFilter: Double
    @State private var enableIntelligentPointSelection: Bool
    @State private var selectedOptimizationLevel: OptimizationLevel
    @State private var enableBackgroundTracking: Bool
    @State private var enableEnhancedBackgroundTracking: Bool
    
    enum OptimizationLevel: String, CaseIterable {
        case automatic = "Automatisch (empfohlen)"
        case conservative = "Konservativ"
        case balanced = "Ausgewogen"
        case aggressive = "Aggressiv"
        case highway = "Autobahn/Highway"
        
        var settings: TrackOptimizer.OptimizationSettings {
            switch self {
            case .automatic: return .level2 // Default-Fallback
            case .conservative: return .level1
            case .balanced: return .level2
            case .aggressive: return .level3
            case .highway: return .level5
            }
        }
        
        var description: String {
            switch self {
            case .automatic:
                return "Wählt automatisch basierend auf Geschwindigkeit (<20km/h: Konservativ, 20-50km/h: Ausgewogen, 50-80km/h: Aggressiv, >80km/h: Highway)"
            case .conservative:
                return "Hohe Genauigkeit, mehr Punkte (ideal für Wandern, <20km/h)"
            case .balanced:
                return "Gute Balance zwischen Genauigkeit und Speicher (Fahrrad, 20-50km/h)"
            case .aggressive:
                return "Weniger Punkte, geringere Genauigkeit (Auto, 50-80km/h)"
            case .highway:
                return "Minimale Punkte für sehr schnelle Fahrten (Autobahn/Zug, >80km/h)"
            }
        }
    }
    
    init(locationManager: LocationManager) {
        _selectedAccuracy = State(initialValue: locationManager.trackingAccuracy)
        _useRecommendedSettings = State(initialValue: locationManager.useRecommendedSettings)
        _customDistanceFilter = State(initialValue: locationManager.customDistanceFilter)
        _enableIntelligentPointSelection = State(initialValue: locationManager.enableIntelligentPointSelection)
        _enableBackgroundTracking = State(initialValue: locationManager.enableBackgroundTracking)
        _enableEnhancedBackgroundTracking = State(initialValue: locationManager.enableEnhancedBackgroundTracking)
        
        // Bestimme aktuelles Optimierungslevel 
        if locationManager.automaticOptimizationEnabled {
            _selectedOptimizationLevel = State(initialValue: .automatic)
        } else {
            let currentSettings = locationManager.optimizationLevel
            switch currentSettings.maxDeviation {
            case 5.0: _selectedOptimizationLevel = State(initialValue: .conservative)
            case 10.0: _selectedOptimizationLevel = State(initialValue: .balanced)
            case 20.0: _selectedOptimizationLevel = State(initialValue: .aggressive)
            case 30.0: _selectedOptimizationLevel = State(initialValue: .highway)
            default: _selectedOptimizationLevel = State(initialValue: .balanced)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GPS-Tracking-Genauigkeit")
                            .font(.headline)
                        
                        Text("Wähle die gewünschte Genauigkeit für das GPS-Tracking. Höhere Genauigkeit verbraucht mehr Batterie.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    ForEach(TrackingAccuracy.allCases, id: \.self) { accuracy in
                        AccuracyRow(
                            accuracy: accuracy,
                            isSelected: selectedAccuracy == accuracy
                        ) {
                            selectedAccuracy = accuracy
                        }
                    }
                } header: {
                    Text("Tracking-Genauigkeit")
                }
                
                Section {
                    Toggle("Empfohlene Einstellungen verwenden", isOn: $useRecommendedSettings)
                        .tint(.blue)
                    
                    if !useRecommendedSettings {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Distanzfilter")
                                Spacer()
                                Text("\(Int(customDistanceFilter)) m")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $customDistanceFilter, in: 1...500, step: 1) {
                                Text("Distanzfilter")
                            }
                            .tint(.blue)
                            
                            Text("Mindestdistanz zwischen aufgezeichneten Punkten. Niedrigere Werte = präzisere Aufzeichnung, aber höherer Batterieverbrauch.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Distanzfilter")
                } footer: {
                    if useRecommendedSettings {
                        Text("Empfohlener Filter für \(selectedAccuracy.displayName): \(Int(selectedAccuracy.recommendedDistanceFilter)) Meter")
                    }
                }
                
                Section {
                    BatteryImpactCard(accuracy: selectedAccuracy)
                } header: {
                    Text("Batterieauswirkung")
                }
                
                Section {
                    Toggle("Background-Tracking aktivieren", isOn: $enableBackgroundTracking)
                        .tint(.blue)
                    
                    if enableBackgroundTracking {
                        Toggle("Enhanced Background-Tracking", isOn: $enableEnhancedBackgroundTracking)
                            .tint(.green)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            if enableEnhancedBackgroundTracking {
                                Label {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Robustes Multi-Layer-Tracking")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text("• Visit Monitoring für Aufenthalte\n• Proximity Regions (100m) für Bewegungserkennung\n• Background Task Rotation alle 5 Min\n• Periodische Location Checks alle 10 Min\n• Automatische Service-Reaktivierung")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: "location.fill.viewfinder")
                                        .foregroundColor(.green)
                                }
                                .padding(.vertical, 4)
                            } else {
                                Label {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Standard Background-Tracking")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text("Nur Significant Location Changes (>500m Bewegung)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: "location")
                                        .foregroundColor(.blue)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } header: {
                    Text("Background-Tracking")
                } footer: {
                    if enableBackgroundTracking {
                        if enableEnhancedBackgroundTracking {
                            Text("Enhanced Modus verhindert Tracking-Lücken nach längeren Pausen durch mehrfache Redundanz. Benötigt 'Immer' Standortberechtigung für optimale Funktion.")
                        } else {
                            Text("Standard Modus nutzt nur iOS Significant Location Changes. Kann bei längeren Pausen ohne Bewegung Lücken im Tracking haben.")
                        }
                    } else {
                        Text("Tracking nur im Vordergrund aktiv. App muss geöffnet bleiben für kontinuierliche Aufzeichnung.")
                    }
                }
                
                Section {
                    Toggle("Intelligente Punkteauswahl", isOn: $enableIntelligentPointSelection)
                        .tint(.blue)
                    
                    if enableIntelligentPointSelection {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Optimierungslevel")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(OptimizationLevel.allCases, id: \.self) { level in
                                OptimizationLevelRow(
                                    level: level,
                                    isSelected: selectedOptimizationLevel == level
                                ) {
                                    selectedOptimizationLevel = level
                                    // Deaktiviere automatische Optimierung wenn manuelle Einstellung gewählt wird
                                    if level != .automatic {
                                        // Debug-Ausgabe für Troubleshooting
                                        print("🔧 Manuelle Optimierung gewählt: \(level.rawValue) - Automatik wird deaktiviert")
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Track-Optimierung")
                } footer: {
                    if enableIntelligentPointSelection {
                        Text("Die intelligente Punkteauswahl reduziert die Anzahl gespeicherter GPS-Punkte erheblich, ohne die Genauigkeit des Tracks wesentlich zu beeinträchtigen. Besonders nützlich für lange Reisen.")
                    } else {
                        Text("Deaktiviert: Alle GPS-Updates werden gespeichert (kann bei langen Reisen zu vielen Punkten führen).")
                    }
                }
                
                Section {
                    Picker("Tracking-Schutzlevel", selection: $locationManager.trackingProtectionLevel) {
                        Text("Niedrig").tag(LocationManager.TrackingProtectionLevel.low)
                        Text("Mittel").tag(LocationManager.TrackingProtectionLevel.medium)
                        Text("Hoch").tag(LocationManager.TrackingProtectionLevel.high)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        switch locationManager.trackingProtectionLevel {
                        case .low:
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Minimaler Schutz")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("Automatische Tracking-Stops sind möglich. Nur grundlegende Robustheit.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "shield")
                                    .foregroundColor(.orange)
                            }
                            
                        case .medium:
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Standard-Schutz")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("Verhindert automatische Stops bei benutzerinitiiertem Tracking. Gute Balance zwischen Schutz und Flexibilität.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "shield.lefthalf.filled")
                                    .foregroundColor(.blue)
                            }
                            
                        case .high:
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Maximaler Schutz")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("Verhindert alle automatischen Tracking-Stops. Nur manuelle Beendigung durch Benutzer möglich. Empfohlen bei Problemen mit selbstbeendenden Reisen.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "shield.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Tracking-Robustheit")
                } footer: {
                    Text("Der Schutzlevel bestimmt, wie robust das Tracking gegen ungewollte Beendigung ist. Bei Problemen mit sich selbst beendenden Reisen verwenden Sie 'Hoch'.")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsSummaryRow(
                            title: "Aktuelle Genauigkeit",
                            value: selectedAccuracy.displayName
                        )
                        
                        SettingsSummaryRow(
                            title: "Distanzfilter",
                            value: useRecommendedSettings 
                                ? "\(Int(selectedAccuracy.recommendedDistanceFilter)) m (empfohlen)"
                                : "\(Int(customDistanceFilter)) m (angepasst)"
                        )
                        
                        SettingsSummaryRow(
                            title: "Intelligente Auswahl",
                            value: enableIntelligentPointSelection ? 
                                (selectedOptimizationLevel == .automatic ? 
                                    "Automatisch (aktuell: \(locationManager.currentAutomaticOptimization))" : 
                                    "Manuell (\(selectedOptimizationLevel.rawValue))") : 
                                "Deaktiviert"
                        )
                        
                        SettingsSummaryRow(
                            title: "Batterieauswirkung",
                            value: selectedAccuracy.batteryImpact
                        )
                        
                        SettingsSummaryRow(
                            title: "Background-Tracking",
                            value: enableBackgroundTracking ? 
                                (enableEnhancedBackgroundTracking ? "Enhanced (Multi-Layer)" : "Standard (Significant Changes)") : 
                                "Deaktiviert"
                        )
                    }
                } header: {
                    Text("Zusammenfassung")
                }
            }
            .navigationTitle("GPS-Einstellungen")
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
    }
    
    private func saveSettings() {
        // Erst alle Einstellungen setzen, dann einmal speichern
        locationManager.trackingAccuracy = selectedAccuracy
        locationManager.useRecommendedSettings = useRecommendedSettings
        locationManager.customDistanceFilter = customDistanceFilter
        locationManager.enableBackgroundTracking = enableBackgroundTracking
        locationManager.enableEnhancedBackgroundTracking = enableEnhancedBackgroundTracking
        locationManager.enableIntelligentPointSelection = enableIntelligentPointSelection
        // Setze automatische Optimierung basierend auf Auswahl
        if selectedOptimizationLevel == .automatic {
            locationManager.automaticOptimizationEnabled = true
            print("🔧 Automatische Optimierung aktiviert")
        } else {
            locationManager.automaticOptimizationEnabled = false
            locationManager.optimizationLevel = selectedOptimizationLevel.settings
            print("🔧 Manuelle Optimierung gesetzt: \(selectedOptimizationLevel.rawValue)")
        }
        
        // Location Manager Einstellungen aktualisieren
        locationManager.updateLocationManagerSettings()
        
        // Einmal speichern am Ende
        locationManager.saveSettings()
    }
}

struct AccuracyRow: View {
    let accuracy: TrackingAccuracy
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(accuracy.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text("Batterieauswirkung: \(accuracy.batteryImpact)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct OptimizationLevelRow: View {
    let level: GPSSettingsView.OptimizationLevel
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.rawValue)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BatteryImpactCard: View {
    let accuracy: TrackingAccuracy
    
    private var impactColor: Color {
        switch accuracy {
        case .hundredMeters: return .yellow
        case .twoFiftyMeters: return .orange
        case .kilometer: return .green
        case .reduced: return .blue
        }
    }
    
    private var impactIcon: String {
        switch accuracy {
        case .hundredMeters: return "battery.50"
        case .twoFiftyMeters: return "battery.75"
        case .kilometer: return "battery.100"
        case .reduced: return "battery.100"
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: impactIcon)
                .foregroundColor(impactColor)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Batterieauswirkung: \(accuracy.batteryImpact)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Bei \(accuracy.displayName) Genauigkeit")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(impactColor.opacity(0.1))
        .cornerRadius(8)
    }
}

struct SettingsSummaryRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let locationManager = LocationManager(context: context)
    
    return GPSSettingsView(locationManager: locationManager)
        .environmentObject(locationManager)
} 