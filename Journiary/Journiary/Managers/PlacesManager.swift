import Foundation
import CoreLocation

// MARK: - PlaceSearchResult Model
struct PlaceSearchResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let formattedAddress: String
    let latitude: Double
    let longitude: Double
    let country: String
    let region: String?
    let placeType: String?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PlaceSearchResult, rhs: PlaceSearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - PlacesManager
@MainActor
class PlacesManager: ObservableObject {
    @Published var searchResults: [PlaceSearchResult] = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    // Mapping von deutschen und englischen Ländernamen auf ISO-3166-1 country codes
    private let countryNameToCode: [String: String] = [
        // Europa & Nordamerika
        "deutschland": "de", "germany": "de",
        "frankreich": "fr", "france": "fr",
        "italien": "it", "italy": "it",
        "spanien": "es", "spain": "es",
        "schweiz": "ch", "switzerland": "ch",
        "österreich": "at", "austria": "at",
        "niederlande": "nl", "netherlands": "nl", "holland": "nl",
        "belgien": "be", "belgium": "be",
        "dänemark": "dk", "denmark": "dk",
        "polen": "pl", "poland": "pl",
        "tschechien": "cz", "czechia": "cz", "czech republic": "cz",
        "ungarn": "hu", "hungary": "hu",
        "portugal": "pt",
        "griechenland": "gr", "greece": "gr",
        "kroatien": "hr", "croatia": "hr",
        "norwegen": "no", "norway": "no",
        "schweden": "se", "sweden": "se",
        "finnland": "fi", "finland": "fi",
        "island": "is", "iceland": "is",
        "irland": "ie", "ireland": "ie",
        "großbritannien": "gb", "england": "gb", "united kingdom": "gb", "uk": "gb", "schottland": "gb", "wales": "gb",
        "usa": "us", "vereinigte staaten": "us", "united states": "us", "amerika": "us", "united states of america": "us",
        "kanada": "ca", "canada": "ca",
        "australien": "au", "australia": "au",
        "neuseeland": "nz", "new zealand": "nz",
        // Südamerika
        "argentinien": "ar", "argentina": "ar",
        "brasilien": "br", "brazil": "br",
        "chile": "cl",
        "kolumbien": "co", "colombia": "co",
        "peru": "pe",
        "ecuador": "ec",
        "bolivien": "bo", "bolivia": "bo",
        "paraguay": "py",
        "uruguay": "uy",
        "venezuela": "ve",
        "suriname": "sr",
        "guyana": "gy",
        // Afrika
        "ägypten": "eg", "egypt": "eg",
        "südafrika": "za", "south africa": "za",
        "nigeria": "ng",
        "kenia": "ke", "kenya": "ke",
        "marokko": "ma", "morocco": "ma",
        "algerien": "dz", "algeria": "dz",
        "tunesien": "tn", "tunisia": "tn",
        "ghana": "gh",
        "tansania": "tz", "tanzania": "tz",
        "uganda": "ug",
        "angola": "ao",
        "mosambik": "mz", "mozambique": "mz",
        "senegal": "sn",
        "elfenbeinküste": "ci", "ivory coast": "ci", "côte d'ivoire": "ci",
        "kamerun": "cm", "cameroon": "cm",
        "sambia": "zm", "zambia": "zm",
        "simbabwe": "zw", "zimbabwe": "zw",
        "äthiopien": "et", "ethiopia": "et",
        "sudan": "sd",
        "kongo": "cd", "congo": "cd",
        "ruanda": "rw", "rwanda": "rw",
        "botswana": "bw",
        "namibia": "na",
        "madagaskar": "mg", "madagascar": "mg",
        "mauretanien": "mr", "mauritania": "mr",
        "mali": "ml",
        "burkina faso": "bf",
        "niger": "ne",
        "libyen": "ly", "libya": "ly",
        "tschad": "td", "chad": "td",
        "benin": "bj",
        "burundi": "bi",
        "gabun": "ga", "gabon": "ga",
        "gambia": "gm",
        "guinea": "gn",
        "lesotho": "ls",
        "liberia": "lr",
        "malawi": "mw",
        "mauritius": "mu",
        "seychellen": "sc", "seychelles": "sc",
        "sierra leone": "sl",
        "somalia": "so",
        "swasiland": "sz", "swaziland": "sz", "eswatini": "sz",
        "togo": "tg",
        "zentralafrikanische republik": "cf", "central african republic": "cf",
        "dschibuti": "dj", "djibouti": "dj",
        "eritrea": "er",
        "äquatorialguinea": "gq", "equatorial guinea": "gq",
        "kap verde": "cv", "cape verde": "cv",
        "komoren": "km", "comoros": "km",
        "são tomé und príncipe": "st", "sao tome and principe": "st"
    ]
    
