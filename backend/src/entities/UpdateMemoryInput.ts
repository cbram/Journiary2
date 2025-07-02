import { InputType, Field, Float } from 'type-graphql';

@InputType({ description: "Update memory data" })
export class UpdateMemoryInput {
    
    @Field({ nullable: true })
    title?: string;

    @Field({ nullable: true })
    text?: string;
    
    @Field({ nullable: true })
    timestamp?: Date;

    @Field(() => Float, { nullable: true })
    latitude?: number;

    @Field(() => Float, { nullable: true })
    longitude?: number;

    @Field({ nullable: true })
    locationName?: string;

    @Field(() => [String], { nullable: true, description: "A list of Tag IDs to associate with this memory" })
    tagIds?: string[];
} 