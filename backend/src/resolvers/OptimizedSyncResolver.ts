import { Resolver, Mutation, Arg, Ctx, Authorized, Query } from "type-graphql";
import { AuthenticationError } from "apollo-server-express";
import { AppDataSource } from "../utils/database";
import { MyContext } from "..";
import { 
    SyncOperation, 
    BatchSyncOptions, 
    BatchSyncResponse, 
    SyncResult, 
    FailedOperation,
    SyncResultStatus 
} from "./types/BatchSyncTypes";
import { BatchProcessor } from "../utils/BatchProcessor";
import { PerformanceMeasurement, MetricsCollector, performanceMonitor } from "../utils/PerformanceMonitoring";
import { EntityManager } from "typeorm";

@Resolver()
export class OptimizedSyncResolver {
    private readonly batchProcessor: BatchProcessor;
    
    constructor() {
        this.batchProcessor = new BatchProcessor();
    }
    
    @Authorized()
    @Mutation(() => BatchSyncResponse, { 
        description: "Erweiterte Batch-Synchronisation mit Performance-Optimierungen" 
    })
    async batchSync(
        @Arg("operations", () => [SyncOperation]) operations: SyncOperation[],
        @Ctx() { userId }: MyContext,
        @Arg("options", () => BatchSyncOptions, { nullable: true }) options?: BatchSyncOptions
    ): Promise<BatchSyncResponse> {
        if (!userId) {
            throw new AuthenticationError("Benutzer muss angemeldet sein für Batch-Sync.");
        }
        
        const startTime = Date.now();
        const measurement = performanceMonitor.startMeasurement(
            "BatchSync", 
            options?.batchSize, 
            options?.maxConcurrency
        );
        
        console.log(`🚀 Batch-Sync gestartet: ${operations.length} Operationen für User ${userId}`);
        
        try {
            // Validiere Operationen
            if (!options?.skipValidation) {
                this.validateOperations(operations);
            }
            
            // Parallelisiere Batch-Operationen
            const batchSize = options?.batchSize || 100;
            const batches = this.chunkOperations(operations, batchSize);
            
            console.log(`📊 Aufgeteilt in ${batches.length} Batches à ${batchSize} Operationen`);
            
            // Verarbeite Batches parallel mit Error-Handling
            const results = await Promise.allSettled(
                batches.map((batch, index) => 
                    this.processBatch(batch, userId, index, options?.timeout)
                )
            );
            
            // Sammle Ergebnisse
            const successful: SyncResult[] = [];
            const failed: FailedOperation[] = [];
            
            results.forEach((result, batchIndex) => {
                if (result.status === 'fulfilled') {
                    successful.push(...result.value.successful);
                    failed.push(...result.value.failed);
                } else {
                    // Behandle Batch-Level-Fehler
                    const batchOps = batches[batchIndex];
                    batchOps.forEach(op => {
                        failed.push({
                            id: op.id,
                            error: `Batch-Fehler: ${result.reason.message}`,
                            entityType: op.entityType,
                            operationType: op.type
                        });
                    });
                }
            });
            
            const duration = Date.now() - startTime;
            const successRate = operations.length > 0 ? successful.length / operations.length : 0;
            
            // Performance-Metriken sammeln
            const performanceMetrics = this.generatePerformanceMetrics(
                operations.length,
                duration,
                successful.length,
                failed.length,
                options
            );
            
            measurement.finish(operations.length);
            
            console.log(`✅ Batch-Sync abgeschlossen: ${successful.length}/${operations.length} erfolgreich in ${duration}ms`);
            
            return {
                successful,
                failed,
                processed: operations.length,
                duration,
                timestamp: new Date(),
                successRate,
                performanceMetrics: JSON.stringify(performanceMetrics)
            };
            
        } catch (error) {
            const duration = Date.now() - startTime;
            measurement.finish(operations.length, error as Error);
            
            console.error(`❌ Batch-Sync fehlgeschlagen nach ${duration}ms:`, error);
            
            // Erstelle Fehler-Response
            const failed: FailedOperation[] = operations.map(op => ({
                id: op.id,
                error: `Globaler Batch-Fehler: ${(error as Error).message}`,
                entityType: op.entityType,
                operationType: op.type
            }));
            
            return {
                successful: [],
                failed,
                processed: operations.length,
                duration,
                timestamp: new Date(),
                successRate: 0,
                performanceMetrics: JSON.stringify({ error: (error as Error).message })
            };
        }
    }
    
    @Authorized()
    @Query(() => String, { 
        description: "Exportiert Performance-Metriken als JSON" 
    })
    async exportPerformanceMetrics(@Ctx() { userId }: MyContext): Promise<string> {
        if (!userId) {
            throw new AuthenticationError("Benutzer muss angemeldet sein.");
        }
        
        return performanceMonitor.exportMetrics();
    }
    
    @Authorized()
    @Query(() => String, { 
        description: "Gibt aktuelle Batch-Performance-Statistiken zurück" 
    })
    async getBatchPerformanceStats(
        @Ctx() { userId }: MyContext,
        @Arg("operation", { nullable: true }) operation?: string,
        @Arg("lastMinutes", { nullable: true, defaultValue: 60 }) lastMinutes?: number
    ): Promise<string> {
        if (!userId) {
            throw new AuthenticationError("Benutzer muss angemeldet sein.");
        }
        
        const metrics = performanceMonitor.getMetrics(operation, lastMinutes);
        return JSON.stringify(metrics, null, 2);
    }
    
