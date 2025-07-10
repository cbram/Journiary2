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
exports.BatchSyncResponse = exports.FailedOperation = exports.SyncResult = exports.BatchSyncOptions = exports.SyncOperation = exports.SyncResultStatus = exports.SyncOperationType = void 0;
const type_graphql_1 = require("type-graphql");
// Enums für bessere Typisierung
var SyncOperationType;
(function (SyncOperationType) {
    SyncOperationType["CREATE"] = "CREATE";
    SyncOperationType["UPDATE"] = "UPDATE";
    SyncOperationType["DELETE"] = "DELETE";
})(SyncOperationType = exports.SyncOperationType || (exports.SyncOperationType = {}));
var SyncResultStatus;
(function (SyncResultStatus) {
    SyncResultStatus["SUCCESS"] = "success";
    SyncResultStatus["FAILED"] = "failed";
})(SyncResultStatus = exports.SyncResultStatus || (exports.SyncResultStatus = {}));
(0, type_graphql_1.registerEnumType)(SyncOperationType, {
    name: "SyncOperationType",
    description: "Typ der Synchronisations-Operation"
});
(0, type_graphql_1.registerEnumType)(SyncResultStatus, {
    name: "SyncResultStatus",
    description: "Status der Synchronisations-Operation"
});
// Input-Typen für GraphQL
let SyncOperation = class SyncOperation {
};
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    __metadata("design:type", String)
], SyncOperation.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => SyncOperationType),
    __metadata("design:type", String)
], SyncOperation.prototype, "type", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], SyncOperation.prototype, "entityType", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], SyncOperation.prototype, "data", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [String], { nullable: true }),
    __metadata("design:type", Array)
], SyncOperation.prototype, "dependencies", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    __metadata("design:type", Date)
], SyncOperation.prototype, "timestamp", void 0);
SyncOperation = __decorate([
    (0, type_graphql_1.InputType)()
], SyncOperation);
exports.SyncOperation = SyncOperation;
let BatchSyncOptions = class BatchSyncOptions {
};
__decorate([
    (0, type_graphql_1.Field)(() => Number, { nullable: true, defaultValue: 100 }),
    __metadata("design:type", Number)
], BatchSyncOptions.prototype, "batchSize", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Number, { nullable: true, defaultValue: 10 }),
    __metadata("design:type", Number)
], BatchSyncOptions.prototype, "maxConcurrency", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Number, { nullable: true, defaultValue: 30000 }),
    __metadata("design:type", Number)
], BatchSyncOptions.prototype, "timeout", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true, defaultValue: false }),
    __metadata("design:type", Boolean)
], BatchSyncOptions.prototype, "skipValidation", void 0);
BatchSyncOptions = __decorate([
    (0, type_graphql_1.InputType)()
], BatchSyncOptions);
exports.BatchSyncOptions = BatchSyncOptions;
// Output-Typen für GraphQL
let SyncResult = class SyncResult {
};
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    __metadata("design:type", String)
], SyncResult.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => SyncResultStatus),
    __metadata("design:type", String)
], SyncResult.prototype, "status", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    __metadata("design:type", String)
], SyncResult.prototype, "data", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    __metadata("design:type", String)
], SyncResult.prototype, "error", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Number, { nullable: true }),
    __metadata("design:type", Number)
], SyncResult.prototype, "processingTime", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    __metadata("design:type", String)
], SyncResult.prototype, "entityType", void 0);
SyncResult = __decorate([
    (0, type_graphql_1.ObjectType)()
], SyncResult);
exports.SyncResult = SyncResult;
let FailedOperation = class FailedOperation {
};
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID),
    __metadata("design:type", String)
], FailedOperation.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], FailedOperation.prototype, "error", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], FailedOperation.prototype, "entityType", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => SyncOperationType),
    __metadata("design:type", String)
], FailedOperation.prototype, "operationType", void 0);
FailedOperation = __decorate([
    (0, type_graphql_1.ObjectType)()
], FailedOperation);
exports.FailedOperation = FailedOperation;
let BatchSyncResponse = class BatchSyncResponse {
};
__decorate([
    (0, type_graphql_1.Field)(() => [SyncResult]),
    __metadata("design:type", Array)
], BatchSyncResponse.prototype, "successful", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [FailedOperation]),
    __metadata("design:type", Array)
], BatchSyncResponse.prototype, "failed", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Number),
    __metadata("design:type", Number)
], BatchSyncResponse.prototype, "processed", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Number),
    __metadata("design:type", Number)
], BatchSyncResponse.prototype, "duration", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Date),
    __metadata("design:type", Date)
], BatchSyncResponse.prototype, "timestamp", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => Number),
    __metadata("design:type", Number)
], BatchSyncResponse.prototype, "successRate", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => String, { nullable: true }),
    __metadata("design:type", String)
], BatchSyncResponse.prototype, "performanceMetrics", void 0);
BatchSyncResponse = __decorate([
    (0, type_graphql_1.ObjectType)()
], BatchSyncResponse);
exports.BatchSyncResponse = BatchSyncResponse;
