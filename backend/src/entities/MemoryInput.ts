import { InputType, Field, ID, Float } from 'type-graphql';
import { Memory } from './Memory';

@InputType({ description: "New memory data" })
export class MemoryInput implements Partial<Memory> {
    
    @Field()
    title!: string;

    @Field({ nullable: true })
    text?: string;
    
    @Field()
    timestamp!: Date;

    @Field(() => Float)
    latitude!: number;

    @Field(() => Float)
    longitude!: number;

    @Field({ nullable: true })
    locationName?: string;

    @Field(() => ID, { description: "The ID of the trip this memory belongs to" })
    tripId!: string;

    @Field(() => [ID], { nullable: true, description: "A list of Tag IDs to associate with this memory" })
    tagIds?: string[];
} 