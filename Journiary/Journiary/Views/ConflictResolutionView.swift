//
//  ConflictResolutionView.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import SwiftUI
import CoreData

struct ConflictResolutionView: View {
    @ObservedObject private var conflictResolver = ConflictResolver.shared
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedStrategy: ConflictResolutionStrategy
    
    init() {
        _selectedStrategy = State(initialValue: ConflictResolver.shared.resolutionStrategy)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if conflictResolver.conflicts.isEmpty {
                    noConflictsView
                } else {
                    conflictsListView
                }
                
                strategySelectorView
            }
            .padding()
            .navigationTitle("Konflikte")
            .navigationBarItems(trailing: Button("Schließen") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private var noConflictsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Keine Konflikte vorhanden")
                .font(.headline)
            
            Text("Alle Daten sind synchronisiert und konfliktfrei.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var conflictsListView: some View {
        List {
            ForEach(conflictResolver.conflicts, id: \.entityId) { conflict in
                ConflictItemView(conflict: conflict)
            }
        }
    }
    
    private var strategySelectorView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Konfliktstrategie:")
                .font(.headline)
            
            Picker("Strategie", selection: $selectedStrategy) {
                Text("Lokale Daten bevorzugen").tag(ConflictResolutionStrategy.localWins)
                Text("Remote-Daten bevorzugen").tag(ConflictResolutionStrategy.remoteWins)
                Text("Neuere Daten bevorzugen").tag(ConflictResolutionStrategy.newerWins)
                Text("Manuell auflösen").tag(ConflictResolutionStrategy.manual)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedStrategy) { newValue in
                conflictResolver.setResolutionStrategy(newValue)
            }
            
            Text("Hinweis: Bei automatischen Strategien werden neue Konflikte automatisch nach der gewählten Strategie aufgelöst.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(10)
    }
}

struct ConflictItemView: View {
    let conflict: Conflict
    @ObservedObject private var conflictResolver = ConflictResolver.shared
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(entityTypeDisplayName)
                        .font(.headline)
                    
                    Text("Geändert: \(formattedDates)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.blue)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }
            
            if isExpanded {
                conflictDetailsView
            }
        }
        .padding(.vertical, 8)
    }
    
    private var entityTypeDisplayName: String {
        switch conflict.entityType {
        case "Trip":
            return "Reise"
        case "Memory":
            return "Erinnerung"
        case "MediaItem":
            return "Medien"
        case "Tag":
            return "Tag"
        case "BucketListItem":
            return "Bucket-List-Eintrag"
        default:
            return conflict.entityType
        }
    }
    
    private var formattedDates: String {
        let localDateStr = DateFormatter.localizedString(from: conflict.localVersion, dateStyle: .short, timeStyle: .short)
        let remoteDateStr = DateFormatter.localizedString(from: conflict.remoteVersion, dateStyle: .short, timeStyle: .short)
        return "Lokal: \(localDateStr), Remote: \(remoteDateStr)"
    }
    
    private var conflictDetailsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            Text("Konfliktdetails:")
                .font(.subheadline)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("ID: \(conflict.entityId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Konflikttyp: \(conflictTypeString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            HStack {
                Button(action: {
                    resolveConflict(useLocalData: true)
                }) {
                    Text("Lokale Version")
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    resolveConflict(useLocalData: false)
                }) {
                    Text("Remote-Version")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.top, 8)
    }
    
    private var conflictTypeString: String {
        switch conflict.conflictType {
        case .create:
            return "Erstellung"
        case .update:
            return "Aktualisierung"
        case .delete:
            return "Löschung"
        }
    }
    
    private func resolveConflict(useLocalData: Bool) {
        guard let resolvedData = conflictResolver.resolveManually(conflictId: conflict.entityId, useLocalData: useLocalData) else {
            return
        }
        
        // Hier würden wir die Daten in Core Data aktualisieren
        // Dies ist eine vereinfachte Version, die tatsächliche Implementierung
        // würde die spezifische Entität finden und aktualisieren
        
        // Beispiel für eine allgemeine Aktualisierung:
        let fetchRequest: NSFetchRequest<NSFetchRequestResult>
        
        switch conflict.entityType {
        case "Trip":
            fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        case "Memory":
            fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Memory")
        case "MediaItem":
            fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "MediaItem")
        case "Tag":
            fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Tag")
        case "BucketListItem":
            fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "BucketListItem")
        default:
            return
        }
        
        fetchRequest.predicate = NSPredicate(format: "id == %@", UUID(uuidString: conflict.entityId)! as CVarArg)
        
        do {
            if let entity = try viewContext.fetch(fetchRequest).first as? NSManagedObject {
                entity.update(with: resolvedData)
                try viewContext.save()
            }
        } catch {
            print("Fehler beim Aktualisieren der Entität: \(error)")
        }
    }
}

struct ConflictResolutionView_Previews: PreviewProvider {
    static var previews: some View {
        ConflictResolutionView()
    }
} 