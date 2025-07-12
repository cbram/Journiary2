//
//  SupabaseConfig.swift
//  Journiary
//
//  Created by Supabase Integration on 08.06.25.
//

import Foundation

struct SupabaseConfig {
    // MARK: - Supabase Configuration
    
    static let supabaseURL = "http://192.168.10.20:8000"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE"
    static let supabaseServiceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q"
    
    // MARK: - Validation
    
    static func validateConfiguration() -> Bool {
        guard !supabaseURL.isEmpty,
              !supabaseAnonKey.isEmpty,
              URL(string: supabaseURL) != nil else {
            print("⚠️ Supabase-Konfiguration ungültig!")
            return false
        }
        
        print("✅ Supabase-Konfiguration validiert")
        print("📍 URL: \(supabaseURL)")
        return true
    }
    
    // MARK: - Environment Detection
    
    static var isLocalNetwork: Bool {
        return supabaseURL.contains("192.168.") || supabaseURL.contains("localhost")
    }
    
    // MARK: - Network Configuration für lokales Netzwerk
    
    static func configureNetworkSecurity() {
        if isLocalNetwork {
            print("🔧 Lokales Netzwerk erkannt - HTTP-Verbindungen erlaubt")
            // Für lokale Entwicklung HTTP erlauben
            // In Info.plist: NSAppTransportSecurity -> NSAllowsArbitraryLoads = YES
        }
    }
} 