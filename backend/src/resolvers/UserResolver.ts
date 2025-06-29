import { Resolver, Query, Mutation, Arg, Ctx, ObjectType, Field } from 'type-graphql';
import { User } from '../entities/User';
import { AppDataSource } from '../utils/database';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { UserInputError } from 'apollo-server-express';
import { UserInput } from '../entities/UserInput'; // We'll create this next

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
        // TODO: Move JWT_SECRET to a secure environment variable!
        console.log("🔐 JWT DEBUG - Creating token for user:", user.id, "email:", user.email);
        const payload = { userId: user.id };
        console.log("🔐 JWT DEBUG - Payload:", JSON.stringify(payload));
        
        const token = jwt.sign(payload, "your-super-secret-key", {
            expiresIn: '7d', // Token expires in 7 days
        });
        
        console.log("🔐 JWT DEBUG - Generated token:", token.substring(0, 50) + "...");
        
        // Verify token immediately to test
        try {
            const decoded = jwt.verify(token, "your-super-secret-key") as any;
            console.log("🔐 JWT DEBUG - Token verification successful:", JSON.stringify(decoded));
        } catch (error) {
            console.log("🔐 JWT DEBUG - Token verification FAILED:", error);
        }

        // 4. Return token and user
        return {
            token,
            user,
        };
    }
} 