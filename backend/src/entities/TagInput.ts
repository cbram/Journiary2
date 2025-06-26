import { Field, InputType, ID } from "type-graphql";
import { Tag } from "./Tag";

@InputType({ description: "Input data for creating a new Tag" })
export class TagInput implements Partial<Tag> {
    @Field()
    name!: string;

    @Field({ nullable: true })
    emoji?: string;

    @Field({ nullable: true })
    color?: string;

    @Field({ nullable: true })
    tagDescription?: string;

    @Field(() => ID, { nullable: true, description: "The ID of the category this tag belongs to" })
    categoryId?: string;
} 