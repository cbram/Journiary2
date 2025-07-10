import { Repository } from 'typeorm';
import { AppDataSource } from '../utils/database';
import { 
    ConflictResolutionStrategy, 
    ConflictMetadata, 
    ConflictResolutionResult,
    BaseEntity,
    ConflictLog,
    DeviceRegistry,
    DeviceInfo,
    IDeviceRegistry,
    ConflictDetectionResult,
    ConflictResolutionOptions
} from '../types/ConflictTypes';

// Device-Registry-Service
export class DeviceRegistryService implements IDeviceRegistry {
    private deviceRepository: Repository<DeviceRegistry>;
    
    constructor() {
        this.deviceRepository = AppDataSource.getRepository(DeviceRegistry);
    }
    
    async getDevice(deviceId: string): Promise<DeviceInfo | null> {
        const device = await this.deviceRepository.findOne({
            where: { deviceId }
        });
        
        if (!device) return null;
        
        return {
            id: device.id,
            name: device.name,
            type: device.type,
            priority: device.priority,
            lastSeen: device.lastSeen,
            userId: device.userId
        };
    }
    
    async registerDevice(deviceInfo: Omit<DeviceInfo, 'id'>): Promise<DeviceInfo> {
        const existingDevice = await this.deviceRepository.findOne({
            where: { deviceId: deviceInfo.name, userId: deviceInfo.userId }
        });
        
        if (existingDevice) {
            // Update existing device
            existingDevice.lastSeen = new Date();
            existingDevice.type = deviceInfo.type;
            existingDevice.priority = deviceInfo.priority;
            await this.deviceRepository.save(existingDevice);
            
            return {
                id: existingDevice.id,
                name: existingDevice.name,
                type: existingDevice.type,
                priority: existingDevice.priority,
                lastSeen: existingDevice.lastSeen,
                userId: existingDevice.userId
            };
        }
        
        // Create new device
        const newDevice = this.deviceRepository.create({
            deviceId: deviceInfo.name,
            name: deviceInfo.name,
            type: deviceInfo.type,
            priority: deviceInfo.priority,
            lastSeen: deviceInfo.lastSeen,
            userId: deviceInfo.userId
        });
        
        const savedDevice = await this.deviceRepository.save(newDevice);
        
        return {
            id: savedDevice.id,
            name: savedDevice.name,
            type: savedDevice.type,
            priority: savedDevice.priority,
            lastSeen: savedDevice.lastSeen,
            userId: savedDevice.userId
        };
    }
    
    async updateDevicePriority(deviceId: string, priority: number): Promise<void> {
        await this.deviceRepository.update({ deviceId }, { priority });
    }
    
    async getDevicesForUser(userId: string): Promise<DeviceInfo[]> {
        const devices = await this.deviceRepository.find({
            where: { userId },
            order: { priority: 'DESC', lastSeen: 'DESC' }
        });
        
        return devices.map(device => ({
            id: device.id,
            name: device.name,
            type: device.type,
            priority: device.priority,
            lastSeen: device.lastSeen,
            userId: device.userId
        }));
    }
}

// Haupt-Conflict-Resolver
export class BackendConflictResolver {
    private readonly conflictLog: Repository<ConflictLog>;
    private readonly deviceRegistry: DeviceRegistryService;
    
    constructor() {
        this.conflictLog = AppDataSource.getRepository(ConflictLog);
        this.deviceRegistry = new DeviceRegistryService();
    }
    
