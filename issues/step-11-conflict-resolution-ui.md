# [MIGRATION] Schritt 11: Conflict Resolution UI

## 🎯 Ziel
Benutzerfreundliche UI für manuelle Konfliktlösung bei gleichzeitigen Änderungen mit Side-by-Side-Vergleich und intelligenten Merge-Vorschlägen.

## 📋 Aufgaben

- [ ] **ConflictResolutionView** - Haupt-UI für Konflikt-Management
- [ ] **Side-by-Side Comparison** - Lokale vs. Remote Änderungen anzeigen
- [ ] **Field-Level Resolution** - Granulare Auswahl von Änderungen
- [ ] **Smart Merge Suggestions** - KI-basierte Merge-Vorschläge
- [ ] **Conflict Notifications** - Push-Notifications für Konflikte
- [ ] **Batch Conflict Resolution** - Multiple Konflikte gleichzeitig lösen
- [ ] **Conflict History** - Protokoll aller gelösten Konflikte

## ✅ Akzeptanzkriterien

- [ ] App kompiliert erfolgreich
- [ ] Konflikte werden benutzerfreundlich angezeigt
- [ ] Side-by-Side-Vergleich ist klar verständlich
- [ ] Field-Level-Auswahl funktioniert intuitiv
- [ ] Merge-Vorschläge sind hilfreich
- [ ] Batch-Resolution für multiple Konflikte
- [ ] Conflict-History ist nachvollziehbar

## 🤖 KI-Prompt für Implementation

```
Als erfahrener iOS-Entwickler mit SwiftUI und Core Data Expertise implementiere bitte:

SCHRITT 11: Conflict Resolution UI für Travel Companion iOS App

Implementiere eine intuitive, benutzerfreundliche Konfliktlösungs-UI:

1. **ConflictResolutionView.swift** (Haupt-Interface)
   - @StateObject conflictManager: ConflictManager
   - NavigationView mit Conflict-Liste
   - Detail-View für einzelne Konflikte
   - Batch-Actions für multiple Konflikte
   - Search & Filter für Conflict-History

2. **ConflictDetailView.swift** (Single Conflict Resolution)
   - Side-by-Side Layout (Local | Remote)
   - Field-by-Field Comparison
   - Interactive Selection (Tap to choose)
   - Preview der merged Entity
   - "Apply Resolution" Action

3. **Field-Level Conflict UI Components**
   - ConflictFieldRow.swift für einzelne Felder
   - Visual Highlighting von Unterschieden
   - Color-Coding: 🟢 Same, 🟡 Modified, 🔴 Conflict
   - Tap-to-Select Interaction
   - Custom Views für verschiedene Field-Types

4. **Smart Merge Suggestions**
   - AI-based Conflict-Resolution-Hints
   - "Neuere Version wählen" Suggestion
   - "Änderungen kombinieren" wo möglich
   - Context-aware Recommendations
   - Confidence-Scoring für Suggestions

5. **Conflict Notification System**
   - Local Notifications für neue Konflikte
   - Badge-Count für unresolved Conflicts
   - In-App Conflict-Alerts
   - Email-Notifications für shared Trip-Conflicts

6. **Batch Resolution Interface**
   - Multi-Select für Conflict-Liste
   - "Alle lokale Änderungen" Button
   - "Alle Remote-Änderungen" Button
   - Smart Batch-Resolution mit AI-Suggestions
   - Progress-Tracking für Batch-Operations

7. **Conflict History & Audit Trail**
   - ConflictHistoryView.swift
   - Chronological Conflict-Log
   - Before/After für resolved Conflicts
   - User-Attribution (wer hat resolved)
   - Export-Funktion für Audit-Purposes

8. **Entity-Specific Conflict Views**
   - TripConflictView für Trip-spezifische Konflikte
   - MemoryConflictView für Memory-Konflikte
   - MediaConflictView für Media-Konflikte
   - Custom UI für verschiedene Entity-Types

9. **Advanced Conflict Features**
   - Three-Way-Merge-Visualization
   - Conflict-Simulation für Testing
   - Auto-Resolution Rules Configuration
   - Developer-Mode für Conflict-Debugging

Verwende dabei:
- SwiftUI DiffableDataSource für Side-by-Side
- Combine für reactive Conflict-Updates
- Core Data NSManagedObjectContext für Previews
- UserNotifications für Conflict-Alerts

Berücksichtige dabei:
- Intuitive User-Experience (nicht technical)
- Clear Visual Design für Differences
- Performance bei vielen Konflikten
- Accessibility für Conflict-Resolution
- German Localization für alle UI-Texte
- Error-Handling für Resolution-Failures
- Thread-Safety für Conflict-Resolution
- User-Guidance für komplexe Konflikte
```

