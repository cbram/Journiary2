import { InputType, Field, ID, Float } from 'type-graphql';

@InputType({ description: "Bulk update memory data" })
export class BulkMemoryUpdateInput {
    
    @Field(() => ID)
    id!: string;

    @Field({ nullable: true })
    title?: string;

    @Field({ nullable: true })
    content?: string;

    @Field({ nullable: true })
    date?: Date;

    @Field(() => Float, { nullable: true })
    latitude?: number;

    @Field(() => Float, { nullable: true })
    longitude?: number;

    @Field({ nullable: true })
    address?: string;

    @Field(() => ID, { nullable: true })
    tripId?: string;

    @Field()
    updatedAt!: Date;
} 