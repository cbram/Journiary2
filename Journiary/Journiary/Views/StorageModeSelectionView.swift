//
//  StorageModeSelectionView.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import SwiftUI

struct StorageModeSelectionView: View {
    @StateObject private var appSettings = AppSettings.shared
    @State private var selectedMode: StorageMode = .cloudKit
    @State private var showingModeDetail = false
    @State private var animateContent = false
    @State private var isConfirming = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Storage Mode Options
                    storageModeOptions
                    
                    // Continue Button
                    continueButtonSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
            }
            .background(backgroundGradient)
            .navigationBarHidden(true)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animateContent = true
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)
            
            // App Icon
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
                .scaleEffect(animateContent ? 1.0 : 0.8)
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateContent)
            
            VStack(spacing: 12) {
                Text("Willkommen bei Travel Companion")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Wählen Sie, wie Ihre Reisedaten gespeichert werden sollen")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .opacity(animateContent ? 1.0 : 0.0)
            .offset(y: animateContent ? 0 : 20)
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: animateContent)
            
            Spacer(minLength: 40)
        }
    }
    
    // MARK: - Storage Mode Options
    
    private var storageModeOptions: some View {
        VStack(spacing: 16) {
            ForEach(StorageMode.allCases, id: \.self) { mode in
                StorageModeCard(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    animationDelay: Double(StorageMode.allCases.firstIndex(of: mode) ?? 0) * 0.1
                ) {
                    selectedMode = mode
                    
                    // Haptic Feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
                .opacity(animateContent ? 1.0 : 0.0)
                .offset(x: animateContent ? 0 : -50)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.8)
                    .delay(0.4 + Double(StorageMode.allCases.firstIndex(of: mode) ?? 0) * 0.1),
                    value: animateContent
                )
            }
        }
    }
    
    // MARK: - Continue Button
    
    private var continueButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                confirmSelection()
            }) {
                HStack {
                    Image(systemName: selectedMode.iconName)
                        .font(.title2)
                    
                    Text("Mit \(selectedMode.displayName) fortfahren")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .opacity(animateContent ? 1.0 : 0.0)
            .offset(y: animateContent ? 0 : 30)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8), value: animateContent)
            
            // Info Text
            Text(getInfoText())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .opacity(animateContent ? 1.0 : 0.0)
                .offset(y: animateContent ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.9), value: animateContent)
        }
        .padding(.top, 32)
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.95),
                Color.blue.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Helper Methods
    
    private func getInfoText() -> String {
        switch selectedMode {
        case .cloudKit:
            return "Ihre Daten werden sicher in iCloud gespeichert und automatisch zwischen Ihren Geräten synchronisiert."
        case .backend:
            return "Ihre Daten werden auf Ihrem eigenen Server gespeichert. Vollständige Kontrolle und Privatsphäre."
        case .hybrid:
            return "Beste aus beiden Welten: iCloud für Komfort, Ihr Server als Backup und für erweiterte Features."
        }
    }
    
    private func confirmSelection() {
        // Haptic Feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Storage Mode speichern
        appSettings.storageMode = selectedMode
        
        print("✅ Storage Mode gewählt: \(selectedMode.displayName)")
    }
}

// MARK: - Storage Mode Card

struct StorageModeCard: View {
    let mode: StorageMode
    let isSelected: Bool
    let animationDelay: Double
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Icon
                Image(systemName: mode.iconName)
                    .font(.system(size: 40))
                    .foregroundColor(isSelected ? .white : .blue)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                
                // Title and Description
                VStack(spacing: 8) {
                    Text(mode.displayName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                
                // Features List
                featuresList
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                        ? LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .stroke(
                        isSelected ? Color.blue.opacity(0.8) : Color(.systemGray4),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .shadow(
                color: isSelected ? .blue.opacity(0.3) : .black.opacity(0.1),
                radius: isSelected ? 12 : 4,
                x: 0,
                y: isSelected ? 6 : 2
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var featuresList: some View {
        VStack(spacing: 4) {
            ForEach(getFeatures(), id: \.self) { feature in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .green)
                    
                    Text(feature)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.top, 8)
    }
    
    private func getFeatures() -> [String] {
        switch mode {
        case .cloudKit:
            return ["Automatische Synchronisation", "Keine Konfiguration nötig", "Apple ID erforderlich"]
        case .backend:
            return ["Vollständige Kontrolle", "Eigener Server", "Maximale Privatsphäre"]
        case .hybrid:
            return ["iCloud + Eigener Server", "Redundante Sicherung", "Beste Flexibilität"]
        }
    }
}

// MARK: - Preview

struct StorageModeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        StorageModeSelectionView()
    }
} 