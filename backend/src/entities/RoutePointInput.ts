import { InputType, Field, Float } from "type-graphql";

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
} 