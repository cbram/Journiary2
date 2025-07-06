"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.UserResolver = void 0;
const type_graphql_1 = require("type-graphql");
const User_1 = require("../entities/User");
const database_1 = require("../utils/database");
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const apollo_server_express_1 = require("apollo-server-express");
const UserInput_1 = require("../entities/UserInput");
const UpdateUserInput_1 = require("../entities/UpdateUserInput");
let AuthResponse = class AuthResponse {
};
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], AuthResponse.prototype, "token", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => User_1.User),
    __metadata("design:type", User_1.User)
], AuthResponse.prototype, "user", void 0);
AuthResponse = __decorate([
    (0, type_graphql_1.ObjectType)()
], AuthResponse);
let UserResolver = class UserResolver {
    async register(input) {
        const { email, password } = input;
        // 1. Validate input
        if (!email || !password) {
            throw new apollo_server_express_1.UserInputError('Email and password are required.');
        }
        if (password.length < 8) {
            throw new apollo_server_express_1.UserInputError('Password must be at least 8 characters long.');
        }
        // 2. Check if user already exists
        const existingUser = await database_1.AppDataSource.getRepository(User_1.User).findOneBy({ email });
        if (existingUser) {
            throw new apollo_server_express_1.UserInputError('A user with this email address already exists.');
        }
        // 3. Hash password
        const hashedPassword = await bcryptjs_1.default.hash(password, 12);
        // 4. Create and save user
        const user = database_1.AppDataSource.getRepository(User_1.User).create({
            email,
            username: email,
            password: hashedPassword,
        });
        try {
            await database_1.AppDataSource.getRepository(User_1.User).save(user);
            // In a real app, you might want to automatically log the user in here
            // and return a token, but for now, we'll just return the user.
            return user;
        }
        catch (error) {
            console.error("Error creating user:", error);
            throw new Error("Could not create user.");
        }
    }
    async login({ email, password }) {
        // 1. Find user by email
        const user = await database_1.AppDataSource.getRepository(User_1.User).findOneBy({ email });
        if (!user) {
            throw new apollo_server_express_1.UserInputError("Invalid credentials. Please check email and password.");
        }
        // 2. Validate password
        const isValid = await bcryptjs_1.default.compare(password, user.password);
        if (!isValid) {
            throw new apollo_server_express_1.UserInputError("Invalid credentials. Please check email and password.");
        }
        // 3. Generate JWT
        const jwtSecret = process.env.JWT_SECRET;
        if (!jwtSecret) {
            console.error("FATAL ERROR: JWT_SECRET is not defined in environment variables.");
            throw new Error("Internal server error: Could not process login.");
        }
        const payload = { userId: user.id };
        const token = jsonwebtoken_1.default.sign(payload, jwtSecret, {
            expiresIn: '7d', // Token expires in 7 days
        });
        // 4. Return token and user
        return {
            token,
            user,
        };
    }
    async updateUser(input, { userId }) {
        if (!userId) {
            throw new apollo_server_express_1.AuthenticationError("You must be logged in to update your profile.");
        }
        const userRepository = database_1.AppDataSource.getRepository(User_1.User);
        const user = await userRepository.findOneBy({ id: userId });
        if (!user) {
            throw new apollo_server_express_1.AuthenticationError("User not found.");
        }
        // Update only provided fields
        if (input.username !== undefined)
            user.username = input.username;
        if (input.email !== undefined)
            user.email = input.email;
        if (input.firstName !== undefined)
            user.firstName = input.firstName;
        if (input.lastName !== undefined)
            user.lastName = input.lastName;
        return await userRepository.save(user);
    }
    async getCurrentUser({ userId }) {
        if (!userId) {
            return null;
        }
        const user = await database_1.AppDataSource.getRepository(User_1.User).findOneBy({ id: userId });
        if (user) {
            user.updateLastLogin();
            await database_1.AppDataSource.getRepository(User_1.User).save(user);
        }
        return user;
    }
};
exports.UserResolver = UserResolver;
__decorate([
    (0, type_graphql_1.Mutation)(() => User_1.User, { description: "Register a new user" }),
    __param(0, (0, type_graphql_1.Arg)("input")),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [UserInput_1.UserInput]),
    __metadata("design:returntype", Promise)
], UserResolver.prototype, "register", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => AuthResponse, { description: "Log in a user" }),
    __param(0, (0, type_graphql_1.Arg)("input")),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [UserInput_1.UserInput]),
    __metadata("design:returntype", Promise)
], UserResolver.prototype, "login", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => User_1.User, { description: "Update user profile" }),
    __param(0, (0, type_graphql_1.Arg)("input")),
    __param(1, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [UpdateUserInput_1.UpdateUserInput, Object]),
    __metadata("design:returntype", Promise)
], UserResolver.prototype, "updateUser", null);
__decorate([
    (0, type_graphql_1.Query)(() => User_1.User, { nullable: true, description: "Get current user profile" }),
    __param(0, (0, type_graphql_1.Ctx)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], UserResolver.prototype, "getCurrentUser", null);
exports.UserResolver = UserResolver = __decorate([
    (0, type_graphql_1.Resolver)(User_1.User)
], UserResolver);
