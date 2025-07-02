import { InputType, Field, ID } from 'type-graphql';

@InputType({ description: "Bulk update trip data" })
export class BulkTripUpdateInput {
    
    @Field(() => ID)
    id!: string;

    @Field({ nullable: true })
    name?: string;

    @Field({ nullable: true })
    description?: string;

    @Field({ nullable: true })
    startDate?: Date;

    @Field({ nullable: true })
    endDate?: Date;

    @Field({ nullable: true })
    isActive?: boolean;

    @Field()
    updatedAt!: Date;
} 