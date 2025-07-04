//
//  DateFormatter+German.swift
//  Journiary
//
//  Created by AI Assistant on [Current Date]
//

import Foundation

extension DateFormatter {
    static let germanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    static let germanDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let germanCompactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "EE, dd.MM.yyyy"
        return formatter
    }()
    
    static let germanCompactDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "EE, dd.MM.yyyy • HH:mm"
        return formatter
    }()
    
    static let germanFullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "EEEE, dd. MMMM yyyy"
        return formatter
    }()
}

extension Date {
    var germanFormatted: String {
        return DateFormatter.germanDateTimeFormatter.string(from: self)
    }
    
    var germanFormattedCompact: String {
        return DateFormatter.germanCompactDateTimeFormatter.string(from: self)
    }
    
    var germanFormattedDateOnly: String {
        return DateFormatter.germanCompactDateFormatter.string(from: self)
    }
    
    var germanFormattedFull: String {
        return DateFormatter.germanFullDateFormatter.string(from: self)
    }
} 