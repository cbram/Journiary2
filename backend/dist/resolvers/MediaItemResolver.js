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
exports.MediaItemResolver = void 0;
const type_graphql_1 = require("type-graphql");
const MediaItem_1 = require("../entities/MediaItem");
const MediaItemInput_1 = require("../entities/MediaItemInput");
const UpdateMediaItemInput_1 = require("../entities/UpdateMediaItemInput");
const database_1 = require("../utils/database");
const minio_1 = require("../utils/minio");
const Memory_1 = require("../entities/Memory");
const PresignedUrlResponse_1 = require("./types/PresignedUrlResponse");
const crypto_1 = require("crypto");
const apollo_server_express_1 = require("apollo-server-express");
const auth_1 = require("../utils/auth");
const TripMembership_1 = require("../entities/TripMembership");
const type_graphql_2 = require("type-graphql");
const DeletionLog_1 = require("../entities/DeletionLog");
let MediaItemResolver = class MediaItemResolver {
    async getPresignedUploadUrl(filename, contentType, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        const fileExtension = filename.split(".").pop() || "unknown";
        const objectName = `media/${(0, crypto_1.randomUUID)()}.${fileExtension}`;
        try {
            const uploadUrl = await (0, minio_1.generatePresignedPutUrl)(objectName, contentType);
            return { uploadUrl, objectName, downloadUrl: undefined, expiresIn: 3600 };
        }
        catch (error) {
            console.error("Error creating presigned URL:", error);
            throw new Error("Could not create upload URL.");
        }
    }
    async getPresignedDownloadUrl(key, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        try {
            const downloadUrl = await (0, minio_1.generatePresignedGetUrl)(key);
            return { uploadUrl: downloadUrl, objectName: key, downloadUrl, expiresIn: 3600 };
        }
        catch (error) {
            console.error("Error creating download URL:", error);
            throw new Error("Could not create download URL.");
        }
    }
    async downloadUrl(mediaItem) {
        if (!mediaItem.objectName)
            return null;
        try {
            return (0, minio_1.generatePresignedGetUrl)(mediaItem.objectName);
        }
        catch (error) {
            console.error(`Failed to get download URL for ${mediaItem.objectName}`, error);
            return null;
        }
    }
    async thumbnailUrl(mediaItem) {
        if (!mediaItem.thumbnailObjectName)
            return null;
        try {
            // Use a shorter expiry for thumbnails as they are requested more often
            return (0, minio_1.generatePresignedGetUrl)(mediaItem.thumbnailObjectName, 900); // 15 minutes
        }
        catch (error) {
            console.error(`Failed to get thumbnail URL for ${mediaItem.thumbnailObjectName}`, error);
            return null;
        }
    }
    async createUploadUrl(filename, contentType = "application/octet-stream", { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        const fileExtension = filename.split(".").pop() || "unknown";
        const objectName = `media/${(0, crypto_1.randomUUID)()}.${fileExtension}`;
        try {
            const uploadUrl = await (0, minio_1.generatePresignedPutUrl)(objectName, contentType);
            return { uploadUrl, objectName, downloadUrl: undefined, expiresIn: 3600 };
        }
        catch (error) {
            console.error("Error creating presigned URL:", error);
            throw new Error("Could not create upload URL.");
        }
    }
    async createMediaItem(input, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        // First, find the memory to get its tripId
        const memory = await database_1.AppDataSource.getRepository(Memory_1.Memory).findOne({
            where: { id: input.memoryId },
            relations: ["trip"]
        });
        if (!memory) {
            throw new apollo_server_express_1.UserInputError(`Memory with ID ${input.memoryId} not found.`);
        }
        // Now check if the user has editor rights on that trip
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, memory.trip.id, TripMembership_1.TripRole.EDITOR);
        if (!hasAccess) {
            throw new apollo_server_express_1.UserInputError(`You don't have permission to add media to memory ${input.memoryId}.`);
        }
        const mediaItemRepository = database_1.AppDataSource.getRepository(MediaItem_1.MediaItem);
        const mediaItem = mediaItemRepository.create({
            ...input,
            memory: memory,
        });
        return await mediaItemRepository.save(mediaItem);
    }
    async updateMediaItem(id, input, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        const mediaItem = await database_1.AppDataSource.getRepository(MediaItem_1.MediaItem).findOne({
            where: { id },
            relations: ["memory", "memory.trip"]
        });
        if (!mediaItem) {
            throw new apollo_server_express_1.UserInputError(`Media item with ID ${id} not found.`);
        }
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, mediaItem.memory.trip.id, TripMembership_1.TripRole.EDITOR);
        if (!hasAccess) {
            throw new apollo_server_express_1.AuthenticationError("You don't have permission to update this media item.");
        }
        // Update the media item with the provided fields
        Object.assign(mediaItem, input);
        return await database_1.AppDataSource.getRepository(MediaItem_1.MediaItem).save(mediaItem);
    }
    async deleteMediaItem(id, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        const mediaItem = await database_1.AppDataSource.getRepository(MediaItem_1.MediaItem).findOne({
            where: { id },
            relations: ["memory", "memory.trip"]
        });
        if (!mediaItem) {
            throw new apollo_server_express_1.UserInputError(`Media item with ID ${id} not found.`);
        }
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, mediaItem.memory.trip.id, TripMembership_1.TripRole.EDITOR);
        if (!hasAccess) {
            throw new apollo_server_express_1.AuthenticationError("You don't have permission to delete this media item.");
        }
        try {
            await database_1.AppDataSource.transaction(async (em) => {
                // Log the deletion
                const deletionLog = em.create(DeletionLog_1.DeletionLog, { entityId: id, entityType: 'MediaItem', tripId: mediaItem.memory.trip.id });
                await em.save(deletionLog);
                // Delete the media item. The actual file deletion from MinIO is not handled here.
                await em.remove(mediaItem);
            });
            return true;
        }
        catch (error) {
            console.error("Error deleting media item:", error);
            throw new Error("Could not delete media item.");
        }
    }
    // ---------------------------------------------------------------------------
    // Kompatibilitäts-Resolver für Legacy-iOS-Feldnamen
    // ---------------------------------------------------------------------------
    filename(mediaItem) {
        return mediaItem.objectName;
    }
    originalFilename() {
        // Originaler Dateiname wird aktuell nicht gespeichert
        return null;
    }
    fileSize(mediaItem) {
        return mediaItem.filesize;
    }
};
__decorate([
    (0, type_graphql_1.Query)(() => PresignedUrlResponse_1.PresignedUrlResponse, { description: "Generate a pre-signed URL to upload a file" }),
    __param(0, (0, type_graphql_1.Arg)("filename")),
    __param(1, (0, type_graphql_1.Arg)("mimeType")),
    __param(2, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object]),
    __metadata("design:returntype", Promise)
], MediaItemResolver.prototype, "getPresignedUploadUrl", null);
__decorate([
    (0, type_graphql_1.Query)(() => PresignedUrlResponse_1.PresignedUrlResponse, { description: "Generate a pre-signed URL to download a file" }),
    __param(0, (0, type_graphql_1.Arg)("objectKey")),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], MediaItemResolver.prototype, "getPresignedDownloadUrl", null);
