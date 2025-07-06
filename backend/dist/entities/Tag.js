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
exports.Tag = void 0;
const type_graphql_1 = require("type-graphql");
const typeorm_1 = require("typeorm");
const TagCategory_1 = require("./TagCategory");
const Memory_1 = require("./Memory");
const User_1 = require("./User");
let Tag = class Tag {
};
exports.Tag = Tag;
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.PrimaryGeneratedColumn)("uuid"),
    __metadata("design:type", String)
], Tag.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ unique: true }),
    __metadata("design:type", String)
], Tag.prototype, "name", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], Tag.prototype, "normalizedName", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], Tag.prototype, "displayName", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], Tag.prototype, "emoji", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], Tag.prototype, "color", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ default: false }),
    __metadata("design:type", Boolean)
], Tag.prototype, "isSystemTag", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Int),
    (0, typeorm_1.Column)({ default: 0 }),
    __metadata("design:type", Number)
], Tag.prototype, "usageCount", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], Tag.prototype, "createdAt", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.UpdateDateColumn)(),
    __metadata("design:type", Date)
], Tag.prototype, "updatedAt", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ default: false }),
    __metadata("design:type", Boolean)
], Tag.prototype, "isArchived", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Int),
    (0, typeorm_1.Column)({ default: 0 }),
    __metadata("design:type", Number)
], Tag.prototype, "sortOrder", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], Tag.prototype, "tagDescription", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => User_1.User, user => user.createdTags),
    __metadata("design:type", User_1.User)
], Tag.prototype, "creator", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => TagCategory_1.TagCategory, category => category.tags, { nullable: true, onDelete: 'SET NULL' }),
    (0, type_graphql_1.Field)(() => TagCategory_1.TagCategory, { nullable: true }),
    __metadata("design:type", Object)
], Tag.prototype, "category", void 0);
__decorate([
    (0, typeorm_1.ManyToMany)(() => Memory_1.Memory, memory => memory.tags),
    __metadata("design:type", Array)
], Tag.prototype, "memories", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [Tag], { nullable: true }),
    (0, typeorm_1.ManyToMany)(() => Tag),
    (0, typeorm_1.JoinTable)({
        name: "tag_related_tags",
        joinColumn: { name: "tag_id", referencedColumnName: "id" },
        inverseJoinColumn: { name: "related_tag_id", referencedColumnName: "id" }
    }),
    __metadata("design:type", Array)
], Tag.prototype, "relatedTags", void 0);
exports.Tag = Tag = __decorate([
    (0, type_graphql_1.ObjectType)({ description: "A tag to categorize memories" }),
    (0, typeorm_1.Entity)()
], Tag);
