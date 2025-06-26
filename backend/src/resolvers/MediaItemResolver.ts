import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import {
  PutObjectCommand,
  PutObjectCommandInput,
  S3Client,
} from "@aws-sdk/client-s3";
import { randomUUID } from "crypto";
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
import { getMinioClient, BUCKET_NAME } from "../utils/minio";
import { Memory } from "../entities/Memory";

/*
const {
  MINIO_PUBLIC_HOST,
  MINIO_PUBLIC_PORT,
  MINIO_PUBLIC_SSL,
} = process.env;

const useSsl = MINIO_PUBLIC_SSL === 'true';
const port = MINIO_PUBLIC_PORT ? parseInt(MINIO_PUBLIC_PORT, 10) : undefined;

// Create a separate client for signing URLs with the public-facing endpoint
const signingClient = MINIO_PUBLIC_HOST && port ? new S3Client({
  endpoint: `${useSsl ? 'https' : 'http'}://${MINIO_PUBLIC_HOST}:${port}`,
  region: "us-east-1",
  credentials: {
    accessKeyId: "minioadmin",
    secretAccessKey: "minioadmin",
  },
  forcePathStyle: true,
}) : minioClient;
*/

@ObjectType()
class PresignedUrlResponse {
  @Field()
  uploadUrl!: string;

  @Field()
  objectName!: string;
}

@Resolver(MediaItem)
export class MediaItemResolver {
  @Mutation(() => PresignedUrlResponse, {
    description: "Generates a pre-signed URL to upload a file to MinIO.",
  })
  async createUploadUrl(
    @Arg("filename") filename: string,
    @Arg("contentType", { nullable: true }) contentType?: string
  ): Promise<PresignedUrlResponse> {
    const fileExtension = filename.split(".").pop() || "unknown";
    const objectName = `${randomUUID()}.${fileExtension}`;

    const minioClient = getMinioClient();

    // Use the AWS SDK v3 style for creating presigned URLs
    const commandParams: PutObjectCommandInput = {
      Bucket: BUCKET_NAME,
      Key: objectName,
    };

    if (contentType) {
      commandParams.ContentType = contentType;
    }

    const command = new PutObjectCommand(commandParams);

    try {
      const publicMinioUrl = process.env.MINIO_PUBLIC_URL;
      if (!publicMinioUrl) {
        throw new Error("MINIO_PUBLIC_URL environment variable is not set.");
      }
      
      // Create a dedicated S3 client instance for signing, configured with the public URL.
      // This ensures the signature is generated for the correct public-facing host.
      const signingClient = new S3Client({
        endpoint: publicMinioUrl,
        region: "us-east-1", // Must match the region of the actual client
        credentials: {
          accessKeyId: "minioadmin", // Must match
          secretAccessKey: "minioadmin", // Must match
        },
        forcePathStyle: true,
      });

      const presignedUrl = await getSignedUrl(
        signingClient, 
        command, 
        {
          expiresIn: 900, // 15 minutes
        }
      );

      return { uploadUrl: presignedUrl, objectName };
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