__decorate([
    (0, type_graphql_1.FieldResolver)(() => String, { nullable: true, description: "A temporary URL to download the full media file." }),
    __param(0, (0, type_graphql_1.Root)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [MediaItem_1.MediaItem]),
    __metadata("design:returntype", Promise)
], MediaItemResolver.prototype, "downloadUrl", null);
__decorate([
    (0, type_graphql_1.FieldResolver)(() => String, { nullable: true, description: "A temporary URL to download the thumbnail of the media file." }),
    __param(0, (0, type_graphql_1.Root)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [MediaItem_1.MediaItem]),
    __metadata("design:returntype", Promise)
], MediaItemResolver.prototype, "thumbnailUrl", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => PresignedUrlResponse_1.PresignedUrlResponse, {
        description: "Generates a pre-signed URL to upload a file to MinIO.",
    }),
    __param(0, (0, type_graphql_1.Arg)("filename")),
    __param(1, (0, type_graphql_1.Arg)("mimeType", { nullable: true })),
    __param(2, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object]),
    __metadata("design:returntype", Promise)
], MediaItemResolver.prototype, "createUploadUrl", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => MediaItem_1.MediaItem),
    __param(0, (0, type_graphql_1.Arg)("input")),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [MediaItemInput_1.MediaItemInput, Object]),
    __metadata("design:returntype", Promise)
], MediaItemResolver.prototype, "createMediaItem", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => MediaItem_1.MediaItem, { description: "Update a media item" }),
    __param(0, (0, type_graphql_1.Arg)("id", () => String)),
    __param(1, (0, type_graphql_1.Arg)("input")),
    __param(2, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, UpdateMediaItemInput_1.UpdateMediaItemInput, Object]),
    __metadata("design:returntype", Promise)
], MediaItemResolver.prototype, "updateMediaItem", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Boolean, { description: "Delete a media item" }),
    __param(0, (0, type_graphql_1.Arg)("id", () => String)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], MediaItemResolver.prototype, "deleteMediaItem", null);
__decorate([
    (0, type_graphql_1.FieldResolver)(() => String, { name: "filename" }),
    __param(0, (0, type_graphql_1.Root)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [MediaItem_1.MediaItem]),
    __metadata("design:returntype", String)
], MediaItemResolver.prototype, "filename", null);
__decorate([
    (0, type_graphql_1.FieldResolver)(() => String, { name: "originalFilename", nullable: true }),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Object)
], MediaItemResolver.prototype, "originalFilename", null);
__decorate([
    (0, type_graphql_1.FieldResolver)(() => type_graphql_2.Int, { name: "fileSize" }),
    __param(0, (0, type_graphql_1.Root)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [MediaItem_1.MediaItem]),
    __metadata("design:returntype", Number)
], MediaItemResolver.prototype, "fileSize", null);
MediaItemResolver = __decorate([
    (0, type_graphql_1.Resolver)(MediaItem_1.MediaItem)
], MediaItemResolver);
exports.MediaItemResolver = MediaItemResolver;
