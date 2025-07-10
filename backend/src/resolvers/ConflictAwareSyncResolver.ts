import { Resolver, Mutation, Arg, Ctx, Query } from 'type-graphql';
import { Authorized } from 'type-graphql';
import { AppDataSource } from '../utils/database';
import { MyContext } from '../index';
import { 
    ConflictAwareSyncResponse,
    ConflictInfo,
    FailedOperation,
    SyncOperation,
    SyncResult,
    ConflictResolutionStrategy,
    ConflictResolutionOptions
} from '../types/ConflictTypes';
import { BackendConflictResolver } from './ConflictResolver';
import { OptimizedSyncResolver } from './OptimizedSyncResolver';
import { Trip } from '../entities/Trip';
import { Memory } from '../entities/Memory';
import { MediaItem } from '../entities/MediaItem';
import { Tag } from '../entities/Tag';
import { TagCategory } from '../entities/TagCategory';
import { BucketListItem } from '../entities/BucketListItem';
import { GPXTrack } from '../entities/GPXTrack';

@Resolver()
export class ConflictAwareSyncResolver extends OptimizedSyncResolver {
    private readonly conflictResolver: BackendConflictResolver;
    
    constructor() {
        super();
        this.conflictResolver = new BackendConflictResolver();
    }
    
    @Authorized()
    @Mutation(() => String) // Vereinfachter Return-Type für GraphQL
    async conflictAwareSync(
        @Ctx() { userId }: MyContext,
        @Arg("operations", () => String) operationsJson: string,
        @Arg("deviceId") deviceId: string,
        @Arg("strategy", { nullable: true }) strategy?: ConflictResolutionStrategy
    ): Promise<string> {
        if (!userId) {
            throw new Error("User not authenticated");
        }
        const operations: SyncOperation[] = JSON.parse(operationsJson);
        const conflicts: ConflictInfo[] = [];
        const resolved: SyncResult[] = [];
        const failed: FailedOperation[] = [];
        
        console.log(`🔄 Starting conflict-aware sync: ${operations.length} operations for device ${deviceId}`);
        
        for (const operation of operations) {
            try {
                const entityId = operation.data.id || operation.data.serverId;
                if (!entityId) {
                    throw new Error(`No entity ID found for ${operation.entityType}`);
                }
                
                const existingEntity = await this.findExistingEntity(
                    operation.entityType,
                    entityId,
                    userId
                );
                
                if (existingEntity && await this.hasConflict(existingEntity, operation.data)) {
                    console.log(`⚠️ Conflict detected for ${operation.entityType}:${entityId}`);
                    
                    const resolutionOptions: ConflictResolutionOptions = {
                        strategy: strategy || 'lastWriteWins',
                        deviceId,
                        userId
                    };
                    
                    const resolution = await this.conflictResolver.resolveConflict(
                        operation.entityType,
                        existingEntity,
                        operation.data,
                        resolutionOptions
                    );
                    
                    conflicts.push({
                        conflictId: resolution.conflictId,
                        entityType: operation.entityType,
                        entityId: entityId,
                        resolution: resolution.metadata,
                        strategy: resolution.strategy
                    });
                    
                    // Speichere aufgelöste Entität
                    const saved = await this.saveResolvedEntity(
                        operation.entityType,
                        resolution.resolvedEntity,
                        userId
                    );
                    
                    resolved.push({
                        id: operation.id,
                        status: 'resolved',
                        data: saved,
                        conflictId: resolution.conflictId,
                        entityType: operation.entityType
                    });
                } else {
                    // Keine Konflikte - normale Verarbeitung
                    console.log(`✅ No conflict for ${operation.entityType}:${entityId} - processing normally`);
                    
                    const result = await this.processNormalOperation(operation, userId);
                    resolved.push(result);
                }
            } catch (error) {
                console.error(`❌ Failed to process operation ${operation.id}:`, error);
                
                failed.push({
                    id: operation.id,
                    error: error instanceof Error ? error.message : 'Unknown error',
                    entityType: operation.entityType,
                    entityId: operation.data.id || 'unknown'
                });
            }
        }
        
        const response: ConflictAwareSyncResponse = {
            resolved,
            conflicts,
            failed,
            totalProcessed: operations.length
        };
        
        console.log(`🎯 Conflict-aware sync completed: ${resolved.length} resolved, ${conflicts.length} conflicts, ${failed.length} failed`);
        
        return JSON.stringify(response);
    }
    
