import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import {
  PutObjectCommand,
  PutObjectCommandInput,
  S3Client,
  GetObjectCommand,
} from "@aws-sdk/client-s3";
import { randomUUID } from "crypto";
import {
  Arg,
  Field,
  Mutation,
  ObjectType,
  Resolver,
  ID,
  Query,
} from "type-graphql";
import { AppDataSource } from "../utils/database";
import { BUCKET_NAME, getMinioClient } from "../utils/minio";
import { GPXTrack } from "../entities/GPXTrack";
import { Trip } from "../entities/Trip";
import { TrackSegment } from "../entities/TrackSegment";
import { RoutePoint } from "../entities/RoutePoint";
// eslint-disable-next-line @typescript-eslint/no-var-requires
const GpxParser = require("gpxparser");

interface GpxPoint {
  lat: number;
  lon: number;
  ele: number;
  time: string | Date;
}

@ObjectType()
class PresignedGpxUploadResponse {
  @Field()
  uploadUrl!: string;

  @Field()
  objectName!: string;
}

@Resolver(GPXTrack)
export class GPXResolver {
  @Query(() => [GPXTrack], { description: "Get all GPX tracks for a specific trip." })
  async gpxTracksByTrip(@Arg("tripId", () => ID) tripId: string): Promise<GPXTrack[]> {
    try {
      return await AppDataSource.getRepository(GPXTrack).find({
        where: { tripId },
        relations: ["segments"], // Optional: pre-load segments
      });
    } catch (error) {
      console.error("Error fetching GPX tracks by trip:", error);
      throw new Error("Could not fetch GPX tracks.");
    }
  }

  @Query(() => GPXTrack, { nullable: true, description: "Get a single GPX track by its ID, including all its data." })
  async gpxTrack(@Arg("id", () => ID) id: string): Promise<GPXTrack | null> {
    try {
      return await AppDataSource.getRepository(GPXTrack).findOne({
        where: { id },
        relations: ["segments", "segments.points"],
      });
    } catch (error) {
      console.error("Error fetching single GPX track:", error);
      throw new Error("Could not fetch the GPX track.");
    }
  }

  @Mutation(() => PresignedGpxUploadResponse, {
    description: "Generates a pre-signed URL to upload a GPX file to MinIO.",
  })
  async createGpxUploadUrl(
    @Arg("tripId", () => ID) tripId: string,
    @Arg("filename") filename: string
  ): Promise<PresignedGpxUploadResponse> {
    
    // Verify trip exists
    const trip = await AppDataSource.getRepository(Trip).findOneBy({ id: tripId });
    if (!trip) {
      throw new Error(`Trip with ID ${tripId} not found.`);
    }

    const objectName = `${randomUUID()}.gpx`;

    const commandParams: PutObjectCommandInput = {
      Bucket: BUCKET_NAME,
      Key: objectName,
      ContentType: "application/gpx+xml",
    };

    const command = new PutObjectCommand(commandParams);

    try {
      const publicMinioUrl = process.env.MINIO_PUBLIC_URL;
      if (!publicMinioUrl) {
        throw new Error("MINIO_PUBLIC_URL environment variable is not set.");
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

      const presignedUrl = await getSignedUrl(
        signingClient, 
        command, 
        {
          expiresIn: 900, // 15 minutes
        }
      );

      return { uploadUrl: presignedUrl, objectName };
    } catch (error) {
      console.error("Error creating presigned URL for GPX:", error);
      throw new Error("Could not create GPX upload URL.");
    }
  }

  @Mutation(() => GPXTrack, { description: "Processes an uploaded GPX file and creates the track data." })
  async processGpxFile(
    @Arg("objectName") objectName: string,
    @Arg("tripId", () => ID) tripId: string,
    @Arg("trackName") trackName: string,
  ): Promise<GPXTrack> {
    const tripRepository = AppDataSource.getRepository(Trip);
    const trip = await tripRepository.findOneBy({ id: tripId });
    if (!trip) {
      throw new Error(`Trip with ID ${tripId} not found.`);
    }

    const minioClient = getMinioClient();
    let gpxContent: string;

    try {
      const command = new GetObjectCommand({
        Bucket: BUCKET_NAME,
        Key: objectName,
      });
      const response = await minioClient.send(command);
      gpxContent = await response.Body!.transformToString();
    } catch (error) {
      console.error(`Error downloading GPX file ${objectName} from MinIO:`, error);
      throw new Error("Failed to download GPX file.");
    }

    const gpx = new GpxParser();
    gpx.parse(gpxContent);

    const gpxTrackRepository = AppDataSource.getRepository(GPXTrack);
    const trackSegmentRepository = AppDataSource.getRepository(TrackSegment);
    const routePointRepository = AppDataSource.getRepository(RoutePoint);

    const newGpxTrack = gpxTrackRepository.create({
      name: trackName || gpx.metadata.name || "Unnamed Track",
      description: gpx.metadata.desc,
      trip: trip,
      segments: [],
    });
    
    await gpxTrackRepository.save(newGpxTrack);

    for (const track of gpx.tracks) {
      // The gpx-parser library combines all segments into a single points array per track.
      // We will create one segment per track from the GPX file.
      if (track.points && track.points.length > 0) {
        const newSegment = trackSegmentRepository.create({
          gpxTrack: newGpxTrack,
          points: [],
        });
        await trackSegmentRepository.save(newSegment);

        const routePoints = track.points.map((point: GpxPoint) => {
          return routePointRepository.create({
            latitude: point.lat,
            longitude: point.lon,
            altitude: point.ele,
            timestamp: new Date(point.time),
            trackSegment: newSegment,
            trip: trip, // also associate with the trip directly
          });
        });
        await routePointRepository.save(routePoints);
        
        newSegment.points = routePoints;
        await trackSegmentRepository.save(newSegment); // Save again to update relation
        newGpxTrack.segments.push(newSegment);
      }
    }
    
    // Save the track again to update its segments relation
    return await gpxTrackRepository.save(newGpxTrack);
  }

  @Mutation(() => Boolean, { description: "Deletes a GPX track and its associated data." })
  async deleteGpxTrack(@Arg("id", () => ID) id: string): Promise<boolean> {
    try {
      // TypeORM's cascade functionality should handle deleting related segments and points
      const result = await AppDataSource.getRepository(GPXTrack).delete(id);
      
      if (result.affected === 0) {
        throw new Error(`GPX Track with ID ${id} not found.`);
      }

      return true;
    } catch (error) {
      console.error("Error deleting GPX track:", error);
      // Re-throw with a more user-friendly message if it's a known error,
      // otherwise, a generic failure message.
      if (error instanceof Error && error.message.includes("not found")) {
        throw error;
      }
      throw new Error("Could not delete the GPX track.");
    }
  }
} 