# 🚀 Multi-User Performance Testing Guide

## Übersicht

Diese Dokumentation beschreibt die automatisierte Performance-Test-Suite für das Multi-User Core Data System von Journiary. Die Tests sind darauf ausgelegt, die Performance mit großen Datenmengen zu messen und sicherzustellen, dass User-spezifische Queries schnell bleiben.

## 🎯 Test-Ziele

### Performance-Ziele für Step 4 (Multi-User Core Data Implementation)

1. **Skalierbarkeit**: 1000+ Trips mit verschiedenen Usern
2. **Query-Performance**: User-spezifische Queries unter 100ms
3. **Memory-Effizienz**: Konstante Memory-Usage bei großen Datenmengen
4. **Concurrent Access**: Gleichzeitige Zugriffe mehrerer User ohne Performance-Verlust

## 📊 Test-Konfigurationen

### Quick Test (Empfohlen für Development)
- **👥 Users**: 10
- **🗺️ Trips pro User**: 10
- **💭 Memories pro Trip**: 5
- **🏷️ System Tags**: 50
- **⏱️ Geschätzte Dauer**: ~30 Sekunden
- **📊 Total**: 100 Trips, 500 Memories

### Full Test (Für CI/CD und Release-Validierung)
- **👥 Users**: 50
- **🗺️ Trips pro User**: 25
- **💭 Memories pro Trip**: 8
- **🏷️ System Tags**: 200
- **⏱️ Geschätzte Dauer**: ~5-10 Minuten
- **📊 Total**: 1,250+ Trips, 10,000+ Memories

### Custom Test (Flexible Konfiguration)
- **Interaktive Konfiguration** aller Parameter
- **Anpassbar** an spezifische Test-Szenarien

## 🚀 Tests Ausführen

### Schnell-Start

```bash
# Quick Test (empfohlen für Development)
./run_performance_tests.sh --quick

# Full Test (für CI/CD)
./run_performance_tests.sh --full

# Interactive Custom Configuration
./run_performance_tests.sh --custom

# Help anzeigen
./run_performance_tests.sh --help
```

### Ohne Parameter (Interaktiv)

```bash
./run_performance_tests.sh
```

Das Script führt Sie durch eine interaktive Auswahl der Test-Konfiguration.

## 📋 Test-Phasen

### Phase 1: Test-Daten Generierung
- **User-Erstellung**: Verschiedene Test-User mit realistischen Daten
- **Trip-Generierung**: Trips mit verschiedenen Eigenschaften und Zeiträumen
- **Memory-Erstellung**: Memories mit Tags, Locations und realistischem Content
- **Tag-System**: System-Tags mit verschiedenen Kategorien

### Phase 2: Query-Performance Tests
- **User Trips Query**: Optimierte Abfrage aller Trips eines Users
- **User Memories Query**: Optimierte Abfrage aller Memories eines Users
- **User Tags Query**: Tag-Abfragen mit Usage-basiertem Sorting
- **Complex Multi-Relationship Query**: Komplexe Queries mit mehreren Joins

### Phase 3: Memory Usage Tests
- **Large Result Set Handling**: Testen von großen Ergebnismengen
- **Batch Processing**: Memory-effiziente Batch-Verarbeitung
- **Memory Cleanup**: Effektivität der Memory-Bereinigung

### Phase 4: Concurrent Access Tests
- **Multi-User Simulation**: Simultane Queries von verschiedenen Usern
- **Background Context**: Testen mit Background Core Data Contexts
- **Thread Safety**: Sicherstellung thread-sicherer Operationen

### Phase 5: Bulk Operations Tests
- **Bulk Insert**: Performance von großen Insert-Operationen
- **Bulk Update**: Effizienz von Massen-Updates
- **Bulk Delete**: Performance von Löschoperationen

## 📊 Performance-Metriken

### Query-Performance Thresholds
- **Standard Queries**: < 100ms
- **Complex Queries**: < 200ms
- **Bulk Operations**: < 5s für 1000 Objekte

### Memory-Usage Limits
- **Memory Increase**: < 100MB während Tests
- **Cleanup Effectiveness**: > 80% Memory-Freigabe nach Cleanup

### Concurrent Access
- **Multiple Users**: Gleichzeitige Queries ohne Timeout
- **Thread Safety**: Keine Race Conditions oder Deadlocks

## 📈 Ergebnisse Interpretieren

### Erfolgreiche Tests
```
✅ All performance thresholds met!
📊 QUERY PERFORMANCE:
   UserTripsOptimized:
     📊 Queries: 10
     ⏱️  Avg: 45.23ms
     ⏱️  Min: 32.11ms
     ⏱️  Max: 67.89ms
```

### Performance-Probleme
```
⚠️ Some performance thresholds were exceeded!
❌ User memories query exceeded 100ms threshold: 156.78ms
```

### Memory-Probleme
```
❌ Memory usage increased too much: 128.5 MB
🧹 Cleanup Effectiveness: 45.2%
```

