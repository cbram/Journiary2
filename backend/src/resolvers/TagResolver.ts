import { Resolver, Mutation, Arg, Query } from "type-graphql";
import { Tag } from "../entities/Tag";
import { TagInput } from "../entities/TagInput";
import { AppDataSource } from "../utils/database";
import { TagCategory } from "../entities/TagCategory";

@Resolver(Tag)
export class TagResolver {

    @Query(() => [Tag])
    async tags(): Promise<Tag[]> {
        return AppDataSource.getRepository(Tag).find({ relations: ["category"] });
    }

    @Mutation(() => Tag)
    async createTag(@Arg("input") input: TagInput): Promise<Tag> {
        const tagRepository = AppDataSource.getRepository(Tag);
        
        const newTag = tagRepository.create(input);

        if (input.categoryId) {
            const category = await AppDataSource.getRepository(TagCategory).findOneBy({ id: input.categoryId });
            if (!category) {
                throw new Error(`Category with ID ${input.categoryId} not found.`);
            }
            newTag.category = category;
        }

        return await tagRepository.save(newTag);
    }
} 