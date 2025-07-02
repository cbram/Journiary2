import { InputType, Field } from 'type-graphql';

@InputType({ description: "Update user data" })
export class UpdateUserInput {
    
    @Field({ nullable: true })
    username?: string;

    @Field({ nullable: true })
    email?: string;

    @Field({ nullable: true })
    firstName?: string;

    @Field({ nullable: true })
    lastName?: string;
} 