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
exports.RoutePoint = void 0;
const type_graphql_1 = require("type-graphql");
const typeorm_1 = require("typeorm");
const Trip_1 = require("./Trip");
const TrackSegment_1 = require("./TrackSegment");
const User_1 = require("./User");
let RoutePoint = class RoutePoint {
};
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.PrimaryGeneratedColumn)("uuid"),
    __metadata("design:type", String)
], RoutePoint.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float),
    (0, typeorm_1.Column)("double precision"),
    __metadata("design:type", Number)
], RoutePoint.prototype, "latitude", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float),
    (0, typeorm_1.Column)("double precision"),
    __metadata("design:type", Number)
], RoutePoint.prototype, "longitude", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("double precision", { nullable: true }),
    __metadata("design:type", Number)
], RoutePoint.prototype, "altitude", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], RoutePoint.prototype, "speed", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)(),
    __metadata("design:type", Date)
], RoutePoint.prototype, "timestamp", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => User_1.User, user => user.recordedRoutePoints),
    __metadata("design:type", User_1.User)
], RoutePoint.prototype, "recorder", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Trip_1.Trip, (trip) => trip.routePoints),
    __metadata("design:type", Trip_1.Trip)
], RoutePoint.prototype, "trip", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => TrackSegment_1.TrackSegment, segment => segment.points, { nullable: true }),
    __metadata("design:type", TrackSegment_1.TrackSegment)
], RoutePoint.prototype, "trackSegment", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], RoutePoint.prototype, "created_at", void 0);
RoutePoint = __decorate([
    (0, type_graphql_1.ObjectType)({ description: "Represents a single GPS point on a route" }),
    (0, typeorm_1.Entity)()
], RoutePoint);
exports.RoutePoint = RoutePoint;
