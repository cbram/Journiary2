import { InputType, Field, ID } from 'type-graphql';

@InputType({ description: "Update tag data" })
export class UpdateTagInput {
    
    @Field({ nullable: true })
    name?: string;

    @Field({ nullable: true })
    color?: string;

    @Field(() => ID, { nullable: true })
    categoryId?: string;
} 