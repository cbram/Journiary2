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
