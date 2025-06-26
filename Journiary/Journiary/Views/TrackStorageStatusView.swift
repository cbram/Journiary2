//
//  TrackStorageStatusView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import Charts

struct TrackStorageStatusView: View {
    @ObservedObject var storageManager: TrackStorageManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCompressionDetails = false
    @State private var selectedSegment: TrackSegment?
    
    init(storageManager: TrackStorageManager) {
        self.storageManager = storageManager
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Storage Statistics Header
                    storageStatisticsCard
                    
                    // Compression Progress
                    if storageManager.isCompressing {
                        compressionProgressCard
                    }
                    
                    // Recent Activity
                    recentActivitySection
                    
                    // Manual Controls
                    manualControlsSection
                }
                .padding()
            }
            .navigationTitle("Track-Speicher")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCompressionDetails) {
                CompressionDetailsView()
            }
        }
    }
    
    // MARK: - Storage Statistics
    
    private var storageStatisticsCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speicher-Effizienz")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Intelligente Komprimierung aktiviert")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingCompressionDetails = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
            
            // Storage Savings Visualization
            if storageManager.storageStatistics.totalSegments > 0 {
                HStack(spacing: 20) {
                    StatisticItem(
                        title: "Gespart",
                        value: storageManager.storageStatistics.savedSpaceFormatted,
                        icon: "arrow.down.circle.fill",
                        color: .green
                    )
                    
                    StatisticItem(
                        title: "Komprimiert",
                        value: "\(storageManager.storageStatistics.compressedSegments)/\(storageManager.storageStatistics.totalSegments)",
                        icon: "archivebox.fill",
                        color: .blue
                    )
                    
                    StatisticItem(
                        title: "Effizienz",
                        value: "\(Int((1.0 - storageManager.storageStatistics.compressionRatio) * 100))%",
                        icon: "speedometer",
                        color: .orange
                    )
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "archivebox")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("Noch keine Track-Daten")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Starten Sie eine GPS-Aufzeichnung um das intelligente Speichermanagement zu sehen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Compression Progress
    
    private var compressionProgressCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .foregroundColor(.blue)
                    .symbolEffect(.rotate, isActive: true)
                
                Text("Komprimierung läuft...")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(storageManager.compressionProgress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: storageManager.compressionProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            Text("Track-Daten werden optimiert für bessere Performance")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBlue).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Recent Activity
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Letzte Aktivität")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ActivityItem(
                    icon: "location.fill",
                    title: "Live-Tracking",
                    subtitle: "Aktuell aktiv",
                    time: "vor 2 Min",
                    color: .green
                )
                
                ActivityItem(
                    icon: "archivebox.fill",
                    title: "Segment komprimiert",
                    subtitle: "85% Speicher gespart",
                    time: "vor 1 Std",
                    color: .blue
                )
                
                ActivityItem(
                    icon: "arrow.up.circle.fill",
                    title: "Cloud-Sync",
                    subtitle: "3 Segmente synchronisiert",
                    time: "vor 2 Std",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Manual Controls
    
    private var manualControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manuelle Steuerung")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Button(action: triggerManualCompression) {
                    HStack {
                        Image(systemName: "archivebox.circle.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Sofort komprimieren")
                                .fontWeight(.medium)
                            Text("Optimiert alle verfügbaren Track-Segmente")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: showStorageSettings) {
                    HStack {
                        Image(systemName: "gear.circle.fill")
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading) {
                            Text("Speicher-Einstellungen")
                                .fontWeight(.medium)
                            Text("Komprimierung und Qualitätsstufen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Actions
    
    private func triggerManualCompression() {
        Task {
            let oldSegments = storageManager.getCompressibleSegments(olderThan: Date())
            
            for segment in oldSegments.prefix(5) { // Maximal 5 auf einmal
                _ = await storageManager.compressSegment(segment)
            }
        }
    }
    
    private func showStorageSettings() {
        // TODO: Navigation zu Speicher-Einstellungen
    }
}

// MARK: - Supporting Views

struct StatisticItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ActivityItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let time: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CompressionDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Intelligente Komprimierung")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Journiary verwendet fortschrittliche Algorithmen um Ihre GPS-Tracks zu optimieren ohne wichtige Details zu verlieren.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureItem(
                        icon: "highway",
                        title: "Autobahn-Optimierung",
                        description: "Bis zu 85% Speicherersparnis bei geraden Strecken"
                    )
                    
                    FeatureItem(
                        icon: "map",
                        title: "Stadtverkehr-Hybrid",
                        description: "Optimale Balance zwischen Genauigkeit und Speicher"
                    )
                    
                    FeatureItem(
                        icon: "figure.walk",
                        title: "Wandern-Vollauflösung",
                        description: "Erhält alle Details bei unregelmäßigen Bewegungen"
                    )
                    
                    FeatureItem(
                        icon: "cloud.fill",
                        title: "Cloud-Sync-Optimiert",
                        description: "Schnellere Synchronisation zwischen Geräten"
                    )
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Komprimierung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30, height: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    TrackStorageStatusView(storageManager: TrackStorageManager(context: PersistenceController.preview.container.viewContext))
} 