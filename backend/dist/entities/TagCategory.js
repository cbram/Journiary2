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
exports.TagCategory = void 0;
const type_graphql_1 = require("type-graphql");
const typeorm_1 = require("typeorm");
const Tag_1 = require("./Tag");
const User_1 = require("./User");
let TagCategory = class TagCategory {
};
exports.TagCategory = TagCategory;
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    (0, typeorm_1.PrimaryGeneratedColumn)("uuid"),
    __metadata("design:type", String)
], TagCategory.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ unique: true }),
    __metadata("design:type", String)
], TagCategory.prototype, "name", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], TagCategory.prototype, "displayName", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], TagCategory.prototype, "emoji", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    (0, typeorm_1.Column)({ nullable: true }),
    __metadata("design:type", String)
], TagCategory.prototype, "color", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ default: false }),
    __metadata("design:type", Boolean)
], TagCategory.prototype, "isSystemCategory", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Int),
    (0, typeorm_1.Column)({ default: 0 }),
    __metadata("design:type", Number)
], TagCategory.prototype, "sortOrder", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ default: true }),
    __metadata("design:type", Boolean)
], TagCategory.prototype, "isExpanded", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.CreateDateColumn)(),
    __metadata("design:type", Date)
], TagCategory.prototype, "createdAt", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    (0, typeorm_1.Column)({ type: "timestamp", default: () => "CURRENT_TIMESTAMP", onUpdate: "CURRENT_TIMESTAMP" }),
    __metadata("design:type", Date)
], TagCategory.prototype, "updatedAt", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => User_1.User, user => user.createdTagCategories),
    __metadata("design:type", User_1.User)
], TagCategory.prototype, "creator", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [Tag_1.Tag]),
    (0, typeorm_1.OneToMany)(() => Tag_1.Tag, tag => tag.category),
    __metadata("design:type", Array)
], TagCategory.prototype, "tags", void 0);
exports.TagCategory = TagCategory = __decorate([
    (0, type_graphql_1.ObjectType)({ description: "Represents a category for grouping tags" }),
    (0, typeorm_1.Entity)()
], TagCategory);
