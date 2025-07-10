"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.BackendConflictResolver = exports.DeviceRegistryService = void 0;
const database_1 = require("../utils/database");
const ConflictTypes_1 = require("../types/ConflictTypes");
// Device-Registry-Service
class DeviceRegistryService {
    constructor() {
        this.deviceRepository = database_1.AppDataSource.getRepository(ConflictTypes_1.DeviceRegistry);
    }
    async getDevice(deviceId) {
        const device = await this.deviceRepository.findOne({
            where: { deviceId }
        });
        if (!device)
            return null;
        return {
            id: device.id,
            name: device.name,
            type: device.type,
            priority: device.priority,
            lastSeen: device.lastSeen,
            userId: device.userId
        };
    }
    async registerDevice(deviceInfo) {
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
    async updateDevicePriority(deviceId, priority) {
        await this.deviceRepository.update({ deviceId }, { priority });
    }
    async getDevicesForUser(userId) {
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
exports.DeviceRegistryService = DeviceRegistryService;
// Haupt-Conflict-Resolver
class BackendConflictResolver {
    constructor() {
        this.conflictLog = database_1.AppDataSource.getRepository(ConflictTypes_1.ConflictLog);
        this.deviceRegistry = new DeviceRegistryService();
    }
    async resolveConflict(entityType, localVersion, remoteVersion, options) {
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
        });
        let resolvedEntity;
        let metadata;
        try {
            switch (options.strategy) {
                case 'lastWriteWins':
                    ({ resolvedEntity, metadata } = await this.resolveLastWriteWins(localVersion, remoteVersion));
                    break;
                case 'fieldLevel':
                    ({ resolvedEntity, metadata } = await this.resolveFieldLevel(localVersion, remoteVersion));
                    break;
                case 'devicePriority':
                    ({ resolvedEntity, metadata } = await this.resolveDevicePriority(localVersion, remoteVersion, options.deviceId || 'unknown'));
                    break;
                case 'userChoice':
                    ({ resolvedEntity, metadata } = await this.resolveUserChoice(localVersion, remoteVersion, conflictId));
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
        }
        catch (error) {
            // Fehler-Behandlung
            await this.updateConflictLog(conflictId, {
                status: 'pending',
                metadata: { error: error instanceof Error ? error.message : 'Unknown error' }
            });
            console.error(`❌ Conflict resolution failed: ${conflictId}`, error);
            throw error;
        }
    }
    async resolveLastWriteWins(local, remote) {
        const localTimestamp = local.updatedAt || local.createdAt || new Date(0);
        const remoteTimestamp = remote.updatedAt || remote.createdAt || new Date(0);
        const winner = remoteTimestamp > localTimestamp ? remote : local;
        const metadata = {
            strategy: 'lastWriteWins',
            winner: winner === local ? 'local' : 'remote',
            localTimestamp,
            remoteTimestamp,
            details: `${winner === local ? 'Local' : 'Remote'} version newer (${winner === local ? localTimestamp : remoteTimestamp})`
        };
        console.log(`📅 Last-Write-Wins: ${metadata.winner} version selected`);
        return { resolvedEntity: winner, metadata };
    }
    async resolveFieldLevel(local, remote) {
        const merged = { ...local };
        const changedFields = [];
        const localTimestamp = local.updatedAt || local.createdAt || new Date(0);
        const remoteTimestamp = remote.updatedAt || remote.createdAt || new Date(0);
        // Feld-für-Feld-Vergleich
        for (const [field, remoteValue] of Object.entries(remote)) {
            if (['id', 'createdAt'].includes(field))
                continue;
            const localValue = local[field];
            if (localValue !== remoteValue) {
                // Nehme neueren Wert pro Feld (vereinfacht)
                if (remoteTimestamp > localTimestamp) {
                    merged[field] = remoteValue;
                    changedFields.push(field);
                }
            }
        }
        // Aktualisiere Timestamp
        merged.updatedAt = new Date();
        const metadata = {
            strategy: 'fieldLevel',
            changedFields,
            details: `Field-level merge: ${changedFields.join(', ')}`
        };
        console.log(`🔧 Field-Level merge completed: ${changedFields.length} fields changed`);
        return { resolvedEntity: merged, metadata };
    }
    async resolveDevicePriority(local, remote, deviceId) {
        const deviceInfo = await this.deviceRegistry.getDevice(deviceId);
        const devicePriority = deviceInfo?.priority || 0;
        // Höhere Priorität gewinnt (> 5 ist hoch)
        const winner = devicePriority > 5 ? local : remote;
        const metadata = {
            strategy: 'devicePriority',
            winner: winner === local ? 'local' : 'remote',
            devicePriority,
            details: `Device priority: ${devicePriority} (${deviceInfo?.name || 'unknown'})`
        };
        console.log(`📱 Device-Priority: ${metadata.winner} wins with priority ${devicePriority}`);
        return { resolvedEntity: winner, metadata };
    }
    async resolveUserChoice(local, remote, conflictId) {
        // Markiere als pending user choice
        await this.updateConflictLog(conflictId, {
            status: 'pending_user_choice',
            metadata: {
                local: this.serializeEntity(local),
                remote: this.serializeEntity(remote)
            }
        });
        // Für jetzt: Default zu Remote (wird später durch User-UI ersetzt)
        const metadata = {
            strategy: 'userChoice',
            status: 'pending',
            details: 'Awaiting user decision - defaulted to remote'
        };
        console.log(`👤 User-Choice: Pending user decision for conflict ${conflictId}`);
        return { resolvedEntity: remote, metadata };
    }
    // Erweiterte Conflict-Detection
    async detectConflict(local, remote) {
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
        let conflictType = 'none';
        if (hasConflict) {
            if (conflictedFields.length > 5) {
                conflictType = 'structural';
            }
            else if (hasTimestampConflict) {
                conflictType = 'timestamp';
            }
            else {
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
    findConflictedFields(local, remote) {
        const conflictedFields = [];
        for (const [field, remoteValue] of Object.entries(remote)) {
            if (['id', 'createdAt', 'updatedAt'].includes(field))
                continue;
            const localValue = local[field];
            if (localValue !== remoteValue) {
                conflictedFields.push(field);
            }
        }
        return conflictedFields;
    }
    generateChecksum(entity) {
        const normalized = JSON.stringify(entity, Object.keys(entity).sort());
        let hash = 0;
        for (let i = 0; i < normalized.length; i++) {
            const char = normalized.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash; // Convert to 32-bit integer
        }
        return hash.toString(16);
    }
    async logConflict(conflict) {
        return await this.conflictLog.save(conflict);
    }
    async updateConflictLog(conflictId, updates) {
        await this.conflictLog.update({ id: conflictId }, updates);
    }
    generateConflictId(entityType, entityId) {
        return `conflict_${entityType}_${entityId}_${Date.now()}`;
    }
    serializeEntity(entity) {
        return JSON.stringify(entity, null, 2);
    }
}
exports.BackendConflictResolver = BackendConflictResolver;
