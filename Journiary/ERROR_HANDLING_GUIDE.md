# Error Handling System - Travel Companion

## 🎯 Übersicht

Das neue Error Handling System in Travel Companion bietet benutzerfreundliche Fehlerbehandlung mit automatischen Retry-Optionen und detailliertem Feedback für verschiedene Fehlerszenarien.

## ✨ Features

### 1. **Backend Offline → User-friendly Error**
- **Erkennung**: Server nicht erreichbar, Connection refused
- **Anzeige**: "Der Server ist momentan offline. Bitte versuchen Sie es in einigen Minuten erneut."
- **Retry**: Automatische Wiederholung möglich
- **Netzwerkstatus**: Live-Anzeige der Internetverbindung

### 2. **Invalid Query → GraphQL Error angezeigt**
- **Erkennung**: Ungültige GraphQL Queries, Syntaxfehler
- **Anzeige**: Benutzerfreundliche Nachricht mit technischen Details (optional)
- **Kategorisierung**: Server-Fehler, Validierungsfehler, Parse-Fehler
- **Retry**: Je nach Fehlertyp verfügbar

### 3. **Network Timeout → Retry-Option**
- **Erkennung**: Zeitüberschreitung bei Netzwerkoperationen
- **Anzeige**: "Die Anfrage hat zu lange gedauert. Bitte versuchen Sie es erneut."
- **Retry**: Automatisch mit Backoff-Strategie
- **Timeout**: 30 Sekunden mit 2 automatischen Wiederholungen

## 🧪 Testing

### Error Handling Test View

Die App enthält eine dedizierte Test-View für alle Error-Szenarien:

**Zugriff**: Einstellungen → Debug & Entwicklung → Error Handling Test

**Verfügbare Tests**:
1. **Backend Offline** - Simuliert nicht erreichbaren Server
2. **Netzwerk-Fehler** - Simuliert Internetverbindungsprobleme
3. **Invalid Query** - Simuliert ungültige GraphQL Syntax
4. **Timeout** - Simuliert Zeitüberschreitung
5. **Auth Fehler** - Simuliert Authentifizierungsprobleme
6. **Parse Fehler** - Simuliert JSON/Data Parsing Probleme

### Manuelle Tests

```bash
# Backend offline testen
# 1. Backend Server stoppen
# 2. Login versuchen oder GraphQL Query ausführen
# 3. Benutzerfreundliche Fehlermeldung prüfen

# Network timeout testen
# 1. Flugmodus aktivieren → deaktivieren (langsame Verbindung simulieren)
# 2. Große GraphQL Operation ausführen
# 3. Timeout-Handling und Retry prüfen

# Invalid Query testen
# 1. In Error Test View "Invalid Query" Button drücken
# 2. GraphQL Syntaxfehler wird simuliert
# 3. Technische Details optional anzeigbar
```

## 🔧 Integration

### In bestehende Views

```swift
struct MyView: View {
    @StateObject private var errorHandler = ErrorHandler.shared
    
    var body: some View {
        // Your view content
        .handleErrors() // Automatisches Error Handling
        .onReceive(someService.$error) { error in
            if let error = error {
                errorHandler.handle(error) {
                    // Optional: Retry-Aktion
                    performRetryOperation()
                }
            }
        }
    }
}
```

### Manuelle Error Behandlung

```swift
// Fehler mit Retry-Option behandeln
ErrorHandler.shared.handle(error) {
    // Retry-Logik
    retryOperation()
}

// Fehler ohne Retry behandeln
ErrorHandler.shared.handle(error)
```

## 📊 Error Kategorien

| Kategorie | Icon | Farbe | Retry | Beschreibung |
|-----------|------|-------|-------|--------------|
| **Network** | wifi.exclamationmark | Orange | ✅ | Verbindungsprobleme |
| **Authentication** | person.badge.key | Rot | ❌ | Login-Probleme |
| **Server** | server.rack | Rot | ✅ | Backend-Probleme |
| **Validation** | exclamationmark.triangle | Gelb | ❌ | Eingabefehler |
| **Cache** | internaldrive | Blau | ✅ | Lokale Speicherprobleme |
| **Parsing** | doc.text | Lila | ✅ | Datenverarbeitung |
| **Unknown** | questionmark.circle | Grau | ✅ | Unbekannte Fehler |

## 🔧 Konfiguration

### Timeout-Einstellungen

```swift
// GraphQL Network Client
.timeout(.seconds(30), scheduler: DispatchQueue.main)
.retry(2) // 2 automatische Wiederholungen
```

### Backend URL

Das System verwendet automatisch die konfigurierte Backend URL aus `AppSettings.shared.backendURL` - keine hardcodierten URLs.

## 🚀 Production Ready

- ✅ Keine hardcodierten URLs oder Demo-Daten
- ✅ Benutzerfreundliche Fehlermeldungen auf Deutsch
- ✅ Automatische Retry-Logik mit Backoff
- ✅ Network Status Integration
- ✅ Technische Details optional verfügbar
- ✅ Logging für Debugging und Analytics
- ✅ Responsive UI mit Animationen

## 🐛 Debugging

### Error Logs

Alle Fehler werden detailliert geloggt:

```
🚨 Error handled by ErrorHandler:
📋 Original: URLError(_nsError: Error Domain=NSURLErrorDomain Code=-1009)
👤 User-Friendly: Keine Internetverbindung - Bitte prüfen Sie Ihre Netzwerkeinstellungen.
🏷️ Category: network
⚠️ Severity: high
🔄 Can Retry: true
```

### Test Results

Die Error Test View zeigt detaillierte Testergebnisse mit Timestamps für jede durchgeführte Operation.

## 📱 UI/UX Features

- **Animierte Icons** mit SF Symbols
- **Severity Badges** (Niedrig/Mittel/Hoch/Kritisch)
- **Netzwerkstatus-Anzeige** bei Netzwerkfehlern
- **Technische Details** ausklappbar für Entwickler
- **Retry-Button** mit Loading-Animation
- **Responsive Design** für alle Bildschirmgrößen

Das Error Handling System ist vollständig in die App integriert und sofort einsatzbereit! 