    func searchPlaces(query: String, country: String? = nil) async {
        guard !query.isEmpty else { return }
        
        print("[PlacesManager] Starte Suche: query=\(query), country=\(country ?? "-")")
        let provider = UserDefaults.standard.string(forKey: "PlaceProvider") ?? "Nominatim"
        isSearching = true
        errorMessage = nil
        
        if provider == "Nominatim" {
            do {
                print("[PlacesManager][DEBUG] Starte Nominatim-Suche mit query=\(query), country=\(country ?? "-")")
                let results = try await performNominatimSearch(query: query, country: country)
                print("[PlacesManager][DEBUG] Nominatim Ergebnisse: \(results.count)")
                searchResults = results
            } catch {
                print("[PlacesManager][DEBUG] Fehler bei Nominatim-Suche: \(error)")
                errorMessage = "Fehler bei der Ortssuche (Nominatim): \(error.localizedDescription)"
                searchResults = []
            }
            isSearching = false
            return
        }
        
        // Google Places wie gehabt
        let apiKey = UserDefaults.standard.string(forKey: "GooglePlacesAPIKey") ?? ""
        guard !apiKey.isEmpty else {
            errorMessage = "Kein Google Places API-Key hinterlegt. Bitte im Profil eintragen."
            searchResults = []
            isSearching = false
            return
        }
        do {
            let results = try await performPlaceSearch(query: query, country: country, apiKey: apiKey)
            print("[PlacesManager] Google Places Ergebnisse: \(results.count)")
            searchResults = results
        } catch {
            errorMessage = "Fehler bei der Ortssuche: \(error.localizedDescription)"
            searchResults = []
        }
        isSearching = false
    }
    
    private func performPlaceSearch(query: String, country: String?, apiKey: String) async throws -> [PlaceSearchResult] {
        // Erstelle die Suchanfrage
        var searchQuery = query
        if let country = country, !country.isEmpty {
            searchQuery += ", \(country)"
        }
        print("[PlacesManager] Google Query: \(searchQuery)")
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://maps.googleapis.com/maps/api/place/textsearch/json?query=\(encodedQuery)&key=\(apiKey)"
        print("[PlacesManager] Google URL: \(urlString)")
        guard let url = URL(string: urlString) else {
            throw PlacesError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlacesError.networkError
        }
        let placesResponse = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
        guard placesResponse.status == "OK" else {
            throw PlacesError.apiError(placesResponse.status)
        }
        print("[PlacesManager] Google API Antwort: \(placesResponse.results.count) Ergebnisse, Status: \(placesResponse.status)")
        return placesResponse.results.map { place in
            // Extrahiere Land und Region aus den Adresskomponenten
            let country = extractCountry(from: place.addressComponents)
            let region = extractRegion(from: place.addressComponents)
            let placeType = place.types.first ?? "unknown"
            print("[PlacesManager] Ergebnis: \(place.name), Land: \(country), Region: \(region ?? "-")")
            return PlaceSearchResult(
                name: place.name,
                formattedAddress: place.formattedAddress,
                latitude: place.geometry.location.lat,
                longitude: place.geometry.location.lng,
                country: country,
                region: region,
                placeType: placeType
            )
        }
    }
    
    private func extractCountry(from components: [AddressComponent]) -> String {
        return components.first { $0.types.contains("country") }?.longName ?? ""
    }
    
    private func extractRegion(from components: [AddressComponent]) -> String? {
        return components.first { 
            $0.types.contains("administrative_area_level_1") 
        }?.longName
    }
    
    func clearResults() {
        searchResults = []
        errorMessage = nil
    }
    
