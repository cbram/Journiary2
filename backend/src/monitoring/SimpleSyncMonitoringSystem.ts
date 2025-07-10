import { EventEmitter } from 'events';
import { SyncMetricData, AlertSeverity, AlertType, HealthStatus } from '../types/MonitoringTypes';

/**
 * Vereinfachtes Sync-Monitoring-System für Phase 7.2
 * Memory-basierte Implementierung ohne externe Dependencies
 */
export class SimpleSyncMonitoringSystem extends EventEmitter {
    private metrics: SyncMetricData[] = [];
    private alerts: SyncAlert[] = [];
    private healthChecks: HealthCheck[] = [];
    private readonly maxMetrics = 10000;
    private readonly maxAlerts = 1000;
    private readonly maxHealthChecks = 100;

    constructor() {
        super();
        this.startPeriodicTasks();
        console.log('📊 SimpleSyncMonitoringSystem initialized');
    }

    // Metrics-Aufzeichnung
    async recordMetric(metric: SyncMetricData): Promise<void> {
        const enhancedMetric: SyncMetricData = {
            ...metric,
            timestamp: new Date()
        };

        this.metrics.push(enhancedMetric);
        
        // Begrenzen der Metrics-Anzahl
        if (this.metrics.length > this.maxMetrics) {
            this.metrics = this.metrics.slice(-this.maxMetrics);
        }

        // Echtzeitanalyse für Anomalien
        await this.analyzeMetricRealtime(enhancedMetric);
        
        console.log(`📈 Metric recorded: ${metric.operation} - ${metric.entityCount} entities in ${metric.duration}ms`);
    }

    // Performance-Analyse
    async getPerformanceAnalysis(timeWindow: 'hour' | 'day' | 'week' = 'hour'): Promise<PerformanceAnalysis> {
        const windowStart = this.getTimeWindowStart(timeWindow);
        const relevantMetrics = this.metrics.filter(m => 
            m.timestamp && new Date(m.timestamp) >= windowStart
        );

        const analysis: PerformanceAnalysis = {
            totalOperations: relevantMetrics.length,
            successRate: this.calculateSuccessRate(relevantMetrics),
            averageDuration: this.calculateAverageDuration(relevantMetrics),
            throughput: this.calculateThroughput(relevantMetrics, timeWindow),
            errorRate: this.calculateErrorRate(relevantMetrics),
            topBottlenecks: this.identifyBottlenecks(relevantMetrics),
            recommendations: this.generateRecommendations(relevantMetrics)
        };

        return analysis;
    }

    // Health-Check
    async performHealthCheck(): Promise<HealthCheckResult> {
        const healthCheck: HealthCheck = {
            id: `health_${Date.now()}`,
            timestamp: new Date(),
            status: 'healthy',
            score: 1.0,
            details: {}
        };

        try {
            // Simuliere verschiedene Health-Checks
            const checks = await Promise.all([
                this.checkMemoryUsage(),
                this.checkResponseTimes(),
                this.checkErrorRates(),
                this.checkThroughput()
            ]);

            const overallScore = checks.reduce((sum, check) => sum + check.score, 0) / checks.length;
            
            healthCheck.score = overallScore;
            healthCheck.status = this.determineHealthStatus(overallScore);
            healthCheck.details = {
                memoryUsage: checks[0],
                responseTimes: checks[1],
                errorRates: checks[2],
                throughput: checks[3]
            };

            // Speichere Health-Check
            this.healthChecks.push(healthCheck);
            if (this.healthChecks.length > this.maxHealthChecks) {
                this.healthChecks = this.healthChecks.slice(-this.maxHealthChecks);
            }

            // Trigger Alert bei schlechter Gesundheit
            if (overallScore < 0.7) {
                await this.triggerAlert(
                    'health',
                    overallScore < 0.5 ? 'critical' : 'warning',
                    `System health degraded: ${(overallScore * 100).toFixed(1)}%`,
                    healthCheck.details
                );
            }

            return {
                status: healthCheck.status,
                score: healthCheck.score,
                timestamp: healthCheck.timestamp,
                details: healthCheck.details
            };

        } catch (error) {
            const errorMessage = error instanceof Error ? error.message : 'Unknown error';
            await this.triggerAlert('health', 'critical', `Health check failed: ${errorMessage}`);
            
            return {
                status: 'critical',
                score: 0,
                timestamp: new Date(),
                details: { error: errorMessage }
            };
        }
    }