## 🔧 Troubleshooting

### Häufige Probleme

#### 1. Query-Performance zu langsam
- **Ursache**: Nicht-optimierte Fetch Requests
- **Lösung**: 
  - Verwendung der optimierten Fetch Requests aus `CoreDataExtensions+Performance.swift`
  - Batch-Size und Prefetching überprüfen
  - Core Data Indexes prüfen

#### 2. Memory Usage zu hoch
- **Ursache**: Objects werden nicht ordnungsgemäß als Faults zurückgesetzt
- **Lösung**:
  - `context.refresh(object, mergeChanges: false)` verwenden
  - Batch-Processing implementieren
  - Autoreleasepool verwenden

#### 3. Concurrent Access Probleme
- **Ursache**: Nicht thread-sichere Core Data Operationen
- **Lösung**:
  - Background Contexts verwenden
  - `performAndWait` für synchrone Operationen
  - Object IDs für Context-übergreifende Operationen

### Debug-Strategien

#### Detaillierte Logging aktivieren
1. Core Data Debug-Flags setzen:
   ```swift
   // In AppDelegate oder PersistenceController
   container.viewContext.undoManager = nil
   container.viewContext.shouldDeleteInaccessibleFaults = true
   ```

2. SQL-Queries loggen:
   ```
   -com.apple.CoreData.SQLDebug 1
   ```

#### Performance-Profile erstellen
1. Xcode Instruments verwenden
2. Core Data Instrument aktivieren
3. Time Profiler für CPU-Usage
4. Allocations für Memory-Usage

## 🎯 Integration in CI/CD

### GitHub Actions Example
```yaml
name: Performance Tests
on: [push, pull_request]

jobs:
  performance:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v2
    - name: Setup Xcode
      uses: actions/setup-xcode@v1
      with:
        xcode-version: '15.0'
    - name: Run Performance Tests
      run: ./run_performance_tests.sh --full
    - name: Archive Results
      uses: actions/upload-artifact@v2
      with:
        name: performance-results
        path: performance_test_results/
```

### Performance Regression Detection
```bash
# Script für Performance-Regression Detection
./run_performance_tests.sh --full > current_results.log
./scripts/compare_performance.sh baseline_results.log current_results.log
```

## 📚 Best Practices

### 1. Test-Daten Design
- **Realistische Daten**: Test-Daten sollten reale Anwendungsfälle widerspiegeln
- **Verschiedene Szenarien**: Verschiedene User-Typen und Datenmengen testen
- **Edge Cases**: Leere Resultsets, sehr große Datasets

### 2. Performance-Optimierung
- **Batch Fetching**: `fetchBatchSize` verwenden für große Datasets
- **Prefetching**: `relationshipKeyPathsForPrefetching` für Relationships
- **Faulting**: Objects als Faults lassen wenn möglich

### 3. Memory Management
- **Regelmäßige Cleanup**: Objects als Faults zurücksetzen
- **Batch Processing**: Große Operationen in kleinere Batches aufteilen
- **Autoreleasepool**: Für intensive Operationen verwenden

### 4. Test Maintenance
- **Regelmäßige Ausführung**: Performance-Tests als Teil der CI/CD Pipeline
- **Threshold Anpassung**: Performance-Thresholds bei Hardware-Upgrades anpassen
- **Baseline Updates**: Baseline-Performance nach Optimierungen aktualisieren

## 🔍 Erweiterte Features

### Custom Performance Assertions
```swift
// Custom Assertion für spezifische Performance-Tests
func XCTAssertPerformance<T>(
    _ operation: () throws -> T,
    threshold: TimeInterval,
    file: StaticString = #file,
    line: UInt = #line
) throws {
    let startTime = CFAbsoluteTimeGetCurrent()
    _ = try operation()
    let duration = CFAbsoluteTimeGetCurrent() - startTime
    
    XCTAssertLessThan(
        duration, threshold,
        "Operation exceeded threshold: \(duration)s > \(threshold)s",
        file: file, line: line
    )
}
```

### Performance Monitoring Integration
```swift
// Integration mit Performance Monitoring Services
func reportPerformanceMetrics(_ metrics: PerformanceMetrics) {
    // Firebase Performance Monitoring
    // Sentry Performance
    // Custom Analytics
}
```

## 📞 Support

Bei Fragen oder Problemen mit den Performance-Tests:

1. **Log-Dateien prüfen**: Performance-Test-Logs in `performance_test_results/`
2. **Known Issues**: Dokumentierte Probleme in diesem Guide
3. **Debug-Strategien**: Oben beschriebene Debugging-Methoden anwenden

## 🚀 Nächste Schritte

Nach erfolgreichem Performance-Testing:

1. **Baseline etablieren**: Erste Performance-Werte als Baseline dokumentieren
2. **CI/CD Integration**: Performance-Tests in Continuous Integration einbauen
3. **Monitoring Setup**: Production Performance Monitoring einrichten
4. **Regular Reviews**: Monatliche Performance-Reviews durchführen 