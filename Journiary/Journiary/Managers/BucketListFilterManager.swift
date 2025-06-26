//
//  BucketListFilterManager.swift
//  Journiary
//
//  Created by AI Assistant on [Current Date]
//

import Foundation
import CoreData
import CoreLocation
import SwiftUI
import Combine

@MainActor
class BucketListFilterManager: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedCountry: String? = nil
    @Published var selectedTypes: Set<BucketListType> = []
    @Published var useDistanceFilter: Bool = false
    @Published var maxDistance: Double = 50.0 // km
    @Published var showOpenItems: Bool = true
    @Published var showCompletedItems: Bool = true
    
    @Published var filteredItems: [BucketListItem] = []
    @Published var filteredCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var availableCountries: [String] = []
    @Published var isLocationAvailable: Bool = false
    @Published var filterUpdateID = UUID()
    
    // Search Properties
    @Published var searchText: String = "" {
        didSet {
            handleSearchTextChange()
        }
    }
    @Published var isSearchActive: Bool = false
    
    // MARK: - Private Properties
    private let context: NSManagedObjectContext
    private var allItems: [BucketListItem] = []
    private var searchWorkItem: DispatchWorkItem?
    
    // MARK: - Initialization
    init(context: NSManagedObjectContext) {
        self.context = context
        print("[FilterManager] Initialisiert: \(Unmanaged.passUnretained(self).toOpaque())")
        loadData()
    }
    
    // MARK: - Data Loading
    func loadData() {
        let request: NSFetchRequest<BucketListItem> = BucketListItem.fetchRequest()
        
        do {
            allItems = try context.fetch(request)
            totalCount = allItems.count
            print("[FilterManager] Daten geladen: \(totalCount) Items")
            
            updateAvailableCountries()
            applyFilters()
        } catch {
            print("[FilterManager] Fehler beim Laden der Daten: \(error)")
            allItems = []
            totalCount = 0
        }
    }
    
    private func updateAvailableCountries() {
        let countries = Set(allItems.compactMap { $0.country?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter { !$0.isEmpty }
            .sorted()
        
        availableCountries = countries
    }
    
    // MARK: - Search Methods
    
    private func handleSearchTextChange() {
        isSearchActive = !searchText.isEmpty
        
        // Cancel previous work item
        searchWorkItem?.cancel()
        
        // Create new work item  
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.applyFilters()
            }
        }
        
        // Store and execute work item
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    

    
    func clearSearch() {
        // Cancel pending search work
        searchWorkItem?.cancel()
        
        searchText = ""
        isSearchActive = false
        applyFilters()
    }
    
    // MARK: - Filter Methods
    func applyFilters() {
        var filtered = allItems
        
        // Suchtext Filter mit verbesserter Logik
        if !searchText.isEmpty {
            let lowercaseSearch = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !lowercaseSearch.isEmpty {
                filtered = filtered.filter { item in
                    let name = item.name?.lowercased() ?? ""
                    let country = item.country?.lowercased() ?? ""
                    let region = item.region?.lowercased() ?? ""
                    let typeDisplayName = BucketListType(rawValue: item.type ?? "")?.displayName.lowercased() ?? ""
                    
                    return name.contains(lowercaseSearch) ||
                           country.contains(lowercaseSearch) ||
                           region.contains(lowercaseSearch) ||
                           typeDisplayName.contains(lowercaseSearch)
                }
            }
        }
        
        // Land Filter
        if let selectedCountry = selectedCountry {
            filtered = filtered.filter { item in
                return item.country?.trimmingCharacters(in: .whitespacesAndNewlines) == selectedCountry
            }
        }
        
        // Art Filter
        if !selectedTypes.isEmpty {
            filtered = filtered.filter { item in
                guard let typeString = item.type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                      let type = BucketListType(rawValue: typeString) else {
                    return false
                }
                return selectedTypes.contains(type)
            }
        }
        
        // Status Filter
        if !showOpenItems || !showCompletedItems {
            filtered = filtered.filter { item in
                return (showOpenItems && !item.isDone) || (showCompletedItems && item.isDone)
            }
        }
        
        // Entfernungsfilter (falls aktiviert und Standort verfügbar)
        if useDistanceFilter && isLocationAvailable {
            filtered = filtered.filter { item in
                if item.latitude1 == 0.0 && item.longitude1 == 0.0 {
                    return false
                }
                
                guard let currentLocation = LocationManager.shared?.currentLocation else {
                    return false
                }
                
                let itemLocation = CLLocation(latitude: item.latitude1, longitude: item.longitude1)
                let distance = currentLocation.distance(from: itemLocation) / 1000.0 // Convert to km
                return distance <= maxDistance
            }
        }
        
        filteredItems = filtered
        filteredCount = filtered.count
        filterUpdateID = UUID()
        
        print("[FilterManager] Filter angewendet: \(filteredCount)/\(totalCount) Items")
    }
    
    // MARK: - Filter Actions
    func toggleCountry(_ country: String) {
        if selectedCountry == country {
            selectedCountry = nil
        } else {
            selectedCountry = country
        }
        applyFilters()
    }
    
    func toggleType(_ type: BucketListType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
        applyFilters()
    }
    
    func resetAllFilters() {
        selectedCountry = nil
        selectedTypes.removeAll()
        useDistanceFilter = false
        maxDistance = 50.0
        showOpenItems = true
        showCompletedItems = true
        clearSearch()
    }
    
    func resetCountryFilter() {
        selectedCountry = nil
        applyFilters()
    }
    
    func resetTypeFilter() {
        selectedTypes.removeAll()
        applyFilters()
    }
    
    func resetDistanceFilter() {
        useDistanceFilter = false
        applyFilters()
    }
    
    // MARK: - Helper Methods
    func distance(from item: BucketListItem) -> Double? {
        guard let currentLocation = LocationManager.shared?.currentLocation else { return nil }
        let itemLocation = CLLocation(latitude: item.latitude1, longitude: item.longitude1)
        return currentLocation.distance(from: itemLocation) / 1000.0 // km
    }
    
    func formattedDistance(from item: BucketListItem) -> String? {
        guard let distance = distance(from: item) else { return nil }
        
        if distance < 1.0 {
            return String(format: "%.0f m", distance * 1000)
        } else if distance < 100.0 {
            return String(format: "%.1f km", distance)
        } else {
            return String(format: "%.0f km", distance)
        }
    }
    
    var hasActiveFilters: Bool {
        return selectedCountry != nil ||
               !selectedTypes.isEmpty ||
               useDistanceFilter ||
               !showOpenItems ||
               !showCompletedItems ||
               !searchText.isEmpty
    }
    
    var activeFilterCount: Int {
        var count = 0
        if selectedCountry != nil { count += 1 }
        if !selectedTypes.isEmpty { count += 1 }
        if useDistanceFilter { count += 1 }
        if !showOpenItems || !showCompletedItems { count += 1 }
        if !searchText.isEmpty { count += 1 }
        return count
    }
    
    // MARK: - Migration für Typen
    /// Setzt alle BucketListItem-Typen auf die korrekten Enum-Strings (klein, ohne Leerzeichen)
    func migrateTypeStrings() {
        let request: NSFetchRequest<BucketListItem> = BucketListItem.fetchRequest()
        do {
            let items = try context.fetch(request)
            for item in items {
                if let typeString = item.type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                   let type = BucketListType(rawValue: typeString) {
                    item.type = type.rawValue
                } else {
                    item.type = BucketListType.sonstiges.rawValue
                }
            }
            try context.save()
            print("Migration abgeschlossen: Alle Typen vereinheitlicht.")
        } catch {
            print("Fehler bei der Migration der Typen: \(error)")
        }
    }
}

// MARK: - Extensions
extension BucketListFilterManager {
    @MainActor
    static func preview() -> BucketListFilterManager {
        let manager = BucketListFilterManager(context: PersistenceController.preview.container.viewContext)
        return manager
    }
} 