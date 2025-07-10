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
exports.BucketListItem = void 0;
const type_graphql_1 = require("type-graphql");
const typeorm_1 = require("typeorm");
const Memory_1 = require("./Memory");
const User_1 = require("./User");
let BucketListItem = class BucketListItem {
};
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.PrimaryGeneratedColumn)("uuid"),
    __metadata("design:type", String)
], BucketListItem.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)(),
    __metadata("design:type", String)
], BucketListItem.prototype, "name", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], BucketListItem.prototype, "country", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], BucketListItem.prototype, "region", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], BucketListItem.prototype, "type", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], BucketListItem.prototype, "latitude1", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], BucketListItem.prototype, "longitude1", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], BucketListItem.prototype, "latitude2", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    (0, typeorm_1.Column)("float", { nullable: true }),
    __metadata("design:type", Number)
], BucketListItem.prototype, "longitude2", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ default: false }),
    __metadata("design:type", Boolean)
], BucketListItem.prototype, "isDone", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], BucketListItem.prototype, "createdAt", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ type: "timestamp", default: () => "CURRENT_TIMESTAMP" }),
    __metadata("design:type", Date)
], BucketListItem.prototype, "updatedAt", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => User_1.User, user => user.createdBucketListItems),
    __metadata("design:type", User_1.User)
], BucketListItem.prototype, "creator", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ type: "timestamp", nullable: true }),
    __metadata("design:type", Date)
], BucketListItem.prototype, "completedAt", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [Memory_1.Memory], { nullable: true }),
    (0, typeorm_1.OneToMany)(() => Memory_1.Memory, memory => memory.bucketListItem),
    __metadata("design:type", Array)
], BucketListItem.prototype, "memories", void 0);
BucketListItem = __decorate([
    (0, type_graphql_1.ObjectType)(),
    (0, typeorm_1.Entity)()
], BucketListItem);
exports.BucketListItem = BucketListItem;
