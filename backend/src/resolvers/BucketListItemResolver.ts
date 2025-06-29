import { Resolver, Query, Mutation, Arg, ID, Ctx } from "type-graphql";
import { BucketListItem } from "../entities/BucketListItem";
import { BucketListItemInput } from "../entities/BucketListItemInput";
import { AppDataSource } from "../utils/database";
import { Memory } from "../entities/Memory";
import { MyContext } from "../index";
import { User } from "../entities/User";
import { AuthenticationError, UserInputError } from "apollo-server-express";

@Resolver(BucketListItem)
export class BucketListItemResolver {
    @Query(() => [BucketListItem])
    async bucketListItems(@Ctx() { userId }: MyContext): Promise<BucketListItem[]> {
        if (!userId) return [];
        return AppDataSource.getRepository(BucketListItem).find({ where: { creator: { id: userId } } });
    }

    @Mutation(() => BucketListItem)
    async createBucketListItem(
        @Arg("input") input: BucketListItemInput,
        @Ctx() { userId }: MyContext
    ): Promise<BucketListItem> {
        if (!userId) throw new AuthenticationError("You must be logged in.");
        const user = await AppDataSource.getRepository(User).findOneBy({ id: userId });
        if (!user) throw new AuthenticationError("User not found.");

        const item = AppDataSource.getRepository(BucketListItem).create({ ...input, creator: user });
        return await AppDataSource.getRepository(BucketListItem).save(item);
    }

    @Mutation(() => BucketListItem, { nullable: true })
    async updateBucketListItem(
        @Arg("id", () => ID) id: string,
        @Arg("input") input: BucketListItemInput,
        @Ctx() { userId }: MyContext
    ): Promise<BucketListItem | null> {
        if (!userId) throw new AuthenticationError("You must be logged in.");
        const item = await AppDataSource.getRepository(BucketListItem).findOne({ where: { id, creator: { id: userId } } });
        if (!item) throw new UserInputError("Item not found or you don't have access.");

        await AppDataSource.getRepository(BucketListItem).update(id, input);
        return item; // Return the original item after update to avoid a second DB call
    }

    @Mutation(() => BucketListItem, { nullable: true })
    async completeBucketListItem(
        @Arg("id", () => ID) id: string,
        @Arg("memoryId", () => ID) memoryId: string,
        @Ctx() { userId }: MyContext
    ): Promise<BucketListItem | null> {
        if (!userId) throw new AuthenticationError("You must be logged in.");
        
        const item = await AppDataSource.getRepository(BucketListItem).findOne({ where: { id, creator: { id: userId } } });
        if (!item) throw new UserInputError("Bucket list item not found or you don't have access.");

        const hasAccessToMemory = await AppDataSource.getRepository(Memory).count({ where: { id: memoryId, trip: { members: { user: { id: userId } } } } });
        if(hasAccessToMemory === 0) throw new UserInputError("Memory not found or you don't have access.");
        
        const memory = await AppDataSource.getRepository(Memory).findOneBy({ id: memoryId });

        item.isDone = true;
        item.completedAt = new Date();
        if (!item.memories) item.memories = [];
        item.memories.push(memory!);

        return await AppDataSource.getRepository(BucketListItem).save(item);
    }

    @Mutation(() => Boolean)
    async deleteBucketListItem(
        @Arg("id", () => ID) id: string,
        @Ctx() { userId }: MyContext
    ): Promise<boolean> {
        if (!userId) throw new AuthenticationError("You must be logged in.");
        const result = await AppDataSource.getRepository(BucketListItem).delete({ id, creator: { id: userId } });
        return result.affected === 1;
    }
} 