# GraphQL Client & API Layer Integration

## Übersicht

Diese Implementierung stellt eine vollständige Apollo GraphQL Integration für die Travel Companion iOS App bereit. Sie umfasst:

- **Apollo Client Setup** mit JWT Authentication
- **Automatische Code-Generation** aus GraphQL Schema
- **DTOs** für bidirektionale Core Data ↔ GraphQL Konvertierung
- **Service Layer** für alle API-Operationen
- **Robustes Error Handling** mit deutschen Fehlermeldungen
- **Cache Management** mit SQLite Persistence
- **Sync Services** für Offline/Online Synchronisation

## Architektur

```
┌─────────────────────┐
│   SwiftUI Views     │
├─────────────────────┤
│   AuthManager       │
│   Services Layer    │
├─────────────────────┤
│   Apollo Client     │
│   DTOs              │
├─────────────────────┤
│   Core Data         │
│   Local Storage     │
└─────────────────────┘
```

## Komponenten

### 1. Apollo Client (`ApolloClient.swift`)

**Features:**
- JWT Authentication Interceptor
- Automatisches Token-Refresh
- SQLite + In-Memory Cache (layered)
- Error Handling mit Retry-Logic
- Backend-URL Configuration

**Verwendung:**
```swift
let apolloClient = ApolloClientManager.shared.apollo
```

### 2. GraphQL Operations (`/Operations/*.graphql`)

**Verfügbare Operations:**
- **User**: Login, Register, UpdateProfile, GetCurrentUser
- **Trip**: CRUD Operations, Sharing, Members
- **Memory**: CRUD Operations, Search
- **Media**: Upload/Download mit Presigned URLs
- **Tag**: Tag & Category Management
- **Sync**: Bulk Operations, Real-time Updates

### 3. DTOs (`/DTOs/*.swift`)

**Bidirektionale Konvertierung:**
```swift
// Core Data → GraphQL
let tripDTO = TripDTO.from(coreData: trip)
let input = tripDTO.toGraphQLInput()

// GraphQL → Core Data
let tripDTO = TripDTO.from(graphQL: responseData)
let trip = tripDTO.toCoreData(context: context)
```

### 4. Service Layer (`/Services/*.swift`)

**Verfügbare Services:**
- `GraphQLUserService` - Authentication & User Management
- `GraphQLTripService` - Trip CRUD & Sharing
- `GraphQLMemoryService` - Memory Management
- `GraphQLMediaService` - Media Upload/Download
- `GraphQLTagService` - Tag Management
- `GraphQLSyncService` - Bulk Synchronisation

## Setup & Installation

### 1. Apollo CLI Installation

```bash
# Apollo CLI installieren
npm install -g @apollo/rover

# Setup Script ausführen
./setup_apollo.sh
```

### 2. Xcode Projekt Konfiguration

1. **Package Dependencies hinzufügen:**
   - Apollo iOS: `https://github.com/apollographql/apollo-ios.git`

2. **Build Phase hinzufügen:**
   ```bash
   # Run Script Phase
   $(SRCROOT)/apollo_codegen_build_phase.sh
   ```

3. **Schema herunterladen:**
   ```bash
   rover graph introspect http://localhost:4000/graphql > schema.graphqls
   ```

### 3. Code Generation

```bash
# Automatisch bei Xcode Build
# Oder manuell:
apollo-ios-cli generate \
    --schema-name JourniaryAPI \
    --module-type swiftPackageManager \
    --target-name JourniaryAPI \
    --output Journiary/GraphQL/Generated
```

## Verwendung

### 1. Authentication

```swift
// Login
let authManager = GraphQLAuthManager.shared

authManager.login(email: "user@example.com", password: "password")

// Status überwachen
authManager.$isAuthenticated.sink { isAuthenticated in
    // UI Update
}
```

### 2. Trip Management

```swift
let tripService = GraphQLTripService()

// Trip erstellen
let newTrip = TripDTO(
    id: UUID().uuidString,
    name: "Sommerurlaub 2024",
    description: "Reise nach Italien",
    startDate: Date(),
    endDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
    userId: "user-id",
    createdAt: Date(),
    updatedAt: Date()
)

tripService.createTrip(newTrip)
    .sink(
        receiveCompletion: { completion in
            // Error Handling
        },
        receiveValue: { createdTrip in
            // Success
        }
    )
```

### 3. Media Upload

```swift
let mediaService = GraphQLMediaService()

// Bild hochladen
mediaService.uploadImage(
    image,
    filename: "vacation_photo.jpg",
    memoryId: "memory-id"
)
.sink(
    receiveCompletion: { completion in
        // Error Handling
    },
    receiveValue: { mediaItem in
        // Success - Media wurde hochgeladen
    }
)
```

### 4. Synchronisation

