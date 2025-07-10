# Backend-Erweiterungsplan für erweiterte Synchronisation

## Ziel
Erweiterung des bestehenden Node.js/TypeScript GraphQL-Backends zur Unterstützung der erweiterten Sync-Funktionalität aus dem COMPLETE_SYNC_IMPLEMENTATION_PLAN.

## Grundprinzipien
- **Rückwärtskompatibilität**: Bestehende APIs bleiben funktionsfähig
- **Performance**: Optimierte Bulk-Operationen und Batch-Processing
- **Skalierbarkeit**: Effiziente Datenbankabfragen
- **Robustheit**: Umfassende Fehlerbehandlung und Conflict-Resolution

---

## Phase 1: Entity-Erweiterungen (Woche 1)

### Schritt 1.1: Erweiterte Sync-Felder hinzufügen (120 min)

**Alle Entities erweitern um:**
```typescript
// Beispiel: Memory.ts erweitern
@Entity()
export class Memory {
    // ... bestehende Felder ...
    
    // Erweiterte Sync-Felder
    @Field({ nullable: true })
    @Column({ type: "timestamp", nullable: true })
    lastSyncAttempt?: Date;
    
    @Field({ nullable: true })
    @Column({ nullable: true })
    syncErrorMessage?: string;
    
    @Field(() => Int)
    @Column({ default: 0 })
    syncVersion!: number;
    
    @Field()
    @Column({ default: false })
    isDirty!: boolean;
    
    @Field()
    @Column({ default: false })
    needsSync!: boolean;
    
    @Field(() => SyncStatus)
    @Column({ type: "enum", enum: SyncStatus, default: SyncStatus.IN_SYNC })
    syncStatus!: SyncStatus;
    
    @Field(() => SyncPriority)
    @Column({ type: "enum", enum: SyncPriority, default: SyncPriority.NORMAL })
    syncPriority!: SyncPriority;
}
```

**Neue Enums:**
```typescript
// backend/src/entities/SyncStatus.ts
export enum SyncStatus {
    IN_SYNC = "IN_SYNC",
    NEEDS_UPLOAD = "NEEDS_UPLOAD", 
    NEEDS_DOWNLOAD = "NEEDS_DOWNLOAD",
    UPLOADING = "UPLOADING",
    DOWNLOADING = "DOWNLOADING",
    SYNC_ERROR = "SYNC_ERROR",
    FILES_PENDING = "FILES_PENDING",
    CONFLICT = "CONFLICT"
}

// backend/src/entities/SyncPriority.ts
export enum SyncPriority {
    LOW = "LOW",
    NORMAL = "NORMAL",
    HIGH = "HIGH",
    CRITICAL = "CRITICAL"
}
```

**Betroffene Entities:**
- Memory.ts
- Trip.ts  
- MediaItem.ts
- GPXTrack.ts
- Tag.ts
- TagCategory.ts
- BucketListItem.ts

---

### Schritt 1.2: Bulk-Input-Types erweitern (60 min)

**Neue Bulk-Input-Types:**
```typescript
// backend/src/entities/BulkSyncInput.ts
@InputType()
export class BulkSyncInput {
    @Field(() => [BulkMemoryInput])
    memories!: BulkMemoryInput[];
    
    @Field(() => [BulkTripInput])  
    trips!: BulkTripInput[];
    
    @Field(() => [BulkMediaItemInput])
    mediaItems!: BulkMediaItemInput[];
    
    @Field(() => [BulkGPXTrackInput])
    gpxTracks!: BulkGPXTrackInput[];
    
    @Field(() => [BulkTagInput])
    tags!: BulkTagInput[];
    
    @Field(() => [BulkTagCategoryInput])
    tagCategories!: BulkTagCategoryInput[];
    
    @Field(() => [BulkBucketListItemInput])
    bucketListItems!: BulkBucketListItemInput[];
}

@InputType()
export class BulkMemoryInput {
    @Field(() => ID, { nullable: true })
    id?: string;
    
    @Field({ nullable: true })
    title?: string;
    
    @Field({ nullable: true })
    content?: string;
    
    @Field({ nullable: true })
    date?: Date;
    
    @Field(() => ID)
    tripId!: string;
    
    @Field()
    syncVersion!: number;
    
    @Field()
    clientTimestamp!: Date;
    
    @Field(() => SyncOperation)
    operation!: SyncOperation;
}

enum SyncOperation {
    CREATE = "CREATE",
    UPDATE = "UPDATE", 
    DELETE = "DELETE"
}
```

