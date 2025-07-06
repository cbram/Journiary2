#!/bin/bash

# Apollo iOS Code Generation Script
# Dieses Script wird in Xcode als Build Phase ausgeführt

set -e

# Setze den Pfad zur Apollo CLI
APOLLO_CLI_PATH="${SRCROOT}/apollo-ios-cli"

# Prüfe, ob Apollo CLI existiert
if [ ! -f "$APOLLO_CLI_PATH" ]; then
    echo "Apollo CLI nicht gefunden. Lade es herunter..."
    
    # Erstelle einen temporären Ordner
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Lade Apollo CLI herunter
    curl -L https://github.com/apollographql/apollo-ios-cli/releases/download/1.17.0/apollo-ios-cli.zip -o apollo-ios-cli.zip
    
    # Extrahiere und kopiere
    unzip apollo-ios-cli.zip
    cp apollo-ios-cli "$APOLLO_CLI_PATH"
    chmod +x "$APOLLO_CLI_PATH"
    
    # Räume auf
    cd "$SRCROOT"
    rm -rf "$TEMP_DIR"
fi

# Wechsle in das Projektverzeichnis
cd "$SRCROOT"

# Führe Apollo Code Generation aus
echo "Generiere Apollo Code..."
# Der Pfad zur Konfigurationsdatei wird explizit mit ${SRCROOT} angegeben, um Eindeutigkeit zu gewährleisten.
"$APOLLO_CLI_PATH" generate --config "${SRCROOT}/apollo-codegen-config.json"

echo "Apollo Code Generation abgeschlossen!" 