## 🔗 Abhängigkeiten

- Abhängig von: #8 (Sync Engine), #9 (Hybrid-Sync)
- Blockiert: #12 (Advanced Sync Features)

## 🧪 Test-Plan

1. **Basic Conflict Detection**
   - Device A & B offline
   - Beide bearbeiten gleichen Trip
   - Online: Konflikt wird erkannt
   - ConflictResolutionView öffnet sich

2. **Side-by-Side Comparison**
   - Konflikt anzeigen
   - Lokale vs. Remote Änderungen sichtbar
   - Field-Level Differences highlighted
   - Clear Visual Indication

3. **Field-Level Resolution**
   - Tap auf lokalen Wert → ausgewählt
   - Tap auf Remote-Wert → ausgewählt
   - Mixed Resolution möglich
   - Preview zeigt Merge-Result

4. **Smart Suggestions**
   - KI schlägt "Neuere Version" vor
   - Confidence-Score angezeigt
   - One-Click Suggestion-Acceptance
   - Manual Override möglich

5. **Batch Resolution**
   - Multiple Konflikte vorhanden
   - Select All → Batch-Action
   - Progress-Bar für Resolution
   - Success/Error-Feedback

## 📱 UI/UX Mockups

```
Conflict Resolution Main:
┌─────────────────────────┐
│ ⚠️ Konflikte (3)        │
│                         │
│ 🏖️ Trip "Mallorca"     │
│ 2 Felder, vor 5 Min    │
│                         │
│ 📸 Memory "Strand"     │
│ 1 Feld, vor 10 Min     │
│                         │
│ 🎯 Memory "Hotel"      │
│ 3 Felder, vor 1 Std    │
│                         │
│ [ Alle lokal ] [ Remote ]│
└─────────────────────────┘

Side-by-Side Conflict:
┌─────────────────────────┐
│ ⚠️ Trip "Mallorca"      │
│                         │
│ 📱 Lokal    │ 🌐 Remote │
│━━━━━━━━━━━━│━━━━━━━━━━━━│
│ Name:       │ Name:      │
│ 🟢 Mallorca │ 🟢 Mallorca│
│             │            │
│ Beschreibung│ Beschreibung│
│ 🔴 Toller   │ 🔴 Super   │
│    Urlaub   │    Reise   │
│             │            │
│ Start:      │ Start:     │
│ 🟡 01.06.   │ 🟡 02.06.  │
│             │            │
│ [ Vorschau ] [ Speichern ]│
└─────────────────────────┘

Smart Suggestions:
┌─────────────────────────┐
│ 🤖 KI-Vorschlag        │
│                         │
│ ✨ Empfehlung (85%):    │
│ Neuere Version wählen   │
│ (Remote ist 5min neuer) │
│                         │
│ 🔄 Alternative:         │
│ Beschreibungen         │
│ kombinieren            │
│                         │
│ [ Anwenden ] [ Ignorieren]│
└─────────────────────────┘
```

## ⚠️ Risiken & Überlegungen

- **User Confusion**: Konfliktlösung kann für User verwirrend sein
- **Data Loss**: Falsche Conflict-Resolution kann zu Datenverlust führen
- **Performance**: Komplexe Diff-Calculations können langsam sein
- **UI Complexity**: Balance zwischen Features und Einfachheit
- **Accessibility**: Conflict-UI muss für alle User zugänglich sein

## 📚 Ressourcen

- [SwiftUI Advanced Layouts](https://developer.apple.com/documentation/swiftui/building_layouts_with_stack_views)
- [User Notifications Framework](https://developer.apple.com/documentation/usernotifications)
- [Core Data Conflict Resolution](https://developer.apple.com/documentation/coredata/resolving_conflicts)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) 