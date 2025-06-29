#!/bin/bash

# Production-Ready GraphQL Schema Update Script
# Downloads schema from configured backend URL (no hardcoded localhost)

set -e

echo "🔄 GraphQL Schema Update für Travel Companion"
echo "============================================="

# Farben für bessere Lesbarkeit
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Überprüfen ob Rover installiert ist
if ! command -v rover &> /dev/null; then
    echo -e "${RED}❌ Apollo Rover ist nicht installiert.${NC}"
    echo "Installiere mit: npm install -g @apollo/rover"
    exit 1
fi

echo -e "${GREEN}✅ Apollo Rover gefunden${NC}"

# Backend URL muss als Umgebungsvariable gesetzt werden
# Kein Default für Self-Hosting App
if [ -z "$BACKEND_URL" ]; then
    echo -e "${RED}❌ BACKEND_URL nicht konfiguriert${NC}"
    echo "Für Self-Hosting Apps muss die Backend-URL explizit gesetzt werden:"
    echo "  BACKEND_URL=https://your-server.com/graphql ./update_schema.sh"
    echo ""
    echo "Beispiele:"
    echo "  BACKEND_URL=https://journiary.example.com/graphql ./update_schema.sh"
    echo "  BACKEND_URL=http://localhost:4001/graphql ./update_schema.sh  # Nur Development"
    exit 1
fi

echo -e "${YELLOW}📡 Backend URL: $BACKEND_URL${NC}"

# Überprüfen ob Backend erreichbar ist
echo "🔍 Überprüfe Backend-Erreichbarkeit..."
if curl -f -s -m 10 "$BACKEND_URL" > /dev/null; then
    echo -e "${GREEN}✅ Backend ist erreichbar${NC}"
else
    echo -e "${RED}❌ Backend nicht erreichbar: $BACKEND_URL${NC}"
    echo "Mögliche Ursachen:"
    echo "  • Backend Server ist offline"
    echo "  • URL ist falsch konfiguriert"
    echo "  • Netzwerkverbindung fehlgeschlagen"
    exit 1
fi

# Schema introspektieren und herunterladen
echo "📥 Lade GraphQL Schema herunter..."
if rover graph introspect "$BACKEND_URL" > schema.graphqls.tmp; then
    
    # Überprüfen ob Schema gültig ist
    if [ -s schema.graphqls.tmp ]; then
        # Backup des alten Schemas (falls vorhanden)
        if [ -f schema.graphqls ]; then
            cp schema.graphqls schema.graphqls.backup
            echo -e "${YELLOW}💾 Altes Schema als schema.graphqls.backup gesichert${NC}"
        fi
        
        # Neues Schema aktivieren
        mv schema.graphqls.tmp schema.graphqls
        echo -e "${GREEN}✅ Schema erfolgreich heruntergeladen${NC}"
        
        # Schema-Info anzeigen
        SCHEMA_SIZE=$(wc -l < schema.graphqls)
        echo -e "${GREEN}📊 Schema enthält $SCHEMA_SIZE Zeilen${NC}"
        
        # Introspection für Apollo Client Cache
        if [ -f introspection.json ]; then
            cp introspection.json introspection.json.backup
        fi
        
        rover graph introspect "$BACKEND_URL" --format json > introspection.json 2>/dev/null || echo -e "${YELLOW}⚠️  Introspection JSON konnte nicht erstellt werden (optional)${NC}"
        
    else
        echo -e "${RED}❌ Heruntergeladenes Schema ist leer${NC}"
        rm -f schema.graphqls.tmp
        exit 1
    fi
else
    echo -e "${RED}❌ Schema Download fehlgeschlagen${NC}"
    rm -f schema.graphqls.tmp
    exit 1
fi

# Code-Generation (Optional - nur wenn Apollo CLI verfügbar)
if command -v apollo &> /dev/null; then
    echo "🔧 Starte Apollo Code-Generation..."
    apollo codegen:generate --config apollo-codegen-config.json --target swift
    echo -e "${GREEN}✅ Code-Generation abgeschlossen${NC}"
else
    echo -e "${YELLOW}⚠️  Apollo CLI nicht gefunden - Code-Generation übersprungen${NC}"
    echo "Installiere mit: npm install -g apollo"
fi

echo ""
echo -e "${GREEN}🎉 Schema Update erfolgreich abgeschlossen!${NC}"
echo ""
echo "📋 Nächste Schritte:"
echo "  1. Überprüfe das neue Schema: schema.graphqls"
echo "  2. Teste die App mit dem neuen Schema"
echo "  3. Bei Problemen: Restore mit mv schema.graphqls.backup schema.graphqls"
echo ""
echo "🔄 Schema automatisch aktuell halten:"
echo "  • Führe dieses Skript vor jedem Build aus"
echo "  • Füge zu Xcode Build Phase hinzu"
echo "  • Verwende in CI/CD Pipeline" 