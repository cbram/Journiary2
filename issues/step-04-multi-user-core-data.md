# [MIGRATION] Schritt 4: Multi-User Core Data Schema

## 🎯 Ziel
Core Data Schema um Multi-User-Unterstützung erweitern mit User-Relationen für alle Entitäten und Vorbereitung für Sharing-System.

## 📋 Aufgaben

- [ ] **User.swift** - Core Data User Entity erweitern
- [ ] **Core Data Model Migration** - Schema-Update für alle Entitäten
- [ ] **Relationship Updates** - User-Relationen zu Trip, Memory, etc.
- [ ] **Data Migration Script** - Bestehende Daten zu aktuellem User zuweisen
- [ ] **NSFetchRequest Extensions** - Multi-User Filtering
- [ ] **Predicate Helpers** - User-spezifische Datenabfragen

## ✅ Akzeptanzkriterien

- [ ] App kompiliert erfolgreich
- [ ] Core Data Migration läuft ohne Fehler
- [ ] Bestehende Daten sind noch vorhanden
- [ ] Neue Entitäten haben User-Relation
- [ ] Multi-User Filtering funktioniert
- [ ] CloudKit-Schema bleibt kompatibel

## 🤖 KI-Prompt für Implementation

```
Als erfahrener iOS-Entwickler mit SwiftUI und Core Data Expertise implementiere bitte:

SCHRITT 4: Multi-User Core Data Schema für Travel Companion iOS App

Erweitere das bestehende Core Data Schema um Multi-User Support:

1. **User Entity Update** (Core Data)
   - Existierende User-Entity erweitern
   - CloudKit-Kompatibilität beibehalten
   - CKRecord.Reference für CloudKit-Users
   - Local vs. Remote User-Identifiers

2. **Entity Relationships** (Alle bestehenden Entitäten)
   - Trip → User (owner)
   - Memory → User (creator)
   - MediaItem → User (uploader)
   - BucketListItem → User (creator)
   - Tag → User (creator)
   - RoutePoint → User (recorder)

3. **Core Data Migration**
   - Lightweight Migration Setup
   - Migration Policy für User-Assignment
   - Bestehende Daten zu "Default User" zuweisen
   - Error-Handling für Migration-Failures

4. **NSFetchRequest Extensions**
   - userTrips(for: User) -> NSFetchRequest<Trip>
   - userMemories(for: User) -> NSFetchRequest<Memory>
   - sharedContent(for: User) -> NSFetchRequest<Trip>
   - Predicate-Builder für Multi-User Queries

5. **User Context Management**
   - CurrentUser ObservableObject
   - Automatic User-Context für alle Queries
   - Thread-Safe User-Session Management
   - CloudKit vs. Backend User-Handling

6. **CloudKit Schema Updates**
   - CKRecord Updates für User-References
   - CloudKit Zone-Sharing vorbereiten
   - Custom Zone für User-Data
   - Schema-Kompatibilität zwischen Local/Cloud

7. **Performance Optimizations**
   - Indexes für User-Relationships
   - Batch-Fetching für User-Content
   - Memory-Efficient User-Queries
   - Background-Context für User-Operations

Berücksichtige dabei:
- Lightweight Migration (automatisch ohne Datenverlust)
- CloudKit-Kompatibilität für bestehende iCloud-Sync
- Thread-Safety für Multi-User Operations
- Performance bei großen Datasets
- Backward-Compatibility für alte App-Versionen
- German Error-Messages für Migration-Failures
```

## 🔗 Abhängigkeiten

- Abhängig von: #2 (User-System Implementation)
- Blockiert: #4 (Sharing & Permissions), #5 (Offline-Queue)

## 🧪 Test-Plan

1. **Schema Migration**
   - App mit bestehenden Daten starten
   - Migration läuft erfolgreich
   - Alle Daten sind noch vorhanden
   - Neue User-Relationen sind gesetzt

2. **Multi-User Queries**
   - User A erstellt Trip
   - User B sieht Trip nicht (bis Sharing)
   - NSFetchRequest filtert korrekt nach User

3. **CloudKit Compatibility**
   - CloudKit-Sync funktioniert weiterhin
   - User-References werden korrekt synchronisiert
   - Keine CloudKit-Schema-Konflikte

4. **Performance Testing**
   - 1000+ Trips mit verschiedenen Usern
   - User-spezifische Queries sind schnell (<100ms)
   - Memory-Usage bleibt konstant

## 📱 UI/UX Mockups

```
Core Data Schema (Updated):
┌─────────────────────────┐
│ User                    │
│ ├── id: UUID           │
│ ├── email: String      │
│ ├── trips: [Trip]      │
│ └── memories: [Memory] │
│                         │
│ Trip                    │
│ ├── owner: User        │
│ ├── members: [User]    │
│ └── memories: [Memory] │
│                         │
│ Memory                  │
│ ├── creator: User      │
│ ├── trip: Trip         │
│ └── mediaItems: [Media]│
└─────────────────────────┘
```

## ⚠️ Risiken & Überlegungen

- **Data Loss**: Migration kann bei Fehlern zu Datenverlust führen
- **CloudKit Conflicts**: Schema-Changes können CloudKit-Sync stören  
- **Performance Impact**: User-Joins können Queries verlangsamen
- **Migration Time**: Große Datasets benötigen lange Migration-Zeit
- **Rollback Strategy**: Schwierig bei irreversibler Schema-Migration

## 📚 Ressourcen

- [Core Data Lightweight Migration](https://developer.apple.com/documentation/coredata/using_lightweight_migration)
- [CloudKit Schema Migration](https://developer.apple.com/documentation/cloudkit/modifying_and_saving_records)
- [NSFetchRequest Performance](https://developer.apple.com/documentation/coredata/nsfetchrequest)
- [Core Data Relationships](https://developer.apple.com/documentation/coredata/modeling_data/configuring_relationships) 