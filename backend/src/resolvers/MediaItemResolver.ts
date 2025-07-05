import {
  Arg,
  Ctx,
  Field,
  FieldResolver,
  Mutation,
  ObjectType,
  Query,
  Resolver,
  Root,
} from "type-graphql";
import { MediaItem } from "../entities/MediaItem";
import { MediaItemInput } from "../entities/MediaItemInput";
import { AppDataSource } from "../utils/database";
import { generatePresignedPutUrl, generatePresignedGetUrl } from "../utils/minio";
import { Memory } from "../entities/Memory";
import { PresignedUrlResponse } from "./types/PresignedUrlResponse";
import { randomUUID } from "crypto";
import { MyContext } from "..";
import { AuthenticationError, UserInputError } from "apollo-server-express";
import { checkTripAccess } from '../utils/auth';
import { TripRole } from '../entities/TripMembership';
import { Int } from "type-graphql";
import { DeletionLog } from "../entities/DeletionLog";

@Resolver(MediaItem)
export class MediaItemResolver {
  @Query(() => PresignedUrlResponse, { description: "Generate a pre-signed URL to upload a file" })
  async getPresignedUploadUrl(
    @Arg("filename") filename: string,
    @Arg("mimeType") contentType: string,
    @Ctx() { userId }: MyContext
  ): Promise<PresignedUrlResponse> {
    if (!userId) throw new AuthenticationError("You must be logged in.");

    const fileExtension = filename.split(".").pop() || "unknown";
    const objectName = `media/${randomUUID()}.${fileExtension}`;

    try {
      const uploadUrl = await generatePresignedPutUrl(objectName, contentType);
      return { uploadUrl, objectName, downloadUrl: undefined, expiresIn: 3600 };
    } catch (error) {
      console.error("Error creating presigned URL:", error);
      throw new Error("Could not create upload URL.");
    }
  }

  @Query(() => PresignedUrlResponse, { description: "Generate a pre-signed URL to download a file" })
  async getPresignedDownloadUrl(
    @Arg("objectKey") key: string,
    @Ctx() { userId }: MyContext
  ): Promise<PresignedUrlResponse> {
    if (!userId) throw new AuthenticationError("You must be logged in.");

    try {
      const downloadUrl = await generatePresignedGetUrl(key);
      return { uploadUrl: downloadUrl, objectName: key, downloadUrl, expiresIn: 3600 };
    } catch (error) {
      console.error("Error creating download URL:", error);
      throw new Error("Could not create download URL.");
    }
  }

  @FieldResolver(() => String, { nullable: true, description: "A temporary URL to download the full media file." })
  async downloadUrl(@Root() mediaItem: MediaItem): Promise<string | null> {
    if (!mediaItem.objectName) return null;
    try {
      return generatePresignedGetUrl(mediaItem.objectName);
    } catch (error) {
      console.error(`Failed to get download URL for ${mediaItem.objectName}`, error);
      return null;
    }
  }

  @FieldResolver(() => String, { nullable: true, description: "A temporary URL to download the thumbnail of the media file." })
  async thumbnailUrl(@Root() mediaItem: MediaItem): Promise<string | null> {
    if (!mediaItem.thumbnailObjectName) return null;
    try {
      // Use a shorter expiry for thumbnails as they are requested more often
      return generatePresignedGetUrl(mediaItem.thumbnailObjectName, 900); // 15 minutes
    } catch (error) {
      console.error(`Failed to get thumbnail URL for ${mediaItem.thumbnailObjectName}`, error);
      return null;
    }
  }

  @Mutation(() => PresignedUrlResponse, {
    description: "Generates a pre-signed URL to upload a file to MinIO.",
  })
  async createUploadUrl(
    @Arg("filename") filename: string,
    @Arg("mimeType", { nullable: true }) contentType: string = "application/octet-stream",
    @Ctx() { userId }: MyContext
  ): Promise<PresignedUrlResponse> {
    if (!userId) throw new AuthenticationError("You must be logged in.");

    const fileExtension = filename.split(".").pop() || "unknown";
    const objectName = `media/${randomUUID()}.${fileExtension}`;

    try {
      const uploadUrl = await generatePresignedPutUrl(objectName, contentType);
      return { uploadUrl, objectName, downloadUrl: undefined, expiresIn: 3600 };
    } catch (error) {
      console.error("Error creating presigned URL:", error);
      throw new Error("Could not create upload URL.");
    }
  }

  @Mutation(() => MediaItem)
  async createMediaItem(
    @Arg("input") input: MediaItemInput,
    @Ctx() { userId }: MyContext
  ): Promise<MediaItem> {
    if (!userId) throw new AuthenticationError("You must be logged in.");
    
    // First, find the memory to get its tripId
    const memory = await AppDataSource.getRepository(Memory).findOne({ 
        where: { id: input.memoryId },
        relations: ["trip"] 
    });
    if (!memory) {
      throw new UserInputError(`Memory with ID ${input.memoryId} not found.`);
    }

    // Now check if the user has editor rights on that trip
    const hasAccess = await checkTripAccess(userId, memory.trip.id, TripRole.EDITOR);
    if (!hasAccess) {
        throw new UserInputError(`You don't have permission to add media to memory ${input.memoryId}.`);
    }

    const mediaItemRepository = AppDataSource.getRepository(MediaItem);
    const mediaItem = mediaItemRepository.create({
      ...input,
      memory: memory,
    });

    return await mediaItemRepository.save(mediaItem);
  }

  @Mutation(() => Boolean, { description: "Delete a media item" })
  async deleteMediaItem(
    @Arg("id", () => String) id: string,
    @Ctx() { userId }: MyContext
  ): Promise<boolean> {
    if (!userId) throw new AuthenticationError("You must be logged in.");

    const mediaItem = await AppDataSource.getRepository(MediaItem).findOne({
      where: { id },
      relations: ["memory", "memory.trip"]
    });

    if (!mediaItem) {
      throw new UserInputError(`Media item with ID ${id} not found.`);
    }

    const hasAccess = await checkTripAccess(userId, mediaItem.memory.trip.id, TripRole.EDITOR);
    if (!hasAccess) {
      throw new AuthenticationError("You don't have permission to delete this media item.");
    }
    
    try {
        await AppDataSource.transaction(async (em) => {
            // Log the deletion
            const deletionLog = em.create(DeletionLog, { entityId: id, entityType: 'MediaItem', tripId: mediaItem.memory.trip.id });
            await em.save(deletionLog);

            // Delete the media item. The actual file deletion from MinIO is not handled here.
            await em.remove(mediaItem);
        });
        return true;
    } catch (error) {
        console.error("Error deleting media item:", error);
        throw new Error("Could not delete media item.");
    }
  }

  // ---------------------------------------------------------------------------
  // Kompatibilitäts-Resolver für Legacy-iOS-Feldnamen
  // ---------------------------------------------------------------------------

  @FieldResolver(() => String, { name: "filename" })
  filename(@Root() mediaItem: MediaItem): string {
    return mediaItem.objectName;
  }

  @FieldResolver(() => String, { name: "originalFilename", nullable: true })
  originalFilename(): string | null {
    // Originaler Dateiname wird aktuell nicht gespeichert
    return null;
  }

  @FieldResolver(() => Int, { name: "fileSize" })
  fileSize(@Root() mediaItem: MediaItem): number {
    return mediaItem.filesize;
  }

  // s3Key und thumbnailS3Key werden bereits durch Aliase im Entity abgedeckt.
} 