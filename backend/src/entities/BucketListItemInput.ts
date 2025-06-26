import { Field, InputType, Float } from "type-graphql";

@InputType({ description: "Input data for creating a new Bucket List Item" })
export class BucketListItemInput {
    @Field()
    title!: string;

    @Field({ nullable: true })
    description?: string;
    
    @Field({ nullable: true })
    targetDate?: Date;

    @Field(() => Float, { nullable: true })
    latitude?: number;

    @Field(() => Float, { nullable: true })
    longitude?: number;
} 