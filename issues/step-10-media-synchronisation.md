# [MIGRATION] Schritt 10: Media-Synchronisation

## 🎯 Ziel
Vollständige Synchronisation von Fotos und Videos zwischen Geräten mit intelligenter Upload/Download-Strategie und Bandbreiten-Optimierung.

## 📋 Aufgaben

- [ ] **MediaSyncManager** - Zentrale Media-Synchronisation
- [ ] **Progressive Downloads** - Thumbnails → Full-Resolution
- [ ] **Upload Optimization** - Compression und Batch-Uploads
- [ ] **MinIO Integration** - Backend-Media-Storage
- [ ] **CloudKit Assets** - CloudKit-Media-Handling
- [ ] **Bandwidth Management** - WiFi vs. Cellular-Optimierung
- [ ] **Storage Management** - Local Cache mit intelligenter Bereinigung

## ✅ Akzeptanzkriterien

- [ ] App kompiliert erfolgreich
- [ ] Fotos/Videos syncen automatisch zwischen Geräten
- [ ] Progressive Downloads (Thumbnails zuerst)
- [ ] Intelligente Upload-Kompression
- [ ] Bandwidth-aware Synchronisation
- [ ] Local Cache funktioniert effizient
- [ ] Media ist offline verfügbar (bei explizitem Download)

## 🤖 KI-Prompt für Implementation

```
Als erfahrener iOS-Entwickler mit SwiftUI und Core Data Expertise implementiere bitte:

SCHRITT 10: Media-Synchronisation für Travel Companion iOS App

Implementiere ein vollständiges Media-Sync-System:

1. **MediaSyncManager.swift** (Zentrale Orchestrierung)
   - ObservableObject für UI-Updates
   - uploadMedia(mediaItem:) → Progress<UploadResult>
   - downloadMedia(mediaItem:quality:) → Progress<DownloadResult>
   - MediaQuality: .thumbnail, .medium, .original
   - Background-Upload/Download mit URLSession

2. **Progressive Download Strategy**
   - Thumbnail-first Download (fast loading)
   - On-demand Full-Resolution Download
   - Smart Preloading basierend auf User-Behavior
   - Cache-Hierarchie: Thumbnail → Medium → Full
   - Memory-efficient Image-Loading

3. **Upload Optimization System**
   - HEIC → JPEG Conversion mit Quality-Settings
   - Video-Compression (H.264 optimization)
   - Batch-Upload für multiple Media-Items
   - Resume-fähige Uploads bei Unterbrechung
   - Duplicate-Detection (Hash-based)

4. **MinIO Backend Integration**
   - S3-compatible Upload via MinIO
   - Presigned-URL Generation für Uploads
   - Bucket-Organization (users/trips/memories)
   - Metadata-Storage (EXIF, location, timestamps)
   - CDN-ähnliche Download-Optimization

5. **CloudKit Assets Integration**
   - CKAsset für CloudKit-Media-Storage
   - Parallel zu MinIO verfügbar
   - CloudKit Asset-Sharing für shared Trips
   - Asset-Cleanup bei CloudKit-Sync

6. **Bandwidth Management**
   - NetworkMonitor für Connection-Type
   - WiFi: Full-Quality Uploads/Downloads
   - Cellular: Compressed/Thumbnail-only
   - User-configurable Bandwidth-Settings
   - Background-Transfer nur bei WiFi

7. **Storage Management & Caching**
   - MediaCacheManager.swift
   - LRU-Cache für local Media-Storage
   - Configurable Cache-Size (GB-based)
   - Intelligent Cache-Eviction
   - Offline-Mode Media-Prioritization

8. **Progress & Status Management**
   - Upload/Download Progress-Tracking
   - Media-Sync-Status pro MediaItem
   - Queue-Management für Background-Transfers
   - Error-Recovery für failed Transfers
   - User-Notifications für completed Transfers

9. **Media Processing Pipeline**
   - EXIF-Data preservation
   - GPS-Location embedding
   - Thumbnail-Generation (multiple sizes)
   - Video-Frame-Extraction für Previews
   - Metadata-Sync zwischen Local/Remote

Verwende dabei:
- URLSession für Background-Downloads
- AVFoundation für Video-Processing
- CoreImage für Image-Processing
- Photos Framework für HEIC/JPEG handling
- FileManager für Cache-Management

Berücksichtige dabei:
- Memory-Management bei großen Media-Files
- Battery-Optimization für Background-Processing
- Privacy-Compliance für Photo-Access
- Thread-Safety für concurrent Media-Operations
- User-Experience bei langen Upload/Downloads
- Storage-Efficiency (avoid duplicates)
- German Localization für Progress-Messages
- Accessibility für Media-Progress-UI
```

