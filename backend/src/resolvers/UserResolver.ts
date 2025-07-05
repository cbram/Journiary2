import { Resolver, Query, Mutation, Arg, Ctx, ObjectType, Field } from 'type-graphql';
import { User } from '../entities/User';
import { AppDataSource } from '../utils/database';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { UserInputError, AuthenticationError } from 'apollo-server-express';
import { UserInput } from '../entities/UserInput';
import { UpdateUserInput } from '../entities/UpdateUserInput';
import { MyContext } from '..';

@ObjectType()
class AuthResponse {
    @Field()
    token!: string;

    @Field(() => User)
    user!: User;
}

@Resolver(User)
export class UserResolver {

    @Mutation(() => User, { description: "Register a new user" })
    async register(@Arg("input") input: UserInput): Promise<User> {
        const { email, password } = input;

        // 1. Validate input
        if (!email || !password) {
            throw new UserInputError('Email and password are required.');
        }
        if (password.length < 8) {
            throw new UserInputError('Password must be at least 8 characters long.');
        }

        // 2. Check if user already exists
        const existingUser = await AppDataSource.getRepository(User).findOneBy({ email });
        if (existingUser) {
            throw new UserInputError('A user with this email address already exists.');
        }

        // 3. Hash password
        const hashedPassword = await bcrypt.hash(password, 12);

        // 4. Create and save user
        const user = AppDataSource.getRepository(User).create({
            email,
            username: email,
            password: hashedPassword,
        });

        try {
            await AppDataSource.getRepository(User).save(user);
            // In a real app, you might want to automatically log the user in here
            // and return a token, but for now, we'll just return the user.
            return user;
        } catch (error) {
            console.error("Error creating user:", error);
            throw new Error("Could not create user.");
        }
    }

    @Mutation(() => AuthResponse, { description: "Log in a user" })
    async login(@Arg("input") { email, password }: UserInput): Promise<AuthResponse> {
        // 1. Find user by email
        const user = await AppDataSource.getRepository(User).findOneBy({ email });
        if (!user) {
            throw new UserInputError("Invalid credentials. Please check email and password.");
        }

        // 2. Validate password
        const isValid = await bcrypt.compare(password, user.password);
        if (!isValid) {
            throw new UserInputError("Invalid credentials. Please check email and password.");
        }

        // 3. Generate JWT
        const jwtSecret = process.env.JWT_SECRET;
        if (!jwtSecret) {
            console.error("FATAL ERROR: JWT_SECRET is not defined in environment variables.");
            throw new Error("Internal server error: Could not process login.");
        }
        
        const payload = { userId: user.id };
        const token = jwt.sign(payload, jwtSecret, {
            expiresIn: '7d', // Token expires in 7 days
        });

        // 4. Return token and user
        return {
            token,
            user,
        };
    }

    @Mutation(() => User, { description: "Update user profile" })
    async updateUser(
        @Arg("input") input: UpdateUserInput,
        @Ctx() { userId }: MyContext
    ): Promise<User> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to update your profile.");
        }

        const userRepository = AppDataSource.getRepository(User);
        const user = await userRepository.findOneBy({ id: userId });

        if (!user) {
            throw new AuthenticationError("User not found.");
        }

        // Update only provided fields
        if (input.username !== undefined) user.username = input.username;
        if (input.email !== undefined) user.email = input.email;
        if (input.firstName !== undefined) user.firstName = input.firstName;
        if (input.lastName !== undefined) user.lastName = input.lastName;

        return await userRepository.save(user);
    }

    @Query(() => User, { nullable: true, description: "Get current user profile" })
    async getCurrentUser(@Ctx() { userId }: MyContext): Promise<User | null> {
        if (!userId) {
            return null;
        }

        const user = await AppDataSource.getRepository(User).findOneBy({ id: userId });

        if (user) {
            user.updateLastLogin();
            await AppDataSource.getRepository(User).save(user);
        }

        return user;
    }
} 