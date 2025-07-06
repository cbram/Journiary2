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
exports.Memory = void 0;
const type_graphql_1 = require("type-graphql");
const typeorm_1 = require("typeorm");
const Trip_1 = require("./Trip");
const MediaItem_1 = require("./MediaItem");
const Tag_1 = require("./Tag");
const GPXTrack_1 = require("./GPXTrack");
const BucketListItem_1 = require("./BucketListItem");
const User_1 = require("./User");
let Memory = class Memory {
    // Alias-Feld `content` für neue iOS-Versionen
    get content() {
        return this.text;
    }
    get date() {
        return this.timestamp;
    }
    get address() {
        return this.locationName;
    }
    /**
     * Alias-Feld – liefert die ID des Erstellers als `userId`, wie im iOS-Schema erwartet.
     * Wird mittels Getter bereitgestellt, ohne ein eigenes DB-Feld anzulegen.
     */
    get userId() {
        return this.creator?.id ?? "unknown";
    }
};
exports.Memory = Memory;
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.PrimaryGeneratedColumn)("uuid"),
    __metadata("design:type", String)
], Memory.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Memory.prototype, "title", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)("text", { nullable: true }),
    __metadata("design:type", String)
], Memory.prototype, "text", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => String, { name: "content", nullable: true }),
    __metadata("design:type", Object),
    __metadata("design:paramtypes", [])
], Memory.prototype, "content", null);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ type: "timestamp", default: () => "CURRENT_TIMESTAMP" }),
    __metadata("design:type", Date)
], Memory.prototype, "timestamp", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Date, { name: "date" }),
    __metadata("design:type", Date),
    __metadata("design:paramtypes", [])
], Memory.prototype, "date", null);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float),
    (0, typeorm_1.Column)("double precision"),
    __metadata("design:type", Number)
], Memory.prototype, "latitude", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float),
    (0, typeorm_1.Column)("double precision"),
    __metadata("design:type", Number)
], Memory.prototype, "longitude", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], Memory.prototype, "locationName", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => String, { name: "address", nullable: true }),
    __metadata("design:type", Object),
    __metadata("design:paramtypes", [])
], Memory.prototype, "address", null);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true, description: "JSON string containing weather data" }),
    (0, typeorm_1.Column)("text", { nullable: true }),
    __metadata("design:type", String)
], Memory.prototype, "weatherJSON", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [MediaItem_1.MediaItem], { description: "A list of media items associated with this memory" }),
    (0, typeorm_1.OneToMany)(() => MediaItem_1.MediaItem, (mediaItem) => mediaItem.memory),
    __metadata("design:type", Array)
], Memory.prototype, "mediaItems", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [Tag_1.Tag]),
    (0, typeorm_1.ManyToMany)(() => Tag_1.Tag, tag => tag.memories),
    (0, typeorm_1.JoinTable)(),
    __metadata("design:type", Array)
], Memory.prototype, "tags", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => User_1.User, user => user.createdMemories),
    __metadata("design:type", User_1.User)
], Memory.prototype, "creator", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Trip_1.Trip, (trip) => trip.memories),
    __metadata("design:type", Trip_1.Trip)
], Memory.prototype, "trip", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Memory.prototype, "tripId", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => GPXTrack_1.GPXTrack, { nullable: true }),
    (0, typeorm_1.OneToOne)(() => GPXTrack_1.GPXTrack, gpxTrack => gpxTrack.memory, { cascade: true, nullable: true }),
    (0, typeorm_1.JoinColumn)(),
    __metadata("design:type", GPXTrack_1.GPXTrack)
], Memory.prototype, "gpxTrack", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => BucketListItem_1.BucketListItem, item => item.memories, { nullable: true }),
    __metadata("design:type", BucketListItem_1.BucketListItem)
], Memory.prototype, "bucketListItem", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], Memory.prototype, "createdAt", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.UpdateDateColumn)(),
    __metadata("design:type", Date)
], Memory.prototype, "updatedAt", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID, { name: "userId" }),
    __metadata("design:type", String),
    __metadata("design:paramtypes", [])
], Memory.prototype, "userId", null);
exports.Memory = Memory = __decorate([
    (0, type_graphql_1.ObjectType)({ description: "Represents a single memory or event within a trip" }),
    (0, typeorm_1.Entity)()
], Memory);
