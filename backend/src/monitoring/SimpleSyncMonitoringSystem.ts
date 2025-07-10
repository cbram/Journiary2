import { EventEmitter } from 'events';
import {
    SyncMetricData,
    PerformanceAnalysis,
    HealthCheckResult,
    AlertType,
    AlertSeverity,
    HealthStatus,
    SyncTrendAnalysis
} from '../types/MonitoringTypes';

/**
 * Vereinfachte Monitoring-Infrastruktur für Synchronisations-Operationen
 * Implementiert Phase 7.2: Backend-Monitoring (Funktionale Version)
 */
export class SimpleSyncMonitoringSystem extends EventEmitter {
    private readonly metricsBuffer: SyncMetricData[] = [];
    private readonly alertsBuffer: AlertData[] = [];
    private readonly healthChecksBuffer: HealthCheckData[] = [];
    private readonly maxBufferSize = 10000;
    
    constructor() {
        super();
        this.startPeriodicAnalysis();
    }
    
    /**
     * Sync-Metriken aufzeichnen
     */
    async recordSyncMetric(metricData: SyncMetricData): Promise<void> {
        const metric: SyncMetricData = {
            ...metricData,
            timestamp: new Date()
        };
        
        this.metricsBuffer.push(metric);
        
        // Buffer-Größe begrenzen
        if (this.metricsBuffer.length > this.maxBufferSize) {
            this.metricsBuffer.shift();
        }
        
        // Echtzeitanalyse für kritische Metriken
        await this.analyzeMetricRealtime(metric);
        
        console.log(`📊 Sync-Metrik aufgezeichnet: ${metric.operation} (${metric.entityType}) - ${metric.success ? 'SUCCESS' : 'FAILED'} - ${metric.duration}ms`);
    }
    
    /**
     * Performance-Analyse
     */
    async getPerformanceAnalysis(timeWindow: 'hour' | 'day' | 'week' = 'hour'): Promise<PerformanceAnalysis> {
        const windowStart = this.getTimeWindowStart(timeWindow);
        const metrics = this.metricsBuffer.filter(m => 
            m.timestamp && new Date(m.timestamp) >= windowStart
        );
        
        const analysis: PerformanceAnalysis = {
            totalOperations: metrics.length,
            successRate: this.calculateSuccessRate(metrics),
            averageDuration: this.calculateAverageDuration(metrics),
            medianDuration: this.calculateMedianDuration(metrics),
            throughput: this.calculateThroughput(metrics, timeWindow),
            errorRate: this.calculateErrorRate(metrics),
            performanceByEntityType: this.analyzeByEntityType(metrics),
            devicePerformance: this.analyzeByDevice(metrics),
            timeSeriesData: this.generateTimeSeriesData(metrics),
            bottlenecks: this.identifyBottlenecks(metrics),
            recommendations: this.generatePerformanceRecommendations(metrics)
        };
        
        console.log(`📈 Performance-Analyse erstellt: ${analysis.totalOperations} Operationen, ${(analysis.successRate * 100).toFixed(1)}% Erfolgsrate`);
        return analysis;
    }
    
    /**
     * Sync-Health-Check
     */
    async performHealthCheck(): Promise<HealthCheckResult> {
        const healthCheck: HealthCheckData = {
            timestamp: new Date(),
            status: 'healthy',
            score: 0,
            details: {}
        };
        
        try {
            // Prüfe verschiedene Gesundheitsindikatoren
            const recentMetrics = this.getRecentMetrics(5); // Letzte 5 Minuten
            const errorRate = this.calculateErrorRate(recentMetrics);
            const avgDuration = this.calculateAverageDuration(recentMetrics);
            
            let score = 1.0;
            
            // Bewerte Error Rate
            if (errorRate > 0.1) {
                score -= 0.4;
                healthCheck.status = 'critical';
            } else if (errorRate > 0.05) {
                score -= 0.2;
                healthCheck.status = 'warning';
            }
            
            // Bewerte Performance
            if (avgDuration > 30000) {
                score -= 0.3;
                if (healthCheck.status === 'healthy') healthCheck.status = 'warning';
            } else if (avgDuration > 60000) {
                score -= 0.5;
                healthCheck.status = 'critical';
            }
            
            // Bewerte Aktivität
            if (recentMetrics.length === 0) {
                score -= 0.1;
            }
            
            healthCheck.score = Math.max(0, score);
            healthCheck.details = {
                recentOperations: recentMetrics.length,
                errorRate: errorRate,
                averageDuration: avgDuration,
                systemUptime: process.uptime(),
                memoryUsage: process.memoryUsage()
            };
            
            this.healthChecksBuffer.push(healthCheck);
            
            // Buffer-Größe begrenzen
            if (this.healthChecksBuffer.length > 1000) {
                this.healthChecksBuffer.shift();
            }
            
            console.log(`🏥 Health-Check durchgeführt: ${healthCheck.status} (Score: ${healthCheck.score.toFixed(2)})`);
            
            return {
                status: healthCheck.status,
                score: healthCheck.score,
                timestamp: healthCheck.timestamp,
                details: healthCheck.details
            };
            
        } catch (error) {
            const errorMessage = error instanceof Error ? error.message : 'Unknown error';
            healthCheck.status = 'critical';
            healthCheck.score = 0;
            healthCheck.details = { error: errorMessage };
            
            this.healthChecksBuffer.push(healthCheck);
            
            console.error(`🚨 Health-Check fehlgeschlagen: ${errorMessage}`);
            
            return {
                status: 'critical',
                score: 0,
                timestamp: healthCheck.timestamp,
                details: { error: errorMessage }
            };
        }
    }
    
