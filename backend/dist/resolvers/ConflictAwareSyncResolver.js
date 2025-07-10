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
exports.ConflictAwareSyncResolver = void 0;
const type_graphql_1 = require("type-graphql");
const type_graphql_2 = require("type-graphql");
const database_1 = require("../utils/database");
const ConflictResolver_1 = require("./ConflictResolver");
const OptimizedSyncResolver_1 = require("./OptimizedSyncResolver");
const Trip_1 = require("../entities/Trip");
const Memory_1 = require("../entities/Memory");
const MediaItem_1 = require("../entities/MediaItem");
const Tag_1 = require("../entities/Tag");
const TagCategory_1 = require("../entities/TagCategory");
const BucketListItem_1 = require("../entities/BucketListItem");
const GPXTrack_1 = require("../entities/GPXTrack");
let ConflictAwareSyncResolver = class ConflictAwareSyncResolver extends OptimizedSyncResolver_1.OptimizedSyncResolver {
    constructor() {
        super();
        this.conflictResolver = new ConflictResolver_1.BackendConflictResolver();
    }
    async conflictAwareSync({ userId }, operationsJson, deviceId, strategy) {
        if (!userId) {
            throw new Error("User not authenticated");
        }
        const operations = JSON.parse(operationsJson);
        const conflicts = [];
        const resolved = [];
        const failed = [];
        console.log(`🔄 Starting conflict-aware sync: ${operations.length} operations for device ${deviceId}`);
        for (const operation of operations) {
            try {
                const entityId = operation.data.id || operation.data.serverId;
                if (!entityId) {
                    throw new Error(`No entity ID found for ${operation.entityType}`);
                }
                const existingEntity = await this.findExistingEntity(operation.entityType, entityId, userId);
                if (existingEntity && await this.hasConflict(existingEntity, operation.data)) {
                    console.log(`⚠️ Conflict detected for ${operation.entityType}:${entityId}`);
                    const resolutionOptions = {
                        strategy: strategy || 'lastWriteWins',
                        deviceId,
                        userId
                    };
                    const resolution = await this.conflictResolver.resolveConflict(operation.entityType, existingEntity, operation.data, resolutionOptions);
                    conflicts.push({
                        conflictId: resolution.conflictId,
                        entityType: operation.entityType,
                        entityId: entityId,
                        resolution: resolution.metadata,
                        strategy: resolution.strategy
                    });
                    // Speichere aufgelöste Entität
                    const saved = await this.saveResolvedEntity(operation.entityType, resolution.resolvedEntity, userId);
                    resolved.push({
                        id: operation.id,
                        status: 'resolved',
                        data: saved,
                        conflictId: resolution.conflictId,
                        entityType: operation.entityType
                    });
                }
                else {
                    // Keine Konflikte - normale Verarbeitung
                    console.log(`✅ No conflict for ${operation.entityType}:${entityId} - processing normally`);
                    const result = await this.processNormalOperation(operation, userId);
                    resolved.push(result);
                }
            }
            catch (error) {
                console.error(`❌ Failed to process operation ${operation.id}:`, error);
                failed.push({
                    id: operation.id,
                    error: error instanceof Error ? error.message : 'Unknown error',
                    entityType: operation.entityType,
                    entityId: operation.data.id || 'unknown'
                });
            }
        }
        const response = {
            resolved,
            conflicts,
            failed,
            totalProcessed: operations.length
        };
        console.log(`🎯 Conflict-aware sync completed: ${resolved.length} resolved, ${conflicts.length} conflicts, ${failed.length} failed`);
        return JSON.stringify(response);
    }
    async getConflictResolutionMetrics({ userId }, timeframe) {
        if (!userId) {
            throw new Error("User not authenticated");
        }
        const conflictLogRepo = database_1.AppDataSource.getRepository('ConflictLog');
        // Berechne Zeitfenster
        const timeframeHours = this.parseTimeframe(timeframe);
        const cutoffDate = new Date();
        cutoffDate.setHours(cutoffDate.getHours() - timeframeHours);
        const totalConflicts = await conflictLogRepo.count({
            where: {
                timestamp: { $gte: cutoffDate }
            }
        });
        const resolvedConflicts = await conflictLogRepo.count({
            where: {
                timestamp: { $gte: cutoffDate },
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
    async findExistingEntity(entityType, entityId, userId) {
        let repository;
        switch (entityType.toLowerCase()) {
            case 'trip':
                repository = database_1.AppDataSource.getRepository(Trip_1.Trip);
                break;
            case 'memory':
                repository = database_1.AppDataSource.getRepository(Memory_1.Memory);
                break;
            case 'mediaitem':
                repository = database_1.AppDataSource.getRepository(MediaItem_1.MediaItem);
                break;
            case 'tag':
                repository = database_1.AppDataSource.getRepository(Tag_1.Tag);
                break;
            case 'tagcategory':
                repository = database_1.AppDataSource.getRepository(TagCategory_1.TagCategory);
                break;
            case 'bucketlistitem':
                repository = database_1.AppDataSource.getRepository(BucketListItem_1.BucketListItem);
                break;
            case 'gpxtrack':
                repository = database_1.AppDataSource.getRepository(GPXTrack_1.GPXTrack);
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
    async hasConflict(existingEntity, incomingData) {
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
    hasContentDifferences(existing, incoming) {
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
    async saveResolvedEntity(entityType, resolvedEntity, userId) {
        let repository;
        switch (entityType.toLowerCase()) {
            case 'trip':
                repository = database_1.AppDataSource.getRepository(Trip_1.Trip);
                break;
            case 'memory':
                repository = database_1.AppDataSource.getRepository(Memory_1.Memory);
                break;
            case 'mediaitem':
                repository = database_1.AppDataSource.getRepository(MediaItem_1.MediaItem);
                break;
            case 'tag':
                repository = database_1.AppDataSource.getRepository(Tag_1.Tag);
                break;
            case 'tagcategory':
                repository = database_1.AppDataSource.getRepository(TagCategory_1.TagCategory);
                break;
            case 'bucketlistitem':
                repository = database_1.AppDataSource.getRepository(BucketListItem_1.BucketListItem);
                break;
            case 'gpxtrack':
                repository = database_1.AppDataSource.getRepository(GPXTrack_1.GPXTrack);
                break;
            default:
                throw new Error(`Unknown entity type: ${entityType}`);
        }
        // Setze updatedAt auf aktuelle Zeit
        resolvedEntity.updatedAt = new Date();
        return await repository.save(resolvedEntity);
    }
    async processNormalOperation(operation, userId) {
        try {
            let result;
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
                    }
                    catch {
                        result = await this.createEntity(operation.entityType, operation.data, userId);
                    }
            }
            return {
                id: operation.id,
                status: 'success',
                data: result,
                entityType: operation.entityType
            };
        }
        catch (error) {
            throw new Error(`Failed to process ${operation.operation} for ${operation.entityType}: ${error instanceof Error ? error.message : 'Unknown error'}`);
        }
    }
    async createEntity(entityType, data, userId) {
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
    async updateEntity(entityType, data, userId) {
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
    async deleteEntity(entityType, entityId, userId) {
        const repository = this.getRepositoryForEntityType(entityType);
        const result = await repository.delete({ id: entityId });
        return {
            id: entityId,
            deleted: result.affected ? result.affected > 0 : false
        };
    }
    getRepositoryForEntityType(entityType) {
        switch (entityType.toLowerCase()) {
            case 'trip':
                return database_1.AppDataSource.getRepository(Trip_1.Trip);
            case 'memory':
                return database_1.AppDataSource.getRepository(Memory_1.Memory);
            case 'mediaitem':
                return database_1.AppDataSource.getRepository(MediaItem_1.MediaItem);
            case 'tag':
                return database_1.AppDataSource.getRepository(Tag_1.Tag);
            case 'tagcategory':
                return database_1.AppDataSource.getRepository(TagCategory_1.TagCategory);
            case 'bucketlistitem':
                return database_1.AppDataSource.getRepository(BucketListItem_1.BucketListItem);
            case 'gpxtrack':
                return database_1.AppDataSource.getRepository(GPXTrack_1.GPXTrack);
            default:
                throw new Error(`Unknown entity type: ${entityType}`);
        }
    }
    parseTimeframe(timeframe) {
        const match = timeframe.match(/^(\d+)([hdw])$/);
        if (!match)
            return 24; // Default 24 Stunden
        const value = parseInt(match[1]);
        const unit = match[2];
        switch (unit) {
            case 'h': return value;
            case 'd': return value * 24;
            case 'w': return value * 24 * 7;
            default: return 24;
        }
    }
};
exports.ConflictAwareSyncResolver = ConflictAwareSyncResolver;
__decorate([
    (0, type_graphql_2.Authorized)(),
    (0, type_graphql_1.Mutation)(() => String) // Vereinfachter Return-Type für GraphQL
    ,
    __param(0, (0, type_graphql_1.Ctx)()),
    __param(1, (0, type_graphql_1.Arg)("operations", () => String)),
    __param(2, (0, type_graphql_1.Arg)("deviceId")),
    __param(3, (0, type_graphql_1.Arg)("strategy", { nullable: true })),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String, String]),
    __metadata("design:returntype", Promise)
], ConflictAwareSyncResolver.prototype, "conflictAwareSync", null);
__decorate([
    (0, type_graphql_2.Authorized)(),
    (0, type_graphql_1.Query)(() => String),
    __param(0, (0, type_graphql_1.Ctx)()),
    __param(1, (0, type_graphql_1.Arg)("timeframe", { nullable: true, defaultValue: "24h" })),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], ConflictAwareSyncResolver.prototype, "getConflictResolutionMetrics", null);
exports.ConflictAwareSyncResolver = ConflictAwareSyncResolver = __decorate([
    (0, type_graphql_1.Resolver)(),
    __metadata("design:paramtypes", [])
], ConflictAwareSyncResolver);
