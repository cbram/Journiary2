import { Resolver, Query, Mutation, Arg, ObjectType, Field } from 'type-graphql';
import { User } from '../entities/User';
import { AppDataSource } from '../utils/database';
import bcrypt from 'bcryptjs';
import { UserInputError } from 'apollo-server-express';

@ObjectType()
class AdminUserInfo {
    @Field()
    id!: string;

    @Field()
    email!: string;

    @Field()
    passwordHash!: string;

    @Field()
    createdAt!: Date;
}

@ObjectType()
class AdminResponse {
    @Field()
    success!: boolean;

    @Field()
    message!: string;

    @Field(() => [AdminUserInfo])
    users!: AdminUserInfo[];
}

@Resolver()
export class AdminResolver {

    @Query(() => AdminResponse, { description: "Get all users for debugging (production: remove this)" })
    async listUsers(): Promise<AdminResponse> {
        try {
            const userRepository = AppDataSource.getRepository(User);
            const allUsers = await userRepository.find();
            
            const userInfos = allUsers.map(user => ({
                id: user.id,
                email: user.email,
                passwordHash: user.password.substring(0, 20) + "...", // Only show first 20 chars for security
                createdAt: user.createdAt
            }));

            return {
                success: true,
                message: `Found ${allUsers.length} users`,
                users: userInfos
            };
        } catch (error) {
            console.error("Error listing users:", error);
            return {
                success: false,
                message: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
                users: []
            };
        }
    }

    @Mutation(() => AdminResponse, { description: "Reset user password (production: secure this endpoint)" })
    async resetUserPassword(
        @Arg("email") email: string,
        @Arg("newPassword") newPassword: string
    ): Promise<AdminResponse> {
        try {
            if (!email || !newPassword) {
                throw new UserInputError('Email and new password are required.');
            }
            
            if (newPassword.length < 8) {
                throw new UserInputError('Password must be at least 8 characters long.');
            }

            const userRepository = AppDataSource.getRepository(User);
            const user = await userRepository.findOneBy({ email });
            
            if (!user) {
                throw new UserInputError(`User with email ${email} not found.`);
            }

            // Hash the new password
            const hashedPassword = await bcrypt.hash(newPassword, 12);
            
            // Update user password
            user.password = hashedPassword;
            await userRepository.save(user);

            console.log(`🔐 ADMIN: Password reset for user ${email}`);

            return {
                success: true,
                message: `Password reset successful for ${email}`,
                users: [{
                    id: user.id,
                    email: user.email,
                    passwordHash: hashedPassword.substring(0, 20) + "...",
                    createdAt: user.createdAt
                }]
            };
        } catch (error) {
            console.error("Error resetting password:", error);
            return {
                success: false,
                message: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
                users: []
            };
        }
    }

    @Mutation(() => AdminResponse, { description: "Create admin user if not exists" })
    async ensureAdminUser(
        @Arg("email") email: string,
        @Arg("password") password: string
    ): Promise<AdminResponse> {
        try {
            if (!email || !password) {
                throw new UserInputError('Email and password are required.');
            }
            
            if (password.length < 8) {
                throw new UserInputError('Password must be at least 8 characters long.');
            }

            const userRepository = AppDataSource.getRepository(User);
            let user = await userRepository.findOneBy({ email });
            
            if (user) {
                // User exists, update password
                const hashedPassword = await bcrypt.hash(password, 12);
                user.password = hashedPassword;
                await userRepository.save(user);
                
                console.log(`🔐 ADMIN: Updated existing user ${email}`);
                
                return {
                    success: true,
                    message: `Updated existing user ${email}`,
                    users: [{
                        id: user.id,
                        email: user.email,
                        passwordHash: hashedPassword.substring(0, 20) + "...",
                        createdAt: user.createdAt
                    }]
                };
            } else {
                // User doesn't exist, create new one
                const hashedPassword = await bcrypt.hash(password, 12);
                const newUser = userRepository.create({
                    email,
                    password: hashedPassword,
                });
                
                await userRepository.save(newUser);
                console.log(`🔐 ADMIN: Created new user ${email}`);
                
                return {
                    success: true,
                    message: `Created new user ${email}`,
                    users: [{
                        id: newUser.id,
                        email: newUser.email,
                        passwordHash: hashedPassword.substring(0, 20) + "...",
                        createdAt: newUser.createdAt
                    }]
                };
            }
        } catch (error) {
            console.error("Error ensuring admin user:", error);
            return {
                success: false,
                message: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
                users: []
            };
        }
    }
} 