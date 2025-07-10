"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.connectionManager = exports.OptimizedConnectionManager = void 0;
const typeorm_1 = require("typeorm");
const pg_1 = require("pg");
class OptimizedConnectionManager {
    constructor() {
        this.pools = new Map();
        this.isInitialized = false;
        this.initializeOptimizedDataSource();
    }
    initializeOptimizedDataSource() {
        const options = {
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
                max: 20,
                min: 5,
                idleTimeoutMillis: 30000,
                connectionTimeoutMillis: 5000,
                acquireTimeoutMillis: 60000,
                // PostgreSQL-spezifische Einstellungen
                application_name: 'journiary_sync',
                statement_timeout: 30000,
                query_timeout: 25000,
                // Connection-Pool-Optimierungen
                poolErrorHandler: (err) => {
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
                duration: 30000,
                type: 'redis',
                options: {
                    host: process.env.REDIS_HOST,
                    port: parseInt(process.env.REDIS_PORT || '6379')
                }
            } : false,
            // Logging für Performance-Monitoring
            logging: process.env.NODE_ENV === 'development' ? ['error', 'warn', 'migration'] : ['error'],
            maxQueryExecutionTime: 5000,
            // Production-Settings
            synchronize: false,
            migrationsRun: false,
            dropSchema: false
        };
        this.dataSource = new typeorm_1.DataSource(options);
    }
    // Initialisierung aller Verbindungen
    async initialize() {
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
        }
        catch (error) {
            console.error('❌ Failed to initialize connection manager:', error);
            throw error;
        }
    }
    // Spezialisierte Pools für verschiedene Operationen
    async createSpecializedPools() {
        console.log('🔄 Creating specialized connection pools...');
        // Read-Only Pool für Abfragen
        const readOnlyConfig = {
            host: process.env.DB_READ_HOST || process.env.DB_HOST || 'db',
            port: parseInt(process.env.DB_READ_PORT || process.env.DB_PORT || '5432'),
            user: process.env.DB_READ_USERNAME || process.env.DB_USERNAME || 'travelcompanion',
            password: process.env.DB_READ_PASSWORD || process.env.DB_PASSWORD || 'travelcompanion',
            database: process.env.DB_NAME || 'journiary',
            max: 15,
            min: 3,
            idleTimeoutMillis: 30000,
            connectionTimeoutMillis: 5000,
            application_name: 'journiary_read_only',
            // Read-Only-Optimierungen
            statement_timeout: 15000,
            query_timeout: 10000
        };
        // Write-Heavy Pool für Sync-Operationen
        const writeHeavyConfig = {
            host: process.env.DB_HOST || 'db',
            port: parseInt(process.env.DB_PORT || '5432'),
            user: process.env.DB_USERNAME || 'travelcompanion',
            password: process.env.DB_PASSWORD || 'travelcompanion',
            database: process.env.DB_NAME || 'journiary',
            max: 10,
            min: 2,
            idleTimeoutMillis: 20000,
            connectionTimeoutMillis: 3000,
            application_name: 'journiary_write_heavy',
            // Write-Optimierungen
            statement_timeout: 60000,
            query_timeout: 45000
        };
        // Analytics Pool für Reporting und Statistiken
        const analyticsConfig = {
            host: process.env.DB_ANALYTICS_HOST || process.env.DB_HOST || 'db',
            port: parseInt(process.env.DB_ANALYTICS_PORT || process.env.DB_PORT || '5432'),
            user: process.env.DB_ANALYTICS_USERNAME || process.env.DB_USERNAME || 'travelcompanion',
            password: process.env.DB_ANALYTICS_PASSWORD || process.env.DB_PASSWORD || 'travelcompanion',
            database: process.env.DB_NAME || 'journiary',
            max: 5,
            min: 1,
            idleTimeoutMillis: 60000,
            connectionTimeoutMillis: 10000,
            application_name: 'journiary_analytics',
            // Analytics-Optimierungen
            statement_timeout: 300000,
            query_timeout: 240000 // 4 Minuten Query-Timeout
        };
        try {
            const readOnlyPool = new pg_1.Pool(readOnlyConfig);
            const writeHeavyPool = new pg_1.Pool(writeHeavyConfig);
            const analyticsPool = new pg_1.Pool(analyticsConfig);
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
        }
        catch (error) {
            console.error('❌ Error creating specialized pools:', error);
            throw error;
        }
    }
    // Intelligente Connection-Auswahl
    getOptimalConnection(operationType = 'read') {
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
    async executeQuery(query, params = [], operationType = 'read') {
        const connection = this.getOptimalConnection(operationType);
        // Performance-Monitoring
        const startTime = Date.now();
        try {
            let result;
            if (connection instanceof pg_1.Pool) {
                // Verwende Pool-Connection
                const client = await connection.connect();
                try {
                    result = await client.query(query, params);
                }
                finally {
                    client.release();
                }
            }
            else {
                // Verwende TypeORM DataSource
                result = await connection.query(query, params);
            }
            const duration = Date.now() - startTime;
            if (duration > 1000) { // Log langsame Queries
                console.warn(`⚠️ Slow query detected (${duration}ms): ${query.substring(0, 100)}...`);
            }
            console.log(`📊 Query executed in ${duration}ms using ${operationType} pool`);
            return result.rows || result;
        }
        catch (error) {
            const duration = Date.now() - startTime;
            console.error(`❌ Query failed after ${duration}ms:`, error);
            throw error;
        }
    }
    // Transaction-Support mit optimalen Pools
    async executeTransaction(operations, operationType = 'write') {
        const pool = this.getOptimalConnection(operationType);
        if (!(pool instanceof pg_1.Pool)) {
            throw new Error('Transactions require Pool connection');
        }
        const client = await pool.connect();
        try {
            await client.query('BEGIN');
            const result = await operations(client);
            await client.query('COMMIT');
            console.log(`✅ Transaction completed successfully in ${operationType} pool`);
            return result;
        }
        catch (error) {
            await client.query('ROLLBACK');
            console.error(`❌ Transaction rolled back in ${operationType} pool:`, error);
            throw error;
        }
        finally {
            client.release();
        }
    }
    // Connection-Health-Monitoring
    async monitorConnectionHealth() {
        const pools = Array.from(this.pools.entries());
        const healthStatus = {
            totalConnections: 0,
            activeConnections: 0,
            idleConnections: 0,
            waitingConnections: 0,
            poolStatuses: []
        };
        for (const [name, pool] of pools) {
            const poolStatus = {
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
            }
            else if (utilization > 0.7) {
                poolStatus.health = 'warning';
            }
            // Prüfe Waiting-Connections
            if (pool.waitingCount > 5) {
                poolStatus.health = 'critical';
            }
            else if (pool.waitingCount > 2) {
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
    async getPerformanceStats() {
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
    generatePerformanceRecommendations(health) {
        const recommendations = [];
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
    getDatabaseOptimizations() {
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
            random_page_cost: 1.1,
            effective_cache_size: '1GB',
            // Batch-Größen-Optimierungen
            batch_size: 1000,
            max_batch_size: 5000
        };
    }
    // Graceful Shutdown
    async gracefulShutdown() {
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
        }
        catch (error) {
            console.error('❌ Error during graceful shutdown:', error);
            throw error;
        }
    }
    // Getter für DataSource (Backward-Compatibility)
    get mainDataSource() {
        return this.dataSource;
    }
    // Pool-Status für Debugging
    async debugPoolStatus() {
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
exports.OptimizedConnectionManager = OptimizedConnectionManager;
// Singleton-Instance
exports.connectionManager = new OptimizedConnectionManager();