    /**
     * Alert-System
     */
    async triggerAlert(
        type: AlertType,
        severity: AlertSeverity,
        message: string,
        details?: any
    ): Promise<void> {
        const alert: AlertData = {
            type,
            severity,
            message,
            details,
            timestamp: new Date(),
            acknowledged: false
        };
        
        this.alertsBuffer.push(alert);
        
        // Buffer-Größe begrenzen
        if (this.alertsBuffer.length > 1000) {
            this.alertsBuffer.shift();
        }
        
        // Emittiere Event für externe Systeme
        this.emit('alert', alert);
        
        // Konsolen-Output basierend auf Severity
        switch (severity) {
            case 'critical':
                console.error(`🚨 CRITICAL ALERT [${type}]: ${message}`, details);
                break;
            case 'warning':
                console.warn(`⚠️ WARNING [${type}]: ${message}`, details);
                break;
            case 'info':
                console.info(`ℹ️ INFO [${type}]: ${message}`, details);
                break;
        }
    }
    
    /**
     * Sync-Trends analysieren
     */
    async analyzeSyncTrends(days: number = 7): Promise<SyncTrendAnalysis> {
        const endDate = new Date();
        const startDate = new Date();
        startDate.setDate(endDate.getDate() - days);
        
        const metrics = this.metricsBuffer.filter(m => 
            m.timestamp && new Date(m.timestamp) >= startDate
        );
        
        const dailyMetrics = this.groupMetricsByDay(metrics);
        const trends = this.calculateTrends(dailyMetrics);
        
        console.log(`📊 Trend-Analyse erstellt für ${days} Tage`);
        
        return {
            period: `${days} days`,
            trends,
            anomalies: [],
            recommendations: this.generateTrendRecommendations(trends),
            forecast: {
                nextWeekOperations: dailyMetrics.length * 7,
                nextWeekDuration: this.calculateAverageDuration(metrics),
                confidence: 0.8
            },
            seasonality: {
                hasSeasonality: false,
                peakDays: [],
                lowDays: []
            }
        };
    }
    
    /**
     * Statistiken abrufen
     */
    getStats(): MonitoringStats {
        const recentMetrics = this.getRecentMetrics(60); // Letzte Stunde
        const recentAlerts = this.getRecentAlerts(24); // Letzte 24 Stunden
        const latestHealthCheck = this.getLatestHealthCheck();
        
        return {
            totalMetrics: this.metricsBuffer.length,
            recentOperations: recentMetrics.length,
            successRate: this.calculateSuccessRate(recentMetrics),
            averageDuration: this.calculateAverageDuration(recentMetrics),
            totalAlerts: this.alertsBuffer.length,
            recentAlerts: recentAlerts.length,
            systemHealth: latestHealthCheck?.status || 'unknown',
            healthScore: latestHealthCheck?.score || 0,
            uptime: process.uptime(),
            memoryUsage: process.memoryUsage().heapUsed / 1024 / 1024 // MB
        };
    }
    
    // Private Hilfsmethoden
    private async analyzeMetricRealtime(metric: SyncMetricData): Promise<void> {
        // Prüfe auf Performance-Anomalien
        if (metric.duration > 30000) { // > 30 Sekunden
            await this.triggerAlert(
                'performance',
                'warning',
                `Langsame Sync-Operation: ${metric.operation} dauerte ${metric.duration}ms`,
                { metric }
            );
        }
        
        // Prüfe auf Fehler
        if (!metric.success) {
            await this.triggerAlert(
                'error',
                'warning',
                `Sync-Operation fehlgeschlagen: ${metric.operation} - ${metric.errorMessage}`,
                { metric }
            );
        }
        
        // Prüfe auf hohen Memory-Verbrauch
        if (metric.memoryUsage && metric.memoryUsage > 100 * 1024 * 1024) { // > 100MB
            await this.triggerAlert(
                'memory',
                'info',
                `Hoher Memory-Verbrauch: ${Math.round(metric.memoryUsage / 1024 / 1024)}MB für ${metric.operation}`,
                { metric }
            );
        }
    }
    
