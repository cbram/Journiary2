import { Resolver, Mutation, Arg, Query, Ctx, FieldResolver, Root } from "type-graphql";
import { Tag } from "../entities/Tag";
import { TagInput } from "../entities/TagInput";
import { UpdateTagInput } from "../entities/UpdateTagInput";
import { AppDataSource } from "../utils/database";
import { TagCategory } from "../entities/TagCategory";
import { MyContext } from "..";
import { AuthenticationError } from "apollo-server-express";
import { DeletionLog } from "../entities/DeletionLog";

@Resolver(Tag)
export class TagResolver {

    @Query(() => [Tag])
    async tags(): Promise<Tag[]> {
        return AppDataSource.getRepository(Tag).find({ relations: ["category"] });
    }

    @Mutation(() => Tag)
    async createTag(
        @Arg("input") input: TagInput,
        @Ctx() { userId }: MyContext
    ): Promise<Tag> {
        if (!userId) throw new AuthenticationError("You must be logged in to create a tag.");

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

    @Mutation(() => Tag, { nullable: true })
    async updateTag(
        @Arg("id") id: string,
        @Arg("input") input: UpdateTagInput,
        @Ctx() { userId }: MyContext
    ): Promise<Tag | null> {
        if (!userId) throw new AuthenticationError("You must be logged in to update a tag.");

        const tagRepo = AppDataSource.getRepository(Tag);
        const tag = await tagRepo.findOneBy({ id });

        if (!tag) {
            return null;
        }

        // Update properties from input (only update provided fields)
        if (input.name !== undefined) tag.name = input.name;
        if (input.color !== undefined) tag.color = input.color;

        // Handle category change
        if (input.categoryId !== undefined) {
            if (input.categoryId) {
                const category = await AppDataSource.getRepository(TagCategory).findOneBy({ id: input.categoryId });
                if (!category) {
                    throw new Error(`Category with ID ${input.categoryId} not found.`);
                }
                tag.category = category;
            } else {
                tag.category = null; // Allow removing category
            }
        }

        return await tagRepo.save(tag);
    }

    @Mutation(() => Boolean)
    async deleteTag(
        @Arg("id") id: string,
        @Ctx() { userId }: MyContext
    ): Promise<boolean> {
        if (!userId) throw new AuthenticationError("You must be logged in to delete a tag.");
        
        try {
            await AppDataSource.transaction(async (em) => {
                const tag = await em.findOneBy(Tag, { id });
                if (!tag) {
                    throw new Error("Tag not found.");
                }
                
                // Log the deletion
                const deletionLog = em.create(DeletionLog, { entityId: id, entityType: 'Tag' });
                await em.save(deletionLog);

                // Perform the deletion
                await em.remove(tag);
            });
            return true;
        } catch (error) {
            console.error("Error deleting tag:", error);
            return false;
        }
    }

    // ---------------------------------------------------------------------------
    // Kompatibilitäts-Resolver für Legacy-iOS-Feldnamen
    // ---------------------------------------------------------------------------

    @FieldResolver(() => String, { name: "categoryId", nullable: true })
    categoryId(@Root() tag: Tag): string | null | undefined {
        return tag.category?.id;
    }
} 