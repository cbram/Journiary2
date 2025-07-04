# Projektplan: Synchronisations-Feature

Dieses Dokument beschreibt den schrittweisen Plan zur Implementierung des Synchronisations-Features für die "Journiary" App.

## Phase 1: Backend API-Erweiterungen

Ziel dieser Phase ist es, das Backend so zu ertüchtigen, dass es eine inkrementelle Synchronisation unterstützt.

*   **1.1: `sync`-Query erstellen:** Eine neue GraphQL-Query `sync(lastSyncedAt: Timestamp!)` wird dem Schema hinzugefügt. Sie wird ein Objekt zurückgeben, das Listen von neuen/geänderten Entitäten und eine Liste von gelöschten Entitäts-IDs enthält.
*   **1.2: `sync`-Resolver implementieren:** Der Resolver für die `sync`-Query muss die Datenbank effizient nach allen Entitäten durchsuchen, die seit `lastSyncedAt` für den authentifizierten Benutzer geändert, erstellt oder gelöscht wurden.
*   **1.3: Zeitstempel garantieren:** Überprüfung aller bestehenden `create` und `update` Mutationen. Es muss sichergestellt sein, dass die `createdAt` und `updatedAt` Felder bei jeder Operation korrekt gesetzt werden.
*   **1.4: Lösch-Mutationen hinzufügen:** Für jede synchronisierte Entität muss eine `delete`-Mutation (z.B. `deleteMemory(id: ID!)`) erstellt werden, die ein Objekt aus der Datenbank entfernt.
*   **1.5: Berechtigungen prüfen:** Alle neuen und bestehenden Resolver müssen sicherstellen, dass ein Benutzer nur seine eigenen Daten lesen oder ändern kann.

## Phase 2: Fundament im iOS-Projekt

Diese Phase legt die grundlegenden Bausteine für die Kommunikation mit dem Backend in der iOS-App.

*   **2.1: GraphQL-Client integrieren:** Integration einer robusten GraphQL-Client-Bibliothek wie [Apollo iOS](https://github.com/apollographql/apollo-ios). Dies beinhaltet die Konfiguration des Clients und das Einrichten der Codegenerierung für die GraphQL-Operationen.
*   **2.2: UI für Authentifizierung:** Erstellung von Views für die Registrierung und Anmeldung von Benutzern.
*   **2.3: Token-Management:** Implementierung eines `AuthService`, der Authentifizierungs-Tokens sicher im `Keychain` des Geräts speichert und verwaltet. Der GraphQL-Client wird so konfiguriert, dass er bei jeder Anfrage den Token im `Authorization`-Header mitsendet.

## Phase 3: iOS Core Data-Migration

Die lokale Datenhaltung muss für die Synchronisation vorbereitet werden.

*   **3.1: Neues Core Data Modell erstellen:** Erstellung einer neuen Version des `.xcdatamodeld`.
*   **3.2: Synchronisations-Felder hinzufügen:** Hinzufügen der folgenden Attribute zu allen zu synchronisierenden Entitäten (`Trip`, `Memory`, `MediaItem`, etc.):
    - `createdAt: Date`
    - `updatedAt: Date`
    - `syncStatus: String` (z.B. "local_only", "in_sync", "needs_upload")
*   **3.3: Core Data Migration implementieren:** Erstellung einer `NSMigrationPolicy` für eine leichtgewichtige Migration, um die Daten der Benutzer auf die neue Schema-Version zu heben.

## Phase 4: iOS Synchronisationslogik

Dies ist das Herzstück der Implementierung auf dem Client.

*   **4.1: `SyncManager` implementieren:** Erstellung der Singleton-Klasse `SyncManager`.
*   **4.2: Upload-Phase implementieren:** Logik zum Finden von Objekten mit `syncStatus == "needs_upload"` und Senden der entsprechenden `create`/`update`-Mutationen. Implementierung der Logik für die Behandlung von Löschungen.
*   **4.3: Download-Phase implementieren:** Aufruf der `sync`-Query mit dem `lastSyncedAt`-Zeitstempel und Verarbeitung der Antwort. Dies beinhaltet das Erstellen, Aktualisieren oder Löschen von lokalen Core Data Objekten basierend auf der Server-Antwort.
*   **4.4: Konfliktlösung umsetzen:** Implementierung der "Last-Write-Wins"-Strategie durch Vergleich der `updatedAt`-Zeitstempel bei der Verarbeitung der Download-Antwort.
*   **4.5: Dateisynchronisation:** Implementierung des zweistufigen Prozesses für `MediaItem` und `GPXTrack` über Presigned URLs.
*   **4.6: Fehlerbehandlung:** Implementierung einer robusten Fehlerbehandlung, um sicherzustellen, dass Sync-Zyklen bei Netzwerkfehlern atomar bleiben.
*   **4.7: `lastSyncedAt` verwalten:** Speichern und Aktualisieren des Zeitstempels der letzten erfolgreichen Synchronisation (z.B. in `UserDefaults`).

## Phase 5: UI-Integration & Benutzererfahrung

Die Synchronisationslogik muss für den Benutzer zugänglich und verständlich gemacht werden.

*   **5.1: Manuelle Aktualisierung:** Integration eines `UIRefreshControl` (Pull-to-Refresh) in den Hauptansichten, um den `SyncManager` zu triggern.
*   **5.2: Automatische Trigger:** Automatisches Starten eines Sync-Zyklus beim App-Start und potenziell bei anderen wichtigen Lebenszyklus-Events der App.
*   **5.3: Visuelles Feedback:** Anzeige von Indikatoren (z.B. `UIActivityIndicatorView`), um dem Benutzer zu signalisieren, dass eine Synchronisation stattfindet.
*   **5.4: UI-Aktualisierung:** Sicherstellen, dass die Benutzeroberfläche nach einem erfolgreichen Sync-Zyklus die neuen Daten korrekt darstellt, z.B. durch Neuladen von Listen oder Aktualisieren von Detailansichten. 