    // Nominatim-Integration
    private func performNominatimSearch(query: String, country: String?) async throws -> [PlaceSearchResult] {
        // 1. Query vorverarbeiten
        print("[PlacesManager][DEBUG] performNominatimSearch: query=\(query), country=\(country ?? "-")")
        let (mainQuery, extractedCity, extractedCountry) = preprocessNominatimQuery(query)
        var usedCountryCode: String? = nil
        if let countryInput = (country ?? extractedCountry)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !countryInput.isEmpty {
            usedCountryCode = countryNameToCode[countryInput]
            if usedCountryCode == nil {
                print("[PlacesManager][DEBUG] Unbekanntes Land: \(countryInput)")
                errorMessage = "Land nicht erkannt. Bitte auf Deutsch oder Englisch eingeben (z.B. 'Frankreich', 'France')."
                return []
            }
        }
        print("[PlacesManager][DEBUG] mainQuery=\(mainQuery), extractedCity=\(extractedCity ?? "-"), usedCountryCode=\(usedCountryCode ?? "-")")

        // 1.1 Strukturierte Suche, wenn ein country_code angegeben ist
        if let countryCode = usedCountryCode {
            var urlComponents = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
            urlComponents.queryItems = [
                URLQueryItem(name: "city", value: mainQuery),
                URLQueryItem(name: "country", value: countryCode),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "addressdetails", value: "1"),
                URLQueryItem(name: "limit", value: "10")
            ]
            print("[PlacesManager][DEBUG] Strukturierte Nominatim-URL (ISO-Code): \(urlComponents.url?.absoluteString ?? "-")")
            guard let url = urlComponents.url else {
                print("[PlacesManager][DEBUG] Fehler: Ungültige strukturierte URL")
                throw PlacesError.invalidURL
            }
            var request = URLRequest(url: url)
            request.setValue("JourniaryApp/1.0 (your@email.com)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("[PlacesManager][DEBUG] HTTP Status: \(httpResponse.statusCode)")
            }
            print("[PlacesManager][DEBUG] Antwort (strukturiert, ISO-Code): \(String(data: data, encoding: .utf8) ?? "-")")
            let nominatimResults = try JSONDecoder().decode([NominatimResult].self, from: data)
            // Nach country_code filtern
            let filteredResults = nominatimResults.filter { result in
                (result.address.country_code?.lowercased() ?? "") == countryCode
            }
            if !filteredResults.isEmpty {
                return filteredResults.map { result in
                    PlaceSearchResult(
                        name: result.display_name.components(separatedBy: ",").first ?? result.display_name,
                        formattedAddress: result.display_name,
                        latitude: Double(result.lat) ?? 0.0,
                        longitude: Double(result.lon) ?? 0.0,
                        country: result.address.country ?? "",
                        region: result.address.state ?? result.address.county,
                        placeType: result.type
                    )
                }
            }
            print("[PlacesManager][DEBUG] Keine Ergebnisse bei strukturierter Suche (ISO-Code)")
            // Fallback auf Freitextsuche, falls keine Ergebnisse
        }

