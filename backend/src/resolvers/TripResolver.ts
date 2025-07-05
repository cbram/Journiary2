import { Resolver, Query, Mutation, Arg, FieldResolver, Root, ID, ObjectType, Field, Ctx } from 'type-graphql';
import { Trip } from '../entities/Trip';
import { TripInput } from '../entities/TripInput';
import { UpdateTripInput } from '../entities/UpdateTripInput';
import { Memory } from '../entities/Memory';
import { AppDataSource } from '../utils/database';
import { generatePresignedPutUrl, generatePresignedGetUrl } from '../utils/minio';
import { v4 as uuidv4 } from 'uuid';
import { PresignedUrlResponse } from './types/PresignedUrlResponse';
import { MyContext } from '../index';
import { User } from '../entities/User';
import { AuthenticationError, UserInputError } from 'apollo-server-express';
import { TripMembership, TripRole } from '../entities/TripMembership';
import { checkTripAccess } from '../utils/auth';
import { MediaItem } from '../entities/MediaItem';
import { RoutePoint } from '../entities/RoutePoint';
import { TrackSegment } from '../entities/TrackSegment';
import { GPXTrack } from '../entities/GPXTrack';
import { Permission } from '../entities/Permission';
import { Not } from 'typeorm';
import { DeletionLog } from '../entities/DeletionLog';

@ObjectType()
class TripMembershipResponse {
    @Field(() => ID)
    id!: string;

    @Field(() => String)
    tripId!: string;

    @Field(() => String)
    userId!: string;

    @Field(() => TripRole)
    role!: TripRole;

    @Field(() => String)
    status!: string;

    @Field(() => User)
    user!: User;

    @Field(() => Trip, { nullable: true })
    trip?: Trip;

    @Field(() => Date)
    createdAt!: Date;
}

@Resolver(Trip)
export class TripResolver {

    @Query(() => [Trip], { description: "Get all trips the logged-in user is a member of" })
    async trips(@Ctx() { userId }: MyContext): Promise<Trip[]> {
        if (!userId) {
            return [];
        }

        // Find all memberships for the user and return the associated trips
        const memberships = await AppDataSource.getRepository(TripMembership).find({
            where: { user: { id: userId } },
            relations: ["trip"],
        });

        return memberships.map(m => m.trip);
    }

