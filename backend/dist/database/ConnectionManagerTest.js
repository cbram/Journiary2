"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.testConnectionManager = void 0;
const OptimizedConnectionManager_1 = require("./OptimizedConnectionManager");
// Test-Funktion für den OptimizedConnectionManager
async function testConnectionManager() {
    const connectionManager = new OptimizedConnectionManager_1.OptimizedConnectionManager();
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
    }
    catch (error) {
        console.error('❌ Test failed:', error);
    }
}
exports.testConnectionManager = testConnectionManager;
