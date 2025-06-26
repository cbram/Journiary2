//
//  WeatherManager.swift
//  Journiary
//
//  Created by AI Assistant on [Current Date]
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - Weather Data Models

struct WeatherData {
    let temperature: Double
    let weatherCondition: WeatherCondition
    let locationName: String
    
    var temperatureString: String {
        return String(format: "%.0f°", temperature)
    }
}

enum WeatherCondition: String, CaseIterable {
    case sunny = "sunny"
    case partlyCloudy = "partly-cloudy"
    case cloudy = "cloudy"
    case rainy = "rainy"
    case snowy = "snowy"
    case stormy = "stormy"
    case foggy = "foggy"
    case unknown = "unknown"
    
    var icon: String {
        switch self {
        case .sunny:
            return "sun.max.fill"
        case .partlyCloudy:
            return "cloud.sun.fill"
        case .cloudy:
            return "cloud.fill"
        case .rainy:
            return "cloud.rain.fill"
        case .snowy:
            return "cloud.snow.fill"
        case .stormy:
            return "cloud.bolt.fill"
        case .foggy:
            return "cloud.fog.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .sunny:
            return .orange
        case .partlyCloudy:
            return .blue
        case .cloudy:
            return .gray
        case .rainy:
            return .blue
        case .snowy:
            return .cyan
        case .stormy:
            return .purple
        case .foggy:
            return .gray
        case .unknown:
            return .secondary
        }
    }
    
    var description: String {
        switch self {
        case .sunny:
            return "Sonnig"
        case .partlyCloudy:
            return "Teilweise bewölkt"
        case .cloudy:
            return "Bewölkt"
        case .rainy:
            return "Regnerisch"
        case .snowy:
            return "Schnee"
        case .stormy:
            return "Gewitter"
        case .foggy:
            return "Nebelig"
        case .unknown:
            return "Unbekannt"
        }
    }
}

// MARK: - Weather Manager

@MainActor
class WeatherManager: ObservableObject {
    @Published var currentWeather: WeatherData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let session = URLSession.shared
    
    func fetchWeatherData(for coordinate: CLLocationCoordinate2D, locationName: String) async {
        isLoading = true
        errorMessage = nil
        
        // Prüfe ob API-Key konfiguriert ist
        let apiKey = UserDefaults.standard.string(forKey: "tomorrowIOAPIKey") ?? ""
        
        if apiKey.isEmpty {
            // Kein API-Key - verwende Demo-Wetter
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 Sekunden
            currentWeather = createRealisticDemoWeatherData(for: locationName, coordinate: coordinate)
        } else {
            // API-Key vorhanden - verwende echte API
            do {
                let weather = try await requestWeatherData(coordinate: coordinate, locationName: locationName, apiKey: apiKey)
                currentWeather = weather
            } catch {
                errorMessage = "Wetterdaten konnten nicht geladen werden"
                print("Weather API Fehler: \(error)")
                // Fallback auf Demo-Wetter bei API-Fehler
                currentWeather = createRealisticDemoWeatherData(for: locationName, coordinate: coordinate)
            }
        }
        
        isLoading = false
    }
    
    private func requestWeatherData(coordinate: CLLocationCoordinate2D, locationName: String, apiKey: String) async throws -> WeatherData {
        // Tomorrow.io API
        let urlString = "https://api.tomorrow.io/v4/weather/realtime?location=\(coordinate.latitude),\(coordinate.longitude)&apikey=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }
        
        let weatherResponse = try JSONDecoder().decode(TomorrowIOResponse.self, from: data)
        
        return WeatherData(
            temperature: weatherResponse.data.values.temperature,
            weatherCondition: mapTomorrowIOCondition(weatherResponse.data.values.weatherCode),
            locationName: locationName
        )
    }
    
