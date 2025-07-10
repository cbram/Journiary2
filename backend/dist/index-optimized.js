"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.cacheManager = exports.connectionManager = exports.startOptimizedServer = void 0;
require("reflect-metadata");
const apollo_server_express_1 = require("apollo-server-express");
const express_1 = __importDefault(require("express"));
const http_1 = __importDefault(require("http"));
const cors_1 = __importDefault(require("cors"));
const type_graphql_1 = require("type-graphql");
const TripResolver_1 = require("./resolvers/TripResolver");
const MemoryResolver_1 = require("./resolvers/MemoryResolver");
const MediaItemResolver_1 = require("./resolvers/MediaItemResolver");
const RoutePointResolver_1 = require("./resolvers/RoutePointResolver");
const database_1 = require("./utils/database");
const minio_1 = require("./utils/minio");
require("dotenv/config");
const HelloWorldResolver_1 = require("./resolvers/HelloWorldResolver");
const TagResolver_1 = require("./resolvers/TagResolver");
const TagCategoryResolver_1 = require("./resolvers/TagCategoryResolver");
const BucketListItemResolver_1 = require("./resolvers/BucketListItemResolver");
const GPXResolver_1 = require("./resolvers/GPXResolver");
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const UserResolver_1 = require("./resolvers/UserResolver");
const AdminResolver_1 = require("./resolvers/AdminResolver");
const SyncResolver_1 = require("./resolvers/SyncResolver");
const OptimizedSyncResolver_1 = require("./resolvers/OptimizedSyncResolver");
const ConflictAwareSyncResolver_1 = require("./resolvers/ConflictAwareSyncResolver");
const auth_1 = require("./utils/auth");
// Importiere optimierte Systeme
const OptimizedConnectionManager_1 = require("./database/OptimizedConnectionManager");
Object.defineProperty(exports, "connectionManager", { enumerable: true, get: function () { return OptimizedConnectionManager_1.connectionManager; } });
const RedisCacheManager_1 = require("./caching/RedisCacheManager");
Object.defineProperty(exports, "cacheManager", { enumerable: true, get: function () { return RedisCacheManager_1.cacheManager; } });
async function startOptimizedServer() {
    console.log('🚀 Starting Journiary Backend with Performance Optimizations...');
    try {
        // Initialisiere optimierte Systeme parallel
        console.log('🔄 Initializing optimized backend systems...');
        const initTasks = [
            initializeDatabase(),
            initializeConnectionManager(),
            initializeCacheManager(),
            initializeStorage()
        ];
        await Promise.all(initTasks);
        console.log('✅ All backend systems initialized successfully');
    }
    catch (error) {
        console.error('❌ Failed to initialize backend systems:', error);
        process.exit(1);
    }
    const app = (0, express_1.default)();
    const httpServer = http_1.default.createServer(app);
    // Apollo Server mit optimiertem Context
    const apolloServer = new apollo_server_express_1.ApolloServer({
        schema: await (0, type_graphql_1.buildSchema)({
            resolvers: [
                HelloWorldResolver_1.HelloWorldResolver,
                TripResolver_1.TripResolver,
                MemoryResolver_1.MemoryResolver,
                MediaItemResolver_1.MediaItemResolver,
                RoutePointResolver_1.RoutePointResolver,
                TagResolver_1.TagResolver,
                TagCategoryResolver_1.TagCategoryResolver,
                BucketListItemResolver_1.BucketListItemResolver,
                GPXResolver_1.GPXResolver,
                UserResolver_1.UserResolver,
                AdminResolver_1.AdminResolver,
                SyncResolver_1.SyncResolver,
                OptimizedSyncResolver_1.OptimizedSyncResolver,
                ConflictAwareSyncResolver_1.ConflictAwareSyncResolver
            ],
            validate: false,
            authChecker: auth_1.authChecker,
        }),
        context: async ({ req, res }) => {
            const context = {
                req,
                res,
                connectionManager: OptimizedConnectionManager_1.connectionManager,
                cacheManager: RedisCacheManager_1.cacheManager
            };
            const authHeader = req.headers.authorization;
            if (authHeader) {
                const token = authHeader.split(' ')[1];
                if (token) {
                    try {
                        const jwtSecret = process.env.JWT_SECRET;
                        if (!jwtSecret) {
                            throw new Error('JWT_SECRET nicht konfiguriert');
                        }
                        const decoded = jsonwebtoken_1.default.verify(token, jwtSecret);
                        context.userId = decoded.userId;
                        // Preload User-Data in Cache
                        if (decoded.userId) {
                            // Non-blocking preload
                            RedisCacheManager_1.cacheManager.preloadUserData(decoded.userId).catch(err => {
                                console.warn('⚠️ Failed to preload user data:', err);
                            });
                        }
                        console.log('✅ User authenticated and data preloaded:', decoded.userId);
                    }
                    catch (err) {
                        console.error('❌ JWT Verification failed:', err.message);
                    }
                }
            }
            return context;
        },
        // Performance-Monitoring wird über Health-Check-Endpoints realisiert
    });
    await apolloServer.start();
    // Middleware
    app.use((0, cors_1.default)());
    app.use(express_1.default.json({ limit: '50mb' })); // Erhöhtes Limit für große Sync-Payloads
    // Health-Check-Endpoint
    app.get('/health', async (req, res) => {
        try {
            const [dbHealth, cacheHealth] = await Promise.all([
                OptimizedConnectionManager_1.connectionManager.monitorConnectionHealth(),
                RedisCacheManager_1.cacheManager.healthCheck()
            ]);
            res.json({
                status: 'healthy',
                timestamp: new Date().toISOString(),
                database: dbHealth,
                cache: cacheHealth,
                uptime: process.uptime()
            });
        }
        catch (error) {
            res.status(500).json({
                status: 'unhealthy',
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    });
    // Performance-Stats-Endpoint
    app.get('/performance', async (req, res) => {
        try {
            const [dbStats, cacheStats] = await Promise.all([
                OptimizedConnectionManager_1.connectionManager.getPerformanceStats(),
                RedisCacheManager_1.cacheManager.getCacheStats()
            ]);
            res.json({
                timestamp: new Date().toISOString(),
                database: dbStats,
                cache: cacheStats,
                memory: {
                    used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
                    total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
                    external: Math.round(process.memoryUsage().external / 1024 / 1024)
                }
            });
        }
        catch (error) {
            res.status(500).json({
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    });
    apolloServer.applyMiddleware({ app: app, path: '/graphql' });
    const PORT = process.env.PORT || 4000;
    // Graceful Shutdown
    const server = httpServer.listen({ port: PORT }, () => {
        console.log(`🚀 Optimized Journiary Backend ready at http://localhost:${PORT}/graphql`);
        console.log(`📊 Health Check: http://localhost:${PORT}/health`);
        console.log(`📈 Performance Stats: http://localhost:${PORT}/performance`);
    });
    // Graceful Shutdown Handler
    process.on('SIGTERM', gracefulShutdown);
    process.on('SIGINT', gracefulShutdown);
    async function gracefulShutdown(signal) {
        console.log(`\n🔄 Received ${signal}, initiating graceful shutdown...`);
        server.close(async () => {
            console.log('🔄 HTTP server closed');
            try {
                await Promise.all([
                    OptimizedConnectionManager_1.connectionManager.gracefulShutdown(),
                    RedisCacheManager_1.cacheManager.shutdown()
                ]);
                console.log('✅ All systems shut down gracefully');
                process.exit(0);
            }
            catch (error) {
                console.error('❌ Error during shutdown:', error);
                process.exit(1);
            }
        });
    }
}
exports.startOptimizedServer = startOptimizedServer;
// Helper-Funktionen
async function initializeDatabase() {
    try {
        await database_1.AppDataSource.initialize();
        console.log('✅ Database connection initialized');
    }
    catch (error) {
        console.error('❌ Database initialization failed:', error);
        throw error;
    }
}
async function initializeConnectionManager() {
    try {
        await OptimizedConnectionManager_1.connectionManager.initialize();
        console.log('✅ Optimized connection manager initialized');
    }
    catch (error) {
        console.error('❌ Connection manager initialization failed:', error);
        throw error;
    }
}
async function initializeCacheManager() {
    try {
        const healthCheck = await RedisCacheManager_1.cacheManager.healthCheck();
        if (healthCheck.status === 'healthy') {
            console.log('✅ Redis cache manager initialized');
        }
        else {
            console.warn('⚠️ Redis cache manager unhealthy but continuing:', healthCheck.details);
        }
    }
    catch (error) {
        console.warn('⚠️ Cache manager initialization failed, continuing without cache:', error);
    }
}
async function initializeStorage() {
    try {
        await (0, minio_1.ensureBucketExists)();
        console.log('✅ MinIO storage initialized');
    }
    catch (error) {
        console.error('❌ Storage initialization failed:', error);
        throw error;
    }
}
// Start server wenn direkt ausgeführt
if (require.main === module) {
    startOptimizedServer();
}
