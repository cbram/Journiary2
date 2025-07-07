import { Resolver, Query, Arg, Ctx, Authorized, Mutation, ObjectType, Field, ID, InputType } from "type-graphql";
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
import { generatePresignedGetUrl, generatePresignedPutUrl } from "../utils/minio";

@InputType()
class UploadRequest {
    @Field(() => ID)
    entityId!: string;

    @Field()
    entityType!: string;

    @Field()
    objectName!: string;

    @Field()
    mimeType!: string;
}

@ObjectType()
class FileDownloadUrl {
    @Field(() => ID)
    entityId!: string;

    @Field()
    entityType!: string;

    @Field()
    objectName!: string;

    @Field()
    downloadUrl!: string;

    @Field(() => Number)
    expiresIn!: number;
}

@ObjectType()
class FileSyncResponse {
    @Field(() => [FileDownloadUrl])
    downloadUrls!: FileDownloadUrl[];

    @Field(() => Date)
    generatedAt!: Date;
}

@ObjectType()
class BulkUploadUrl {
    @Field(() => ID)
    entityId!: string;

    @Field()
    entityType!: string;

    @Field()
    objectName!: string;

    @Field()
    uploadUrl!: string;

    @Field(() => Number)
    expiresIn!: number;
}

@ObjectType()
class BulkUploadResponse {
    @Field(() => [BulkUploadUrl])
    uploadUrls!: BulkUploadUrl[];

