import { InputType, Field, Float } from 'type-graphql';

@InputType({ description: "Update memory data" })
export class UpdateMemoryInput {
    
    @Field({ nullable: true })
    title?: string;

    @Field({ name: "content", nullable: true })
    text?: string;
    
    @Field({ name: "date", nullable: true })
    timestamp?: Date;

    @Field(() => Float, { nullable: true })
    latitude?: number;

    @Field(() => Float, { nullable: true })
    longitude?: number;

    @Field({ name: "address", nullable: true })
    locationName?: string;

    @Field(() => [String], { nullable: true, description: "A list of Tag IDs to associate with this memory" })
    tagIds?: string[];
} 