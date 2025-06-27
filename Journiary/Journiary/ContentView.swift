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
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var offlineQueue: OfflineQueue
    
    @State private var selectedTab = 0
    @State private var showLogin = false
    @State private var isAuthenticated = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                TripView()
            }
            .tabItem {
                Label("Reisen", systemImage: "airplane")
            }
            .tag(0)
            
            NavigationView {
                MemoriesView()
            }
            .tabItem {
                Label("Erinnerungen", systemImage: "photo.on.rectangle")
            }
            .tag(1)
            
            NavigationView {
                BucketListMapView()
            }
            .tabItem {
                Label("Bucket List", systemImage: "list.bullet")
            }
            .tag(2)
            
            NavigationView {
                ProfileView()
            }
            .tabItem {
                Label("Profil", systemImage: "person.crop.circle")
            }
            .tag(3)
        }
        .onAppear {
            // Prüfe, ob der Benutzer authentifiziert ist
            isAuthenticated = settings.isAuthenticated
            
            // Zeige den Login-Screen, wenn der Benutzer nicht authentifiziert ist
            // und der Speichermodus Self-Hosted oder Hybrid ist
            if !isAuthenticated && (settings.storageMode == .selfHosted || settings.storageMode == .hybrid) {
                showLogin = true
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView(isPresented: $showLogin)
        }
        .overlay(
            VStack {
                if networkMonitor.status == .disconnected && settings.offlineModeEnabled {
                    offlineModeIndicator
                }
                Spacer()
            }
        )
        .onChange(of: settings.isAuthenticated) { newValue in
            isAuthenticated = newValue
        }
    }
    
    private var offlineModeIndicator: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.white)
            
            Text("Offline-Modus aktiv")
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
            
            if !offlineQueue.operations.isEmpty {
                Text("\(offlineQueue.operations.count) ausstehend")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            Button(action: {
                selectedTab = 3 // Wechsle zum Profil-Tab
            }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.red)
        .transition(.move(edge: .top))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AppSettings.shared)
    }
}