    @Field(() => Date)
    generatedAt!: Date;
}

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

    @Authorized()
    @Query(() => FileSyncResponse, { description: "Generate batch download URLs for media files and GPX tracks" })
    async generateBatchDownloadUrls(
        @Ctx() { userId }: MyContext,
        @Arg("mediaItemIds", () => [ID], { nullable: true }) mediaItemIds?: string[],
        @Arg("gpxTrackIds", () => [ID], { nullable: true }) gpxTrackIds?: string[],
        @Arg("expiresIn", () => Number, { nullable: true }) expiresIn?: number
    ): Promise<FileSyncResponse> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to generate download URLs.");
        }

        const downloadUrls: FileDownloadUrl[] = [];
        const now = new Date();
        const urlExpiresIn = expiresIn || 3600;

        // Process MediaItems
        if (mediaItemIds && mediaItemIds.length > 0) {
            const mediaItems = await AppDataSource.getRepository(MediaItem).find({
                where: { id: In(mediaItemIds) },
                relations: ["memory", "memory.trip"]
            });

            for (const mediaItem of mediaItems) {
                // Check access permissions
                const memberships = await AppDataSource.getRepository(TripMembership).find({
                    where: { user: { id: userId }, trip: { id: mediaItem.memory.trip.id } }
                });
                if (memberships.length === 0) continue;

                // Generate download URL for main file
                if (mediaItem.objectName) {
                    try {
                        const downloadUrl = await generatePresignedGetUrl(mediaItem.objectName, urlExpiresIn);
                        downloadUrls.push({
                            entityId: mediaItem.id,
                            entityType: 'MediaItem',
                            objectName: mediaItem.objectName,
                            downloadUrl,
                            expiresIn: urlExpiresIn
                        });
                    } catch (error) {
                        console.error(`Failed to generate download URL for MediaItem ${mediaItem.id}:`, error);
                    }
                }

                // Generate download URL for thumbnail
                if (mediaItem.thumbnailObjectName) {
                    try {
                        const downloadUrl = await generatePresignedGetUrl(mediaItem.thumbnailObjectName, urlExpiresIn);
                        downloadUrls.push({
                            entityId: mediaItem.id,
                            entityType: 'MediaItemThumbnail',
                            objectName: mediaItem.thumbnailObjectName,
                            downloadUrl,
                            expiresIn: urlExpiresIn
                        });
                    } catch (error) {
                        console.error(`Failed to generate thumbnail download URL for MediaItem ${mediaItem.id}:`, error);
                    }
                }
            }
        }

        // Process GPXTracks
        if (gpxTrackIds && gpxTrackIds.length > 0) {
            const gpxTracks = await AppDataSource.getRepository(GPXTrack).find({
                where: { id: In(gpxTrackIds) },
                relations: ["trip"]
            });

            for (const gpxTrack of gpxTracks) {
                // Check access permissions
                const memberships = await AppDataSource.getRepository(TripMembership).find({
                    where: { user: { id: userId }, trip: { id: gpxTrack.trip.id } }
                });
                if (memberships.length === 0) continue;

                // Generate download URL for GPX file
                if (gpxTrack.gpxFileObjectName) {
                    try {
                        const downloadUrl = await generatePresignedGetUrl(gpxTrack.gpxFileObjectName, urlExpiresIn);
                        downloadUrls.push({
                            entityId: gpxTrack.id,
                            entityType: 'GPXTrack',
                            objectName: gpxTrack.gpxFileObjectName,
                            downloadUrl,
                            expiresIn: urlExpiresIn
                        });
                    } catch (error) {
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

    @Authorized()
    @Mutation(() => BulkUploadResponse, { description: "Generate batch upload URLs for media files and GPX tracks" })
    async generateBatchUploadUrls(
        @Arg("uploadRequests", () => [UploadRequest]) uploadRequests: UploadRequest[],
        @Ctx() { userId }: MyContext,
        @Arg("expiresIn", () => Number, { nullable: true }) expiresIn?: number
    ): Promise<BulkUploadResponse> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to generate upload URLs.");
        }

        const uploadUrls: BulkUploadUrl[] = [];
        const now = new Date();
        const urlExpiresIn = expiresIn || 3600;

        for (const request of uploadRequests) {
            try {
                const uploadUrl = await generatePresignedPutUrl(request.objectName, request.mimeType, urlExpiresIn);
                uploadUrls.push({
                    entityId: request.entityId,
                    entityType: request.entityType,
                    objectName: request.objectName,
                    uploadUrl,
                    expiresIn: urlExpiresIn
                });
            } catch (error) {
                console.error(`Failed to generate upload URL for ${request.entityType} ${request.entityId}:`, error);
            }
        }

        return {
            uploadUrls,
            generatedAt: now
        };
    }

    @Authorized()
    @Mutation(() => Boolean, { description: "Mark file upload as completed and update entity" })
    async markFileUploadComplete(
        @Arg("entityId", () => ID) entityId: string,
        @Arg("entityType") entityType: string,
        @Arg("objectName") objectName: string,
        @Ctx() { userId }: MyContext
    ): Promise<boolean> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to mark uploads complete.");
        }

        try {
            switch (entityType) {
                case 'MediaItem':
                    const mediaItem = await AppDataSource.getRepository(MediaItem).findOne({
                        where: { id: entityId },
                        relations: ["memory", "memory.trip"]
                    });
                    if (!mediaItem) throw new Error("MediaItem not found");

                    // Check permissions
                    const memberships = await AppDataSource.getRepository(TripMembership).find({
                        where: { user: { id: userId }, trip: { id: mediaItem.memory.trip.id } }
                    });
                    if (memberships.length === 0) throw new Error("Access denied");

                    // Update objectName if needed
                    if (mediaItem.objectName !== objectName) {
                        mediaItem.objectName = objectName;
                        await AppDataSource.getRepository(MediaItem).save(mediaItem);
                    }
                    break;

                case 'GPXTrack':
                    const gpxTrack = await AppDataSource.getRepository(GPXTrack).findOne({
                        where: { id: entityId },
                        relations: ["trip"]
                    });
                    if (!gpxTrack) throw new Error("GPXTrack not found");

                    // Check permissions
                    const gpxMemberships = await AppDataSource.getRepository(TripMembership).find({
                        where: { user: { id: userId }, trip: { id: gpxTrack.trip.id } }
                    });
                    if (gpxMemberships.length === 0) throw new Error("Access denied");

                    // Update objectName if needed
                    if (gpxTrack.gpxFileObjectName !== objectName) {
                        gpxTrack.gpxFileObjectName = objectName;
                        await AppDataSource.getRepository(GPXTrack).save(gpxTrack);
                    }
                    break;

                default:
                    throw new Error(`Unsupported entity type: ${entityType}`);
            }

            return true;
        } catch (error) {
            console.error(`Failed to mark upload complete for ${entityType} ${entityId}:`, error);
            return false;
        }
    }
} 