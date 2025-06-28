//
//  AppSettings.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Combine
import Security

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // MARK: - Published Properties
    
    @Published var storageMode: StorageMode {
        didSet {
            UserDefaults.standard.set(storageMode.rawValue, forKey: "StorageMode")
        }
    }
    
    @Published var backendURL: String {
        didSet {
            UserDefaults.standard.set(backendURL, forKey: "BackendURL")
        }
    }
    
    @Published var username: String {
        didSet {
            UserDefaults.standard.set(username, forKey: "BackendUsername")
        }
    }
    
    @Published var autoSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoSyncEnabled, forKey: "AutoSyncEnabled")
        }
    }
    
    @Published var syncInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(syncInterval, forKey: "SyncInterval")
        }
    }
    
    @Published var backgroundSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(backgroundSyncEnabled, forKey: "BackgroundSyncEnabled")
        }
    }
    
    @Published var wifiOnlySyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(wifiOnlySyncEnabled, forKey: "WiFiOnlySyncEnabled")
        }
    }
    
    // MARK: - Private Properties
    
    private let keychainService = "com.journiary.credentials"
    private let passwordKey = "BackendPassword"
    
    // MARK: - Initialization
    
    private init() {
        // Beim ersten Start soll der Benutzer explizit wählen - kein Default setzen
        let storedMode = UserDefaults.standard.string(forKey: "StorageMode")
        if let storedMode = storedMode, !storedMode.isEmpty {
            self.storageMode = StorageMode(rawValue: storedMode) ?? .cloudKit
        } else {
            // Beim ersten Start: CloudKit als fallback, aber wird durch StorageModeSelection überschrieben
            self.storageMode = .cloudKit
        }
        
        // Development: Verwende lokalen Server oder Demo-Mode
        let defaultURL: String
        #if DEBUG
        defaultURL = "http://localhost:4001" // Lokaler Development Server (Docker Port-Mapping)
        #else
        defaultURL = "https://api.journiary.com"
        #endif
        
        self.backendURL = UserDefaults.standard.string(forKey: "BackendURL") ?? defaultURL
        self.username = UserDefaults.standard.string(forKey: "BackendUsername") ?? ""
        self.autoSyncEnabled = UserDefaults.standard.bool(forKey: "AutoSyncEnabled")
        self.syncInterval = UserDefaults.standard.double(forKey: "SyncInterval") == 0 ? 300 : UserDefaults.standard.double(forKey: "SyncInterval") // 5 Minuten default
        self.backgroundSyncEnabled = UserDefaults.standard.bool(forKey: "BackgroundSyncEnabled")
        self.wifiOnlySyncEnabled = UserDefaults.standard.bool(forKey: "WiFiOnlySyncEnabled")
    }
    
    // MARK: - Password Management (Keychain)
    
    var password: String {
        get {
            return getPasswordFromKeychain() ?? ""
        }
        set {
            setPasswordInKeychain(newValue)
        }
    }
    
    private func getPasswordFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: passwordKey,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let password = String(data: data, encoding: .utf8) {
            return password
        }
        
        return nil
    }
    
    private func setPasswordInKeychain(_ password: String) {
        let data = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: passwordKey
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        
        if status == errSecItemNotFound {
            // Item existiert noch nicht, erstelle es
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
    
    func deletePasswordFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: passwordKey
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Computed Properties
    
    var isBackendConfigured: Bool {
        return !backendURL.isEmpty && !username.isEmpty && !password.isEmpty
    }
    
    var shouldUseBackend: Bool {
        return storageMode == .backend || storageMode == .hybrid
    }
    
    var shouldUseCloudKit: Bool {
        return storageMode == .cloudKit || storageMode == .hybrid
    }
    
    // MARK: - Sync Interval Options
    
    static let syncIntervalOptions: [(title: String, value: TimeInterval)] = [
        ("Nie", 0),
        ("1 Minute", 60),
        ("5 Minuten", 300),
        ("15 Minuten", 900),
        ("30 Minuten", 1800),
        ("1 Stunde", 3600)
    ]
    
    var syncIntervalDisplayName: String {
        let option = Self.syncIntervalOptions.first { $0.value == syncInterval }
        return option?.title ?? "5 Minuten"
    }
} 