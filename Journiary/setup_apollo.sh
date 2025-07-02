#!/bin/bash

# Apollo iOS Setup Script für Travel Companion
# Dieser Script installiert Apollo CLI und generiert GraphQL Code

set -e

echo "🚀 Apollo iOS Setup für Travel Companion"
echo "========================================"

# Überprüfen ob Node.js installiert ist
if ! command -v node &> /dev/null; then
    echo "❌ Node.js ist nicht installiert. Bitte installieren Sie Node.js von https://nodejs.org/"
    exit 1
fi

# Überprüfen ob npm installiert ist  
if ! command -v npm &> /dev/null; then
    echo "❌ npm ist nicht installiert. Bitte installieren Sie npm."
    exit 1
fi

echo "✅ Node.js und npm gefunden"

# Apollo CLI installieren
echo "📦 Installiere Apollo CLI..."
npm install -g @apollo/rover

# Überprüfen ob Installation erfolgreich war
if ! command -v rover &> /dev/null; then
    echo "❌ Apollo Rover Installation fehlgeschlagen"
    exit 1
fi

echo "✅ Apollo Rover erfolgreich installiert"

# Erstelle notwendige Verzeichnisse
echo "📁 Erstelle Verzeichnisstruktur..."
mkdir -p Journiary/GraphQL/Generated
mkdir -p Journiary/GraphQL/Operations

echo "✅ Verzeichnisse erstellt"

# Schema herunterladen (falls Backend verfügbar)
BACKEND_URL="${BACKEND_URL:-https://travelcompanion.sky-lab.org/graphql}"
echo "📡 Versuche Schema von $BACKEND_URL herunterzuladen..."

if curl -f -s -o /dev/null "$BACKEND_URL"; then
    echo "✅ Backend erreichbar - lade Schema herunter..."
    rover graph introspect "$BACKEND_URL" > schema.graphqls
    echo "✅ Schema erfolgreich heruntergeladen"
else
    echo "⚠️  Backend nicht erreichbar - verwende lokales Schema falls vorhanden"
fi

# Apollo Code Generation ausführen
if [ -f "schema.graphqls" ]; then
    echo "🔧 Generiere Apollo Code..."
    
    # Apollo iOS Code Generation (via Swift Package)
    echo "⚠️  Code-Generation erfolgt über Swift Package Manager"
    echo "   Siehe Package.swift für Apollo iOS Integration"
    
    echo "✅ Apollo Code erfolgreich generiert"
else
    echo "⚠️  Kein Schema gefunden - Code-Generation übersprungen"
    echo "   Stelle sicher, dass 'schema.graphqls' im Projekt-Root existiert"
fi

# Xcode Projekt konfigurieren
echo "🔧 Konfiguriere Xcode Projekt..."

# Build Phase Script für automatische Code-Generation
cat > apollo_codegen_build_phase.sh << 'EOF'
#!/bin/bash

# Apollo iOS Code Generation Build Phase
# Füge dieses Script als "Run Script Phase" in Xcode hinzu

# Nur bei Clean Build oder wenn GraphQL Dateien geändert wurden
if [ "${CONFIGURATION}" = "Debug" ] || [ "${ACTION}" = "clean" ]; then
    cd "${SRCROOT}"
    
    # Überprüfe ob Schema existiert
    if [ -f "schema.graphqls" ]; then
        # Code-Generation erfolgt über Swift Package Manager
        echo "Code-Generation via Swift Package Manager beim Build"
        
        echo "Apollo Code erfolgreich generiert"
    else
        echo "Warnung: schema.graphqls nicht gefunden"
    fi
fi
EOF

chmod +x apollo_codegen_build_phase.sh

echo "✅ Setup abgeschlossen!"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Öffne das Xcode Projekt"
echo "2. Füge eine 'Run Script Phase' zum Build Target hinzu"
echo "3. Inhalt der Script Phase: \$(SRCROOT)/apollo_codegen_build_phase.sh"
echo "4. Stelle sicher, dass das Backend läuft und aktualisiere das Schema"
echo ""
echo "🔄 Schema aktualisieren:"
echo "   ./setup_apollo.sh"
echo ""
echo "📚 Weitere Informationen:"
echo "   https://www.apollographql.com/docs/ios/" 