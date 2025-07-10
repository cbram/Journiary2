import { Resolver, Query, Arg, Ctx, Int } from 'type-graphql';
import { Service } from 'typedi';
import * as DataLoader from 'dataloader';
import { Repository, In, getConnection, getRepository } from 'typeorm';
import { Trip } from '../entities/Trip';
import { Memory } from '../entities/Memory';
import { MediaItem } from '../entities/MediaItem';
import { GPXTrack } from '../entities/GPXTrack';
import { Tag } from '../entities/Tag';

// Temporäre Cache-Implementierung (bis RedisCacheManager verfügbar ist)
class SimpleCacheManager {
    private cache = new Map<string, { data: any; expiry: number }>();
    
    async smartCache<T>(
        key: string,
        fetchFunction: () => Promise<T>,
        ttl: number = 300
    ): Promise<T> {
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
    
    async invalidateCache(pattern: string): Promise<void> {
        for (const key of this.cache.keys()) {
            if (key.includes(pattern.replace('*', ''))) {
                this.cache.delete(key);
            }
        }
    }
}

class OptimizedSyncResponse {
    trips: Trip[];
    memories: Memory[];
    mediaItems: MediaItem[];
    gpxTracks: GPXTrack[];
    tags: Tag[];
    timestamp: Date;
    totalCount: number;

    constructor(data: any) {
        this.trips = data.trips || [];
        this.memories = data.memories || [];
        this.mediaItems = data.mediaItems || [];
        this.gpxTracks = data.gpxTracks || [];
        this.tags = data.tags || [];
        this.timestamp = data.timestamp || new Date();
        this.totalCount = data.totalCount || 0;
    }
}

interface Context {
    user: { id: string };
}

@Service()
@Resolver(() => Trip)
export class OptimizedSyncResolver {
    private cacheManager: SimpleCacheManager;
    private tripRepository: Repository<Trip>;
    private memoryRepository: Repository<Memory>;
    private mediaItemRepository: Repository<MediaItem>;
    private gpxTrackRepository: Repository<GPXTrack>;
    private tagRepository: Repository<Tag>;

    constructor() {
        this.cacheManager = new SimpleCacheManager();
        this.tripRepository = getRepository(Trip);
        this.memoryRepository = getRepository(Memory);
        this.mediaItemRepository = getRepository(MediaItem);
        this.gpxTrackRepository = getRepository(GPXTrack);
        this.tagRepository = getRepository(Tag);
    }

    @Query(() => OptimizedSyncResponse)
    async optimizedSync(
        @Arg('userId') userId: string,
        @Arg('lastSync', { nullable: true }) lastSync?: Date,
        @Arg('limit', { defaultValue: 1000 }) limit: number = 1000,
        @Ctx() context?: Context
    ): Promise<OptimizedSyncResponse> {
        const syncTimestamp = new Date();
        const cacheKey = `sync:${userId}:${lastSync?.getTime() || 0}:${limit}`;
        
        return await this.cacheManager.smartCache(
            cacheKey,
            async () => {
                const results = await this.performOptimizedSync(userId, lastSync, limit);
                return new OptimizedSyncResponse({
                    ...results,
                    timestamp: syncTimestamp,
                    totalCount: results.trips.length + results.memories.length + 
                               results.mediaItems.length + results.gpxTracks.length + results.tags.length
                });
            },
            60 // 1 Minute Cache
        );
    }

    @Query(() => [Trip])
    async tripsOptimized(
        @Arg('userId') userId: string,
        @Arg('limit', { defaultValue: 50 }) limit: number = 50,
        @Arg('offset', { defaultValue: 0 }) offset: number = 0
    ): Promise<Trip[]> {
        const cacheKey = `trips:${userId}:${limit}:${offset}`;
        
        return await this.cacheManager.smartCache(
            cacheKey,
            async () => {
                const queryBuilder = this.tripRepository.createQueryBuilder('trip')
                    .where('trip.userId = :userId', { userId })
                    .orderBy('trip.createdAt', 'DESC')
                    .limit(limit)
                    .offset(offset);
                
                return await queryBuilder.getMany();
            },
            300 // 5 Minuten Cache
        );
    }

    private async performOptimizedSync(
        userId: string,
        lastSync?: Date,
        limit: number = 1000
    ): Promise<{
        trips: Trip[];
        memories: Memory[];
        mediaItems: MediaItem[];
        gpxTracks: GPXTrack[];
        tags: Tag[];
    }> {
        const connection = getConnection();
        
        // Verwende optimierte Raw-Query für bessere Performance
        const entities = await this.buildOptimizedSyncQuery(userId, lastSync, limit);
        
        // Separiere Entities nach Typ
        const trips: Trip[] = [];
        const memories: Memory[] = [];
        const mediaItems: MediaItem[] = [];
        const gpxTracks: GPXTrack[] = [];
        const tags: Tag[] = [];
        
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

    private async buildOptimizedSyncQuery(
        userId: string,
        lastSync?: Date,
        limit: number = 1000
    ): Promise<any[]> {
        const connection = getConnection();
        const params: any[] = [userId];
        
        // Baue WHERE-Bedingungen
        const syncCondition = lastSync ? 
            `AND updated_at > $${params.length + 1}` : '';
        if (lastSync) params.push(lastSync);
        
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

    private async invalidateRelatedCaches(userId: string): Promise<void> {
        const cacheKeys = [
            `trips:${userId}:*`,
            `sync:${userId}:*`,
            `user:${userId}:*`
        ];
        
        for (const pattern of cacheKeys) {
            await this.cacheManager.invalidateCache(pattern);
        }
    }
}

// Query-Komplexitäts-Analyzer für Performance-Monitoring
export class QueryComplexityAnalyzer {
    static analyzeComplexity(query: string): QueryComplexity {
        const complexity = {
            score: 0,
            factors: [] as string[],
            recommendations: [] as string[]
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

interface QueryComplexity {
    score: number;
    factors: string[];
    recommendations: string[];
} 