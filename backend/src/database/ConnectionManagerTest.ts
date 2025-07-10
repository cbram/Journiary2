import { OptimizedConnectionManager } from './OptimizedConnectionManager';

// Test-Funktion für den OptimizedConnectionManager
async function testConnectionManager(): Promise<void> {
    const connectionManager = new OptimizedConnectionManager();
    
    console.log('🧪 Testing OptimizedConnectionManager...');
    
    try {
        // Initialisierung testen
        await connectionManager.initialize();
        console.log('✅ Connection manager initialized successfully');
        
        // Health-Check testen
        const health = await connectionManager.monitorConnectionHealth();
        console.log('✅ Health check completed:', health);
        
        // Performance-Stats testen
        const stats = await connectionManager.getPerformanceStats();
        console.log('✅ Performance stats retrieved:', stats);
        
        // Pool-Status debuggen
        await connectionManager.debugPoolStatus();
        
        // Graceful Shutdown testen
        await connectionManager.gracefulShutdown();
        console.log('✅ Graceful shutdown completed');
        
    } catch (error) {
        console.error('❌ Test failed:', error);
    }
}

// Export für mögliche Verwendung
export { testConnectionManager }; 