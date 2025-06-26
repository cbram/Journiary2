import { Resolver, Mutation, Arg } from "type-graphql";
import { TagCategory } from "../entities/TagCategory";
import { TagCategoryInput } from "../entities/TagCategoryInput";
import { AppDataSource } from "../utils/database";

@Resolver(TagCategory)
export class TagCategoryResolver {
    @Mutation(() => TagCategory)
    async createTagCategory(@Arg("input") input: TagCategoryInput): Promise<TagCategory> {
        const categoryRepository = AppDataSource.getRepository(TagCategory);
        const category = categoryRepository.create(input);
        return await categoryRepository.save(category);
    }
} 