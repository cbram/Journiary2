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
exports.TripResolver = void 0;
const type_graphql_1 = require("type-graphql");
const Trip_1 = require("../entities/Trip");
const TripInput_1 = require("../entities/TripInput");
const UpdateTripInput_1 = require("../entities/UpdateTripInput");
const Memory_1 = require("../entities/Memory");
const database_1 = require("../utils/database");
const minio_1 = require("../utils/minio");
const uuid_1 = require("uuid");
const PresignedUrlResponse_1 = require("./types/PresignedUrlResponse");
const User_1 = require("../entities/User");
const apollo_server_express_1 = require("apollo-server-express");
const TripMembership_1 = require("../entities/TripMembership");
const auth_1 = require("../utils/auth");
const MediaItem_1 = require("../entities/MediaItem");
const Permission_1 = require("../entities/Permission");
const DeletionLog_1 = require("../entities/DeletionLog");
let TripMembershipResponse = class TripMembershipResponse {
};
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    __metadata("design:type", String)
], TripMembershipResponse.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => String),
    __metadata("design:type", String)
], TripMembershipResponse.prototype, "tripId", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => String),
    __metadata("design:type", String)
], TripMembershipResponse.prototype, "userId", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => TripMembership_1.TripRole),
    __metadata("design:type", String)
], TripMembershipResponse.prototype, "role", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => String),
    __metadata("design:type", String)
], TripMembershipResponse.prototype, "status", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => User_1.User),
    __metadata("design:type", User_1.User)
], TripMembershipResponse.prototype, "user", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Trip_1.Trip, { nullable: true }),
    __metadata("design:type", Trip_1.Trip)
], TripMembershipResponse.prototype, "trip", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Date),
    __metadata("design:type", Date)
], TripMembershipResponse.prototype, "createdAt", void 0);
TripMembershipResponse = __decorate([
    (0, type_graphql_1.ObjectType)()
], TripMembershipResponse);
let TripResolver = class TripResolver {
    async trips({ userId }) {
        if (!userId) {
            return [];
        }
        // Find all memberships for the user and return the associated trips
        const memberships = await database_1.AppDataSource.getRepository(TripMembership_1.TripMembership).find({
            where: { user: { id: userId } },
            relations: ["trip"],
        });
        return memberships.map(m => m.trip);
    }
    async trip(id, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to view this trip.");
        }
        // Check if the user has at least VIEWER rights for this trip
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, id, TripMembership_1.TripRole.VIEWER);
        if (!hasAccess) {
            throw new apollo_server_express_1.AuthenticationError("You don't have permission to view this trip.");
        }
        const trip = await database_1.AppDataSource.getRepository(Trip_1.Trip).findOne({ where: { id } });
        return trip;
    }
    async getTripMembers(tripId, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to view trip members.");
        }
        // Check if the user has at least VIEWER rights for this trip
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, tripId, TripMembership_1.TripRole.VIEWER);
        if (!hasAccess) {
            throw new apollo_server_express_1.AuthenticationError("You don't have permission to view members of this trip.");
        }
        const memberships = await database_1.AppDataSource.getRepository(TripMembership_1.TripMembership).find({
            where: { trip: { id: tripId } },
            relations: ["user"],
        });
        return memberships.map(membership => ({
            id: membership.id,
            tripId: tripId,
            userId: membership.user.id,
            role: membership.role,
            status: "accepted", // Default status for existing memberships
            user: membership.user,
            trip: undefined,
            createdAt: new Date() // TripMembership doesn't have createdAt, so use current date
        }));
    }
    async createTrip(input, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to create a trip.");
        }
        const user = await database_1.AppDataSource.getRepository(User_1.User).findOneBy({ id: userId });
        if (!user) {
            throw new apollo_server_express_1.AuthenticationError("User not found.");
        }
        const tripRepository = database_1.AppDataSource.getRepository(Trip_1.Trip);
        const membershipRepository = database_1.AppDataSource.getRepository(TripMembership_1.TripMembership);
        // Create a new trip instance
        const trip = tripRepository.create(input);
        // Use a transaction to save both the trip and the membership
        try {
            await database_1.AppDataSource.transaction(async (transactionalEntityManager) => {
                // First save the trip to get its ID
                const savedTrip = await transactionalEntityManager.save(Trip_1.Trip, trip);
                // Now create membership with the saved trip
                const membership = membershipRepository.create({
                    user: user,
                    trip: savedTrip,
                    role: TripMembership_1.TripRole.OWNER,
                });
                // Save the membership
                await transactionalEntityManager.save(TripMembership_1.TripMembership, membership);
                // Update the trip reference for return
                Object.assign(trip, savedTrip);
            });
            return trip;
        }
        catch (error) {
            console.error("Error creating trip with membership:", error);
            throw new Error("Could not create trip.");
        }
    }
    async updateTrip(id, input, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        }
        if (!(await (0, auth_1.checkTripAccess)(userId, id, TripMembership_1.TripRole.EDITOR))) {
            throw new apollo_server_express_1.AuthenticationError("You don't have permission to edit this trip.");
        }
        const trip = await database_1.AppDataSource.getRepository(Trip_1.Trip).findOne({ where: { id } });
        if (!trip) {
            return null;
        }
        Object.assign(trip, input);
        await database_1.AppDataSource.getRepository(Trip_1.Trip).save(trip);
        return trip;
    }
    async generateTripCoverImageUploadUrl(tripId, contentType) {
        try {
            // Basic content type validation
            const extension = contentType.split('/')[1];
            if (!extension || !['jpeg', 'png', 'jpg', 'webp'].includes(extension)) {
                throw new Error("Invalid content type. Only jpeg, jpg, png, and webp are allowed.");
            }
            const objectName = `trip-${tripId}/cover-${(0, uuid_1.v4)()}.${extension}`;
            const uploadUrl = await (0, minio_1.generatePresignedPutUrl)(objectName, contentType);
            return { uploadUrl, objectName };
        }
        catch (error) {
            console.error("Error generating upload URL:", error);
            throw new Error("Could not generate upload URL.");
        }
    }
    async assignCoverImageToTrip(tripId, objectName) {
        const tripRepository = database_1.AppDataSource.getRepository(Trip_1.Trip);
        try {
            const trip = await tripRepository.findOneBy({ id: tripId });
            if (!trip) {
                throw new Error("Trip not found.");
            }
            trip.coverImageObjectName = objectName;
            await tripRepository.save(trip);
            return trip;
        }
        catch (error) {
            console.error("Error assigning cover image:", error);
            throw new Error("Could not assign cover image.");
        }
    }
    async deleteTrip(id, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        }
        if (!(await (0, auth_1.checkTripAccess)(userId, id, TripMembership_1.TripRole.OWNER))) {
            throw new apollo_server_express_1.AuthenticationError("You must be an owner to delete this trip.");
        }
        const trip = await database_1.AppDataSource.getRepository(Trip_1.Trip).findOne({ where: { id }, relations: ["memories", "gpxTracks", "routePoints"] });
        if (!trip) {
            throw new apollo_server_express_1.UserInputError("Trip not found.");
        }
        try {
            await database_1.AppDataSource.transaction(async (em) => {
                const deletionLogs = [];
                // Log deletion of the trip itself
                deletionLogs.push(em.create(DeletionLog_1.DeletionLog, { entityId: trip.id, entityType: 'Trip', tripId: trip.id }));
                // Log deletion of associated memories and their media items
                for (const memory of trip.memories) {
                    deletionLogs.push(em.create(DeletionLog_1.DeletionLog, { entityId: memory.id, entityType: 'Memory', tripId: trip.id }));
                    const mediaItems = await em.find(MediaItem_1.MediaItem, { where: { memory: { id: memory.id } } });
                    for (const mediaItem of mediaItems) {
                        deletionLogs.push(em.create(DeletionLog_1.DeletionLog, { entityId: mediaItem.id, entityType: 'MediaItem', tripId: trip.id }));
                    }
                }
                // Log deletion of associated GPX tracks
                for (const track of trip.gpxTracks) {
                    deletionLogs.push(em.create(DeletionLog_1.DeletionLog, { entityId: track.id, entityType: 'GPXTrack', tripId: trip.id }));
                }
                // Log deletion of associated route points
                for (const point of trip.routePoints) {
                    deletionLogs.push(em.create(DeletionLog_1.DeletionLog, { entityId: point.id, entityType: 'RoutePoint', tripId: trip.id }));
                }
                // Save all deletion logs
                await em.save(DeletionLog_1.DeletionLog, deletionLogs);
                // Now, perform the actual deletion (TypeORM's cascade should handle most of this)
                await em.remove(trip);
            });
            return true;
        }
        catch (error) {
            console.error("Error deleting trip:", error);
            // Re-throw a generic error to the client
            throw new Error("Could not delete trip.");
        }
    }
    async memories(trip, { userId }) {
        // Benutzer muss Zugriff auf die Reise haben, um Erinnerungen sehen zu dürfen
        if (!userId || !(await (0, auth_1.checkTripAccess)(userId, trip.id, TripMembership_1.TripRole.VIEWER))) {
            throw new apollo_server_express_1.AuthenticationError("You don't have permission to access memories for this trip.");
        }
        try {
            const memoryRepository = database_1.AppDataSource.getRepository(Memory_1.Memory);
            return await memoryRepository.find({ where: { trip: { id: trip.id } } });
        }
        catch (error) {
            console.error(`Error fetching memories for trip ${trip.id}:`, error);
            throw new Error("Could not fetch memories for the trip.");
        }
    }
    async shareTrip(tripId, email, permission, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to share a trip.");
        }
        // Check if the user has at least EDITOR rights for this trip
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, tripId, TripMembership_1.TripRole.EDITOR);
        if (!hasAccess) {
            throw new apollo_server_express_1.AuthenticationError("You don't have permission to share this trip.");
        }
        // Find the trip
        const trip = await database_1.AppDataSource.getRepository(Trip_1.Trip).findOneBy({ id: tripId });
        if (!trip) {
            throw new apollo_server_express_1.UserInputError(`Trip with ID ${tripId} not found.`);
        }
        // Find the user to share with
        const userToShareWith = await database_1.AppDataSource.getRepository(User_1.User).findOneBy({ email });
        if (!userToShareWith) {
            throw new apollo_server_express_1.UserInputError(`User with email ${email} not found.`);
        }
        // Check if user is already a member
        const existingMembership = await database_1.AppDataSource.getRepository(TripMembership_1.TripMembership).findOne({
            where: {
                user: { id: userToShareWith.id },
                trip: { id: tripId }
            }
        });
        if (existingMembership) {
            throw new apollo_server_express_1.UserInputError(`User ${email} is already a member of this trip.`);
        }
        // Convert Permission to TripRole
        let tripRole;
        switch (permission) {
            case Permission_1.Permission.READ:
                tripRole = TripMembership_1.TripRole.VIEWER;
                break;
            case Permission_1.Permission.WRITE:
            case Permission_1.Permission.ADMIN: // ADMIN erhält EDITOR-Rechte, nicht OWNER!
                tripRole = TripMembership_1.TripRole.EDITOR;
                break;
            default:
                tripRole = TripMembership_1.TripRole.VIEWER;
        }
        // Create membership
        const membership = database_1.AppDataSource.getRepository(TripMembership_1.TripMembership).create({
            user: userToShareWith,
            trip: trip,
            role: tripRole,
        });
        return await database_1.AppDataSource.getRepository(TripMembership_1.TripMembership).save(membership);
    }
    async coverImageUrl(trip) {
        if (!trip.coverImageObjectName)
            return null;
        try {
            return (0, minio_1.generatePresignedGetUrl)(trip.coverImageObjectName, 1800); // 30 minutes expiry
        }
        catch (error) {
            console.error(`Failed to get cover image URL for ${trip.coverImageObjectName}`, error);
            return null;
        }
    }
    async claimTrip(tripId, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to claim a trip.");
        }
        const tripRepository = database_1.AppDataSource.getRepository(Trip_1.Trip);
        const membershipRepository = database_1.AppDataSource.getRepository(TripMembership_1.TripMembership);
        const userRepository = database_1.AppDataSource.getRepository(User_1.User);
        const trip = await tripRepository.findOneBy({ id: tripId });
        if (!trip) {
            throw new apollo_server_express_1.UserInputError(`Trip with ID ${tripId} not found.`);
        }
        // Prüfen, ob bereits Membership existiert
        const existingMembership = await membershipRepository.findOne({
            where: { trip: { id: tripId }, user: { id: userId } },
        });
        if (!existingMembership) {
            const user = await userRepository.findOneBy({ id: userId });
            if (!user) {
                throw new Error("User not found.");
            }
            const membership = membershipRepository.create({
                trip: trip,
                user: user,
                role: TripMembership_1.TripRole.OWNER,
            });
            await membershipRepository.save(membership);
        }
        return trip;
    }
};
exports.TripResolver = TripResolver;
__decorate([
    (0, type_graphql_1.Query)(() => [Trip_1.Trip], { description: "Get all trips the logged-in user is a member of" }),
    __param(0, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], TripResolver.prototype, "trips", null);
__decorate([
    (0, type_graphql_1.Query)(() => Trip_1.Trip, { nullable: true, description: "Get a single trip by ID." }),
    __param(0, (0, type_graphql_1.Arg)("id", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], TripResolver.prototype, "trip", null);
__decorate([
    (0, type_graphql_1.Query)(() => [TripMembershipResponse], { description: "Get all members of a trip" }),
    __param(0, (0, type_graphql_1.Arg)("tripId", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], TripResolver.prototype, "getTripMembers", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Trip_1.Trip, { description: "Create a new trip" }),
    __param(0, (0, type_graphql_1.Arg)("input")),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [TripInput_1.TripInput, Object]),
    __metadata("design:returntype", Promise)
], TripResolver.prototype, "createTrip", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Trip_1.Trip, { description: "Update an existing trip" }),
    __param(0, (0, type_graphql_1.Arg)("id", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Arg)("input")),
    __param(2, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, UpdateTripInput_1.UpdateTripInput, Object]),
    __metadata("design:returntype", Promise)
], TripResolver.prototype, "updateTrip", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => PresignedUrlResponse_1.PresignedUrlResponse, { description: "Generate a pre-signed URL to upload a trip cover image" }),
    __param(0, (0, type_graphql_1.Arg)("tripId", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Arg)("contentType")),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], TripResolver.prototype, "generateTripCoverImageUploadUrl", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Trip_1.Trip, { description: "Assign a new cover image to a trip after upload" }),
    __param(0, (0, type_graphql_1.Arg)("tripId", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Arg)("objectName")),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], TripResolver.prototype, "assignCoverImageToTrip", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Boolean, { description: "Delete a trip" }),
    __param(0, (0, type_graphql_1.Arg)("id", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], TripResolver.prototype, "deleteTrip", null);