    // Alert-System
    async triggerAlert(type: AlertType, severity: AlertSeverity, message: string, details?: any): Promise<void> {
        const alert: SyncAlert = {
            id: `alert_${Date.now()}`,
            type,
            severity,
            message,
            details,
            timestamp: new Date(),
            acknowledged: false
        };

        // Duplikat-Detection
        const isDuplicate = this.alerts.some(existing => 
            existing.type === type && 
            existing.message === message && 
            (Date.now() - existing.timestamp.getTime()) < 5 * 60 * 1000 // 5 Minuten
        );

        if (!isDuplicate) {
            this.alerts.push(alert);
            
            // Begrenzen der Alerts-Anzahl
            if (this.alerts.length > this.maxAlerts) {
                this.alerts = this.alerts.slice(-this.maxAlerts);
            }

            // Emittiere Event
            this.emit('alert', alert);
            
            console.log(`🚨 Alert [${severity.toUpperCase()}]: ${message}`);
        }
    }

    // Trend-Analyse
    async analyzeTrends(days: number = 7): Promise<TrendAnalysis> {
        const endDate = new Date();
        const startDate = new Date(endDate.getTime() - days * 24 * 60 * 60 * 1000);
        
        const relevantMetrics = this.metrics.filter(m => 
            m.timestamp && new Date(m.timestamp) >= startDate
        );

        const trends = {
            performanceTrend: this.calculatePerformanceTrend(relevantMetrics),
            errorRateTrend: this.calculateErrorRateTrend(relevantMetrics),
            throughputTrend: this.calculateThroughputTrend(relevantMetrics),
            recommendation: this.generateTrendRecommendations(relevantMetrics)
        };

        return {
            period: `${days} days`,
            trends,
            forecast: this.generateForecast(relevantMetrics),
            recommendations: [trends.recommendation]
        };
    }

    // Demostriere Funktionalität
    async demonstrateMonitoring(): Promise<void> {
        console.log('\n🎯 Demonstrating Sync Monitoring System...\n');

        // Simuliere verschiedene Sync-Operationen
        const testMetrics = [
            { operation: 'uploadTrips', entityType: 'Trip', entityCount: 15, duration: 2500, success: true },
            { operation: 'downloadMemories', entityType: 'Memory', entityCount: 234, duration: 1800, success: true },
            { operation: 'syncMediaItems', entityType: 'MediaItem', entityCount: 45, duration: 8900, success: false, errorMessage: 'Network timeout' },
            { operation: 'uploadGPXTracks', entityType: 'GPXTrack', entityCount: 8, duration: 3200, success: true }
        ];

        // Aufzeichnen der Metriken
        for (const metric of testMetrics) {
            await this.recordMetric(metric);
        }

        // Performance-Analyse
        const analysis = await this.getPerformanceAnalysis('hour');
        console.log('📊 Performance Analysis:', {
            totalOperations: analysis.totalOperations,
            successRate: `${(analysis.successRate * 100).toFixed(1)}%`,
            averageDuration: `${analysis.averageDuration.toFixed(0)}ms`,
            throughput: `${analysis.throughput.toFixed(1)} entities/hour`
        });

        // Health-Check durchführen
        const healthResult = await this.performHealthCheck();
        console.log('🏥 Health Check:', {
            status: healthResult.status,
            score: `${(healthResult.score * 100).toFixed(1)}%`
        });

        // Trend-Analyse
        const trendAnalysis = await this.analyzeTrends(1);
        console.log('📈 Trend Analysis:', {
            period: trendAnalysis.period,
            recommendations: trendAnalysis.recommendations
        });

        console.log('\n✅ Monitoring demonstration completed!\n');
    }

    // Private Hilfsmethoden
    private startPeriodicTasks(): void {
        // Alle 15 Minuten: Automatischer Health-Check
        setInterval(() => {
            this.performHealthCheck().catch(error => {
                console.error('Periodic health check failed:', error);
            });
        }, 15 * 60 * 1000);

        // Alle 30 Minuten: Cleanup alter Daten
        setInterval(() => {
            this.cleanupOldData();
        }, 30 * 60 * 1000);

        // Alle 5 Minuten: Anomalie-Erkennung
        setInterval(() => {
            this.detectAnomalies();
        }, 5 * 60 * 1000);
    }

