import { InputType, Field, Float } from "type-graphql";
import { BucketListItem } from "./BucketListItem";

@InputType()
export class BucketListItemInput implements Partial<BucketListItem> {
    @Field()
    name!: string;

    @Field({ nullable: true })
    country?: string;

    @Field({ nullable: true })
    region?: string;

    @Field({ nullable: true })
    type?: string;

    @Field(() => Float, { nullable: true })
    latitude1?: number;

    @Field(() => Float, { nullable: true })
    longitude1?: number;

    @Field(() => Float, { nullable: true })
    latitude2?: number;

    @Field(() => Float, { nullable: true })
    longitude2?: number;
    
    @Field({ nullable: true })
    isDone?: boolean;
} 