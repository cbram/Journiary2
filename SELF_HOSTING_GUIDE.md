# 🏠 Self-Hosting Anleitung für Travel Companion

## Übersicht

Travel Companion ist eine Self-Hosting-App. Das bedeutet, dass **keine Default-Server-URL** konfiguriert ist und Sie Ihren eigenen Backend-Server betreiben müssen.

## ✅ Was ist bereits vorbereitet

- ✅ **Keine hardcodierten Server-URLs** - Schutz vor ungewollter Nutzung fremder Server
- ✅ **Flexible Backend-Konfiguration** - Jeder kann seinen eigenen Server verwenden
- ✅ **Production-ready GraphQL Client** - Vollständige API-Integration
- ✅ **Automatische Server-Validierung** - Connection-Tests vor der Nutzung

## 🚀 Setup für End-User (App Store Download)

### Schritt 1: Backend-Server betreiben
1. **Docker-Compose** aus diesem Repository verwenden:
   ```bash
   cd server-deployment
   docker-compose up -d
   ```

2. **Eigenen Server deployen** (siehe Backend-Dokumentation)

### Schritt 2: App konfigurieren
1. **App aus App Store herunterladen**
2. **Bei erstem Start**: App fragt nach Server-Konfiguration
3. **Server-URL eingeben**: `https://ihr-server.com/graphql`
4. **Anmeldedaten eingeben**: Username und Passwort
5. **Verbindung testen**: App validiert Server-Erreichbarkeit

### Schritt 3: Synchronisation aktivieren
- **Storage Mode wählen**: Backend, CloudKit oder Hybrid
- **Auto-Sync aktivieren**: Für automatische Synchronisation
- **Sync-Intervall setzen**: Nach Bedarf (5 Minuten Standard)

## 🔧 Für Entwickler

### Schema-Download konfigurieren
```bash
# Backend-URL als Umgebungsvariable setzen
export BACKEND_URL="https://ihr-server.com/graphql"

# Schema herunterladen
cd Journiary
./update_schema.sh
```

### Xcode Build-Integration
1. **Build Phase hinzufügen**: "Run Script Phase"
2. **Script-Pfad**: `$(SRCROOT)/Journiary/apollo_codegen_build_phase.sh`
3. **Umgebungsvariable setzen**: `BACKEND_URL` in Xcode Schema

### Development-Setup
```bash
# Lokales Backend für Development
export BACKEND_URL="http://localhost:4001/graphql"
./update_schema.sh
```

## 🛡️ Sicherheits-Features

### Kein Default-Server
```swift
// ✅ Korrekt: Leere URL zwingt zur Konfiguration
let defaultURL = ""

// ❌ Falsch: Hardcodierte URLs
// let defaultURL = "https://fremder-server.com"
```

### Explizite Konfiguration
- **Kein automatischer Fallback** auf fremde Server
- **User muss bewusst** seinen Server eingeben
- **Connection-Test** vor der ersten Nutzung
- **Validierung** der Server-Antworten

### Schema-Download Sicherheit
```bash
# ✅ Korrekt: Explizite URL erforderlich
BACKEND_URL=https://ihr-server.com/graphql ./update_schema.sh

# ❌ Falsch: Automatischer Fallback
# ./update_schema.sh  # Würde Fehler ausgeben
```

## 🔄 Update-Prozess

### App-Updates
1. **Schema-Kompatibilität prüfen**: Neue App-Version mit Backend testen
2. **Schema aktualisieren**: `./update_schema.sh` nach Backend-Updates
3. **Build neu erstellen**: Bei Schema-Änderungen

### Backend-Updates
1. **Backend aktualisieren**: Docker-Container oder Server
2. **Schema herunterladen**: Mit Update-Skript
3. **App testen**: Funktionalität validieren

## 📱 User Experience

### Erste Nutzung
1. **App-Start**: "Backend konfigurieren" Screen
2. **URL eingeben**: Server-Adresse mit `/graphql` Endpunkt
3. **Credentials eingeben**: Username/Passwort für Backend
4. **Test durchführen**: App prüft Server-Erreichbarkeit
5. **Ready to use**: Nach erfolgreicher Konfiguration

### Fehlerbehebung
- **"Backend nicht erreichbar"**: URL oder Server-Status prüfen
- **"Anmeldung fehlgeschlagen"**: Credentials überprüfen
- **"Schema-Fehler"**: Backend-Version mit App kompatibel?

## 🏗️ Deployment-Beispiele

### Einfaches Docker-Setup
```yaml
# docker-compose.yml
version: '3.8'
services:
  journiary-backend:
    image: journiary/backend:latest
    ports:
      - "4001:4001"
    environment:
      - DATABASE_URL=sqlite:./data/journiary.sqlite
      - JWT_SECRET=your-secret-here
    volumes:
      - ./data:/app/data
```

### Nginx Reverse Proxy
```nginx
# nginx.conf
server {
    listen 443 ssl;
    server_name ihr-server.com;
    
    location /graphql {
        proxy_pass http://localhost:4001/graphql;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Traefik Labels
```yaml
# docker-compose.yml
services:
  journiary-backend:
    image: journiary/backend:latest
    labels:
      - "traefik.http.routers.journiary.rule=Host(`ihr-server.com`) && Path(`/graphql`)"
      - "traefik.http.services.journiary.loadbalancer.server.port=4001"
```

## ⚠️ Wichtige Hinweise

### Für App-Store-Benutzer
- **Kein Default-Server**: Sie müssen Ihren eigenen Server betreiben
- **Server-URL erforderlich**: App funktioniert nicht ohne Backend-Konfiguration
- **Selbst-Hosting notwendig**: Keine kostenlose Cloud-Option verfügbar

### Für Entwickler
- **Keine hardcodierten URLs**: Immer Umgebungsvariablen verwenden
- **Schema-Updates**: Bei Backend-Änderungen erforderlich
- **Connection-Tests**: Vor Production-Deployment durchführen

### Für Server-Administratoren
- **HTTPS empfohlen**: Für Production-Deployments
- **CORS konfigurieren**: Für Web-Client-Zugriff
- **Backup-Strategie**: Für Datenbank und Media-Files

## 📞 Support

Bei Problemen mit der Self-Hosting-Konfiguration:
1. **Server-Logs prüfen**: Backend-Container oder Service
2. **Network-Debugging**: Erreichbarkeit testen
3. **Schema-Validierung**: Mit GraphQL Playground
4. **Connection-Test**: In der App verwenden

## 🔗 Weitere Ressourcen

- **Backend-Dokumentierung**: `backend/README.md`
- **Docker-Setup**: `server-deployment/README.md`
- **GraphQL-Schema**: `schema.graphqls`
- **Migration-Guide**: `MIGRATION_PLAN.md` 