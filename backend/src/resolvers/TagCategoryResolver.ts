import { Resolver, Mutation, Arg, Ctx, Query } from "type-graphql";
import { TagCategory } from "../entities/TagCategory";
import { TagCategoryInput } from "../entities/TagCategoryInput";
import { UpdateTagCategoryInput } from "../entities/UpdateTagCategoryInput";
import { AppDataSource } from "../utils/database";
import { MyContext } from "..";
import { AuthenticationError } from "apollo-server-express";
import { DeletionLog } from "../entities/DeletionLog";
import { Tag } from "../entities/Tag";

@Resolver(TagCategory)
export class TagCategoryResolver {
    @Query(() => [TagCategory])
    async tagCategories(): Promise<TagCategory[]> {
        return AppDataSource.getRepository(TagCategory).find();
    }

    @Mutation(() => TagCategory)
    async createTagCategory(
        @Arg("input") input: TagCategoryInput,
        @Ctx() { userId }: MyContext
    ): Promise<TagCategory> {
        if (!userId) throw new AuthenticationError("You must be logged in to create a tag category.");

        const categoryRepository = AppDataSource.getRepository(TagCategory);
        const category = categoryRepository.create(input);
        return await categoryRepository.save(category);
    }

    @Mutation(() => TagCategory, { nullable: true })
    async updateTagCategory(
        @Arg("id") id: string,
        @Arg("input") input: UpdateTagCategoryInput,
        @Ctx() { userId }: MyContext
    ): Promise<TagCategory | null> {
        if (!userId) throw new AuthenticationError("You must be logged in to update a tag category.");

        const categoryRepo = AppDataSource.getRepository(TagCategory);
        const category = await categoryRepo.findOneBy({ id });

        if (!category) {
            return null;
        }

        // Update properties from input (only update provided fields)
        if (input.name !== undefined) category.name = input.name;
        if (input.color !== undefined) category.color = input.color;
        if (input.icon !== undefined) category.emoji = input.icon;

        return await categoryRepo.save(category);
    }

    @Mutation(() => Boolean)
    async deleteTagCategory(
        @Arg("id") id: string,
        @Ctx() { userId }: MyContext
    ): Promise<boolean> {
        if (!userId) throw new AuthenticationError("You must be logged in to delete a tag category.");
        
        try {
            await AppDataSource.transaction(async (em) => {
                const category = await em.findOneBy(TagCategory, { id });
                if (!category) {
                    throw new Error("TagCategory not found.");
                }

                // Log the deletion
                const deletionLog = em.create(DeletionLog, { entityId: id, entityType: 'TagCategory' });
                await em.save(deletionLog);
                
                // Manually set category to null for all tags in this category
                // This is to ensure the update timestamp on the tags is touched for sync
                await em.createQueryBuilder()
                    .update(Tag)
                    .set({ category: undefined })
                    .where({ category: { id } })
                    .execute();

                // Perform the deletion
                await em.remove(category);
            });
            return true;
        } catch (error) {
            console.error("Error deleting tag category:", error);
            return false;
        }
    }
} 