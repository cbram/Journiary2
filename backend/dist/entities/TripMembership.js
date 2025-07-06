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
exports.TripMembership = exports.TripRole = void 0;
const type_graphql_1 = require("type-graphql");
const typeorm_1 = require("typeorm");
const User_1 = require("./User");
const Trip_1 = require("./Trip");
var TripRole;
(function (TripRole) {
    TripRole["OWNER"] = "owner";
    TripRole["EDITOR"] = "editor";
    TripRole["VIEWER"] = "viewer";
})(TripRole || (exports.TripRole = TripRole = {}));
(0, type_graphql_1.registerEnumType)(TripRole, {
    name: "TripRole",
    description: "The role of a user in a trip",
});
let TripMembership = class TripMembership {
};
exports.TripMembership = TripMembership;
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.PrimaryGeneratedColumn)("uuid"),
    __metadata("design:type", String)
], TripMembership.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => User_1.User, user => user.tripMemberships),
    __metadata("design:type", User_1.User)
], TripMembership.prototype, "user", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => Trip_1.Trip, trip => trip.members),
    __metadata("design:type", Trip_1.Trip)
], TripMembership.prototype, "trip", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => TripRole),
    (0, typeorm_1.Column)({
        type: "enum",
        enum: TripRole,
        default: TripRole.VIEWER,
    }),
    __metadata("design:type", String)
], TripMembership.prototype, "role", void 0);
exports.TripMembership = TripMembership = __decorate([
    (0, type_graphql_1.ObjectType)(),
    (0, typeorm_1.Entity)(),
    (0, typeorm_1.Unique)(["user", "trip"]) // A user can only have one role per trip
], TripMembership);