    @Authorized()
    @Query(() => String)
    async getConflictResolutionMetrics(
        @Ctx() { userId }: MyContext,
        @Arg("timeframe", { nullable: true, defaultValue: "24h" }) timeframe: string
    ): Promise<string> {
        if (!userId) {
            throw new Error("User not authenticated");
        }
        const conflictLogRepo = AppDataSource.getRepository('ConflictLog');
        
        // Berechne Zeitfenster
        const timeframeHours = this.parseTimeframe(timeframe);
        const cutoffDate = new Date();
        cutoffDate.setHours(cutoffDate.getHours() - timeframeHours);
        
        const totalConflicts = await conflictLogRepo.count({
            where: {
                timestamp: { $gte: cutoffDate } as any
            }
        });
        
        const resolvedConflicts = await conflictLogRepo.count({
            where: {
                timestamp: { $gte: cutoffDate } as any,
                status: 'resolved'
            }
        });
        
        const pendingConflicts = totalConflicts - resolvedConflicts;
        
        const metrics = {
            totalConflicts,
            resolvedConflicts,
            pendingConflicts,
            resolutionRate: totalConflicts > 0 ? resolvedConflicts / totalConflicts : 0,
            timeframe
        };
        
        return JSON.stringify(metrics);
    }
    
    // Private Hilfsmethoden
    private async findExistingEntity(
        entityType: string,
        entityId: string,
        userId: string
    ): Promise<any | null> {
        let repository: any;
        
        switch (entityType.toLowerCase()) {
            case 'trip':
                repository = AppDataSource.getRepository(Trip);
                break;
            case 'memory':
                repository = AppDataSource.getRepository(Memory);
                break;
            case 'mediaitem':
                repository = AppDataSource.getRepository(MediaItem);
                break;
            case 'tag':
                repository = AppDataSource.getRepository(Tag);
                break;
            case 'tagcategory':
                repository = AppDataSource.getRepository(TagCategory);
                break;
            case 'bucketlistitem':
                repository = AppDataSource.getRepository(BucketListItem);
                break;
            case 'gpxtrack':
                repository = AppDataSource.getRepository(GPXTrack);
                break;
            default:
                throw new Error(`Unknown entity type: ${entityType}`);
        }
        
        // Versuche zuerst über serverId
        let entity = await repository.findOne({
            where: { serverId: entityId }
        });
        
        // Falls nicht gefunden, versuche über id
        if (!entity) {
            entity = await repository.findOne({
                where: { id: entityId }
            });
        }
        
        return entity;
    }
    
    private async hasConflict(existingEntity: any, incomingData: any): Promise<boolean> {
        const existingTimestamp = existingEntity.updatedAt || existingEntity.createdAt;
        const incomingTimestamp = incomingData.updatedAt || incomingData.createdAt;
        
        if (!existingTimestamp || !incomingTimestamp) {
            return false; // Keine Zeitstempel = kein Konflikt
        }
        
        // Parse Zeitstempel falls nötig
        const existingDate = existingTimestamp instanceof Date ? existingTimestamp : new Date(existingTimestamp);
        const incomingDate = incomingTimestamp instanceof Date ? incomingTimestamp : new Date(incomingTimestamp);
        
        // Konflikt wenn beide in letzten 5 Minuten geändert wurden und unterschiedlich sind
        const timeDiff = Math.abs(existingDate.getTime() - incomingDate.getTime());
        const hasRecentChanges = timeDiff < 5 * 60 * 1000; // 5 Minuten in ms
        
        // Prüfe ob Inhalte unterschiedlich sind
        const hasContentDifferences = this.hasContentDifferences(existingEntity, incomingData);
        
        return hasRecentChanges && hasContentDifferences;
    }
    
    private hasContentDifferences(existing: any, incoming: any): boolean {
        const importantFields = ['title', 'description', 'content', 'name', 'value'];
        
        for (const field of importantFields) {
            if (existing[field] !== undefined && incoming[field] !== undefined) {
                if (existing[field] !== incoming[field]) {
                    return true;
                }
            }
        }
        
        return false;
    }
    
