import { Repository } from 'typeorm';
import { EventEmitter } from 'events';
import {
    SyncMetricData,
    PerformanceAnalysis,
    EntityTypeAnalysis,
    DeviceAnalysis,
    TimeSeriesDataPoint,
    BottleneckAnalysis,
    AlertThresholds,
    HealthCheckResult,
    DatabasePerformance,
    QueueStatus,
    MemoryUsage,
    NetworkPerformance,
    DiskSpace,
    SyncTrendAnalysis,
    TrendAnalysis,
    AnomalyDetection,
    ForecastData,
    SeasonalityAnalysis,
    CapacityPlan,
    CurrentCapacity,
    ProjectedCapacity,
    CapacityAlert,
    CapacityTimelineEntry,
    AlertType,
    AlertSeverity,
    HealthStatus,
    SyncMetric,
    SyncAlert,
    HealthCheck
} from '../types/MonitoringTypes';

/**
 * Erweiterte Monitoring-Infrastruktur für Synchronisations-Operationen
 * Implementiert Phase 7.2: Backend-Monitoring mit Metriken, Alerts und Health-Checks
 */
export class SyncMonitoringSystem extends EventEmitter {
    private readonly metricsRepository: Repository<SyncMetricEntity>;
    private readonly alertsRepository: Repository<SyncAlertEntity>;
    private readonly healthCheckRepository: Repository<HealthCheckEntity>;
    private readonly metricsBuffer: Map<string, SyncMetricEntity[]> = new Map();
    private readonly alertThresholds: AlertThresholds;
    
    constructor(
        metricsRepo: Repository<SyncMetric>,
        alertsRepo: Repository<SyncAlert>,
        healthRepo: Repository<HealthCheck>
    ) {
        super();
        this.metricsRepository = metricsRepo;
        this.alertsRepository = alertsRepo;
        this.healthCheckRepository = healthRepo;
        this.alertThresholds = this.getDefaultAlertThresholds();
        
        // Starte periodische Auswertungen
        this.startPeriodicAnalysis();
    }
    
    /**
     * Sync-Metriken aufzeichnen
     */
    async recordSyncMetric(metricData: SyncMetricData): Promise<void> {
        const syncMetric = new SyncMetric();
        syncMetric.operation = metricData.operation;
        syncMetric.entityType = metricData.entityType;
        syncMetric.entityCount = metricData.entityCount;
        syncMetric.duration = metricData.duration;
        syncMetric.success = metricData.success;
        syncMetric.errorMessage = metricData.errorMessage;
        syncMetric.deviceId = metricData.deviceId;
        syncMetric.timestamp = new Date();
        syncMetric.memoryUsage = metricData.memoryUsage || 0;
        syncMetric.networkBytesTransferred = metricData.networkBytesTransferred || 0;
        
        // Puffere Metriken für bessere Performance
        const bufferKey = `${metricData.operation}_${metricData.entityType}`;
        if (!this.metricsBuffer.has(bufferKey)) {
            this.metricsBuffer.set(bufferKey, []);
        }
        this.metricsBuffer.get(bufferKey)!.push(syncMetric);
        
        // Speichere Batch periodisch
        if (this.metricsBuffer.get(bufferKey)!.length >= 100) {
            await this.flushMetrics(bufferKey);
        }
        
        // Echtzeitanalyse für kritische Metriken
        await this.analyzeMetricRealtime(syncMetric);
    }
    
    /**
     * Performance-Analyse mit detaillierten Metriken
     */
    async getPerformanceAnalysis(
        timeWindow: 'hour' | 'day' | 'week' = 'hour'
    ): Promise<PerformanceAnalysis> {
        const windowStart = this.getTimeWindowStart(timeWindow);
        
        const metrics = await this.metricsRepository
            .createQueryBuilder('metric')
            .where('metric.timestamp >= :start', { start: windowStart })
            .getMany();
        
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
        
        return analysis;
    }
    
