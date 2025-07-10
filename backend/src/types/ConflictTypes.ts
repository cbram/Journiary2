import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, BaseEntity as TypeORMBaseEntity } from 'typeorm';

// Basis-Entity-Interface
export interface BaseEntity {
    id: string;
    createdAt?: Date;
    updatedAt?: Date;
}

// Conflict-Resolution-Strategien
export type ConflictResolutionStrategy = 'lastWriteWins' | 'fieldLevel' | 'devicePriority' | 'userChoice';

// Conflict-Metadaten
export interface ConflictMetadata {
    strategy: ConflictResolutionStrategy;
    winner?: 'local' | 'remote';
    localTimestamp?: Date;
    remoteTimestamp?: Date;
    devicePriority?: number;
    changedFields?: string[];
    status?: 'resolved' | 'pending';
    details?: string;
}

// Conflict-Resolution-Ergebnis
export interface ConflictResolutionResult<T> {
    resolvedEntity: T;
    conflictId: string;
    metadata: ConflictMetadata;
    strategy: ConflictResolutionStrategy;
}

// Conflict-Information für Response
export interface ConflictInfo {
    conflictId: string;
    entityType: string;
    entityId: string;
    resolution: ConflictMetadata;
    strategy: ConflictResolutionStrategy;
}

// Fehlgeschlagene Operation
export interface FailedOperation {
    id: string;
    error: string;
    entityType: string;
    entityId?: string;
}

// Sync-Operationen für Conflict-Aware-Sync
export interface SyncOperation {
    id: string;
    entityType: string;
    data: any;
    operation?: 'CREATE' | 'UPDATE' | 'DELETE';
}

// Sync-Ergebnis
export interface SyncResult {
    id: string;
    status: 'success' | 'resolved' | 'failed';
    data?: any;
    conflictId?: string;
    entityType?: string;
}

// Conflict-Aware-Sync-Response
export interface ConflictAwareSyncResponse {
    resolved: SyncResult[];
    conflicts: ConflictInfo[];
    failed: FailedOperation[];
    totalProcessed: number;
}

// Device-Information
export interface DeviceInfo {
    id: string;
    name: string;
    type: 'ios' | 'android' | 'web';
    priority: number;
    lastSeen: Date;
    userId: string;
}

// ConflictLog-Entity
@Entity('conflict_logs')
export class ConflictLog extends TypeORMBaseEntity {
    @PrimaryGeneratedColumn('uuid')
    id!: string;

    @Column()
    entityType!: string;

    @Column()
    entityId!: string;

    @Column()
    deviceId!: string;

    @Column('varchar')
    strategy!: ConflictResolutionStrategy;

    @Column('text')
    localVersion!: string;

    @Column('text')
    remoteVersion!: string;

    @CreateDateColumn()
    timestamp!: Date;

    @Column('jsonb', { nullable: true })
    resolution?: ConflictMetadata;

    @UpdateDateColumn({ nullable: true })
    resolvedAt?: Date;

    @Column('varchar', { default: 'pending' })
    status!: 'pending' | 'resolved' | 'pending_user_choice';

    @Column('jsonb', { nullable: true })
    metadata?: any;
}

// Device-Registry-Entity
@Entity('device_registry')
export class DeviceRegistry extends TypeORMBaseEntity {
    @PrimaryGeneratedColumn('uuid')
    id!: string;

    @Column()
    deviceId!: string;

    @Column()
    name!: string;

    @Column('varchar')
    type!: 'ios' | 'android' | 'web';

    @Column('int', { default: 0 })
    priority!: number;

    @UpdateDateColumn()
    lastSeen!: Date;

    @Column()
    userId!: string;

    @Column('jsonb', { nullable: true })
    metadata?: any;
}

// Device-Registry-Service-Interface
export interface IDeviceRegistry {
    getDevice(deviceId: string): Promise<DeviceInfo | null>;
    registerDevice(deviceInfo: Omit<DeviceInfo, 'id'>): Promise<DeviceInfo>;
    updateDevicePriority(deviceId: string, priority: number): Promise<void>;
    getDevicesForUser(userId: string): Promise<DeviceInfo[]>;
}

// Advanced Conflict-Resolution-Optionen
export interface ConflictResolutionOptions {
    strategy: ConflictResolutionStrategy;
    deviceId?: string;
    userId?: string;
    customRules?: ConflictRule[];
    timeout?: number;
}

// Regel für Custom-Conflict-Resolution
export interface ConflictRule {
    field: string;
    priority: 'local' | 'remote' | 'newest' | 'custom';
    condition?: (localValue: any, remoteValue: any) => boolean;
    resolver?: (localValue: any, remoteValue: any) => any;
}

// Conflict-Detection-Ergebnis
export interface ConflictDetectionResult {
    hasConflict: boolean;
    conflictedFields: string[];
    localChecksum?: string;
    remoteChecksum?: string;
    conflictType: 'none' | 'data' | 'timestamp' | 'structural';
}

// Batch-Conflict-Resolution
export interface BatchConflictResolution {
    operations: ConflictResolutionOperation[];
    options: ConflictResolutionOptions;
}

export interface ConflictResolutionOperation {
    entityType: string;
    entityId: string;
    localData: any;
    remoteData: any;
}

// Multi-Device-Sync-Koordination
export interface MultiDeviceSyncCoordination {
    coordinationId: string;
    deviceIds: string[];
    syncTimestamp: Date;
    lockTimeout: number;
    conflictResolutions: ConflictResolutionResult<any>[];
}

// Erweiterte Device-Prioritäts-Regeln
export interface DevicePriorityRule {
    deviceType: 'ios' | 'android' | 'web';
    basePriority: number;
    boostFactors: {
        recentActivity?: number;  // Boost für kürzliche Aktivität
        dataCreator?: number;     // Boost wenn Gerät Daten erstellt hat
        userPreference?: number;  // Benutzer-definierte Priorität
    };
}

// Conflict-Resolution-Metriken
export interface ConflictResolutionMetrics {
    totalConflicts: number;
    resolvedConflicts: number;
    pendingConflicts: number;
    strategyCounts: Record<ConflictResolutionStrategy, number>;
    averageResolutionTime: number;
    deviceConflictCounts: Record<string, number>;
} 