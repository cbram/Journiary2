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
exports.User = void 0;
const type_graphql_1 = require("type-graphql");
const typeorm_1 = require("typeorm");
const Trip_1 = require("./Trip");
const Memory_1 = require("./Memory");
const MediaItem_1 = require("./MediaItem");
const BucketListItem_1 = require("./BucketListItem");
const Tag_1 = require("./Tag");
const TagCategory_1 = require("./TagCategory");
const RoutePoint_1 = require("./RoutePoint");
const GPXTrack_1 = require("./GPXTrack");
const TripMembership_1 = require("./TripMembership");
let User = class User {
    // Computed Fields
    get displayName() {
        if (this.firstName && this.lastName) {
            return `${this.firstName} ${this.lastName}`;
        }
        else if (this.firstName) {
            return this.firstName;
        }
        else if (this.username) {
            return this.username;
        }
        else {
            return this.email;
        }
    }
    get initials() {
        if (this.firstName && this.lastName) {
            return `${this.firstName.charAt(0)}${this.lastName.charAt(0)}`.toUpperCase();
        }
        else if (this.firstName) {
            return this.firstName.substring(0, 2).toUpperCase();
        }
        else if (this.username) {
            return this.username.substring(0, 2).toUpperCase();
        }
        else {
            return this.email.substring(0, 2).toUpperCase();
        }
    }
    get isOnline() {
        if (!this.lastLoginAt)
            return false;
        const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
        return this.lastLoginAt > thirtyMinutesAgo;
    }
    // Helper Methods (not exposed as GraphQL fields)
    updateLastLogin() {
        this.lastLoginAt = new Date();
    }
    markEmailAsVerified() {
        this.isEmailVerified = true;
    }
    deactivate() {
        this.isActive = false;
    }
    reactivate() {
        this.isActive = true;
    }
};
exports.User = User;
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.PrimaryGeneratedColumn)("uuid"),
    __metadata("design:type", String)
], User.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ unique: true }),
    __metadata("design:type", String)
], User.prototype, "email", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ unique: true }),
    __metadata("design:type", String)
], User.prototype, "username", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], User.prototype, "firstName", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], User.prototype, "lastName", void 0);
__decorate([
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], User.prototype, "password", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], User.prototype, "profileImageUrl", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ default: true }),
    __metadata("design:type", Boolean)
], User.prototype, "isActive", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ default: false }),
    __metadata("design:type", Boolean)
], User.prototype, "isEmailVerified", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", Date)
], User.prototype, "lastLoginAt", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], User.prototype, "createdAt", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.UpdateDateColumn)(),
    __metadata("design:type", Date)
], User.prototype, "updatedAt", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => Trip_1.Trip, trip => trip.owner),
    __metadata("design:type", Array)
], User.prototype, "ownedTrips", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => TripMembership_1.TripMembership, membership => membership.user),
    __metadata("design:type", Array)
], User.prototype, "tripMemberships", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => Memory_1.Memory, memory => memory.creator),
    __metadata("design:type", Array)
], User.prototype, "createdMemories", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => MediaItem_1.MediaItem, mediaItem => mediaItem.uploader),
    __metadata("design:type", Array)
], User.prototype, "uploadedMediaItems", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => BucketListItem_1.BucketListItem, item => item.creator),
    __metadata("design:type", Array)
], User.prototype, "createdBucketListItems", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => Tag_1.Tag, tag => tag.creator),
    __metadata("design:type", Array)
], User.prototype, "createdTags", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => TagCategory_1.TagCategory, category => category.creator),
    __metadata("design:type", Array)
], User.prototype, "createdTagCategories", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => RoutePoint_1.RoutePoint, routePoint => routePoint.recorder),
    __metadata("design:type", Array)
], User.prototype, "recordedRoutePoints", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => GPXTrack_1.GPXTrack, gpxTrack => gpxTrack.creator),
    __metadata("design:type", Array)
], User.prototype, "createdGPXTracks", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String),
    __metadata("design:paramtypes", [])
], User.prototype, "displayName", null);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String),
    __metadata("design:paramtypes", [])
], User.prototype, "initials", null);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", Boolean),
    __metadata("design:paramtypes", [])
], User.prototype, "isOnline", null);
exports.User = User = __decorate([
    (0, type_graphql_1.ObjectType)({ description: "Represents a user of the application" }),
    (0, typeorm_1.Entity)()
], User);