    private async analyzeMetricRealtime(metric: SyncMetricData): Promise<void> {
        // Langsame Operationen erkennen
        if (metric.duration > 5000) { // > 5 Sekunden
            await this.triggerAlert(
                'performance',
                'warning',
                `Slow operation detected: ${metric.operation} took ${metric.duration}ms`,
                metric
            );
        }

        // Fehlgeschlagene Operationen
        if (!metric.success) {
            await this.triggerAlert(
                'error',
                'warning',
                `Operation failed: ${metric.operation} - ${metric.errorMessage || 'Unknown error'}`,
                metric
            );
        }

        // Sehr hohe Entity-Counts
        if (metric.entityCount > 1000) {
            await this.triggerAlert(
                'throughput',
                'info',
                `High throughput operation: ${metric.operation} processed ${metric.entityCount} entities`,
                metric
            );
        }
    }

    private cleanupOldData(): void {
        const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000); // 24 Stunden
        
        // Alte Metriken entfernen
        this.metrics = this.metrics.filter(m => 
            m.timestamp && new Date(m.timestamp) >= cutoff
        );

        // Alte Alerts entfernen (die bereits acknowledged sind)
        this.alerts = this.alerts.filter(a => 
            !a.acknowledged || (Date.now() - a.timestamp.getTime()) < 7 * 24 * 60 * 60 * 1000 // 7 Tage
        );

