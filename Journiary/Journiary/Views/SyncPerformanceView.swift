import SwiftUI

/// View zur Anzeige von Performance-Metriken der Sync-Operationen
struct SyncPerformanceView: View {
    @State private var refreshTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @State private var performanceMetrics: [SyncPerformanceMetrics] = []
    
    var body: some View {
        NavigationView {
            List {
                if performanceMetrics.isEmpty {
                    Section("Sync Performance") {
                        HStack {
                            Image(systemName: "chart.bar")
                                .foregroundColor(.blue)
                            Text("Keine Performance-Daten verfügbar")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    Section("Letzte Sync-Operationen") {
                        ForEach(performanceMetrics.indices, id: \.self) { index in
                            let metric = performanceMetrics[index]
                            PerformanceMetricRow(metric: metric)
                        }
                    }
                    
                    Section("Statistiken") {
                        if let averageDuration = averageDuration {
                            StatisticRow(
                                title: "Durchschnittliche Sync-Dauer",
                                value: String(format: "%.2f s", averageDuration),
                                icon: "clock"
                            )
                        }
                        
                        if let averageThroughput = averageThroughput {
                            StatisticRow(
                                title: "Durchschnittlicher Durchsatz",
                                value: String(format: "%.1f Entitäten/s", averageThroughput),
                                icon: "speedometer"
                            )
                        }
                        
                        if let peakMemory = peakMemoryUsage {
                            StatisticRow(
                                title: "Höchster Speicherverbrauch",
                                value: formatBytes(peakMemory),
                                icon: "memorychip"
                            )
                        }
                    }
                }
            }
            .navigationTitle("Sync Performance")
            .refreshable {
                loadPerformanceMetrics()
            }
            .onReceive(refreshTimer) { _ in
                loadPerformanceMetrics()
            }
            .onAppear {
                loadPerformanceMetrics()
            }
        }
    }
    
    private func loadPerformanceMetrics() {
        performanceMetrics = PerformanceMonitor.shared.getAllMetrics()
    }
    
    private var averageDuration: Double? {
        guard !performanceMetrics.isEmpty else { return nil }
        let totalDuration = performanceMetrics.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(performanceMetrics.count)
    }
    
    private var averageThroughput: Double? {
        guard !performanceMetrics.isEmpty else { return nil }
        let totalThroughput = performanceMetrics.reduce(0) { $0 + $1.throughput }
        return totalThroughput / Double(performanceMetrics.count)
    }
    
    private var peakMemoryUsage: UInt64? {
        guard !performanceMetrics.isEmpty else { return nil }
        return performanceMetrics.map { $0.memoryUsage }.max()
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

/// Row-View für eine einzelne Performance-Metrik
struct PerformanceMetricRow: View {
    let metric: SyncPerformanceMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(metric.operation)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(timeAgo(from: metric.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dauer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f s", metric.duration))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text("Entitäten")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(metric.entityCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Durchsatz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f/s", metric.throughput))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            if metric.networkBytesTransferred > 0 {
                HStack {
                    Text("Netzwerk:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatBytes(metric.networkBytesTransferred))
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("(\(String(format: "%.1f KB/s", metric.bytesPerSecond / 1024)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "vor \(Int(interval))s"
        } else if interval < 3600 {
            return "vor \(Int(interval/60))m"
        } else if interval < 86400 {
            return "vor \(Int(interval/3600))h"
        } else {
            return "vor \(Int(interval/86400))d"
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

/// Row-View für Statistiken
struct StatisticRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SyncPerformanceView()
} 