__decorate([
    (0, type_graphql_1.FieldResolver)(() => [Memory_1.Memory]),
    __param(0, (0, type_graphql_1.Root)()),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Trip_1.Trip, Object]),
    __metadata("design:returntype", Promise)
], TripResolver.prototype, "memories", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => TripMembership_1.TripMembership, { description: "Share a trip with another user" }),
    __param(0, (0, type_graphql_1.Arg)("tripId", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Arg)("email")),
    __param(2, (0, type_graphql_1.Arg)("permission", () => Permission_1.Permission)),
    __param(3, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, Object]),
    __metadata("design:returntype", Promise)
], TripResolver.prototype, "shareTrip", null);
__decorate([
    (0, type_graphql_1.FieldResolver)(() => String, { nullable: true }),
    __param(0, (0, type_graphql_1.Root)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Trip_1.Trip]),
    __metadata("design:returntype", Promise)
], TripResolver.prototype, "coverImageUrl", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Trip_1.Trip, { description: "Claim an existing trip for the current user (adds OWNER membership if missing)" }),
    __param(0, (0, type_graphql_1.Arg)("tripId", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], TripResolver.prototype, "claimTrip", null);
exports.TripResolver = TripResolver = __decorate([
    (0, type_graphql_1.Resolver)(Trip_1.Trip)
], TripResolver);
