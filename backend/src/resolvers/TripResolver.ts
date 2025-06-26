import { Resolver, Query, Mutation, Arg, FieldResolver, Root, ID, ObjectType, Field } from 'type-graphql';
import { Trip } from '../entities/Trip';
import { TripInput } from '../entities/TripInput';
import { UpdateTripInput } from '../entities/UpdateTripInput';
import { Memory } from '../entities/Memory';
import { AppDataSource } from '../utils/database';
import { generatePresignedPutUrl } from '../utils/minio';
import { v4 as uuidv4 } from 'uuid';
import { PresignedUrlResponse } from './types/PresignedUrlResponse';

@Resolver(Trip)
export class TripResolver {

    @Query(() => [Trip], { description: "Get all trips" })
    async trips(): Promise<Trip[]> {
        try {
            const result = await AppDataSource.getRepository(Trip).find();
            return result;
        } catch (error) {
            console.error("Error fetching trips:", error);
            throw new Error("Could not fetch trips.");
        }
    }

    @Mutation(() => Trip, { description: "Create a new trip" })
    async createTrip(@Arg("input") input: TripInput): Promise<Trip> {
        const trip = AppDataSource.getRepository(Trip).create(input);
        try {
            await AppDataSource.getRepository(Trip).save(trip);
            return trip;
        } catch (error) {
            console.error("Error creating trip:", error);
            throw new Error("Could not create trip.");
        }
    }

    @Mutation(() => Trip, { description: "Update an existing trip" })
    async updateTrip(
        @Arg("id", () => ID) id: string,
        @Arg("input") input: UpdateTripInput
    ): Promise<Trip | null> {
        try {
            const trip = await AppDataSource.getRepository(Trip).findOne({ where: { id } });
            if (!trip) {
                return null;
            }
            Object.assign(trip, input);
            await AppDataSource.getRepository(Trip).save(trip);
            return trip;
        } catch (error) {
            console.error("Error updating trip:", error);
            throw new Error("Could not update trip.");
        }
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
    async deleteTrip(@Arg("id", () => ID) id: string): Promise<boolean> {
        try {
            const deleteResult = await AppDataSource.getRepository(Trip).delete(id);
            return deleteResult.affected === 1;
        } catch (error) {
            console.error("Error deleting trip:", error);
            throw new Error("Could not delete trip.");
        }
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
} 