    private async saveResolvedEntity(
        entityType: string,
        resolvedEntity: any,
        userId: string
    ): Promise<any> {
        let repository: any;
        
        switch (entityType.toLowerCase()) {
            case 'trip':
                repository = AppDataSource.getRepository(Trip);
                break;
            case 'memory':
                repository = AppDataSource.getRepository(Memory);
                break;
            case 'mediaitem':
                repository = AppDataSource.getRepository(MediaItem);
                break;
            case 'tag':
                repository = AppDataSource.getRepository(Tag);
                break;
            case 'tagcategory':
                repository = AppDataSource.getRepository(TagCategory);
                break;
            case 'bucketlistitem':
                repository = AppDataSource.getRepository(BucketListItem);
                break;
            case 'gpxtrack':
                repository = AppDataSource.getRepository(GPXTrack);
                break;
            default:
                throw new Error(`Unknown entity type: ${entityType}`);
        }
        
        // Setze updatedAt auf aktuelle Zeit
        resolvedEntity.updatedAt = new Date();
        
        return await repository.save(resolvedEntity);
    }
    
    private async processNormalOperation(operation: SyncOperation, userId: string): Promise<SyncResult> {
        try {
            let result: any;
            
            switch (operation.operation) {
                case 'CREATE':
                    result = await this.createEntity(operation.entityType, operation.data, userId);
                    break;
                case 'UPDATE':
                    result = await this.updateEntity(operation.entityType, operation.data, userId);
                    break;
                case 'DELETE':
                    result = await this.deleteEntity(operation.entityType, operation.data.id, userId);
                    break;
                default:
                    // Fallback: Versuche Update, dann Create
                    try {
                        result = await this.updateEntity(operation.entityType, operation.data, userId);
                    } catch {
                        result = await this.createEntity(operation.entityType, operation.data, userId);
                    }
            }
            
            return {
                id: operation.id,
                status: 'success',
                data: result,
                entityType: operation.entityType
            };
        } catch (error) {
            throw new Error(`Failed to process ${operation.operation} for ${operation.entityType}: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
    }
    
    private async createEntity(entityType: string, data: any, userId: string): Promise<any> {
        const repository = this.getRepositoryForEntityType(entityType);
        
        // Setze userId und Zeitstempel
        const entityData = {
            ...data,
            userId: userId,
            createdAt: new Date(),
            updatedAt: new Date()
        };
        
        const entity = repository.create(entityData);
        return await repository.save(entity);
    }
    
    private async updateEntity(entityType: string, data: any, userId: string): Promise<any> {
        const repository = this.getRepositoryForEntityType(entityType);
        
        const existing = await repository.findOne({
            where: { id: data.id }
        });
        
        if (!existing) {
            throw new Error(`Entity not found: ${entityType}:${data.id}`);
        }
        
        // Update mit neuen Daten
        const updated = {
            ...existing,
            ...data,
            updatedAt: new Date()
        };
        
        return await repository.save(updated);
    }
    
    private async deleteEntity(entityType: string, entityId: string, userId: string): Promise<any> {
        const repository = this.getRepositoryForEntityType(entityType);
        
        const result = await repository.delete({ id: entityId });
        
        return {
            id: entityId,
            deleted: result.affected ? result.affected > 0 : false
        };
    }
    
    private getRepositoryForEntityType(entityType: string): any {
        switch (entityType.toLowerCase()) {
            case 'trip':
                return AppDataSource.getRepository(Trip);
            case 'memory':
                return AppDataSource.getRepository(Memory);
            case 'mediaitem':
                return AppDataSource.getRepository(MediaItem);
            case 'tag':
                return AppDataSource.getRepository(Tag);
            case 'tagcategory':
                return AppDataSource.getRepository(TagCategory);
            case 'bucketlistitem':
                return AppDataSource.getRepository(BucketListItem);
            case 'gpxtrack':
                return AppDataSource.getRepository(GPXTrack);
            default:
                throw new Error(`Unknown entity type: ${entityType}`);
        }
    }
    
    private parseTimeframe(timeframe: string): number {
        const match = timeframe.match(/^(\d+)([hdw])$/);
        if (!match) return 24; // Default 24 Stunden
        
        const value = parseInt(match[1]);
        const unit = match[2];
        
        switch (unit) {
            case 'h': return value;
            case 'd': return value * 24;
            case 'w': return value * 24 * 7;
            default: return 24;
        }
    }
} 