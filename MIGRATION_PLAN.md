# iOS App Migration Plan: CloudKit → Multi-Backend System

## Übersicht
Migration der iOS Travel Companion App von reinem CloudKit zu einem flexiblen Multi-Backend-System mit CloudKit, Self-Hosted Backend und Hybrid-Modus.

## Ziele
- ✅ Multi-User Support mit Sharing-Funktionen
- ✅ Offline-First mit verzögerter Synchronisation
- ✅ Flexible Backend-Auswahl (CloudKit/Backend/Hybrid)
- ✅ Konfliktlösung bei gleichzeitigen Änderungen
- ✅ Progressive Migration ohne Datenverlust

## Phasen-Übersicht

### Phase 1: Grundlagen & Infrastruktur
- **Schritt 1:** Backend-Integration Setup
- **Schritt 2:** Benutzer-System Implementation
- **Schritt 3:** GraphQL Client & API Layer

### Phase 2: Datenmodell-Erweiterung
- **Schritt 4:** Multi-User Core Data Schema
- **Schritt 5:** Sharing & Permissions System
- **Schritt 6:** CloudKit Schema-Update

### Phase 3: Synchronisation
- **Schritt 7:** Offline-Queue System
- **Schritt 8:** Bidirektionale Sync Engine
- **Schritt 9:** CloudKit + Backend Hybrid-Sync

### Phase 4: Media & Advanced Features
- **Schritt 10:** Media-Synchronisation
- **Schritt 11:** Conflict Resolution UI
- **Schritt 12:** Advanced Sync Features

## GitHub Issues Template

Jeder Schritt wird als GitHub Issue erstellt mit:
- Detaillierte Aufgabenbeschreibung
- Akzeptanzkriterien
- KI-Prompt für Implementation
- Definition of Done
- Abhängigkeiten zu anderen Issues

## Fortschritt Tracking

- [ ] Phase 1: Grundlagen (Issues #1-3)
- [ ] Phase 2: Datenmodell (Issues #4-6) 
- [ ] Phase 3: Synchronisation (Issues #7-9)
- [ ] Phase 4: Advanced Features (Issues #10-12)

## Testing Strategy

Nach jedem Schritt:
1. App kompiliert erfolgreich
2. Neue Funktion ist testbar
3. Keine Regression in bestehenden Features
4. UI/UX ist intuitiv bedienbar 