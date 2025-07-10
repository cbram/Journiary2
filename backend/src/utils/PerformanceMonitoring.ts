import { PerformanceMetric, BatchMetrics } from "../resolvers/types/BatchSyncTypes";

// Performance-Messung für Backend-Operationen
export class PerformanceMeasurement {
    private startTime: Date;
    private operation: string;
    private entityCount: number = 0;
    private batchSize?: number;
    private concurrency?: number;
    
    constructor(operation: string, batchSize?: number, concurrency?: number) {
        this.operation = operation;
        this.startTime = new Date();
        this.batchSize = batchSize;
        this.concurrency = concurrency;
        
        console.log(`🚀 Performance-Messung gestartet: ${operation}`);
    }
    
    /**
     * Beendet die Performance-Messung und protokolliert die Ergebnisse
     */
    finish(entityCount: number, error?: Error): void {
        this.entityCount = entityCount;
        const duration = this.getDuration();
        const memoryUsage = this.getMemoryUsage();
        
        const metric: PerformanceMetric = {
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
    get duration(): number {
        return this.getDuration();
    }
    
    private getDuration(): number {
        return Date.now() - this.startTime.getTime();
    }
    
    private getMemoryUsage(): number {
        try {
            // Speicher-Nutzung erfassen
            const used = process.memoryUsage();
            return used.heapUsed;
        } catch (error) {
            return 0;
        }
    }
}

// Metriken-Sammler für Performance-Daten
export class MetricsCollector {
    private static metrics: PerformanceMetric[] = [];
    private static readonly MAX_METRICS = 1000; // Maximale Anzahl gespeicherter Metriken
    
    /**
     * Zeichnet eine Performance-Metrik auf
     */
    static record(metric: PerformanceMetric): void {
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
    static getBatchMetrics(
        operation?: string,
        lastMinutes: number = 60
    ): BatchMetrics {
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
            .filter((size): size is number => size !== undefined);
        
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
    static getRecentMetrics(count: number = 50): PerformanceMetric[] {
        return this.metrics.slice(-count);
    }
    
    /**
     * Setzt die Metriken zurück (hauptsächlich für Tests)
     */
    static reset(): void {
        this.metrics = [];
    }
    
    /**
     * Exportiert alle Metriken als JSON
     */
    static exportMetrics(): string {
        return JSON.stringify(this.metrics, null, 2);
    }
    
    private static logMetric(metric: PerformanceMetric): void {
        const success = metric.success ? "✅" : "❌";
        const throughput = metric.entityCount > 0 
            ? (metric.entityCount / (metric.duration / 1000)).toFixed(1)
            : "0";
            
        console.log(
            `📊 [${metric.timestamp.toISOString()}] ${success} ${metric.operation}: ` +
            `${metric.entityCount} entities, ${metric.duration}ms, ${throughput} ops/s`
        );
    }
}

// Performance-Alert-System
export class PerformanceAlerts {
    private static readonly SLOW_OPERATION_THRESHOLD = 5000; // 5 Sekunden
    private static readonly HIGH_MEMORY_THRESHOLD = 500 * 1024 * 1024; // 500MB
    private static readonly LOW_THROUGHPUT_THRESHOLD = 1; // 1 Operation pro Sekunde
    
    /**
     * Prüft Metriken auf Performance-Probleme
     */
    static checkPerformanceIssues(metric: PerformanceMetric): string[] {
        const alerts: string[] = [];
        
        // Langsame Operationen
        if (metric.duration > this.SLOW_OPERATION_THRESHOLD) {
            alerts.push(
                `⚠️ Langsame Operation: ${metric.operation} dauerte ${metric.duration}ms`
            );
        }
        
        // Hoher Speicherverbrauch
        if (metric.memoryUsage && metric.memoryUsage > this.HIGH_MEMORY_THRESHOLD) {
            const memoryMB = (metric.memoryUsage / 1024 / 1024).toFixed(1);
            alerts.push(
                `⚠️ Hoher Speicherverbrauch: ${metric.operation} verwendete ${memoryMB}MB`
            );
        }
        
        // Niedrige Durchsatzrate
        if (metric.entityCount > 0) {
            const throughput = metric.entityCount / (metric.duration / 1000);
            if (throughput < this.LOW_THROUGHPUT_THRESHOLD) {
                alerts.push(
                    `⚠️ Niedrige Durchsatzrate: ${metric.operation} nur ${throughput.toFixed(2)} ops/s`
                );
            }
        }
        
        return alerts;
    }
}

// Singleton für einfache Verwendung
export const performanceMonitor = {
    startMeasurement: (operation: string, batchSize?: number, concurrency?: number) => 
        new PerformanceMeasurement(operation, batchSize, concurrency),
    
    getMetrics: (operation?: string, lastMinutes?: number) => 
        MetricsCollector.getBatchMetrics(operation, lastMinutes),
    
    getRecentMetrics: (count?: number) => 
        MetricsCollector.getRecentMetrics(count),
    
    exportMetrics: () => 
        MetricsCollector.exportMetrics(),
    
    reset: () => 
        MetricsCollector.reset()
}; 