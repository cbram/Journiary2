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
exports.GPXTrack = void 0;
const type_graphql_1 = require("type-graphql");
const typeorm_1 = require("typeorm");
const Trip_1 = require("./Trip");
const TrackSegment_1 = require("./TrackSegment");
const Memory_1 = require("./Memory");
let GPXTrack = class GPXTrack {
};
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.PrimaryGeneratedColumn)("uuid"),
    __metadata("design:type", String)
], GPXTrack.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], GPXTrack.prototype, "name", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)("text", { nullable: true }),
    __metadata("design:type", String)
], GPXTrack.prototype, "description", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], GPXTrack.prototype, "originalFilename", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true, description: "The name of the GPX file object in the storage (e.g., MinIO)" }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], GPXTrack.prototype, "gpxFileObjectName", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], GPXTrack.prototype, "totalDistance", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], GPXTrack.prototype, "totalDuration", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], GPXTrack.prototype, "averageSpeed", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], GPXTrack.prototype, "maxSpeed", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], GPXTrack.prototype, "elevationGain", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], GPXTrack.prototype, "elevationLoss", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], GPXTrack.prototype, "minElevation", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], GPXTrack.prototype, "maxElevation", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Int, { nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", Number)
], GPXTrack.prototype, "totalPoints", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", Date)
], GPXTrack.prototype, "startTime", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", Date)
], GPXTrack.prototype, "endTime", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], GPXTrack.prototype, "creator", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], GPXTrack.prototype, "trackType", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], GPXTrack.prototype, "createdAt", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ type: "timestamp", default: () => "CURRENT_TIMESTAMP" }),
    __metadata("design:type", Date)
], GPXTrack.prototype, "updatedAt", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Trip_1.Trip, trip => trip.gpxTracks),
    __metadata("design:type", Trip_1.Trip)
], GPXTrack.prototype, "trip", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], GPXTrack.prototype, "tripId", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => String, { nullable: true, description: "A temporary URL to download the GPX file." }),
    __metadata("design:type", String)
], GPXTrack.prototype, "downloadUrl", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [TrackSegment_1.TrackSegment]),
    (0, typeorm_1.OneToMany)(() => TrackSegment_1.TrackSegment, segment => segment.gpxTrack, { cascade: true }),
    __metadata("design:type", Array)
], GPXTrack.prototype, "segments", void 0);
__decorate([
    (0, typeorm_1.OneToOne)(() => Memory_1.Memory, memory => memory.gpxTrack, { nullable: true }),
    __metadata("design:type", Memory_1.Memory)
], GPXTrack.prototype, "memory", void 0);
GPXTrack = __decorate([
    (0, type_graphql_1.ObjectType)({ description: "Represents a GPX track, which is a collection of track segments" }),
    (0, typeorm_1.Entity)()
], GPXTrack);
exports.GPXTrack = GPXTrack;
