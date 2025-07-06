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
exports.BulkMemoryUpdateInput = void 0;
const type_graphql_1 = require("type-graphql");
let BulkMemoryUpdateInput = class BulkMemoryUpdateInput {
};
exports.BulkMemoryUpdateInput = BulkMemoryUpdateInput;
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    __metadata("design:type", String)
], BulkMemoryUpdateInput.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    __metadata("design:type", String)
], BulkMemoryUpdateInput.prototype, "title", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    __metadata("design:type", String)
], BulkMemoryUpdateInput.prototype, "content", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    __metadata("design:type", Date)
], BulkMemoryUpdateInput.prototype, "date", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    __metadata("design:type", Number)
], BulkMemoryUpdateInput.prototype, "latitude", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.Float, { nullable: true }),
    __metadata("design:type", Number)
], BulkMemoryUpdateInput.prototype, "longitude", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    __metadata("design:type", String)
], BulkMemoryUpdateInput.prototype, "address", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID, { nullable: true }),
    __metadata("design:type", String)
], BulkMemoryUpdateInput.prototype, "tripId", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", Date)
], BulkMemoryUpdateInput.prototype, "updatedAt", void 0);
exports.BulkMemoryUpdateInput = BulkMemoryUpdateInput = __decorate([
    (0, type_graphql_1.InputType)({ description: "Bulk update memory data" })
], BulkMemoryUpdateInput);