    private startPeriodicAnalysis(): void {
        // Alle 15 Minuten: Health-Check
        setInterval(async () => {
            await this.performHealthCheck();
        }, 15 * 60 * 1000);
        
        // Alle 30 Minuten: Trend-Analyse
        setInterval(async () => {
            const trends = await this.analyzeSyncTrends(1);
            this.emit('trends', trends);
        }, 30 * 60 * 1000);
        
        // Alle 5 Minuten: Performance-Analyse
        setInterval(async () => {
            const analysis = await this.getPerformanceAnalysis('hour');
            this.emit('performance', analysis);
        }, 5 * 60 * 1000);
    }
    
    private getTimeWindowStart(window: string): Date {
        const now = new Date();
        switch (window) {
            case 'hour':
                return new Date(now.getTime() - 60 * 60 * 1000);
            case 'day':
                return new Date(now.getTime() - 24 * 60 * 60 * 1000);
            case 'week':
                return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
            default:
                return new Date(now.getTime() - 60 * 60 * 1000);
        }
    }
    
    private getRecentMetrics(minutes: number): SyncMetricData[] {
        const cutoff = new Date(Date.now() - minutes * 60 * 1000);
        return this.metricsBuffer.filter(m => 
            m.timestamp && new Date(m.timestamp) >= cutoff
        );
    }
    
    private getRecentAlerts(hours: number): AlertData[] {
        const cutoff = new Date(Date.now() - hours * 60 * 60 * 1000);
        return this.alertsBuffer.filter(a => 
            a.timestamp && new Date(a.timestamp) >= cutoff
        );
    }
    
    private getLatestHealthCheck(): HealthCheckData | undefined {
        return this.healthChecksBuffer[this.healthChecksBuffer.length - 1];
    }
    
    private calculateSuccessRate(metrics: SyncMetricData[]): number {
        const successful = metrics.filter(m => m.success).length;
        return metrics.length > 0 ? successful / metrics.length : 0;
    }
    
    private calculateAverageDuration(metrics: SyncMetricData[]): number {
        const totalDuration = metrics.reduce((sum, m) => sum + m.duration, 0);
        return metrics.length > 0 ? totalDuration / metrics.length : 0;
    }
    
    private calculateMedianDuration(metrics: SyncMetricData[]): number {
        const sortedDurations = metrics.map(m => m.duration).sort((a, b) => a - b);
        const middle = Math.floor(sortedDurations.length / 2);
        
        if (sortedDurations.length % 2 === 0) {
            return (sortedDurations[middle - 1] + sortedDurations[middle]) / 2;
        } else {
            return sortedDurations[middle];
        }
    }
    
    private calculateThroughput(metrics: SyncMetricData[], timeWindow: string): number {
        const totalEntities = metrics.reduce((sum, m) => sum + m.entityCount, 0);
        const windowHours = this.getTimeWindowHours(timeWindow);
        return totalEntities / windowHours;
    }
    
    private calculateErrorRate(metrics: SyncMetricData[]): number {
        const failed = metrics.filter(m => !m.success).length;
        return metrics.length > 0 ? failed / metrics.length : 0;
    }
    
    private analyzeByEntityType(metrics: SyncMetricData[]): Record<string, any> {
        const analysis: Record<string, any> = {};
        
        const entityTypes = [...new Set(metrics.map(m => m.entityType))];
        
        for (const entityType of entityTypes) {
            const typeMetrics = metrics.filter(m => m.entityType === entityType);
            analysis[entityType] = {
                totalOperations: typeMetrics.length,
                successRate: this.calculateSuccessRate(typeMetrics),
                averageDuration: this.calculateAverageDuration(typeMetrics),
                totalEntities: typeMetrics.reduce((sum, m) => sum + m.entityCount, 0)
            };
        }
        
        return analysis;
    }
    
    private analyzeByDevice(metrics: SyncMetricData[]): Record<string, any> {
        const analysis: Record<string, any> = {};
        
        const devices = [...new Set(metrics.map(m => m.deviceId).filter(Boolean))];
        
        for (const deviceId of devices) {
            if (deviceId) {
                const deviceMetrics = metrics.filter(m => m.deviceId === deviceId);
                analysis[deviceId] = {
                    totalOperations: deviceMetrics.length,
                    successRate: this.calculateSuccessRate(deviceMetrics),
                    averageDuration: this.calculateAverageDuration(deviceMetrics),
                    totalDataTransferred: deviceMetrics.reduce((sum, m) => sum + (m.networkBytesTransferred || 0), 0)
                };
            }
        }
        
        return analysis;
    }
    
