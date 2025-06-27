//
//  AppSettings.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import SwiftUI

/// Zentrale Klasse zur Verwaltung der App-Einstellungen
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let keychain = UserDefaults.standard
    
    // MARK: - Allgemeine Einstellungen
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    @Published var useMetricSystem: Bool {
        didSet {
            UserDefaults.standard.set(useMetricSystem, forKey: "useMetricSystem")
        }
    }
    
    // MARK: - Speichermodus
    @Published var storageMode: StorageMode {
        didSet {
            UserDefaults.standard.set(storageMode.rawValue, forKey: "storageMode")
        }
    }
    
    // MARK: - Backend-Einstellungen
    @Published var backendURL: String {
        didSet {
            UserDefaults.standard.set(backendURL, forKey: "backendURL")
        }
    }
    
    @Published var minioURL: String {
        didSet {
            UserDefaults.standard.set(minioURL, forKey: "minioURL")
        }
    }
    
    // MARK: - Synchronisierungseinstellungen
    @Published var syncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(syncEnabled, forKey: "syncEnabled")
        }
    }
    
    @Published var syncMedia: Bool {
        didSet {
            UserDefaults.standard.set(syncMedia, forKey: "syncMedia")
        }
    }
    
    @Published var syncAutomatically: Bool {
        didSet {
            UserDefaults.standard.set(syncAutomatically, forKey: "syncAutomatically")
        }
    }
    
    @Published var syncInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(syncInterval, forKey: "syncInterval")
        }
    }
    
    @Published var syncOnlyOnWifi: Bool {
        didSet {
            UserDefaults.standard.set(syncOnlyOnWifi, forKey: "syncOnlyOnWifi")
        }
    }
    
    @Published var syncOnlyWhenCharging: Bool {
        didSet {
            UserDefaults.standard.set(syncOnlyWhenCharging, forKey: "syncOnlyWhenCharging")
        }
    }
    
    @Published var avoidExpensiveConnections: Bool {
        didSet {
            UserDefaults.standard.set(avoidExpensiveConnections, forKey: "avoidExpensiveConnections")
        }
    }
    
    // MARK: - Media-Synchronisierungseinstellungen
    @Published var autoUploadMedia: Bool {
        didSet {
            UserDefaults.standard.set(autoUploadMedia, forKey: "autoUploadMedia")
        }
    }
    
    @Published var uploadMediaOnWifiOnly: Bool {
        didSet {
            UserDefaults.standard.set(uploadMediaOnWifiOnly, forKey: "uploadMediaOnWifiOnly")
        }
    }
    
    @Published var downloadMediaOnWifiOnly: Bool {
        didSet {
            UserDefaults.standard.set(downloadMediaOnWifiOnly, forKey: "downloadMediaOnWifiOnly")
        }
    }
    
    @Published var deleteLocalMediaAfterUpload: Bool {
        didSet {
            UserDefaults.standard.set(deleteLocalMediaAfterUpload, forKey: "deleteLocalMediaAfterUpload")
        }
    }
    
    // MARK: - Offline-Modus-Einstellungen
    @Published var offlineModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(offlineModeEnabled, forKey: "offlineModeEnabled")
        }
    }
    
    @Published var autoDownloadMedia: Bool {
        didSet {
            UserDefaults.standard.set(autoDownloadMedia, forKey: "autoDownloadMedia")
        }
    }
    
    @Published var maxOfflineStorageSize: Int {
        didSet {
            UserDefaults.standard.set(maxOfflineStorageSize, forKey: "maxOfflineStorageSize")
        }
    }
    
    // MARK: - Konfliktlösungseinstellungen
    @Published var conflictResolutionStrategy: String {
        didSet {
            UserDefaults.standard.set(conflictResolutionStrategy, forKey: "conflictResolutionStrategy")
        }
    }
    
    // MARK: - Debug-Einstellungen
    @Published var debugModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(debugModeEnabled, forKey: "debugModeEnabled")
        }
    }
    
    @Published var verboseLogging: Bool {
        didSet {
            UserDefaults.standard.set(verboseLogging, forKey: "verboseLogging")
        }
    }
    
    // MARK: - Auth Token Management
    
    var authToken: String? {
        get {
            UserDefaults.standard.string(forKey: "auth_token")
        }
        set {
            if let token = newValue {
                UserDefaults.standard.set(token, forKey: "auth_token")
            } else {
                UserDefaults.standard.removeObject(forKey: "auth_token")
            }
        }
    }
    
    var isLoggedIn: Bool {
        return authToken != nil
    }
    
    func logout() {
        authToken = nil
    }
    
    // MARK: - Migration Settings
    
    @AppStorage("migration_in_progress") var migrationInProgress: Bool = false
    @AppStorage("migration_progress") var migrationProgress: Double = 0
    
    private init() {
        // Private initializer to enforce singleton pattern
        
        // Allgemeine Einstellungen
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        self.useMetricSystem = UserDefaults.standard.bool(forKey: "useMetricSystem")
        
        // Speichermodus
        if let storageModeString = UserDefaults.standard.string(forKey: "storageMode"),
           let storageMode = StorageMode(rawValue: storageModeString) {
            self.storageMode = storageMode
        } else {
            self.storageMode = .local
        }
        
        // Backend-Einstellungen
        self.backendURL = UserDefaults.standard.string(forKey: "backendURL") ?? "http://localhost:4000/graphql"
        self.minioURL = UserDefaults.standard.string(forKey: "minioURL") ?? "http://localhost:9000"
        
        // Synchronisierungseinstellungen
        self.syncEnabled = UserDefaults.standard.bool(forKey: "syncEnabled")
        self.syncMedia = UserDefaults.standard.bool(forKey: "syncMedia")
        self.syncAutomatically = UserDefaults.standard.bool(forKey: "syncAutomatically")
        self.syncInterval = UserDefaults.standard.double(forKey: "syncInterval")
        if self.syncInterval == 0 {
            self.syncInterval = 3600 // Standard: 1 Stunde
        }
        self.syncOnlyOnWifi = UserDefaults.standard.bool(forKey: "syncOnlyOnWifi")
        self.syncOnlyWhenCharging = UserDefaults.standard.bool(forKey: "syncOnlyWhenCharging")
        self.avoidExpensiveConnections = UserDefaults.standard.bool(forKey: "avoidExpensiveConnections")
        
        // Media-Synchronisierungseinstellungen
        self.autoUploadMedia = UserDefaults.standard.bool(forKey: "autoUploadMedia")
        self.uploadMediaOnWifiOnly = UserDefaults.standard.bool(forKey: "uploadMediaOnWifiOnly")
        self.downloadMediaOnWifiOnly = UserDefaults.standard.bool(forKey: "downloadMediaOnWifiOnly")
        self.deleteLocalMediaAfterUpload = UserDefaults.standard.bool(forKey: "deleteLocalMediaAfterUpload")
        
        // Offline-Modus-Einstellungen
        self.offlineModeEnabled = UserDefaults.standard.bool(forKey: "offlineModeEnabled")
        self.autoDownloadMedia = UserDefaults.standard.bool(forKey: "autoDownloadMedia")
        self.maxOfflineStorageSize = UserDefaults.standard.integer(forKey: "maxOfflineStorageSize")
        if self.maxOfflineStorageSize == 0 {
            self.maxOfflineStorageSize = 1024 // Standard: 1 GB
        }
        
        // Konfliktlösungseinstellungen
        self.conflictResolutionStrategy = UserDefaults.standard.string(forKey: "conflictResolutionStrategy") ?? "newerWins"
        
        // Debug-Einstellungen
        self.debugModeEnabled = UserDefaults.standard.bool(forKey: "debugModeEnabled")
        self.verboseLogging = UserDefaults.standard.bool(forKey: "verboseLogging")
    }
    
    // MARK: - Hilfsfunktionen
    
    /// Setzt alle Einstellungen auf die Standardwerte zurück
    func resetToDefaults() {
        // Allgemeine Einstellungen
        isDarkMode = false
        useMetricSystem = true
        
        // Speichermodus
        storageMode = .local
        
        // Backend-Einstellungen
        backendURL = "http://localhost:4000/graphql"
        minioURL = "http://localhost:9000"
        
        // Synchronisierungseinstellungen
        syncEnabled = false
        syncMedia = true
        syncAutomatically = true
        syncInterval = 3600 // 1 Stunde
        syncOnlyOnWifi = true
        syncOnlyWhenCharging = false
        avoidExpensiveConnections = true
        
        // Media-Synchronisierungseinstellungen
        autoUploadMedia = true
        uploadMediaOnWifiOnly = true
        downloadMediaOnWifiOnly = true
        deleteLocalMediaAfterUpload = false
        
        // Offline-Modus-Einstellungen
        offlineModeEnabled = true
        autoDownloadMedia = false
        maxOfflineStorageSize = 1024 // 1 GB
        
        // Konfliktlösungseinstellungen
        conflictResolutionStrategy = "newerWins"
        
        // Debug-Einstellungen
        debugModeEnabled = false
        verboseLogging = false
    }
    
    /// Gibt die formatierte Größe des maximalen Offline-Speichers zurück
    var formattedMaxOfflineStorageSize: String {
        if maxOfflineStorageSize >= 1024 {
            let sizeInGB = Double(maxOfflineStorageSize) / 1024.0
            return String(format: "%.1f GB", sizeInGB)
        } else {
            return "\(maxOfflineStorageSize) MB"
        }
    }
    
    /// Gibt das formatierte Synchronisierungsintervall zurück
    var formattedSyncInterval: String {
        let hours = Int(syncInterval) / 3600
        let minutes = (Int(syncInterval) % 3600) / 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours) Std. \(minutes) Min."
            } else {
                return "\(hours) Stunden"
            }
        } else {
            return "\(minutes) Minuten"
        }
    }
}
