import SwiftUI

struct SyncDebugDashboard: View {
    @StateObject private var viewModel = SyncDebugViewModel()
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Debug-Kategorie", selection: $selectedTab) {
                    Text("Status").tag(0)
                    Text("Logs").tag(1)
                    Text("Performance").tag(2)
                    Text("Queue").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                TabView(selection: $selectedTab) {
                    SyncStatusView()
                        .tag(0)
                    
                    SyncLogsView(viewModel: viewModel)
                        .tag(1)
                    
                    PerformanceView(viewModel: viewModel)
                        .tag(2)
                    
                    QueueStatusView(viewModel: viewModel)
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Sync Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.loadData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                viewModel.loadData()
            }
        }
    }
}

// Verwende die existierende SyncStatusView aus der separaten Datei

struct SyncLogsView: View {
    @ObservedObject var viewModel: SyncDebugViewModel
    @State private var showingShareSheet = false
    @State private var logExportText = ""
    
    var body: some View {
        VStack {
            HStack {
                Picker("Log Level", selection: $viewModel.selectedLogLevel) {
                    Text("Alle").tag(Optional<SyncLogger.LogLevel>.none)
                    ForEach(SyncLogger.LogLevel.allCases, id: \.rawValue) { level in
                        Text(level.rawValue).tag(Optional(level))
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: viewModel.selectedLogLevel) { _, _ in
                    viewModel.loadLogs()
                }
                
                Spacer()
                
                Button("Export") {
                    logExportText = viewModel.exportLogs()
                    showingShareSheet = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            
            if viewModel.filteredLogs.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Keine Logs verfügbar")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Starte eine Synchronisation, um Logs zu sehen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(viewModel.filteredLogs, id: \.timestamp) { log in
                    SyncLogRow(log: log)
                }
                .listStyle(PlainListStyle())
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [logExportText])
        }
        .refreshable {
            viewModel.loadLogs()
        }
    }
}

struct SyncLogRow: View {
    let log: SyncLogger.LogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.level.emoji)
                    .font(.caption)
                Text(log.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                Spacer()
                Text(log.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(log.message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(logTextColor)
            
            if !log.metadata.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatMetadata(log.metadata))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var logTextColor: Color {
        switch log.level {
        case .error, .critical:
            return .red
        case .warning:
            return .orange
        case .info:
            return .primary
        case .debug:
            return .secondary
        }
    }
    
    private func formatMetadata(_ metadata: [String: Any]) -> String {
        return metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}

struct PerformanceView: View {
    @ObservedObject var viewModel: SyncDebugViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Performance-Übersicht
                VStack(alignment: .leading, spacing: 12) {
                    Text("Performance-Übersicht")
                        .font(.headline)
                    
                    HStack {
                        MetricCard(
                            title: "Durchschnittliche Sync-Zeit",
                            value: viewModel.averageSyncTime,
                            unit: "s",
                            color: .blue
                        )
                        MetricCard(
                            title: "Erfolgsrate",
                            value: String(format: "%.1f", viewModel.successRate * 100),
                            unit: "%",
                            color: viewModel.successRate > 0.9 ? .green : .orange
                        )
                    }
                    
                    HStack {
                        MetricCard(
                            title: "Entitäten/Sekunde",
                            value: String(format: "%.1f", viewModel.throughput),
                            unit: "e/s",
                            color: .purple
                        )
                        MetricCard(
                            title: "Netzwerk-Bytes",
                            value: viewModel.formattedNetworkBytes,
                            unit: "",
                            color: .cyan
                        )
                    }
                }
                .padding()
                
                // Entitäten-Performance
                VStack(alignment: .leading, spacing: 12) {
                    Text("Performance nach Entitäten")
                        .font(.headline)
                    
                    ForEach(viewModel.entityPerformance, id: \.entityType) { performance in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(performance.entityType)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(String(format: "%.2f", performance.avgDuration))s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                ProgressView(value: performance.relativePerformance)
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .scaleEffect(y: 0.6)
                                
                                Text(performance.status)
                                    .font(.caption2)
                                    .foregroundColor(performance.statusColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Letzte Sync-Operationen
                VStack(alignment: .leading, spacing: 12) {
                    Text("Letzte Sync-Operationen")
                        .font(.headline)
                    
                    ForEach(viewModel.recentSyncOperations, id: \.id) { operation in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(operation.type)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(operation.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(operation.entityCount) entities")
                                    .font(.caption)
                                Text("\(String(format: "%.2f", operation.duration))s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Circle()
                                .fill(operation.success ? .green : .red)
                                .frame(width: 8, height: 8)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .refreshable {
            viewModel.loadPerformanceData()
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct QueueStatusView: View {
    @ObservedObject var viewModel: SyncDebugViewModel
    
    var body: some View {
        List {
            Section("Warteschlangen-Status") {
                HStack {
                    Text("Pending Uploads")
                    Spacer()
                    Text("\(viewModel.pendingUploads)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(6)
                }
                
                HStack {
                    Text("Pending Downloads")
                    Spacer()
                    Text("\(viewModel.pendingDownloads)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(6)
                }
                
                HStack {
                    Text("Fehlgeschlagene Operationen")
                    Spacer()
                    Text("\(viewModel.failedOperations)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            
            Section("Warteschlangen-Operationen") {
                ForEach(viewModel.queueOperations, id: \.id) { operation in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(operation.type)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(operation.status)
                                .font(.caption)
                                .foregroundColor(operation.statusColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(operation.statusColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Text(operation.entityType)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(operation.timestamp, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let error = operation.error {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .refreshable {
            viewModel.loadQueueData()
        }
    }
}

// ShareSheet für Export
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SyncDebugDashboard()
} 