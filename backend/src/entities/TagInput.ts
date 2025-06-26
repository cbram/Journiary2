import { Field, InputType, ID } from "type-graphql";

@InputType({ description: "Input data for creating a new Tag" })
export class TagInput {
    @Field()
    name!: string;

    @Field({ nullable: true })
    emoji?: string;

    @Field({ nullable: true })
    color?: string;

    @Field(() => ID, { nullable: true, description: "The ID of the category this tag belongs to" })
    categoryId?: string;
} 