import { Resolver, Query, Mutation, Arg, FieldResolver, Root, ID } from 'type-graphql';
import { Trip } from '../entities/Trip';
import { TripInput } from '../entities/TripInput';
import { UpdateTripInput } from '../entities/UpdateTripInput';
import { Memory } from '../entities/Memory';
import { AppDataSource } from '../utils/database';

@Resolver(Trip)
export class TripResolver {

    @Query(() => [Trip], { description: "Get all trips" })
    async trips(): Promise<Trip[]> {
        try {
            const result = await AppDataSource.getRepository(Trip).find();
            return result;
        } catch (error) {
            console.error("Error fetching trips:", error);
            throw new Error("Could not fetch trips.");
        }
    }

    @Mutation(() => Trip, { description: "Create a new trip" })
    async createTrip(@Arg("input") input: TripInput): Promise<Trip> {
        const trip = AppDataSource.getRepository(Trip).create(input);
        try {
            await AppDataSource.getRepository(Trip).save(trip);
            return trip;
        } catch (error) {
            console.error("Error creating trip:", error);
            throw new Error("Could not create trip.");
        }
    }

    @Mutation(() => Trip, { description: "Update an existing trip" })
    async updateTrip(
        @Arg("id", () => ID) id: string,
        @Arg("input") input: UpdateTripInput
    ): Promise<Trip | null> {
        try {
            const trip = await AppDataSource.getRepository(Trip).findOne({ where: { id } });
            if (!trip) {
                return null;
            }
            Object.assign(trip, input);
            await AppDataSource.getRepository(Trip).save(trip);
            return trip;
        } catch (error) {
            console.error("Error updating trip:", error);
            throw new Error("Could not update trip.");
        }
    }

    @Mutation(() => Boolean, { description: "Delete a trip" })
    async deleteTrip(@Arg("id", () => ID) id: string): Promise<boolean> {
        try {
            const deleteResult = await AppDataSource.getRepository(Trip).delete(id);
            return deleteResult.affected === 1;
        } catch (error) {
            console.error("Error deleting trip:", error);
            throw new Error("Could not delete trip.");
        }
    }

    @FieldResolver(() => [Memory])
    async memories(@Root() trip: Trip): Promise<Memory[]> {
        try {
            const memoryRepository = AppDataSource.getRepository(Memory);
            return await memoryRepository.find({ where: { trip: { id: trip.id } } });
        } catch (error) {
            console.error(`Error fetching memories for trip ${trip.id}:`, error);
            throw new Error("Could not fetch memories for the trip.");
        }
    }
}