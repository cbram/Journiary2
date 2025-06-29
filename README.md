# Travel Companion App

Eine umfassende **Self-Hosting** Reisebegleiter-App für iOS, die es Benutzern ermöglicht, Reisen zu planen, Erinnerungen festzuhalten und Reiserouten aufzuzeichnen.

> **⚠️ WICHTIG: Diese App ist für Self-Hosting konzipiert.**  
> Es gibt **keine Default-Server-URLs** - Sie müssen Ihren eigenen Backend-Server betreiben oder CloudKit verwenden.

## Funktionen

### Grundfunktionen
- Reiseplanung und -verwaltung
- Erinnerungen mit Fotos, Videos und Text
- GPS-Tracking von Reiserouten
- Bucket-List für Reiseziele
- Tag-System zur Organisation

### Synchronisierung und Cloud-Speicher
- Flexible Speichermodi:
  - Lokal (nur auf dem Gerät)
  - CloudKit (iCloud-Synchronisierung)
  - Self-Hosted (eigener Backend-Server)
  - Hybrid (Kombination aus CloudKit und Self-Hosted)
- Vollständige Datensynchronisierung zwischen Geräten
- Medien-Synchronisierung mit automatischem Hoch- und Herunterladen

### Erweiterte Funktionen
- Offline-Modus mit automatischer Synchronisierung bei Wiederverbindung
- Konfliktlösung bei gleichzeitigen Änderungen
- Hintergrundsynchronisierung
- Netzwerküberwachung und adaptive Synchronisierung
- Konfigurierbare Synchronisierungseinstellungen:
  - Automatische Synchronisierung in konfigurierbaren Intervallen
  - WLAN-Beschränkung
  - Nur beim Laden synchronisieren
  - Teure Verbindungen vermeiden

## Technische Details

### Frontend (iOS)
- SwiftUI für moderne, deklarative Benutzeroberfläche
- Core Data für lokale Datenspeicherung
- MapKit und CoreLocation für Kartenintegration und GPS-Tracking
- PhotoKit für Medienintegration
- Combine für reaktive Programmierung

### Backend
- Node.js mit TypeScript
- GraphQL API mit Apollo Server
- TypeORM für Datenbankzugriff
- PostgreSQL als Datenbank
- MinIO für Medienspeicherung (S3-kompatibel)
- Docker für einfache Bereitstellung

## 🏠 Self-Hosting Setup

**Die App ist ausschließlich für Self-Hosting konzipiert** - es gibt keine vorkonfigurierten Server:

### Für End-User (App Store Download):
1. **Backend betreiben**: Eigenen Server mit Docker aufsetzen
2. **App konfigurieren**: Bei erstem Start Backend-URL eingeben
3. **Verbindung testen**: App validiert Server vor Nutzung

### Für Entwickler:
1. Repository klonen
2. Backend starten: `cd server-deployment && docker-compose up -d`
3. Schema downloaden: `BACKEND_URL=http://localhost:4001/graphql ./update_schema.sh`
4. App in Xcode öffnen und bauen

> **📖 Detaillierte Anleitung**: Siehe [SELF_HOSTING_GUIDE.md](SELF_HOSTING_GUIDE.md)

### Warum Self-Hosting?
- **🔒 Datenschutz**: Ihre Daten bleiben auf Ihrem Server
- **🛡️ Sicherheit**: Keine Abhängigkeit von Drittanbietern
- **⚙️ Kontrolle**: Vollständige Kontrolle über Ihre Infrastruktur
- **💰 Kosten**: Keine monatlichen Cloud-Gebühren

## Synchronisierungssystem

Das Synchronisierungssystem der App bietet folgende Funktionen:

- Bidirektionale Synchronisierung zwischen Core Data und Backend
- Intelligente Konfliktlösung mit verschiedenen Strategien:
  - Lokale Daten bevorzugen
  - Remote-Daten bevorzugen
  - Neuere Daten bevorzugen
  - Manuelle Auflösung
- Offline-Warteschlange für Änderungen bei fehlender Verbindung
- Automatische Wiederverbindung und Synchronisierung
- Priorisierte Synchronisierung wichtiger Daten

## Offline-Modus

Der Offline-Modus ermöglicht die vollständige Nutzung der App ohne Internetverbindung:

