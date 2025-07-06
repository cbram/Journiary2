//
//  NetworkProvider.swift
//  Journiary
//
//  Created by Gemini on 08.06.25.
//

import Foundation
import Apollo
import ApolloAPI

@MainActor
class NetworkProvider {
    
    private(set) var apollo: ApolloClient
    
    // MARK: - Singleton Instance
    
    static let shared = NetworkProvider()
    
    // MARK: - Public Methods
    
    public func resetClient() {
        self.apollo = NetworkProvider.createClient()
        print("ApolloClient wurde zurückgesetzt und neu initialisiert.")
    }
    
    // MARK: - Initialization
    
    private init() {
        self.apollo = NetworkProvider.createClient()
    }
    
    // MARK: - Private Factory
    
    static func getBackendURL() -> String {
        // Priority:
        // 1. Manual override from UserDefaults (highest priority)
        if let userURL = UserDefaults.standard.string(forKey: "backendURL"), !userURL.isEmpty {
            print("Verwende benutzerdefinierte URL aus UserDefaults: \(userURL)")
            return userURL
        }
        
        // 2. Configuration from plist (Debug vs. Production)
        guard let path = Bundle.main.path(forResource: "Configuration", ofType: "plist"),
              let configDict = NSDictionary(contentsOfFile: path) as? [String: String] else {
            fatalError("Configuration.plist nicht gefunden oder fehlerhaft. Stellen Sie sicher, dass die Datei zum Target gehört.")
        }
        
        #if DEBUG
        let key = "backendURL_debug"
        #else
        let key = "backendURL_production"
        #endif
        
        guard let urlFromConfig = configDict[key] else {
            fatalError("'\(key)' nicht in Configuration.plist gefunden.")
        }
        
        print("Verwende URL aus Konfiguration ('\(key)'): \(urlFromConfig)")
        return urlFromConfig
    }
    
    private static func createClient() -> ApolloClient {
        let store = ApolloStore()
        
        let backendURLString = getBackendURL()
        
        guard let url = URL(string: backendURLString) else {
            fatalError("Ungültige Backend-URL: \(backendURLString)")
        }
        
        print("ApolloClient wird mit URL initialisiert: \(url)")

        let client = URLSessionClient()
        let provider = NetworkInterceptorProvider(store: store, client: client)
        let transport = RequestChainNetworkTransport(
            interceptorProvider: provider,
            endpointURL: url
        )
        
        return ApolloClient(networkTransport: transport, store: store)
    }
} 