import { SimpleSyncMonitoringSystem } from './SimpleSyncMonitoringSystem';

async function demonstrateMonitoring() {
    console.log('🎯 Starting Sync Monitoring System Demo...\n');
    
    const monitoring = new SimpleSyncMonitoringSystem();
    
    // Zeige das demonstrierte Monitoring
    await monitoring.demonstrateMonitoring();
    
    console.log('🎉 Demo completed successfully!');
}

// Führe Demo nur aus wenn direkt aufgerufen
if (require.main === module) {
    demonstrateMonitoring().catch(console.error);
}

export { demonstrateMonitoring }; 