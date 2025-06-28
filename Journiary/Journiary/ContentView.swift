//
//  ContentView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var appSettings = AppSettings.shared
    @State private var appMode: AppMode = .tracking
    @State private var isStorageModeConfigured = false
    @State private var isAnimating = true
    
    var body: some View {
        Group {
            if shouldShowStorageModeSelection {
                StorageModeSelectionView()
                    .transition(.opacity)
            } else if shouldShowLogin {
                LoginView()
                    .transition(.opacity)
            } else if shouldShowMainApp {
                authenticatedContentView
                    .transition(.opacity)
            } else {
                // Fallback Loading Screen
                loadingView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentViewState) // Kürzere Animation für bessere Performance
        .environmentObject(authManager)
        .environmentObject(appSettings)
        .onAppear {
            checkStorageModeConfiguration()
        }
        .onReceive(appSettings.$storageMode) { _ in
            DispatchQueue.main.async { // Verhindere synchrone Updates
                checkStorageModeConfiguration()
            }
        }
    }
    
    // MARK: - Content Views
    
    private var authenticatedContentView: some View {
        Group {
            switch appMode {
            case .tracking:
                TrackingView(appMode: $appMode)
            case .planning:
                POIView(appMode: $appMode)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: appMode)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            
            Text("Travel Companion")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if authManager.isLoading {
                ProgressView("Authentifizierung läuft...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("App wird geladen...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            isAnimating = true
        }
    }
    
    // MARK: - Computed Properties
    
    private var shouldShowStorageModeSelection: Bool {
        // Zeige Storage Mode Selection, wenn noch kein Storage Mode gewählt wurde
        return !isStorageModeConfigured
    }
    
    private var shouldShowLogin: Bool {
        // Zeige Login wenn:
        // 1. Storage Mode ist konfiguriert UND
        // 2. Backend-Mode aktiviert ist UND
        // 3. Benutzer nicht authentifiziert ist (egal ob Loading oder nicht)
        let result = isStorageModeConfigured &&
                     appSettings.shouldUseBackend && 
                     !authManager.isAuthenticated
        
        // Reduziere Debug-Output um Performance zu verbessern
        #if DEBUG
        if result {
            print("📱 ContentView: Login-Screen wird angezeigt (isLoading: \(authManager.isLoading))")
        }
        #endif
        
        return result
    }
    
    private var shouldShowMainApp: Bool {
        // Zeige Hauptapp nur wenn:
        // 1. Storage Mode ist konfiguriert UND
        // 2. (CloudKit-Mode ODER erfolgreich authentifiziert) UND
        // 3. Nicht gerade ein Login-Loading läuft
        let result = isStorageModeConfigured &&
                     (!appSettings.shouldUseBackend || authManager.isAuthenticated)
        
        // Reduziere Debug-Output um Performance zu verbessern
        #if DEBUG
        if result {
            print("📱 ContentView: Hauptapp wird angezeigt")
        }
        #endif
        
        return result
    }
    
    private func checkStorageModeConfiguration() {
        let userDefaultsValue = UserDefaults.standard.string(forKey: "StorageMode")
        let hasStoredValue = userDefaultsValue != nil && !userDefaultsValue!.isEmpty
        
        // Nur loggen wenn sich der State ändert
        let previousState = isStorageModeConfigured
        isStorageModeConfigured = hasStoredValue
        
        #if DEBUG
        if previousState != hasStoredValue {
            print("🔍 StorageMode Check: UserDefaults=\(userDefaultsValue ?? "nil"), hasStored=\(hasStoredValue)")
            
            if hasStoredValue {
                print("✅ Storage Mode konfiguriert: \(appSettings.storageMode.displayName)")
                if appSettings.shouldUseBackend {
                    print("🔐 Backend-Mode → Login wird angezeigt")
                } else {
                    print("☁️ CloudKit-Mode → Direkt zur App")
                }
            }
        }
        #endif
    }
    
    // Für Animation-Tracking - mit Cache um wiederholte String-Berechnungen zu vermeiden
    private var currentViewState: Int {
        if shouldShowStorageModeSelection {
            return 0 // "storageSelection"
        } else if shouldShowLogin {
            return 1 // "login"
        } else if shouldShowMainApp {
            return 2 // "authenticated"
        } else {
            return 3 // "loading"
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
