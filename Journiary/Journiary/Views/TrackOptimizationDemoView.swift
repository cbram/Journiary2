//
//  TrackOptimizationDemoView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import CoreLocation

struct TrackOptimizationDemoView: View {
    @State private var selectedLevel: TrackOptimizer.OptimizationSettings = .level2
    @State private var demoPoints: [CLLocation] = []
    @State private var optimizedPoints: [CLLocation] = []
    @State private var showingResults = false
    
    private let levelOptions: [(String, TrackOptimizer.OptimizationSettings)] = [
        ("Zu Fuß (Lvl 1)", .level1),
        ("Fahrrad (Lvl 2)", .level2),
        ("Roller/Moped (Lvl 3)", .level3),
        ("Auto (Lvl 4)", .level4),
        ("Autobahn (Lvl 5)", .level5)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Track-Optimierung Demo")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Sieh dir an, wie die intelligente Punkteauswahl funktioniert")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Optimierungslevel auswählen
                VStack(spacing: 12) {
                    Text("Optimierungslevel")
                        .font(.headline)
                    
                    ForEach(levelOptions, id: \.0) { name, settings in
                        Button(action: {
                            selectedLevel = settings
                        }) {
                            HStack {
                                Text(name)
                                    .font(.body)
                                Spacer()
                                if selectedLevel.maxDeviation == settings.maxDeviation {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedLevel.maxDeviation == settings.maxDeviation ? 
                                          Color.blue.opacity(0.1) : 
                                          Color.gray.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
                
                // Einstellungen anzeigen
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aktuelle Einstellungen")
                        .font(.headline)
                    
                    SettingRow(title: "Max. Abweichung", value: "\(Int(selectedLevel.maxDeviation))m")
                    SettingRow(title: "Min. Distanz", value: "\(Int(selectedLevel.minDistance))m")
                    SettingRow(title: "Max. Distanz", value: "\(Int(selectedLevel.maxDistance))m")
                    SettingRow(title: "Winkel-Threshold", value: "\(Int(selectedLevel.angleThreshold))°")
                    SettingRow(title: "Min. Zeitintervall", value: "\(Int(selectedLevel.minTimeInterval))s")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
                
                // Demo-Buttons
                VStack(spacing: 12) {
                    Button(action: generateDemoTrack) {
                        Text("Demo-Track generieren")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    if !demoPoints.isEmpty {
                        Button(action: runOptimization) {
                            Text("Optimierung durchführen")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Ergebnisse
                if showingResults {
                    VStack(spacing: 8) {
                        Text("Ergebnisse")
                            .font(.headline)
                        
                        HStack {
                            VStack {
                                Text("\(demoPoints.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Original")
                                    .font(.caption)
                            }
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                            
                            VStack {
                                Text("\(optimizedPoints.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                Text("Optimiert")
                                    .font(.caption)
                            }
                            
                            VStack {
                                Text("\(String(format: "%.1f", reductionPercentage))%")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                Text("Reduzierung")
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var reductionPercentage: Double {
        guard demoPoints.count > 0 else { return 0 }
        let saved = demoPoints.count - optimizedPoints.count
        return Double(saved) / Double(demoPoints.count) * 100.0
    }
    
    private func generateDemoTrack() {
        // Generiere einen Beispiel-Track (simulierte Fahrradtour)
        var points: [CLLocation] = []
        let startLat = 52.5200
        let startLon = 13.4050
        let totalPoints = 500 // Simuliert eine längere Tour
        
        for i in 0..<totalPoints {
            let progress = Double(i) / Double(totalPoints)
            
            // Simuliere eine kurvenreiche Route mit geraden Abschnitten
            let noise = sin(progress * 20) * 0.001 + (Double.random(in: -0.0005...0.0005))
            let lat = startLat + progress * 0.05 + noise
            let lon = startLon + progress * 0.03 + sin(progress * 15) * 0.002
            
            let timestamp = Date().addingTimeInterval(TimeInterval(i * 10)) // Alle 10 Sekunden
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                altitude: 100 + sin(progress * 10) * 50, // Simulierte Höhenänderungen
                horizontalAccuracy: 5.0,
                verticalAccuracy: 10.0,
                timestamp: timestamp
            )
            
            points.append(location)
        }
        
        demoPoints = points
        optimizedPoints = []
        showingResults = false
        
        print("📍 Demo-Track generiert: \(points.count) Punkte")
    }
    
    private func runOptimization() {
        guard !demoPoints.isEmpty else { return }
        
        // Führe Douglas-Peucker Optimierung durch
        let optimized = TrackOptimizer.douglasPeucker(
            points: demoPoints,
            epsilon: selectedLevel.maxDeviation
        )
        
        optimizedPoints = optimized
        showingResults = true
        
        let reduction = reductionPercentage
        print("🎯 Optimierung abgeschlossen:")
        print("   Original: \(demoPoints.count) Punkte")
        print("   Optimiert: \(optimized.count) Punkte")
        print("   Reduzierung: \(String(format: "%.1f", reduction))%")
        
        // Haptic Feedback
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)
    }
}

struct SettingRow: View {
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
                .foregroundColor(.blue)
        }
    }
}

#Preview {
    TrackOptimizationDemoView()
} 