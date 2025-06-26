import { Arg, Ctx, Mutation, Query, Resolver, ID } from "type-graphql";
import { RoutePoint } from "../entities/RoutePoint";
import { RoutePointInput } from "../entities/RoutePointInput";
import { AppDataSource } from "../utils/database";
import { Trip } from "../entities/Trip";
import { In } from "typeorm";
import { MyContext } from "..";
import { AuthenticationError, UserInputError } from "apollo-server-express";
import { checkTripAccess } from '../utils/auth';
import { TripRole } from '../entities/TripMembership';

@Resolver(RoutePoint)
export class RoutePointResolver {
    @Query(() => [RoutePoint])
    async routePoints(
        @Arg("tripId", () => ID) tripId: string,
        @Ctx() { userId }: MyContext
    ): Promise<RoutePoint[]> {
        if (!userId) return [];
        
        const hasAccess = await checkTripAccess(userId, tripId, TripRole.VIEWER);
        if (!hasAccess) return [];

        return AppDataSource.getRepository(RoutePoint).findBy({ trip: { id: tripId } });
    }

    @Mutation(() => [RoutePoint])
    async createRoutePoints(
        @Arg("tripId", () => ID) tripId: string,
        @Arg("points", () => [RoutePointInput]) points: RoutePointInput[],
        @Ctx() { userId }: MyContext
    ): Promise<RoutePoint[]> {
        if (!userId) throw new AuthenticationError("You must be logged in.");

        const hasAccess = await checkTripAccess(userId, tripId, TripRole.EDITOR);
        if (!hasAccess) {
            throw new UserInputError(`You don't have permission to add route points to trip ${tripId}.`);
        }
        
        const trip = await AppDataSource.getRepository(Trip).findOneBy({ id: tripId });
        
        const routePointRepository = AppDataSource.getRepository(RoutePoint);
        const newRoutePoints = points.map(point => routePointRepository.create({
            ...point,
            trip: trip!
        }));

        return await routePointRepository.save(newRoutePoints);
    }
} 