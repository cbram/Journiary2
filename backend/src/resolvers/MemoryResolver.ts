import { Resolver, Query, Mutation, Arg, FieldResolver, Root } from 'type-graphql';
import { Memory } from '../entities/Memory';
import { MemoryInput } from '../entities/MemoryInput';
import { AppDataSource } from '../utils/database';
import { MediaItem } from '../entities/MediaItem';
import { Trip } from '../entities/Trip';
import { Tag } from "../entities/Tag";
import { In } from "typeorm";

@Resolver(() => Memory)
export class MemoryResolver {

    @Query(() => [Memory], { description: "Get all memories" })
    async memories(): Promise<Memory[]> {
        return AppDataSource.getRepository(Memory).find({ relations: ["mediaItems", "trip"] });
    }

    @Mutation(() => Memory, { description: "Create a new memory and associate it with a trip" })
    async createMemory(@Arg("input") input: MemoryInput): Promise<Memory> {
        const memoryRepository = AppDataSource.getRepository(Memory);
        
        // Find the trip to associate the memory with
        const trip = await AppDataSource.getRepository(Trip).findOneBy({ id: input.tripId });
        if (!trip) {
            throw new Error(`Trip with ID ${input.tripId} not found.`);
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