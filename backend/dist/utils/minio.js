"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getObjectContent = exports.generatePresignedGetUrl = exports.generatePresignedPutUrl = exports.ensureBucketExists = exports.getMinioClient = exports.BUCKET_NAME = void 0;
const client_s3_1 = require("@aws-sdk/client-s3");
const s3_request_presigner_1 = require("@aws-sdk/s3-request-presigner");
exports.BUCKET_NAME = "journiary";
let minioClientInstance = null;
function getMinioClient() {
    if (!minioClientInstance) {
        minioClientInstance = new client_s3_1.S3Client({
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
exports.getMinioClient = getMinioClient;
// Function to ensure the bucket exists on startup
async function ensureBucketExists() {
    const minioClient = getMinioClient();
    try {
        // Check if the bucket exists
        await minioClient.send(new client_s3_1.HeadBucketCommand({ Bucket: exports.BUCKET_NAME }));
        console.log(`✅ Bucket '${exports.BUCKET_NAME}' already exists.`);
    }
    catch (error) {
        // If the bucket does not exist, the error code will be '404' or similar.
        // A more specific check for NotFound is better if available.
        if (error.name === "NotFound" || error.$metadata?.httpStatusCode === 404) {
            try {
                // Create the bucket
                await minioClient.send(new client_s3_1.CreateBucketCommand({ Bucket: exports.BUCKET_NAME }));
                console.log(`✅ Bucket '${exports.BUCKET_NAME}' created successfully.`);
            }
            catch (createError) {
                console.error(`❌ Error creating bucket '${exports.BUCKET_NAME}':`, createError);
            }
        }
        else {
            // For other errors (e.g., connection issues), log them
            console.error(`❌ Error checking for bucket '${exports.BUCKET_NAME}':`, error);
        }
    }
}
exports.ensureBucketExists = ensureBucketExists;
async function generatePresignedPutUrl(objectName, contentType, expiresIn = 3600) {
    const command = new client_s3_1.PutObjectCommand({
        Bucket: exports.BUCKET_NAME,
        Key: objectName,
        ContentType: contentType,
    });
    try {
        const publicMinioUrl = process.env.MINIO_PUBLIC_URL;
        if (!publicMinioUrl) {
            console.warn("MINIO_PUBLIC_URL environment variable is not set. Using internal endpoint for signing.");
            const internalMinioClient = getMinioClient();
            const url = await (0, s3_request_presigner_1.getSignedUrl)(internalMinioClient, command, { expiresIn });
            return url;
        }
        const signingClient = new client_s3_1.S3Client({
            endpoint: publicMinioUrl,
            region: "us-east-1",
            credentials: {
                accessKeyId: "minioadmin",
                secretAccessKey: "minioadmin",
            },
            forcePathStyle: true,
        });
        const url = await (0, s3_request_presigner_1.getSignedUrl)(signingClient, command, { expiresIn });
        return url;
    }
    catch (error) {
        console.error("Error generating presigned URL", error);
        throw new Error("Could not generate presigned URL for upload.");
    }
}
exports.generatePresignedPutUrl = generatePresignedPutUrl;
async function generatePresignedGetUrl(objectName, expiresIn = 3600) {
    const minioClient = getMinioClient();
    const command = new client_s3_1.GetObjectCommand({
        Bucket: exports.BUCKET_NAME,
        Key: objectName,
    });
    try {
        // Generate a pre-signed URL for the GET request, valid for the specified duration (default 1 hour)
        return await (0, s3_request_presigner_1.getSignedUrl)(minioClient, command, { expiresIn });
    }
    catch (error) {
        console.error(`Error generating presigned GET URL for object ${objectName}`, error);
        throw new Error("Could not generate download URL.");
    }
}
exports.generatePresignedGetUrl = generatePresignedGetUrl;
async function getObjectContent(objectName) {
    const minioClient = getMinioClient();
    const command = new client_s3_1.GetObjectCommand({
        Bucket: exports.BUCKET_NAME,
        Key: objectName,
    });
    try {
        const response = await minioClient.send(command);
        if (!response.Body) {
            throw new Error(`No body in response for object ${objectName}`);
        }
        return response.Body.transformToString("utf-8");
    }
    catch (error) {
        console.error(`Error fetching object ${objectName} from Minio`, error);
        throw new Error(`Could not fetch object ${objectName}.`);
    }
}
exports.getObjectContent = getObjectContent;
