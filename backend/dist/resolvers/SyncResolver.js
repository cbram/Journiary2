"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SyncResolver = void 0;
const type_graphql_1 = require("type-graphql");
const SyncResponse_1 = require("./types/SyncResponse");
const database_1 = require("../utils/database");
const Trip_1 = require("../entities/Trip");
const Memory_1 = require("../entities/Memory");
const Tag_1 = require("../entities/Tag");
const TagCategory_1 = require("../entities/TagCategory");
const MediaItem_1 = require("../entities/MediaItem");
const GPXTrack_1 = require("../entities/GPXTrack");
const BucketListItem_1 = require("../entities/BucketListItem");
const DeletionLog_1 = require("../entities/DeletionLog");
const typeorm_1 = require("typeorm");
const TripMembership_1 = require("../entities/TripMembership");
const apollo_server_express_1 = require("apollo-server-express");
const minio_1 = require("../utils/minio");
let UploadRequest = class UploadRequest {
};
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    __metadata("design:type", String)
], UploadRequest.prototype, "entityId", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], UploadRequest.prototype, "entityType", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], UploadRequest.prototype, "objectName", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], UploadRequest.prototype, "mimeType", void 0);
UploadRequest = __decorate([
    (0, type_graphql_1.InputType)()
], UploadRequest);
let FileDownloadUrl = class FileDownloadUrl {
};
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    __metadata("design:type", String)
], FileDownloadUrl.prototype, "entityId", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], FileDownloadUrl.prototype, "entityType", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], FileDownloadUrl.prototype, "objectName", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], FileDownloadUrl.prototype, "downloadUrl", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Number),
    __metadata("design:type", Number)
], FileDownloadUrl.prototype, "expiresIn", void 0);
FileDownloadUrl = __decorate([
    (0, type_graphql_1.ObjectType)()
], FileDownloadUrl);
let FileSyncResponse = class FileSyncResponse {
};
__decorate([
    (0, type_graphql_1.Field)(() => [FileDownloadUrl]),
    __metadata("design:type", Array)
], FileSyncResponse.prototype, "downloadUrls", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Date),
    __metadata("design:type", Date)
], FileSyncResponse.prototype, "generatedAt", void 0);
FileSyncResponse = __decorate([
    (0, type_graphql_1.ObjectType)()
], FileSyncResponse);
let BulkUploadUrl = class BulkUploadUrl {
};
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    __metadata("design:type", String)
], BulkUploadUrl.prototype, "entityId", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], BulkUploadUrl.prototype, "entityType", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], BulkUploadUrl.prototype, "objectName", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], BulkUploadUrl.prototype, "uploadUrl", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Number),
    __metadata("design:type", Number)
], BulkUploadUrl.prototype, "expiresIn", void 0);
BulkUploadUrl = __decorate([
    (0, type_graphql_1.ObjectType)()
], BulkUploadUrl);
let BulkUploadResponse = class BulkUploadResponse {
};
__decorate([
    (0, type_graphql_1.Field)(() => [BulkUploadUrl]),
    __metadata("design:type", Array)
], BulkUploadResponse.prototype, "uploadUrls", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Date),
    __metadata("design:type", Date)
], BulkUploadResponse.prototype, "generatedAt", void 0);
BulkUploadResponse = __decorate([
    (0, type_graphql_1.ObjectType)()
], BulkUploadResponse);
let SyncResolver = class SyncResolver {
    async sync(lastSyncedAt, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to sync.");
        }
        const now = new Date();
        const memberships = await database_1.AppDataSource.getRepository(TripMembership_1.TripMembership).find({
            where: { user: { id: userId } },
            relations: ["trip"]
        });
        const accessibleTripIds = memberships.map(m => m.trip.id);
        if (accessibleTripIds.length === 0) {
            // User is not part of any trip, can still sync personal items
            const bucketListItems = await database_1.AppDataSource.getRepository(BucketListItem_1.BucketListItem).findBy({ updatedAt: (0, typeorm_1.MoreThan)(lastSyncedAt), creator: { id: userId } });
            const deleted = await database_1.AppDataSource.getRepository(DeletionLog_1.DeletionLog).findBy({ deletedAt: (0, typeorm_1.MoreThan)(lastSyncedAt), ownerId: userId });
            const deletedIds = {
                trips: [], memories: [], tags: [], tagCategories: [], mediaItems: [], gpxTracks: [],
                bucketListItems: deleted.filter(d => d.entityType === 'BucketListItem').map(d => d.entityId),
            };
            const tags = await database_1.AppDataSource.getRepository(Tag_1.Tag).findBy({ updatedAt: (0, typeorm_1.MoreThan)(lastSyncedAt) });
            const tagCategories = await database_1.AppDataSource.getRepository(TagCategory_1.TagCategory).findBy({ updatedAt: (0, typeorm_1.MoreThan)(lastSyncedAt) });
            return {
                trips: [], memories: [], mediaItems: [], gpxTracks: [],
                tags, tagCategories, bucketListItems,
                deleted: deletedIds,
                serverTimestamp: now,
            };
        }
        const trips = await database_1.AppDataSource.getRepository(Trip_1.Trip).findBy({ id: (0, typeorm_1.In)(accessibleTripIds), updatedAt: (0, typeorm_1.MoreThan)(lastSyncedAt) });
        const memories = await database_1.AppDataSource.getRepository(Memory_1.Memory).findBy({ trip: { id: (0, typeorm_1.In)(accessibleTripIds) }, updatedAt: (0, typeorm_1.MoreThan)(lastSyncedAt) });
        const mediaItems = await database_1.AppDataSource.getRepository(MediaItem_1.MediaItem).findBy({ memory: { trip: { id: (0, typeorm_1.In)(accessibleTripIds) } }, updatedAt: (0, typeorm_1.MoreThan)(lastSyncedAt) });
        const gpxTracks = await database_1.AppDataSource.getRepository(GPXTrack_1.GPXTrack).findBy({ trip: { id: (0, typeorm_1.In)(accessibleTripIds) }, updatedAt: (0, typeorm_1.MoreThan)(lastSyncedAt) });
        const bucketListItems = await database_1.AppDataSource.getRepository(BucketListItem_1.BucketListItem).findBy({ creator: { id: userId }, updatedAt: (0, typeorm_1.MoreThan)(lastSyncedAt) });
        const tags = await database_1.AppDataSource.getRepository(Tag_1.Tag).findBy({ updatedAt: (0, typeorm_1.MoreThan)(lastSyncedAt) });
        const tagCategories = await database_1.AppDataSource.getRepository(TagCategory_1.TagCategory).findBy({ updatedAt: (0, typeorm_1.MoreThan)(lastSyncedAt) });
        const deleted = await database_1.AppDataSource.getRepository(DeletionLog_1.DeletionLog).find({
            where: [
                { deletedAt: (0, typeorm_1.MoreThan)(lastSyncedAt), tripId: (0, typeorm_1.In)(accessibleTripIds) },
                { deletedAt: (0, typeorm_1.MoreThan)(lastSyncedAt), ownerId: userId },
                { deletedAt: (0, typeorm_1.MoreThan)(lastSyncedAt), tripId: undefined, ownerId: undefined }
            ]
        });
        const deletedIds = {
            trips: deleted.filter(d => d.entityType === 'Trip').map(d => d.entityId),
            memories: deleted.filter(d => d.entityType === 'Memory').map(d => d.entityId),
            mediaItems: deleted.filter(d => d.entityType === 'MediaItem').map(d => d.entityId),
            gpxTracks: deleted.filter(d => d.entityType === 'GPXTrack').map(d => d.entityId),
            bucketListItems: deleted.filter(d => d.entityType === 'BucketListItem').map(d => d.entityId),
            tags: deleted.filter(d => d.entityType === 'Tag').map(d => d.entityId),
            tagCategories: deleted.filter(d => d.entityType === 'TagCategory').map(d => d.entityId),
        };
        return {
            trips,
            memories,
            tags,
            tagCategories,
            mediaItems,
            gpxTracks,
            bucketListItems,
            deleted: deletedIds,
            serverTimestamp: now,
        };
    }
    async generateBatchDownloadUrls({ userId }, mediaItemIds, gpxTrackIds, expiresIn) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to generate download URLs.");
        }
        const downloadUrls = [];
        const now = new Date();
        const urlExpiresIn = expiresIn || 3600;
        // Process MediaItems
        if (mediaItemIds && mediaItemIds.length > 0) {
            const mediaItems = await database_1.AppDataSource.getRepository(MediaItem_1.MediaItem).find({
                where: { id: (0, typeorm_1.In)(mediaItemIds) },
                relations: ["memory", "memory.trip"]
            });
            for (const mediaItem of mediaItems) {
                // Check access permissions
                const memberships = await database_1.AppDataSource.getRepository(TripMembership_1.TripMembership).find({
                    where: { user: { id: userId }, trip: { id: mediaItem.memory.trip.id } }
                });
                if (memberships.length === 0)
                    continue;
                // Generate download URL for main file
                if (mediaItem.objectName) {
                    try {
                        const downloadUrl = await (0, minio_1.generatePresignedGetUrl)(mediaItem.objectName, urlExpiresIn);
                        downloadUrls.push({
                            entityId: mediaItem.id,
                            entityType: 'MediaItem',
                            objectName: mediaItem.objectName,
                            downloadUrl,
                            expiresIn: urlExpiresIn
                        });
                    }
                    catch (error) {
                        console.error(`Failed to generate download URL for MediaItem ${mediaItem.id}:`, error);
                    }
                }
                // Generate download URL for thumbnail
                if (mediaItem.thumbnailObjectName) {
                    try {
                        const downloadUrl = await (0, minio_1.generatePresignedGetUrl)(mediaItem.thumbnailObjectName, urlExpiresIn);
                        downloadUrls.push({
                            entityId: mediaItem.id,
                            entityType: 'MediaItemThumbnail',
                            objectName: mediaItem.thumbnailObjectName,
                            downloadUrl,
                            expiresIn: urlExpiresIn
                        });
                    }
                    catch (error) {
                        console.error(`Failed to generate thumbnail download URL for MediaItem ${mediaItem.id}:`, error);
                    }
                }
            }
        }
        // Process GPXTracks
        if (gpxTrackIds && gpxTrackIds.length > 0) {
            const gpxTracks = await database_1.AppDataSource.getRepository(GPXTrack_1.GPXTrack).find({
                where: { id: (0, typeorm_1.In)(gpxTrackIds) },
                relations: ["trip"]
            });
            for (const gpxTrack of gpxTracks) {
                // Check access permissions
                const memberships = await database_1.AppDataSource.getRepository(TripMembership_1.TripMembership).find({
                    where: { user: { id: userId }, trip: { id: gpxTrack.trip.id } }
                });
                if (memberships.length === 0)
                    continue;
                // Generate download URL for GPX file
                if (gpxTrack.gpxFileObjectName) {
                    try {
                        const downloadUrl = await (0, minio_1.generatePresignedGetUrl)(gpxTrack.gpxFileObjectName, urlExpiresIn);
                        downloadUrls.push({
                            entityId: gpxTrack.id,
                            entityType: 'GPXTrack',
                            objectName: gpxTrack.gpxFileObjectName,
                            downloadUrl,
                            expiresIn: urlExpiresIn
                        });
                    }
                    catch (error) {
                        console.error(`Failed to generate download URL for GPXTrack ${gpxTrack.id}:`, error);
                    }
                }
            }
        }
        return {
            downloadUrls,
            generatedAt: now
        };
    }
    async generateBatchUploadUrls(uploadRequests, { userId }, expiresIn) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to generate upload URLs.");
        }
        const uploadUrls = [];
        const now = new Date();
        const urlExpiresIn = expiresIn || 3600;
        for (const request of uploadRequests) {
            try {
                const uploadUrl = await (0, minio_1.generatePresignedPutUrl)(request.objectName, request.mimeType, urlExpiresIn);
                uploadUrls.push({
                    entityId: request.entityId,
                    entityType: request.entityType,
                    objectName: request.objectName,
                    uploadUrl,
                    expiresIn: urlExpiresIn
                });
            }
            catch (error) {
                console.error(`Failed to generate upload URL for ${request.entityType} ${request.entityId}:`, error);
            }
        }
        return {
            uploadUrls,
            generatedAt: now
        };
    }
    async markFileUploadComplete(entityId, entityType, objectName, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to mark uploads complete.");
        }
        try {
            switch (entityType) {
                case 'MediaItem':
                    const mediaItem = await database_1.AppDataSource.getRepository(MediaItem_1.MediaItem).findOne({
                        where: { id: entityId },
                        relations: ["memory", "memory.trip"]
                    });
                    if (!mediaItem)
                        throw new Error("MediaItem not found");
                    // Check permissions
                    const memberships = await database_1.AppDataSource.getRepository(TripMembership_1.TripMembership).find({
                        where: { user: { id: userId }, trip: { id: mediaItem.memory.trip.id } }
                    });
                    if (memberships.length === 0)
                        throw new Error("Access denied");
                    // Update objectName if needed
                    if (mediaItem.objectName !== objectName) {
                        mediaItem.objectName = objectName;
                        await database_1.AppDataSource.getRepository(MediaItem_1.MediaItem).save(mediaItem);
                    }
                    break;
                case 'GPXTrack':
                    const gpxTrack = await database_1.AppDataSource.getRepository(GPXTrack_1.GPXTrack).findOne({
                        where: { id: entityId },
                        relations: ["trip"]
                    });
                    if (!gpxTrack)
                        throw new Error("GPXTrack not found");
                    // Check permissions
                    const gpxMemberships = await database_1.AppDataSource.getRepository(TripMembership_1.TripMembership).find({
                        where: { user: { id: userId }, trip: { id: gpxTrack.trip.id } }
                    });
                    if (gpxMemberships.length === 0)
                        throw new Error("Access denied");
                    // Update objectName if needed
                    if (gpxTrack.gpxFileObjectName !== objectName) {
                        gpxTrack.gpxFileObjectName = objectName;
                        await database_1.AppDataSource.getRepository(GPXTrack_1.GPXTrack).save(gpxTrack);
                    }
                    break;
                default:
                    throw new Error(`Unsupported entity type: ${entityType}`);
            }
            return true;
        }
        catch (error) {
            console.error(`Failed to mark upload complete for ${entityType} ${entityId}:`, error);
            return false;
        }
    }
};
__decorate([
    (0, type_graphql_1.Authorized)(),
    (0, type_graphql_1.Query)(() => SyncResponse_1.SyncResponse),
    __param(0, (0, type_graphql_1.Arg)("lastSyncedAt", () => Date)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Date, Object]),
    __metadata("design:returntype", Promise)
], SyncResolver.prototype, "sync", null);
__decorate([
    (0, type_graphql_1.Authorized)(),
    (0, type_graphql_1.Query)(() => FileSyncResponse, { description: "Generate batch download URLs for media files and GPX tracks" }),
    __param(0, (0, type_graphql_1.Ctx)()),
    __param(1, (0, type_graphql_1.Arg)("mediaItemIds", () => [type_graphql_1.ID], { nullable: true })),
    __param(2, (0, type_graphql_1.Arg)("gpxTrackIds", () => [type_graphql_1.ID], { nullable: true })),
    __param(3, (0, type_graphql_1.Arg)("expiresIn", () => Number, { nullable: true })),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Array, Array, Number]),
    __metadata("design:returntype", Promise)
], SyncResolver.prototype, "generateBatchDownloadUrls", null);
__decorate([
    (0, type_graphql_1.Authorized)(),
    (0, type_graphql_1.Mutation)(() => BulkUploadResponse, { description: "Generate batch upload URLs for media files and GPX tracks" }),
    __param(0, (0, type_graphql_1.Arg)("uploadRequests", () => [UploadRequest])),
    __param(1, (0, type_graphql_1.Ctx)()),
    __param(2, (0, type_graphql_1.Arg)("expiresIn", () => Number, { nullable: true })),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Array, Object, Number]),
    __metadata("design:returntype", Promise)
], SyncResolver.prototype, "generateBatchUploadUrls", null);
__decorate([
    (0, type_graphql_1.Authorized)(),
    (0, type_graphql_1.Mutation)(() => Boolean, { description: "Mark file upload as completed and update entity" }),
    __param(0, (0, type_graphql_1.Arg)("entityId", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Arg)("entityType")),
    __param(2, (0, type_graphql_1.Arg)("objectName")),
    __param(3, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, Object]),
    __metadata("design:returntype", Promise)
], SyncResolver.prototype, "markFileUploadComplete", null);
SyncResolver = __decorate([
    (0, type_graphql_1.Resolver)()
], SyncResolver);
exports.SyncResolver = SyncResolver;
