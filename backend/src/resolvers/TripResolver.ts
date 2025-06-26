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
        
        const trip = await AppDataSource.getRepository(Trip).findOne({ where: { id } });
        if (!trip) {
            return null;
        }
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

        // Create a new membership instance for the owner
        const membership = membershipRepository.create({
            user: user,
            trip: trip,
            role: TripRole.OWNER,
        });

        // Use a transaction to save both the trip and the membership
        try {
            await AppDataSource.transaction(async (transactionalEntityManager) => {
                await transactionalEntityManager.save(trip);
                await transactionalEntityManager.save(membership);
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
        
        const deleteResult = await AppDataSource.getRepository(Trip).delete(id);
        
        if (deleteResult.affected === 0) {
            // Consider throwing a NotFoundError if the trip didn't exist
            return false;
        }

        return true;
    }

    @FieldResolver(() => [Memory])
    async memories(@Root() trip: Trip): Promise<Memory[]> {
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