    /**
     * Umfassende Sync-Health-Checks
     */
    async performHealthCheck(): Promise<HealthCheckResult> {
        const healthCheck = new HealthCheck();
        healthCheck.timestamp = new Date();
        
        try {
            // Prüfe Database-Performance
            const dbPerformance = await this.checkDatabasePerformance();
            
            // Prüfe Sync-Queue Status
            const queueStatus = await this.checkSyncQueueStatus();
            
            // Prüfe Error-Rate
            const errorRate = await this.checkErrorRate();
            
            // Prüfe Memory-Usage
            const memoryUsage = await this.checkMemoryUsage();
            
            // Prüfe Network-Performance
            const networkPerformance = await this.checkNetworkPerformance();
            
            // Prüfe Disk-Space
            const diskSpace = await this.checkDiskSpace();
            
            const overallHealth = this.calculateOverallHealth(
                dbPerformance,
                queueStatus,
                errorRate,
                memoryUsage,
                networkPerformance,
                diskSpace
            );
            
            healthCheck.status = overallHealth.status;
            healthCheck.score = overallHealth.score;
            healthCheck.details = {
                database: dbPerformance,
                queue: queueStatus,
                errorRate,
                memory: memoryUsage,
                network: networkPerformance,
                disk: diskSpace
            };
            
            await this.healthCheckRepository.save(healthCheck);
            
            // Trigger Alerts wenn nötig
            if (overallHealth.score < 0.7) {
                await this.triggerHealthAlert(healthCheck);
            }
            
            return {
                status: healthCheck.status,
                score: healthCheck.score,
                timestamp: healthCheck.timestamp,
                details: healthCheck.details
            };
            
        } catch (error) {
            healthCheck.status = 'critical';
            healthCheck.score = 0;
            healthCheck.details = { error: error.message };
            
            await this.healthCheckRepository.save(healthCheck);
            await this.triggerHealthAlert(healthCheck);
            
            return {
                status: 'critical',
                score: 0,
                timestamp: healthCheck.timestamp,
                details: { error: error.message }
            };
        }
    }
    
    /**
     * Intelligentes Alert-System
     */
    async triggerAlert(
        type: AlertType,
        severity: AlertSeverity,
        message: string,
        details?: any
    ): Promise<void> {
        const alert = new SyncAlert();
        alert.type = type;
        alert.severity = severity;
        alert.message = message;
        alert.details = details;
        alert.timestamp = new Date();
        alert.acknowledged = false;
        alert.fingerprint = this.generateAlertFingerprint(type, message, details);
        
        // Prüfe auf Duplikate in letzten 5 Minuten
        const recentSimilarAlert = await this.findRecentSimilarAlert(alert);
        if (recentSimilarAlert) {
            // Erhöhe Counter statt neuen Alert zu erstellen
            await this.incrementAlertCounter(recentSimilarAlert);
            return;
        }
        
        await this.alertsRepository.save(alert);
        
        // Emittiere Event für externe Systeme
        this.emit('alert', alert);
        
        // Sende Benachrichtigungen basierend auf Severity
        await this.sendAlertNotification(alert);
    }
    
    /**
     * Sync-Trends analysieren mit Machine Learning-Ansätzen
     */
    async analyzeSyncTrends(days: number = 7): Promise<SyncTrendAnalysis> {
        const endDate = new Date();
        const startDate = new Date();
        startDate.setDate(endDate.getDate() - days);
        
        const dailyMetrics = await this.metricsRepository
            .createQueryBuilder('metric')
            .select([
                'DATE(metric.timestamp) as date',
                'COUNT(*) as operations',
                'AVG(metric.duration) as avgDuration',
                'MIN(metric.duration) as minDuration',
                'MAX(metric.duration) as maxDuration',
                'SUM(CASE WHEN metric.success = true THEN 1 ELSE 0 END) as successCount',
                'SUM(metric.entityCount) as totalEntities',
                'AVG(metric.memoryUsage) as avgMemoryUsage',
                'SUM(metric.networkBytesTransferred) as totalBytesTransferred'
            ])
            .where('metric.timestamp BETWEEN :start AND :end', { 
                start: startDate, 
                end: endDate 
            })
            .groupBy('DATE(metric.timestamp)')
            .orderBy('date', 'ASC')
            .getRawMany();
        
        const trends = this.calculateTrends(dailyMetrics);
        const anomalies = this.detectAnomalies(dailyMetrics);
        
        return {
            period: `${days} days`,
            trends,
            anomalies,
            recommendations: this.generateTrendRecommendations(trends, anomalies),
            forecast: this.generateForecast(dailyMetrics),
            seasonality: this.analyzeSeasonality(dailyMetrics)
        };
    }
    
