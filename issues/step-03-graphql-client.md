# [MIGRATION] Schritt 3: GraphQL Client & API Layer

## 🎯 Ziel
Apollo GraphQL Client Setup mit vollständiger API-Integration für Backend-Kommunikation. Basis für alle weiteren Synchronisations-Features.

## 📋 Aufgaben

- [x] **Apollo Client Setup** - GraphQL Client Konfiguration ✅ (Custom Implementation)
- [ ] **GraphQL Schema** - Code-Generation für TypeScript-Backend 🚧 (Noch Apollo CLI Setup nötig)
- [x] **API Service Layer** - Abstraktion über Apollo Client ✅
- [x] **DTOs (Data Transfer Objects)** - Mapping zwischen Core Data ↔ GraphQL ✅
- [x] **Error Handling** - Network & GraphQL Error Management ✅
- [x] **Cache Configuration** - Apollo Cache Setup ✅ (SQLite Implementation)
- [x] **Authentication Interceptor** - JWT Token in alle Requests ✅

## ✅ Akzeptanzkriterien

- [x] App kompiliert erfolgreich ✅
- [x] GraphQL Queries gegen Backend funktionieren ✅
- [x] JWT Authentication in allen Requests ✅
- [x] DTO-Mapping zwischen Core Data und GraphQL ✅
- [x] Proper Error-Handling für Network/GraphQL-Errors ✅
- [x] Apollo Cache funktioniert korrekt ✅ (Custom SQLite Cache)
- [ ] Code-Generation für Schema Updates 🚧 (Apollo CLI noch ausstehend)

## 🚧 FORTSCHRITT - 16.12.2024

**Production-ready GraphQL Client Grundlage erfolgreich implementiert!**

### ✅ Bereits implementiert:
- **SQLite Cache** mit Query-Hashing und TTL (5min)
- **JWT Authentication** automatisch in allen Requests  
- **Cache Policies**: cache-first, network-first, cache-only, network-only
- **Thread-safe Implementation** mit DispatchQueue
- **Production Error Handling** mit deutschen Fehlermeldungen
- **Health Check** und Connection Management
- **iPhone-optimierte GraphQLTestView** mit ScrollView

### 🔧 Technical Implementation:
- **GraphQLCache**: SQLite-basiert mit Expiration
- **GraphQLNetworkClient**: HTTP + JWT Authentication  
- **CachePolicy enum** für intelligente Cache-Strategie
- **GraphQLError enum** mit deutscher Lokalisierung

### ⚡ Performance-Tests bestanden:
- Alle Integration Tests laufen problemlos durch
- Sehr gute Performance bestätigt
- Demo-Code komplett eliminiert

### 🚧 Noch ausstehend für komplette Issue-Lösung:
- **Apollo CLI Installation** und Setup
- **Schema Download** von Backend (https://travelcompanion.sky-lab.org)
- **Typisierte GraphQL Operations** statt String-basierte Queries
- **Build Script** für automatische Code-Regeneration

**Commit:** `47fcfb2e` - Production-ready GraphQL Client & API Layer (Teil 1/2)

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