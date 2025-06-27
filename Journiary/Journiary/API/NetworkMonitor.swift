//
//  NetworkMonitor.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import Foundation
import Network
import Combine

/// Status der Netzwerkverbindung
enum ConnectionStatus {
    case connected
    case disconnected
}

/// Typ der Netzwerkverbindung
enum ConnectionType {
    case wifi
    case cellular
    case ethernet
    case unknown
}

/// Überwacht die Netzwerkverbindung und informiert über Änderungen
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var status: ConnectionStatus = .disconnected
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive = false
    @Published var isConstrained = false
    
    private init() {
        startMonitoring()
    }
    
    /// Startet die Überwachung der Netzwerkverbindung
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Aktualisiere den Verbindungsstatus
                self.status = path.status == .satisfied ? .connected : .disconnected
                
                // Aktualisiere den Verbindungstyp
                self.connectionType = self.getConnectionType(path: path)
                
                // Aktualisiere die Verbindungseigenschaften
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained
                
                // Benachrichtige über Änderungen
                self.handleConnectionChange()
            }
        }
        
        monitor.start(queue: queue)
    }
    
    /// Stoppt die Überwachung der Netzwerkverbindung
    func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Ermittelt den Typ der Netzwerkverbindung
    /// - Parameter path: Der Netzwerkpfad
    /// - Returns: Der Typ der Netzwerkverbindung
    private func getConnectionType(path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
    
    /// Behandelt Änderungen der Netzwerkverbindung
    private func handleConnectionChange() {
        // Wenn die Verbindung wiederhergestellt wurde, versuche ausstehende Operationen zu verarbeiten
        if status == .connected {
            processOfflineQueue()
        }
    }
    
    /// Verarbeitet die Offline-Warteschlange, wenn eine Verbindung verfügbar ist
    private func processOfflineQueue() {
        let settings = AppSettings.shared
        let offlineQueue = OfflineQueue.shared
        
        // Prüfe, ob die Synchronisierung aktiviert ist
        guard settings.syncEnabled else {
            return
        }
        
        // Prüfe, ob die WLAN-Einschränkung aktiviert ist und erfüllt wird
        if settings.syncOnlyOnWifi && connectionType != .wifi {
            return
        }
        
        // Erstelle einen neuen Core Data-Kontext für die Verarbeitung
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Verarbeite die Warteschlange
        offlineQueue.processQueue(context: backgroundContext) { _ in
            // Nichts zu tun, da die Warteschlange selbst die Operationen verwaltet
        }
    }
    
    /// Prüft, ob die aktuelle Verbindung die Synchronisierungsbedingungen erfüllt
    /// - Returns: `true`, wenn die Verbindung die Bedingungen erfüllt, sonst `false`
    func canSync() -> Bool {
        let settings = AppSettings.shared
        
        // Prüfe, ob die Synchronisierung aktiviert ist
        guard settings.syncEnabled else {
            return false
        }
        
        // Prüfe, ob eine Verbindung verfügbar ist
        guard status == .connected else {
            return false
        }
        
        // Prüfe, ob die WLAN-Einschränkung aktiviert ist und erfüllt wird
        if settings.syncOnlyOnWifi && connectionType != .wifi {
            return false
        }
        
        // Prüfe, ob die Einschränkung für teure Verbindungen aktiviert ist
        if settings.avoidExpensiveConnections && isExpensive {
            return false
        }
        
        return true
    }
} 