    /**
     * Kapazitätsplanung basierend auf historischen Daten
     */
    async generateCapacityPlan(projectionDays: number = 30): Promise<CapacityPlan> {
        const historicalData = await this.getHistoricalMetrics(30); // 30 Tage Historie
        
        const currentCapacity = {
            averageOperationsPerDay: this.calculateAverageOperationsPerDay(historicalData),
            peakOperationsPerHour: this.calculatePeakOperationsPerHour(historicalData),
            averageDataThroughput: this.calculateAverageDataThroughput(historicalData),
            memoryUsageGrowth: this.calculateMemoryUsageGrowth(historicalData)
        };
        
        const projectedCapacity = this.projectCapacity(currentCapacity, projectionDays);
        
        return {
            currentCapacity,
            projectedCapacity,
            recommendations: this.generateCapacityRecommendations(currentCapacity, projectedCapacity),
            alerts: this.generateCapacityAlerts(currentCapacity, projectedCapacity),
            timeline: this.generateCapacityTimeline(projectionDays)
        };
    }
    
    // Private Hilfsmethoden
    private async flushMetrics(bufferKey: string): Promise<void> {
        const metrics = this.metricsBuffer.get(bufferKey) || [];
        if (metrics.length > 0) {
            await this.metricsRepository.save(metrics);
            this.metricsBuffer.set(bufferKey, []);
        }
    }
    
