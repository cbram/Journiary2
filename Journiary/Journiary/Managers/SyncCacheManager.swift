import Foundation

/// Intelligente Caching-Mechanismen für Sync-Daten
/// Implementiert als Teil von Schritt 5.3 des Sync-Implementierungsplans
class SyncCacheManager: NSObject {
    static let shared = SyncCacheManager()
    
    private let cache = NSCache<NSString, CacheEntry>()
    private let cacheQueue = DispatchQueue(label: "SyncCache", attributes: .concurrent)
    private var keyTracker: Set<String> = []
    private let keyTrackerQueue = DispatchQueue(label: "KeyTracker", attributes: .concurrent)
    
    private override init() {
        super.init()
        setupCache()
        startPeriodicCleanup()
    }
    
    /// Konfiguriert die Cache-Einstellungen
    private func setupCache() {
        cache.countLimit = 1000 // Max 1000 Einträge
        cache.totalCostLimit = 50 * 1024 * 1024 // Max 50MB
        
        // Delegate für Cache-Events
        cache.delegate = self
        
        print("🗄️ SyncCacheManager initialisiert: Max \(cache.countLimit) Einträge, \(formatBytes(cache.totalCostLimit)) Limit")
    }
    
    /// Cached eine Entität mit TTL (Time To Live)
    /// - Parameters:
    ///   - entity: Die zu cachende Entität
    ///   - key: Der Cache-Schlüssel
    ///   - ttl: Time-to-Live in Sekunden (Standard: 300s = 5 Minuten)
    func cacheEntity(_ entity: Any, forKey key: String, ttl: TimeInterval = 300) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let entry = CacheEntry(data: entity, expirationDate: Date().addingTimeInterval(ttl))
            let cost = self.estimateSize(of: entity)
            
            self.cache.setObject(entry, forKey: NSString(string: key), cost: cost)
            
            // Tracking des Keys
            self.keyTrackerQueue.async(flags: .barrier) {
                self.keyTracker.insert(key)
            }
            
