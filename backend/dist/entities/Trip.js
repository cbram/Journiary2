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
exports.Trip = void 0;
const type_graphql_1 = require("type-graphql");
const typeorm_1 = require("typeorm");
const Memory_1 = require("./Memory");
const RoutePoint_1 = require("./RoutePoint");
const GPXTrack_1 = require("./GPXTrack");
const TrackSegment_1 = require("./TrackSegment");
const User_1 = require("./User");
const TripMembership_1 = require("./TripMembership");
let Trip = class Trip {
};
exports.Trip = Trip;
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.PrimaryGeneratedColumn)("uuid"),
    __metadata("design:type", String)
], Trip.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], Trip.prototype, "name", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], Trip.prototype, "tripDescription", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true, description: "The name of the cover image object in the storage (e.g., MinIO)" }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], Trip.prototype, "coverImageObjectName", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => String, { nullable: true, description: "A temporary URL to view the trip's cover image." }),
    __metadata("design:type", String)
], Trip.prototype, "coverImageUrl", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], Trip.prototype, "travelCompanions", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], Trip.prototype, "visitedCountries", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)(),
    __metadata("design:type", Date)
], Trip.prototype, "startDate", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", Date)
], Trip.prototype, "endDate", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ default: true }),
    __metadata("design:type", Boolean)
], Trip.prototype, "isActive", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float),
    (0, typeorm_1.Column)({ type: "float", default: 0 }),
    __metadata("design:type", Number)
], Trip.prototype, "totalDistance", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ default: true }),
    __metadata("design:type", Boolean)
], Trip.prototype, "gpsTrackingEnabled", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ type: "timestamp", default: () => "CURRENT_TIMESTAMP" }),
    __metadata("design:type", Date)
], Trip.prototype, "createdAt", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ type: "timestamp", default: () => "CURRENT_TIMESTAMP" }),
    __metadata("design:type", Date)
], Trip.prototype, "updatedAt", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => User_1.User, user => user.ownedTrips),
    __metadata("design:type", User_1.User)
], Trip.prototype, "owner", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => TripMembership_1.TripMembership, membership => membership.trip),
    __metadata("design:type", Array)
], Trip.prototype, "members", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [Memory_1.Memory]),
    (0, typeorm_1.OneToMany)(() => Memory_1.Memory, memory => memory.trip, { cascade: true }),
    __metadata("design:type", Array)
], Trip.prototype, "memories", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [RoutePoint_1.RoutePoint]),
    (0, typeorm_1.OneToMany)(() => RoutePoint_1.RoutePoint, (routePoint) => routePoint.trip),
    __metadata("design:type", Array)
], Trip.prototype, "routePoints", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [GPXTrack_1.GPXTrack]),
    (0, typeorm_1.OneToMany)(() => GPXTrack_1.GPXTrack, track => track.trip),
    __metadata("design:type", Array)
], Trip.prototype, "gpxTracks", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [TrackSegment_1.TrackSegment]),
    (0, typeorm_1.OneToMany)(() => TrackSegment_1.TrackSegment, segment => segment.trip),
    __metadata("design:type", Array)
], Trip.prototype, "trackSegments", void 0);
exports.Trip = Trip = __decorate([
    (0, type_graphql_1.ObjectType)({ description: "Represents a single journey or trip" }),
    (0, typeorm_1.Entity)()
], Trip);