        // 2. Hauptsuche (Freitext, ohne Land!)
        let urlString = "https://nominatim.openstreetmap.org/search?format=json&q=\(mainQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&addressdetails=1&limit=10"
        print("[PlacesManager][DEBUG] Freitext Nominatim-URL: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("[PlacesManager][DEBUG] Fehler: Ungültige Freitext-URL")
            throw PlacesError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("JourniaryApp/1.0 (your@email.com)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            print("[PlacesManager][DEBUG] HTTP Status: \(httpResponse.statusCode)")
        }
        print("[PlacesManager][DEBUG] Antwort (Freitext): \(String(data: data, encoding: .utf8) ?? "-")")
        let nominatimResults = try JSONDecoder().decode([NominatimResult].self, from: data)
        if !nominatimResults.isEmpty {
            return nominatimResults.map { result in
                PlaceSearchResult(
                    name: result.display_name.components(separatedBy: ",").first ?? result.display_name,
                    formattedAddress: result.display_name,
                    latitude: Double(result.lat) ?? 0.0,
                    longitude: Double(result.lon) ?? 0.0,
                    country: result.address.country ?? "",
                    region: result.address.state ?? result.address.county,
                    placeType: result.type
                )
            }
        }
        print("[PlacesManager][DEBUG] Keine Ergebnisse bei Freitextsuche")
        // 3. Fallback: Nur erster Teil des Queries (falls noch nicht identisch)
        if mainQuery != query {
            let fallbackQuery = (query.components(separatedBy: ",").first ?? query).trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackUrlString = "https://nominatim.openstreetmap.org/search?format=json&q=\(fallbackQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&addressdetails=1&limit=10"
            print("[PlacesManager][DEBUG] Fallback Nominatim-URL: \(fallbackUrlString)")
            guard let fallbackUrl = URL(string: fallbackUrlString) else {
                print("[PlacesManager][DEBUG] Fehler: Ungültige Fallback-URL")
                throw PlacesError.invalidURL
            }
            var fallbackRequest = URLRequest(url: fallbackUrl)
            fallbackRequest.setValue("JourniaryApp/1.0 (your@email.com)", forHTTPHeaderField: "User-Agent")
            let (fallbackData, fallbackResponse) = try await URLSession.shared.data(for: fallbackRequest)
            if let fallbackHttpResponse = fallbackResponse as? HTTPURLResponse {
                print("[PlacesManager][DEBUG] HTTP Status (Fallback): \(fallbackHttpResponse.statusCode)")
            }
            print("[PlacesManager][DEBUG] Antwort (Fallback): \(String(data: fallbackData, encoding: .utf8) ?? "-")")
            let fallbackResults = try JSONDecoder().decode([NominatimResult].self, from: fallbackData)
            if !fallbackResults.isEmpty {
                return fallbackResults.map { result in
                    PlaceSearchResult(
                        name: result.display_name.components(separatedBy: ",").first ?? result.display_name,
                        formattedAddress: result.display_name,
                        latitude: Double(result.lat) ?? 0.0,
                        longitude: Double(result.lon) ?? 0.0,
                        country: result.address.country ?? "",
                        region: result.address.state ?? result.address.county,
                        placeType: result.type
                    )
                }
            }
            print("[PlacesManager][DEBUG] Keine Ergebnisse bei Fallback-Suche")
        }
        // Wenn alles fehlschlägt, leere Liste
        print("[PlacesManager][DEBUG] Nominatim: Keine Ergebnisse für alle Suchvarianten")
        return []
    }
    
    // Hilfsfunktion zur Query-Vorverarbeitung für Nominatim
    private func preprocessNominatimQuery(_ query: String) -> (mainQuery: String, city: String?, country: String?) {
        // Begriffe, die entfernt werden sollen
        let removeWords = ["stadt", "dorf", "ort", "region", "gemeinde", "city", "village", "town", "area"]
        // Query aufsplitten
        let parts = query.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var mainQuery = parts.first ?? query
        var city: String? = nil
        var country: String? = nil
        if parts.count > 1 {
            city = parts[0]
            country = parts[1]
        }
        // Entferne unerwünschte Wörter
        mainQuery = removeWords.reduce(mainQuery) { result, word in
            result.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }.trimmingCharacters(in: .whitespacesAndNewlines)
        city = city.map { c in
            removeWords.reduce(c) { result, word in
                result.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
            }.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        country = country?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (mainQuery, city, country)
    }
    
    // Nominatim-Modelle
    private struct NominatimResult: Codable {
        let display_name: String
        let lat: String
        let lon: String
        let type: String?
        let address: NominatimAddress
    }
    private struct NominatimAddress: Codable {
        let country: String?
        let state: String?
        let county: String?
        let country_code: String?
    }
}

// MARK: - Google Places API Response Models
private struct GooglePlacesResponse: Codable {
    let results: [GooglePlace]
    let status: String
}

private struct GooglePlace: Codable {
    let name: String
    let formattedAddress: String
    let geometry: PlaceGeometry
    let types: [String]
    let addressComponents: [AddressComponent]
    
    enum CodingKeys: String, CodingKey {
        case name
        case formattedAddress = "formatted_address"
        case geometry
        case types
        case addressComponents = "address_components"
    }
}

private struct PlaceGeometry: Codable {
    let location: PlaceLocation
}

private struct PlaceLocation: Codable {
    let lat: Double
    let lng: Double
}

private struct AddressComponent: Codable {
    let longName: String
    let shortName: String
    let types: [String]
    
    enum CodingKeys: String, CodingKey {
        case longName = "long_name"
        case shortName = "short_name"
        case types
    }
}

// MARK: - Error Handling
enum PlacesError: LocalizedError {
    case invalidURL
    case networkError
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ungültige URL für die Ortssuche"
        case .networkError:
            return "Netzwerkfehler bei der Ortssuche"
        case .apiError(let status):
            return "API-Fehler: \(status)"
        }
    }
} 