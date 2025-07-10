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
exports.QueryComplexityAnalyzer = exports.OptimizedSyncResolver = void 0;
const type_graphql_1 = require("type-graphql");
const typedi_1 = require("typedi");
const typeorm_1 = require("typeorm");
const Trip_1 = require("../entities/Trip");
const Memory_1 = require("../entities/Memory");
const MediaItem_1 = require("../entities/MediaItem");
const GPXTrack_1 = require("../entities/GPXTrack");
const Tag_1 = require("../entities/Tag");
// Temporäre Cache-Implementierung (bis RedisCacheManager verfügbar ist)
class SimpleCacheManager {
    constructor() {
        this.cache = new Map();
    }
    async smartCache(key, fetchFunction, ttl = 300) {
        const cached = this.cache.get(key);
        if (cached && Date.now() < cached.expiry) {
            return cached.data;
        }
        const data = await fetchFunction();
        this.cache.set(key, {
            data,
            expiry: Date.now() + ttl * 1000
        });
        return data;
    }
    async invalidateCache(pattern) {
        for (const key of this.cache.keys()) {
            if (key.includes(pattern.replace('*', ''))) {
                this.cache.delete(key);
            }
        }
    }
}
class OptimizedSyncResponse {
    constructor(data) {
        this.trips = data.trips || [];
        this.memories = data.memories || [];
        this.mediaItems = data.mediaItems || [];
        this.gpxTracks = data.gpxTracks || [];
        this.tags = data.tags || [];
        this.timestamp = data.timestamp || new Date();
        this.totalCount = data.totalCount || 0;
    }
}
let OptimizedSyncResolver = class OptimizedSyncResolver {
    constructor() {
        this.cacheManager = new SimpleCacheManager();
        this.tripRepository = (0, typeorm_1.getRepository)(Trip_1.Trip);
        this.memoryRepository = (0, typeorm_1.getRepository)(Memory_1.Memory);
        this.mediaItemRepository = (0, typeorm_1.getRepository)(MediaItem_1.MediaItem);
        this.gpxTrackRepository = (0, typeorm_1.getRepository)(GPXTrack_1.GPXTrack);
        this.tagRepository = (0, typeorm_1.getRepository)(Tag_1.Tag);
    }
    async optimizedSync(userId, lastSync, limit = 1000, context) {
        const syncTimestamp = new Date();
        const cacheKey = `sync:${userId}:${lastSync?.getTime() || 0}:${limit}`;
        return await this.cacheManager.smartCache(cacheKey, async () => {
            const results = await this.performOptimizedSync(userId, lastSync, limit);
            return new OptimizedSyncResponse({
                ...results,
                timestamp: syncTimestamp,
                totalCount: results.trips.length + results.memories.length +
                    results.mediaItems.length + results.gpxTracks.length + results.tags.length
            });
        }, 60 // 1 Minute Cache
        );
    }
    async tripsOptimized(userId, limit = 50, offset = 0) {
        const cacheKey = `trips:${userId}:${limit}:${offset}`;
        return await this.cacheManager.smartCache(cacheKey, async () => {
            const queryBuilder = this.tripRepository.createQueryBuilder('trip')
                .where('trip.userId = :userId', { userId })
                .orderBy('trip.createdAt', 'DESC')
                .limit(limit)
                .offset(offset);
            return await queryBuilder.getMany();
        }, 300 // 5 Minuten Cache
        );
    }
    async performOptimizedSync(userId, lastSync, limit = 1000) {
        const connection = (0, typeorm_1.getConnection)();
        // Verwende optimierte Raw-Query für bessere Performance
        const entities = await this.buildOptimizedSyncQuery(userId, lastSync, limit);
        // Separiere Entities nach Typ
        const trips = [];
        const memories = [];
        const mediaItems = [];
        const gpxTracks = [];
        const tags = [];
        // Lade komplette Entities basierend auf IDs
        const tripIds = entities.filter(e => e.entity_type === 'trip').map(e => e.id);
        const memoryIds = entities.filter(e => e.entity_type === 'memory').map(e => e.id);
        const mediaItemIds = entities.filter(e => e.entity_type === 'media_item').map(e => e.id);
        const gpxTrackIds = entities.filter(e => e.entity_type === 'gpx_track').map(e => e.id);
        const tagIds = entities.filter(e => e.entity_type === 'tag').map(e => e.id);
        // Parallel-Laden für bessere Performance
        const [loadedTrips, loadedMemories, loadedMediaItems, loadedTracks, loadedTags] = await Promise.all([
            tripIds.length > 0 ? this.tripRepository.findByIds(tripIds) : Promise.resolve([]),
            memoryIds.length > 0 ? this.memoryRepository.findByIds(memoryIds) : Promise.resolve([]),
            mediaItemIds.length > 0 ? this.mediaItemRepository.findByIds(mediaItemIds) : Promise.resolve([]),
            gpxTrackIds.length > 0 ? this.gpxTrackRepository.findByIds(gpxTrackIds) : Promise.resolve([]),
            tagIds.length > 0 ? this.tagRepository.findByIds(tagIds) : Promise.resolve([])
        ]);
        return {
            trips: loadedTrips,
            memories: loadedMemories,
            mediaItems: loadedMediaItems,
            gpxTracks: loadedTracks,
            tags: loadedTags
        };
    }
    async buildOptimizedSyncQuery(userId, lastSync, limit = 1000) {
        const connection = (0, typeorm_1.getConnection)();
        const params = [userId];
        // Baue WHERE-Bedingungen
        const syncCondition = lastSync ?
            `AND updated_at > $${params.length + 1}` : '';
        if (lastSync)
            params.push(lastSync);
        // Optimierte Union-Query für PostgreSQL
        const query = `
            SELECT 
                'trip' as entity_type,
                id,
                created_at,
                updated_at
            FROM trips 
            WHERE user_id = $1 
            ${syncCondition}
            
            UNION ALL
            
            SELECT 
                'memory' as entity_type,
                m.id,
                m.created_at,
                m.updated_at
            FROM memories m
            JOIN trips t ON m.trip_id = t.id
            WHERE t.user_id = $1 
            ${syncCondition.replace('updated_at', 'm.updated_at')}
            
            UNION ALL
            
            SELECT 
                'media_item' as entity_type,
                mi.id,
                mi.created_at,
                mi.updated_at
            FROM media_items mi
            JOIN memories m ON mi.memory_id = m.id
            JOIN trips t ON m.trip_id = t.id
            WHERE t.user_id = $1 
            ${syncCondition.replace('updated_at', 'mi.updated_at')}
            
            UNION ALL
            
            SELECT 
                'gpx_track' as entity_type,
                gt.id,
                gt.created_at,
                gt.updated_at
            FROM gpx_tracks gt
            JOIN memories m ON gt.memory_id = m.id
            JOIN trips t ON m.trip_id = t.id
            WHERE t.user_id = $1 
            ${syncCondition.replace('updated_at', 'gt.updated_at')}
            
            UNION ALL
            
            SELECT 
                'tag' as entity_type,
                tag.id,
                tag.created_at,
                tag.updated_at
            FROM tags tag
            WHERE tag.user_id = $1 
            ${syncCondition.replace('updated_at', 'tag.updated_at')}
            
            ORDER BY updated_at DESC
            LIMIT $${params.length + 1}
        `;
        params.push(limit);
        return await connection.query(query, params);
    }
    async invalidateRelatedCaches(userId) {
        const cacheKeys = [
            `trips:${userId}:*`,
            `sync:${userId}:*`,
            `user:${userId}:*`
        ];
        for (const pattern of cacheKeys) {
            await this.cacheManager.invalidateCache(pattern);
        }
    }
};
__decorate([
    (0, type_graphql_1.Query)(() => OptimizedSyncResponse),
    __param(0, (0, type_graphql_1.Arg)('userId')),
    __param(1, (0, type_graphql_1.Arg)('lastSync', { nullable: true })),
    __param(2, (0, type_graphql_1.Arg)('limit', { defaultValue: 1000 })),
    __param(3, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Date, Number, Object]),
    __metadata("design:returntype", Promise)
], OptimizedSyncResolver.prototype, "optimizedSync", null);
__decorate([
    (0, type_graphql_1.Query)(() => [Trip_1.Trip]),
    __param(0, (0, type_graphql_1.Arg)('userId')),
    __param(1, (0, type_graphql_1.Arg)('limit', { defaultValue: 50 })),
    __param(2, (0, type_graphql_1.Arg)('offset', { defaultValue: 0 })),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Number, Number]),
    __metadata("design:returntype", Promise)
], OptimizedSyncResolver.prototype, "tripsOptimized", null);
OptimizedSyncResolver = __decorate([
    (0, typedi_1.Service)(),
    (0, type_graphql_1.Resolver)(() => Trip_1.Trip),
    __metadata("design:paramtypes", [])
], OptimizedSyncResolver);
exports.OptimizedSyncResolver = OptimizedSyncResolver;
// Query-Komplexitäts-Analyzer für Performance-Monitoring
class QueryComplexityAnalyzer {
    static analyzeComplexity(query) {
        const complexity = {
            score: 0,
            factors: [],
            recommendations: []
        };
        // Analysiere JOINs
        const joinMatches = query.match(/JOIN/gi) || [];
        if (joinMatches.length > 0) {
            complexity.score += joinMatches.length * 2;
            complexity.factors.push(`${joinMatches.length} JOIN operations`);
        }
        // Analysiere UNIONs
        const unionMatches = query.match(/UNION/gi) || [];
        if (unionMatches.length > 0) {
            complexity.score += unionMatches.length * 1.5;
            complexity.factors.push(`${unionMatches.length} UNION operations`);
        }
        // Analysiere Subqueries
        const subqueryMatches = query.match(/\(SELECT/gi) || [];
        if (subqueryMatches.length > 0) {
            complexity.score += subqueryMatches.length * 3;
            complexity.factors.push(`${subqueryMatches.length} subqueries`);
        }
        // Analysiere ORDER BY
        if (query.includes('ORDER BY')) {
            complexity.score += 1;
            complexity.factors.push('ORDER BY clause');
        }
        // Generiere Empfehlungen
        if (complexity.score > 10) {
            complexity.recommendations.push('Consider using DataLoader for related data');
            complexity.recommendations.push('Add database indexes for frequently queried columns');
            complexity.recommendations.push('Implement query result caching');
        }
        if (complexity.score > 15) {
            complexity.recommendations.push('Query is highly complex - consider optimization');
            complexity.recommendations.push('Break down into simpler queries where possible');
        }
        return complexity;
    }
}
exports.QueryComplexityAnalyzer = QueryComplexityAnalyzer;
