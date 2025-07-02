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
        
        // Prüfe, ob der eingeloggte Benutzer mindestens VIEWER-Rechte für diese Reise hat
        const hasAccess = await checkTripAccess(userId, id, TripRole.VIEWER);
        if (!hasAccess) {
            throw new AuthenticationError("You don't have permission to view this trip.");
        }

        const trip = await AppDataSource.getRepository(Trip).findOne({ where: { id } });
        // Wenn die Reise nicht existiert, null zurückgeben (GraphQL-Konvention)
        return trip;
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
            return null; // Or throw a NotFoundError
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

            // Optional: Check if the object actually exists in Minio before assigning

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
        
        // Use transaction to ensure proper cleanup order
        try {
            await AppDataSource.transaction(async (transactionalEntityManager) => {
                // 1. First delete all MediaItems (they reference Memory)
                const memories = await transactionalEntityManager.find(Memory, { 
                    where: { trip: { id } },
                    relations: ["mediaItems"]
                });
                
                for (const memory of memories) {
                    if (memory.mediaItems && memory.mediaItems.length > 0) {
                        await transactionalEntityManager.remove(MediaItem, memory.mediaItems);
                    }
                }
                
                // 2. Delete all Memories (they reference Trip)
                await transactionalEntityManager.delete(Memory, { trip: { id } });
                
                // 3. Delete all RoutePoints (they reference Trip and TrackSegment)
                await transactionalEntityManager.delete(RoutePoint, { trip: { id } });
                
                // 4. Delete all TrackSegments (they reference Trip and GPXTrack)
                await transactionalEntityManager.delete(TrackSegment, { trip: { id } });
                
                // 5. Delete all GPXTracks (they reference Trip)
                await transactionalEntityManager.delete(GPXTrack, { trip: { id } });
                
                // 6. Delete all trip memberships
                await transactionalEntityManager.delete(TripMembership, { trip: { id } });
                
                // 7. Finally delete the trip itself
                await transactionalEntityManager.delete(Trip, { id });
            });
            
            return true;
        } catch (error) {
            console.error("Error deleting trip:", error);
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
} 