- Automatische Erkennung des Verbindungsstatus
- Speicherung aller Änderungen in einer Offline-Warteschlange
- Konfigurierbare maximale Speichergröße für Offline-Medien
- Automatische Synchronisierung bei Wiederverbindung
- Statusanzeige für ausstehende Änderungen

## Installation

1. Klonen Sie das Repository
2. Öffnen Sie das Xcode-Projekt
3. Konfigurieren Sie die Entwicklerzertifikate
4. Bauen und starten Sie die App auf Ihrem Gerät oder Simulator

## Anforderungen

- iOS 16.0 oder höher
- Xcode 14.0 oder höher
- Swift 5.7 oder höher
- Für Self-Hosted Modus: Docker und Docker Compose

## Backend-Integration

Die App unterstützt drei verschiedene Speichermodi:

1. **CloudKit**: Nutzt Apple's CloudKit für die Datenspeicherung und Synchronisierung
2. **Self-Hosted**: Nutzt ein eigenes Backend mit GraphQL-API und MinIO für die Medienspeicherung
3. **Hybrid**: Kombiniert beide Ansätze für maximale Flexibilität

### Self-Hosted Backend

Das Backend besteht aus:

- GraphQL-API mit Apollo Server
- PostgreSQL-Datenbank für strukturierte Daten
- MinIO für die Medienspeicherung (S3-kompatibel)

### Synchronisierungslogik

Die Synchronisierung zwischen der App und dem Backend erfolgt in mehreren Schritten:

1. **Trips**: Synchronisierung von Reisedaten
2. **Memories**: Synchronisierung von Erinnerungen
3. **MediaItems**: Synchronisierung von Mediendateien (Fotos, Videos)
4. **Tags**: Synchronisierung von Tags und Kategorien

Die Synchronisierung kann automatisch im Hintergrund oder manuell durch den Benutzer erfolgen. Die App unterstützt:

- Automatische Synchronisierung in konfigurierbaren Intervallen
- Synchronisierung nur über WLAN
- Selektive Synchronisierung von Mediendateien
- Konfliktlösung bei gleichzeitigen Änderungen

#### Komponenten der Synchronisierung

- **BackendSyncService**: Hauptkomponente für die Synchronisierung zwischen Core Data und dem Backend
- **MediaSyncManager**: Spezialisierte Komponente für die Synchronisierung von Mediendateien mit MinIO
- **MediaSyncCoordinator**: Koordiniert die Mediensynchronisierung auf höherer Ebene
- **SyncManager**: UI-Manager für die Anzeige des Synchronisierungsstatus und die Steuerung der Synchronisierung
- **DTOs**: Data Transfer Objects für die Konvertierung zwischen Core Data und GraphQL

## Konfiguration

### Backend-Einstellungen

In der App können unter "Einstellungen > Backend" die folgenden Optionen konfiguriert werden:

- Backend-URL
- Authentifizierung (Benutzername/Passwort)
- Speichermodus (CloudKit, Self-Hosted, Hybrid)
- Synchronisierungsoptionen

### Synchronisierungseinstellungen

Unter "Einstellungen > Synchronisierung" können folgende Optionen konfiguriert werden:

- Automatische Synchronisierung
- Synchronisierungsintervall
- WLAN-Einschränkungen
- Medien-Download/Upload-Optionen

## Entwicklung

### Projektstruktur

- `Journiary/`: Hauptverzeichnis der iOS-App
  - `API/`: Backend-Integration und GraphQL-Client
    - `DTOs/`: Data Transfer Objects für die Konvertierung zwischen Core Data und GraphQL
    - `MediaSync/`: Komponenten für die Mediensynchronisierung
  - `Models/`: Core Data-Modelle und Hilfsfunktionen
  - `Views/`: SwiftUI-Views
  - `Managers/`: Manager-Klassen für verschiedene Funktionen

- `backend/`: GraphQL-Backend
  - `src/`: Quellcode des Backends
    - `entities/`: Entitäten für die Datenbank
    - `resolvers/`: GraphQL-Resolver

### Architektur

Die App folgt einer MVVM-Architektur (Model-View-ViewModel) mit Core Data als lokaler Datenbank. Die Synchronisierung mit dem Backend erfolgt über eine dedizierte Synchronisierungsschicht.

## Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert - siehe die [LICENSE](LICENSE)-Datei für Details. 