---

## Phase 2: Bulk-Sync-Resolver (Woche 2)

### Schritt 2.1: Erweiterte Sync-Resolver (180 min)

**Neue SyncResolver-Methoden:**
```typescript
// backend/src/resolvers/SyncResolver.ts erweitern
@Resolver()
export class SyncResolver {
    // ... bestehende Methoden ...
    
    @Authorized()
    @Mutation(() => BulkSyncResponse)
    async bulkSync(
        @Arg("input") input: BulkSyncInput,
        @Ctx() { userId }: MyContext
    ): Promise<BulkSyncResponse> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to sync.");
        }
        
        const results = await AppDataSource.transaction(async (manager) => {
            const conflicts: ConflictResult[] = [];
            const successful: SyncResult[] = [];
            const failed: SyncError[] = [];
            
            // Process each entity type
            for (const memory of input.memories) {
                try {
                    const result = await this.processBulkMemory(memory, userId, manager);
                    if (result.hasConflict) {
                        conflicts.push(result.conflict!);
                    } else {
                        successful.push(result.success!);
                    }
                } catch (error) {
                    failed.push({
                        entityType: 'Memory',
                        entityId: memory.id || 'unknown',
                        error: error.message
                    });
                }
            }
            
            // Process other entity types...
            
            return { successful, conflicts, failed };
        });
        
        return {
            ...results,
            serverTimestamp: new Date(),
            processedCount: input.memories.length // + andere counts
        };
    }
    
    @Authorized()
    @Query(() => EnhancedSyncResponse)
    async enhancedSync(
        @Arg("lastSyncedAt", () => Date) lastSyncedAt: Date,
        @Arg("syncPriority", () => SyncPriority, { nullable: true }) syncPriority?: SyncPriority,
        @Arg("entityTypes", () => [String], { nullable: true }) entityTypes?: string[],
        @Arg("batchSize", () => Int, { nullable: true }) batchSize?: number,
        @Ctx() { userId }: MyContext
    ): Promise<EnhancedSyncResponse> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to sync.");
        }
        
        const actualBatchSize = batchSize || 100;
        const actualPriority = syncPriority || SyncPriority.NORMAL;
        
        // Dependency-aware sync order
        const syncOrder = this.getSyncOrder(entityTypes);
        
        const results: EnhancedSyncResponse = {
            trips: [],
            memories: [],
            mediaItems: [],
            gpxTracks: [],
            tags: [],
            tagCategories: [],
            bucketListItems: [],
            deleted: { trips: [], memories: [], mediaItems: [], gpxTracks: [], tags: [], tagCategories: [], bucketListItems: [] },
            conflicts: [],
            serverTimestamp: new Date(),
            hasMore: false,
            nextCursor: null,
            totalCount: 0,
            batchSize: actualBatchSize
        };
        
        for (const entityType of syncOrder) {
            const entities = await this.getEntitiesForSync(
                entityType,
                lastSyncedAt,
                actualPriority,
                actualBatchSize,
                userId
            );
            
            results[entityType.toLowerCase()] = entities;
        }
        
        return results;
    }
    
    private async processBulkMemory(
        memory: BulkMemoryInput,
        userId: string,
        manager: EntityManager
    ): Promise<BulkProcessResult> {
        const memoryRepo = manager.getRepository(Memory);
        
        if (memory.operation === SyncOperation.CREATE) {
            // Create new memory
            const newMemory = memoryRepo.create({
                ...memory,
                creator: { id: userId },
                syncVersion: 1,
                syncStatus: SyncStatus.IN_SYNC
            });
            
            const savedMemory = await memoryRepo.save(newMemory);
            return {
                hasConflict: false,
                success: { entityType: 'Memory', entityId: savedMemory.id, operation: 'CREATE' }
            };
        } else if (memory.operation === SyncOperation.UPDATE) {
            // Update existing memory with conflict detection
            const existingMemory = await memoryRepo.findOne({ 
                where: { id: memory.id },
                relations: ['creator']
            });
            
            if (!existingMemory) {
                throw new Error(`Memory with ID ${memory.id} not found`);
            }
            
            // Conflict detection
            if (existingMemory.syncVersion !== memory.syncVersion) {
                return {
                    hasConflict: true,
                    conflict: {
                        entityType: 'Memory',
                        entityId: memory.id!,
                        localVersion: existingMemory.syncVersion,
                        remoteVersion: memory.syncVersion,
                        localData: existingMemory,
                        remoteData: memory,
                        conflictType: ConflictType.VERSION_MISMATCH
                    }
                };
            }
            
            // No conflict - apply update
            Object.assign(existingMemory, memory);
            existingMemory.syncVersion += 1;
            existingMemory.syncStatus = SyncStatus.IN_SYNC;
            existingMemory.updatedAt = new Date();
            
            await memoryRepo.save(existingMemory);
            return {
                hasConflict: false,
                success: { entityType: 'Memory', entityId: existingMemory.id, operation: 'UPDATE' }
            };
        } else if (memory.operation === SyncOperation.DELETE) {
            // Soft delete
            await memoryRepo.softDelete(memory.id);
            
            // Log deletion
            await manager.save(DeletionLog, {
                entityId: memory.id!,
                entityType: 'Memory',
                ownerId: userId
            });
            
            return {
                hasConflict: false,
                success: { entityType: 'Memory', entityId: memory.id!, operation: 'DELETE' }
            };
        }
        
        throw new Error(`Unknown sync operation: ${memory.operation}`);
    }
    
    private getSyncOrder(entityTypes?: string[]): string[] {
        const defaultOrder = [
            'TagCategory',
            'Tag', 
            'BucketListItem',
            'Trip',
            'Memory',
            'MediaItem',
            'GPXTrack'
        ];
        
        return entityTypes || defaultOrder;
    }
    
    private async getEntitiesForSync(
        entityType: string,
        lastSyncedAt: Date,
        priority: SyncPriority,
        batchSize: number,
        userId: string
    ): Promise<any[]> {
        const repository = AppDataSource.getRepository(entityType);
        
        return await repository.find({
            where: [
                { updatedAt: MoreThan(lastSyncedAt) },
                { syncStatus: Not(SyncStatus.IN_SYNC) },
                { syncPriority: MoreThanOrEqual(priority) }
            ],
            take: batchSize,
            relations: this.getRelationsForEntity(entityType)
        });
    }
    
    private getRelationsForEntity(entityType: string): string[] {
        const relationMap: { [key: string]: string[] } = {
            'Memory': ['trip', 'creator', 'tags', 'mediaItems'],
            'MediaItem': ['memory', 'uploader'],
            'GPXTrack': ['trip', 'creator'],
            'Trip': ['owner', 'members'],
            'Tag': ['category', 'creator'],
            'TagCategory': ['creator'],
            'BucketListItem': ['creator']
        };
        
        return relationMap[entityType] || [];
    }
}
```