    private func mapTomorrowIOCondition(_ weatherCode: Int) -> WeatherCondition {
        // Tomorrow.io weather codes mapping
        // https://docs.tomorrow.io/reference/data-layers-core
        switch weatherCode {
        case 1000: // Clear, Sunny
            return .sunny
        case 1100, 1101, 1102: // Mostly Clear, Partly Cloudy, Mostly Cloudy
            return .partlyCloudy
        case 1001, 1103: // Cloudy, Overcast
            return .cloudy
        case 2000, 2100: // Fog, Light Fog
            return .foggy
        case 4000, 4001, 4200, 4201: // Drizzle, Rain, Light Rain, Heavy Rain
            return .rainy
        case 5000, 5001, 5100, 5101: // Snow, Flurries, Light Snow, Heavy Snow
            return .snowy
        case 8000: // Thunderstorm
            return .stormy
        default:
            return .unknown
        }
    }
    
    // Verbesserte Demo-Wetter-Funktion
    func createRealisticDemoWeatherData(for locationName: String, coordinate: CLLocationCoordinate2D) -> WeatherData {
        // Realistische Temperaturen basierend auf Jahreszeit und ungefährer Region
        let currentDate = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: currentDate)
        
        // Temperatur basierend auf Jahreszeit (Deutschland/Europa)
        let baseTemp: Double
        switch month {
        case 12, 1, 2: // Winter
            baseTemp = Double.random(in: -2...8)
        case 3, 4, 5: // Frühling
            baseTemp = Double.random(in: 8...18)
        case 6, 7, 8: // Sommer
            baseTemp = Double.random(in: 18...28)
        case 9, 10, 11: // Herbst
            baseTemp = Double.random(in: 8...18)
        default:
            baseTemp = Double.random(in: 15...22)
        }
        
        // Wetterbedingungen basierend auf Jahreszeit
        let weatherConditions: [WeatherCondition]
        switch month {
        case 12, 1, 2: // Winter
            weatherConditions = [.cloudy, .rainy, .snowy, .foggy, .partlyCloudy]
        case 3, 4, 5: // Frühling
            weatherConditions = [.partlyCloudy, .sunny, .rainy, .cloudy]
        case 6, 7, 8: // Sommer
            weatherConditions = [.sunny, .partlyCloudy, .cloudy]
        case 9, 10, 11: // Herbst
            weatherConditions = [.cloudy, .rainy, .partlyCloudy, .foggy]
        default:
            weatherConditions = [.sunny, .partlyCloudy, .cloudy]
        }
        
        let condition = weatherConditions.randomElement() ?? .sunny
        
        // Temperatur je nach Wetterlage anpassen
        let adjustedTemp: Double
        switch condition {
        case .sunny:
            adjustedTemp = baseTemp + Double.random(in: 0...3)
        case .rainy, .stormy:
            adjustedTemp = baseTemp - Double.random(in: 1...4)
        case .snowy:
            adjustedTemp = min(baseTemp - Double.random(in: 0...5), 2)
        case .foggy:
            adjustedTemp = baseTemp - Double.random(in: 0...2)
        default:
            adjustedTemp = baseTemp
        }
        
        return WeatherData(
            temperature: adjustedTemp,
            weatherCondition: condition,
            locationName: locationName.isEmpty ? "Aktueller Standort" : locationName
        )
    }
    
    // Einfache Demo-Funktion für Fallback
    func createDemoWeatherData(for locationName: String) -> WeatherData {
        return createRealisticDemoWeatherData(
            for: locationName, 
            coordinate: CLLocationCoordinate2D(latitude: 52.5, longitude: 13.4)
        )
    }
}

// MARK: - API Response Models

private struct TomorrowIOResponse: Codable {
    let data: TomorrowIOData
}

private struct TomorrowIOData: Codable {
    let values: TomorrowIOValues
}

private struct TomorrowIOValues: Codable {
    let temperature: Double
    let weatherCode: Int
}

// MARK: - Errors

enum WeatherError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
} 