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
exports.MediaItemInput = void 0;
const type_graphql_1 = require("type-graphql");
let MediaItemInput = class MediaItemInput {
};
__decorate([
    (0, type_graphql_1.Field)({ description: "The name of the object in the storage (e.g., from createUploadUrl)" }),
    __metadata("design:type", String)
], MediaItemInput.prototype, "objectName", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true, description: "The name of the thumbnail object in the storage" }),
    __metadata("design:type", String)
], MediaItemInput.prototype, "thumbnailObjectName", void 0);
__decorate([
    (0, type_graphql_1.Field)({ description: "The ID of the memory this media item belongs to" }),
    __metadata("design:type", String)
], MediaItemInput.prototype, "memoryId", void 0);
__decorate([
    (0, type_graphql_1.Field)({ description: "The type of media, e.g., 'image', 'video'." }),
    __metadata("design:type", String)
], MediaItemInput.prototype, "mediaType", void 0);
__decorate([
    (0, type_graphql_1.Field)({ description: "The timestamp of when the media was created" }),
    __metadata("design:type", Date)
], MediaItemInput.prototype, "timestamp", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Int, { description: "The order of this item within the memory's media list" }),
    __metadata("design:type", Number)
], MediaItemInput.prototype, "order", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Int, { description: "File size in bytes" }),
    __metadata("design:type", Number)
], MediaItemInput.prototype, "filesize", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Int, { nullable: true, description: "For videos, the duration in seconds." }),
    __metadata("design:type", Number)
], MediaItemInput.prototype, "duration", void 0);
MediaItemInput = __decorate([
    (0, type_graphql_1.InputType)({ description: "Input data for creating a new MediaItem" })
], MediaItemInput);
exports.MediaItemInput = MediaItemInput;