    @Query(() => Trip, { nullable: true, description: "Get a single trip by ID." })
    async trip(
        @Arg("id", () => ID) id: string,
        @Ctx() { userId }: MyContext
    ): Promise<Trip | null> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to view this trip.");
        }
        
        // Check if the user has at least VIEWER rights for this trip
        const hasAccess = await checkTripAccess(userId, id, TripRole.VIEWER);
        if (!hasAccess) {
            throw new AuthenticationError("You don't have permission to view this trip.");
        }

        const trip = await AppDataSource.getRepository(Trip).findOne({ where: { id } });
        return trip;
    }

    @Query(() => [TripMembershipResponse], { description: "Get all members of a trip" })
    async getTripMembers(
        @Arg("tripId", () => ID) tripId: string,
        @Ctx() { userId }: MyContext
    ): Promise<TripMembershipResponse[]> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to view trip members.");
        }

        // Check if the user has at least VIEWER rights for this trip
        const hasAccess = await checkTripAccess(userId, tripId, TripRole.VIEWER);
        if (!hasAccess) {
            throw new AuthenticationError("You don't have permission to view members of this trip.");
        }

        const memberships = await AppDataSource.getRepository(TripMembership).find({
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

    @Mutation(() => Trip, { description: "Create a new trip" })
    async createTrip(
        @Arg("input") input: TripInput,
        @Ctx() { userId }: MyContext
    ): Promise<Trip> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to create a trip.");
        }
        
        const user = await AppDataSource.getRepository(User).findOneBy({ id: userId });
        if (!user) {
            throw new AuthenticationError("User not found.");
        }

        const tripRepository = AppDataSource.getRepository(Trip);
        const membershipRepository = AppDataSource.getRepository(TripMembership);

        // Create a new trip instance
        const trip = tripRepository.create(input);

        // Use a transaction to save both the trip and the membership
        try {
            await AppDataSource.transaction(async (transactionalEntityManager) => {
                // First save the trip to get its ID
                const savedTrip = await transactionalEntityManager.save(Trip, trip);
                
                // Now create membership with the saved trip
                const membership = membershipRepository.create({
                    user: user,
                    trip: savedTrip,
                    role: TripRole.OWNER,
                });
                
                // Save the membership
                await transactionalEntityManager.save(TripMembership, membership);
                
                // Update the trip reference for return
                Object.assign(trip, savedTrip);
            });
            return trip;
        } catch (error) {
            console.error("Error creating trip with membership:", error);
            throw new Error("Could not create trip.");
        }
    }

    @Mutation(() => Trip, { description: "Update an existing trip" })
    async updateTrip(
        @Arg("id", () => ID) id: string,
        @Arg("input") input: UpdateTripInput,
        @Ctx() { userId }: MyContext
    ): Promise<Trip | null> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in.");
        }
        if (!(await checkTripAccess(userId, id, TripRole.EDITOR))) {
            throw new AuthenticationError("You don't have permission to edit this trip.");
        }

        const trip = await AppDataSource.getRepository(Trip).findOne({ where: { id } });
        if (!trip) {
            return null;
        }

        Object.assign(trip, input);
        await AppDataSource.getRepository(Trip).save(trip);
        return trip;
    }

    @Mutation(() => PresignedUrlResponse, { description: "Generate a pre-signed URL to upload a trip cover image" })
    async generateTripCoverImageUploadUrl(
        @Arg("tripId", () => ID) tripId: string,
        @Arg("contentType") contentType: string
    ): Promise<PresignedUrlResponse> {
        try {
            // Basic content type validation
            const extension = contentType.split('/')[1];
            if (!extension || !['jpeg', 'png', 'jpg', 'webp'].includes(extension)) {
                throw new Error("Invalid content type. Only jpeg, jpg, png, and webp are allowed.");
            }

            const objectName = `trip-${tripId}/cover-${uuidv4()}.${extension}`;
            const uploadUrl = await generatePresignedPutUrl(objectName, contentType);

            return { uploadUrl, objectName };
        } catch (error) {
            console.error("Error generating upload URL:", error);
            throw new Error("Could not generate upload URL.");
        }
    }

    @Mutation(() => Trip, { description: "Assign a new cover image to a trip after upload" })
    async assignCoverImageToTrip(
        @Arg("tripId", () => ID) tripId: string,
        @Arg("objectName") objectName: string
    ): Promise<Trip> {
        const tripRepository = AppDataSource.getRepository(Trip);
        try {
            const trip = await tripRepository.findOneBy({ id: tripId });
            if (!trip) {
                throw new Error("Trip not found.");
            }

            trip.coverImageObjectName = objectName;
            await tripRepository.save(trip);
            return trip;
        } catch (error) {
            console.error("Error assigning cover image:", error);
            throw new Error("Could not assign cover image.");
        }
    }

    @Mutation(() => Boolean, { description: "Delete a trip" })
    async deleteTrip(
        @Arg("id", () => ID) id: string,
        @Ctx() { userId }: MyContext
    ): Promise<boolean> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in.");
        }
        if (!(await checkTripAccess(userId, id, TripRole.OWNER))) {
            throw new AuthenticationError("You must be an owner to delete this trip.");
        }
        
        const trip = await AppDataSource.getRepository(Trip).findOne({ where: { id }, relations: ["memories", "gpxTracks", "routePoints"] });
        if (!trip) {
            throw new UserInputError("Trip not found.");
        }

        try {
            await AppDataSource.transaction(async (em) => {
                const deletionLogs: DeletionLog[] = [];

                // Log deletion of the trip itself
                deletionLogs.push(em.create(DeletionLog, { entityId: trip.id, entityType: 'Trip', tripId: trip.id }));

                // Log deletion of associated memories and their media items
                for (const memory of trip.memories) {
                    deletionLogs.push(em.create(DeletionLog, { entityId: memory.id, entityType: 'Memory', tripId: trip.id }));
                    const mediaItems = await em.find(MediaItem, { where: { memory: { id: memory.id } } });
                    for (const mediaItem of mediaItems) {
                        deletionLogs.push(em.create(DeletionLog, { entityId: mediaItem.id, entityType: 'MediaItem', tripId: trip.id }));
                    }
                }

                // Log deletion of associated GPX tracks
                for (const track of trip.gpxTracks) {
                    deletionLogs.push(em.create(DeletionLog, { entityId: track.id, entityType: 'GPXTrack', tripId: trip.id }));
                }

                // Log deletion of associated route points
                 for (const point of trip.routePoints) {
                    deletionLogs.push(em.create(DeletionLog, { entityId: point.id, entityType: 'RoutePoint', tripId: trip.id }));
                }
                
                // Save all deletion logs
                await em.save(DeletionLog, deletionLogs);

                // Now, perform the actual deletion (TypeORM's cascade should handle most of this)
                await em.remove(trip);
            });

            return true;
        } catch (error) {
            console.error("Error deleting trip:", error);
            // Re-throw a generic error to the client
            throw new Error("Could not delete trip.");
        }
    }

    @FieldResolver(() => [Memory])
    async memories(
        @Root() trip: Trip,
        @Ctx() { userId }: MyContext
    ): Promise<Memory[]> {
        // Benutzer muss Zugriff auf die Reise haben, um Erinnerungen sehen zu dürfen
        if (!userId || !(await checkTripAccess(userId, trip.id, TripRole.VIEWER))) {
            throw new AuthenticationError("You don't have permission to access memories for this trip.");
        }

        try {
            const memoryRepository = AppDataSource.getRepository(Memory);
            return await memoryRepository.find({ where: { trip: { id: trip.id } } });
        } catch (error) {
            console.error(`Error fetching memories for trip ${trip.id}:`, error);
            throw new Error("Could not fetch memories for the trip.");
        }
    }

    @Mutation(() => TripMembership, { description: "Share a trip with another user" })
    async shareTrip(
        @Arg("tripId", () => ID) tripId: string,
        @Arg("email") email: string,
        @Arg("permission", () => Permission) permission: Permission,
        @Ctx() { userId }: MyContext
    ): Promise<TripMembership> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to share a trip.");
        }

        // Check if the user has at least EDITOR rights for this trip
        const hasAccess = await checkTripAccess(userId, tripId, TripRole.EDITOR);
        if (!hasAccess) {
            throw new AuthenticationError("You don't have permission to share this trip.");
        }

        // Find the trip
        const trip = await AppDataSource.getRepository(Trip).findOneBy({ id: tripId });
        if (!trip) {
            throw new UserInputError(`Trip with ID ${tripId} not found.`);
        }

        // Find the user to share with
        const userToShareWith = await AppDataSource.getRepository(User).findOneBy({ email });
        if (!userToShareWith) {
            throw new UserInputError(`User with email ${email} not found.`);
        }

        // Check if user is already a member
        const existingMembership = await AppDataSource.getRepository(TripMembership).findOne({
            where: {
                user: { id: userToShareWith.id },
                trip: { id: tripId }
            }
        });

        if (existingMembership) {
            throw new UserInputError(`User ${email} is already a member of this trip.`);
        }

        // Convert Permission to TripRole
        let tripRole: TripRole;
        switch (permission) {
            case Permission.READ:
                tripRole = TripRole.VIEWER;
                break;
            case Permission.WRITE:
            case Permission.ADMIN: // ADMIN erhält EDITOR-Rechte, nicht OWNER!
                tripRole = TripRole.EDITOR;
                break;
            default:
                tripRole = TripRole.VIEWER;
        }

        // Create membership
        const membership = AppDataSource.getRepository(TripMembership).create({
            user: userToShareWith,
            trip: trip,
            role: tripRole,
        });

        return await AppDataSource.getRepository(TripMembership).save(membership);
    }

    @FieldResolver(() => String, { nullable: true })
    async coverImageUrl(@Root() trip: Trip): Promise<string | null> {
        if (!trip.coverImageObjectName) return null;
        try {
            return generatePresignedGetUrl(trip.coverImageObjectName, 1800); // 30 minutes expiry
        } catch (error) {
            console.error(`Failed to get cover image URL for ${trip.coverImageObjectName}`, error);
            return null;
        }
    }

    @Mutation(() => Trip, { description: "Claim an existing trip for the current user (adds OWNER membership if missing)" })
    async claimTrip(
        @Arg("tripId", () => ID) tripId: string,
        @Ctx() { userId }: MyContext
    ): Promise<Trip> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to claim a trip.");
        }

        const tripRepository = AppDataSource.getRepository(Trip);
        const membershipRepository = AppDataSource.getRepository(TripMembership);
        const userRepository = AppDataSource.getRepository(User);

        const trip = await tripRepository.findOneBy({ id: tripId });
        if (!trip) {
            throw new UserInputError(`Trip with ID ${tripId} not found.`);
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
                role: TripRole.OWNER,
            });

            await membershipRepository.save(membership);
        }

        return trip;
    }
} 