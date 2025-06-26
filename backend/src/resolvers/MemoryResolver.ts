import { Resolver, Query, Mutation, Arg, FieldResolver, Root, Ctx } from 'type-graphql';
import { Memory } from '../entities/Memory';
import { MemoryInput } from '../entities/MemoryInput';
import { AppDataSource } from '../utils/database';
import { MediaItem } from '../entities/MediaItem';
import { Trip } from '../entities/Trip';
import { Tag } from "../entities/Tag";
import { In } from "typeorm";
import { MyContext } from '../index';
import { AuthenticationError, UserInputError } from 'apollo-server-express';
import { checkTripAccess } from '../utils/auth';
import { TripRole } from '../entities/TripMembership';
import { TripMembership } from '../entities/TripMembership';

@Resolver(() => Memory)
export class MemoryResolver {

    @Query(() => [Memory], { description: "Get all memories for trips the user is a member of" })
    async memories(@Ctx() { userId }: MyContext): Promise<Memory[]> {
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
        
        return AppDataSource.getRepository(Memory).find({
            where: { trip: { id: In(tripIds) } },
            relations: ["mediaItems", "trip"]
        });
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

        const newMemory = memoryRepository.create({
            ...input,
            trip,
        });

        if (input.tagIds && input.tagIds.length > 0) {
            const tags = await AppDataSource.getRepository(Tag).findBy({
                id: In(input.tagIds),
            });
            if (tags.length !== input.tagIds.length) {
                throw new Error("One or more tags were not found.");
            }
            newMemory.tags = tags;
        }

        return await memoryRepository.save(newMemory);
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