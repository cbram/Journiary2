//
//  TrackingView.swift
//  Journiary
//
//  Created by AI Assistant on 08.06.25.
//

import SwiftUI
import CoreData

struct TrackingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationManager: LocationManager
    @State private var selectedTab = 0
    @Binding var appMode: AppMode
    
    init(appMode: Binding<AppMode>) {
        let context = EnhancedPersistenceController.shared.container.viewContext
        self._locationManager = StateObject(wrappedValue: LocationManager(context: context))
        self._appMode = appMode
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MemoriesView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("Timeline")
                }
                .tag(0)
            
            MapView()
                .environmentObject(locationManager)
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Karte")
                }
                .tag(1)
            
            AddMemoryView(selectedTab: $selectedTab)
                .environmentObject(locationManager)
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Erinnerung")
                }
                .tag(2)
            
            TripView()
                .environmentObject(locationManager)
                .tabItem {
                    Image(systemName: "suitcase.fill")
                    Text("Reisen")
                }
                .tag(3)
            
            // Einfacher Wechsel-Tab für POIs
            VStack {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("POI Modus")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Zu Points of Interest wechseln")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                appMode = .planning
            }
            .tabItem {
                Image(systemName: "mappin.and.ellipse")
                Text("POIs")
            }
            .tag(4)
        }
        .accentColor(.blue)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 4 {
                appMode = .planning
            }
        }
    }
}

struct TrackingView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State var mode: AppMode = .tracking
        var body: some View {
            TrackingView(appMode: $mode)
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
    static var previews: some View {
        PreviewWrapper()
    }
} 