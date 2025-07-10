"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.demonstrateMonitoring = void 0;
const SimpleSyncMonitoringSystem_1 = require("./SimpleSyncMonitoringSystem");
async function demonstrateMonitoring() {
    console.log('🎯 Starting Sync Monitoring System Demo...\n');
    const monitoring = new SimpleSyncMonitoringSystem_1.SimpleSyncMonitoringSystem();
    // Zeige das demonstrierte Monitoring
    await monitoring.demonstrateMonitoring();
    console.log('🎉 Demo completed successfully!');
}
exports.demonstrateMonitoring = demonstrateMonitoring;
// Führe Demo nur aus wenn direkt aufgerufen
if (require.main === module) {
    demonstrateMonitoring().catch(console.error);
}
