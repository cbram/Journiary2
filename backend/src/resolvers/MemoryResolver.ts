import { Resolver, Query, Mutation, Arg, FieldResolver, Root, Ctx, ID } from 'type-graphql';
import { Memory } from '../entities/Memory';
import { MemoryInput } from '../entities/MemoryInput';
import { UpdateMemoryInput } from '../entities/UpdateMemoryInput';
import { AppDataSource } from '../utils/database';
import { MediaItem } from '../entities/MediaItem';
import { Trip } from '../entities/Trip';
import { User } from '../entities/User';
import { Tag } from "../entities/Tag";
import { In, Like } from "typeorm";
import { MyContext } from '../index';
import { AuthenticationError, UserInputError } from 'apollo-server-express';
import { checkTripAccess } from '../utils/auth';
import { TripRole } from '../entities/TripMembership';
import { TripMembership } from '../entities/TripMembership';

@Resolver(() => Memory)
export class MemoryResolver {

    @Query(() => [Memory], { description: "Get all memories for trips the user is a member of" })
    async memories(
        @Ctx() { userId }: MyContext,
        @Arg("tripId", () => ID, { nullable: true }) tripId?: string
    ): Promise<Memory[]> {
        if (!userId) {
            return [];
        }

        const memberships = await AppDataSource.getRepository(TripMembership).find({
            where: { user: { id: userId } },
            relations: ["trip"],
        });
        const tripIds = memberships.map(m => m.trip.id);

        if (tripIds.length === 0) {
            return [];
        }
        
        const whereCondition: any = { trip: { id: In(tripIds) } };
        if (tripId && tripIds.includes(tripId)) {
            whereCondition.trip = { id: tripId };
        }

        return AppDataSource.getRepository(Memory).find({
            where: whereCondition,
            relations: ["mediaItems", "trip", "tags"]
        });
    }

