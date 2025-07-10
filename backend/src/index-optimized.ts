import "reflect-metadata";
import { ApolloServer } from 'apollo-server-express';
import express from 'express';
import http from 'http';
import cors from 'cors';
import { buildSchema } from 'type-graphql';
import { TripResolver } from './resolvers/TripResolver';
import { MemoryResolver } from './resolvers/MemoryResolver';
import { MediaItemResolver } from './resolvers/MediaItemResolver';
import { RoutePointResolver } from './resolvers/RoutePointResolver';
import { AppDataSource } from './utils/database';
import { ensureBucketExists } from './utils/minio';
import "dotenv/config";
import { HelloWorldResolver } from "./resolvers/HelloWorldResolver";
import { TagResolver } from "./resolvers/TagResolver";
import { TagCategoryResolver } from "./resolvers/TagCategoryResolver";
import { BucketListItemResolver } from "./resolvers/BucketListItemResolver";
import { GPXResolver } from "./resolvers/GPXResolver";
import jwt from 'jsonwebtoken';
import { UserResolver } from "./resolvers/UserResolver";
import { AdminResolver } from "./resolvers/AdminResolver";
import { SyncResolver } from "./resolvers/SyncResolver";
import { OptimizedSyncResolver } from "./resolvers/OptimizedSyncResolver";
import { ConflictAwareSyncResolver } from "./resolvers/ConflictAwareSyncResolver";
import { authChecker } from "./utils/auth";

// Importiere optimierte Systeme
import { connectionManager } from './database/OptimizedConnectionManager';
import { cacheManager } from './caching/RedisCacheManager';

export interface MyContext {
    req: any;
    res: any;
    userId?: string;
    connectionManager: typeof connectionManager;
    cacheManager: typeof cacheManager;
}

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
        
    } catch (error) {
        console.error('❌ Failed to initialize backend systems:', error);
        process.exit(1);
    }

    const app = express();
    const httpServer = http.createServer(app);

    // Apollo Server mit optimiertem Context
    const apolloServer = new ApolloServer({
        schema: await buildSchema({
            resolvers: [
                HelloWorldResolver,
                TripResolver,
                MemoryResolver,
                MediaItemResolver,
                RoutePointResolver,
                TagResolver,
                TagCategoryResolver,
                BucketListItemResolver,
                GPXResolver,
                UserResolver,
                AdminResolver,
                SyncResolver,
                OptimizedSyncResolver,
                ConflictAwareSyncResolver
            ],
            validate: false,
            authChecker,
        }),
        context: async ({ req, res }): Promise<MyContext> => {
            const context: MyContext = { 
                req, 
                res, 
                connectionManager,
                cacheManager
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
                        
                        const decoded = jwt.verify(token, jwtSecret) as { userId: string };
                        context.userId = decoded.userId;
                        
                        // Preload User-Data in Cache
                        if (decoded.userId) {
                            // Non-blocking preload
                            cacheManager.preloadUserData(decoded.userId).catch(err => {
                                console.warn('⚠️ Failed to preload user data:', err);
                            });
                        }
                        
                        console.log('✅ User authenticated and data preloaded:', decoded.userId);
                        
                    } catch (err: any) {
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
    app.use(cors());
    app.use(express.json({ limit: '50mb' })); // Erhöhtes Limit für große Sync-Payloads

    // Health-Check-Endpoint
    app.get('/health', async (req, res) => {
        try {
            const [dbHealth, cacheHealth] = await Promise.all([
                connectionManager.monitorConnectionHealth(),
                cacheManager.healthCheck()
            ]);
            
            res.json({
                status: 'healthy',
                timestamp: new Date().toISOString(),
                database: dbHealth,
                cache: cacheHealth,
                uptime: process.uptime()
            });
        } catch (error) {
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
                connectionManager.getPerformanceStats(),
                cacheManager.getCacheStats()
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
        } catch (error) {
            res.status(500).json({
                error: error instanceof Error ? error.message : 'Unknown error'
            });
        }
    });

    apolloServer.applyMiddleware({ app: app as any, path: '/graphql' });

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
    
    async function gracefulShutdown(signal: string) {
        console.log(`\n🔄 Received ${signal}, initiating graceful shutdown...`);
        
        server.close(async () => {
            console.log('🔄 HTTP server closed');
            
            try {
                await Promise.all([
                    connectionManager.gracefulShutdown(),
                    cacheManager.shutdown()
                ]);
                
                console.log('✅ All systems shut down gracefully');
                process.exit(0);
            } catch (error) {
                console.error('❌ Error during shutdown:', error);
                process.exit(1);
            }
        });
    }
}

// Helper-Funktionen
async function initializeDatabase(): Promise<void> {
    try {
        await AppDataSource.initialize();
        console.log('✅ Database connection initialized');
    } catch (error) {
        console.error('❌ Database initialization failed:', error);
        throw error;
    }
}

async function initializeConnectionManager(): Promise<void> {
    try {
        await connectionManager.initialize();
        console.log('✅ Optimized connection manager initialized');
    } catch (error) {
        console.error('❌ Connection manager initialization failed:', error);
        throw error;
    }
}

async function initializeCacheManager(): Promise<void> {
    try {
        const healthCheck = await cacheManager.healthCheck();
        if (healthCheck.status === 'healthy') {
            console.log('✅ Redis cache manager initialized');
        } else {
            console.warn('⚠️ Redis cache manager unhealthy but continuing:', healthCheck.details);
        }
    } catch (error) {
        console.warn('⚠️ Cache manager initialization failed, continuing without cache:', error);
    }
}

async function initializeStorage(): Promise<void> {
    try {
        await ensureBucketExists();
        console.log('✅ MinIO storage initialized');
    } catch (error) {
        console.error('❌ Storage initialization failed:', error);
        throw error;
    }
}

// Export für Tests
export { startOptimizedServer, connectionManager, cacheManager };

// Start server wenn direkt ausgeführt
if (require.main === module) {
    startOptimizedServer();
} 