        console.log(`🧹 Cleanup completed: ${this.metrics.length} metrics, ${this.alerts.length} alerts retained`);
    }

    private detectAnomalies(): void {
        const recent = this.metrics.slice(-100); // Letzten 100 Metriken
        
        if (recent.length < 10) return; // Zu wenig Daten
        
        const avgDuration = recent.reduce((sum, m) => sum + m.duration, 0) / recent.length;
        const currentDuration = recent[recent.length - 1]?.duration || 0;
        
        // Anomalie wenn aktuelle Duration > 3x Durchschnitt
        if (currentDuration > avgDuration * 3) {
            this.triggerAlert(
                'performance',
                'warning',
                `Performance anomaly detected: Current duration ${currentDuration}ms vs average ${avgDuration.toFixed(0)}ms`
            );
        }
    }

    private calculateSuccessRate(metrics: SyncMetricData[]): number {
        if (metrics.length === 0) return 0;
        const successful = metrics.filter(m => m.success).length;
        return successful / metrics.length;
    }

    private calculateAverageDuration(metrics: SyncMetricData[]): number {
        if (metrics.length === 0) return 0;
        const totalDuration = metrics.reduce((sum, m) => sum + m.duration, 0);
        return totalDuration / metrics.length;
    }

    private calculateThroughput(metrics: SyncMetricData[], timeWindow: string): number {
        if (metrics.length === 0) return 0;
        const totalEntities = metrics.reduce((sum, m) => sum + m.entityCount, 0);
        const hours = this.getTimeWindowHours(timeWindow);
        return totalEntities / hours;
    }

    private calculateErrorRate(metrics: SyncMetricData[]): number {
        if (metrics.length === 0) return 0;
        const failed = metrics.filter(m => !m.success).length;
        return failed / metrics.length;
    }

    private identifyBottlenecks(metrics: SyncMetricData[]): string[] {
        const operationStats = new Map<string, { count: number, totalDuration: number }>();
        
        for (const metric of metrics) {
            if (!operationStats.has(metric.operation)) {
                operationStats.set(metric.operation, { count: 0, totalDuration: 0 });
            }
            const stats = operationStats.get(metric.operation)!;
            stats.count++;
            stats.totalDuration += metric.duration;
        }

        const bottlenecks: string[] = [];
        for (const [operation, stats] of operationStats) {
            const avgDuration = stats.totalDuration / stats.count;
            if (avgDuration > 3000) { // > 3 Sekunden Durchschnitt
                bottlenecks.push(`${operation} (${avgDuration.toFixed(0)}ms avg)`);
            }
        }

        return bottlenecks.slice(0, 5); // Top 5 Bottlenecks
    }

    private generateRecommendations(metrics: SyncMetricData[]): string[] {
        const recommendations: string[] = [];
        
        const errorRate = this.calculateErrorRate(metrics);
        if (errorRate > 0.1) {
            recommendations.push('High error rate detected - investigate network connectivity');
        }

        const avgDuration = this.calculateAverageDuration(metrics);
        if (avgDuration > 5000) {
            recommendations.push('High average duration - consider batch size optimization');
        }

        const mediaItems = metrics.filter(m => m.entityType === 'MediaItem');
        if (mediaItems.length > 0) {
            const avgMediaDuration = mediaItems.reduce((sum, m) => sum + m.duration, 0) / mediaItems.length;
            if (avgMediaDuration > 8000) {
                recommendations.push('Media sync is slow - consider compression or parallel uploads');
            }
        }

        return recommendations;
    }

    private getTimeWindowStart(window: string): Date {
        const now = new Date();
        switch (window) {
            case 'hour': return new Date(now.getTime() - 60 * 60 * 1000);
            case 'day': return new Date(now.getTime() - 24 * 60 * 60 * 1000);
            case 'week': return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
            default: return new Date(now.getTime() - 60 * 60 * 1000);
        }
    }

    private getTimeWindowHours(window: string): number {
        switch (window) {
            case 'hour': return 1;
            case 'day': return 24;
            case 'week': return 168;
            default: return 1;
        }
    }

    private async checkMemoryUsage(): Promise<HealthCheckComponent> {
        const memoryUsage = process.memoryUsage();
        const heapUsedMB = memoryUsage.heapUsed / 1024 / 1024;
        const heapTotalMB = memoryUsage.heapTotal / 1024 / 1024;
        const utilization = heapUsedMB / heapTotalMB;
        
        return {
            name: 'Memory Usage',
            score: utilization < 0.8 ? 1 : utilization < 0.9 ? 0.7 : 0.3,
            details: {
                heapUsedMB: heapUsedMB.toFixed(1),
                heapTotalMB: heapTotalMB.toFixed(1),
                utilization: `${(utilization * 100).toFixed(1)}%`
            }
        };
    }

    private async checkResponseTimes(): Promise<HealthCheckComponent> {
        const recentMetrics = this.metrics.slice(-50);
        if (recentMetrics.length === 0) {
            return { name: 'Response Times', score: 1, details: { status: 'No recent data' } };
        }

        const avgResponseTime = recentMetrics.reduce((sum, m) => sum + m.duration, 0) / recentMetrics.length;
        const score = avgResponseTime < 2000 ? 1 : avgResponseTime < 5000 ? 0.7 : 0.3;
        
        return {
            name: 'Response Times',
            score,
            details: {
                averageMs: avgResponseTime.toFixed(0),
                samplesCount: recentMetrics.length
            }
        };
    }

    private async checkErrorRates(): Promise<HealthCheckComponent> {
        const recentMetrics = this.metrics.slice(-100);
        if (recentMetrics.length === 0) {
            return { name: 'Error Rates', score: 1, details: { status: 'No recent data' } };
        }

        const errorRate = this.calculateErrorRate(recentMetrics);
        const score = errorRate < 0.01 ? 1 : errorRate < 0.05 ? 0.7 : 0.3;
        
        return {
            name: 'Error Rates',
            score,
            details: {
                errorRate: `${(errorRate * 100).toFixed(2)}%`,
                samplesCount: recentMetrics.length
            }
        };
    }

    private async checkThroughput(): Promise<HealthCheckComponent> {
        const recentMetrics = this.metrics.slice(-20);
        if (recentMetrics.length === 0) {
            return { name: 'Throughput', score: 1, details: { status: 'No recent data' } };
        }

        const throughput = this.calculateThroughput(recentMetrics, 'hour');
        const score = throughput > 100 ? 1 : throughput > 50 ? 0.7 : 0.5;
        
        return {
            name: 'Throughput',
            score,
            details: {
                entitiesPerHour: throughput.toFixed(1),
                samplesCount: recentMetrics.length
            }
        };
    }

    private determineHealthStatus(score: number): HealthStatus {
        if (score >= 0.8) return 'healthy';
        if (score >= 0.6) return 'warning';
        return 'critical';
    }

    private calculatePerformanceTrend(metrics: SyncMetricData[]): string {
        if (metrics.length < 10) return 'insufficient-data';
        
        const half = Math.floor(metrics.length / 2);
        const firstHalf = metrics.slice(0, half);
        const secondHalf = metrics.slice(half);
        
        const firstAvg = firstHalf.reduce((sum, m) => sum + m.duration, 0) / firstHalf.length;
        const secondAvg = secondHalf.reduce((sum, m) => sum + m.duration, 0) / secondHalf.length;
        
        const improvement = (firstAvg - secondAvg) / firstAvg;
        
        if (improvement > 0.1) return 'improving';
        if (improvement < -0.1) return 'degrading';
        return 'stable';
    }

    private calculateErrorRateTrend(metrics: SyncMetricData[]): string {
        if (metrics.length < 10) return 'insufficient-data';
        
        const half = Math.floor(metrics.length / 2);
        const firstHalf = metrics.slice(0, half);
        const secondHalf = metrics.slice(half);
        
        const firstErrorRate = this.calculateErrorRate(firstHalf);
        const secondErrorRate = this.calculateErrorRate(secondHalf);
        
        if (secondErrorRate < firstErrorRate * 0.8) return 'improving';
        if (secondErrorRate > firstErrorRate * 1.2) return 'degrading';
        return 'stable';
    }

    private calculateThroughputTrend(metrics: SyncMetricData[]): string {
        if (metrics.length < 10) return 'insufficient-data';
        
        const half = Math.floor(metrics.length / 2);
        const firstHalf = metrics.slice(0, half);
        const secondHalf = metrics.slice(half);
        
        const firstThroughput = this.calculateThroughput(firstHalf, 'hour');
        const secondThroughput = this.calculateThroughput(secondHalf, 'hour');
        
        const improvement = (secondThroughput - firstThroughput) / firstThroughput;
        
        if (improvement > 0.1) return 'improving';
        if (improvement < -0.1) return 'degrading';
        return 'stable';
    }

    private generateTrendRecommendations(metrics: SyncMetricData[]): string {
        const perfTrend = this.calculatePerformanceTrend(metrics);
        const errorTrend = this.calculateErrorRateTrend(metrics);
        const throughputTrend = this.calculateThroughputTrend(metrics);
        
        if (perfTrend === 'degrading' || errorTrend === 'degrading') {
            return 'Performance degradation detected - investigate system resources and network connectivity';
        }
        
        if (throughputTrend === 'degrading') {
            return 'Throughput declining - consider optimizing batch sizes or parallel processing';
        }
        
        if (perfTrend === 'improving' && errorTrend === 'improving') {
            return 'System performance is improving - current optimizations are effective';
        }
        
        return 'System performance is stable - continue monitoring';
    }

    private generateForecast(metrics: SyncMetricData[]): any {
        if (metrics.length < 20) {
            return { message: 'Insufficient data for forecasting' };
        }
        
        const avgDuration = this.calculateAverageDuration(metrics);
        const errorRate = this.calculateErrorRate(metrics);
        
        return {
            expectedDuration: `${avgDuration.toFixed(0)}ms ± 20%`,
            expectedErrorRate: `${(errorRate * 100).toFixed(2)}% ± 0.5%`,
            confidence: metrics.length > 100 ? 'high' : 'medium'
        };
    }
}

// SyncMetricData ist bereits in MonitoringTypes.ts mit timestamp erweitert

// Interfaces für interne Verwendung
interface SyncAlert {
    id: string;
    type: AlertType;
    severity: AlertSeverity;
    message: string;
    details?: any;
    timestamp: Date;
    acknowledged: boolean;
}

interface HealthCheck {
    id: string;
    timestamp: Date;
    status: HealthStatus;
    score: number;
    details: any;
}

interface PerformanceAnalysis {
    totalOperations: number;
    successRate: number;
    averageDuration: number;
    throughput: number;
    errorRate: number;
    topBottlenecks: string[];
    recommendations: string[];
}

interface TrendAnalysis {
    period: string;
    trends: any;
    forecast: any;
    recommendations: string[];
}

interface HealthCheckResult {
    status: HealthStatus;
    score: number;
    timestamp: Date;
    details: any;
}

interface HealthCheckComponent {
    name: string;
    score: number;
    details: any;
} 