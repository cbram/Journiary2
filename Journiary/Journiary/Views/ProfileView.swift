//
//  ProfileView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import CoreData

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authService: AuthService
    @StateObject private var mapCache = MapCacheManager.shared
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Trip.startDate, ascending: false)],
        animation: .default
    )
    private var allTrips: FetchedResults<Trip>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Memory.timestamp, ascending: false)],
        animation: .default
    )
    private var allMemories: FetchedResults<Memory>
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profil Header
                    profileHeader
                    
                    // Statistiken
                    statisticsSection
                }
                .padding()
            }
            .navigationTitle("Profil")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text(authService.user?.displayName ?? "Reisender")
                .font(.title2)
                .fontWeight(.bold)
            
            Button(action: {
                authService.logout()
                dismiss()
            }) {
                Text("Abmelden")
                    .foregroundColor(.red)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reisestatistiken")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatisticCard(
                    title: "Gesamtreisen",
                    value: "\(allTrips.count)",
                    icon: "location.fill",
                    color: .blue
                )
                
                StatisticCard(
                    title: "Erinnerungen",
                    value: "\(allMemories.count)",
                    icon: "photo.fill",
                    color: .green
                )
                
                StatisticCard(
                    title: "Gesamtdistanz",
                    value: String(format: "%.1f km", totalDistance / 1000),
                    icon: "ruler.fill",
                    color: .orange
                )
                
                StatisticCard(
                    title: "Besuchte Orte",
                    value: "\(uniqueLocationsCount)",
                    icon: "mappin.and.ellipse",
                    color: .purple
                )
                
                StatisticCard(
                    title: "Offline-Karten",
                    value: "\(mapCache.cachedRegions.count)",
                    icon: "square.and.arrow.down.fill",
                    color: .cyan
                )
                
                StatisticCard(
                    title: "Cache-Größe",
                    value: mapCache.formatFileSize(mapCache.totalCacheSize),
                    icon: "externaldrive.fill",
                    color: .indigo
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var totalDistance: Double {
        allTrips.reduce(0) { $0 + $1.totalDistance }
    }
    
    private var uniqueLocationsCount: Int {
        let locations = Set(allMemories.compactMap { $0.locationName })
        return locations.count
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
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
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let locationManager = LocationManager(context: context)
        let authService = AuthService() // Erstelle eine Dummy-Instanz für die Preview
        
        // Simuliere einen eingeloggten Benutzer für die Preview
        let userData: [String: AnyHashable] = [
            "__typename": "User",
            "id": "1",
            "email": "preview@journiary.com",
            "username": "PreviewUser",
            "displayName": "Max Mustermann"
        ]
        let user = JourniaryAPI.UserLoginMutation.Data.Login.User(_dataDict: .init(data: userData, fulfilledFragments: .init()))
        authService.user = user
        authService.isAuthenticated = true
        
        return ProfileView()
            .environmentObject(locationManager)
            .environmentObject(authService) // Füge den authService zur Environment hinzu
            .environment(\.managedObjectContext, context)
    }
} 