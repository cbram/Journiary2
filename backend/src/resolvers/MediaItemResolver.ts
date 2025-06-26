import {
  Arg,
  Ctx,
  Field,
  FieldResolver,
  Mutation,
  ObjectType,
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

@Resolver(MediaItem)
export class MediaItemResolver {
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
    @Arg("contentType", { nullable: true }) contentType: string = "application/octet-stream",
    @Ctx() { userId }: MyContext
  ): Promise<PresignedUrlResponse> {
    if (!userId) throw new AuthenticationError("You must be logged in.");

    const fileExtension = filename.split(".").pop() || "unknown";
    const objectName = `media/${randomUUID()}.${fileExtension}`;

    try {
      const uploadUrl = await generatePresignedPutUrl(objectName, contentType);
      return { uploadUrl, objectName };
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
} 