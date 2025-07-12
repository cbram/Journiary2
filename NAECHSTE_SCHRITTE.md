# 🚀 Nächste Schritte für Supabase-Integration

## ✅ Bereits erledigt:

1. **Supabase-Schema erstellt** (`supabase_schema.sql`)
2. **iOS-Konfiguration** (`SupabaseConfig.swift`)
3. **Supabase-Models** (`SupabaseModels.swift`)
4. **CoreData-Erweiterungen** (`Trip+SupabaseSync.swift`)
5. **Info.plist** für HTTP-Verbindungen konfiguriert

## 🔄 Jetzt zu erledigen:

### 1. SQL-Schema in Supabase ausführen
```bash
# Gehen Sie zu Ihrem Supabase Dashboard: http://192.168.10.20:8000
# Klicken Sie auf "SQL Editor"
# Kopieren Sie den Inhalt von supabase_schema.sql
# Führen Sie das SQL-Script aus
```

### 2. Supabase Swift Package hinzufügen
```swift
// In Xcode:
// File → Add Package Dependencies...
// URL: https://github.com/supabase/supabase-swift
// Version: 2.0.0 oder höher
```

### 3. CoreData-Model erweitern
Das CoreData-Model `Journiary.xcdatamodeld` muss um die neuen Sync-Attribute erweitert werden:

**Neue Attribute für Trip-Entity:**
- `syncVersion` (Integer 32, Default: 1)
- `lastSyncDate` (Date, Optional)
- `needsSync` (Boolean, Default: NO)
- `supabaseID` (UUID, Optional)
- `createdAt` (Date, Optional)
- `updatedAt` (Date, Optional)  
- `coverImageUrl` (String, Optional)

**Anleitung:**
1. Öffnen Sie `Journiary.xcdatamodeld` in Xcode
2. Klicken Sie auf die "Trip" Entity
3. Fügen Sie die oben genannten Attribute hinzu
4. Speichern Sie das Model

### 4. Package Dependencies konfigurieren
Fügen Sie zu `Package.swift` hinzu (oder über Xcode Package Manager):

```swift
dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
]
```

## 🔨 Als nächstes implementieren:

### 1. SupabaseManager Service
### 2. TripSyncService 
### 3. UI-Integration in TripView

## 📋 Checkliste:

- [ ] SQL-Schema in Supabase ausgeführt
- [ ] Supabase Swift Package hinzugefügt
- [ ] CoreData-Model erweitert
- [ ] App ohne Fehler kompiliert
- [ ] Netzwerkverbindung zu Supabase getestet

## 🆘 Bei Problemen:

1. **Compile-Fehler**: Stellen Sie sicher, dass alle neuen Dateien zum Xcode-Projekt hinzugefügt wurden
2. **Netzwerk-Fehler**: Überprüfen Sie die IP-Adresse und den Port Ihrer Supabase-Installation
3. **CoreData-Fehler**: Möglicherweise müssen Sie die App neu installieren nach Model-Änderungen

## 🎯 Nächste Implementierungsrunde:

Nach Abschluss dieser Schritte können wir:
- **SupabaseManager** implementieren
- **TripSyncService** erstellen
- **Erste Sync-Tests** durchführen
- **UI-Integration** beginnen

Melden Sie sich, wenn Sie diese Schritte abgeschlossen haben oder bei Problemen Hilfe benötigen! 