//
//  CountryHelper.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import Foundation

struct CountryHelper {
    private static let countryCodeByName: [String: String] = {
        var nameToCode = [String: String]()
        for code in Locale.Region.isoRegions.map(\.identifier) {
            // German name
            if let name = Locale(identifier: "de_DE").localizedString(forRegionCode: code) {
                nameToCode[name] = code
            }
            // English name
            if let name = Locale(identifier: "en_US").localizedString(forRegionCode: code) {
                nameToCode[name] = code
            }
        }
        return nameToCode
    }()

    static func flag(for countryName: String) -> String {
        let trimmedName = countryName.trimmingCharacters(in: .whitespaces)
        
        guard let countryCode = countryCodeByName[trimmedName] else {
            return "🏳️" // Fallback
        }
        
        let base: UInt32 = 127397
        var s = ""
        for v in countryCode.uppercased().unicodeScalars {
            s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
        }
        return String(s)
    }
} 