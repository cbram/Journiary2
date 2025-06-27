# [MIGRATION] Schritt 8: Bidirektionale Sync Engine

## 🎯 Ziel
Vollständige bidirektionale Synchronisation zwischen Core Data, Backend und CloudKit mit intelligenter Konfliktlösung und Delta-Sync implementieren.

## 📋 Aufgaben

- [ ] **SyncEngine.swift** - Zentrale Sync-Orchestrierung
- [ ] **DeltaSync** - Nur Änderungen übertragen (Performance-Optimierung)
- [ ] **ConflictResolver** - Automatische und manuelle Konfliktlösung
- [ ] **SyncScheduler** - Background-Sync und Timer-basierte Synchronisation
- [ ] **SyncStatus** - Live-Status für UI-Updates
- [ ] **Bidirectional Flow** - Core Data ↔ Backend ↔ CloudKit
- [ ] **Incremental Sync** - Timestamp-basierte Delta-Synchronisation

## ✅ Akzeptanzkriterien

- [ ] App kompiliert erfolgreich
- [ ] Bidirektionale Synchronisation funktioniert
- [ ] Änderungen werden zwischen allen Geräten synchronisiert
- [ ] Konfliktlösung arbeitet automatisch und manuell
- [ ] Performance ist optimiert (nur Änderungen werden übertragen)
- [ ] Background-Sync funktioniert zuverlässig
- [ ] Sync-Status wird in UI angezeigt

## 🤖 KI-Prompt für Implementation

```
Als erfahrener iOS-Entwickler mit SwiftUI und Core Data Expertise implementiere bitte:

SCHRITT 8: Bidirektionale Sync Engine für Travel Companion iOS App

Implementiere eine vollständige, intelligente Synchronisations-Engine:

1. **SyncEngine.swift** (Zentrale Orchestrierung)
   - ObservableObject für UI-Integration
   - sync() → SyncResult Hauptmethode
   - Background Task Management
   - Sync-Priorisierung (Trips → Memories → Media)
   - Error-Recovery und Retry-Logic

2. **DeltaSync Implementation**
   - Timestamp-basierte Änderungserkennung
   - lastSyncTimestamp pro Entity-Type
   - Modified-Since Queries für Backend
   - CKModificationDate für CloudKit
   - Nur geänderte Entities übertragen

3. **ConflictResolver.swift**
   - ConflictResolutionStrategy Enum:
     - .localWins, .remoteWins, .newerWins, .manual
   - Three-Way-Merge für komplexe Konflikte
   - Field-Level Conflict Detection
   - User-Notification für manuelle Auflösung

4. **SyncScheduler.swift** 
   - Timer-basierte Background-Sync
   - App-Lifecycle-Integration (didBecomeActive)
   - NetworkMonitor-Integration
   - Exponential Backoff bei Failures
   - User-configurable Sync-Intervals

5. **SyncStatus Management**
   - @Published syncState: SyncState
   - SyncState: .idle, .syncing, .error, .conflict
   - Progress-Tracking für UI (x/y entities synced)
   - Last-Sync-Timestamp für User-Info
   - Error-Details für Troubleshooting

6. **Bidirectional Flow Architecture**
   ```
   Core Data ←→ SyncEngine ←→ Backend
        ↕                        ↕
   CloudKit ←←←←←←←←←←←←→→→→→→→→→→→ Hybrid
   ```
   - Core Data als Single Source of Truth
   - Backend/CloudKit als Remote-Stores
   - Conflict Resolution bei unterschiedlichen Remote-States

7. **Performance Optimizations**
   - Batch-Operations für große Datasets
   - Background-Context für Sync-Operations
   - Memory-efficient Streaming für Media
   - Concurrent Sync für verschiedene Entity-Types
   - Smart Scheduling (WiFi vs. Cellular)

8. **Entity-Specific Sync Logic**
   - TripSyncHandler für Trip-spezifische Logic
   - MemorySyncHandler für Memory-Sync
   - MediaSyncHandler für File-Upload/Download
   - TagSyncHandler für Tag-Hierarchien
   - Dependency-aware Sync-Order

9. **Error Handling & Recovery**
   - Network-Error Recovery
   - Authentication-Error Handling
   - Partial-Sync bei einzelnen Entity-Failures
   - User-friendly Error-Messages
   - Automatic Retry mit Exponential-Backoff

Verwende dabei:
- NSManagedObjectContext Background-Operations
- Combine für Reactive Sync-Updates
- AsyncSequence für streaming Sync-Operations
- GraphQL Subscriptions für Real-time Updates

Berücksichtige dabei:
- Thread-Safety für Core Data Operations
- Memory-Management bei großen Sync-Operations
- Battery-Optimization für Background-Sync
- Network-Bandwidth-Awareness
- User-Experience bei langen Sync-Vorgängen
- German Localization für Sync-Status
- Accessibility für Sync-Progress-UI
```

