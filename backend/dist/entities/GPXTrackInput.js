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
exports.GPXTrackInput = void 0;
const type_graphql_1 = require("type-graphql");
let GPXTrackInput = class GPXTrackInput {
};
exports.GPXTrackInput = GPXTrackInput;
__decorate([
    (0, type_graphql_1.Field)({ description: "The name of the GPX track" }),
    __metadata("design:type", String)
], GPXTrackInput.prototype, "name", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true, description: "The name of the uploaded GPX file in the object storage" }),
    __metadata("design:type", String)
], GPXTrackInput.prototype, "gpxFileObjectName", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    __metadata("design:type", String)
], GPXTrackInput.prototype, "originalFilename", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID, { description: "The ID of the trip this GPX track belongs to" }),
    __metadata("design:type", String)
], GPXTrackInput.prototype, "tripId", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => type_graphql_1.ID, { nullable: true, description: "Optional ID of the memory this GPX track is associated with" }),
    __metadata("design:type", String)
], GPXTrackInput.prototype, "memoryId", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    __metadata("design:type", String)
], GPXTrackInput.prototype, "creator", void 0);
__decorate([
    (0, type_graphql_1.Field)({ nullable: true }),
    __metadata("design:type", String)
], GPXTrackInput.prototype, "trackType", void 0);
exports.GPXTrackInput = GPXTrackInput = __decorate([
    (0, type_graphql_1.InputType)({ description: "Input data for creating a new GPXTrack" })
], GPXTrackInput);
