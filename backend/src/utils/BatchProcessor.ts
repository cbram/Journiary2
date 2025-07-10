import { AppDataSource } from "./database";
import { EntityManager } from "typeorm";
import { SyncOperation, SyncOperationType } from "../resolvers/types/BatchSyncTypes";
import { PerformanceMeasurement } from "./PerformanceMonitoring";

// Batch-Processor für optimierte Verarbeitung von Sync-Operationen
export class BatchProcessor {
    private readonly maxConcurrency: number;
    private readonly defaultTimeout: number;
    
    constructor(maxConcurrency: number = 10, defaultTimeout: number = 30000) {
        this.maxConcurrency = maxConcurrency;
        this.defaultTimeout = defaultTimeout;
    }
    
    /**
     * Verarbeitet Items parallel mit konfigurierbarer Concurrency
     */
    async processConcurrently<T, R>(
        items: T[],
        processor: (item: T) => Promise<R>,
        concurrency: number = this.maxConcurrency
    ): Promise<R[]> {
        const measurement = new PerformanceMeasurement(
            "ProcessConcurrently", 
            items.length, 
            concurrency
        );
        
        try {
            const results: R[] = [];
            
            // Verarbeite Items in Batches für bessere Memory-Kontrolle
            for (let i = 0; i < items.length; i += concurrency) {
                const batch = items.slice(i, i + concurrency);
                const batchResults = await Promise.allSettled(
                    batch.map(item => processor(item))
                );
                
                // Sammle erfolgreiche Ergebnisse
                const successfulResults = batchResults
                    .filter(r => r.status === 'fulfilled')
                    .map(r => (r as PromiseFulfilledResult<R>).value);
                    
                // Protokolliere Fehler
                batchResults
                    .filter(r => r.status === 'rejected')
                    .forEach((r, index) => {
                        const rejectedResult = r as PromiseRejectedResult;
                        console.error(
                            `❌ Batch-Verarbeitung fehlgeschlagen für Item ${i + index}:`,
                            rejectedResult.reason
                        );
                    });
                
                results.push(...successfulResults);
            }
            
            measurement.finish(items.length);
            return results;
            
        } catch (error) {
            measurement.finish(items.length, error as Error);
            throw error;
        }
    }
    
    /**
     * Verarbeitet Sync-Operationen mit Dependency-Auflösung
     */
    async processOperationsWithDependencies(
        operations: SyncOperation[],
        entityManager: EntityManager
    ): Promise<Array<{ operation: SyncOperation; result?: any; error?: Error }>> {
        const measurement = new PerformanceMeasurement(
            "ProcessOperationsWithDependencies",
            operations.length
        );
        
        try {
            // Sortiere nach Dependencies
            const sortedOperations = this.sortByDependencies(operations);
            console.log(`📋 Verarbeite ${sortedOperations.length} Operationen in dependency-optimierter Reihenfolge`);
            
            const results: Array<{ operation: SyncOperation; result?: any; error?: Error }> = [];
            const processedIds = new Set<string>();
            
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
                    
                } catch (error) {
                    const errorObj = error as Error;
                    results.push({ operation, error: errorObj });
                    console.error(`❌ Operation fehlgeschlagen: ${operation.entityType}:${operation.type}:${operation.id}`, errorObj.message);
                }
            }
            
            measurement.finish(operations.length);
            return results;
            
        } catch (error) {
            measurement.finish(operations.length, error as Error);
            throw error;
        }
    }
    
    /**
     * Sortiert Operationen nach Dependencies (topologische Sortierung)
     */
    private sortByDependencies(operations: SyncOperation[]): SyncOperation[] {
        const dependencyMap = new Map<string, string[]>();
        const ordered: SyncOperation[] = [];
        const processed = new Set<string>();
        const visiting = new Set<string>(); // Für Zyklus-Erkennung
        
        // Erstelle Dependency-Map
        for (const op of operations) {
            dependencyMap.set(op.id, op.dependencies || []);
        }
        
        // Topologische Sortierung mit Zyklus-Erkennung
        const visit = (opId: string): void => {
            if (processed.has(opId)) return;
            
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
    private checkDependencies(operation: SyncOperation, processedIds: Set<string>): boolean {
        if (!operation.dependencies || operation.dependencies.length === 0) {
            return true;
        }
        
        return operation.dependencies.every(depId => processedIds.has(depId));
    }
    
    /**
     * Verarbeitet eine einzelne Sync-Operation
     */
    private async processOperation(
        operation: SyncOperation,
        entityManager: EntityManager
    ): Promise<any> {
        const operationData = JSON.parse(operation.data);
        
        switch (operation.type) {
            case SyncOperationType.CREATE:
                return await this.processCreateOperation(operation.entityType, operationData, entityManager);
                
            case SyncOperationType.UPDATE:
                return await this.processUpdateOperation(operation.entityType, operationData, entityManager);
                
            case SyncOperationType.DELETE:
                return await this.processDeleteOperation(operation.entityType, operationData, entityManager);
                
            default:
                throw new Error(`Unbekannter Operationstyp: ${operation.type}`);
        }
    }
    
    /**
     * Verarbeitet CREATE-Operationen
     */
    private async processCreateOperation(
        entityType: string,
        data: any,
        entityManager: EntityManager
    ): Promise<any> {
        const repository = entityManager.getRepository(entityType);
        const entity = repository.create(data);
        return await repository.save(entity);
    }
    
    /**
     * Verarbeitet UPDATE-Operationen
     */
    private async processUpdateOperation(
        entityType: string,
        data: any,
        entityManager: EntityManager
    ): Promise<any> {
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
    private async processDeleteOperation(
        entityType: string,
        data: any,
        entityManager: EntityManager
    ): Promise<any> {
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
    chunkArray<T>(array: T[], chunkSize: number): T[][] {
        const chunks: T[][] = [];
        for (let i = 0; i < array.length; i += chunkSize) {
            chunks.push(array.slice(i, i + chunkSize));
        }
        return chunks;
    }
    
    /**
     * Verarbeitet Operationen mit Timeout
     */
    async processWithTimeout<T>(
        operation: () => Promise<T>,
        timeout: number = this.defaultTimeout
    ): Promise<T> {
        return Promise.race([
            operation(),
            new Promise<never>((_, reject) => {
                setTimeout(() => {
                    reject(new Error(`Operation timeout nach ${timeout}ms`));
                }, timeout);
            })
        ]);
    }
    
    /**
     * Verarbeitet Operationen in einer Transaktion
     */
    async processInTransaction<T>(
        operations: SyncOperation[],
        processor: (ops: SyncOperation[], manager: EntityManager) => Promise<T>
    ): Promise<T> {
        return await AppDataSource.transaction(async (entityManager) => {
            console.log(`🔄 Starte Transaktion für ${operations.length} Operationen`);
            
            try {
                const result = await processor(operations, entityManager);
                console.log(`✅ Transaktion erfolgreich abgeschlossen`);
                return result;
                
            } catch (error) {
                console.error(`❌ Transaktion fehlgeschlagen, Rollback wird ausgeführt:`, error);
                throw error;
            }
        });
    }
} 