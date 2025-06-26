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

    @Mutation(() => BucketListItem, { nullable: true })
    async updateBucketListItem(
        @Arg("id", () => ID) id: string,
        @Arg("input") input: BucketListItemInput
    ): Promise<BucketListItem | null> {
        const itemRepository = AppDataSource.getRepository(BucketListItem);
        await itemRepository.update(id, input);
        return await itemRepository.findOneBy({ id });
    }

    @Mutation(() => BucketListItem, { nullable: true })
    async completeBucketListItem(
        @Arg("id", () => ID) id: string,
        @Arg("memoryId", () => ID) memoryId: string
    ): Promise<BucketListItem | null> {
        const itemRepository = AppDataSource.getRepository(BucketListItem);
        const memoryRepository = AppDataSource.getRepository(Memory);

        const item = await itemRepository.findOneBy({ id });
        if (!item) throw new Error("Bucket list item not found");

        const memory = await memoryRepository.findOneBy({ id: memoryId });
        if (!memory) throw new Error("Memory not found");

        item.isDone = true;
        item.completedAt = new Date();
        
        // Associate the memory with the bucket list item
        if (!item.memories) {
            item.memories = [];
        }
        item.memories.push(memory);

        return await itemRepository.save(item);
    }

    @Mutation(() => Boolean)
    async deleteBucketListItem(@Arg("id", () => ID) id: string): Promise<boolean> {
        const result = await AppDataSource.getRepository(BucketListItem).delete(id);
        return result.affected === 1;
    }
} 