    async resolveConflict<T extends BaseEntity>(
        entityType: string,
        localVersion: T,
        remoteVersion: T,
        options: ConflictResolutionOptions
    ): Promise<ConflictResolutionResult<T>> {
        const conflictId = this.generateConflictId(entityType, localVersion.id);
        
        console.log(`🔧 Resolving conflict for ${entityType}:${localVersion.id} with strategy: ${options.strategy}`);
        
        // Protokolliere Konflikt
        const conflict = await this.logConflict({
            id: conflictId,
            entityType,
            entityId: localVersion.id,
            deviceId: options.deviceId || 'unknown',
            strategy: options.strategy,
            localVersion: this.serializeEntity(localVersion),
            remoteVersion: this.serializeEntity(remoteVersion),
            timestamp: new Date(),
            status: 'pending'
        } as ConflictLog);
        
        let resolvedEntity: T;
        let metadata: ConflictMetadata;
        
        try {
            switch (options.strategy) {
                case 'lastWriteWins':
                    ({ resolvedEntity, metadata } = await this.resolveLastWriteWins(
                        localVersion, 
                        remoteVersion
                    ));
                    break;
                    
                case 'fieldLevel':
                    ({ resolvedEntity, metadata } = await this.resolveFieldLevel(
                        localVersion, 
                        remoteVersion
                    ));
                    break;
                    
                case 'devicePriority':
                    ({ resolvedEntity, metadata } = await this.resolveDevicePriority(
                        localVersion, 
                        remoteVersion, 
                        options.deviceId || 'unknown'
                    ));
                    break;
                    
                case 'userChoice':
                    ({ resolvedEntity, metadata } = await this.resolveUserChoice(
                        localVersion, 
                        remoteVersion, 
                        conflictId
                    ));
                    break;
                    
                default:
                    throw new Error(`Unknown conflict resolution strategy: ${options.strategy}`);
            }
            
            // Aktualisiere Konflikt-Log
            await this.updateConflictLog(conflictId, {
                resolution: metadata,
                resolvedAt: new Date(),
                status: 'resolved'
            });
            
            console.log(`✅ Conflict resolved: ${conflictId} - Strategy: ${options.strategy}`);
            
            return {
                resolvedEntity,
                conflictId,
                metadata,
                strategy: options.strategy
            };
            
        } catch (error) {
            // Fehler-Behandlung
            await this.updateConflictLog(conflictId, {
                status: 'pending',
                metadata: { error: error instanceof Error ? error.message : 'Unknown error' }
            });
            
            console.error(`❌ Conflict resolution failed: ${conflictId}`, error);
            throw error;
        }
    }
    
    private async resolveLastWriteWins<T extends BaseEntity>(
        local: T,
        remote: T
    ): Promise<{ resolvedEntity: T; metadata: ConflictMetadata }> {
        const localTimestamp = local.updatedAt || local.createdAt || new Date(0);
        const remoteTimestamp = remote.updatedAt || remote.createdAt || new Date(0);
        
        const winner = remoteTimestamp > localTimestamp ? remote : local;
        const metadata: ConflictMetadata = {
            strategy: 'lastWriteWins',
            winner: winner === local ? 'local' : 'remote',
            localTimestamp,
            remoteTimestamp,
            details: `${winner === local ? 'Local' : 'Remote'} version newer (${winner === local ? localTimestamp : remoteTimestamp})`
        };
        
        console.log(`📅 Last-Write-Wins: ${metadata.winner} version selected`);
        
        return { resolvedEntity: winner, metadata };
    }
    
    private async resolveFieldLevel<T extends BaseEntity>(
        local: T,
        remote: T
    ): Promise<{ resolvedEntity: T; metadata: ConflictMetadata }> {
        const merged = { ...local };
        const changedFields: string[] = [];
        
        const localTimestamp = local.updatedAt || local.createdAt || new Date(0);
        const remoteTimestamp = remote.updatedAt || remote.createdAt || new Date(0);
        
        // Feld-für-Feld-Vergleich
        for (const [field, remoteValue] of Object.entries(remote)) {
            if (['id', 'createdAt'].includes(field)) continue;
            
            const localValue = local[field as keyof T];
            
            if (localValue !== remoteValue) {
                // Nehme neueren Wert pro Feld (vereinfacht)
                if (remoteTimestamp > localTimestamp) {
                    (merged as any)[field] = remoteValue;
                    changedFields.push(field);
                }
            }
        }
        
        // Aktualisiere Timestamp
        (merged as any).updatedAt = new Date();
        
        const metadata: ConflictMetadata = {
            strategy: 'fieldLevel',
            changedFields,
            details: `Field-level merge: ${changedFields.join(', ')}`
        };
        
        console.log(`🔧 Field-Level merge completed: ${changedFields.length} fields changed`);
        
        return { resolvedEntity: merged, metadata };
    }
    
