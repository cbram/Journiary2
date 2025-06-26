//
//  TracesTrackSettingsView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI

struct TracesTrackSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKey: String = ""
    @State private var showingAPIKeyHelp = false
    @State private var showingLicenseInfo = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("TracesTrack Karten")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TracesTrack bietet hochwertige topografische Karten basierend auf OpenStreetMap-Daten.")
                            .font(.body)
                        
                        Text("Alle TracesTrack-Features erfordern eine kostenlose Registrierung und einen API-Schlüssel.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Features")) {
                    ForEach(TracesTrackConfig.Feature.allCases, id: \.self) { feature in
                        HStack {
                            Image(systemName: feature.isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundColor(feature.isAvailable ? .green : .orange)
                            
                            Text(feature.description)
                                .font(.body)
                            
                            Spacer()
                            
                            if !feature.isAvailable {
                                Text("API Key erforderlich")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                Section(header: Text("API-Schlüssel (Erforderlich)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SecureField("API-Schlüssel eingeben...", text: $apiKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("Hilfe") {
                                showingAPIKeyHelp = true
                            }
                            .font(.caption)
                        }
                        
                        HStack {
                            Button("Speichern") {
                                TracesTrackConfig.setAPIKey(apiKey.isEmpty ? nil : apiKey)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(apiKey.isEmpty)
                            
                            Button("Löschen") {
                                TracesTrackConfig.setAPIKey(nil)
                                apiKey = ""
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            
                            Spacer()
                            
                            if TracesTrackConfig.hasAPIKey {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Aktiv")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Information")) {
                    Button("Lizenz & Attribution") {
                        showingLicenseInfo = true
                    }
                    
                    Link("TracesTrack Website", destination: URL(string: "https://www.tracestrack.com/")!)
                    
                    Link("OpenStreetMap Copyright", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                }
            }
            .navigationTitle("TracesTrack")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAPIKeyHelp) {
            APIKeyHelpView()
        }
        .sheet(isPresented: $showingLicenseInfo) {
            LicenseInfoView()
        }
        .onAppear {
            // Lade aktuellen API Key (verschleiert)
            if TracesTrackConfig.hasAPIKey {
                apiKey = "••••••••••••"
            }
        }
    }
}

struct APIKeyHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("TracesTrack API-Schlüssel")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Um TracesTrack-Karten zu nutzen, benötigen Sie einen kostenlosen API-Schlüssel von TracesTrack.")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("So erhalten Sie einen API-Schlüssel:")
                            .fontWeight(.semibold)
                        
                        Text("1. Besuchen Sie https://www.tracestrack.com/")
                        Text("2. Registrieren Sie sich für ein Konto")
                        Text("3. Wählen Sie einen passenden Plan")
                        Text("4. Kopieren Sie Ihren API-Schlüssel")
                        Text("5. Fügen Sie ihn hier ein")
                    }
                    
                    Text("Preise:")
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Intro: Kostenlos (100K Kacheln/Monat)")
                        Text("• Standard: €29/Monat (1M Kacheln + Vector-Karten)")
                        Text("• Standard Plus: €59/Monat (4M Kacheln + Alle Features)")
                    }
                    .font(.caption)
                    
                    Text("Auch der kostenlose Plan bietet Zugang zu Topo-Karten mit begrenztem Volumen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("API-Schlüssel Hilfe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LicenseInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Lizenz & Attribution")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(TracesTrackConfig.licenseInfo)
                    
                    Text("Wichtige Informationen:")
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• OpenStreetMap-Daten sind unter der Open Database License (ODbL) verfügbar")
                        Text("• TracesTrack stellt die Kartenstile und Server-Infrastruktur bereit")
                        Text("• Bei Nutzung der Karten muss die entsprechende Attribution angezeigt werden")
                        Text("• Die Nutzung erfolgt gemäß den TracesTrack Nutzungsbedingungen")
                    }
                    .font(.caption)
                    
                    Text("Diese App zeigt die erforderliche Attribution automatisch an, wenn TracesTrack-Karten verwendet werden.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Lizenz Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TracesTrackSettingsView()
} 