import { InputType, Field } from 'type-graphql';
import { Length, IsEmail } from 'class-validator';

@InputType({ description: "Input data for user registration and login" })
export class UserInput {
    
    @Field()
    @IsEmail()
    email!: string;

    @Field()
    @Length(8, 255, { message: "Password must be between 8 and 255 characters" })
    password!: string;
} 