    /**
     * Verarbeitet einen einzelnen Batch von Operationen
     */
    private async processBatch(
        operations: SyncOperation[],
        userId: string,
        batchIndex: number,
        timeout?: number
    ): Promise<{ successful: SyncResult[]; failed: FailedOperation[] }> {
        console.log(`🔄 Verarbeite Batch ${batchIndex + 1} mit ${operations.length} Operationen`);
        
        const batchMeasurement = performanceMonitor.startMeasurement(
            `BatchProcess-${batchIndex}`,
            operations.length
        );
        
        try {
            // Verwende Transaktion für atomare Batch-Verarbeitung
            const result = await this.batchProcessor.processInTransaction(
                operations,
                async (ops, entityManager) => {
                    return await this.processOperationsInBatch(ops, entityManager, userId);
                }
            );
            
            batchMeasurement.finish(operations.length);
            console.log(`✅ Batch ${batchIndex + 1} erfolgreich verarbeitet`);
            
            return result;
            
        } catch (error) {
            batchMeasurement.finish(operations.length, error as Error);
            console.error(`❌ Batch ${batchIndex + 1} fehlgeschlagen:`, error);
            
            // Alle Operationen in diesem Batch als fehlgeschlagen markieren
            const failed: FailedOperation[] = operations.map(op => ({
                id: op.id,
                error: `Batch-Transaktion fehlgeschlagen: ${(error as Error).message}`,
                entityType: op.entityType,
                operationType: op.type
            }));
            
            return { successful: [], failed };
        }
    }
    
    /**
     * Verarbeitet Operationen innerhalb eines Batches mit Dependency-Auflösung
     */
    private async processOperationsInBatch(
        operations: SyncOperation[],
        entityManager: EntityManager,
        userId: string
    ): Promise<{ successful: SyncResult[]; failed: FailedOperation[] }> {
        // Verwende BatchProcessor für dependency-aware Verarbeitung
        const results = await this.batchProcessor.processOperationsWithDependencies(
            operations,
            entityManager
        );
        
        const successful: SyncResult[] = [];
        const failed: FailedOperation[] = [];
        
        results.forEach(({ operation, result, error }) => {
            const processingTime = Date.now(); // Vereinfacht, könnte genauer gemessen werden
            
            if (error) {
                failed.push({
                    id: operation.id,
                    error: error.message,
                    entityType: operation.entityType,
                    operationType: operation.type
                });
            } else {
                successful.push({
                    id: operation.id,
                    status: SyncResultStatus.SUCCESS,
                    data: JSON.stringify(result),
                    processingTime,
                    entityType: operation.entityType
                });
            }
        });
        
        return { successful, failed };
    }
    
    /**
     * Validiert die eingehenden Operationen
     */
    private validateOperations(operations: SyncOperation[]): void {
        if (!operations || operations.length === 0) {
            throw new Error("Keine Operationen zur Verarbeitung erhalten");
        }
        
        if (operations.length > 10000) {
            throw new Error("Zu viele Operationen in einem Batch (Maximum: 10000)");
        }
        
        // Validiere jede Operation
        operations.forEach((op, index) => {
            if (!op.id || !op.type || !op.entityType || !op.data) {
                throw new Error(`Operation ${index} ist unvollständig: ID, Type, EntityType und Data sind erforderlich`);
            }
            
            try {
                JSON.parse(op.data);
            } catch (error) {
                throw new Error(`Operation ${index} hat ungültiges JSON in data-Feld`);
            }
        });
        
        console.log(`✅ ${operations.length} Operationen erfolgreich validiert`);
    }
    
    /**
     * Teilt Operationen in Chunks auf
     */
    private chunkOperations(operations: SyncOperation[], chunkSize: number): SyncOperation[][] {
        return this.batchProcessor.chunkArray(operations, chunkSize);
    }
    
    /**
     * Generiert Performance-Metriken für die Response
     */
    private generatePerformanceMetrics(
        totalOperations: number,
        duration: number,
        successCount: number,
        failCount: number,
        options?: BatchSyncOptions
    ): any {
        const throughput = totalOperations > 0 ? totalOperations / (duration / 1000) : 0;
        const successRate = totalOperations > 0 ? successCount / totalOperations : 0;
        
        return {
            totalOperations,
            duration,
            throughput: parseFloat(throughput.toFixed(2)),
            successRate: parseFloat(successRate.toFixed(4)),
            successCount,
            failCount,
            batchSize: options?.batchSize || 100,
            maxConcurrency: options?.maxConcurrency || 10,
            timestamp: new Date().toISOString(),
            memoryUsage: this.getCurrentMemoryUsage()
        };
    }
    
    /**
     * Gibt aktuellen Speicherverbrauch zurück
     */
    private getCurrentMemoryUsage(): number {
        try {
            const memoryUsage = process.memoryUsage();
            return memoryUsage.heapUsed;
        } catch (error) {
            return 0;
        }
    }
} 