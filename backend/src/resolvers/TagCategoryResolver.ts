import { Resolver, Mutation, Arg, Ctx, Query } from "type-graphql";
import { TagCategory } from "../entities/TagCategory";
import { TagCategoryInput } from "../entities/TagCategoryInput";
import { AppDataSource } from "../utils/database";
import { MyContext } from "..";
import { AuthenticationError } from "apollo-server-express";

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
        @Arg("input") input: TagCategoryInput,
        @Ctx() { userId }: MyContext
    ): Promise<TagCategory | null> {
        if (!userId) throw new AuthenticationError("You must be logged in to update a tag category.");

        const categoryRepo = AppDataSource.getRepository(TagCategory);
        const category = await categoryRepo.findOneBy({ id });

        if (!category) {
            return null;
        }

        Object.assign(category, input);
        return await categoryRepo.save(category);
    }

    @Mutation(() => Boolean)
    async deleteTagCategory(
        @Arg("id") id: string,
        @Ctx() { userId }: MyContext
    ): Promise<boolean> {
        if (!userId) throw new AuthenticationError("You must be logged in to delete a tag category.");
        
        const deleteResult = await AppDataSource.getRepository(TagCategory).delete(id);
        
        return deleteResult.affected === 1;
    }
} 