    private generateTimeSeriesData(metrics: SyncMetricData[]): any[] {
        const hourlyData: Record<string, { count: number, successCount: number, totalDuration: number }> = {};
        
        for (const metric of metrics) {
            if (!metric.timestamp) continue;
            
            const hour = new Date(metric.timestamp).toISOString().slice(0, 13) + ':00:00';
            
            if (!hourlyData[hour]) {
                hourlyData[hour] = { count: 0, successCount: 0, totalDuration: 0 };
            }
            
            hourlyData[hour].count++;
            if (metric.success) hourlyData[hour].successCount++;
            hourlyData[hour].totalDuration += metric.duration;
        }
        
        return Object.entries(hourlyData).map(([timestamp, data]) => ({
            timestamp: new Date(timestamp),
            operationCount: data.count,
            successRate: data.successCount / data.count,
            averageDuration: data.totalDuration / data.count
        }));
    }
    
    private identifyBottlenecks(metrics: SyncMetricData[]): any[] {
        const bottlenecks: any[] = [];
        
        // Analysiere langsame Operationen
        const slowOperations = metrics.filter(m => m.duration > 30000);
        if (slowOperations.length > 0) {
            bottlenecks.push({
                type: 'slow_operations',
                severity: 'medium',
                description: `${slowOperations.length} langsame Operationen erkannt`,
                impact: (slowOperations.length / metrics.length) * 100,
                recommendations: ['Überprüfe Datenbankindizes', 'Optimiere Queries', 'Erhöhe Batch-Größen']
            });
        }
        
        return bottlenecks;
    }
    
    private generatePerformanceRecommendations(metrics: SyncMetricData[]): string[] {
        const recommendations: string[] = [];
        
        const avgDuration = this.calculateAverageDuration(metrics);
        if (avgDuration > 5000) {
            recommendations.push('Erwäge Batch-Verarbeitung für bessere Performance');
        }
        
        const errorRate = this.calculateErrorRate(metrics);
        if (errorRate > 0.02) {
            recommendations.push('Implementiere Retry-Mechanismen für fehlerhafte Operationen');
        }
        
        return recommendations;
    }
    
    private groupMetricsByDay(metrics: SyncMetricData[]): any[] {
        const dailyData: Record<string, any> = {};
        
        for (const metric of metrics) {
            if (!metric.timestamp) continue;
            
            const day = new Date(metric.timestamp).toISOString().slice(0, 10);
            
            if (!dailyData[day]) {
                dailyData[day] = { operations: 0, totalDuration: 0, successCount: 0 };
            }
            
            dailyData[day].operations++;
            dailyData[day].totalDuration += metric.duration;
            if (metric.success) dailyData[day].successCount++;
        }
        
        return Object.entries(dailyData).map(([date, data]) => ({
            date,
            operations: data.operations,
            avgDuration: data.totalDuration / data.operations,
            successRate: data.successCount / data.operations
        }));
    }
    
    private calculateTrends(dailyMetrics: any[]): any {
        return {
            operationsTrend: 'stable',
            durationTrend: 'stable',
            errorRateTrend: 'stable',
            throughputTrend: 'stable'
        };
    }
    
    private generateTrendRecommendations(trends: any): string[] {
        const recommendations: string[] = [];
        
        if (trends.durationTrend === 'degrading') {
            recommendations.push('Performance-Optimierung erforderlich');
        }
        
        if (trends.errorRateTrend === 'increasing') {
            recommendations.push('Fehlerbehandlung überprüfen');
        }
        
        return recommendations;
    }
    
    private getTimeWindowHours(window: string): number {
        switch (window) {
            case 'hour': return 1;
            case 'day': return 24;
            case 'week': return 168;
            default: return 1;
        }
    }
}

// Vereinfachte Datenstrukturen
interface AlertData {
    type: AlertType;
    severity: AlertSeverity;
    message: string;
    details?: any;
    timestamp: Date;
    acknowledged: boolean;
}

interface HealthCheckData {
    timestamp: Date;
    status: HealthStatus;
    score: number;
    details: any;
}

interface MonitoringStats {
    totalMetrics: number;
    recentOperations: number;
    successRate: number;
    averageDuration: number;
    totalAlerts: number;
    recentAlerts: number;
    systemHealth: HealthStatus | 'unknown';
    healthScore: number;
    uptime: number;
    memoryUsage: number;
}

// Erweitere SyncMetricData um timestamp (lokale Erweiterung)
interface ExtendedSyncMetricData extends SyncMetricData {
    timestamp?: Date;
} 