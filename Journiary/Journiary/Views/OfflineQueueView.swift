//
//  OfflineQueueView.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import SwiftUI
import CoreData

struct OfflineQueueView: View {
    @ObservedObject private var offlineQueue = OfflineQueue.shared
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isProcessing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if offlineQueue.operations.isEmpty {
                    emptyQueueView
                } else {
                    queueListView
                }
            }
            .navigationTitle("Offline-Warteschlange")
            .navigationBarItems(
                leading: Button("Schließen") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: HStack {
                    if !offlineQueue.operations.isEmpty {
                        Button(action: processQueue) {
                            HStack {
                                Text("Verarbeiten")
                                Image(systemName: "arrow.up.arrow.down")
                            }
                        }
                        .disabled(isProcessing || offlineQueue.isProcessing)
                    }
                }
            )
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Warteschlange"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private var emptyQueueView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Keine ausstehenden Operationen")
                .font(.headline)
            
            Text("Alle Änderungen wurden mit dem Server synchronisiert.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var queueListView: some View {
        VStack {
            List {
                Section(header: Text("Ausstehende Operationen")) {
                    ForEach(offlineQueue.operations) { operation in
                        OfflineOperationRow(operation: operation)
                            .swipeActions {
                                Button(role: .destructive) {
                                    offlineQueue.removeOperation(operationId: operation.id)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Hinweis:")
                    .font(.headline)
                
                Text("Die Operationen werden automatisch verarbeitet, sobald eine Verbindung zum Server hergestellt wird. Sie können die Operationen auch manuell verarbeiten oder einzelne Operationen löschen.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private func processQueue() {
        isProcessing = true
        
        offlineQueue.processQueue(context: viewContext) { success in
            isProcessing = false
            
            if success {
                if offlineQueue.operations.isEmpty {
                    alertMessage = "Alle Operationen wurden erfolgreich verarbeitet."
                } else {
                    alertMessage = "Einige Operationen konnten nicht verarbeitet werden. Bitte überprüfen Sie Ihre Internetverbindung und versuchen Sie es später erneut."
                }
            } else {
                alertMessage = "Bei der Verarbeitung der Operationen ist ein Fehler aufgetreten. Bitte überprüfen Sie Ihre Internetverbindung und versuchen Sie es später erneut."
            }
            
            showAlert = true
        }
    }
}

struct OfflineOperationRow: View {
    let operation: OfflineOperation
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entityTypeDisplayName)
                    .font(.headline)
                
                Text(operationTypeDisplayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if operation.priority > 0 {
                    Text("Priorität: \(operation.priority)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var entityTypeDisplayName: String {
        switch operation.entityType {
        case .trip:
            return "Reise"
        case .memory:
            return "Erinnerung"
        case .mediaItem:
            return "Medien"
        case .tag:
            return "Tag"
        case .tagCategory:
            return "Tag-Kategorie"
        case .bucketListItem:
            return "Bucket-List-Eintrag"
        }
    }
    
    private var operationTypeDisplayName: String {
        switch operation.operationType {
        case .create:
            return "Erstellen"
        case .update:
            return "Aktualisieren"
        case .delete:
            return "Löschen"
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: operation.createdAt)
    }
}

struct OfflineQueueView_Previews: PreviewProvider {
    static var previews: some View {
        OfflineQueueView()
    }
} 