import { InputType, Field, Float } from 'type-graphql';

@InputType({ description: "Data to update an existing trip" })
export class UpdateTripInput {
    
    @Field({ nullable: true })
    name?: string;

    @Field({ nullable: true })
    tripDescription?: string;

    @Field({ nullable: true })
    travelCompanions?: string;

    @Field({ nullable: true })
    visitedCountries?: string;
    
    @Field({ nullable: true })
    startDate?: Date;

    @Field({ nullable: true })
    endDate?: Date;

    @Field({ nullable: true })
    isActive?: boolean;

    @Field(() => Float, { nullable: true })
    totalDistance?: number;

    @Field({ nullable: true })
    gpsTrackingEnabled?: boolean;
} 