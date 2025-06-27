# [MIGRATION] Schritt 5: Sharing & Permissions System

## 🎯 Ziel
Multi-User Sharing System implementieren, das es mehreren Benutzern ermöglicht, gemeinsam an Trips, Memories und BucketList-Items zu arbeiten mit granularen Berechtigungen.

## 📋 Aufgaben

- [ ] **TripMembership.swift** - Core Data Entity für geteilte Trips
- [ ] **Permission.swift** - Enum für Read/Write/Admin-Berechtigungen
- [ ] **SharingService.swift** - Backend-Integration für Sharing
- [ ] **InvitationManager.swift** - Einladungs-System für neue Teilnehmer
- [ ] **PermissionManager.swift** - Lokale Berechtigungs-Prüfungen
- [ ] **SharingView.swift** - UI für Trip/Memory-Sharing
- [ ] **Core Data Predicates** - Multi-User Data Filtering

## ✅ Akzeptanzkriterien

- [ ] App kompiliert erfolgreich
- [ ] Trips können mit anderen Usern geteilt werden
- [ ] Berechtigungen werden korrekt durchgesetzt (Read/Write/Admin)
- [ ] Einladungs-System funktioniert (Email-basiert)
- [ ] Geteilte Inhalte sind nur für berechtigte User sichtbar
- [ ] CloudKit-Sharing funktioniert parallel zu Backend-Sharing
- [ ] UI zeigt Sharing-Status und Teilnehmer an

## 🤖 KI-Prompt für Implementation

```
Als erfahrener iOS-Entwickler mit SwiftUI und Core Data Expertise implementiere bitte:

SCHRITT 5: Sharing & Permissions System für Travel Companion iOS App

Implementiere ein vollständiges Multi-User Sharing System:

1. **TripMembership.swift** (Core Data Entity)
   - id: UUID
   - trip: Trip (Relationship)
   - user: User (Relationship)
   - permission: String (read, write, admin)
   - invitedBy: User? (Relationship)
   - joinedAt: Date
   - invitedAt: Date
   - status: String (pending, accepted, declined)

2. **Permission.swift** (Enum)
   - Cases: .read, .write, .admin
   - hasPermission(_:for:) Methoden
   - Description und Localization
   - CloudKit CKShare.ParticipantPermission Mapping

3. **SharingService.swift** (GraphQL Service)
   - inviteUserToTrip(tripId:email:permission:)
   - removeUserFromTrip(tripId:userId:)
   - updatePermission(tripId:userId:permission:)
   - getSharedTrips() -> [Trip]
   - acceptInvitation(invitationId:)
   - declineInvitation(invitationId:)

4. **InvitationManager.swift** (ObservableObject)
   - @Published pendingInvitations: [Invitation]
   - sendInvitation(email:trip:permission:)
   - handleInvitationResponse(accepted:invitation:)
   - Email-Validation und User-Lookup

5. **PermissionManager.swift** (Utility Class)
   - canEdit(trip:user:) -> Bool
   - canDelete(memory:user:) -> Bool
   - canInvite(trip:user:) -> Bool
   - filterByPermission(trips:[Trip]) -> [Trip]
   - Core Data Predicate Generation

6. **SharingView.swift** (SwiftUI View)
   - Teilnehmer-Liste mit Berechtigungen
   - "User einladen" Button mit Email-Input
   - Permission-Picker für neue Einladungen
   - Teilnehmer entfernen/Berechtigung ändern
   - CloudKit vs. Backend Sharing-Modi

7. **Core Data Integration**
   - NSFetchRequest Extensions für Multi-User Filtering
   - Automatic User-Context für alle Queries
   - Background-Sync für Membership-Changes
   - Conflict Resolution bei Sharing-Konflikten

8. **CloudKit Integration**
   - CKShare für CloudKit-basiertes Sharing
   - CKContainer.userDiscoverability für User-Lookup
   - Parallel zu Backend-Sharing verfügbar
   - Migration zwischen CloudKit <-> Backend Sharing

9. **UI-Integration**
   - Sharing-Button in Trip/Memory-DetailViews
   - Shared-Status-Icons in Listen-Ansichten
   - Invitation-Notifications
   - Permission-basierte UI-States (Read-Only vs. Editable)

Verwende dabei das bestehende Backend Schema:
- TripMembership Entity mit permission, status, user, trip
- Invitation System über Email-Lookup
- GraphQL Mutations für Sharing-Operations

Berücksichtige dabei:
- Thread-Safety für gleichzeitige Membership-Changes
- Graceful Degradation bei Network-Failures
- German Localization für alle Sharing-Texte
- Accessibility für Sharing-UI
- Privacy-Compliance (DSGVO) für Email-Sharing
- Performance bei großen Teilnehmer-Listen
- Conflict Resolution bei gleichzeitigen Permission-Changes
```