## 🔗 Abhängigkeiten

- Abhängig von: #8 (Sync Engine), #9 (Hybrid-Sync)
- Blockiert: #12 (Advanced Sync Features)

## 🧪 Test-Plan

1. **Basic Media Upload**
   - Füge Foto zu Memory hinzu
   - Upload startet automatisch
   - Foto erscheint auf anderem Gerät
   - Thumbnail lädt sofort, Full-Resolution on-demand

2. **Progressive Downloads**
   - Öffne Memory mit vielen Fotos
   - Thumbnails laden sofort
   - Tap auf Foto → Full-Resolution lädt
   - Smooth User-Experience

3. **Bandwidth Optimization**
   - WiFi: Full-Quality Upload/Download
   - Cellular: Nur Thumbnails/Compressed
   - Settings-Änderung ändert Verhalten
   - Background-Transfer nur bei WiFi

4. **Cache Management**
   - Cache füllt sich mit Media
   - Bei Cache-Limit: LRU-Eviction
   - Oft verwendete Media bleiben lokal
   - Cache-Status in Settings sichtbar

5. **Error Recovery**
   - Upload-Unterbrechung (Airplane-Mode)
   - Resume bei Reconnect
   - Failed Uploads werden erneut versucht
   - User wird über Probleme informiert

## 📱 UI/UX Mockups

```
Media Upload Progress:
┌─────────────────────────┐
│ 📸 Medien synchronisieren│
│                         │
│ 🔄 IMG_001.jpg          │
│ ▓▓▓▓▓▓▓░░░ 70%         │
│                         │
│ ⏳ VID_002.mp4          │
│ ░░░░░░░░░░ Warteschlange│
│                         │
│ ✅ 5 Dateien fertig     │
└─────────────────────────┘

Media Settings:
┌─────────────────────────┐
│ 📱 Medien-Einstellungen │
│                         │
│ 📶 Über Mobilfunk:      │
│ • [x] Nur Thumbnails    │
│ • [ ] Komprimiert       │
│ • [ ] Vollqualität      │
│                         │
│ 💾 Cache: 2.1 GB / 5 GB│
│ [ Cache leeren ]        │
│                         │
│ 🔄 Auto-Upload: [Ein]   │
└─────────────────────────┘

Progressive Loading:
┌─────────────────────────┐
│ 🌅 Memory: Sonnenuntergang│
│                         │
│ [📷] [📷] [📷] [🎥]     │
│  ▓▓▓   ▓▓▓   ...   🔄   │
│                         │
│ Tippen für Vollbild     │
└─────────────────────────┘
```

## ⚠️ Risiken & Überlegungen

- **Storage Usage**: Media kann sehr viel Speicherplatz verbrauchen
- **Network Costs**: Unkontrollierte Uploads können teuer werden
- **Battery Drain**: Video-Processing ist battery-intensive
- **Privacy**: Foto-Zugriff muss DSGVO-konform sein
- **Performance**: Große Media-Files können UI blockieren

## 📚 Ressourcen

- [URLSession Background Downloads](https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background)
- [AVFoundation Media Processing](https://developer.apple.com/documentation/avfoundation)
- [Photos Framework](https://developer.apple.com/documentation/photokit)
- [Core Image Processing](https://developer.apple.com/documentation/coreimage) 