    private async resolveDevicePriority<T extends BaseEntity>(
        local: T,
        remote: T,
        deviceId: string
    ): Promise<{ resolvedEntity: T; metadata: ConflictMetadata }> {
        const deviceInfo = await this.deviceRegistry.getDevice(deviceId);
        const devicePriority = deviceInfo?.priority || 0;
        
        // Höhere Priorität gewinnt (> 5 ist hoch)
        const winner = devicePriority > 5 ? local : remote;
        const metadata: ConflictMetadata = {
            strategy: 'devicePriority',
            winner: winner === local ? 'local' : 'remote',
            devicePriority,
            details: `Device priority: ${devicePriority} (${deviceInfo?.name || 'unknown'})`
        };
        
        console.log(`📱 Device-Priority: ${metadata.winner} wins with priority ${devicePriority}`);
        
        return { resolvedEntity: winner, metadata };
    }
    
    private async resolveUserChoice<T extends BaseEntity>(
        local: T,
        remote: T,
        conflictId: string
    ): Promise<{ resolvedEntity: T; metadata: ConflictMetadata }> {
        // Markiere als pending user choice
        await this.updateConflictLog(conflictId, {
            status: 'pending_user_choice',
            metadata: {
                local: this.serializeEntity(local),
                remote: this.serializeEntity(remote)
            }
        });
        
        // Für jetzt: Default zu Remote (wird später durch User-UI ersetzt)
        const metadata: ConflictMetadata = {
            strategy: 'userChoice',
            status: 'pending',
            details: 'Awaiting user decision - defaulted to remote'
        };
        
        console.log(`👤 User-Choice: Pending user decision for conflict ${conflictId}`);
        
        return { resolvedEntity: remote, metadata };
    }
    
    // Erweiterte Conflict-Detection
    async detectConflict<T extends BaseEntity>(
        local: T,
        remote: T
    ): Promise<ConflictDetectionResult> {
        const localTimestamp = local.updatedAt || local.createdAt || new Date(0);
        const remoteTimestamp = remote.updatedAt || remote.createdAt || new Date(0);
        
        // Zeitstempel-basierte Erkennung
        const timeDifference = Math.abs(localTimestamp.getTime() - remoteTimestamp.getTime());
        const hasTimestampConflict = timeDifference > 1000; // > 1 Sekunde
        
        // Feld-basierte Erkennung
        const conflictedFields = this.findConflictedFields(local, remote);
        
        // Checksummen-Vergleich
        const localChecksum = this.generateChecksum(local);
        const remoteChecksum = this.generateChecksum(remote);
        
        const hasConflict = hasTimestampConflict && conflictedFields.length > 0 && localChecksum !== remoteChecksum;
        
        let conflictType: 'none' | 'data' | 'timestamp' | 'structural' = 'none';
        if (hasConflict) {
            if (conflictedFields.length > 5) {
                conflictType = 'structural';
            } else if (hasTimestampConflict) {
                conflictType = 'timestamp';
            } else {
                conflictType = 'data';
            }
        }
        
        return {
            hasConflict,
            conflictedFields,
            localChecksum,
            remoteChecksum,
            conflictType
        };
    }
    
    // Hilfsmethoden
    private findConflictedFields<T extends BaseEntity>(local: T, remote: T): string[] {
        const conflictedFields: string[] = [];
        
        for (const [field, remoteValue] of Object.entries(remote)) {
            if (['id', 'createdAt', 'updatedAt'].includes(field)) continue;
            
            const localValue = local[field as keyof T];
            if (localValue !== remoteValue) {
                conflictedFields.push(field);
            }
        }
        
        return conflictedFields;
    }
    
    private generateChecksum<T>(entity: T): string {
        const normalized = JSON.stringify(entity, Object.keys(entity as any).sort());
        let hash = 0;
        for (let i = 0; i < normalized.length; i++) {
            const char = normalized.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash; // Convert to 32-bit integer
        }
        return hash.toString(16);
    }
    
    private async logConflict(conflict: ConflictLog): Promise<ConflictLog> {
        return await this.conflictLog.save(conflict);
    }
    
    private async updateConflictLog(
        conflictId: string, 
        updates: Partial<ConflictLog>
    ): Promise<void> {
        await this.conflictLog.update({ id: conflictId }, updates);
    }
    
    private generateConflictId(entityType: string, entityId: string): string {
        return `conflict_${entityType}_${entityId}_${Date.now()}`;
    }
    
    private serializeEntity<T>(entity: T): string {
        return JSON.stringify(entity, null, 2);
    }
} 