            print("💾 Cached entity: \(key) (TTL: \(Int(ttl))s, Size: \(self.formatBytes(cost)))")
        }
    }
    
    /// Ruft eine gecachte Entität ab
    /// - Parameters:
    ///   - key: Der Cache-Schlüssel
    ///   - type: Der erwartete Typ der Entität
    /// - Returns: Die gecachte Entität oder nil wenn nicht gefunden/abgelaufen
    func getCachedEntity<T>(forKey key: String, type: T.Type) -> T? {
        return cacheQueue.sync {
            guard let entry = self.cache.object(forKey: NSString(string: key)) else {
                print("🔍 Cache miss: \(key)")
                return nil
            }
            
            if entry.isExpired {
                print("⏰ Cache expired: \(key)")
                self.cache.removeObject(forKey: NSString(string: key))
                self.removeKeyFromTracker(key)
                return nil
            }
            
            print("✅ Cache hit: \(key)")
            return entry.data as? T
        }
    }
    
    /// Cached eine Entität nur wenn sie noch nicht existiert
    /// - Parameters:
    ///   - entity: Die zu cachende Entität
    ///   - key: Der Cache-Schlüssel
    ///   - ttl: Time-to-Live in Sekunden
    /// - Returns: true wenn gecacht wurde, false wenn bereits vorhanden
    func cacheEntityIfNotExists(_ entity: Any, forKey key: String, ttl: TimeInterval = 300) -> Bool {
        return cacheQueue.sync(flags: .barrier) {
            // Prüfe ob bereits vorhanden und nicht abgelaufen
            if let existingEntry = self.cache.object(forKey: NSString(string: key)),
               !existingEntry.isExpired {
                print("📋 Cache already exists: \(key)")
                return false
            }
            
            // Cache die neue Entität
            let entry = CacheEntry(data: entity, expirationDate: Date().addingTimeInterval(ttl))
            let cost = self.estimateSize(of: entity)
            
            self.cache.setObject(entry, forKey: NSString(string: key), cost: cost)
            
            self.keyTrackerQueue.async(flags: .barrier) {
                self.keyTracker.insert(key)
            }
            
            print("🆕 Cached new entity: \(key)")
            return true
        }
    }
    
    /// Invalidiert den gesamten Cache
    func invalidateCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let cachedCount = self.keyTracker.count
            self.cache.removeAllObjects()
            
            self.keyTrackerQueue.async(flags: .barrier) {
                self.keyTracker.removeAll()
            }
            
            print("🗑️ Cache invalidated: \(cachedCount) entries removed")
        }
    }
    
    /// Invalidiert Cache-Einträge basierend auf Schlüssel-Pattern
    /// - Parameter pattern: Regex-Pattern für Schlüssel-Matching
    func invalidateCache(matching pattern: String) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let keysToRemove = self.getAllCacheKeys().filter { key in
                guard let regex = regex else { return false }
                let range = NSRange(location: 0, length: key.count)
                return regex.firstMatch(in: key, options: [], range: range) != nil
            }
            
            for key in keysToRemove {
                self.cache.removeObject(forKey: NSString(string: key))
                self.removeKeyFromTracker(key)
            }
            
            print("🎯 Pattern invalidation '\(pattern)': \(keysToRemove.count) entries removed")
        }
    }
    
    /// Entfernt abgelaufene Cache-Einträge
    func invalidateExpiredEntries() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let allKeys = self.getAllCacheKeys()
            var expiredCount = 0
            
            for key in allKeys {
                if let entry = self.cache.object(forKey: NSString(string: key)),
                   entry.isExpired {
                    self.cache.removeObject(forKey: NSString(string: key))
                    self.removeKeyFromTracker(key)
                    expiredCount += 1
                }
            }
            
            if expiredCount > 0 {
                print("⏰ Expired entries cleanup: \(expiredCount) entries removed")
            }
        }
    }
    
    /// Liefert Cache-Statistiken
    /// - Returns: Cache-Statistiken
    func getCacheStatistics() -> CacheStatistics {
        return cacheQueue.sync {
            let allKeys = self.getAllCacheKeys()
            let totalEntries = allKeys.count
            var expiredCount = 0
            var totalSize = 0
            
            for key in allKeys {
                if let entry = self.cache.object(forKey: NSString(string: key)) {
                    if entry.isExpired {
                        expiredCount += 1
                    }
                    totalSize += self.estimateSize(of: entry.data)
                }
            }
            
            return CacheStatistics(
                totalEntries: totalEntries,
                totalSize: totalSize,
                hitRate: 0.0, // Würde in echter Implementierung berechnet
                expiredEntries: expiredCount
            )
        }
    }
    
    // MARK: - Private Hilfsmethoden
    
    /// Schätzt die Größe eines Objekts
    /// - Parameter object: Das zu schätzende Objekt
    /// - Returns: Geschätzte Größe in Bytes
    private func estimateSize(of object: Any) -> Int {
        if let string = object as? String {
            return string.utf8.count
        } else if let data = object as? Data {
            return data.count
        } else if let array = object as? [Any] {
            return array.reduce(0) { $0 + estimateSize(of: $1) }
        } else if let dict = object as? [String: Any] {
            return dict.reduce(0) { total, pair in
                total + estimateSize(of: pair.key) + estimateSize(of: pair.value)
            }
        } else {
            // Default-Schätzung für komplexe Objekte
            return 1024
        }
    }
    
    /// Liefert alle Cache-Schlüssel
    /// - Returns: Array aller Cache-Schlüssel
    private func getAllCacheKeys() -> [String] {
        return keyTrackerQueue.sync {
            return Array(self.keyTracker)
        }
    }
    
    /// Entfernt einen Schlüssel aus dem Key-Tracker
    /// - Parameter key: Der zu entfernende Schlüssel
    private func removeKeyFromTracker(_ key: String) {
        keyTrackerQueue.async(flags: .barrier) { [weak self] in
            self?.keyTracker.remove(key)
        }
    }
    
    /// Formatiert Bytes in lesbare Darstellung
    /// - Parameter bytes: Anzahl Bytes
    /// - Returns: Formatierte String-Darstellung
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Startet periodische Cache-Bereinigung
    private func startPeriodicCleanup() {
        // Alle 5 Minuten abgelaufene Einträge entfernen
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.invalidateExpiredEntries()
        }
        
        print("🔄 Periodic cache cleanup scheduled (every 5 minutes)")
    }
}

// MARK: - NSCacheDelegate

extension SyncCacheManager: NSCacheDelegate {
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        // Wird aufgerufen wenn NSCache ein Objekt entfernt
        print("📤 Cache eviction: Object removed due to memory pressure")
    }
}

// MARK: - Cache-Entry und Statistiken

/// Cache-Eintrag mit Ablaufzeit
private class CacheEntry {
    let data: Any
    let expirationDate: Date
    let createdAt: Date
    
    init(data: Any, expirationDate: Date) {
        self.data = data
        self.expirationDate = expirationDate
        self.createdAt = Date()
    }
    
    /// Prüft ob der Eintrag abgelaufen ist
    var isExpired: Bool {
        return Date() > expirationDate
    }
    
    /// Verbleibendes TTL in Sekunden
    var remainingTTL: TimeInterval {
        return max(0, expirationDate.timeIntervalSinceNow)
    }
    
    /// Alter des Eintrags in Sekunden
    var age: TimeInterval {
        return Date().timeIntervalSince(createdAt)
    }
}

/// Cache-Statistiken
struct CacheStatistics {
    let totalEntries: Int
    let totalSize: Int
    let hitRate: Double
    let expiredEntries: Int
    
    /// Formatierte String-Darstellung
    var description: String {
        return """
        📊 Cache Statistics:
        - Total Entries: \(totalEntries)
        - Total Size: \(ByteCountFormatter().string(fromByteCount: Int64(totalSize)))
        - Hit Rate: \(String(format: "%.1f", hitRate * 100))%
        - Expired Entries: \(expiredEntries)
        """
    }
} 