## 🔗 Abhängigkeiten

- Abhängig von: #3 (GraphQL Client), #7 (Offline-Queue)
- Blockiert: #9 (Hybrid-Sync), #10 (Media-Sync), #11 (Conflict Resolution UI)

## 🧪 Test-Plan

1. **Basic Bidirectional Sync**
   - Device A: Erstelle Trip
   - Device B: Trip erscheint nach Sync
   - Device B: Bearbeite Trip
   - Device A: Änderungen erscheinen nach Sync

2. **Conflict Resolution**
   - Device A & B offline
   - Beide bearbeiten gleichen Trip
   - Online: Automatische Konfliktlösung
   - Manuelle Konflikte werden UI angezeigt

3. **Delta Sync Performance**
   - 1000 Trips, nur 1 geändert
   - Sync überträgt nur 1 Trip (nicht alle)
   - Sync-Time < 2 Sekunden

4. **Background Sync**
   - App in Background
   - Timer-basierte Sync läuft
   - Bei App-Activation: Sofortige Sync
   - Battery-Usage bleibt niedrig

5. **Error Recovery**
   - Backend offline während Sync
   - Automatic Retry nach Reconnect
   - Partial-Sync bei einzelnen Failures
   - User wird über Probleme informiert

## 📱 UI/UX Mockups

```
Sync Status Bar:
┌─────────────────────────┐
│ 🔄 Synchronisiert...    │
│ ▓▓▓▓▓░░░░░ 5/10 Trips  │
└─────────────────────────┘

Sync Complete:
┌─────────────────────────┐
│ ✅ Sync abgeschlossen   │
│ 🕐 Vor 2 Minuten        │
│ 📊 15 Updates erhalten  │
└─────────────────────────┘

Conflict Resolution:
┌─────────────────────────┐
│ ⚠️ Konflikt erkannt     │
│                         │
│ Trip "London" wurde     │
│ gleichzeitig bearbeitet │
│                         │
│ [ Lokal ] [ Remote ]    │
│ [ Details anzeigen ]    │
└─────────────────────────┘
```

## ⚠️ Risiken & Überlegungen

- **Data Consistency**: Race-Conditions zwischen gleichzeitigen Sync-Vorgängen
- **Performance Impact**: Große Sync-Operations können UI blockieren
- **Battery Usage**: Background-Sync muss battery-optimiert sein
- **Network Usage**: Delta-Sync ist kritisch für mobile Datenverbindungen
- **Conflict Complexity**: Three-Way-Merge kann sehr komplex werden

## 📚 Ressourcen

- [Core Data Background Processing](https://developer.apple.com/documentation/coredata/using_core_data_in_the_background)
- [CloudKit Sync Strategies](https://developer.apple.com/videos/play/wwdc2019/202/)
- [iOS Background Tasks](https://developer.apple.com/documentation/backgroundtasks)
- [Combine Framework](https://developer.apple.com/documentation/combine) 