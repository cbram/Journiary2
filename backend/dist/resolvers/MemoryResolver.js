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
exports.MemoryResolver = void 0;
const type_graphql_1 = require("type-graphql");
const Memory_1 = require("../entities/Memory");
const MemoryInput_1 = require("../entities/MemoryInput");
const UpdateMemoryInput_1 = require("../entities/UpdateMemoryInput");
const database_1 = require("../utils/database");
const MediaItem_1 = require("../entities/MediaItem");
const Trip_1 = require("../entities/Trip");
const User_1 = require("../entities/User");
const Tag_1 = require("../entities/Tag");
const typeorm_1 = require("typeorm");
const apollo_server_express_1 = require("apollo-server-express");
const auth_1 = require("../utils/auth");
const TripMembership_1 = require("../entities/TripMembership");
const TripMembership_2 = require("../entities/TripMembership");
const Location_1 = require("./types/Location");
const DeletionLog_1 = require("../entities/DeletionLog");
let MemoryResolver = class MemoryResolver {
    async memories({ userId }, tripId) {
        if (!userId) {
            return [];
        }
        const memberships = await database_1.AppDataSource.getRepository(TripMembership_2.TripMembership).find({
            where: { user: { id: userId } },
            relations: ["trip"],
        });
        const tripIds = memberships.map(m => m.trip.id);
        if (tripIds.length === 0) {
            return [];
        }
        const whereCondition = { trip: { id: (0, typeorm_1.In)(tripIds) } };
        if (tripId && tripIds.includes(tripId)) {
            whereCondition.trip = { id: tripId };
        }
        return database_1.AppDataSource.getRepository(Memory_1.Memory).find({
            where: whereCondition,
            relations: ["mediaItems", "trip", "tags"]
        });
    }
    async memory(id, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to view this memory.");
        }
        const memory = await database_1.AppDataSource.getRepository(Memory_1.Memory).findOne({
            where: { id },
            relations: ["trip", "mediaItems", "tags"]
        });
        if (!memory) {
            return null;
        }
        // Check if the user has at least VIEWER rights for the trip this memory belongs to
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, memory.trip.id, TripMembership_1.TripRole.VIEWER);
        if (!hasAccess) {
            throw new apollo_server_express_1.AuthenticationError("You don't have permission to view this memory.");
        }
        return memory;
    }
    async createMemory(input, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to create a memory.");
        }
        // Check if the user has at least EDITOR rights for this trip
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, input.tripId, TripMembership_1.TripRole.EDITOR);
        if (!hasAccess) {
            throw new apollo_server_express_1.UserInputError(`You don't have permission to add memories to trip ${input.tripId}.`);
        }
        const memoryRepository = database_1.AppDataSource.getRepository(Memory_1.Memory);
        const trip = await database_1.AppDataSource.getRepository(Trip_1.Trip).findOneBy({ id: input.tripId });
        if (!trip) {
            // This check is technically redundant if checkTripAccess passed, but good for safety
            throw new apollo_server_express_1.UserInputError(`Trip with ID ${input.tripId} not found.`);
        }
        const creator = await database_1.AppDataSource.getRepository(User_1.User).findOneBy({ id: userId });
        // Falls ein Location-Objekt geliefert wurde, extrahiere Koordinaten
        let latitude = input.latitude;
        let longitude = input.longitude;
        let locationName = input.locationName;
        if (input.location) {
            latitude = input.location.latitude;
            longitude = input.location.longitude;
            if (input.location.name !== undefined) {
                locationName = input.location.name;
            }
        }
        // Standard-Timestamp setzen, falls nicht übergeben
        const timestamp = input.timestamp ?? new Date();
        const newMemory = memoryRepository.create({
            title: input.title,
            text: input.text,
            timestamp,
            latitude,
            longitude,
            locationName,
            trip,
        });
        if (creator) {
            newMemory.creator = creator;
        }
        if (input.tagIds && input.tagIds.length > 0) {
            const tags = await database_1.AppDataSource.getRepository(Tag_1.Tag).findBy({
                id: (0, typeorm_1.In)(input.tagIds),
            });
            if (tags.length !== input.tagIds.length) {
                throw new Error("One or more tags were not found.");
            }
            newMemory.tags = tags;
        }
        console.log("Saving memory with timestamp", newMemory.timestamp);
        return await memoryRepository.save(newMemory);
    }
    async updateMemory(id, input, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to update a memory.");
        }
        const memoryRepository = database_1.AppDataSource.getRepository(Memory_1.Memory);
        const memory = await memoryRepository.findOne({
            where: { id },
            relations: ["trip", "tags"]
        });
        if (!memory) {
            throw new apollo_server_express_1.UserInputError(`Memory with ID ${id} not found.`);
        }
        // Check if the user has at least EDITOR rights for the trip this memory belongs to
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, memory.trip.id, TripMembership_1.TripRole.EDITOR);
        if (!hasAccess) {
            throw new apollo_server_express_1.AuthenticationError("You don't have permission to update this memory.");
        }
        // Update memory fields (only update provided fields)
        if (input.title !== undefined)
            memory.title = input.title;
        if (input.text !== undefined)
            memory.text = input.text;
        if (input.timestamp !== undefined)
            memory.timestamp = input.timestamp;
        // Koordinaten können einzeln oder über location-Objekt aktualisiert werden
        if (input.location) {
            memory.latitude = input.location.latitude;
            memory.longitude = input.location.longitude;
            memory.locationName = input.location.name ?? memory.locationName;
        }
        if (input.latitude !== undefined)
            memory.latitude = input.latitude;
        if (input.longitude !== undefined)
            memory.longitude = input.longitude;
        if (input.locationName !== undefined)
            memory.locationName = input.locationName;
        // Update tags if provided
        if (input.tagIds && input.tagIds.length > 0) {
            const tags = await database_1.AppDataSource.getRepository(Tag_1.Tag).findBy({
                id: (0, typeorm_1.In)(input.tagIds),
            });
            if (tags.length !== input.tagIds.length) {
                throw new Error("One or more tags were not found.");
            }
            memory.tags = tags;
        }
        return await memoryRepository.save(memory);
    }
    async deleteMemory(id, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to delete a memory.");
        }
        const memory = await database_1.AppDataSource.getRepository(Memory_1.Memory).findOne({
            where: { id },
            relations: ["trip", "mediaItems"]
        });
        if (!memory) {
            throw new apollo_server_express_1.UserInputError(`Memory with ID ${id} not found.`);
        }
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, memory.trip.id, TripMembership_1.TripRole.EDITOR);
        if (!hasAccess) {
            throw new apollo_server_express_1.AuthenticationError("You don't have permission to delete this memory.");
        }
        try {
            await database_1.AppDataSource.transaction(async (em) => {
                const deletionLogs = [];
                // Log deletion of the memory itself
                deletionLogs.push(em.create(DeletionLog_1.DeletionLog, { entityId: memory.id, entityType: 'Memory', tripId: memory.trip.id }));
                // Log deletion of associated media items
                if (memory.mediaItems) {
                    for (const mediaItem of memory.mediaItems) {
                        deletionLogs.push(em.create(DeletionLog_1.DeletionLog, { entityId: mediaItem.id, entityType: 'MediaItem', tripId: memory.trip.id }));
                    }
                }
                // Save all deletion logs
                await em.save(DeletionLog_1.DeletionLog, deletionLogs);
                // Now, perform the actual deletion (TypeORM's cascade should handle the rest)
                await em.remove(memory);
            });
            return true;
        }
        catch (error) {
            console.error("Error deleting memory:", error);
            throw new Error("Could not delete memory.");
        }
    }
    async searchMemories(query, { userId }, tripId) {
        if (!userId) {
            return [];
        }
        const memberships = await database_1.AppDataSource.getRepository(TripMembership_2.TripMembership).find({
            where: { user: { id: userId } },
            relations: ["trip"],
        });
        const accessibleTripIds = memberships.map(m => m.trip.id);
        if (accessibleTripIds.length === 0) {
            return [];
        }
        const memoryRepository = database_1.AppDataSource.getRepository(Memory_1.Memory);
        let whereCondition = { trip: { id: (0, typeorm_1.In)(accessibleTripIds) } };
        // Add trip filter if specified
        if (tripId) {
            // Check if user has access to this specific trip
            const hasAccess = await (0, auth_1.checkTripAccess)(userId, tripId, TripMembership_1.TripRole.VIEWER);
            if (!hasAccess) {
                return [];
            }
            whereCondition = { trip: { id: tripId } };
        }
        // Search in title and text fields
        return await memoryRepository.find({
            where: [
                { ...whereCondition, title: (0, typeorm_1.Like)(`%${query}%`) },
                { ...whereCondition, text: (0, typeorm_1.Like)(`%${query}%`) }
            ],
            relations: ["mediaItems", "trip", "tags"]
        });
    }
    async mediaItems(memory) {
        if (memory.mediaItems) {
            return memory.mediaItems;
        }
        const memoryWithMedia = await database_1.AppDataSource.getRepository(Memory_1.Memory).findOne({
            where: { id: memory.id },
            relations: ["mediaItems"],
        });
        return memoryWithMedia ? memoryWithMedia.mediaItems : [];
    }
    location(memory) {
        if (memory.latitude == null || memory.longitude == null) {
            return null;
        }
        return {
            latitude: memory.latitude,
            longitude: memory.longitude,
            name: memory.locationName ?? undefined,
        };
    }
};
__decorate([
    (0, type_graphql_1.Query)(() => [Memory_1.Memory], { description: "Get all memories for trips the user is a member of" }),
    __param(0, (0, type_graphql_1.Ctx)()),
    __param(1, (0, type_graphql_1.Arg)("tripId", () => type_graphql_1.ID, { nullable: true })),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], MemoryResolver.prototype, "memories", null);
