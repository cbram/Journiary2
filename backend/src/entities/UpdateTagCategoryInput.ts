import { InputType, Field } from 'type-graphql';

@InputType({ description: "Update tag category data" })
export class UpdateTagCategoryInput {
    
    @Field({ nullable: true })
    name?: string;

    @Field({ nullable: true })
    color?: string;

    @Field({ nullable: true })
    icon?: string;
} 