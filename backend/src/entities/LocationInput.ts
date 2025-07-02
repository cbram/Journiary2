import { Field, Float, InputType } from "type-graphql";

@InputType({ description: "Represents a geographic location (latitude/longitude) plus optional name" })
export class LocationInput {
    @Field(() => Float)
    latitude!: number;

    @Field(() => Float)
    longitude!: number;

    @Field({ nullable: true })
    name?: string;
} 