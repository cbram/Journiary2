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
exports.GPXResolver = void 0;
const client_s3_1 = require("@aws-sdk/client-s3");
const crypto_1 = require("crypto");
const type_graphql_1 = require("type-graphql");
const database_1 = require("../utils/database");
const minio_1 = require("../utils/minio");
const GPXTrack_1 = require("../entities/GPXTrack");
const Trip_1 = require("../entities/Trip");
const TrackSegment_1 = require("../entities/TrackSegment");
const RoutePoint_1 = require("../entities/RoutePoint");
// eslint-disable-next-line @typescript-eslint/no-var-requires
const GpxParser = require("gpxparser");
const GPXTrackInput_1 = require("../entities/GPXTrackInput");
const PresignedUrlResponse_1 = require("./types/PresignedUrlResponse");
const minio_2 = require("../utils/minio");
const Memory_1 = require("../entities/Memory");
const apollo_server_express_1 = require("apollo-server-express");
const auth_1 = require("../utils/auth");
const TripMembership_1 = require("../entities/TripMembership");
const DeletionLog_1 = require("../entities/DeletionLog");
let PresignedGpxUploadResponse = class PresignedGpxUploadResponse {
};
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], PresignedGpxUploadResponse.prototype, "uploadUrl", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], PresignedGpxUploadResponse.prototype, "objectName", void 0);
PresignedGpxUploadResponse = __decorate([
    (0, type_graphql_1.ObjectType)()
], PresignedGpxUploadResponse);
let GPXResolver = class GPXResolver {
    async downloadUrl(gpxTrack) {
        if (!gpxTrack.gpxFileObjectName)
            return null;
        try {
            return (0, minio_2.generatePresignedGetUrl)(gpxTrack.gpxFileObjectName);
        }
        catch (error) {
            console.error(`Failed to get download URL for ${gpxTrack.gpxFileObjectName}`, error);
            return null;
        }
    }
    async gpxTracksByTrip(tripId, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, tripId, TripMembership_1.TripRole.VIEWER);
        if (!hasAccess)
            throw new apollo_server_express_1.UserInputError("Trip not found or you don't have access.");
        return database_1.AppDataSource.getRepository(GPXTrack_1.GPXTrack).find({ where: { tripId } });
    }
    async gpxTrack(id, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        const track = await database_1.AppDataSource.getRepository(GPXTrack_1.GPXTrack).findOne({ where: { id }, relations: ["trip"] });
        if (!track)
            return null;
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, track.trip.id, TripMembership_1.TripRole.VIEWER);
        if (!hasAccess)
            return null;
        return track;
    }
    async generateGpxUploadUrl(filename, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        const fileExtension = filename.split('.').pop() || 'gpx';
        const objectName = `gpx/${(0, crypto_1.randomUUID)()}.${fileExtension}`;
        const contentType = 'application/gpx+xml';
        try {
            const uploadUrl = await (0, minio_2.generatePresignedPutUrl)(objectName, contentType);
            return { uploadUrl, objectName };
        }
        catch (error) {
            console.error("Error creating presigned URL for GPX:", error);
            throw new Error("Could not create GPX upload URL.");
        }
    }
    async createGpxTrack(input, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, input.tripId, TripMembership_1.TripRole.EDITOR);
        if (!hasAccess)
            throw new apollo_server_express_1.UserInputError(`You don't have permission to add tracks to trip ${input.tripId}.`);
        const trip = await database_1.AppDataSource.getRepository(Trip_1.Trip).findOne({ where: { id: input.tripId } });
        if (!trip)
            throw new apollo_server_express_1.UserInputError(`Trip with ID ${input.tripId} not found.`);
        let memory = null;
        if (input.memoryId) {
            memory = await database_1.AppDataSource.getRepository(Memory_1.Memory).findOne({ where: { id: input.memoryId, trip: { id: input.tripId } } });
            if (!memory)
                console.warn(`Memory with ID ${input.memoryId} not found or you don't have access.`);
        }
        const gpxTrackRepository = database_1.AppDataSource.getRepository(GPXTrack_1.GPXTrack);
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
            const gpxContent = await (0, minio_2.getObjectContent)(input.gpxFileObjectName);
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
            const segments = [];
            for (const track of gpx.tracks) {
                // Create a new segment for each track in the GPX file
                const segment = new TrackSegment_1.TrackSegment();
                segment.distance = track.distance.total;
                const points = track.points.map((p) => {
                    const routePoint = new RoutePoint_1.RoutePoint();
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
        return await database_1.AppDataSource.manager.save(newGpxTrack);
    }
    async deleteGpxTrack(id, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        }
        const gpxTrack = await database_1.AppDataSource.getRepository(GPXTrack_1.GPXTrack).findOne({
            where: { id },
            relations: ["trip", "segments", "segments.points"],
        });
        if (!gpxTrack) {
            throw new apollo_server_express_1.UserInputError(`GPXTrack with ID ${id} not found.`);
        }
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, gpxTrack.trip.id, TripMembership_1.TripRole.EDITOR);
        if (!hasAccess) {
            throw new apollo_server_express_1.AuthenticationError("You don't have permission to delete this track.");
        }
        try {
            await database_1.AppDataSource.transaction(async (em) => {
                const deletionLogs = [];
                // Log deletion of the track itself
                deletionLogs.push(em.create(DeletionLog_1.DeletionLog, { entityId: gpxTrack.id, entityType: 'GPXTrack', tripId: gpxTrack.trip.id }));
                // Log deletion of associated segments and points
                for (const segment of gpxTrack.segments) {
                    deletionLogs.push(em.create(DeletionLog_1.DeletionLog, { entityId: segment.id, entityType: 'TrackSegment', tripId: gpxTrack.trip.id }));
                    for (const point of segment.points) {
                        deletionLogs.push(em.create(DeletionLog_1.DeletionLog, { entityId: point.id, entityType: 'RoutePoint', tripId: gpxTrack.trip.id }));
                    }
                }
                // Save all deletion logs
                await em.save(DeletionLog_1.DeletionLog, deletionLogs);
                // Now, perform the actual deletion (TypeORM's cascade should handle the rest)
                await em.remove(gpxTrack);
            });
            return true;
        }
        catch (error) {
            console.error("Error deleting GPX track:", error);
            throw new Error("Could not delete GPX track.");
        }
    }
    async processGpxFile(objectName, tripId, trackName, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, tripId, TripMembership_1.TripRole.EDITOR);
        if (!hasAccess) {
            throw new apollo_server_express_1.UserInputError(`Trip with ID ${tripId} not found or you don't have access.`);
        }
        const trip = await database_1.AppDataSource.getRepository(Trip_1.Trip).findOne({ where: { id: tripId } });
        if (!trip)
            throw new apollo_server_express_1.UserInputError(`Trip with ID ${tripId} not found.`);
        const minioClient = (0, minio_1.getMinioClient)();
        let gpxContent;
        try {
            const command = new client_s3_1.GetObjectCommand({
                Bucket: minio_1.BUCKET_NAME,
                Key: objectName,
            });
            const response = await minioClient.send(command);
            gpxContent = await response.Body.transformToString();
        }
        catch (error) {
            console.error(`Error downloading GPX file ${objectName} from MinIO:`, error);
            throw new Error("Failed to download GPX file.");
        }
        const gpx = new GpxParser();
        gpx.parse(gpxContent);
        const gpxTrackRepository = database_1.AppDataSource.getRepository(GPXTrack_1.GPXTrack);
        const trackSegmentRepository = database_1.AppDataSource.getRepository(TrackSegment_1.TrackSegment);
        const routePointRepository = database_1.AppDataSource.getRepository(RoutePoint_1.RoutePoint);
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
                const routePoints = track.points.map((point) => {
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
};
exports.GPXResolver = GPXResolver;
__decorate([
    (0, type_graphql_1.FieldResolver)(() => String, { nullable: true }),
    __param(0, (0, type_graphql_1.Root)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [GPXTrack_1.GPXTrack]),
    __metadata("design:returntype", Promise)
], GPXResolver.prototype, "downloadUrl", null);
__decorate([
    (0, type_graphql_1.Query)(() => [GPXTrack_1.GPXTrack], { description: "Get all GPX tracks for a specific trip." }),
    __param(0, (0, type_graphql_1.Arg)("tripId", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], GPXResolver.prototype, "gpxTracksByTrip", null);
__decorate([
    (0, type_graphql_1.Query)(() => GPXTrack_1.GPXTrack, { nullable: true, description: "Get a single GPX track by its ID, including all its data." }),
    __param(0, (0, type_graphql_1.Arg)("id", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], GPXResolver.prototype, "gpxTrack", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => PresignedUrlResponse_1.PresignedUrlResponse, { description: "Generates a pre-signed URL to upload a GPX file." }),
    __param(0, (0, type_graphql_1.Arg)("filename")),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], GPXResolver.prototype, "generateGpxUploadUrl", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => GPXTrack_1.GPXTrack, { description: "Creates a new GPX track record and processes the uploaded file." }),
    __param(0, (0, type_graphql_1.Arg)("input")),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [GPXTrackInput_1.GPXTrackInput, Object]),
    __metadata("design:returntype", Promise)
], GPXResolver.prototype, "createGpxTrack", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Boolean, { description: "Deletes a GPX track and its associated data." }),
    __param(0, (0, type_graphql_1.Arg)("id", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], GPXResolver.prototype, "deleteGpxTrack", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => GPXTrack_1.GPXTrack, { description: "Processes an uploaded GPX file and creates the track data." }),
    __param(0, (0, type_graphql_1.Arg)("objectName")),
    __param(1, (0, type_graphql_1.Arg)("tripId", () => type_graphql_1.ID)),
    __param(2, (0, type_graphql_1.Arg)("trackName")),
    __param(3, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, Object]),
    __metadata("design:returntype", Promise)
], GPXResolver.prototype, "processGpxFile", null);
exports.GPXResolver = GPXResolver = __decorate([
    (0, type_graphql_1.Resolver)(GPXTrack_1.GPXTrack)
], GPXResolver);
