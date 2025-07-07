//
//  POIView.swift
//  Journiary
//
//  Created by AI Assistant on 08.06.25.
//

import SwiftUI
import CoreData
import Combine

enum AppMode {
    case tracking
    case planning
}

struct POIView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    @Binding var appMode: AppMode
    @State private var showingAddBucketListItem = false
    @State private var itemToEdit: BucketListItem? = nil
    @State private var showingDetail: BucketListItem? = nil
    @State private var showingFilter = false
    @State private var showingSettingsView = false
    @StateObject private var filterManager: BucketListFilterManager
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BucketListItem.createdAt, ascending: false)],
        animation: .default
    )
    private var bucketListItems: FetchedResults<BucketListItem>
    
    init(appMode: Binding<AppMode>) {
        self._appMode = appMode
        let context = PersistenceController.shared.container.viewContext
        _filterManager = StateObject(wrappedValue: BucketListFilterManager(context: context))
    }
    
    var body: some View {
        let locationPublisher = LocationManager.shared?.$currentLocation.eraseToAnyPublisher() ?? Just(nil).eraseToAnyPublisher()
        return TabView(selection: $selectedTab) {
            NavigationView {
                VStack(spacing: 0) {
                    // Search Bar
                    BucketListSearchBar(filterManager: filterManager)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                        .zIndex(1) // Ensure suggestions appear above list
                    
                    // Filter Status Bar
                    if filterManager.hasActiveFilters {
                        filterStatusBar
                            .padding(.bottom, 8)
                    }
                    
                    List {
                        ForEach(displayedItems) { item in
                            BucketListRowView(
                                item: item,
                                onToggleComplete: {
                                    item.isDone.toggle()
                                    try? viewContext.save()
                                    filterManager.loadData() // Refresh filters
                                },
                                onTap: {
                                    showingDetail = item
                                },
                                showDistance: filterManager.isLocationAvailable,
                                formattedDistance: filterManager.formattedDistance(from: item)
                            )
                        }
                        .onDelete(perform: deleteItems)
                        
                        if displayedItems.isEmpty {
                            if filterManager.hasActiveFilters {
                                emptyStateView
                            } else {
                                emptyBucketListView
                            }
                        }
                    }
                    .id(filterManager.filterUpdateID)
                    .refreshable {
                        filterManager.loadData()
                    }
                    // Phase 5.4: Automatische UI-Aktualisierung nach Sync-Erfolg
                    .autoRefreshList()
                    .onTapGesture {
                        // Dismiss keyboard when tapping on list
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                .navigationTitle("Bucket List (\(displayedItems.count))")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showingSettingsView = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            Button(action: {
                                showingFilter = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: filterManager.isSearchActive ? "magnifyingglass.circle" : "line.3.horizontal.decrease.circle")
                                    if filterManager.hasActiveFilters {
                                        Text("\(filterManager.activeFilterCount)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(width: 16, height: 16)
                                            .background(filterManager.isSearchActive ? Color.blue : Color.red)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .tabItem {
                Image(systemName: "list.bullet")
                Text("Bucket List")
            }
            .tag(0)
            
            NavigationView {
                BucketListMapView(items: displayedItems)
            }
            .tabItem {
                Image(systemName: "map.fill")
                Text("Map")
            }
            .tag(1)
            
            NavigationView {
                Color.clear
                    .onAppear {
                        itemToEdit = nil
                        showingAddBucketListItem = true
                    }
            }
            .tabItem {
                Image(systemName: "plus.circle.fill")
                Text("Idee")
            }
            .tag(2)
            
            // Einfacher Wechsel-Tab zurück zum Tracker
            VStack {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("Tracker Modus")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Zurück zum Tracking wechseln")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                appMode = .tracking
            }
            .tabItem {
                Image(systemName: "location.fill")
                Text("Tracker")
            }
            .tag(3)
        }
        .accentColor(.blue)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 3 {
                appMode = .tracking
            }
        }
        .sheet(isPresented: $showingAddBucketListItem) {
            AddBucketListItemView(selectedTab: $selectedTab)
        }
        .sheet(item: $showingDetail) { item in
            BucketListItemDetailCompactView(item: item, selectedTab: $selectedTab)
        }
        .sheet(item: $itemToEdit) { item in
            AddBucketListItemView(editItem: item, selectedTab: $selectedTab)
        }
        .sheet(isPresented: $showingFilter) {
            BucketListFilterView(filterManager: filterManager)
        }
        .sheet(isPresented: $showingSettingsView) {
            SettingsView()
                .environmentObject(LocationManager(context: viewContext))
        }
        .onAppear {
            filterManager.loadData()
        }
        .onReceive(locationPublisher) { _ in
            if filterManager.useDistanceFilter {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    filterManager.applyFilters()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var displayedItems: [BucketListItem] {
        if filterManager.hasActiveFilters {
            return filterManager.filteredItems
        } else {
            return Array(bucketListItems)
        }
    }
    
    // MARK: - Filter Status Bar
    
    private var filterStatusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundColor(.blue)
            
            Text("Filter aktiv:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let country = filterManager.selectedCountry {
                        FilterStatusChip(
                            title: country,
                            icon: "globe",
                            onRemove: { filterManager.selectedCountry = nil }
                        )
                    }
                    
                    if !filterManager.selectedTypes.isEmpty {
                        FilterStatusChip(
                            title: "\(filterManager.selectedTypes.count) Art(en)",
                            icon: "tag",
                            onRemove: { filterManager.selectedTypes.removeAll() }
                        )
                    }
                    
                    if filterManager.useDistanceFilter {
                        FilterStatusChip(
                            title: "\(Int(filterManager.maxDistance)) km",
                            icon: "location.circle",
                            onRemove: { filterManager.useDistanceFilter = false }
                        )
                    }
                    
                    if !filterManager.searchText.isEmpty {
                        FilterStatusChip(
                            title: "Suche: \(filterManager.searchText)",
                            icon: "magnifyingglass",
                            onRemove: { filterManager.clearSearch() }
                        )
                    }
                    
                    if !filterManager.showOpenItems || !filterManager.showCompletedItems {
                        let statusText = filterManager.showOpenItems ? "Nur Offen" : (filterManager.showCompletedItems ? "Nur Erledigt" : "Kein Status")
                        FilterStatusChip(
                            title: statusText,
                            icon: "checkmark.circle",
                            onRemove: {
                                filterManager.showOpenItems = true
                                filterManager.showCompletedItems = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
            
            Button("Filter Reset") {
                filterManager.resetAllFilters()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Empty State Views
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: filterManager.isSearchActive ? "magnifyingglass" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .opacity(0.6)
            
            VStack(spacing: 8) {
                Text(filterManager.isSearchActive ? "Keine Suchergebnisse" : "Keine Ergebnisse gefunden")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if filterManager.isSearchActive {
                    Text("Für '\(filterManager.searchText)' wurden keine Orte gefunden.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else {
                    Text("Versuchen Sie andere Filterkriterien oder fügen Sie neue Bucket-List-Items hinzu.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Button(filterManager.isSearchActive ? "Suche löschen" : "Filter Reset") {
                filterManager.resetAllFilters()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private var emptyBucketListView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .opacity(0.7)
            
            VStack(spacing: 12) {
                Text("Ihre Bucket List ist leer")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Fügen Sie Orte hinzu, die Sie besuchen möchten!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                selectedTab = 2 // Wechsel zum Add-Tab
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Ersten Ort hinzufügen")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    // MARK: - Delete
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = displayedItems[index]
            viewContext.delete(item)
        }
        do {
            try viewContext.save()
            filterManager.loadData()
        } catch {
            print("Fehler beim Löschen: \(error.localizedDescription)")
        }
    }
}

struct POIView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State var mode: AppMode = .planning
        var body: some View {
            POIView(appMode: $mode)
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
    static var previews: some View {
        PreviewWrapper()
    }
} 