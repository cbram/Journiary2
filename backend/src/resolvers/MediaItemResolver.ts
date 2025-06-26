import {
  Arg,
  Field,
  Mutation,
  ObjectType,
  Resolver,
} from "type-graphql";
import { MediaItem } from "../entities/MediaItem";
import { MediaItemInput } from "../entities/MediaItemInput";
import { AppDataSource } from "../utils/database";
import { generatePresignedPutUrl } from "../utils/minio";
import { Memory } from "../entities/Memory";
import { PresignedUrlResponse } from "./types/PresignedUrlResponse";
import { randomUUID } from "crypto";

@Resolver(MediaItem)
export class MediaItemResolver {
  @Mutation(() => PresignedUrlResponse, {
    description: "Generates a pre-signed URL to upload a file to MinIO.",
  })
  async createUploadUrl(
    @Arg("filename") filename: string,
    @Arg("contentType", { nullable: true }) contentType: string = "application/octet-stream"
  ): Promise<PresignedUrlResponse> {
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
    @Arg("input") input: MediaItemInput
  ): Promise<MediaItem> {
    const mediaItemRepository = AppDataSource.getRepository(MediaItem);

    const memory = await AppDataSource.getRepository(Memory).findOneBy({ id: input.memoryId });
    if (!memory) {
      throw new Error(`Memory with ID ${input.memoryId} not found.`);
    }

    const mediaItem = mediaItemRepository.create({
      ...input,
      memory: memory,
    });

    return await mediaItemRepository.save(mediaItem);
  }
} 