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
};
exports.SyncResolver = SyncResolver;
__decorate([
    (0, type_graphql_1.Authorized)(),
    (0, type_graphql_1.Query)(() => SyncResponse_1.SyncResponse),
    __param(0, (0, type_graphql_1.Arg)("lastSyncedAt", () => Date)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Date, Object]),
    __metadata("design:returntype", Promise)
], SyncResolver.prototype, "sync", null);
exports.SyncResolver = SyncResolver = __decorate([
    (0, type_graphql_1.Resolver)()
], SyncResolver);
