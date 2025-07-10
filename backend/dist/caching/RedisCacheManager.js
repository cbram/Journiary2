"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.cacheManager = exports.Cached = exports.RedisCacheManager = void 0;
const ioredis_1 = __importDefault(require("ioredis"));
class RedisCacheManager {
    constructor() {
        this.defaultTTL = 3600; // 1 Stunde
        this.redis = new ioredis_1.default({
            host: process.env.REDIS_HOST || 'redis',
            port: parseInt(process.env.REDIS_PORT || '6379'),
            password: process.env.REDIS_PASSWORD,
            retryDelayOnFailover: 100,
            maxRetriesPerRequest: 3,
            lazyConnect: true,
            connectTimeout: 10000,
            commandTimeout: 5000
        });
        this.redis.on('error', (error) => {
            console.error('Redis connection error:', error);
        });
        this.redis.on('connect', () => {
            console.log('✅ Redis connected successfully');
        });
        this.redis.on('ready', () => {
            console.log('📊 Redis ready for operations');
        });
    }
    // Sync-Daten cachen
    async cacheSyncData(key, data, ttl = this.defaultTTL) {
        try {
            const serializedData = JSON.stringify(data);
            await this.redis.setex(key, ttl, serializedData);
            console.log(`🔄 Cached data for key: ${key} (TTL: ${ttl}s)`);
        }
        catch (error) {
            console.error('❌ Error caching sync data:', error);
            throw error;
        }
    }
    // Cached Sync-Daten abrufen
    async getCachedSyncData(key) {
        try {
            const data = await this.redis.get(key);
            if (data) {
                console.log(`✅ Cache hit for key: ${key}`);
                return JSON.parse(data);
            }
            else {
                console.log(`❌ Cache miss for key: ${key}`);
                return null;
            }
        }
        catch (error) {
            console.error('❌ Error retrieving cached sync data:', error);
            return null;
        }
    }
    // Smart Caching für häufig abgerufene Daten
    async smartCache(key, fetchFunction, ttl = this.defaultTTL) {
        // Versuche zuerst aus Cache
        const cached = await this.getCachedSyncData(key);
        if (cached) {
            // Aktualisiere Hit-Counter
            await this.incrementHitCounter(key);
            return cached;
        }
        // Lade Daten und cache sie
        console.log(`🔄 Fetching fresh data for key: ${key}`);
        const data = await fetchFunction();
        await this.cacheSyncData(key, data, ttl);
        // Aktualisiere Miss-Counter
        await this.incrementMissCounter(key);
        return data;
    }
    // Preload-System für vorhersagbare Daten
    async preloadUserData(userId) {
        console.log(`🚀 Preloading data for user: ${userId}`);
        const preloadTasks = [
            this.preloadUserTrips(userId),
            this.preloadUserTags(userId),
            this.preloadUserBucketList(userId),
            this.preloadUserStatistics(userId)
        ];
        const results = await Promise.allSettled(preloadTasks);
        const successful = results.filter(r => r.status === 'fulfilled').length;
        const failed = results.filter(r => r.status === 'rejected').length;
        console.log(`📊 Preload completed: ${successful} successful, ${failed} failed`);
    }
    async preloadUserTrips(userId) {
        const key = `user:${userId}:trips`;
        const cached = await this.getCachedSyncData(key);
        if (!cached) {
            console.log(`🔄 Preloading trips for user: ${userId}`);
            // Simuliere Trip-Laden (würde normalerweise DB-Query sein)
            const trips = await this.fetchUserTrips(userId);
            await this.cacheSyncData(key, trips, 7200); // 2 Stunden Cache
        }
    }
    async preloadUserTags(userId) {
        const key = `user:${userId}:tags`;
        const cached = await this.getCachedSyncData(key);
        if (!cached) {
            console.log(`🔄 Preloading tags for user: ${userId}`);
            const tags = await this.fetchUserTags(userId);
            await this.cacheSyncData(key, tags, 3600); // 1 Stunde Cache
        }
    }
    async preloadUserBucketList(userId) {
        const key = `user:${userId}:bucketlist`;
        const cached = await this.getCachedSyncData(key);
        if (!cached) {
            console.log(`🔄 Preloading bucket list for user: ${userId}`);
            const bucketList = await this.fetchUserBucketList(userId);
            await this.cacheSyncData(key, bucketList, 1800); // 30 Minuten Cache
        }
    }
    async preloadUserStatistics(userId) {
        const key = `user:${userId}:stats`;
        const cached = await this.getCachedSyncData(key);
        if (!cached) {
            console.log(`🔄 Preloading statistics for user: ${userId}`);
            const stats = await this.fetchUserStatistics(userId);
            await this.cacheSyncData(key, stats, 600); // 10 Minuten Cache
        }
    }
    // Cache-Invalidierung
    async invalidateUserCache(userId) {
        console.log(`🗑️ Invalidating cache for user: ${userId}`);
        const patterns = [
            `user:${userId}:*`,
            `trips:user:${userId}:*`,
            `memories:user:${userId}:*`,
            `sync:${userId}:*`
        ];
        for (const pattern of patterns) {
            const keys = await this.redis.keys(pattern);
            if (keys.length > 0) {
                await this.redis.del(...keys);
                console.log(`🗑️ Deleted ${keys.length} keys matching pattern: ${pattern}`);
            }
        }
    }
    async invalidateCache(pattern) {
        if (pattern) {
            const keys = await this.redis.keys(pattern);
            if (keys.length > 0) {
                await this.redis.del(...keys);
                console.log(`🗑️ Invalidated ${keys.length} cache entries`);
            }
        }
        else {
            await this.redis.flushdb();
            console.log(`🗑️ Invalidated entire cache database`);
        }
    }
    // Cache-Statistiken
    async getCacheStats() {
        try {
            const info = await this.redis.info('memory');
            const keyCount = await this.redis.dbsize();
            const memoryUsage = this.parseMemoryInfo(info);
            const hitRate = await this.calculateHitRate();
            const uptime = await this.getUptime();
            return {
                keyCount,
                memoryUsage,
                hitRate,
                uptime
            };
        }
        catch (error) {
            console.error('❌ Error getting cache stats:', error);
            return {
                keyCount: 0,
                memoryUsage: 0,
                hitRate: 0,
                uptime: 0
            };
        }
    }
    // Batch-Operations für bessere Performance
    async batchSet(entries) {
        console.log(`🔄 Batch setting ${entries.length} cache entries`);
        const pipeline = this.redis.pipeline();
        for (const entry of entries) {
            const serializedValue = JSON.stringify(entry.value);
            const ttl = entry.ttl || this.defaultTTL;
            pipeline.setex(entry.key, ttl, serializedValue);
        }
        await pipeline.exec();
        console.log(`✅ Batch set completed for ${entries.length} entries`);
    }
    async batchGet(keys) {
        console.log(`🔄 Batch getting ${keys.length} cache entries`);
        const pipeline = this.redis.pipeline();
        keys.forEach(key => pipeline.get(key));
        const results = await pipeline.exec();
        const resultMap = new Map();
        for (let i = 0; i < keys.length; i++) {
            const [error, value] = results[i];
            if (!error && value) {
                try {
                    resultMap.set(keys[i], JSON.parse(value));
                }
                catch (parseError) {
                    console.error(`❌ Error parsing cached data for key ${keys[i]}:`, parseError);
                }
            }
        }
        console.log(`✅ Batch get completed: ${resultMap.size}/${keys.length} hits`);
        return resultMap;
    }
    // Health Check
    async healthCheck() {
        try {
            const start = Date.now();
            await this.redis.ping();
            const responseTime = Date.now() - start;
            const stats = await this.getCacheStats();
            const isHealthy = responseTime < 100 && stats.memoryUsage < 1024 * 1024 * 1024; // < 1GB
            return {
                status: isHealthy ? 'healthy' : 'unhealthy',
                details: {
                    responseTime: `${responseTime}ms`,
                    ...stats,
                    lastCheck: new Date().toISOString()
                }
            };
        }
        catch (error) {
            return {
                status: 'unhealthy',
                details: {
                    error: error instanceof Error ? error.message : 'Unknown error',
                    lastCheck: new Date().toISOString()
                }
            };
        }
    }
    // Hilfsmethoden
    parseMemoryInfo(info) {
        const lines = info.split('\n');
        const usedMemoryLine = lines.find((line) => line.startsWith('used_memory:'));
        return usedMemoryLine ? parseInt(usedMemoryLine.split(':')[1]) : 0;
    }
    async calculateHitRate() {
        try {
            const hits = await this.redis.get('cache:hits') || '0';
            const misses = await this.redis.get('cache:misses') || '0';
            const total = parseInt(hits) + parseInt(misses);
            return total > 0 ? parseInt(hits) / total : 0;
        }
        catch (error) {
            return 0;
        }
    }
    async getUptime() {
        try {
            const info = await this.redis.info('server');
            const uptimeLine = info.split('\n').find((line) => line.startsWith('uptime_in_seconds:'));
            return uptimeLine ? parseInt(uptimeLine.split(':')[1]) : 0;
        }
        catch (error) {
            return 0;
        }
    }
    async incrementHitCounter(key) {
        try {
            await Promise.all([
                this.redis.incr('cache:hits'),
                this.redis.incr(`cache:hits:${key}`)
            ]);
        }
        catch (error) {
            console.error('❌ Error incrementing hit counter:', error);
        }
    }
    async incrementMissCounter(key) {
        try {
            await Promise.all([
                this.redis.incr('cache:misses'),
                this.redis.incr(`cache:misses:${key}`)
            ]);
        }
        catch (error) {
            console.error('❌ Error incrementing miss counter:', error);
        }
    }
    // Placeholder-Methoden (würden normalerweise richtige DB-Queries sein)
    async fetchUserTrips(userId) {
        // Echte Implementierung würde DB abfragen
        console.log(`📊 Fetching trips from database for user: ${userId}`);
        return [];
    }
    async fetchUserTags(userId) {
        console.log(`📊 Fetching tags from database for user: ${userId}`);
        return [];
    }
    async fetchUserBucketList(userId) {
        console.log(`📊 Fetching bucket list from database for user: ${userId}`);
        return [];
    }
    async fetchUserStatistics(userId) {
        console.log(`📊 Fetching statistics from database for user: ${userId}`);
        return {
            totalTrips: 0,
            totalMemories: 0,
            totalMediaItems: 0,
            totalDistance: 0
        };
    }
    // Graceful Shutdown
    async shutdown() {
        console.log('🔄 Shutting down Redis connection...');
        try {
            await this.redis.quit();
            console.log('✅ Redis connection closed gracefully');
        }
        catch (error) {
            console.error('❌ Error during Redis shutdown:', error);
            this.redis.disconnect();
        }
    }
}
exports.RedisCacheManager = RedisCacheManager;
// Cache-Decorator für automatisches Caching
function Cached(ttl = 3600, keyPrefix = '') {
    return function (target, propertyKey, descriptor) {
        const originalMethod = descriptor.value;
        descriptor.value = async function (...args) {
            const cacheManager = new RedisCacheManager();
            const argsHash = require('crypto')
                .createHash('md5')
                .update(JSON.stringify(args))
                .digest('hex');
            const key = `${keyPrefix}:${propertyKey}:${argsHash}`;
            return await cacheManager.smartCache(key, async () => {
                return await originalMethod.apply(this, args);
            }, ttl);
        };
        return descriptor;
    };
}
exports.Cached = Cached;
// Singleton-Instance für globale Verwendung
exports.cacheManager = new RedisCacheManager();