```swift
let syncService = GraphQLSyncService()

// Vollständige Synchronisation
syncService.performFullSync()
    .sink(
        receiveCompletion: { completion in
            // Error Handling
        },
        receiveValue: { syncResult in
            print("Downloaded: \(syncResult.downloadedItems)")
            print("Uploaded: \(syncResult.uploadedItems)")
            print("Conflicts: \(syncResult.conflictCount)")
        }
    )

// Sync Progress überwachen
syncService.$syncProgress.sink { progress in
    // Update Progress UI
}
```

## Error Handling

### 1. GraphQL Errors

```swift
enum GraphQLError: LocalizedError {
    case networkError(String)
    case graphqlErrors([String])
    case invalidResponse
    case authenticationRequired
    case tokenExpired
    case serverError(Int)
    case cacheError(String)
    case unknown(String)
}
```

### 2. Error Recovery

```swift
// Automatisches Token-Refresh
// Retry-Logic für temporäre Netzwerkfehler
// Fallback zu Demo-Mode bei Development

// Error Handling in Views
.onReceive(authManager.$authenticationError) { error in
    if let error = error {
        switch error {
        case .tokenExpired:
            // Show re-login dialog
        case .networkError:
            // Show retry option
        default:
            // Show generic error
        }
    }
}
```

## Cache Management

### 1. Apollo Cache Policies

```swift
// Verfügbare Cache Policies:
// - .returnCacheDataElseFetch (Standard)
// - .fetchIgnoringCacheData (Force refresh)
// - .returnCacheDataDontFetch (Offline-first)
// - .returnCacheDataAndFetch (Background update)

apolloClient.fetch(
    query: GetTripsQuery(),
    cachePolicy: .returnCacheDataElseFetch
)
```

### 2. Cache Invalidation

```swift
// Cache leeren
apolloClient.clearCache { result in
    switch result {
    case .success:
        print("Cache cleared")
    case .failure(let error):
        print("Cache clear failed: \(error)")
    }
}

// Spezifische Queries invalidieren
apolloClient.store.removeObject(for: tripCacheKey)
```

## Offline Support

### 1. Core Data als Primary Store

- Core Data bleibt die primäre Datenquelle
- GraphQL dient als Synchronisationslayer
- Offline-Fähigkeiten bleiben erhalten

### 2. Sync Strategien

```swift
// Background Sync
syncService.performFullSync()

// Conflict Resolution
// - Last-Write-Wins (Standard)
// - Manual Conflict Resolution (Advanced)

// Queue für Offline-Changes
// - Lokale Änderungen werden in Queue gespeichert
// - Synchronisation bei Netzwerk-Wiederherstellung
```

## Demo Mode

Für Development und Testing steht ein Demo-Mode zur Verfügung:

```swift
// Automatisch aktiv bei localhost Backend
let isDemoMode = backendURL.contains("localhost")

// Simulierte API-Responses
// Keine echten Netzwerk-Requests
// Schnelle Development-Iteration
```

## Migration Guide

### 1. Bestehenden UserService ersetzen

```swift
// Alt:
let userService = UserService()

// Neu:
let userService = GraphQLUserService()
```

### 2. AuthManager Integration

```swift
// Alt:
AuthManager.shared

// Neu (nach vollständiger Migration):
GraphQLAuthManager.shared
```

### 3. Graduelle Migration

1. **Phase 1**: Apollo Client Setup
2. **Phase 2**: User Authentication
3. **Phase 3**: Trip Management
4. **Phase 4**: Memory & Media
5. **Phase 5**: Full Sync Implementation

## Best Practices

### 1. Error Handling

- Immer deutsche Fehlermeldungen
- Graceful Degradation bei Netzwerkfehlern
- Retry-Logic für temporäre Probleme

### 2. Performance

- Lazy-Loading für große Datensätze
- Pagination für Listen
- Image-Thumbnails für bessere Performance

### 3. Security

- JWT Token Refresh
- Secure Keychain Storage
- Input Validation

### 4. Testing

- Mock Services für Unit Tests
- Demo Mode für UI Tests
- GraphQL Mocking

## Troubleshooting

### 1. Code Generation Probleme

```bash
# Schema neu herunterladen
rover graph introspect http://localhost:4001/graphql > schema.graphqls

# Cache leeren
rm -rf Journiary/GraphQL/Generated

# Neu generieren
apollo-ios-cli generate
```

### 2. Authentication Probleme

```bash
# Token prüfen
print(authManager.getJWTToken())

# Cache leeren
apolloClient.clearCache()

# Re-login
authManager.logout()
authManager.login(...)
```

### 3. Sync Probleme

```bash
# Sync Status prüfen
print(syncService.lastSyncTimestamp)

# Vollständiger Reset
syncService.performFullSync()
```

## Support

- **Apollo iOS Dokumentation**: https://www.apollographql.com/docs/ios/
- **GraphQL Specification**: https://graphql.org/
- **Core Data Integration**: Siehe `DTOs/` Implementierung

## Version History

- **v1.0**: Initial Apollo Integration
- **v1.1**: Media Upload/Download
- **v1.2**: Sync Services
- **v1.3**: Demo Mode & Error Handling 