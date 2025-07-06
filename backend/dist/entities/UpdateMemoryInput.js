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
exports.UpdateMemoryInput = void 0;
const type_graphql_1 = require("type-graphql");
const LocationInput_1 = require("./LocationInput");
let UpdateMemoryInput = class UpdateMemoryInput {
};
exports.UpdateMemoryInput = UpdateMemoryInput;
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    __metadata("design:type", String)
], UpdateMemoryInput.prototype, "title", void 0);
__decorate([
    (0, type_graphql_1.Field)({ name: "content", nullable: true }),
    __metadata("design:type", String)
], UpdateMemoryInput.prototype, "text", void 0);
__decorate([
    (0, type_graphql_1.Field)({ name: "date", nullable: true }),
    __metadata("design:type", Date)
], UpdateMemoryInput.prototype, "timestamp", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    __metadata("design:type", Number)
], UpdateMemoryInput.prototype, "latitude", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    __metadata("design:type", Number)
], UpdateMemoryInput.prototype, "longitude", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => LocationInput_1.LocationInput, { nullable: true }),
    __metadata("design:type", LocationInput_1.LocationInput)
], UpdateMemoryInput.prototype, "location", void 0);
__decorate([
    (0, type_graphql_1.Field)({ name: "address", nullable: true }),
    __metadata("design:type", String)
], UpdateMemoryInput.prototype, "locationName", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [String], { nullable: true, description: "A list of Tag IDs to associate with this memory" }),
    __metadata("design:type", Array)
], UpdateMemoryInput.prototype, "tagIds", void 0);
exports.UpdateMemoryInput = UpdateMemoryInput = __decorate([
    (0, type_graphql_1.InputType)({ description: "Update memory data" })
], UpdateMemoryInput);
