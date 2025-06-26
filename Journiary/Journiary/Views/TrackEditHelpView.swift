//
//  TrackEditHelpView.swift
//  Journiary
//
//  Created by AI Assistant on 09.06.25.
//

import SwiftUI

struct TrackEditHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading) {
                                Text("Track Editor")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Bearbeite deine Routenpunkte")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Grundlagen
                    HelpSection(
                        icon: "hand.tap",
                        title: "Grundlagen",
                        items: [
                            "Tippe einen Routenpunkt an, um ihn auszuwählen",
                            "Ausgewählte Punkte werden größer und blau angezeigt",
                            "Tippe in einen leeren Bereich, um die Auswahl aufzuheben"
                        ]
                    )
                    
                    // Verschieben
                    HelpSection(
                        icon: "move.3d",
                        title: "Punkte verschieben",
                        items: [
                            "Wähle einen Punkt aus (wird blau)",
                            "Halte den Punkt gedrückt und ziehe ihn",
                            "Lasse los, um die neue Position zu speichern",
                            "Bei Erfolg fühlst du eine kurze Vibration"
                        ]
                    )
                    
                    // Neue Punkte
                    HelpSection(
                        icon: "plus.circle",
                        title: "Neue Punkte hinzufügen",
                        items: [
                            "Tippe 'Neuer Punkt' um den Einfügen-Modus zu aktivieren",
                            "Wähle 2 benachbarte Punkte aus (werden orange)",
                            "Tippe 'Bestätigen' um einen Punkt dazwischen einzufügen",
                            "Der neue Punkt wird automatisch ausgewählt"
                        ]
                    )
                    
                    // Löschen
                    HelpSection(
                        icon: "trash",
                        title: "Punkte löschen",
                        items: [
                            "Wähle einen Punkt aus",
                            "Tippe den roten 'Löschen' Button",
                            "Bestätige die Löschung im Dialog"
                        ]
                    )
                    
                    // Tipps
                    HelpSection(
                        icon: "lightbulb",
                        title: "Tipps",
                        items: [
                            "Die Distanz wird automatisch neu berechnet",
                            "Änderungen werden sofort gespeichert",
                            "Zoome für präzise Bearbeitung heran",
                            "Der erste und letzte Punkt sind besonders wichtig"
                        ]
                    )
                }
                .padding()
            }
            .navigationTitle("Hilfe")
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

struct HelpSection: View {
    let icon: String
    let title: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        
                        Text(item)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.leading, 36)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
} 