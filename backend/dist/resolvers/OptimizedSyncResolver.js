"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OptimizedSyncResolver = void 0;
const type_graphql_1 = require("type-graphql");
const apollo_server_express_1 = require("apollo-server-express");
const BatchSyncTypes_1 = require("./types/BatchSyncTypes");
const BatchProcessor_1 = require("../utils/BatchProcessor");
const PerformanceMonitoring_1 = require("../utils/PerformanceMonitoring");
let OptimizedSyncResolver = class OptimizedSyncResolver {
    constructor() {
        this.batchProcessor = new BatchProcessor_1.BatchProcessor();
    }
    async batchSync(operations, { userId }, options) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("Benutzer muss angemeldet sein für Batch-Sync.");
        }
        const startTime = Date.now();
        const measurement = PerformanceMonitoring_1.performanceMonitor.startMeasurement("BatchSync", options?.batchSize, options?.maxConcurrency);
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
            const results = await Promise.allSettled(batches.map((batch, index) => this.processBatch(batch, userId, index, options?.timeout)));
            // Sammle Ergebnisse
            const successful = [];
            const failed = [];
            results.forEach((result, batchIndex) => {
                if (result.status === 'fulfilled') {
                    successful.push(...result.value.successful);
                    failed.push(...result.value.failed);
                }
                else {
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
            const performanceMetrics = this.generatePerformanceMetrics(operations.length, duration, successful.length, failed.length, options);
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
        }
        catch (error) {
            const duration = Date.now() - startTime;
            measurement.finish(operations.length, error);
            console.error(`❌ Batch-Sync fehlgeschlagen nach ${duration}ms:`, error);
            // Erstelle Fehler-Response
            const failed = operations.map(op => ({
                id: op.id,
                error: `Globaler Batch-Fehler: ${error.message}`,
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
                performanceMetrics: JSON.stringify({ error: error.message })
            };
        }
    }
    async exportPerformanceMetrics({ userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("Benutzer muss angemeldet sein.");
        }
        return PerformanceMonitoring_1.performanceMonitor.exportMetrics();
    }
    async getBatchPerformanceStats({ userId }, operation, lastMinutes) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("Benutzer muss angemeldet sein.");
        }
        const metrics = PerformanceMonitoring_1.performanceMonitor.getMetrics(operation, lastMinutes);
        return JSON.stringify(metrics, null, 2);
    }
    /**
     * Verarbeitet einen einzelnen Batch von Operationen
     */
    async processBatch(operations, userId, batchIndex, timeout) {
        console.log(`🔄 Verarbeite Batch ${batchIndex + 1} mit ${operations.length} Operationen`);
        const batchMeasurement = PerformanceMonitoring_1.performanceMonitor.startMeasurement(`BatchProcess-${batchIndex}`, operations.length);
        try {
            // Verwende Transaktion für atomare Batch-Verarbeitung
            const result = await this.batchProcessor.processInTransaction(operations, async (ops, entityManager) => {
                return await this.processOperationsInBatch(ops, entityManager, userId);
            });
            batchMeasurement.finish(operations.length);
            console.log(`✅ Batch ${batchIndex + 1} erfolgreich verarbeitet`);
            return result;
        }
        catch (error) {
            batchMeasurement.finish(operations.length, error);
            console.error(`❌ Batch ${batchIndex + 1} fehlgeschlagen:`, error);
            // Alle Operationen in diesem Batch als fehlgeschlagen markieren
            const failed = operations.map(op => ({
                id: op.id,
                error: `Batch-Transaktion fehlgeschlagen: ${error.message}`,
                entityType: op.entityType,
                operationType: op.type
            }));
            return { successful: [], failed };
        }
    }
    /**
     * Verarbeitet Operationen innerhalb eines Batches mit Dependency-Auflösung
     */
    async processOperationsInBatch(operations, entityManager, userId) {
        // Verwende BatchProcessor für dependency-aware Verarbeitung
        const results = await this.batchProcessor.processOperationsWithDependencies(operations, entityManager);
        const successful = [];
        const failed = [];
        results.forEach(({ operation, result, error }) => {
            const processingTime = Date.now(); // Vereinfacht, könnte genauer gemessen werden
            if (error) {
                failed.push({
                    id: operation.id,
                    error: error.message,
                    entityType: operation.entityType,
                    operationType: operation.type
                });
            }
            else {
                successful.push({
                    id: operation.id,
                    status: BatchSyncTypes_1.SyncResultStatus.SUCCESS,
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
    validateOperations(operations) {
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
            }
            catch (error) {
                throw new Error(`Operation ${index} hat ungültiges JSON in data-Feld`);
            }
        });
        console.log(`✅ ${operations.length} Operationen erfolgreich validiert`);
    }
    /**
     * Teilt Operationen in Chunks auf
     */
    chunkOperations(operations, chunkSize) {
        return this.batchProcessor.chunkArray(operations, chunkSize);
    }
    /**
     * Generiert Performance-Metriken für die Response
     */
    generatePerformanceMetrics(totalOperations, duration, successCount, failCount, options) {
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
    getCurrentMemoryUsage() {
        try {
            const memoryUsage = process.memoryUsage();
            return memoryUsage.heapUsed;
        }
        catch (error) {
            return 0;
        }
    }
};
exports.OptimizedSyncResolver = OptimizedSyncResolver;
__decorate([
    (0, type_graphql_1.Authorized)(),
    (0, type_graphql_1.Mutation)(() => BatchSyncTypes_1.BatchSyncResponse, {
        description: "Erweiterte Batch-Synchronisation mit Performance-Optimierungen"
    }),
    __param(0, (0, type_graphql_1.Arg)("operations", () => [BatchSyncTypes_1.SyncOperation])),
    __param(1, (0, type_graphql_1.Ctx)()),
    __param(2, (0, type_graphql_1.Arg)("options", () => BatchSyncTypes_1.BatchSyncOptions, { nullable: true })),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Array, Object, BatchSyncTypes_1.BatchSyncOptions]),
    __metadata("design:returntype", Promise)
], OptimizedSyncResolver.prototype, "batchSync", null);
__decorate([
    (0, type_graphql_1.Authorized)(),
    (0, type_graphql_1.Query)(() => String, {
        description: "Exportiert Performance-Metriken als JSON"
    }),
    __param(0, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], OptimizedSyncResolver.prototype, "exportPerformanceMetrics", null);
__decorate([
    (0, type_graphql_1.Authorized)(),
    (0, type_graphql_1.Query)(() => String, {
        description: "Gibt aktuelle Batch-Performance-Statistiken zurück"
    }),
    __param(0, (0, type_graphql_1.Ctx)()),
    __param(1, (0, type_graphql_1.Arg)("operation", { nullable: true })),
    __param(2, (0, type_graphql_1.Arg)("lastMinutes", { nullable: true, defaultValue: 60 })),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, Number]),
    __metadata("design:returntype", Promise)
], OptimizedSyncResolver.prototype, "getBatchPerformanceStats", null);
exports.OptimizedSyncResolver = OptimizedSyncResolver = __decorate([
    (0, type_graphql_1.Resolver)(),
    __metadata("design:paramtypes", [])
], OptimizedSyncResolver);
