//
//  SharedUIComponents.swift
//  Journiary
//
//  Created by AI Assistant on 25.06.25.
//

import SwiftUI
import UIKit

// MARK: - Shared Activity View Controller

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        
        // Konfiguration für bessere Kompatibilität
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .markupAsPDF,
            .openInIBooks
        ]
        
        // iPad-spezifische Konfiguration
        if let popover = activityVC.popoverPresentationController {
            // Fallback für iPad - setze source view
            popover.sourceView = nil
            popover.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
            popover.permittedArrowDirections = []
        }
        
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update
    }
}

// MARK: - Shared Statistics Components

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    init(title: String, value: String, icon: String, color: Color = .blue) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
} 