import { Arg, Mutation, Query, Resolver, ID } from "type-graphql";
import { RoutePoint } from "../entities/RoutePoint";
import { RoutePointInput } from "../entities/RoutePointInput";
import { AppDataSource } from "../utils/database";
import { Trip } from "../entities/Trip";
import { In } from "typeorm";

@Resolver(RoutePoint)
export class RoutePointResolver {
    @Query(() => [RoutePoint])
    async routePoints(@Arg("tripId", () => ID) tripId: string): Promise<RoutePoint[]> {
        return AppDataSource.getRepository(RoutePoint).findBy({ trip: { id: tripId } });
    }

    @Mutation(() => [RoutePoint])
    async createRoutePoints(
        @Arg("tripId", () => ID) tripId: string,
        @Arg("points", () => [RoutePointInput]) points: RoutePointInput[]
    ): Promise<RoutePoint[]> {
        const routePointRepository = AppDataSource.getRepository(RoutePoint);
        
        const trip = await AppDataSource.getRepository(Trip).findOneBy({ id: tripId });
        if (!trip) {
            throw new Error(`Trip with ID ${tripId} not found.`);
        }

        const newRoutePoints = points.map(point => routePointRepository.create({
            ...point,
            trip: trip
        }));

        return await routePointRepository.save(newRoutePoints);
    }
} 