    @Query(() => Memory, { nullable: true, description: "Get a single memory by ID" })
    async memory(
        @Arg("id", () => String) id: string,
        @Ctx() { userId }: MyContext
    ): Promise<Memory | null> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to view this memory.");
        }

        const memory = await AppDataSource.getRepository(Memory).findOne({
            where: { id },
            relations: ["trip", "mediaItems", "tags"]
        });

        if (!memory) {
            return null;
        }

        // Check if the user has at least VIEWER rights for the trip this memory belongs to
        const hasAccess = await checkTripAccess(userId, memory.trip.id, TripRole.VIEWER);
        if (!hasAccess) {
            throw new AuthenticationError("You don't have permission to view this memory.");
        }

        return memory;
    }

    @Mutation(() => Memory, { description: "Create a new memory and associate it with a trip" })
    async createMemory(
        @Arg("input") input: MemoryInput,
        @Ctx() { userId }: MyContext
    ): Promise<Memory> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to create a memory.");
        }

        // Check if the user has at least EDITOR rights for this trip
        const hasAccess = await checkTripAccess(userId, input.tripId, TripRole.EDITOR);
        if (!hasAccess) {
            throw new UserInputError(`You don't have permission to add memories to trip ${input.tripId}.`);
        }

        const memoryRepository = AppDataSource.getRepository(Memory);
        
        const trip = await AppDataSource.getRepository(Trip).findOneBy({ id: input.tripId });
        if (!trip) {
            // This check is technically redundant if checkTripAccess passed, but good for safety
            throw new UserInputError(`Trip with ID ${input.tripId} not found.`);
        }

        const creator = await AppDataSource.getRepository(User).findOneBy({ id: userId });

        // Falls ein Location-Objekt geliefert wurde, extrahiere Koordinaten
        let latitude = input.latitude;
        let longitude = input.longitude;
        let locationName = input.locationName;

        if (input.location) {
            latitude = input.location.latitude;
            longitude = input.location.longitude;
            if (input.location.name !== undefined) {
                locationName = input.location.name;
            }
        }

        // Standard-Timestamp setzen, falls nicht übergeben
        const timestamp = input.timestamp ?? new Date();

        const newMemory = memoryRepository.create({
            title: input.title,
            text: input.text,
            timestamp,
            latitude,
            longitude,
            locationName,
            trip,
        });

        if (creator) {
            newMemory.creator = creator;
        }

        if (input.tagIds && input.tagIds.length > 0) {
            const tags = await AppDataSource.getRepository(Tag).findBy({
                id: In(input.tagIds),
            });
            if (tags.length !== input.tagIds.length) {
                throw new Error("One or more tags were not found.");
            }
            newMemory.tags = tags;
        }

        console.log("Saving memory with timestamp", newMemory.timestamp);
        return await memoryRepository.save(newMemory);
    }

    @Mutation(() => Memory, { description: "Update an existing memory" })
    async updateMemory(
        @Arg("id", () => String) id: string,
        @Arg("input") input: UpdateMemoryInput,
        @Ctx() { userId }: MyContext
    ): Promise<Memory> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to update a memory.");
        }

        const memoryRepository = AppDataSource.getRepository(Memory);
        const memory = await memoryRepository.findOne({
            where: { id },
            relations: ["trip", "tags"]
        });

        if (!memory) {
            throw new UserInputError(`Memory with ID ${id} not found.`);
        }

        // Check if the user has at least EDITOR rights for the trip this memory belongs to
        const hasAccess = await checkTripAccess(userId, memory.trip.id, TripRole.EDITOR);
        if (!hasAccess) {
            throw new AuthenticationError("You don't have permission to update this memory.");
        }

        // Update memory fields (only update provided fields)
        if (input.title !== undefined) memory.title = input.title;
        if (input.text !== undefined) memory.text = input.text;
        if (input.timestamp !== undefined) memory.timestamp = input.timestamp;

        // Koordinaten können einzeln oder über location-Objekt aktualisiert werden
        if (input.location) {
            memory.latitude = input.location.latitude;
            memory.longitude = input.location.longitude;
            memory.locationName = input.location.name ?? memory.locationName;
        }

        if (input.latitude !== undefined) memory.latitude = input.latitude;
        if (input.longitude !== undefined) memory.longitude = input.longitude;
        if (input.locationName !== undefined) memory.locationName = input.locationName;

        // Update tags if provided
        if (input.tagIds && input.tagIds.length > 0) {
            const tags = await AppDataSource.getRepository(Tag).findBy({
                id: In(input.tagIds),
            });
            if (tags.length !== input.tagIds.length) {
                throw new Error("One or more tags were not found.");
            }
            memory.tags = tags;
        }

        return await memoryRepository.save(memory);
    }

    @Mutation(() => Boolean, { description: "Delete a memory" })
    async deleteMemory(
        @Arg("id", () => String) id: string,
        @Ctx() { userId }: MyContext
    ): Promise<boolean> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to delete a memory.");
        }

        const memoryRepository = AppDataSource.getRepository(Memory);
        const memory = await memoryRepository.findOne({
            where: { id },
            relations: ["trip", "mediaItems"]
        });

        if (!memory) {
            throw new UserInputError(`Memory with ID ${id} not found.`);
        }

        // Check if the user has at least EDITOR rights for the trip this memory belongs to
        const hasAccess = await checkTripAccess(userId, memory.trip.id, TripRole.EDITOR);
        if (!hasAccess) {
            throw new AuthenticationError("You don't have permission to delete this memory.");
        }

        // Delete associated media items first
        if (memory.mediaItems && memory.mediaItems.length > 0) {
            await AppDataSource.getRepository(MediaItem).remove(memory.mediaItems);
        }

        // Delete the memory
        await memoryRepository.remove(memory);
        return true;
    }

    @Query(() => [Memory], { description: "Search memories by query and optional trip filter" })
    async searchMemories(
        @Arg("query") query: string,
        @Ctx() { userId }: MyContext,
        @Arg("tripId", () => ID, { nullable: true }) tripId?: string
    ): Promise<Memory[]> {
        if (!userId) {
            return [];
        }

        const memberships = await AppDataSource.getRepository(TripMembership).find({
            where: { user: { id: userId } },
            relations: ["trip"],
        });
        const accessibleTripIds = memberships.map(m => m.trip.id);

        if (accessibleTripIds.length === 0) {
            return [];
        }

        const memoryRepository = AppDataSource.getRepository(Memory);
        let whereCondition: any = { trip: { id: In(accessibleTripIds) } };

        // Add trip filter if specified
        if (tripId) {
            // Check if user has access to this specific trip
            const hasAccess = await checkTripAccess(userId, tripId, TripRole.VIEWER);
            if (!hasAccess) {
                return [];
            }
            whereCondition = { trip: { id: tripId } };
        }

        // Search in title and text fields
        return await memoryRepository.find({
            where: [
                { ...whereCondition, title: Like(`%${query}%`) },
                { ...whereCondition, text: Like(`%${query}%`) }
            ],
            relations: ["mediaItems", "trip", "tags"]
        });
    }

    @FieldResolver(() => [MediaItem])
    async mediaItems(@Root() memory: Memory): Promise<MediaItem[]> {
        if (memory.mediaItems) {
            return memory.mediaItems;
        }
        const memoryWithMedia = await AppDataSource.getRepository(Memory).findOne({
            where: { id: memory.id },
            relations: ["mediaItems"],
        });
        return memoryWithMedia ? memoryWithMedia.mediaItems : [];
    }
} 