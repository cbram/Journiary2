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
exports.SyncResponse = exports.DeletedIds = void 0;
const type_graphql_1 = require("type-graphql");
const Trip_1 = require("../../entities/Trip");
const Memory_1 = require("../../entities/Memory");
const Tag_1 = require("../../entities/Tag");
const TagCategory_1 = require("../../entities/TagCategory");
const MediaItem_1 = require("../../entities/MediaItem");
const GPXTrack_1 = require("../../entities/GPXTrack");
const BucketListItem_1 = require("../../entities/BucketListItem");
let DeletedIds = class DeletedIds {
};
exports.DeletedIds = DeletedIds;
__decorate([
    (0, type_graphql_1.Field)(() => [type_graphql_1.ID]),
    __metadata("design:type", Array)
], DeletedIds.prototype, "trips", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [type_graphql_1.ID]),
    __metadata("design:type", Array)
], DeletedIds.prototype, "memories", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [type_graphql_1.ID]),
    __metadata("design:type", Array)
], DeletedIds.prototype, "tags", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [type_graphql_1.ID]),
    __metadata("design:type", Array)
], DeletedIds.prototype, "tagCategories", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [type_graphql_1.ID]),
    __metadata("design:type", Array)
], DeletedIds.prototype, "mediaItems", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [type_graphql_1.ID]),
    __metadata("design:type", Array)
], DeletedIds.prototype, "gpxTracks", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [type_graphql_1.ID]),
    __metadata("design:type", Array)
], DeletedIds.prototype, "bucketListItems", void 0);
exports.DeletedIds = DeletedIds = __decorate([
    (0, type_graphql_1.ObjectType)()
], DeletedIds);
let SyncResponse = class SyncResponse {
};
exports.SyncResponse = SyncResponse;
__decorate([
    (0, type_graphql_1.Field)(() => [Trip_1.Trip]),
    __metadata("design:type", Array)
], SyncResponse.prototype, "trips", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [Memory_1.Memory]),
    __metadata("design:type", Array)
], SyncResponse.prototype, "memories", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [Tag_1.Tag]),
    __metadata("design:type", Array)
], SyncResponse.prototype, "tags", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [TagCategory_1.TagCategory]),
    __metadata("design:type", Array)
], SyncResponse.prototype, "tagCategories", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [MediaItem_1.MediaItem]),
    __metadata("design:type", Array)
], SyncResponse.prototype, "mediaItems", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [GPXTrack_1.GPXTrack]),
    __metadata("design:type", Array)
], SyncResponse.prototype, "gpxTracks", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [BucketListItem_1.BucketListItem]),
    __metadata("design:type", Array)
], SyncResponse.prototype, "bucketListItems", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => DeletedIds),
    __metadata("design:type", DeletedIds)
], SyncResponse.prototype, "deleted", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", Date)
], SyncResponse.prototype, "serverTimestamp", void 0);
exports.SyncResponse = SyncResponse = __decorate([
    (0, type_graphql_1.ObjectType)()
], SyncResponse);
