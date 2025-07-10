/**
 * Type-Definitionen für das Sync-Monitoring-System
 * Implementiert Phase 7.2: Backend-Monitoring-Types
 */

export interface SyncMetricData {
    operation: string;
    entityType: string;
    entityCount: number;
    duration: number;
    success: boolean;
    errorMessage?: string;
    deviceId?: string;
    memoryUsage?: number;
    networkBytesTransferred?: number;
    timestamp?: Date; // Erweitert für Monitoring-System
}

export interface PerformanceAnalysis {
    totalOperations: number;
    successRate: number;
    averageDuration: number;
    medianDuration: number;
    throughput: number;
    errorRate: number;
    performanceByEntityType: Record<string, EntityTypeAnalysis>;
    devicePerformance: Record<string, DeviceAnalysis>;
    timeSeriesData: TimeSeriesDataPoint[];
    bottlenecks: BottleneckAnalysis[];
    recommendations: string[];
}

export interface EntityTypeAnalysis {
    totalOperations: number;
    successRate: number;
    averageDuration: number;
    totalEntities: number;
    averageEntitiesPerOperation: number;
}

export interface DeviceAnalysis {
    totalOperations: number;
    successRate: number;
    averageDuration: number;
    totalDataTransferred: number;
    lastSeen: Date;
}

export interface TimeSeriesDataPoint {
    timestamp: Date;
    operationCount: number;
    successRate: number;
    averageDuration: number;
}

export interface BottleneckAnalysis {
    type: string;
    severity: 'low' | 'medium' | 'high';
    description: string;
    impact: number;
    recommendations: string[];
}

export interface AlertThresholds {
    slowOperationThreshold: number;
    highMemoryThreshold: number;
    lowThroughputThreshold: number;
    highErrorRateThreshold: number;
    criticalErrorRateThreshold: number;
}

export interface HealthCheckResult {
    status: HealthStatus;
    score: number;
    timestamp: Date;
    details: any;
}

export interface DatabasePerformance {
    connectionCount: number;
    averageQueryTime: number;
    slowQueries: number;
    health: 'healthy' | 'warning' | 'critical';
}

export interface QueueStatus {
    pendingItems: number;
    processingItems: number;
    health: 'healthy' | 'warning' | 'critical';
}

export interface MemoryUsage {
    used: number;
    total: number;
    percentage: number;
    health: 'healthy' | 'warning' | 'critical';
}

export interface NetworkPerformance {
    latency: number;
    bandwidth: number;
    health: 'healthy' | 'warning' | 'critical';
}

export interface DiskSpace {
    used: number;
    total: number;
    percentage: number;
    health: 'healthy' | 'warning' | 'critical';
}

export interface SyncTrendAnalysis {
    period: string;
    trends: TrendAnalysis;
    anomalies: AnomalyDetection[];
    recommendations: string[];
    forecast: ForecastData;
    seasonality: SeasonalityAnalysis;
}

export interface TrendAnalysis {
    operationsTrend: 'increasing' | 'decreasing' | 'stable';
    durationTrend: 'improving' | 'degrading' | 'stable';
    errorRateTrend: 'increasing' | 'decreasing' | 'stable';
    throughputTrend: 'improving' | 'degrading' | 'stable';
}

export interface AnomalyDetection {
    type: string;
    severity: 'low' | 'medium' | 'high';
    description: string;
    timestamp: Date;
    impact: number;
}

export interface ForecastData {
    nextWeekOperations: number;
    nextWeekDuration: number;
    confidence: number;
}

export interface SeasonalityAnalysis {
    hasSeasonality: boolean;
    peakDays: string[];
    lowDays: string[];
}

export interface CapacityPlan {
    currentCapacity: CurrentCapacity;
    projectedCapacity: ProjectedCapacity;
    recommendations: string[];
    alerts: CapacityAlert[];
    timeline: CapacityTimelineEntry[];
}

export interface CurrentCapacity {
    averageOperationsPerDay: number;
    peakOperationsPerHour: number;
    averageDataThroughput: number;
    memoryUsageGrowth: number;
}

export interface ProjectedCapacity {
    projectedOperationsPerDay: number;
    projectedPeakOperationsPerHour: number;
    projectedDataThroughput: number;
    projectedMemoryUsage: number;
}

export interface CapacityAlert {
    type: string;
    message: string;
    estimatedDate: Date;
}

export interface CapacityTimelineEntry {
    date: Date;
    projectedOperations: number;
    projectedMemoryUsage: number;
    confidence: number;
}

export type AlertType = 'performance' | 'error' | 'health' | 'capacity' | 'memory' | 'throughput';
export type AlertSeverity = 'info' | 'warning' | 'critical';
export type HealthStatus = 'healthy' | 'warning' | 'critical';

// Monitoring-Event-Types
export interface MonitoringEvent {
    type: 'alert' | 'health_check' | 'performance_analysis' | 'capacity_planning';
    timestamp: Date;
    data: any;
}

export interface MetricsBatch {
    metrics: SyncMetricData[];
    timestamp: Date;
    batchId: string;
}

export interface AlertRule {
    id: string;
    name: string;
    type: AlertType;
    condition: string;
    threshold: number;
    severity: AlertSeverity;
    enabled: boolean;
    cooldownMinutes: number;
}

export interface MonitoringConfig {
    alertRules: AlertRule[];
    healthCheckInterval: number;
    performanceAnalysisInterval: number;
    capacityPlanningInterval: number;
    retentionDays: number;
    batchSize: number;
    alertThresholds: AlertThresholds;
}

export interface SystemInfo {
    version: string;
    uptime: number;
    nodeVersion: string;
    memory: {
        used: number;
        total: number;
        percentage: number;
    };
    cpu: {
        usage: number;
        cores: number;
    };
    disk: {
        used: number;
        total: number;
        percentage: number;
    };
}

// Monitoring-Dashboard-Types
export interface DashboardMetrics {
    currentOperations: number;
    successRate: number;
    averageResponseTime: number;
    errorRate: number;
    activeAlerts: number;
    systemHealth: HealthStatus;
    lastUpdated: Date;
}

export interface AlertSummary {
    total: number;
    critical: number;
    warning: number;
    info: number;
    recentAlerts: SyncAlert[];
}

export interface PerformanceSummary {
    throughput: number;
    latency: number;
    errorRate: number;
    topSlowOperations: {
        operation: string;
        avgDuration: number;
        count: number;
    }[];
    topErrorOperations: {
        operation: string;
        errorCount: number;
        errorRate: number;
    }[];
}

// Entitäts-Klassen Interface
export interface SyncMetric {
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

export interface SyncAlert {
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

export interface HealthCheck {
    id: string;
    status: HealthStatus;
    score: number;
    details: any;
    timestamp: Date;
} 