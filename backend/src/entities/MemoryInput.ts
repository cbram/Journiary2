import { InputType, Field, ID, Float } from 'type-graphql';
import { Memory } from './Memory';
import { LocationInput } from './LocationInput';

@InputType({ description: "New memory data" })
export class MemoryInput implements Partial<Memory> {
    
    @Field()
    title!: string;

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

    @Field(() => LocationInput, { nullable: true })
    location?: LocationInput;

    @Field(() => ID, { description: "The ID of the trip this memory belongs to" })
    tripId!: string;

    @Field(() => [ID], { nullable: true, description: "A list of Tag IDs to associate with this memory" })
    tagIds?: string[];
} 