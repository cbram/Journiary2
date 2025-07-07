#!/bin/bash

# Apollo iOS Code Generation Script (Moderne Version)
# Dieses Script verwendet den modernen SPM-basierten Ansatz für Apollo iOS 1.x

set -e

# Setze die SRCROOT-Variable, falls sie nicht gesetzt ist (für manuelle Ausführung)
: "${SRCROOT:=.}"

# Definiere den Pfad für die Apollo CLI (erstellt durch SPM Plugin)
APOLLO_CLI_PATH="${SRCROOT}/apollo-ios-cli"

# Prüfe, ob die Apollo CLI existiert, falls nicht, installiere sie über SPM Plugin
if [ ! -f "$APOLLO_CLI_PATH" ]; then
    echo "Apollo CLI nicht gefunden. Installiere über SPM Plugin..."
    
    # Wechsle in das Verzeichnis mit Package.swift
    cd "${SRCROOT}"
    
    # Installiere die Apollo CLI über den SPM Plugin
    echo "Führe SPM Apollo CLI Installation aus..."
    swift package --allow-writing-to-package-directory apollo-cli-install
    
    # Überprüfe, ob die Installation erfolgreich war
    if [ ! -f "$APOLLO_CLI_PATH" ]; then
        echo "❌ Apollo CLI Installation fehlgeschlagen."
        echo "💡 Tipp: Stelle sicher, dass Apollo iOS als SPM Dependency installiert ist."
        exit 1
    fi
    
    echo "✅ Apollo CLI wurde erfolgreich installiert."
else
    echo "✅ Apollo CLI bereits vorhanden."
fi

# Speichere den absoluten Pfad zur CLI vor dem Verzeichniswechsel
APOLLO_CLI_ABSOLUTE_PATH="$(pwd)/apollo-ios-cli"

# Wechsle in das Journiary Verzeichnis für Code Generation
cd "${SRCROOT}/Journiary"

# Führe Apollo Code Generation aus (mit absolutem Pfad zur CLI)
echo "🚀 Generiere Apollo Code..."
"$APOLLO_CLI_ABSOLUTE_PATH" generate --path ./apollo-codegen-config.json

echo "✅ Apollo Code Generation abgeschlossen!" 