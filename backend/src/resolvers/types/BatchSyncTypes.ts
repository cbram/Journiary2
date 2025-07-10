import { ObjectType, Field, ID, InputType, registerEnumType } from "type-graphql";

// Enums für bessere Typisierung
export enum SyncOperationType {
    CREATE = "CREATE",
    UPDATE = "UPDATE", 
    DELETE = "DELETE"
}

export enum SyncResultStatus {
    SUCCESS = "success",
    FAILED = "failed"
}

registerEnumType(SyncOperationType, {
    name: "SyncOperationType",
    description: "Typ der Synchronisations-Operation"
});

registerEnumType(SyncResultStatus, {
    name: "SyncResultStatus", 
    description: "Status der Synchronisations-Operation"
});

// Input-Typen für GraphQL
@InputType()
export class SyncOperation {
    @Field(() => ID)
    id!: string;

    @Field(() => SyncOperationType)
    type!: SyncOperationType;

    @Field()
    entityType!: string;

    @Field()
    data!: string; // JSON-serialisierte Entity-Daten

    @Field(() => [String], { nullable: true })
    dependencies?: string[];

    @Field({ nullable: true })
    timestamp?: Date;
}

@InputType()
export class BatchSyncOptions {
    @Field(() => Number, { nullable: true, defaultValue: 100 })
    batchSize?: number;

    @Field(() => Number, { nullable: true, defaultValue: 10 })
    maxConcurrency?: number;

    @Field(() => Number, { nullable: true, defaultValue: 30000 })
    timeout?: number;

    @Field({ nullable: true, defaultValue: false })
    skipValidation?: boolean;
}

// Output-Typen für GraphQL
@ObjectType()
export class SyncResult {
    @Field(() => ID)
    id!: string;

    @Field(() => SyncResultStatus)
    status!: SyncResultStatus;

    @Field({ nullable: true })
    data?: string; // JSON-serialisierte Ergebnis-Daten

    @Field({ nullable: true })
    error?: string;

    @Field(() => Number, { nullable: true })
    processingTime?: number;

    @Field({ nullable: true })
    entityType?: string;
}

@ObjectType()
export class FailedOperation {
    @Field(() => ID)
    id!: string;

    @Field()
    error!: string;

    @Field()
    entityType!: string;

    @Field(() => SyncOperationType)
    operationType!: SyncOperationType;
}

@ObjectType()
export class BatchSyncResponse {
    @Field(() => [SyncResult])
    successful!: SyncResult[];

    @Field(() => [FailedOperation])
    failed!: FailedOperation[];

    @Field(() => Number)
    processed!: number;

    @Field(() => Number)
    duration!: number;

    @Field(() => Date)
    timestamp!: Date;

    @Field(() => Number)
    successRate!: number;

    @Field(() => String, { nullable: true })
    performanceMetrics?: string; // JSON-serialisierte Performance-Daten
}

// Performance-Metriken für interne Verwendung
export interface PerformanceMetric {
    operation: string;
    duration: number;
    entityCount: number;
    success: boolean;
    timestamp: Date;
    memoryUsage?: number;
    batchSize?: number;
    concurrency?: number;
}

export interface BatchMetrics {
    totalDuration: number;
    averageOperationTime: number;
    successCount: number;
    failureCount: number;
    throughput: number; // Operationen pro Sekunde
    peakMemoryUsage: number;
    batchSizes: number[];
} 