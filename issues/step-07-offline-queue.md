# [MIGRATION] Schritt 7: Offline-Queue System

## 🎯 Ziel
Vollständiges Offline-First System implementieren, das alle Änderungen in einer lokalen Queue speichert und bei Netzwerk-Verfügbarkeit automatisch synchronisiert.

## 📋 Aufgaben

- [ ] **OfflineQueue.swift** - Core Data Entity für ausstehende Änderungen
- [ ] **ChangeTracker.swift** - Automatisches Tracking aller Core Data Änderungen
- [ ] **QueueManager.swift** - Management der Offline-Queue
- [ ] **SyncOperation.swift** - Einzelne Sync-Operationen (Create/Update/Delete)
- [ ] **NetworkMonitor.swift** - Erweitert um Auto-Sync bei Reconnect
- [ ] **OfflineQueueView.swift** - UI zur Anzeige ausstehender Änderungen
- [ ] **Background Sync** - Sync bei App-Aktivierung

## ✅ Akzeptanzkriterien

- [ ] App kompiliert erfolgreich
- [ ] Offline-Änderungen werden automatisch erfasst
- [ ] Queue ist persistent bei App-Neustart
- [ ] Auto-Sync bei Netzwerk-Reconnect
- [ ] UI zeigt ausstehende Änderungen an
- [ ] Manuelle Sync-Auslösung möglich
- [ ] Fehlerhafte Sync-Operationen werden erneut versucht

## 🤖 KI-Prompt für Implementation

```
Als erfahrener iOS-Entwickler mit SwiftUI und Core Data Expertise implementiere bitte:

SCHRITT 7: Offline-Queue System für Travel Companion iOS App

Implementiere ein robustes Offline-First System:

1. **OfflineQueue.swift** (Core Data Entity)
   - id: UUID
   - entityType: String (Trip, Memory, MediaItem, etc.)
   - entityId: UUID
   - operation: String (create, update, delete)
   - data: Data? (JSON der Änderungen)
   - createdAt: Date
   - attempts: Int16
   - lastAttempt: Date?
   - error: String?
   - priority: Int16 (0=low, 1=normal, 2=high)

2. **ChangeTracker.swift** (NSManagedObjectContext Observer)
   - NSManagedObjectContextDidSave Notification Observer
   - Automatische Queue-Entry Erstellung bei Änderungen
   - Filtering für lokale vs. sync-relevante Änderungen
   - Batch-Operations für Performance

3. **QueueManager.swift** (ObservableObject)
   - @Published pendingChanges: [OfflineQueue]
   - addToQueue(entity:operation:data:) Methoden
   - processQueue() für Bulk-Synchronisation
   - retryFailedOperations() für Fehler-Behandlung
   - clearQueue() nach erfolgreicher Sync

4. **SyncOperation.swift** (Protocol & Implementations)
   - Protocol für verschiedene Sync-Operationen
   - CreateTripOperation, UpdateMemoryOperation, etc.
   - execute() -> SyncResult
   - rollback() bei Fehlern
   - Priority-basierte Ausführung

5. **NetworkMonitor.swift** (Erweitert)
   - Automatic Queue-Processing bei Reconnect
   - Background App Refresh Integration
   - Bandwidth-Detection für Medien-Sync
   - Smart Retry-Logic (exponential backoff)

6. **OfflineQueueView.swift** (SwiftUI View)
   - Liste aller ausstehenden Änderungen
   - Status-Icons (pending, syncing, error, success)
   - Manual Retry für fehlgeschlagene Operationen
   - Queue-Clearing Button
   - Prioritäts-Anzeige

7. **Background Sync Integration**
   - AppDelegate/SceneDelegate Integration
   - applicationDidBecomeActive Sync-Trigger
   - Background App Refresh
   - Push Notification Sync-Trigger

8. **Conflict Prevention**
   - Timestamp-basierte Conflict Detection
   - Local-First Strategy (lokale Änderungen gewinnen)
   - User-Notification bei kritischen Konflikten

Berücksichtige dabei:
- Core Data Thread-Safety mit Background Contexts
- Memory-efficient Queue-Processing (Batch-Verarbeitung)
- Robust Error-Handling mit Retry-Logic
- User-friendly Progress-Anzeige
- German Localization für Queue-Status
- Accessibility für Queue-Management
- Performance bei großen Queues (1000+ Entries)
- Storage-Cleanup für alte, erfolgreiche Operationen
```

## 🔗 Abhängigkeiten

- Abhängig von: #3 (GraphQL Client), #4 (Multi-User Core Data)
- Blockiert: #8 (Sync Engine), #9 (Hybrid-Sync)

## 🧪 Test-Plan

1. **Offline Change Tracking**
   - Aktiviere Flugmodus
   - Erstelle neue Trip
   - Bearbeite Memory
   - Lösche MediaItem
   - → Alle Änderungen in Queue

2. **Auto-Sync bei Reconnect**
   - Deaktiviere Flugmodus
   - → Queue wird automatisch abgearbeitet
   - Alle Änderungen im Backend sichtbar

3. **Error Handling**
   - Simuliere Backend-Fehler (503 Error)
   - → Operation wird für Retry markiert
   - Backend wieder online → Retry erfolgreich

4. **UI-Integration**
   - Öffne OfflineQueueView
   - Pending Operations sind sichtbar
   - Sync-Status wird Live-Update angezeigt

5. **Priority Handling**
   - Trip-Erstellung = High Priority
   - Memory-Update = Normal Priority
   - → High Priority wird zuerst synchronisiert

## 📱 UI/UX Mockups

```
Offline Queue View:
┌─────────────────────────┐
│ 📤 Ausstehende Änderungen│
│                         │
│ 🔴 Trip "Berlin" erstellen│
│ 🟡 Memory "Dom" bearbeiten│
│ 🟢 Photo synchronisiert   │
│                         │
│ [ Alle synchronisieren ] │
│ [ Queue leeren ]        │
└─────────────────────────┘

Status Bar Integration:
┌─────────────────────────┐
│ ⭐ Trips    📍 Memories │
│                         │
│ 🔄 3 Änderungen ausstehend│
└─────────────────────────┘
```

## ⚠️ Risiken & Überlegungen

- **Storage Growth**: Queue kann bei langem Offline-Betrieb sehr groß werden
- **Memory Usage**: Große Queues können Memory-Issues verursachen
- **Conflict Resolution**: Lokale vs. Remote Änderungen können kollidieren
- **Data Integrity**: Abhängige Entities müssen in korrekter Reihenfolge synchronisiert werden
- **Performance**: Batch-Processing für 1000+ Queue-Entries

## 📚 Ressourcen

- [Core Data Background Processing](https://developer.apple.com/documentation/coredata/using_core_data_in_the_background)
- [iOS Background App Refresh](https://developer.apple.com/documentation/backgroundtasks)
- [Network Framework Connection Monitoring](https://developer.apple.com/documentation/network/monitoring_network_changes)
- [NSManagedObjectContext Notifications](https://developer.apple.com/documentation/coredata/nsmanagedobjectcontext/1506692-didchangenotification) 