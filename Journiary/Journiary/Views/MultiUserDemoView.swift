//
//  MultiUserDemoView.swift
//  Journiary
//
//  Created by TravelCompanion AI on 28.12.24.
//

import SwiftUI
import CoreData

struct MultiUserDemoView: View {
    @StateObject private var userContextManager = UserContextManager.shared
    @Environment(\.managedObjectContext) private var context
    
    @State private var showingMigrationAlert = false
    @State private var migrationCompleted = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Current User Section
                    currentUserSection
                    
                    // Migration Section
                    migrationSection
                    
                    // Demo Actions
                    demoActionsSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Multi-User Demo")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Legacy-Daten Migration", isPresented: $showingMigrationAlert) {
            Button("Migrieren") {
                userContextManager.migrateLegacyData()
                migrationCompleted = true
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Sollen bestehende Daten dem aktuellen User zugeordnet werden?")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Multi-User Core Data")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("✅ Schema V2 mit User-Relationships")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Current User Section
    
    private var currentUserSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Aktueller Benutzer")
                    .font(.headline)
                Spacer()
                
                if userContextManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let user = userContextManager.currentUser {
                HStack(spacing: 16) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.blue, .blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 60, height: 60)
                        
                        Text(user.initials)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.headline)
                        
                        Text(user.email ?? "Keine E-Mail")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if user.isCurrentUser {
                            Text("✅ Aktiver User")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            } else {
                Text("Kein User geladen")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
            }
            
            if let errorMessage = userContextManager.errorMessage {
                Text("⚠️ \(errorMessage)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Migration Section
    
    private var migrationSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Daten-Migration")
                    .font(.headline)
                Spacer()
            }
            
            Button("Legacy-Daten migrieren") {
                showingMigrationAlert = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(userContextManager.currentUser == nil)
            
            if migrationCompleted {
                Text("✅ Migration erfolgreich abgeschlossen")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
    
    // MARK: - Demo Actions Section
    
    private var demoActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Demo-Aktionen")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Button {
                    createDemoTrip()
                } label: {
                    HStack {
                        Image(systemName: "map.badge.plus")
                        Text("Demo-Trip erstellen")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(userContextManager.currentUser == nil)
                
                Button {
                    testMultiUserQueries()
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass.circle")
                        Text("Multi-User Queries testen")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(userContextManager.currentUser == nil)
            }
        }
    }
    
    // MARK: - Demo Actions
    
    private func createDemoTrip() {
        guard let currentUser = userContextManager.currentUser else {
            print("❌ Kein Current User für Demo-Trip")
            return
        }
        
        let trip = Trip(context: context)
        trip.id = UUID()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        trip.name = "Demo Trip - \(formatter.string(from: Date()))"
        trip.tripDescription = "Ein Demo-Trip mit Multi-User Support"
        trip.startDate = Date()
        trip.endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        trip.isActive = true
        trip.owner = currentUser // 🆕 User-Zuordnung
        
        do {
            try context.save()
            print("✅ Demo-Trip erstellt und User zugeordnet")
        } catch {
            print("❌ Demo-Trip erstellen fehlgeschlagen: \(error)")
        }
    }
    
    private func testMultiUserQueries() {
        guard let currentUser = userContextManager.currentUser else {
            print("❌ Kein Current User für Query-Tests")
            return
        }
        
        print("\n🧪 Multi-User Query Tests:")
        
        // Test 1: User Trips
                    let userTripsRequest = TripFetchRequestHelpers.userTrips(for: currentUser)
        do {
            let userTrips = try context.fetch(userTripsRequest)
            print("✅ User Trips: \(userTrips.count)")
        } catch {
            print("❌ User Trips Query fehlgeschlagen: \(error)")
        }
        
        // Test 2: User Memories
                    let userMemoriesRequest = MemoryFetchRequestHelpers.userMemories(for: currentUser)
        do {
            let userMemories = try context.fetch(userMemoriesRequest)
            print("✅ User Memories: \(userMemories.count)")
        } catch {
            print("❌ User Memories Query fehlgeschlagen: \(error)")
        }
        
        print("🧪 Multi-User Query Tests abgeschlossen!\n")
    }
}

#Preview {
    MultiUserDemoView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 