---

### Schritt 2.2: Conflict-Resolution-Logik (120 min)

**Neue Conflict-Resolution-Types:**
```typescript
// backend/src/entities/ConflictTypes.ts
export enum ConflictType {
    VERSION_MISMATCH = "VERSION_MISMATCH",
    CONCURRENT_MODIFICATION = "CONCURRENT_MODIFICATION",
    DEPENDENCY_CONFLICT = "DEPENDENCY_CONFLICT",
    DELETION_CONFLICT = "DELETION_CONFLICT"
}

export enum ConflictResolutionStrategy {
    LAST_WRITE_WINS = "LAST_WRITE_WINS",
    FIRST_WRITE_WINS = "FIRST_WRITE_WINS",
    MANUAL_RESOLUTION = "MANUAL_RESOLUTION",
    KEEP_BOTH = "KEEP_BOTH"
}

@ObjectType()
export class ConflictResult {
    @Field()
    entityType!: string;
    
    @Field(() => ID)
    entityId!: string;
    
    @Field(() => ConflictType)
    conflictType!: ConflictType;
    
    @Field(() => Int)
    localVersion!: number;
    
    @Field(() => Int)
    remoteVersion!: number;
    
    @Field(() => String)
    localData!: string; // JSON serialized
    
    @Field(() => String)
    remoteData!: string; // JSON serialized
    
    @Field(() => [String])
    conflictedFields!: string[];
    
    @Field()
    timestamp!: Date;
}

@ObjectType()
export class ConflictResolution {
    @Field(() => ID)
    conflictId!: string;
    
    @Field(() => ConflictResolutionStrategy)
    strategy!: ConflictResolutionStrategy;
    
    @Field(() => String, { nullable: true })
    resolvedData?: string; // JSON serialized
    
    @Field()
    resolvedAt!: Date;
    
    @Field(() => ID)
    resolvedBy!: string; // User ID
}
```

