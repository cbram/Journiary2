import { InputType, Field, Float } from 'type-graphql';
import { Trip } from './Trip';

@InputType({ description: "New trip data" })
export class TripInput implements Partial<Trip> {
    
    @Field()
    name!: string;

    @Field({ nullable: true })
    tripDescription?: string;

    @Field({ nullable: true })
    travelCompanions?: string;

    @Field({ nullable: true })
    visitedCountries?: string;
    
    @Field()
    startDate!: Date;

    @Field({ nullable: true })
    endDate?: Date;

    @Field({ defaultValue: false })
    isActive!: boolean;

    @Field(() => Float, { defaultValue: 0.0 })
    totalDistance!: number;

    @Field({ defaultValue: true })
    gpsTrackingEnabled!: boolean;
} 