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
import { GPXTrackInput } from "../entities/GPXTrackInput";
import { PresignedUrlResponse } from "./types/PresignedUrlResponse";
import { generatePresignedPutUrl, getObjectContent } from "../utils/minio";
import { Memory } from "../entities/Memory";

interface GpxPoint {
  lat: number;
  lon: number;
  ele: number;
  time: Date;
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

  @Mutation(() => PresignedUrlResponse, { description: "Generates a pre-signed URL to upload a GPX file." })
  async generateGpxUploadUrl(
    @Arg("filename") filename: string
  ): Promise<PresignedUrlResponse> {
    const fileExtension = filename.split('.').pop() || 'gpx';
    const objectName = `gpx/${randomUUID()}.${fileExtension}`;
    const contentType = 'application/gpx+xml';
    
    try {
      const uploadUrl = await generatePresignedPutUrl(objectName, contentType);
      return { uploadUrl, objectName };
    } catch (error) {
      console.error("Error creating presigned URL for GPX:", error);
      throw new Error("Could not create GPX upload URL.");
    }
  }

  @Mutation(() => GPXTrack, { description: "Creates a new GPX track record and processes the uploaded file." })
  async createGpxTrack(
    @Arg("input") input: GPXTrackInput
  ): Promise<GPXTrack> {
    const trip = await AppDataSource.getRepository(Trip).findOneBy({ id: input.tripId });
    if (!trip) {
      throw new Error(`Trip with ID ${input.tripId} not found.`);
    }

    let memory: Memory | null = null;
    if (input.memoryId) {
      memory = await AppDataSource.getRepository(Memory).findOneBy({ id: input.memoryId });
      if (!memory) {
        console.warn(`Memory with ID ${input.memoryId} not found, but proceeding.`);
      }
    }

    const gpxTrackRepository = AppDataSource.getRepository(GPXTrack);
    const newGpxTrack = gpxTrackRepository.create({
      name: input.name,
      originalFilename: input.originalFilename,
      gpxFileObjectName: input.gpxFileObjectName,
      creator: input.creator,
      trackType: input.trackType,
      trip: trip,
      memory: memory || undefined,
    });

    // If a file was uploaded, process it now
    if (input.gpxFileObjectName) {
      const gpxContent = await getObjectContent(input.gpxFileObjectName);
      const gpx = new GpxParser();
      gpx.parse(gpxContent);

      // Check if the GPX file contains at least one track
      if (!gpx.tracks || gpx.tracks.length === 0) {
        // If not, we still save the metadata but don't process track data
        console.warn(`GPX file ${input.originalFilename} is valid but contains no tracks. Saving metadata only.`);
        return await gpxTrackRepository.save(newGpxTrack);
      }

      // For simplicity, we aggregate data from the first track.
      // A more complex implementation could handle multiple tracks.
      const firstTrack = gpx.tracks[0];
      newGpxTrack.totalDistance = firstTrack?.distance.total;
      newGpxTrack.elevationGain = firstTrack?.elevation.pos;
      newGpxTrack.elevationLoss = firstTrack?.elevation.neg;
      newGpxTrack.minElevation = firstTrack?.elevation.min;
      newGpxTrack.maxElevation = firstTrack?.elevation.max;

      const segments: TrackSegment[] = [];
      for (const track of gpx.tracks) {
        // Create a new segment for each track in the GPX file
        const segment = new TrackSegment();
        segment.distance = track.distance.total;

        const points: RoutePoint[] = track.points.map((p: GpxPoint) => {
          const routePoint = new RoutePoint();
          routePoint.latitude = p.lat;
          routePoint.longitude = p.lon;
          routePoint.altitude = p.ele;
          routePoint.timestamp = p.time;
          return routePoint;
        });
        segment.points = points;
        segments.push(segment);
      }
      newGpxTrack.segments = segments;
    }

    // Use the entity manager to save the track and all its cascaded segments and points
    return await AppDataSource.manager.save(newGpxTrack);
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