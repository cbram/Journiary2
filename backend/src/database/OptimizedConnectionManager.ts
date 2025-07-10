import { DataSource, DataSourceOptions } from 'typeorm';
import { Pool, PoolClient, PoolConfig } from 'pg';

interface ConnectionHealthStatus {
    totalConnections: number;
    activeConnections: number;
    idleConnections: number;
    waitingConnections: number;
    poolStatuses: PoolStatus[];
}

interface PoolStatus {
    name: string;
    totalCount: number;
    idleCount: number;
    waitingCount: number;
    health: 'healthy' | 'warning' | 'critical';
}

export class OptimizedConnectionManager {
    private dataSource!: DataSource;
    private readonly pools: Map<string, Pool> = new Map();
    private isInitialized = false;
    
    constructor() {
        this.initializeOptimizedDataSource();
    }
    
    private initializeOptimizedDataSource(): void {
        const options: DataSourceOptions = {
            type: 'postgres',
            host: process.env.DB_HOST || 'db',
            port: parseInt(process.env.DB_PORT || '5432'),
            username: process.env.DB_USERNAME || 'travelcompanion',
            password: process.env.DB_PASSWORD || 'travelcompanion',
            database: process.env.DB_NAME || 'journiary',
            
            // Basis-Entitäten
            entities: ['src/entities/*.ts'],
            
            // Optimierte Pool-Einstellungen
            extra: {
                max: 20, // Maximum 20 Verbindungen
                min: 5,  // Minimum 5 Verbindungen
                idleTimeoutMillis: 30000, // 30 Sekunden Idle-Timeout
                connectionTimeoutMillis: 5000, // 5 Sekunden Connection-Timeout
                acquireTimeoutMillis: 60000, // 60 Sekunden Acquire-Timeout
                
                // PostgreSQL-spezifische Einstellungen
                application_name: 'journiary_sync',
                statement_timeout: 30000, // 30 Sekunden Statement-Timeout
                query_timeout: 25000, // 25 Sekunden Query-Timeout
                
                // Connection-Pool-Optimierungen
                poolErrorHandler: (err: Error) => {
                    console.error('Pool error:', err);
                },
                
                // Retry-Logik
                retryAttempts: 3,
                retryDelay: 1000,
                
                // Performance-Optimierungen
                ...this.getDatabaseOptimizations()
            },
            
            // Query-Caching (falls Redis verfügbar)
            cache: process.env.REDIS_HOST ? {
                duration: 30000, // 30 Sekunden Query-Cache
                type: 'redis',
                options: {
                    host: process.env.REDIS_HOST,
                    port: parseInt(process.env.REDIS_PORT || '6379')
                }
            } : false,
            
            // Logging für Performance-Monitoring
            logging: process.env.NODE_ENV === 'development' ? ['error', 'warn', 'migration'] : ['error'],
            maxQueryExecutionTime: 5000, // Warnung bei Queries > 5 Sekunden
            
            // Production-Settings
            synchronize: false, // Nie in Production verwenden
            migrationsRun: false, // Manuelle Migration-Kontrolle
            dropSchema: false
        };
        
        this.dataSource = new DataSource(options);
    }
    
    // Initialisierung aller Verbindungen
    async initialize(): Promise<void> {
        if (this.isInitialized) {
            console.log('🔄 Connection manager already initialized');
            return;
        }
        
        try {
            console.log('🔄 Initializing optimized database connections...');
            
            // Haupt-DataSource initialisieren
            await this.dataSource.initialize();
            console.log('✅ Main DataSource initialized');
            
            // Spezialisierte Pools erstellen
            await this.createSpecializedPools();
            console.log('✅ Specialized pools created');
            
            // Health-Check durchführen
            const health = await this.monitorConnectionHealth();
            console.log(`📊 Connection health: ${health.totalConnections} total connections`);
            
            this.isInitialized = true;
            console.log('✅ OptimizedConnectionManager fully initialized');
            
        } catch (error) {
            console.error('❌ Failed to initialize connection manager:', error);
            throw error;
        }
    }
    
