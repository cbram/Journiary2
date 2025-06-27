# [MIGRATION] Schritt 3: GraphQL Client & API Layer

## 🎯 Ziel
Apollo GraphQL Client Setup mit vollständiger API-Integration für Backend-Kommunikation. Basis für alle weiteren Synchronisations-Features.

## 📋 Aufgaben

- [ ] **Apollo Client Setup** - GraphQL Client Konfiguration
- [ ] **GraphQL Schema** - Code-Generation für TypeScript-Backend
- [ ] **API Service Layer** - Abstraktion über Apollo Client
- [ ] **DTOs (Data Transfer Objects)** - Mapping zwischen Core Data ↔ GraphQL
- [ ] **Error Handling** - Network & GraphQL Error Management
- [ ] **Cache Configuration** - Apollo Cache Setup
- [ ] **Authentication Interceptor** - JWT Token in alle Requests

## ✅ Akzeptanzkriterien

- [ ] App kompiliert erfolgreich
- [ ] GraphQL Queries gegen Backend funktionieren
- [ ] JWT Authentication in allen Requests
- [ ] DTO-Mapping zwischen Core Data und GraphQL
- [ ] Proper Error-Handling für Network/GraphQL-Errors
- [ ] Apollo Cache funktioniert korrekt
- [ ] Code-Generation für Schema Updates

## 🤖 KI-Prompt für Implementation

```
Als erfahrener iOS-Entwickler mit SwiftUI, Core Data und GraphQL Expertise implementiere bitte:

SCHRITT 3: GraphQL Client & API Layer für Travel Companion iOS App

Implementiere vollständige GraphQL-Integration:

1. **Apollo Client Setup**
   - Apollo iOS SDK Integration
   - Client-Konfiguration mit Backend-URL
   - JWT Authentication Interceptor
   - Cache-Konfiguration
   - Error-Link für Error-Handling

2. **GraphQL Schema & Code-Generation**
   - Schema Download vom Backend
   - Apollo Code-Generation Setup
   - Generated Types für alle Backend-Entitäten
   - Query/Mutation/Subscription Definitionen

3. **DTOs (Data Transfer Objects)**
   - TripDTO.swift - Core Data Trip ↔ GraphQL Trip
   - MemoryDTO.swift - Core Data Memory ↔ GraphQL Memory
   - MediaItemDTO.swift - Media Mapping
   - TagDTO.swift - Tag System Mapping
   - UserDTO.swift - User Mapping
   - Bidirektionale Konvertierungs-Methoden

4. **API Service Layer**
   - TripService.swift - Trip CRUD Operations
   - MemoryService.swift - Memory Operations
   - MediaService.swift - Media Upload/Download
   - TagService.swift - Tag Management
   - SyncService.swift - Bulk Sync Operations

5. **Error Handling**
   - GraphQLError Enum
   - NetworkError Handling
   - Authentication Error Detection
   - User-friendly Error Messages
   - Retry-Logic für temporäre Failures

6. **Authentication Integration**
   - JWT Token aus AuthManager
   - Automatic Token-Refresh
   - Logout bei Token-Expiry
   - Anonymous Requests für Public-Data

7. **Cache & Performance**
   - Apollo Cache Policies
   - Optimistic Updates
   - Cache Invalidation
   - Background Sync

Verwende dabei das bestehende Backend Schema:
- User (id, email, username, firstName, lastName)
- Trip (id, name, description, startDate, endDate, userId)
- Memory (id, title, content, location, tripId, userId)
- MediaItem (id, filename, mimeType, memoryId)
- Tag/TagCategory für Tagging-System
- RoutePoint für GPS-Tracking

Berücksichtige dabei:
- Apollo iOS Best Practices
- Combine Integration für reactive Streams
- Thread-Safety für Core Data Operations
- Memory Management für große Datasets
- Offline-Readiness (Cache-First Policies)
- German Error Messages
- Accessibility für Loading States
```

## 🔗 Abhängigkeiten

- Abhängig von: #1 (Backend-Integration), #2 (User-System)
- Blockiert: #4 (Multi-User Core Data), #7 (Offline-Queue), #8 (Sync Engine)

## 🧪 Test-Plan

1. **Basic GraphQL Connectivity**
   - Backend läuft auf localhost:4001
   - App kann Schema laden
   - Simple Query (Hello World) funktioniert

2. **Authentication Integration**
   - Login → JWT Token verfügbar
   - Authenticated Query funktioniert
   - Bei abgelaufenem Token → Auto-Refresh

3. **CRUD Operations**
   - Trip erstellen via GraphQL
   - Trip laden und anzeigen
   - Trip bearbeiten und speichern
   - Trip löschen

4. **DTO Mapping**
   - Core Data Trip → GraphQL Trip Input
   - GraphQL Trip Response → Core Data Trip
   - Alle Felder korrekt gemappt

5. **Error Handling**
   - Backend offline → User-friendly Error
   - Invalid Query → GraphQL Error angezeigt
   - Network Timeout → Retry-Option

## 📱 UI/UX Mockups

```
Loading States:
┌─────────────────────┐
│ 🔄 Synchronisiere..│
│                     │
│ Trips werden        │
│ geladen...          │
└─────────────────────┘

Error States:
┌─────────────────────┐
│ ⚠️ Verbindungsfehler│
│                     │
│ Backend nicht       │
│ erreichbar          │
│                     │
│ [ Erneut versuchen ]│
└─────────────────────┘
```

## ⚠️ Risiken & Überlegungen

- **Schema-Changes**: Backend-Updates können Breaking Changes verursachen
- **Cache-Invalidation**: Komplexe Cache-Logic bei Realtime-Updates
- **Memory-Usage**: Große GraphQL Responses können Memory-Issues verursachen
- **Network-Performance**: Optimistic Updates vs. Network Latency
- **Type-Safety**: Generated Types müssen aktuell gehalten werden

## 📚 Ressourcen

- [Apollo iOS Documentation](https://www.apollographql.com/docs/ios/)
- [GraphQL Best Practices](https://graphql.org/learn/best-practices/)
- [Apollo Cache Configuration](https://www.apollographql.com/docs/ios/caching/cache-configuration)
- [Swift Combine + Apollo](https://www.apollographql.com/docs/ios/tutorial/tutorial-query-ui/) 