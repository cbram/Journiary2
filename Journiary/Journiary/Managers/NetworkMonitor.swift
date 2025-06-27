//
//  NetworkMonitor.swift
//  Journiary
//
//  Created by Christian Bram on 16.12.24.
//

import Foundation
import Network
import Combine

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive = false
    @Published var isConstrained = false
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        
        var displayName: String {
            switch self {
            case .wifi:
                return "WLAN"
            case .cellular:
                return "Mobilfunk"
            case .ethernet:
                return "Ethernet"
            case .unknown:
                return "Unbekannt"
            }
        }
        
        var iconName: String {
            switch self {
            case .wifi:
                return "wifi"
            case .cellular:
                return "antenna.radiowaves.left.and.right"
            case .ethernet:
                return "cable.connector"
            case .unknown:
                return "questionmark.circle"
            }
        }
    }
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStatus(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func stopMonitoring() {
        monitor.cancel()
    }
    
    private func updateConnectionStatus(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
    
    // MARK: - Convenience Methods
    
    var isWiFiConnected: Bool {
        return isConnected && connectionType == .wifi
    }
    
    var isCellularConnected: Bool {
        return isConnected && connectionType == .cellular
    }
    
    var connectionStatusText: String {
        if !isConnected {
            return "Keine Verbindung"
        }
        
        var status = connectionType.displayName
        
        if isExpensive {
            status += " (kostenpflichtig)"
        }
        
        if isConstrained {
            status += " (begrenzt)"
        }
        
        return status
    }
    
    var connectionQualityColor: String {
        if !isConnected {
            return "red"
        } else if isConstrained || (connectionType == .cellular && isExpensive) {
            return "orange"
        } else {
            return "green"
        }
    }
} 