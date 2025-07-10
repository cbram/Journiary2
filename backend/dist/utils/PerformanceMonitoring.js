"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.performanceMonitor = exports.PerformanceAlerts = exports.MetricsCollector = exports.PerformanceMeasurement = void 0;
// Performance-Messung für Backend-Operationen
class PerformanceMeasurement {
    constructor(operation, batchSize, concurrency) {
        this.entityCount = 0;
        this.operation = operation;
        this.startTime = new Date();
        this.batchSize = batchSize;
        this.concurrency = concurrency;
        console.log(`🚀 Performance-Messung gestartet: ${operation}`);
    }
    /**
     * Beendet die Performance-Messung und protokolliert die Ergebnisse
     */
    finish(entityCount, error) {
        this.entityCount = entityCount;
        const duration = this.getDuration();
        const memoryUsage = this.getMemoryUsage();
        const metric = {
            operation: this.operation,
            duration,
            entityCount,
            success: !error,
            timestamp: new Date(),
            memoryUsage,
            batchSize: this.batchSize,
            concurrency: this.concurrency
        };
        // Metriken an Monitoring-System senden
        MetricsCollector.record(metric);
        // Console-Logging für Development
        const status = error ? "❌ FEHLER" : "✅ ERFOLG";
        const throughput = entityCount > 0 ? (entityCount / (duration / 1000)).toFixed(1) : "0";
        console.log(`${status} ${this.operation}: ${entityCount} Entitäten in ${duration}ms (${throughput} ops/s)`);
        if (error) {
            console.error(`   └─ Fehler: ${error.message}`);
        }
        if (memoryUsage > 0) {
            console.log(`   └─ Memory: ${(memoryUsage / 1024 / 1024).toFixed(1)}MB`);
        }
    }
    /**
     * Gibt die aktuelle Dauer in Millisekunden zurück
     */
    get duration() {
        return this.getDuration();
    }
    getDuration() {
        return Date.now() - this.startTime.getTime();
    }
    getMemoryUsage() {
        try {
            // Speicher-Nutzung erfassen
            const used = process.memoryUsage();
            return used.heapUsed;
        }
        catch (error) {
            return 0;
        }
    }
}
exports.PerformanceMeasurement = PerformanceMeasurement;
// Metriken-Sammler für Performance-Daten
class MetricsCollector {
    /**
     * Zeichnet eine Performance-Metrik auf
     */
    static record(metric) {
        this.metrics.push(metric);
        // Begrenze die Anzahl der Metriken
        if (this.metrics.length > this.MAX_METRICS) {
            this.metrics = this.metrics.slice(-this.MAX_METRICS);
        }
        // Erweiterte Logging-Ausgabe
        this.logMetric(metric);
    }
    /**
     * Gibt Batch-Metriken für einen bestimmten Zeitraum zurück
     */
    static getBatchMetrics(operation, lastMinutes = 60) {
        const cutoffTime = new Date(Date.now() - lastMinutes * 60 * 1000);
        const relevantMetrics = this.metrics.filter(m => {
            const matchesOperation = !operation || m.operation === operation;
            const isRecent = m.timestamp >= cutoffTime;
            return matchesOperation && isRecent;
        });
        if (relevantMetrics.length === 0) {
            return {
                totalDuration: 0,
                averageOperationTime: 0,
                successCount: 0,
                failureCount: 0,
                throughput: 0,
                peakMemoryUsage: 0,
                batchSizes: []
            };
        }
        const totalDuration = relevantMetrics.reduce((sum, m) => sum + m.duration, 0);
        const successCount = relevantMetrics.filter(m => m.success).length;
        const failureCount = relevantMetrics.length - successCount;
        const totalEntities = relevantMetrics.reduce((sum, m) => sum + m.entityCount, 0);
        const throughput = totalEntities / (totalDuration / 1000); // Entitäten pro Sekunde
        const peakMemoryUsage = Math.max(...relevantMetrics.map(m => m.memoryUsage || 0));
        const batchSizes = relevantMetrics
            .map(m => m.batchSize)
            .filter((size) => size !== undefined);
        return {
            totalDuration,
            averageOperationTime: totalDuration / relevantMetrics.length,
            successCount,
            failureCount,
            throughput: isFinite(throughput) ? throughput : 0,
            peakMemoryUsage,
            batchSizes
        };
    }
    /**
     * Gibt die letzten N Metriken zurück
     */
    static getRecentMetrics(count = 50) {
        return this.metrics.slice(-count);
    }
    /**
     * Setzt die Metriken zurück (hauptsächlich für Tests)
     */
    static reset() {
        this.metrics = [];
    }
    /**
     * Exportiert alle Metriken als JSON
     */
    static exportMetrics() {
        return JSON.stringify(this.metrics, null, 2);
    }
    static logMetric(metric) {
        const success = metric.success ? "✅" : "❌";
        const throughput = metric.entityCount > 0
            ? (metric.entityCount / (metric.duration / 1000)).toFixed(1)
            : "0";
        console.log(`📊 [${metric.timestamp.toISOString()}] ${success} ${metric.operation}: ` +
            `${metric.entityCount} entities, ${metric.duration}ms, ${throughput} ops/s`);
    }
}
exports.MetricsCollector = MetricsCollector;
MetricsCollector.metrics = [];
MetricsCollector.MAX_METRICS = 1000; // Maximale Anzahl gespeicherter Metriken
// Performance-Alert-System
class PerformanceAlerts {
    /**
     * Prüft Metriken auf Performance-Probleme
     */
    static checkPerformanceIssues(metric) {
        const alerts = [];
        // Langsame Operationen
        if (metric.duration > this.SLOW_OPERATION_THRESHOLD) {
            alerts.push(`⚠️ Langsame Operation: ${metric.operation} dauerte ${metric.duration}ms`);
        }
        // Hoher Speicherverbrauch
        if (metric.memoryUsage && metric.memoryUsage > this.HIGH_MEMORY_THRESHOLD) {
            const memoryMB = (metric.memoryUsage / 1024 / 1024).toFixed(1);
            alerts.push(`⚠️ Hoher Speicherverbrauch: ${metric.operation} verwendete ${memoryMB}MB`);
        }
        // Niedrige Durchsatzrate
        if (metric.entityCount > 0) {
            const throughput = metric.entityCount / (metric.duration / 1000);
            if (throughput < this.LOW_THROUGHPUT_THRESHOLD) {
                alerts.push(`⚠️ Niedrige Durchsatzrate: ${metric.operation} nur ${throughput.toFixed(2)} ops/s`);
            }
        }
        return alerts;
    }
}
exports.PerformanceAlerts = PerformanceAlerts;
PerformanceAlerts.SLOW_OPERATION_THRESHOLD = 5000; // 5 Sekunden
PerformanceAlerts.HIGH_MEMORY_THRESHOLD = 500 * 1024 * 1024; // 500MB
PerformanceAlerts.LOW_THROUGHPUT_THRESHOLD = 1; // 1 Operation pro Sekunde
// Singleton für einfache Verwendung
exports.performanceMonitor = {
    startMeasurement: (operation, batchSize, concurrency) => new PerformanceMeasurement(operation, batchSize, concurrency),
    getMetrics: (operation, lastMinutes) => MetricsCollector.getBatchMetrics(operation, lastMinutes),
    getRecentMetrics: (count) => MetricsCollector.getRecentMetrics(count),
    exportMetrics: () => MetricsCollector.exportMetrics(),
    reset: () => MetricsCollector.reset()
};
