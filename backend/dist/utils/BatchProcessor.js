"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BatchProcessor = void 0;
const database_1 = require("./database");
const BatchSyncTypes_1 = require("../resolvers/types/BatchSyncTypes");
const PerformanceMonitoring_1 = require("./PerformanceMonitoring");
// Batch-Processor für optimierte Verarbeitung von Sync-Operationen
class BatchProcessor {
    constructor(maxConcurrency = 10, defaultTimeout = 30000) {
        this.maxConcurrency = maxConcurrency;
        this.defaultTimeout = defaultTimeout;
    }
    /**
     * Verarbeitet Items parallel mit konfigurierbarer Concurrency
     */
    async processConcurrently(items, processor, concurrency = this.maxConcurrency) {
        const measurement = new PerformanceMonitoring_1.PerformanceMeasurement("ProcessConcurrently", items.length, concurrency);
        try {
            const results = [];
            // Verarbeite Items in Batches für bessere Memory-Kontrolle
            for (let i = 0; i < items.length; i += concurrency) {
                const batch = items.slice(i, i + concurrency);
                const batchResults = await Promise.allSettled(batch.map(item => processor(item)));
                // Sammle erfolgreiche Ergebnisse
                const successfulResults = batchResults
                    .filter(r => r.status === 'fulfilled')
                    .map(r => r.value);
                // Protokolliere Fehler
                batchResults
                    .filter(r => r.status === 'rejected')
                    .forEach((r, index) => {
                    const rejectedResult = r;
                    console.error(`❌ Batch-Verarbeitung fehlgeschlagen für Item ${i + index}:`, rejectedResult.reason);
                });
                results.push(...successfulResults);
            }
            measurement.finish(items.length);
            return results;
        }
        catch (error) {
            measurement.finish(items.length, error);
            throw error;
        }
    }
    /**
     * Verarbeitet Sync-Operationen mit Dependency-Auflösung
     */
    async processOperationsWithDependencies(operations, entityManager) {
        const measurement = new PerformanceMonitoring_1.PerformanceMeasurement("ProcessOperationsWithDependencies", operations.length);
        try {
            // Sortiere nach Dependencies
            const sortedOperations = this.sortByDependencies(operations);
            console.log(`📋 Verarbeite ${sortedOperations.length} Operationen in dependency-optimierter Reihenfolge`);
            const results = [];
            const processedIds = new Set();
            // Verarbeite Operationen in dependency-korrekter Reihenfolge
            for (const operation of sortedOperations) {
                try {
                    // Prüfe ob alle Dependencies erfüllt sind
                    const dependenciesMet = this.checkDependencies(operation, processedIds);
                    if (!dependenciesMet) {
                        throw new Error(`Dependencies nicht erfüllt für Operation ${operation.id}`);
                    }
                    // Verarbeite Operation
                    const result = await this.processOperation(operation, entityManager);
                    results.push({ operation, result });
                    processedIds.add(operation.id);
                    console.log(`✅ Operation erfolgreich: ${operation.entityType}:${operation.type}:${operation.id}`);
                }
                catch (error) {
                    const errorObj = error;
                    results.push({ operation, error: errorObj });
                    console.error(`❌ Operation fehlgeschlagen: ${operation.entityType}:${operation.type}:${operation.id}`, errorObj.message);
                }
            }
            measurement.finish(operations.length);
            return results;
        }
        catch (error) {
            measurement.finish(operations.length, error);
            throw error;
        }
    }
    /**
     * Sortiert Operationen nach Dependencies (topologische Sortierung)
     */
    sortByDependencies(operations) {
        const dependencyMap = new Map();
        const ordered = [];
        const processed = new Set();
        const visiting = new Set(); // Für Zyklus-Erkennung
        // Erstelle Dependency-Map
        for (const op of operations) {
            dependencyMap.set(op.id, op.dependencies || []);
        }
        // Topologische Sortierung mit Zyklus-Erkennung
        const visit = (opId) => {
            if (processed.has(opId))
                return;
            if (visiting.has(opId)) {
                throw new Error(`Zirkuläre Dependency erkannt bei Operation ${opId}`);
            }
            visiting.add(opId);
            const deps = dependencyMap.get(opId) || [];
            for (const dep of deps) {
                visit(dep);
            }
            visiting.delete(opId);
            processed.add(opId);
            const operation = operations.find(op => op.id === opId);
            if (operation) {
                ordered.push(operation);
            }
        };
        // Besuche alle Operationen
        for (const op of operations) {
            visit(op.id);
        }
        console.log(`📊 Dependency-Sortierung: ${operations.length} → ${ordered.length} Operationen`);
        return ordered;
    }
    /**
     * Prüft ob alle Dependencies einer Operation erfüllt sind
     */
    checkDependencies(operation, processedIds) {
        if (!operation.dependencies || operation.dependencies.length === 0) {
            return true;
        }
        return operation.dependencies.every(depId => processedIds.has(depId));
    }
    /**
     * Verarbeitet eine einzelne Sync-Operation
     */
    async processOperation(operation, entityManager) {
        const operationData = JSON.parse(operation.data);
        switch (operation.type) {
            case BatchSyncTypes_1.SyncOperationType.CREATE:
                return await this.processCreateOperation(operation.entityType, operationData, entityManager);
            case BatchSyncTypes_1.SyncOperationType.UPDATE:
                return await this.processUpdateOperation(operation.entityType, operationData, entityManager);
            case BatchSyncTypes_1.SyncOperationType.DELETE:
                return await this.processDeleteOperation(operation.entityType, operationData, entityManager);
            default:
                throw new Error(`Unbekannter Operationstyp: ${operation.type}`);
        }
    }
    /**
     * Verarbeitet CREATE-Operationen
     */
    async processCreateOperation(entityType, data, entityManager) {
        const repository = entityManager.getRepository(entityType);
        const entity = repository.create(data);
        return await repository.save(entity);
    }
    /**
     * Verarbeitet UPDATE-Operationen
     */
    async processUpdateOperation(entityType, data, entityManager) {
        const repository = entityManager.getRepository(entityType);
        // Finde existierende Entity
        const existingEntity = await repository.findOne({
            where: { id: data.id }
        });
        if (!existingEntity) {
            throw new Error(`Entity ${entityType} mit ID ${data.id} nicht gefunden`);
        }
        // Aktualisiere Entity
        Object.assign(existingEntity, data);
        return await repository.save(existingEntity);
    }
    /**
     * Verarbeitet DELETE-Operationen
     */
    async processDeleteOperation(entityType, data, entityManager) {
        const repository = entityManager.getRepository(entityType);
        const result = await repository.delete(data.id);
        if (result.affected === 0) {
            throw new Error(`Entity ${entityType} mit ID ${data.id} konnte nicht gelöscht werden`);
        }
        return { deleted: true, id: data.id };
    }
    /**
     * Teilt ein Array in Chunks auf
     */
    chunkArray(array, chunkSize) {
        const chunks = [];
        for (let i = 0; i < array.length; i += chunkSize) {
            chunks.push(array.slice(i, i + chunkSize));
        }
        return chunks;
    }
    /**
     * Verarbeitet Operationen mit Timeout
     */
    async processWithTimeout(operation, timeout = this.defaultTimeout) {
        return Promise.race([
            operation(),
            new Promise((_, reject) => {
                setTimeout(() => {
                    reject(new Error(`Operation timeout nach ${timeout}ms`));
                }, timeout);
            })
        ]);
    }
    /**
     * Verarbeitet Operationen in einer Transaktion
     */
    async processInTransaction(operations, processor) {
        return await database_1.AppDataSource.transaction(async (entityManager) => {
            console.log(`🔄 Starte Transaktion für ${operations.length} Operationen`);
            try {
                const result = await processor(operations, entityManager);
                console.log(`✅ Transaktion erfolgreich abgeschlossen`);
                return result;
            }
            catch (error) {
                console.error(`❌ Transaktion fehlgeschlagen, Rollback wird ausgeführt:`, error);
                throw error;
            }
        });
    }
}
exports.BatchProcessor = BatchProcessor;
