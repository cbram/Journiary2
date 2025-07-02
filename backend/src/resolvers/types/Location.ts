import { Field, Float, ObjectType } from "type-graphql";

@ObjectType()
export class Location {
    @Field(() => Float)
    latitude!: number;

    @Field(() => Float)
    longitude!: number;

    @Field({ nullable: true })
    name?: string;
} 