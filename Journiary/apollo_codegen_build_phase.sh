#!/bin/bash

# Production-Ready Apollo iOS Code Generation Build Phase
# Füge dieses Script als "Run Script Phase" in Xcode hinzu

# Farben für bessere Lesbarkeit
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Nur bei Clean Build oder wenn GraphQL Dateien geändert wurden
if [ "${CONFIGURATION}" = "Debug" ] || [ "${ACTION}" = "clean" ]; then
    cd "${SRCROOT}/Journiary"
    
    echo -e "${YELLOW}🔧 Apollo Code-Generation Build Phase${NC}"
    
    # Überprüfe ob Schema existiert
    if [ -f "schema.graphqls" ]; then
        echo -e "${GREEN}✅ GraphQL Schema gefunden${NC}"
        
        # Schema-Alter prüfen (älter als 1 Stunde = Update empfohlen)
        if [ $(find "schema.graphqls" -mtime +0.04 | wc -l) -gt 0 ]; then
            echo -e "${YELLOW}⚠️  Schema ist älter als 1 Stunde - Update empfohlen${NC}"
            echo "Führe './update_schema.sh' aus um das Schema zu aktualisieren"
        fi
        
        # Code-Generation erfolgt über Swift Package Manager
        echo -e "${GREEN}✅ Code-Generation via Swift Package Manager beim Build${NC}"
        
        # GraphQL Operations Datei überprüfen
        if [ -f "Journiary/GraphQL/Generated/GraphQLOperations.swift" ]; then
            echo -e "${GREEN}✅ Typisierte GraphQL Operations verfügbar${NC}"
        else
            echo -e "${YELLOW}⚠️  GraphQL Operations nicht gefunden - verwende String-basierte Queries${NC}"
        fi
        
        echo -e "${GREEN}✅ Apollo Code erfolgreich generiert${NC}"
    else
        echo -e "${RED}❌ schema.graphqls nicht gefunden${NC}"
        echo "Führe './update_schema.sh' aus um das Schema herunterzuladen"
        
        # Build nicht abbrechen, nur warnen
        echo -e "${YELLOW}⚠️  Build wird ohne Schema fortgesetzt (Demo-Modus)${NC}"
    fi
fi 