**Conflict-Resolution-Resolver:**
```typescript
// backend/src/resolvers/ConflictResolver.ts
@Resolver()
export class ConflictResolver {
    @Authorized()
    @Mutation(() => ConflictResolution)
    async resolveConflict(
        @Arg("conflictId", () => ID) conflictId: string,
        @Arg("strategy", () => ConflictResolutionStrategy) strategy: ConflictResolutionStrategy,
        @Arg("resolvedData", { nullable: true }) resolvedData?: string,
        @Ctx() { userId }: MyContext
    ): Promise<ConflictResolution> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to resolve conflicts.");
        }
        
        // Implement conflict resolution logic
        const resolution = await this.applyConflictResolution(
            conflictId,
            strategy,
            resolvedData,
            userId
        );
        
        return resolution;
    }
    
    @Authorized()
    @Query(() => [ConflictResult])
    async getConflicts(
        @Arg("entityType", { nullable: true }) entityType?: string,
        @Arg("limit", () => Int, { nullable: true }) limit?: number,
        @Ctx() { userId }: MyContext
    ): Promise<ConflictResult[]> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to view conflicts.");
        }
        
        // Return user's conflicts
        return await this.getUserConflicts(userId, entityType, limit || 20);
    }
    
    private async applyConflictResolution(
        conflictId: string,
        strategy: ConflictResolutionStrategy,
        resolvedData: string | undefined,
        userId: string
    ): Promise<ConflictResolution> {
        // Implement resolution logic based on strategy
        switch (strategy) {
            case ConflictResolutionStrategy.LAST_WRITE_WINS:
                return await this.applyLastWriteWins(conflictId, userId);
            case ConflictResolutionStrategy.FIRST_WRITE_WINS:
                return await this.applyFirstWriteWins(conflictId, userId);
            case ConflictResolutionStrategy.MANUAL_RESOLUTION:
                return await this.applyManualResolution(conflictId, resolvedData!, userId);
            case ConflictResolutionStrategy.KEEP_BOTH:
                return await this.applyKeepBoth(conflictId, userId);
            default:
                throw new Error(`Unknown conflict resolution strategy: ${strategy}`);
        }
    }
    
    // Implementation der verschiedenen Strategien...
}
```

---

## Phase 3: Performance-Optimierungen (Woche 3)

### Schritt 3.1: Batch-Processing-Optimierungen (90 min)

**Optimierte Datenbankabfragen:**
```typescript
// backend/src/utils/BatchProcessor.ts
export class BatchProcessor {
    private readonly BATCH_SIZE = 100;
    
    async processBatch<T>(
        items: T[],
        processor: (batch: T[]) => Promise<void>,
        batchSize: number = this.BATCH_SIZE
    ): Promise<void> {
        for (let i = 0; i < items.length; i += batchSize) {
            const batch = items.slice(i, i + batchSize);
            await processor(batch);
        }
    }
    
    async bulkInsert<T>(
        repository: Repository<T>,
        entities: T[],
        batchSize: number = this.BATCH_SIZE
    ): Promise<T[]> {
        const results: T[] = [];
        
        await this.processBatch(entities, async (batch) => {
            const inserted = await repository.save(batch);
            results.push(...inserted);
        }, batchSize);
        
        return results;
    }
    
    async bulkUpdate<T>(
        repository: Repository<T>,
        updates: Partial<T>[],
        batchSize: number = this.BATCH_SIZE
    ): Promise<void> {
        await this.processBatch(updates, async (batch) => {
            await repository.save(batch);
        }, batchSize);
    }
}
```