    // Spezialisierte Pools für verschiedene Operationen
    async createSpecializedPools(): Promise<void> {
        console.log('🔄 Creating specialized connection pools...');
        
        // Read-Only Pool für Abfragen
        const readOnlyConfig: PoolConfig = {
            host: process.env.DB_READ_HOST || process.env.DB_HOST || 'db',
            port: parseInt(process.env.DB_READ_PORT || process.env.DB_PORT || '5432'),
            user: process.env.DB_READ_USERNAME || process.env.DB_USERNAME || 'travelcompanion',
            password: process.env.DB_READ_PASSWORD || process.env.DB_PASSWORD || 'travelcompanion',
            database: process.env.DB_NAME || 'journiary',
            max: 15, // Mehr Verbindungen für Read-Operationen
            min: 3,
            idleTimeoutMillis: 30000,
            connectionTimeoutMillis: 5000,
            application_name: 'journiary_read_only',
            // Read-Only-Optimierungen
            statement_timeout: 15000, // Kürzerer Timeout für Read-Queries
            query_timeout: 10000
        };
        
        // Write-Heavy Pool für Sync-Operationen
        const writeHeavyConfig: PoolConfig = {
            host: process.env.DB_HOST || 'db',
            port: parseInt(process.env.DB_PORT || '5432'),
            user: process.env.DB_USERNAME || 'travelcompanion',
            password: process.env.DB_PASSWORD || 'travelcompanion',
            database: process.env.DB_NAME || 'journiary',
            max: 10, // Weniger aber stabile Verbindungen für Write-Ops
            min: 2,
            idleTimeoutMillis: 20000, // Kürzerer Idle-Timeout für aktive Writes
            connectionTimeoutMillis: 3000,
            application_name: 'journiary_write_heavy',
            // Write-Optimierungen
            statement_timeout: 60000, // Längerer Timeout für komplexe Writes
            query_timeout: 45000
        };
        
        // Analytics Pool für Reporting und Statistiken
        const analyticsConfig: PoolConfig = {
            host: process.env.DB_ANALYTICS_HOST || process.env.DB_HOST || 'db',
            port: parseInt(process.env.DB_ANALYTICS_PORT || process.env.DB_PORT || '5432'),
            user: process.env.DB_ANALYTICS_USERNAME || process.env.DB_USERNAME || 'travelcompanion',
            password: process.env.DB_ANALYTICS_PASSWORD || process.env.DB_PASSWORD || 'travelcompanion',
            database: process.env.DB_NAME || 'journiary',
            max: 5, // Kleine Pool für Analytics
            min: 1,
            idleTimeoutMillis: 60000, // Längerer Idle für Analytics
            connectionTimeoutMillis: 10000,
            application_name: 'journiary_analytics',
            // Analytics-Optimierungen
            statement_timeout: 300000, // 5 Minuten für komplexe Analytics
            query_timeout: 240000 // 4 Minuten Query-Timeout
        };
        
        try {
            const readOnlyPool = new Pool(readOnlyConfig);
            const writeHeavyPool = new Pool(writeHeavyConfig);
            const analyticsPool = new Pool(analyticsConfig);
            
            // Error-Handler für alle Pools
            [readOnlyPool, writeHeavyPool, analyticsPool].forEach((pool, index) => {
                const poolNames = ['readonly', 'writeheavy', 'analytics'];
                pool.on('error', (err) => {
                    console.error(`❌ Pool error in ${poolNames[index]}:`, err);
                });
                
                pool.on('connect', () => {
                    console.log(`🔌 New connection established in ${poolNames[index]} pool`);
                });
                
                pool.on('remove', () => {
                    console.log(`🔌 Connection removed from ${poolNames[index]} pool`);
                });
            });
            
            this.pools.set('readonly', readOnlyPool);
            this.pools.set('writeheavy', writeHeavyPool);
            this.pools.set('analytics', analyticsPool);
            
            console.log('✅ All specialized pools created successfully');
            
        } catch (error) {
            console.error('❌ Error creating specialized pools:', error);
            throw error;
        }
    }
    
