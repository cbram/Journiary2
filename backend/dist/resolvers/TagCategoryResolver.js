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
exports.TagCategoryResolver = void 0;
const type_graphql_1 = require("type-graphql");
const TagCategory_1 = require("../entities/TagCategory");
const TagCategoryInput_1 = require("../entities/TagCategoryInput");
const UpdateTagCategoryInput_1 = require("../entities/UpdateTagCategoryInput");
const database_1 = require("../utils/database");
const apollo_server_express_1 = require("apollo-server-express");
const DeletionLog_1 = require("../entities/DeletionLog");
const Tag_1 = require("../entities/Tag");
let TagCategoryResolver = class TagCategoryResolver {
    async tagCategories() {
        return database_1.AppDataSource.getRepository(TagCategory_1.TagCategory).find();
    }
    async createTagCategory(input, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to create a tag category.");
        const categoryRepository = database_1.AppDataSource.getRepository(TagCategory_1.TagCategory);
        const category = categoryRepository.create(input);
        return await categoryRepository.save(category);
    }
    async updateTagCategory(id, input, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to update a tag category.");
        const categoryRepo = database_1.AppDataSource.getRepository(TagCategory_1.TagCategory);
        const category = await categoryRepo.findOneBy({ id });
        if (!category) {
            return null;
        }
        // Update properties from input (only update provided fields)
        if (input.name !== undefined)
            category.name = input.name;
        if (input.color !== undefined)
            category.color = input.color;
        if (input.icon !== undefined)
            category.emoji = input.icon;
        return await categoryRepo.save(category);
    }
    async deleteTagCategory(id, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to delete a tag category.");
        try {
            await database_1.AppDataSource.transaction(async (em) => {
                const category = await em.findOneBy(TagCategory_1.TagCategory, { id });
                if (!category) {
                    throw new Error("TagCategory not found.");
                }
                // Log the deletion
                const deletionLog = em.create(DeletionLog_1.DeletionLog, { entityId: id, entityType: 'TagCategory' });
                await em.save(deletionLog);
                // Manually set category to null for all tags in this category
                // This is to ensure the update timestamp on the tags is touched for sync
                await em.createQueryBuilder()
                    .update(Tag_1.Tag)
                    .set({ category: undefined })
                    .where({ category: { id } })
                    .execute();
                // Perform the deletion
                await em.remove(category);
            });
            return true;
        }
        catch (error) {
            console.error("Error deleting tag category:", error);
            return false;
        }
    }
};
exports.TagCategoryResolver = TagCategoryResolver;
__decorate([
    (0, type_graphql_1.Query)(() => [TagCategory_1.TagCategory]),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], TagCategoryResolver.prototype, "tagCategories", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => TagCategory_1.TagCategory),
    __param(0, (0, type_graphql_1.Arg)("input")),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [TagCategoryInput_1.TagCategoryInput, Object]),
    __metadata("design:returntype", Promise)
], TagCategoryResolver.prototype, "createTagCategory", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => TagCategory_1.TagCategory, { nullable: true }),
    __param(0, (0, type_graphql_1.Arg)("id")),
    __param(1, (0, type_graphql_1.Arg)("input")),
    __param(2, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, UpdateTagCategoryInput_1.UpdateTagCategoryInput, Object]),
    __metadata("design:returntype", Promise)
], TagCategoryResolver.prototype, "updateTagCategory", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Boolean),
    __param(0, (0, type_graphql_1.Arg)("id")),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], TagCategoryResolver.prototype, "deleteTagCategory", null);
exports.TagCategoryResolver = TagCategoryResolver = __decorate([
    (0, type_graphql_1.Resolver)(TagCategory_1.TagCategory)
], TagCategoryResolver);