__decorate([
    (0, type_graphql_1.Query)(() => Memory_1.Memory, { nullable: true, description: "Get a single memory by ID" }),
    __param(0, (0, type_graphql_1.Arg)("id", () => String)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], MemoryResolver.prototype, "memory", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Memory_1.Memory, { description: "Create a new memory and associate it with a trip" }),
    __param(0, (0, type_graphql_1.Arg)("input")),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [MemoryInput_1.MemoryInput, Object]),
    __metadata("design:returntype", Promise)
], MemoryResolver.prototype, "createMemory", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Memory_1.Memory, { description: "Update an existing memory" }),
    __param(0, (0, type_graphql_1.Arg)("id", () => String)),
    __param(1, (0, type_graphql_1.Arg)("input")),
    __param(2, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, UpdateMemoryInput_1.UpdateMemoryInput, Object]),
    __metadata("design:returntype", Promise)
], MemoryResolver.prototype, "updateMemory", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => Boolean, { description: "Delete a memory" }),
    __param(0, (0, type_graphql_1.Arg)("id", () => String)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], MemoryResolver.prototype, "deleteMemory", null);
__decorate([
    (0, type_graphql_1.Query)(() => [Memory_1.Memory], { description: "Search memories by query and optional trip filter" }),
    __param(0, (0, type_graphql_1.Arg)("query")),
    __param(1, (0, type_graphql_1.Ctx)()),
    __param(2, (0, type_graphql_1.Arg)("tripId", () => type_graphql_1.ID, { nullable: true })),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, String]),
    __metadata("design:returntype", Promise)
], MemoryResolver.prototype, "searchMemories", null);
__decorate([
    (0, type_graphql_1.FieldResolver)(() => [MediaItem_1.MediaItem]),
    __param(0, (0, type_graphql_1.Root)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Memory_1.Memory]),
    __metadata("design:returntype", Promise)
], MemoryResolver.prototype, "mediaItems", null);
__decorate([
    (0, type_graphql_1.FieldResolver)(() => Location_1.Location, { nullable: true }),
    __param(0, (0, type_graphql_1.Root)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Memory_1.Memory]),
    __metadata("design:returntype", Object)
], MemoryResolver.prototype, "location", null);
MemoryResolver = __decorate([
    (0, type_graphql_1.Resolver)(() => Memory_1.Memory)
], MemoryResolver);
exports.MemoryResolver = MemoryResolver;
