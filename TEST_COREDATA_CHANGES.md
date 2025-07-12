# 🧪 Test-Anleitung: CoreData-Änderungen

## ✅ Was wurde geändert:

1. **CoreData-Model erweitert**: 7 neue Sync-Attribute zur Trip-Entity hinzugefügt
2. **SyncSetupManager erstellt**: Für Initialisierung bestehender Daten

## 🏗️ Neue Trip-Attribute:

- `syncVersion` (Integer 32, Default: 1)
- `lastSyncDate` (Date, Optional)
- `needsSync` (Boolean, Default: NO)
- `supabaseID` (UUID, Optional)
- `createdAt` (Date, Optional)
- `updatedAt` (Date, Optional)
- `coverImageUrl` (String, Optional)

## 🔬 Test-Schritte:

### 1. Kompilierung testen
```bash
# In Xcode:
# Command + B (Build)
# Sollte ohne Fehler kompilieren
```

### 2. App-Start testen
```swift
// Falls die App nicht startet, müssen Sie möglicherweise:
// 1. App deinstallieren (CoreData-Schema-Änderung)
// 2. App neu installieren
// 3. Simulator zurücksetzen: Device → Erase All Content and Settings
```

### 3. Sync-Setup initialisieren
```swift
// Fügen Sie temporär in AppDelegate oder SceneDelegate hinzu:
let context = PersistenceController.shared.container.viewContext
SyncSetupManager.initializeSyncForExistingData(context: context)
SyncSetupManager.validateSyncSetup(context: context)
```

### 4. Debug-Informationen anzeigen
```swift
// Temporär in einer View hinzufügen:
Button("Debug Sync Info") {
    let context = PersistenceController.shared.container.viewContext
    SyncSetupManager.printSyncDebugInfo(context: context)
}
```

## 🚨 Mögliche Probleme & Lösungen:

### Problem: App crasht beim Start
**Lösung**: CoreData-Schema-Änderung erfordert Reset
```bash
# Lösungen:
1. App deinstallieren und neu installieren
2. Simulator → Device → Erase All Content and Settings
3. Core Data → "Delete and Re-create" (nur für Development)
```

### Problem: Attribute nicht verfügbar
**Lösung**: Xcode-Projekt aktualisieren
```bash
# Schritte:
1. Xcode schließen
2. Projekt neu öffnen
3. Product → Clean Build Folder
4. Neu kompilieren
```

### Problem: Compile-Fehler in Trip+SupabaseSync.swift
**Lösung**: CoreData-Model nicht richtig erweitert
```bash
# Prüfen Sie:
1. Sind alle 7 Attribute in der Trip-Entity vorhanden?
2. Haben sie die korrekten Datentypen?
3. Ist das Model gespeichert?
```

## 📱 Schnelltest in der App:

### 1. Trip erstellen
```swift
// Erstellen Sie eine neue Reise in der App
// Prüfen Sie, ob sie gespeichert wird
```

### 2. Sync-Attribute prüfen
```swift
// Fügen Sie temporär hinzu:
if let trip = allTrips.first {
    print("Trip Debug Info:")
    print(trip.syncDebugInfo())
}
```

### 3. Erwartete Ausgabe:
```
Trip Sync Debug Info:
- Name: Ihre Reise
- Supabase ID: nil
- Sync Version: 1
- Needs Sync: true
- Last Sync: nie
- Updated At: 2024-06-08 12:00:00
```

## ✅ Erfolg-Kriterien:

- [ ] App kompiliert ohne Fehler
- [ ] App startet ohne Crash
- [ ] Neue Trips können erstellt werden
- [ ] Sync-Attribute sind verfügbar
- [ ] SyncSetupManager funktioniert
- [ ] Debug-Informationen werden angezeigt

## 🎯 Nächste Schritte:

Nach erfolgreichem Test können wir:
1. **SupabaseManager** implementieren
2. **TripSyncService** erstellen
3. **Erste Sync-Tests** durchführen

## 📞 Bei Problemen:

Melden Sie sich mit:
- Fehlermeldungen (Screenshots)
- Console-Ausgaben
- Welcher Schritt fehlschlägt

Dann kann ich gezielt helfen! 