### Schritt 3.2: Caching-Layer (60 min)

**Redis-Cache-Implementation:**
```typescript
// backend/src/utils/cache.ts
import Redis from 'ioredis';

export class SyncCache {
    private redis: Redis;
    private readonly TTL = 3600; // 1 hour
    
    constructor() {
        this.redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');
    }
    
    async get<T>(key: string): Promise<T | null> {
        const cached = await this.redis.get(key);
        return cached ? JSON.parse(cached) : null;
    }
    
    async set<T>(key: string, value: T, ttl: number = this.TTL): Promise<void> {
        await this.redis.setex(key, ttl, JSON.stringify(value));
    }
    
    async invalidate(pattern: string): Promise<void> {
        const keys = await this.redis.keys(pattern);
        if (keys.length > 0) {
            await this.redis.del(...keys);
        }
    }
    
    getSyncKey(userId: string, entityType: string): string {
        return `sync:${userId}:${entityType}`;
    }
    
    getEntityKey(entityType: string, entityId: string): string {
        return `entity:${entityType}:${entityId}`;
    }
}
```

---

## Phase 4: Monitoring & Logging (Woche 4)

### Schritt 4.1: Erweiterte Logging-Infrastruktur (60 min)

**Structured Logging:**
```typescript
// backend/src/utils/logger.ts
import winston from 'winston';

export class SyncLogger {
    private logger: winston.Logger;
    
    constructor() {
        this.logger = winston.createLogger({
            level: 'info',
            format: winston.format.combine(
                winston.format.timestamp(),
                winston.format.errors({ stack: true }),
                winston.format.json()
            ),
            transports: [
                new winston.transports.File({ filename: 'sync-error.log', level: 'error' }),
                new winston.transports.File({ filename: 'sync-combined.log' }),
                new winston.transports.Console({
                    format: winston.format.simple()
                })
            ]
        });
    }
    
    logSyncStart(userId: string, entityType: string, operation: string): void {
        this.logger.info('Sync operation started', {
            userId,
            entityType,
            operation,
            timestamp: new Date().toISOString()
        });
    }
    
    logSyncSuccess(userId: string, entityType: string, operation: string, duration: number): void {
        this.logger.info('Sync operation completed', {
            userId,
            entityType,
            operation,
            duration,
            timestamp: new Date().toISOString()
        });
    }
    
    logSyncError(userId: string, entityType: string, operation: string, error: Error): void {
        this.logger.error('Sync operation failed', {
            userId,
            entityType,
            operation,
            error: error.message,
            stack: error.stack,
            timestamp: new Date().toISOString()
        });
    }
    
    logConflict(userId: string, entityType: string, entityId: string, conflictType: ConflictType): void {
        this.logger.warn('Sync conflict detected', {
            userId,
            entityType,
            entityId,
            conflictType,
            timestamp: new Date().toISOString()
        });
    }
}
```

### Schritt 4.2: Performance-Monitoring (45 min)

**Sync-Metriken:**
```typescript
// backend/src/utils/metrics.ts
export class SyncMetrics {
    private metrics: Map<string, number> = new Map();
    
    recordSyncDuration(operation: string, duration: number): void {
        const key = `sync_duration_${operation}`;
        this.metrics.set(key, duration);
    }
    
    recordEntityCount(entityType: string, count: number): void {
        const key = `entity_count_${entityType}`;
        this.metrics.set(key, count);
    }
    
    recordConflictCount(entityType: string, count: number): void {
        const key = `conflict_count_${entityType}`;
        this.metrics.set(key, count);
    }
    
    getMetrics(): { [key: string]: number } {
        return Object.fromEntries(this.metrics);
    }
    
    reset(): void {
        this.metrics.clear();
    }
}
```

