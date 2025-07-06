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
exports.MemoryInput = void 0;
const type_graphql_1 = require("type-graphql");
const LocationInput_1 = require("./LocationInput");
let MemoryInput = class MemoryInput {
};
exports.MemoryInput = MemoryInput;
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], MemoryInput.prototype, "title", void 0);
__decorate([
    (0, type_graphql_1.Field)({ name: "content", nullable: true }),
    __metadata("design:type", String)
], MemoryInput.prototype, "text", void 0);
__decorate([
    (0, type_graphql_1.Field)({ name: "date", nullable: true }),
    __metadata("design:type", Date)
], MemoryInput.prototype, "timestamp", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    __metadata("design:type", Number)
], MemoryInput.prototype, "latitude", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    __metadata("design:type", Number)
], MemoryInput.prototype, "longitude", void 0);
__decorate([
    (0, type_graphql_1.Field)({ name: "address", nullable: true }),
    __metadata("design:type", String)
], MemoryInput.prototype, "locationName", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => LocationInput_1.LocationInput, { nullable: true }),
    __metadata("design:type", LocationInput_1.LocationInput)
], MemoryInput.prototype, "location", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID, { description: "The ID of the trip this memory belongs to" }),
    __metadata("design:type", String)
], MemoryInput.prototype, "tripId", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [type_graphql_1.ID], { nullable: true, description: "A list of Tag IDs to associate with this memory" }),
    __metadata("design:type", Array)
], MemoryInput.prototype, "tagIds", void 0);
exports.MemoryInput = MemoryInput = __decorate([
    (0, type_graphql_1.InputType)({ description: "New memory data" })
], MemoryInput);