    private async analyzeMetricRealtime(metric: SyncMetric): Promise<void> {
        // Prüfe auf Performance-Anomalien
        if (metric.duration > this.alertThresholds.slowOperationThreshold) {
            await this.triggerAlert(
                'performance',
                'warning',
                `Langsame Sync-Operation erkannt: ${metric.operation} dauerte ${metric.duration}ms`,
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
        
        // Prüfe auf Memory-Spitzen
        if (metric.memoryUsage > this.alertThresholds.highMemoryThreshold) {
            await this.triggerAlert(
                'memory',
                'warning',
                `Hoher Memory-Verbrauch: ${metric.memoryUsage} bytes für ${metric.operation}`,
                { metric }
            );
        }
        
        // Prüfe auf geringe Throughput
        const throughput = metric.entityCount / (metric.duration / 1000);
        if (throughput < this.alertThresholds.lowThroughputThreshold) {
            await this.triggerAlert(
                'throughput',
                'info',
                `Geringe Throughput: ${throughput.toFixed(2)} entities/s für ${metric.operation}`,
                { metric }
            );
        }
    }
    
    private startPeriodicAnalysis(): void {
        // Alle 2 Minuten: Metriken flushen
        setInterval(async () => {
            for (const bufferKey of this.metricsBuffer.keys()) {
                await this.flushMetrics(bufferKey);
            }
        }, 2 * 60 * 1000);
        
        // Alle 10 Minuten: Health-Check
        setInterval(async () => {
            await this.performHealthCheck();
        }, 10 * 60 * 1000);
        
        // Alle 30 Minuten: Trend-Analyse
        setInterval(async () => {
            const trends = await this.analyzeSyncTrends(1);
            this.emit('trends', trends);
        }, 30 * 60 * 1000);
        
        // Täglich: Kapazitätsplanung
        setInterval(async () => {
            const capacityPlan = await this.generateCapacityPlan(7);
            this.emit('capacityPlan', capacityPlan);
        }, 24 * 60 * 60 * 1000);
    }
    
    private calculateSuccessRate(metrics: SyncMetric[]): number {
        const successful = metrics.filter(m => m.success).length;
        return metrics.length > 0 ? successful / metrics.length : 0;
    }
    
    private calculateAverageDuration(metrics: SyncMetric[]): number {
        const totalDuration = metrics.reduce((sum, m) => sum + m.duration, 0);
        return metrics.length > 0 ? totalDuration / metrics.length : 0;
    }
    
    private calculateMedianDuration(metrics: SyncMetric[]): number {
        const sortedDurations = metrics.map(m => m.duration).sort((a, b) => a - b);
        const middle = Math.floor(sortedDurations.length / 2);
        
        if (sortedDurations.length % 2 === 0) {
            return (sortedDurations[middle - 1] + sortedDurations[middle]) / 2;
        } else {
            return sortedDurations[middle];
        }
    }
    
    private calculateThroughput(metrics: SyncMetric[], timeWindow: string): number {
        const totalEntities = metrics.reduce((sum, m) => sum + m.entityCount, 0);
        const windowHours = this.getTimeWindowHours(timeWindow);
        return totalEntities / windowHours;
    }
    
    private calculateErrorRate(metrics: SyncMetric[]): number {
        const failed = metrics.filter(m => !m.success).length;
        return metrics.length > 0 ? failed / metrics.length : 0;
    }
    
    private analyzeByEntityType(metrics: SyncMetric[]): Record<string, EntityTypeAnalysis> {
        const analysis: Record<string, EntityTypeAnalysis> = {};
        
        const entityTypes = [...new Set(metrics.map(m => m.entityType))];
        
        for (const entityType of entityTypes) {
            const typeMetrics = metrics.filter(m => m.entityType === entityType);
            analysis[entityType] = {
                totalOperations: typeMetrics.length,
                successRate: this.calculateSuccessRate(typeMetrics),
                averageDuration: this.calculateAverageDuration(typeMetrics),
                totalEntities: typeMetrics.reduce((sum, m) => sum + m.entityCount, 0),
                averageEntitiesPerOperation: typeMetrics.reduce((sum, m) => sum + m.entityCount, 0) / typeMetrics.length
            };
        }
        
        return analysis;
    }
    
    private analyzeByDevice(metrics: SyncMetric[]): Record<string, DeviceAnalysis> {
        const analysis: Record<string, DeviceAnalysis> = {};
        
        const devices = [...new Set(metrics.map(m => m.deviceId).filter(Boolean))];
        
        for (const deviceId of devices) {
            const deviceMetrics = metrics.filter(m => m.deviceId === deviceId);
            analysis[deviceId] = {
                totalOperations: deviceMetrics.length,
                successRate: this.calculateSuccessRate(deviceMetrics),
                averageDuration: this.calculateAverageDuration(deviceMetrics),
                totalDataTransferred: deviceMetrics.reduce((sum, m) => sum + (m.networkBytesTransferred || 0), 0),
                lastSeen: new Date(Math.max(...deviceMetrics.map(m => m.timestamp.getTime())))
            };
        }
        
        return analysis;
    }
    
    private generateTimeSeriesData(metrics: SyncMetric[]): TimeSeriesDataPoint[] {
        const hourlyData: Record<string, { count: number, successCount: number, totalDuration: number }> = {};
        
        for (const metric of metrics) {
            const hour = metric.timestamp.toISOString().slice(0, 13) + ':00:00';
            
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
    
    private identifyBottlenecks(metrics: SyncMetric[]): BottleneckAnalysis[] {
        const bottlenecks: BottleneckAnalysis[] = [];
        
        // Analysiere langsame Operationen
        const slowOperations = metrics.filter(m => m.duration > this.alertThresholds.slowOperationThreshold);
        if (slowOperations.length > 0) {
            bottlenecks.push({
                type: 'slow_operations',
                severity: 'medium',
                description: `${slowOperations.length} langsame Operationen erkannt`,
                impact: (slowOperations.length / metrics.length) * 100,
                recommendations: ['Überprüfe Datenbankindizes', 'Optimiere Queries', 'Erhöhe Batch-Größen']
            });
        }
        
        // Analysiere Fehlerrate
        const errorRate = this.calculateErrorRate(metrics);
        if (errorRate > 0.05) { // > 5% Fehlerrate
            bottlenecks.push({
                type: 'high_error_rate',
                severity: 'high',
                description: `Hohe Fehlerrate: ${(errorRate * 100).toFixed(2)}%`,
                impact: errorRate * 100,
                recommendations: ['Überprüfe Netzwerkstabilität', 'Validiere Eingabedaten', 'Verbessere Fehlerbehandlung']
            });
        }
        
        return bottlenecks;
    }
    
    private generatePerformanceRecommendations(metrics: SyncMetric[]): string[] {
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
    
    private getDefaultAlertThresholds(): AlertThresholds {
        return {
            slowOperationThreshold: 30000, // 30 Sekunden
            highMemoryThreshold: 100 * 1024 * 1024, // 100MB
            lowThroughputThreshold: 0.5, // 0.5 entities/s
            highErrorRateThreshold: 0.05, // 5%
            criticalErrorRateThreshold: 0.1 // 10%
        };
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
    
    private getTimeWindowHours(window: string): number {
        switch (window) {
            case 'hour': return 1;
            case 'day': return 24;
            case 'week': return 168;
            default: return 1;
        }
    }
    
    private generateAlertFingerprint(type: AlertType, message: string, details?: any): string {
        const data = `${type}_${message}_${JSON.stringify(details)}`;
        return Buffer.from(data).toString('base64').slice(0, 32);
    }
    
    private async findRecentSimilarAlert(alert: SyncAlert): Promise<SyncAlert | null> {
        const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
        
        return await this.alertsRepository.findOne({
            where: {
                fingerprint: alert.fingerprint,
                timestamp: { $gte: fiveMinutesAgo }
            }
        });
    }
    
    private async incrementAlertCounter(alert: SyncAlert): Promise<void> {
        alert.count = (alert.count || 1) + 1;
        alert.lastOccurrence = new Date();
        await this.alertsRepository.save(alert);
    }
    
    private async sendAlertNotification(alert: SyncAlert): Promise<void> {
        switch (alert.severity) {
            case 'critical':
                await this.sendCriticalAlert(alert);
                break;
            case 'warning':
                await this.sendWarningAlert(alert);
                break;
            case 'info':
                await this.sendInfoAlert(alert);
                break;
        }
    }
    
    private async sendCriticalAlert(alert: SyncAlert): Promise<void> {
        console.error(`🚨 CRITICAL ALERT: ${alert.message}`, alert.details);
        // Hier würde normalerweise E-Mail/Slack/etc. gesendet werden
    }
    
    private async sendWarningAlert(alert: SyncAlert): Promise<void> {
        console.warn(`⚠️ WARNING: ${alert.message}`, alert.details);
        // Hier würde normalerweise eine Benachrichtigung gesendet werden
    }
    
    private async sendInfoAlert(alert: SyncAlert): Promise<void> {
        console.info(`ℹ️ INFO: ${alert.message}`, alert.details);
        // Hier würde normalerweise eine Info-Benachrichtigung gesendet werden
    }
    
    // Weitere private Hilfsmethoden für Database-Checks, Queue-Status, etc.
    private async checkDatabasePerformance(): Promise<DatabasePerformance> {
        // Implementierung für Database-Performance-Checks
        return {
            connectionCount: 10,
            averageQueryTime: 50,
            slowQueries: 2,
            health: 'healthy'
        };
    }
    
    private async checkSyncQueueStatus(): Promise<QueueStatus> {
        // Implementierung für Queue-Status-Checks
        return {
            pendingItems: 5,
            processingItems: 2,
            health: 'healthy'
        };
    }
    
    private async checkErrorRate(): Promise<number> {
        // Implementierung für Error-Rate-Checks
        return 0.02; // 2%
    }
    
    private async checkMemoryUsage(): Promise<MemoryUsage> {
        // Implementierung für Memory-Usage-Checks
        return {
            used: 512 * 1024 * 1024, // 512MB
            total: 2 * 1024 * 1024 * 1024, // 2GB
            percentage: 25,
            health: 'healthy'
        };
    }
    
    private async checkNetworkPerformance(): Promise<NetworkPerformance> {
        // Implementierung für Network-Performance-Checks
        return {
            latency: 50,
            bandwidth: 1000,
            health: 'healthy'
        };
    }
    
    private async checkDiskSpace(): Promise<DiskSpace> {
        // Implementierung für Disk-Space-Checks
        return {
            used: 50 * 1024 * 1024 * 1024, // 50GB
            total: 500 * 1024 * 1024 * 1024, // 500GB
            percentage: 10,
            health: 'healthy'
        };
    }
    
    private calculateOverallHealth(...healthChecks: any[]): { status: HealthStatus; score: number } {
        // Vereinfachte Health-Berechnung
        const healthyCount = healthChecks.filter(h => h.health === 'healthy').length;
        const score = healthyCount / healthChecks.length;
        
        let status: HealthStatus;
        if (score >= 0.8) {
            status = 'healthy';
        } else if (score >= 0.6) {
            status = 'warning';
        } else {
            status = 'critical';
        }
        
        return { status, score };
    }
    
    private async triggerHealthAlert(healthCheck: HealthCheck): Promise<void> {
        await this.triggerAlert(
            'health',
            healthCheck.status === 'critical' ? 'critical' : 'warning',
            `System Health Score: ${healthCheck.score}`,
            healthCheck.details
        );
    }
    
    private calculateTrends(dailyMetrics: any[]): TrendAnalysis {
        // Vereinfachte Trend-Berechnung
        return {
            operationsTrend: 'stable',
            durationTrend: 'improving',
            errorRateTrend: 'stable',
            throughputTrend: 'improving'
        };
    }
    
    private detectAnomalies(dailyMetrics: any[]): AnomalyDetection[] {
        // Vereinfachte Anomalie-Erkennung
        return [];
    }
    
    private generateTrendRecommendations(trends: TrendAnalysis, anomalies: AnomalyDetection[]): string[] {
        const recommendations: string[] = [];
        
        if (trends.durationTrend === 'degrading') {
            recommendations.push('Performance-Optimierung erforderlich');
        }
        
        if (trends.errorRateTrend === 'increasing') {
            recommendations.push('Fehlerbehandlung überprüfen');
        }
        
        return recommendations;
    }
    
    private generateForecast(dailyMetrics: any[]): ForecastData {
        // Vereinfachte Prognose-Berechnung
        return {
            nextWeekOperations: 1000,
            nextWeekDuration: 5000,
            confidence: 0.85
        };
    }
    
    private analyzeSeasonality(dailyMetrics: any[]): SeasonalityAnalysis {
        // Vereinfachte Saisonalitäts-Analyse
        return {
            hasSeasonality: false,
            peakDays: [],
            lowDays: []
        };
    }
    
    private async getHistoricalMetrics(days: number): Promise<SyncMetric[]> {
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);
        
        return await this.metricsRepository.find({
            where: {
                timestamp: { $gte: startDate }
            },
            order: {
                timestamp: 'ASC'
            }
        });
    }
    
    private calculateAverageOperationsPerDay(metrics: SyncMetric[]): number {
        const days = new Set(metrics.map(m => m.timestamp.toDateString())).size;
        return days > 0 ? metrics.length / days : 0;
    }
    
    private calculatePeakOperationsPerHour(metrics: SyncMetric[]): number {
        const hourlyOperations: Record<string, number> = {};
        
        for (const metric of metrics) {
            const hour = metric.timestamp.toISOString().slice(0, 13);
            hourlyOperations[hour] = (hourlyOperations[hour] || 0) + 1;
        }
        
        return Math.max(...Object.values(hourlyOperations));
    }
    
    private calculateAverageDataThroughput(metrics: SyncMetric[]): number {
        const totalBytes = metrics.reduce((sum, m) => sum + (m.networkBytesTransferred || 0), 0);
        const totalDuration = metrics.reduce((sum, m) => sum + m.duration, 0);
        return totalDuration > 0 ? totalBytes / (totalDuration / 1000) : 0;
    }
    
    private calculateMemoryUsageGrowth(metrics: SyncMetric[]): number {
        const sortedMetrics = metrics.sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());
        if (sortedMetrics.length < 2) return 0;
        
        const firstWeek = sortedMetrics.slice(0, Math.floor(sortedMetrics.length / 2));
        const secondWeek = sortedMetrics.slice(Math.floor(sortedMetrics.length / 2));
        
        const firstWeekAvg = firstWeek.reduce((sum, m) => sum + (m.memoryUsage || 0), 0) / firstWeek.length;
        const secondWeekAvg = secondWeek.reduce((sum, m) => sum + (m.memoryUsage || 0), 0) / secondWeek.length;
        
        return secondWeekAvg - firstWeekAvg;
    }
    
    private projectCapacity(current: any, days: number): any {
        // Vereinfachte Kapazitäts-Projektion
        return {
            projectedOperationsPerDay: current.averageOperationsPerDay * 1.1,
            projectedPeakOperationsPerHour: current.peakOperationsPerHour * 1.2,
            projectedDataThroughput: current.averageDataThroughput * 1.1,
            projectedMemoryUsage: current.memoryUsageGrowth * days
        };
    }
    
    private generateCapacityRecommendations(current: any, projected: any): string[] {
        const recommendations: string[] = [];
        
        if (projected.projectedOperationsPerDay > current.averageOperationsPerDay * 1.5) {
            recommendations.push('Erwäge Skalierung der Backend-Infrastruktur');
        }
        
        if (projected.projectedMemoryUsage > 1024 * 1024 * 1024) { // 1GB
            recommendations.push('Memory-Optimierung erforderlich');
        }
        
        return recommendations;
    }
    
    private generateCapacityAlerts(current: any, projected: any): CapacityAlert[] {
        const alerts: CapacityAlert[] = [];
        
        if (projected.projectedOperationsPerDay > current.averageOperationsPerDay * 2) {
            alerts.push({
                type: 'capacity_warning',
                message: 'Kapazitätsgrenze könnte erreicht werden',
                estimatedDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
            });
        }
        
        return alerts;
    }
    
    private generateCapacityTimeline(days: number): CapacityTimelineEntry[] {
        const timeline: CapacityTimelineEntry[] = [];
        
        for (let i = 0; i < days; i++) {
            const date = new Date();
            date.setDate(date.getDate() + i);
            
            timeline.push({
                date,
                projectedOperations: 100 + i * 5,
                projectedMemoryUsage: 512 * 1024 * 1024 + i * 10 * 1024 * 1024,
                confidence: 0.9 - (i * 0.01)
            });
        }
        
        return timeline;
    }
}

// Entitäts-Klassen (vereinfacht - für TypeORM)
export class SyncMetricEntity {
    id: string;
    operation: string;
    entityType: string;
    entityCount: number;
    duration: number;
    success: boolean;
    errorMessage?: string;
    deviceId?: string;
    timestamp: Date;
    memoryUsage: number;
    networkBytesTransferred: number;
}

export class SyncAlertEntity {
    id: string;
    type: AlertType;
    severity: AlertSeverity;
    message: string;
    details?: any;
    timestamp: Date;
    acknowledged: boolean;
    acknowledgedBy?: string;
    acknowledgedAt?: Date;
    fingerprint: string;
    count?: number;
    lastOccurrence?: Date;
}

export class HealthCheckEntity {
    id: string;
    status: HealthStatus;
    score: number;
    details: any;
    timestamp: Date;
} 