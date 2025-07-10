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
exports.TrackSegment = void 0;
const type_graphql_1 = require("type-graphql");
const typeorm_1 = require("typeorm");
const GPXTrack_1 = require("./GPXTrack");
const RoutePoint_1 = require("./RoutePoint");
const TrackMetadata_1 = require("./TrackMetadata");
const Trip_1 = require("./Trip");
let TrackSegment = class TrackSegment {
};
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.PrimaryGeneratedColumn)("uuid"),
    __metadata("design:type", String)
], TrackSegment.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => GPXTrack_1.GPXTrack, track => track.segments),
    (0, typeorm_1.JoinColumn)({ name: "gpxTrackId" }),
    __metadata("design:type", GPXTrack_1.GPXTrack)
], TrackSegment.prototype, "gpxTrack", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Trip_1.Trip, trip => trip.trackSegments, { nullable: true }),
    __metadata("design:type", Trip_1.Trip)
], TrackSegment.prototype, "trip", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [RoutePoint_1.RoutePoint]),
    (0, typeorm_1.OneToMany)(() => RoutePoint_1.RoutePoint, point => point.trackSegment, { cascade: true }),
    __metadata("design:type", Array)
], TrackSegment.prototype, "points", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], TrackSegment.prototype, "segmentType", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: "bytea", nullable: true }),
    __metadata("design:type", Buffer)
], TrackSegment.prototype, "encodedData", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], TrackSegment.prototype, "compressionRatio", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", Date)
], TrackSegment.prototype, "startDate", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", Date)
], TrackSegment.prototype, "endDate", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], TrackSegment.prototype, "distance", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], TrackSegment.prototype, "averageSpeed", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], TrackSegment.prototype, "maxSpeed", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Int, { nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", Number)
], TrackSegment.prototype, "originalPointCount", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", Boolean)
], TrackSegment.prototype, "isCompressed", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], TrackSegment.prototype, "qualityLevel", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => TrackMetadata_1.TrackMetadata, { nullable: true }),
    (0, typeorm_1.OneToOne)(() => TrackMetadata_1.TrackMetadata, metadata => metadata.trackSegment, { cascade: true, nullable: true }),
    __metadata("design:type", TrackMetadata_1.TrackMetadata)
], TrackSegment.prototype, "metadata", void 0);
TrackSegment = __decorate([
    (0, type_graphql_1.ObjectType)({ description: "A continuous segment of a GPX track, containing a series of points." }),
    (0, typeorm_1.Entity)()
], TrackSegment);
exports.TrackSegment = TrackSegment;
