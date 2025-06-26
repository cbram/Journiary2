import { Resolver, Mutation, Arg, Ctx } from "type-graphql";
import { TagCategory } from "../entities/TagCategory";
import { TagCategoryInput } from "../entities/TagCategoryInput";
import { AppDataSource } from "../utils/database";
import { MyContext } from "..";
import { AuthenticationError } from "apollo-server-express";

@Resolver(TagCategory)
export class TagCategoryResolver {
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
} 