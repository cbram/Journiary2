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
Object.defineProperty(exports, "__esModule", { value: true });
exports.MediaItem = void 0;
const type_graphql_1 = require("type-graphql");
const typeorm_1 = require("typeorm");
const Memory_1 = require("./Memory");
const User_1 = require("./User");
let MediaItem = class MediaItem {
};
exports.MediaItem = MediaItem;
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.PrimaryGeneratedColumn)("uuid"),
    __metadata("design:type", String)
], MediaItem.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)({ name: "mimeType" }),
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], MediaItem.prototype, "mediaType", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)(),
    __metadata("design:type", Date)
], MediaItem.prototype, "timestamp", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Int, { description: "The order of this item within the memory's media list" }),
    (0, typeorm_1.Column)(),
    __metadata("design:type", Number)
], MediaItem.prototype, "order", void 0);
__decorate([
    (0, type_graphql_1.Field)({ name: "s3Key" }),
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], MediaItem.prototype, "objectName", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Int, { name: "fileSize", description: "File size in bytes" }),
    (0, typeorm_1.Column)(),
    __metadata("design:type", Number)
], MediaItem.prototype, "filesize", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true, description: "For videos, the duration in seconds." }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", Number)
], MediaItem.prototype, "duration", void 0);
__decorate([
    (0, type_graphql_1.Field)({ name: "thumbnailS3Key", nullable: true, description: "The name of the thumbnail object in the storage (e.g., MinIO)" }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], MediaItem.prototype, "thumbnailObjectName", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => User_1.User, user => user.uploadedMediaItems),
    __metadata("design:type", User_1.User)
], MediaItem.prototype, "uploader", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Memory_1.Memory),
    (0, typeorm_1.ManyToOne)(() => Memory_1.Memory, (memory) => memory.mediaItems),
    __metadata("design:type", Memory_1.Memory)
], MediaItem.prototype, "memory", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], MediaItem.prototype, "createdAt", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.UpdateDateColumn)(),
    __metadata("design:type", Date)
], MediaItem.prototype, "updatedAt", void 0);
exports.MediaItem = MediaItem = __decorate([
    (0, type_graphql_1.ObjectType)({ description: "Represents a media file (photo, video, etc.) associated with a memory" }),
    (0, typeorm_1.Entity)()
], MediaItem);
