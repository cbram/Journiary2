# [MIGRATION] Schritt 2: Benutzer-System Implementation

## 🎯 Ziel
Benutzer-System mit Registrierung, Login und JWT-Token-Management für Backend-Authentifizierung implementieren. CloudKit behält automatische User-Detection.

## 📋 Aufgaben

- [ ] **User.swift** - Core Data Entität für lokale User-Speicherung
- [ ] **AuthManager.swift** - JWT Token Management & Authentication
- [ ] **LoginView.swift** - Login-Formular für Backend-Mode
- [ ] **RegisterView.swift** - Registrierung für neue User
- [ ] **UserService.swift** - GraphQL User Queries & Mutations
- [ ] **Core Data Migration** - User Entity hinzufügen
- [ ] **App State** - User Session Management

## ✅ Akzeptanzkriterien

- [ ] App kompiliert erfolgreich
- [ ] User Registration über UI funktioniert
- [ ] Login mit Email/Password funktioniert
- [ ] JWT Token wird sicher gespeichert
- [ ] Auto-Login bei App-Start
- [ ] Logout löscht Token und Session
- [ ] CloudKit-Mode funktioniert weiterhin ohne User-System

## 🤖 KI-Prompt für Implementation

```
Als erfahrener iOS-Entwickler mit SwiftUI und Core Data Expertise implementiere bitte:

SCHRITT 2: Benutzer-System für Travel Companion iOS App

Implementiere ein vollständiges User-System:

1. **User.swift** (Core Data Entity)
   - id: UUID
   - email: String
   - username: String
   - firstName: String?
   - lastName: String?
   - isCurrentUser: Bool
   - backendUserId: String? (für Backend-Sync)
   - createdAt: Date
   - updatedAt: Date

2. **AuthManager.swift** (ObservableObject)
   - JWT Token Management (Keychain-Speicherung)
   - Login/Logout Funktionen
   - Auto-Login bei App-Start
   - Token-Refresh-Logic
   - Published currentUser Property
   - isAuthenticated computed property

3. **LoginView.swift** (SwiftUI View)
   - Email TextField
   - Password SecureField
   - "Anmelden" Button
   - "Registrieren" Link
   - Loading-State
   - Error-Handling mit Alerts

4. **RegisterView.swift** (SwiftUI View)
   - Email, Username, Password, Confirm Password
   - "Registrieren" Button
   - Validation (Email-Format, Password-Länge)
   - Success/Error-Handling

5. **UserService.swift** (GraphQL Service)
   - login(email:password:) -> JWT Token
   - register(user:) -> User
   - getCurrentUser() -> User
   - updateUser() -> User
   - Error-Handling für Network/Auth-Errors

6. **Core Data Migration**
   - User Entity zum Model hinzufügen
   - Migration für bestehende Daten
   - Relationships zu Trip/Memory vorbereiten

7. **App-Integration**
   - AuthManager in App-Environment
   - Login-Screen als Initial View bei Backend-Mode
   - Tab-Navigation nur bei authentifiziertem User

Berücksichtige dabei:
- JWT Token sicher in Keychain speichern
- AppSettings.storageMode berücksichtigen
- CloudKit-Mode überspringt User-System
- Proper Error-Handling für Network-Failures
- German Localization
- Accessibility Support
- Password-Validation (min. 8 Zeichen)
- Email-Format-Validation
```

## 🔗 Abhängigkeiten

- Abhängig von: #1 (Backend-Integration Setup)
- Blockiert: #3 (GraphQL Client), #4 (Multi-User Core Data)

## 🧪 Test-Plan

1. **User Registration (Backend-Mode)**
   - Öffne App im Backend-Mode
   - Klicke "Neuen Account erstellen"
   - Fülle alle Felder aus
   - Registration erfolgreich → Auto-Login

2. **User Login**
   - Öffne App im Backend-Mode
   - Gebe Email/Password ein
   - Login erfolgreich → Hauptansicht öffnet sich
   - Bei falschen Credentials → Error-Message

3. **Token-Persistierung**
   - Login erfolgreich
   - App schließen und neu öffnen
   - User ist automatisch eingeloggt

4. **Logout**
   - Klicke Logout-Button
   - Wird zur Login-Ansicht weitergeleitet
   - Token ist gelöscht

5. **CloudKit-Mode**
   - Wechsle zu CloudKit-Mode
   - Kein Login erforderlich
   - App funktioniert normal

## 📱 UI/UX Mockups

```
Backend-Mode App Start:
┌─────────────────────┐
│  Travel Companion  │
│                     │
│  Email: [_______]   │
│  Passwort: [____]   │
│                     │
│  [ Anmelden ]       │
│                     │
│  Noch kein Account? │
│  → Registrieren     │
└─────────────────────┘

Nach Login:
┌─────────────────────┐
│ ⚙️ Settings         │
│                     │
│ 👤 Max Mustermann   │
│ 📧 max@example.com  │
│                     │
│ [ Abmelden ]        │
└─────────────────────┘
```

## ⚠️ Risiken & Überlegungen

- **Token-Sicherheit**: JWT in Keychain, nie in UserDefaults
- **Token-Expiry**: Refresh-Logic implementieren
- **Network-Failures**: Graceful Degradation bei Offline-Mode
- **Password-Sicherheit**: Minimum Requirements kommunizieren
- **Data-Migration**: Bestehende Trips/Memories User zuweisen

## 📚 Ressourcen

- [JWT Token Best Practices](https://auth0.com/blog/a-look-at-the-latest-draft-for-jwt-bcp/)
- [iOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [SwiftUI Authentication Flow](https://developer.apple.com/documentation/swiftui/managing-user-interface-state)
- [Core Data Lightweight Migration](https://developer.apple.com/documentation/coredata/using_lightweight_migration) 