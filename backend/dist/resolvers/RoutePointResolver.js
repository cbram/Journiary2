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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RoutePointResolver = void 0;
const type_graphql_1 = require("type-graphql");
const RoutePoint_1 = require("../entities/RoutePoint");
const RoutePointInput_1 = require("../entities/RoutePointInput");
const database_1 = require("../utils/database");
const Trip_1 = require("../entities/Trip");
const apollo_server_express_1 = require("apollo-server-express");
const auth_1 = require("../utils/auth");
const TripMembership_1 = require("../entities/TripMembership");
let RoutePointResolver = class RoutePointResolver {
    async routePoints(tripId, { userId }) {
        if (!userId)
            return [];
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, tripId, TripMembership_1.TripRole.VIEWER);
        if (!hasAccess)
            return [];
        return database_1.AppDataSource.getRepository(RoutePoint_1.RoutePoint).findBy({ trip: { id: tripId } });
    }
    async createRoutePoints(tripId, points, { userId }) {
        if (!userId)
            throw new apollo_server_express_1.AuthenticationError("You must be logged in.");
        const hasAccess = await (0, auth_1.checkTripAccess)(userId, tripId, TripMembership_1.TripRole.EDITOR);
        if (!hasAccess) {
            throw new apollo_server_express_1.UserInputError(`You don't have permission to add route points to trip ${tripId}.`);
        }
        const trip = await database_1.AppDataSource.getRepository(Trip_1.Trip).findOneBy({ id: tripId });
        const routePointRepository = database_1.AppDataSource.getRepository(RoutePoint_1.RoutePoint);
        const newRoutePoints = points.map(point => routePointRepository.create({
            ...point,
            trip: trip
        }));
        return await routePointRepository.save(newRoutePoints);
    }
};
__decorate([
    (0, type_graphql_1.Query)(() => [RoutePoint_1.RoutePoint]),
    __param(0, (0, type_graphql_1.Arg)("tripId", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", Promise)
], RoutePointResolver.prototype, "routePoints", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => [RoutePoint_1.RoutePoint]),
    __param(0, (0, type_graphql_1.Arg)("tripId", () => type_graphql_1.ID)),
    __param(1, (0, type_graphql_1.Arg)("points", () => [RoutePointInput_1.RoutePointInput])),
    __param(2, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Array, Object]),
    __metadata("design:returntype", Promise)
], RoutePointResolver.prototype, "createRoutePoints", null);
RoutePointResolver = __decorate([
    (0, type_graphql_1.Resolver)(RoutePoint_1.RoutePoint)
], RoutePointResolver);
exports.RoutePointResolver = RoutePointResolver;
