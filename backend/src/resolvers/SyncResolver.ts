import { Resolver, Query, Arg, Ctx, Authorized } from "type-graphql";
import { SyncResponse, DeletedIds } from "./types/SyncResponse";
import { AppDataSource } from "../utils/database";
import { Trip } from "../entities/Trip";
import { Memory } from "../entities/Memory";
import { Tag } from "../entities/Tag";
import { TagCategory } from "../entities/TagCategory";
import { MediaItem } from "../entities/MediaItem";
import { GPXTrack } from "../entities/GPXTrack";
import { BucketListItem } from "../entities/BucketListItem";
import { DeletionLog } from "../entities/DeletionLog";
import { MoreThan, In } from "typeorm";
import { MyContext } from "..";
import { TripMembership } from "../entities/TripMembership";
import { AuthenticationError } from "apollo-server-express";

@Resolver()
export class SyncResolver {
    @Authorized()
    @Query(() => SyncResponse)
    async sync(
        @Arg("lastSyncedAt", () => Date) lastSyncedAt: Date,
        @Ctx() { userId }: MyContext
    ): Promise<SyncResponse> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to sync.");
        }
        
        const now = new Date();

        const memberships = await AppDataSource.getRepository(TripMembership).find({ 
            where: { user: { id: userId } },
            relations: ["trip"] 
        });
        const accessibleTripIds = memberships.map(m => m.trip.id);
        
        if (accessibleTripIds.length === 0) {
            // User is not part of any trip, can still sync personal items
            const bucketListItems = await AppDataSource.getRepository(BucketListItem).findBy({ updatedAt: MoreThan(lastSyncedAt), creator: { id: userId } });
            const deleted = await AppDataSource.getRepository(DeletionLog).findBy({ deletedAt: MoreThan(lastSyncedAt), ownerId: userId });
             const deletedIds: DeletedIds = {
                trips: [], memories: [], tags: [], tagCategories: [], mediaItems: [], gpxTracks: [],
                bucketListItems: deleted.filter(d => d.entityType === 'BucketListItem').map(d => d.entityId),
            };
            const tags = await AppDataSource.getRepository(Tag).findBy({ updatedAt: MoreThan(lastSyncedAt) });
            const tagCategories = await AppDataSource.getRepository(TagCategory).findBy({ updatedAt: MoreThan(lastSyncedAt) });

            return {
                trips: [], memories: [], mediaItems: [], gpxTracks: [],
                tags, tagCategories, bucketListItems,
                deleted: deletedIds,
                serverTimestamp: now,
            };
        }

        const trips = await AppDataSource.getRepository(Trip).findBy({ id: In(accessibleTripIds), updatedAt: MoreThan(lastSyncedAt) });
        const memories = await AppDataSource.getRepository(Memory).findBy({ trip: { id: In(accessibleTripIds) }, updatedAt: MoreThan(lastSyncedAt) });
        const mediaItems = await AppDataSource.getRepository(MediaItem).findBy({ memory: { trip: { id: In(accessibleTripIds) } }, updatedAt: MoreThan(lastSyncedAt) });
        const gpxTracks = await AppDataSource.getRepository(GPXTrack).findBy({ trip: { id: In(accessibleTripIds) }, updatedAt: MoreThan(lastSyncedAt) });
        const bucketListItems = await AppDataSource.getRepository(BucketListItem).findBy({ creator: { id: userId }, updatedAt: MoreThan(lastSyncedAt) });
        const tags = await AppDataSource.getRepository(Tag).findBy({ updatedAt: MoreThan(lastSyncedAt) });
        const tagCategories = await AppDataSource.getRepository(TagCategory).findBy({ updatedAt: MoreThan(lastSyncedAt) });

        const deleted = await AppDataSource.getRepository(DeletionLog).find({
            where: [
                { deletedAt: MoreThan(lastSyncedAt), tripId: In(accessibleTripIds) },
                { deletedAt: MoreThan(lastSyncedAt), ownerId: userId },
                { deletedAt: MoreThan(lastSyncedAt), tripId: undefined, ownerId: undefined }
            ]
        });

        const deletedIds: DeletedIds = {
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
} 