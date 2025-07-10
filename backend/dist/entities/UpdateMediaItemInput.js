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
exports.UpdateMediaItemInput = void 0;
const type_graphql_1 = require("type-graphql");
let UpdateMediaItemInput = class UpdateMediaItemInput {
};
exports.UpdateMediaItemInput = UpdateMediaItemInput;
__decorate([
    (0, type_graphql_1.Field)({ nullable: true, description: "The name of the object in the storage (e.g., from createUploadUrl)" }),
    __metadata("design:type", String)
], UpdateMediaItemInput.prototype, "objectName", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true, description: "The name of the thumbnail object in the storage" }),
    __metadata("design:type", String)
], UpdateMediaItemInput.prototype, "thumbnailObjectName", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true, description: "The type of media, e.g., 'image', 'video'." }),
    __metadata("design:type", String)
], UpdateMediaItemInput.prototype, "mediaType", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true, description: "The timestamp of when the media was created" }),
    __metadata("design:type", Date)
], UpdateMediaItemInput.prototype, "timestamp", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Int, { nullable: true, description: "The order of this item within the memory's media list" }),
    __metadata("design:type", Number)
], UpdateMediaItemInput.prototype, "order", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Int, { nullable: true, description: "File size in bytes" }),
    __metadata("design:type", Number)
], UpdateMediaItemInput.prototype, "filesize", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Int, { nullable: true, description: "For videos, the duration in seconds." }),
    __metadata("design:type", Number)
], UpdateMediaItemInput.prototype, "duration", void 0);
exports.UpdateMediaItemInput = UpdateMediaItemInput = __decorate([
    (0, type_graphql_1.InputType)({ description: "Input data for updating a MediaItem" })
], UpdateMediaItemInput);
