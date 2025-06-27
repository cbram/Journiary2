# [MIGRATION] Schritt 1: Backend-Integration Setup

## 🎯 Ziel
Grundlegende Infrastruktur für Backend-Integration schaffen mit Einstellungs-UI zur Auswahl des Speichermodus (CloudKit/Backend/Hybrid) und Backend-Konfiguration.

## 📋 Aufgaben

- [ ] **AppSettings.swift** - Zentrale App-Einstellungen mit UserDefaults
- [ ] **StorageMode.swift** - Enum für CloudKit/Backend/Hybrid-Modi
- [ ] **BackendSettingsView.swift** - UI für Backend-URL, Credentials
- [ ] **NetworkMonitor.swift** - Network-Status-Überwachung
- [ ] **APIClient.swift** - Basis HTTP-Client für Backend-Kommunikation
- [ ] **SettingsView** erweitern - Integration der Backend-Einstellungen

## ✅ Akzeptanzkriterien

- [ ] App kompiliert erfolgreich
- [ ] Backend-Settings sind über UI erreichbar
- [ ] Speichermodus kann gewechselt werden
- [ ] Backend-Verbindungstest funktioniert
- [ ] Network-Status wird angezeigt
- [ ] Einstellungen bleiben nach App-Neustart erhalten

## 🤖 KI-Prompt für Implementation

```
Als erfahrener iOS-Entwickler mit SwiftUI und Core Data Expertise implementiere bitte:

SCHRITT 1: Backend-Integration Setup für Travel Companion iOS App

Erstelle folgende Komponenten:

1. **AppSettings.swift** (ObservableObject)
   - UserDefaults-basierte Einstellungen
   - StorageMode (CloudKit/Backend/Hybrid)
   - Backend-URL, Username, Password
   - Auto-Sync-Einstellungen
   - Published Properties für SwiftUI

2. **StorageMode.swift** (Enum)
   - Cases: .cloudKit, .backend, .hybrid
   - User-friendly descriptions
   - Default-Werte

3. **BackendSettingsView.swift** (SwiftUI View)
   - Backend-URL Input Field
   - Username/Password Fields
   - "Test Connection" Button
   - Storage Mode Picker
   - Auto-Sync Toggle

4. **NetworkMonitor.swift** (ObservableObject)
   - Network.framework Integration
   - Published isConnected Property
   - Connection type detection

5. **APIClient.swift** (Basic HTTP Client)
   - URL configuration from AppSettings
   - Basic authentication
   - Connection test endpoint
   - Error handling

6. **SettingsView Erweiterung**
   - Backend Settings Section hinzufügen
   - Navigation zu BackendSettingsView

Berücksichtige dabei:
- SwiftUI Best Practices mit @Published und @ObservedObject
- UserDefaults für Einstellungen-Persistierung
- Sichere Credential-Speicherung (Keychain für Passwörter)
- Network.framework für Verbindungsüberwachung
- Accessibility Labels
- German Localization
- Error Handling mit AlertPresentation
```

## 🔗 Abhängigkeiten

- Abhängig von: Keine (Startpunkt)
- Blockiert: #2 (Benutzer-System), #3 (GraphQL Client)

## 🧪 Test-Plan

1. **Backend-Einstellungen öffnen**
   - Gehe zu Einstellungen
   - Navigiere zu "Backend-Konfiguration"
   - Alle UI-Elemente sind sichtbar

2. **Backend-URL konfigurieren**
   - Gebe "http://localhost:4001/graphql" ein
   - Speichere Einstellungen
   - Starte App neu → URL ist noch vorhanden

3. **Verbindungstest**
   - Klicke "Verbindung testen"
   - Bei laufendem Backend: ✅ Erfolgreich
   - Bei gestopptem Backend: ❌ Fehler-Message

4. **Speichermodus wechseln**
   - Wähle verschiedene Modi aus Picker
   - Einstellung wird gespeichert
   - UI passt sich entsprechend an

## 📱 UI/UX Mockups

```
Settings
├── Backend-Konfiguration
    ├── Speichermodus: [CloudKit ▼]
    ├── Backend-URL: [Text Field]
    ├── Benutzername: [Text Field] 
    ├── Passwort: [Secure Field]
    ├── [Verbindung testen] Button
    ├── Auto-Sync: [Toggle]
    └── Netzwerk-Status: 🟢 Verbunden
```

## ⚠️ Risiken & Überlegungen

- **Credential-Sicherheit**: Passwörter müssen in Keychain gespeichert werden
- **Network-Privacy**: Info.plist Network Usage Description hinzufügen
- **Backend-Verfügbarkeit**: Graceful Handling wenn Backend offline
- **URL-Validierung**: Prüfung auf gültige GraphQL-Endpoints

## 📚 Ressourcen

- [Apple Network Framework](https://developer.apple.com/documentation/network)
- [SwiftUI Settings Patterns](https://developer.apple.com/design/human-interface-guidelines/settings)
- [UserDefaults Best Practices](https://developer.apple.com/documentation/foundation/userdefaults)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services) 