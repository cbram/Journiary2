import { Resolver, Query, Mutation, Arg, ID } from "type-graphql";
import { BucketListItem } from "../entities/BucketListItem";
import { BucketListItemInput } from "../entities/BucketListItemInput";
import { AppDataSource } from "../utils/database";
import { Memory } from "../entities/Memory";

@Resolver(BucketListItem)
export class BucketListItemResolver {
    @Query(() => [BucketListItem])
    async bucketListItems(): Promise<BucketListItem[]> {
        return AppDataSource.getRepository(BucketListItem).find();
    }

    @Mutation(() => BucketListItem)
    async createBucketListItem(@Arg("input") input: BucketListItemInput): Promise<BucketListItem> {
        const itemRepository = AppDataSource.getRepository(BucketListItem);
        const item = itemRepository.create(input);
        return await itemRepository.save(item);
    }

    @Mutation(() => BucketListItem)
    async completeBucketListItem(
        @Arg("id", () => ID) id: string,
        @Arg("memoryId", () => ID) memoryId: string
    ): Promise<BucketListItem> {
        const itemRepository = AppDataSource.getRepository(BucketListItem);
        const memoryRepository = AppDataSource.getRepository(Memory);

        const item = await itemRepository.findOneBy({ id });
        if (!item) {
            throw new Error(`BucketListItem with ID ${id} not found.`);
        }

        const memory = await memoryRepository.findOneBy({ id: memoryId });
        if (!memory) {
            throw new Error(`Memory with ID ${memoryId} not found.`);
        }

        item.isCompleted = true;
        item.completedAt = new Date();
        item.completionMemory = memory;
        item.completionMemoryId = memory.id;

        return await itemRepository.save(item);
    }
} 