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
  Ctx,
  FieldResolver,
  Root,
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
import { generatePresignedPutUrl, getObjectContent, generatePresignedGetUrl } from "../utils/minio";
import { Memory } from "../entities/Memory";
import { MyContext } from "..";
import { AuthenticationError, UserInputError } from "apollo-server-express";
import { checkTripAccess } from '../utils/auth';
import { TripRole } from '../entities/TripMembership';

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
  @FieldResolver(() => String, { nullable: true })
  async downloadUrl(@Root() gpxTrack: GPXTrack): Promise<string | null> {
    if (!gpxTrack.gpxFileObjectName) return null;
    try {
      return generatePresignedGetUrl(gpxTrack.gpxFileObjectName);
    } catch (error) {
      console.error(`Failed to get download URL for ${gpxTrack.gpxFileObjectName}`, error);
      return null;
    }
  }

  @Query(() => [GPXTrack], { description: "Get all GPX tracks for a specific trip." })
  async gpxTracksByTrip(
    @Arg("tripId", () => ID) tripId: string,
    @Ctx() { userId }: MyContext
  ): Promise<GPXTrack[]> {
    if (!userId) throw new AuthenticationError("You must be logged in.");
    const hasAccess = await checkTripAccess(userId, tripId, TripRole.VIEWER);
    if (!hasAccess) throw new UserInputError("Trip not found or you don't have access.");
    return AppDataSource.getRepository(GPXTrack).find({ where: { tripId } });
  }

  @Query(() => GPXTrack, { nullable: true, description: "Get a single GPX track by its ID, including all its data." })
  async gpxTrack(
    @Arg("id", () => ID) id: string,
    @Ctx() { userId }: MyContext
  ): Promise<GPXTrack | null> {
    if (!userId) throw new AuthenticationError("You must be logged in.");
    const track = await AppDataSource.getRepository(GPXTrack).findOne({ where: { id }, relations: ["trip"] });
    if (!track) return null;
    const hasAccess = await checkTripAccess(userId, track.trip.id, TripRole.VIEWER);
    if (!hasAccess) return null;
    return track;
  }

  @Mutation(() => PresignedUrlResponse, { description: "Generates a pre-signed URL to upload a GPX file." })
  async generateGpxUploadUrl(
    @Arg("filename") filename: string,
    @Ctx() { userId }: MyContext
  ): Promise<PresignedUrlResponse> {
    if (!userId) throw new AuthenticationError("You must be logged in.");
    
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
    @Arg("input") input: GPXTrackInput,
    @Ctx() { userId }: MyContext
  ): Promise<GPXTrack> {
    if (!userId) throw new AuthenticationError("You must be logged in.");
    const hasAccess = await checkTripAccess(userId, input.tripId, TripRole.EDITOR);
    if (!hasAccess) throw new UserInputError(`You don't have permission to add tracks to trip ${input.tripId}.`);

    const trip = await AppDataSource.getRepository(Trip).findOne({ where: { id: input.tripId, user: { id: userId } } });
    if (!trip) throw new UserInputError(`Trip with ID ${input.tripId} not found or you don't have access.`);

    let memory: Memory | null = null;
    if (input.memoryId) {
      memory = await AppDataSource.getRepository(Memory).findOne({ where: { id: input.memoryId, trip: { user: { id: userId } } } });
      if (!memory) console.warn(`Memory with ID ${input.memoryId} not found or you don't have access.`);
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
    @Ctx() { userId }: MyContext
  ): Promise<GPXTrack> {
    if (!userId) throw new AuthenticationError("You must be logged in.");
    
    const trip = await AppDataSource.getRepository(Trip).findOne({ where: { id: tripId, user: { id: userId } } });
    if (!trip) throw new UserInputError(`Trip with ID ${tripId} not found or you don't have access.`);

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
  async deleteGpxTrack(
    @Arg("id", () => ID) id: string,
    @Ctx() { userId }: MyContext
  ): Promise<boolean> {
    if (!userId) throw new AuthenticationError("You must be logged in.");

    const repo = AppDataSource.getRepository(GPXTrack);
    const track = await repo.findOne({ where: { id }, relations: ["trip"] });
    if (!track) return false;

    const hasAccess = await checkTripAccess(userId, track.trip.id, TripRole.EDITOR);
    if (!hasAccess) throw new UserInputError("You don't have permission to delete this track.");

    const result = await repo.delete(id);
    return result.affected === 1;
  }
} 