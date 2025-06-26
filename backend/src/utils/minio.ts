import {
  S3Client,
  CreateBucketCommand,
  HeadBucketCommand,
  PutObjectCommand,
  GetObjectCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

export const BUCKET_NAME = "journiary";

let minioClientInstance: S3Client | null = null;

export function getMinioClient(): S3Client {
  if (!minioClientInstance) {
    minioClientInstance = new S3Client({
      endpoint: "http://minio:9000",
      region: "us-east-1",
      credentials: {
        accessKeyId: "minioadmin",
        secretAccessKey: "minioadmin",
      },
      forcePathStyle: true, // Important for MinIO
    });
  }
  return minioClientInstance;
}

// Function to ensure the bucket exists on startup
export async function ensureBucketExists() {
  const minioClient = getMinioClient();
  try {
    // Check if the bucket exists
    await minioClient.send(new HeadBucketCommand({ Bucket: BUCKET_NAME }));
    console.log(`✅ Bucket '${BUCKET_NAME}' already exists.`);
  } catch (error: any) {
    // If the bucket does not exist, the error code will be '404' or similar.
    // A more specific check for NotFound is better if available.
    if (error.name === "NotFound" || error.$metadata?.httpStatusCode === 404) {
      try {
        // Create the bucket
        await minioClient.send(
          new CreateBucketCommand({ Bucket: BUCKET_NAME })
        );
        console.log(`✅ Bucket '${BUCKET_NAME}' created successfully.`);
      } catch (createError) {
        console.error(`❌ Error creating bucket '${BUCKET_NAME}':`, createError);
      }
    } else {
      // For other errors (e.g., connection issues), log them
      console.error(
        `❌ Error checking for bucket '${BUCKET_NAME}':`,
        error
      );
    }
  }
}

export async function generatePresignedPutUrl(objectName: string, contentType: string, expiresIn: number = 3600): Promise<string> {
    const command = new PutObjectCommand({
        Bucket: BUCKET_NAME,
        Key: objectName,
        ContentType: contentType,
    });

    try {
        const publicMinioUrl = process.env.MINIO_PUBLIC_URL;
        if (!publicMinioUrl) {
            console.warn("MINIO_PUBLIC_URL environment variable is not set. Using internal endpoint for signing.");
            const internalMinioClient = getMinioClient();
            const url = await getSignedUrl(internalMinioClient, command, { expiresIn });
            return url;
        }

        const signingClient = new S3Client({
            endpoint: publicMinioUrl,
            region: "us-east-1",
            credentials: {
                accessKeyId: "minioadmin",
                secretAccessKey: "minioadmin",
            },
            forcePathStyle: true,
        });
        
        const url = await getSignedUrl(signingClient, command, { expiresIn });
        return url;
    } catch (error) {
        console.error("Error generating presigned URL", error);
        throw new Error("Could not generate presigned URL for upload.");
    }
}

export async function generatePresignedGetUrl(objectName: string, expiresIn: number = 3600): Promise<string> {
    const minioClient = getMinioClient();
    const command = new GetObjectCommand({
        Bucket: BUCKET_NAME,
        Key: objectName,
    });

    try {
        // Generate a pre-signed URL for the GET request, valid for the specified duration (default 1 hour)
        return await getSignedUrl(minioClient, command, { expiresIn });
    } catch (error) {
        console.error(`Error generating presigned GET URL for object ${objectName}`, error);
        throw new Error("Could not generate download URL.");
    }
}

export async function getObjectContent(objectName: string): Promise<string> {
    const minioClient = getMinioClient();
    const command = new GetObjectCommand({
        Bucket: BUCKET_NAME,
        Key: objectName,
    });

    try {
        const response = await minioClient.send(command);
        if (!response.Body) {
            throw new Error(`No body in response for object ${objectName}`);
        }
        return response.Body.transformToString("utf-8");
    } catch (error) {
        console.error(`Error fetching object ${objectName} from Minio`, error);
        throw new Error(`Could not fetch object ${objectName}.`);
    }
}
