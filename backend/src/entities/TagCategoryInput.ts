import { Field, InputType } from "type-graphql";

@InputType({ description: "Input data for creating a new Tag Category" })
export class TagCategoryInput {
    @Field()
    name!: string;

    @Field({ nullable: true })
    emoji?: string;

    @Field({ nullable: true })
    color?: string;
} 