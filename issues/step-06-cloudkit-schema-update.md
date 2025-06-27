# [MIGRATION] Schritt 6: CloudKit Schema-Update

## 🎯 Ziel
CloudKit Schema um Multi-User-Support erweitern und parallel zu Backend-Sharing funktionsfähig machen. CKShare für CloudKit-Sharing implementieren.

## 📋 Aufgaben

- [ ] **CloudKit Schema Migration** - CKRecord Updates für User-References
- [ ] **CKShare Integration** - CloudKit-basiertes Sharing implementieren
- [ ] **User Discovery** - CKContainer.userDiscoverability für User-Lookup
- [ ] **CloudKit Permissions** - CKShare.ParticipantPermission Mapping
- [ ] **Hybrid Compatibility** - CloudKit + Backend parallel nutzbar
- [ ] **Schema Versioning** - Backward-Compatibility für alte App-Versionen
- [ ] **Zone Management** - Custom Zones für User-spezifische Daten

## ✅ Akzeptanzkriterien

- [ ] App kompiliert erfolgreich
- [ ] CloudKit-Sharing funktioniert parallel zu Backend-Sharing
- [ ] CKShare für Trips/Memories verfügbar
- [ ] User Discovery über iCloud funktioniert
- [ ] Schema-Migration läuft ohne Datenverlust
- [ ] Hybrid-Modus (CloudKit + Backend) funktioniert
- [ ] Bestehende CloudKit-Daten bleiben erhalten

## 🤖 KI-Prompt für Implementation

```
Als erfahrener iOS-Entwickler mit SwiftUI und CloudKit Expertise implementiere bitte:

SCHRITT 6: CloudKit Schema-Update für Travel Companion iOS App

Erweitere CloudKit um Multi-User Support parallel zum Backend:

1. **CloudKit Schema Migration**
   - CKRecord User-Reference Fields hinzufügen
   - owner, creator, members Fields für alle Entitäten
   - CKRecord.ID Mapping für Backend-User-IDs
   - Schema-Versioning für schrittweise Migration

2. **CKShare Implementation**
   - CKShare für Trip-Sharing
   - CKShare für Memory-Sharing  
   - CKShare.ParticipantPermission Enum
   - Share-URL Generation und Handling

3. **User Discovery System**
   - CKContainer.userDiscoverability Setup
   - User-Lookup by Email/iCloud-Account
   - Privacy-Settings berücksichtigen
   - Fallback für nicht-discoverable Users

4. **CloudKit Permissions Manager**
   - Permission Enum → CKShare.ParticipantPermission
   - canEdit/canDelete Checks für CloudKit-Records
   - Owner vs. Participant Distinction
   - Share-Management UI Integration

5. **Hybrid Mode Support**
   - CloudKit + Backend parallel verfügbar
   - Storage-Mode switching ohne Datenverlust
   - Conflict Resolution zwischen CloudKit/Backend
   - Smart Fallback (CloudKit → Backend → Local)

6. **Zone Management**
   - Custom CKRecordZone für User-Data
   - Shared Zones für collaborative Content
   - Zone-Subscription für real-time Updates
   - Zone-Cleanup bei User-Deletion

7. **CloudKit Service Layer**
   - CloudKitSharingService.swift
   - shareTrip(trip:with:permission:) → CKShare
   - acceptShare(shareURL:) → Trip
   - removeParticipant(from:trip:) → Void
   - Error-Handling für CloudKit-specific Errors

8. **Migration & Compatibility**
   - Existing CloudKit-Data zu Multi-User migrieren
   - Schema-Version-Detection
   - Graceful Degradation für alte App-Versionen
   - Rollback-Strategy bei Migration-Failures

Verwende dabei:
- CKShare für CloudKit-native Sharing
- CKContainer.default().discoverUserIdentity
- Custom CKRecordZone für bessere Organisation
- CKQuerySubscription für real-time Updates

Berücksichtige dabei:
- CloudKit Rate-Limits und Error-Handling
- iCloud-Account-Status Checks
- Privacy-Compliance für User-Discovery
- Thread-Safety für CloudKit-Operations
- Memory-Management für große CloudKit-Responses
- German Localization für CloudKit-Errors
- Accessibility für Sharing-UI
```

## 🔗 Abhängigkeiten

- Abhängig von: #4 (Multi-User Core Data), #5 (Sharing & Permissions)
- Blockiert: #9 (Hybrid-Sync), #11 (Conflict Resolution)

## 🧪 Test-Plan

1. **CloudKit Schema Migration**
   - App mit bestehenden CloudKit-Daten starten
   - Schema-Migration läuft erfolgreich
   - Alte Daten sind weiterhin verfügbar
   - Neue User-Fields sind gesetzt

2. **CKShare Functionality**
   - Trip mit anderem iCloud-User teilen
   - CKShare-URL generieren und versenden
   - Empfänger kann geteilten Trip öffnen
   - Permissions werden korrekt durchgesetzt

3. **User Discovery**
   - User-Lookup by Email funktioniert
   - iCloud-Account-Discovery zeigt richtige Users
   - Privacy-Settings werden respektiert
   - Fallback für nicht-discoverable Users

4. **Hybrid Mode**
   - CloudKit-Mode: Sharing funktioniert
   - Backend-Mode: Sharing funktioniert
   - Hybrid-Mode: Beide parallel verfügbar
   - Mode-Switch ohne Datenverlust

5. **Real-time Updates**
   - Geteilter Trip wird bearbeitet
   - Änderungen erscheinen bei allen Teilnehmern
   - Push-Notifications für Updates

## 📱 UI/UX Mockups

```
CloudKit Sharing:
┌─────────────────────────┐
│ 📤 Trip teilen (iCloud) │
│                         │
│ 👤 Max Mustermann       │
│ 📧 max@icloud.com       │
│ Berechtigung: [Edit ▼]  │
│                         │
│ [ iCloud-Link senden ]  │
│                         │
│ Oder per Email suchen:  │
│ 📧 [_______________]    │
│ [ Suchen ]              │
└─────────────────────────┘

Sharing Status:
┌─────────────────────────┐
│ ✈️ London-Trip          │
│ 👥 Geteilt via:         │
│ ☁️ iCloud (3 Personen)  │
│ 🌐 Backend (2 Personen) │
│                         │
│ [ Teilnehmer verwalten ]│
└─────────────────────────┘
```

## ⚠️ Risiken & Überlegungen

- **iCloud Dependency**: CloudKit erfordert aktiven iCloud-Account
- **User Discovery Privacy**: Nicht alle User sind über Email auffindbar
- **Rate Limits**: CloudKit hat strenge Rate-Limits für Operations
- **Schema Changes**: CloudKit-Schema-Changes sind nicht rückgängig machbar
- **Network Requirements**: CloudKit-Sharing erfordert Internetverbindung

## 📚 Ressourcen

- [CloudKit Sharing](https://developer.apple.com/documentation/cloudkit/shared_records)
- [CKShare Documentation](https://developer.apple.com/documentation/cloudkit/ckshare)
- [CloudKit User Discovery](https://developer.apple.com/documentation/cloudkit/accessing_user_information)
- [CloudKit Schema Management](https://developer.apple.com/documentation/cloudkit/designing_and_creating_a_cloudkit_database) 