---

## Phase 5: Testing & Validierung (Woche 5)

### Schritt 5.1: Unit-Tests für Sync-Logik (120 min)

**Sync-Resolver-Tests:**
```typescript
// backend/src/tests/SyncResolver.test.ts
describe('SyncResolver', () => {
    let resolver: SyncResolver;
    let mockContext: MyContext;
    
    beforeEach(() => {
        resolver = new SyncResolver();
        mockContext = { userId: 'test-user-id' };
    });
    
    describe('bulkSync', () => {
        it('should process bulk memory updates successfully', async () => {
            const input: BulkSyncInput = {
                memories: [{
                    id: 'memory-1',
                    title: 'Updated Memory',
                    content: 'Updated content',
                    syncVersion: 1,
                    clientTimestamp: new Date(),
                    operation: SyncOperation.UPDATE,
                    tripId: 'trip-1'
                }],
                trips: [],
                mediaItems: [],
                gpxTracks: [],
                tags: [],
                tagCategories: [],
                bucketListItems: []
            };
            
            const result = await resolver.bulkSync(input, mockContext);
            
            expect(result.successful).toHaveLength(1);
            expect(result.conflicts).toHaveLength(0);
            expect(result.failed).toHaveLength(0);
        });
        
        it('should detect version conflicts', async () => {
            // Test conflict detection logic
        });
        
        it('should handle dependency violations', async () => {
            // Test dependency validation
        });
    });
    
    describe('enhancedSync', () => {
        it('should return entities in correct dependency order', async () => {
            // Test dependency-aware sync order
        });
        
        it('should respect batch size limits', async () => {
            // Test batch size handling
        });
    });
});
```

### Schritt 5.2: Integration-Tests (90 min)

**End-to-End-Sync-Tests:**
```typescript
// backend/src/tests/SyncIntegration.test.ts
describe('Sync Integration', () => {
    it('should complete full sync cycle without conflicts', async () => {
        // Test complete sync workflow
    });
    
    it('should handle concurrent modifications gracefully', async () => {
        // Test concurrent access scenarios
    });
    
    it('should maintain data integrity during conflicts', async () => {
        // Test conflict resolution maintains consistency
    });
});
```

---

## Deployment-Strategie

### Database-Migrationen
```typescript
// backend/src/migrations/AddSyncFields.ts
export class AddSyncFields1234567890 implements MigrationInterface {
    public async up(queryRunner: QueryRunner): Promise<void> {
        // Add sync fields to all entities
        await queryRunner.addColumn('memory', new TableColumn({
            name: 'lastSyncAttempt',
            type: 'timestamp',
            isNullable: true
        }));
        
        await queryRunner.addColumn('memory', new TableColumn({
            name: 'syncErrorMessage',
            type: 'varchar',
            isNullable: true
        }));
        
        // Add other sync fields...
    }
    
    public async down(queryRunner: QueryRunner): Promise<void> {
        // Reverse migrations
    }
}
```

### Environment-Variablen
```env
# .env
REDIS_URL=redis://localhost:6379
SYNC_BATCH_SIZE=100
SYNC_CACHE_TTL=3600
CONFLICT_RESOLUTION_STRATEGY=LAST_WRITE_WINS
```

---

## Erfolgs-Metriken

1. **Performance**: 
   - Bulk-Sync von 1000 Entities in < 5 Sekunden
   - Conflict-Resolution in < 1 Sekunde
   - Memory-Usage stabil bei < 500MB

2. **Robustheit**:
   - 99.9% Sync-Erfolgsrate
   - Automatische Conflict-Resolution in 95% der Fälle
   - Zero-Downtime-Deployments

3. **Skalierbarkeit**:
   - Unterstützung für 10.000+ gleichzeitige Sync-Operationen
   - Horizontale Skalierung mit Redis-Clustering
   - Optimized Database-Queries mit < 100ms Response-Time

---

*Dieser Plan gewährleistet eine vollständige Backend-Erweiterung zur Unterstützung der erweiterten iOS-Sync-Funktionalität.* 