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
exports.BucketListItemResolver = void 0;
const type_graphql_1 = require("type-graphql");
const BucketListItem_1 = require("../entities/BucketListItem");
const BucketListItemInput_1 = require("../entities/BucketListItemInput");
const database_1 = require("../utils/database");
const Memory_1 = require("../entities/Memory");
const User_1 = require("../entities/User");
const apollo_server_express_1 = require("apollo-server-express");
const DeletionLog_1 = require("../entities/DeletionLog");
let BucketListItemResolver = class BucketListItemResolver {
    async bucketListItems({ userId }) {
        if (!userId)
            return [];
        return database_1.AppDataSource.getRepository(BucketListItem_1.BucketListItem).find({ where: { creator: { id: userId } } });
    }
    async createBucketListItem(input, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        const user = await database_1.AppDataSource.getRepository(User_1.User).findOneBy({ id: userId });
        if (!user)
            throw new apollo_server_express_1.AuthenticationError("User not found.");
        const item = database_1.AppDataSource.getRepository(BucketListItem_1.BucketListItem).create({ ...input, creator: user });
        return await database_1.AppDataSource.getRepository(BucketListItem_1.BucketListItem).save(item);
    }
    async updateBucketListItem(id, input, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        const itemRepo = database_1.AppDataSource.getRepository(BucketListItem_1.BucketListItem);
        const item = await itemRepo.findOne({ where: { id, creator: { id: userId } } });
        if (!item)
            throw new apollo_server_express_1.UserInputError("Item not found or you don't have access.");
        // Apply partial update
        Object.assign(item, input);
        await itemRepo.save(item);
        return item; // Return the updated item
    }
    async completeBucketListItem(id, memoryId, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        const item = await database_1.AppDataSource.getRepository(BucketListItem_1.BucketListItem).findOne({ where: { id, creator: { id: userId } } });
        if (!item)
            throw new apollo_server_express_1.UserInputError("Bucket list item not found or you don't have access.");
        const hasAccessToMemory = await database_1.AppDataSource.getRepository(Memory_1.Memory).count({ where: { id: memoryId, trip: { members: { user: { id: userId } } } } });
        if (hasAccessToMemory === 0)
            throw new apollo_server_express_1.UserInputError("Memory not found or you don't have access.");
        const memory = await database_1.AppDataSource.getRepository(Memory_1.Memory).findOneBy({ id: memoryId });
        item.isDone = true;
        item.completedAt = new Date();
        if (!item.memories)
            item.memories = [];
        item.memories.push(memory);
        return await database_1.AppDataSource.getRepository(BucketListItem_1.BucketListItem).save(item);
    }
    async deleteBucketListItem(id, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        try {
            await database_1.AppDataSource.transaction(async (em) => {
                const item = await em.findOneBy(BucketListItem_1.BucketListItem, { id, creator: { id: userId } });
                if (!item) {
                    throw new apollo_server_express_1.UserInputError("Item not found or you don't have access.");
                }
                // Log the deletion
                const deletionLog = em.create(DeletionLog_1.DeletionLog, { entityId: id, entityType: 'BucketListItem', ownerId: userId });
                await em.save(deletionLog);
                // Perform the deletion
                await em.remove(item);
            });
            return true;
        }
        catch (error) {
            console.error("Error deleting bucket list item:", error);
            if (error instanceof apollo_server_express_1.UserInputError)
                throw error;
            return false;
        }
    }
};
exports.BucketListItemResolver = BucketListItemResolver;
__decorate([
    (0, type_graphql_1.Query)(() => [BucketListItem_1.BucketListItem]),
    __param(0, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], BucketListItemResolver.prototype, "bucketListItems", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => BucketListItem_1.BucketListItem),
    __param(0, (0, type_graphql_1.Arg)("input")),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [BucketListItemInput_1.BucketListItemInput, Object]),
    __metadata("design:returntype", Promise)
], BucketListItemResolver.prototype, "createBucketListItem", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => BucketListItem_1.BucketListItem, { nullable: true }),
    __param(0, (0, type_graphql_1.Arg)("id", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Arg)("input")),
    __param(2, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, BucketListItemInput_1.BucketListItemInput, Object]),
    __metadata("design:returntype", Promise)
], BucketListItemResolver.prototype, "updateBucketListItem", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => BucketListItem_1.BucketListItem, { nullable: true }),
    __param(0, (0, type_graphql_1.Arg)("id", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Arg)("memoryId", () => type_graphql_1.ID)),
    __param(2, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Object]),
    __metadata("design:returntype", Promise)
], BucketListItemResolver.prototype, "completeBucketListItem", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Boolean),
    __param(0, (0, type_graphql_1.Arg)("id", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], BucketListItemResolver.prototype, "deleteBucketListItem", null);
exports.BucketListItemResolver = BucketListItemResolver = __decorate([
    (0, type_graphql_1.Resolver)(BucketListItem_1.BucketListItem)
], BucketListItemResolver);
