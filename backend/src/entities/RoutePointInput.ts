import { InputType, Field, Float, ID } from "type-graphql";

@InputType({ description: "Input data to create a new RoutePoint" })
export class RoutePointInput {
    @Field(() => Float)
    latitude!: number;

    @Field(() => Float)
    longitude!: number;

    @Field(() => Float, { nullable: true })
    altitude?: number;

    @Field(() => Float, { nullable: true })
    speed?: number;

    @Field()
    timestamp!: Date;

    @Field(() => ID, { description: "The ID of the trip this route point belongs to" })
    tripId!: string;
} 