## 🔗 Abhängigkeiten

- Abhängig von: #2 (User-System), #4 (Multi-User Core Data)
- Blockiert: #6 (CloudKit Schema-Update), #8 (Sync Engine)

## 🧪 Test-Plan

1. **Trip Sharing (Backend-Mode)**
   - Erstelle Trip als User A
   - Lade User B via Email ein
   - User B akzeptiert Einladung
   - Trip erscheint in User B's Trip-Liste

2. **Permission Testing**
   - User A gibt User B "Read"-Berechtigung
   - User B kann Trip sehen, aber nicht bearbeiten
   - User A ändert auf "Write"-Berechtigung
   - User B kann jetzt Memories hinzufügen

3. **Memory Sharing**
   - Geteilter Trip zwischen User A & B
   - User A erstellt Memory
   - Memory ist sofort für User B sichtbar
   - User B kann Memory bearbeiten (bei Write-Permission)

4. **CloudKit Sharing**
   - Wechsle zu CloudKit-Mode
   - Nutze CKShare für Trip-Sharing
   - CloudKit Sharing funktioniert parallel

5. **Invitation Workflow**
   - Einladung wird per Email versendet
   - Empfänger öffnet App → Pending Invitation sichtbar
   - Accept/Decline funktioniert korrekt

## 📱 UI/UX Mockups

```
Sharing View:
┌─────────────────────────┐
│ 👥 Trip "London" teilen  │
│                         │
│ 👤 Max (Admin)          │
│ 👤 Anna (Write) [↓]     │
│ 👤 Tom (Read) [↓]       │
│                         │
│ ➕ User einladen        │
│ Email: [_________]      │
│ Berechtigung: [Write ▼] │
│ [ Einladung senden ]    │
└─────────────────────────┘

Trip Liste mit Sharing:
┌─────────────────────────┐
│ 🌍 Meine Trips          │
│                         │
│ ✈️ London 👥 (3 Users)  │
│ 🏖️ Mallorca            │
│ 🚗 Berlin 👥 (Geteilt)  │
└─────────────────────────┘
```

## ⚠️ Risiken & Überlegungen

- **Privacy**: Email-Sharing muss DSGVO-konform sein
- **Performance**: Große Teilnehmer-Listen können UI verlangsamen
- **Conflict Resolution**: Gleichzeitige Permission-Changes können zu Konflikten führen
- **Data Consistency**: Backend & CloudKit Sharing müssen synchron bleiben
- **Spam-Protection**: Rate-Limiting für Einladungen implementieren

## 📚 Ressourcen

- [CloudKit Sharing](https://developer.apple.com/documentation/cloudkit/shared_records)
- [CKShare Documentation](https://developer.apple.com/documentation/cloudkit/ckshare)
- [Core Data Relationships](https://developer.apple.com/documentation/coredata/modeling_data/configuring_relationships)
- [GraphQL Subscriptions](https://www.apollographql.com/docs/react/data/subscriptions/) 