    // Intelligente Connection-Auswahl
    getOptimalConnection(operationType: 'read' | 'write' | 'analytics' = 'read'): Pool | DataSource {
        if (!this.isInitialized) {
            console.warn('⚠️ Connection manager not initialized, using default DataSource');
            return this.dataSource;
        }
        
        switch (operationType) {
            case 'read':
                const readPool = this.pools.get('readonly');
                return readPool || this.dataSource;
            case 'write':
                const writePool = this.pools.get('writeheavy');
                return writePool || this.dataSource;
            case 'analytics':
                const analyticsPool = this.pools.get('analytics');
                return analyticsPool || this.dataSource;
            default:
                return this.dataSource;
        }
    }
    
    // Erweiterte Query-Ausführung mit automatischer Pool-Auswahl
    async executeQuery<T = any>(
        query: string,
        params: any[] = [],
        operationType: 'read' | 'write' | 'analytics' = 'read'
    ): Promise<T[]> {
        const connection = this.getOptimalConnection(operationType);
        
        // Performance-Monitoring
        const startTime = Date.now();
        
        try {
            let result: any;
            
            if (connection instanceof Pool) {
                // Verwende Pool-Connection
                const client = await connection.connect();
                try {
                    result = await client.query(query, params);
                } finally {
                    client.release();
                }
            } else {
                // Verwende TypeORM DataSource
                result = await connection.query(query, params);
            }
            
            const duration = Date.now() - startTime;
            
            if (duration > 1000) { // Log langsame Queries
                console.warn(`⚠️ Slow query detected (${duration}ms): ${query.substring(0, 100)}...`);
            }
            
            console.log(`📊 Query executed in ${duration}ms using ${operationType} pool`);
            
            return result.rows || result;
            
        } catch (error) {
            const duration = Date.now() - startTime;
            console.error(`❌ Query failed after ${duration}ms:`, error);
            throw error;
        }
    }
    
    // Transaction-Support mit optimalen Pools
    async executeTransaction<T>(
        operations: (client: PoolClient) => Promise<T>,
        operationType: 'write' | 'analytics' = 'write'
    ): Promise<T> {
        const pool = this.getOptimalConnection(operationType) as Pool;
        
        if (!(pool instanceof Pool)) {
            throw new Error('Transactions require Pool connection');
        }
        
        const client = await pool.connect();
        
        try {
            await client.query('BEGIN');
            const result = await operations(client);
            await client.query('COMMIT');
            
            console.log(`✅ Transaction completed successfully in ${operationType} pool`);
            return result;
            
        } catch (error) {
            await client.query('ROLLBACK');
            console.error(`❌ Transaction rolled back in ${operationType} pool:`, error);
            throw error;
        } finally {
            client.release();
        }
    }
    
    // Connection-Health-Monitoring
    async monitorConnectionHealth(): Promise<ConnectionHealthStatus> {
        const pools = Array.from(this.pools.entries());
        const healthStatus: ConnectionHealthStatus = {
            totalConnections: 0,
            activeConnections: 0,
            idleConnections: 0,
            waitingConnections: 0,
            poolStatuses: []
        };
        
        for (const [name, pool] of pools) {
            const poolStatus: PoolStatus = {
                name,
                totalCount: pool.totalCount,
                idleCount: pool.idleCount,
                waitingCount: pool.waitingCount,
                health: 'healthy'
            };
            
            // Bewerte Pool-Gesundheit
            const utilization = pool.totalCount > 0 ? (pool.totalCount - pool.idleCount) / pool.totalCount : 0;
            
            if (utilization > 0.9) {
                poolStatus.health = 'critical';
            } else if (utilization > 0.7) {
                poolStatus.health = 'warning';
            }
            
            // Prüfe Waiting-Connections
            if (pool.waitingCount > 5) {
                poolStatus.health = 'critical';
            } else if (pool.waitingCount > 2) {
                poolStatus.health = poolStatus.health === 'healthy' ? 'warning' : poolStatus.health;
            }
            
            healthStatus.totalConnections += pool.totalCount;
            healthStatus.activeConnections += (pool.totalCount - pool.idleCount);
            healthStatus.idleConnections += pool.idleCount;
            healthStatus.waitingConnections += pool.waitingCount;
            healthStatus.poolStatuses.push(poolStatus);
        }
        
        return healthStatus;
    }
    
