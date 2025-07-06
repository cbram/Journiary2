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
exports.TrackMetadata = void 0;
const type_graphql_1 = require("type-graphql");
const typeorm_1 = require("typeorm");
const TrackSegment_1 = require("./TrackSegment");
let TrackMetadata = class TrackMetadata {
};
exports.TrackMetadata = TrackMetadata;
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.PrimaryGeneratedColumn)("uuid"),
    __metadata("design:type", String)
], TrackMetadata.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], TrackMetadata.prototype, "transportationMode", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], TrackMetadata.prototype, "movementPattern", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], TrackMetadata.prototype, "terrainType", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], TrackMetadata.prototype, "weatherConditions", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], TrackMetadata.prototype, "batteryLevel", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], TrackMetadata.prototype, "gpsAccuracy", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], TrackMetadata.prototype, "elevationGain", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], TrackMetadata.prototype, "elevationLoss", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], TrackMetadata.prototype, "pauseDuration", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], TrackMetadata.prototype, "createdAt", void 0);
__decorate([
    (0, typeorm_1.OneToOne)(() => TrackSegment_1.TrackSegment, segment => segment.metadata),
    (0, typeorm_1.JoinColumn)(),
    __metadata("design:type", TrackSegment_1.TrackSegment)
], TrackMetadata.prototype, "trackSegment", void 0);
exports.TrackMetadata = TrackMetadata = __decorate([
    (0, type_graphql_1.ObjectType)({ description: "Represents metadata for a track segment" }),
    (0, typeorm_1.Entity)()
], TrackMetadata);
