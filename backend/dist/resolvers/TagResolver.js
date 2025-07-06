"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TagResolver = void 0;
const type_graphql_1 = require("type-graphql");
const Tag_1 = require("../entities/Tag");
const TagInput_1 = require("../entities/TagInput");
const UpdateTagInput_1 = require("../entities/UpdateTagInput");
const database_1 = require("../utils/database");
const TagCategory_1 = require("../entities/TagCategory");
const apollo_server_express_1 = require("apollo-server-express");
const DeletionLog_1 = require("../entities/DeletionLog");
let TagResolver = class TagResolver {
    async tags() {
        return database_1.AppDataSource.getRepository(Tag_1.Tag).find({ relations: ["category"] });
    }
    async createTag(input, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to create a tag.");
        const tagRepository = database_1.AppDataSource.getRepository(Tag_1.Tag);
        const newTag = tagRepository.create(input);
        if (input.categoryId) {
            const category = await database_1.AppDataSource.getRepository(TagCategory_1.TagCategory).findOneBy({ id: input.categoryId });
            if (!category) {
                throw new Error(`Category with ID ${input.categoryId} not found.`);
            }
            newTag.category = category;
        }
        return await tagRepository.save(newTag);
    }
    async updateTag(id, input, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to update a tag.");
        const tagRepo = database_1.AppDataSource.getRepository(Tag_1.Tag);
        const tag = await tagRepo.findOneBy({ id });
        if (!tag) {
            return null;
        }
        // Update properties from input (only update provided fields)
        if (input.name !== undefined)
            tag.name = input.name;
        if (input.color !== undefined)
            tag.color = input.color;
        // Handle category change
        if (input.categoryId !== undefined) {
            if (input.categoryId) {
                const category = await database_1.AppDataSource.getRepository(TagCategory_1.TagCategory).findOneBy({ id: input.categoryId });
                if (!category) {
                    throw new Error(`Category with ID ${input.categoryId} not found.`);
                }
                tag.category = category;
            }
            else {
                tag.category = null; // Allow removing category
            }
        }
        return await tagRepo.save(tag);
    }
    async deleteTag(id, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to delete a tag.");
        try {
            await database_1.AppDataSource.transaction(async (em) => {
                const tag = await em.findOneBy(Tag_1.Tag, { id });
                if (!tag) {
                    throw new Error("Tag not found.");
                }
                // Log the deletion
                const deletionLog = em.create(DeletionLog_1.DeletionLog, { entityId: id, entityType: 'Tag' });
                await em.save(deletionLog);
                // Perform the deletion
                await em.remove(tag);
            });
            return true;
        }
        catch (error) {
            console.error("Error deleting tag:", error);
            return false;
        }
    }
    // ---------------------------------------------------------------------------
    // Kompatibilitäts-Resolver für Legacy-iOS-Feldnamen
    // ---------------------------------------------------------------------------
    categoryId(tag) {
        return tag.category?.id;
    }
};
exports.TagResolver = TagResolver;
__decorate([
    (0, type_graphql_1.Query)(() => [Tag_1.Tag]),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], TagResolver.prototype, "tags", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Tag_1.Tag),
    __param(0, (0, type_graphql_1.Arg)("input")),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [TagInput_1.TagInput, Object]),
    __metadata("design:returntype", Promise)
], TagResolver.prototype, "createTag", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Tag_1.Tag, { nullable: true }),
    __param(0, (0, type_graphql_1.Arg)("id")),
    __param(1, (0, type_graphql_1.Arg)("input")),
    __param(2, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, UpdateTagInput_1.UpdateTagInput, Object]),
    __metadata("design:returntype", Promise)
], TagResolver.prototype, "updateTag", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Boolean),
    __param(0, (0, type_graphql_1.Arg)("id")),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], TagResolver.prototype, "deleteTag", null);
__decorate([
    (0, type_graphql_1.FieldResolver)(() => String, { name: "categoryId", nullable: true }),
    __param(0, (0, type_graphql_1.Root)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Tag_1.Tag]),
    __metadata("design:returntype", Object)
], TagResolver.prototype, "categoryId", null);
exports.TagResolver = TagResolver = __decorate([
    (0, type_graphql_1.Resolver)(Tag_1.Tag)
], TagResolver);