    // Performance-Statistiken
    async getPerformanceStats(): Promise<any> {
        const health = await this.monitorConnectionHealth();
        
        return {
            timestamp: new Date().toISOString(),
            connectionHealth: health,
            poolUtilization: health.poolStatuses.map(pool => ({
                name: pool.name,
                utilization: pool.totalCount > 0 ? (pool.totalCount - pool.idleCount) / pool.totalCount : 0,
                health: pool.health
            })),
            recommendations: this.generatePerformanceRecommendations(health)
        };
    }
    
    private generatePerformanceRecommendations(health: ConnectionHealthStatus): string[] {
        const recommendations: string[] = [];
        
        // Prüfe Gesamt-Utilization
        const overallUtilization = health.totalConnections > 0 ? 
            health.activeConnections / health.totalConnections : 0;
        
        if (overallUtilization > 0.8) {
            recommendations.push('Consider increasing connection pool sizes');
        }
        
        if (health.waitingConnections > 10) {
            recommendations.push('High connection wait time detected - check query performance');
        }
        
        // Pool-spezifische Empfehlungen
        for (const pool of health.poolStatuses) {
            if (pool.health === 'critical') {
                recommendations.push(`${pool.name} pool is critically overloaded`);
            }
            
            if (pool.waitingCount > pool.totalCount) {
                recommendations.push(`${pool.name} pool has excessive waiting connections`);
            }
        }
        
        return recommendations;
    }
    
    // Database-Performance-Optimierungen
    private getDatabaseOptimizations(): any {
        return {
            // PostgreSQL-spezifische Optimierungen
            synchronous_commit: process.env.NODE_ENV === 'production' ? 'on' : 'off',
            wal_buffers: '16MB',
            checkpoint_completion_target: 0.9,
            
            // Memory-Optimierungen
            work_mem: '256MB',
            maintenance_work_mem: '256MB',
            shared_buffers: '256MB',
            
            // Connection-Optimierungen
            tcp_keepalives_idle: 600,
            tcp_keepalives_interval: 30,
            tcp_keepalives_count: 3,
            
            // Query-Optimierungen
            random_page_cost: 1.1, // SSD-optimiert
            effective_cache_size: '1GB',
            
            // Batch-Größen-Optimierungen
            batch_size: 1000,
            max_batch_size: 5000
        };
    }
    
    // Graceful Shutdown
    async gracefulShutdown(): Promise<void> {
        console.log('🔄 Initiating graceful database shutdown...');
        
        try {
            // Schließe alle Pools
            for (const [name, pool] of this.pools) {
                console.log(`🔄 Closing pool: ${name}`);
                await pool.end();
                console.log(`✅ Pool ${name} closed`);
            }
            
            // Schließe Haupt-DataSource
            if (this.dataSource?.isInitialized) {
                await this.dataSource.destroy();
                console.log('✅ Main DataSource destroyed');
            }
            
            this.isInitialized = false;
            console.log('✅ Database shutdown completed successfully');
            
        } catch (error) {
            console.error('❌ Error during graceful shutdown:', error);
            throw error;
        }
    }
    
    // Getter für DataSource (Backward-Compatibility)
    get mainDataSource(): DataSource {
        return this.dataSource;
    }
    
    // Pool-Status für Debugging
    async debugPoolStatus(): Promise<void> {
        console.log('\n📊 === CONNECTION POOL STATUS ===');
        
        for (const [name, pool] of this.pools) {
            console.log(`\n🔍 Pool: ${name}`);
            console.log(`  Total: ${pool.totalCount}`);
            console.log(`  Idle: ${pool.idleCount}`);
            console.log(`  Active: ${pool.totalCount - pool.idleCount}`);
            console.log(`  Waiting: ${pool.waitingCount}`);
            
            const utilization = pool.totalCount > 0 ? 
                ((pool.totalCount - pool.idleCount) / pool.totalCount * 100).toFixed(1) : '0';
            console.log(`  Utilization: ${utilization}%`);
        }
        
        console.log('\n=================================\n');
    }
}

// Singleton-Instance
export const connectionManager = new OptimizedConnectionManager(); 