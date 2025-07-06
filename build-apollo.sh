#!/bin/bash

# Apollo iOS Code Generation Script
# Dieses Script wird in Xcode als Build Phase ausgeführt

set -e

# Setze die SRCROOT-Variable, falls sie nicht gesetzt ist (für manuelle Ausführung)
: "${SRCROOT:=.}"

# Definiere die Version und den Pfad für die Apollo CLI
APOLLO_CLI_VERSION="1.23.0"
APOLLO_CLI_PATH="${SRCROOT}/apollo-ios-cli"
ZIP_PATH="${SRCROOT}/apollo-ios-cli.zip"

# Prüfe, ob die korrekte Version der Apollo CLI existiert
should_download=false
if [ ! -f "$APOLLO_CLI_PATH" ]; then
    echo "Apollo CLI nicht gefunden."
    should_download=true
else
    # Extrahiere die Version aus der CLI und vergleiche sie
    current_version=$("$APOLLO_CLI_PATH" --version 2>/dev/null || echo "0.0.0")
    if [ "$current_version" != "$APOLLO_CLI_VERSION" ]; then
        echo "Falsche Apollo CLI Version gefunden ($current_version), erfordere $APOLLO_CLI_VERSION."
        should_download=true
    fi
fi

if [ "$should_download" = true ]; then
    echo "Lade Apollo CLI v$APOLLO_CLI_VERSION herunter..."
    
    # Endgültig korrigierte Download-URL
    wget -O "$ZIP_PATH" "https://github.com/apollographql/apollo-ios/releases/download/${APOLLO_CLI_VERSION}/apollo-ios-cli.zip"
    
    # Überprüfe, ob der Download erfolgreich war
    if [ ! -s "$ZIP_PATH" ]; then
        echo "Download der Apollo CLI fehlgeschlagen. Die heruntergeladene Datei ist leer."
        exit 1
    fi

    # Entpacke und überschreibe die alte CLI
    unzip -o "$ZIP_PATH" -d "${SRCROOT}"
    
    # Stelle sicher, dass die Datei ausführbar ist
    chmod +x "$APOLLO_CLI_PATH"
    
    # Räume die ZIP-Datei auf
    rm "$ZIP_PATH"
    echo "Apollo CLI wurde erfolgreich auf Version $APOLLO_CLI_VERSION aktualisiert."
fi

# Wechsle in das Projektverzeichnis, falls SRCROOT nicht das aktuelle Verzeichnis ist
if [ "$SRCROOT" != "." ]; then
    cd "$SRCROOT"
fi

# Führe Apollo Code Generation aus
echo "Generiere Apollo Code..."
"$APOLLO_CLI_PATH" generate --path "${SRCROOT}/Journiary/apollo-codegen-config.json"

echo "Apollo Code Generation abgeschlossen!" 