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
exports.AdminResolver = void 0;
const type_graphql_1 = require("type-graphql");
const User_1 = require("../entities/User");
const database_1 = require("../utils/database");
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const apollo_server_express_1 = require("apollo-server-express");
let AdminUserInfo = class AdminUserInfo {
};
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], AdminUserInfo.prototype, "id", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], AdminUserInfo.prototype, "email", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], AdminUserInfo.prototype, "passwordHash", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", Date)
], AdminUserInfo.prototype, "createdAt", void 0);
AdminUserInfo = __decorate([
    (0, type_graphql_1.ObjectType)()
], AdminUserInfo);
let AdminResponse = class AdminResponse {
};
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", Boolean)
], AdminResponse.prototype, "success", void 0);
__decorate([
    (0, type_graphql_1.Field)(),
    __metadata("design:type", String)
], AdminResponse.prototype, "message", void 0);
__decorate([
    (0, type_graphql_1.Field)(() => [AdminUserInfo]),
    __metadata("design:type", Array)
], AdminResponse.prototype, "users", void 0);
AdminResponse = __decorate([
    (0, type_graphql_1.ObjectType)()
], AdminResponse);
let AdminResolver = class AdminResolver {
    async listUsers() {
        try {
            const userRepository = database_1.AppDataSource.getRepository(User_1.User);
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
        }
        catch (error) {
            console.error("Error listing users:", error);
            return {
                success: false,
                message: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
                users: []
            };
        }
    }
    async resetUserPassword(email, newPassword) {
        try {
            if (!email || !newPassword) {
                throw new apollo_server_express_1.UserInputError('Email and new password are required.');
            }
            if (newPassword.length < 8) {
                throw new apollo_server_express_1.UserInputError('Password must be at least 8 characters long.');
            }
            const userRepository = database_1.AppDataSource.getRepository(User_1.User);
            const user = await userRepository.findOneBy({ email });
            if (!user) {
                throw new apollo_server_express_1.UserInputError(`User with email ${email} not found.`);
            }
            // Hash the new password
            const hashedPassword = await bcryptjs_1.default.hash(newPassword, 12);
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
        }
        catch (error) {
            console.error("Error resetting password:", error);
            return {
                success: false,
                message: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
                users: []
            };
        }
    }
    async ensureAdminUser(email, password) {
        try {
            if (!email || !password) {
                throw new apollo_server_express_1.UserInputError('Email and password are required.');
            }
            if (password.length < 8) {
                throw new apollo_server_express_1.UserInputError('Password must be at least 8 characters long.');
            }
            const userRepository = database_1.AppDataSource.getRepository(User_1.User);
            let user = await userRepository.findOneBy({ email });
            if (user) {
                // User exists, update password
                const hashedPassword = await bcryptjs_1.default.hash(password, 12);
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
            }
            else {
                // User doesn't exist, create new one
                const hashedPassword = await bcryptjs_1.default.hash(password, 12);
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
        }
        catch (error) {
            console.error("Error ensuring admin user:", error);
            return {
                success: false,
                message: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
                users: []
            };
        }
    }
};
exports.AdminResolver = AdminResolver;
__decorate([
    (0, type_graphql_1.Query)(() => AdminResponse, { description: "Get all users for debugging (production: remove this)" }),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], AdminResolver.prototype, "listUsers", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => AdminResponse, { description: "Reset user password (production: secure this endpoint)" }),
    __param(0, (0, type_graphql_1.Arg)("email")),
    __param(1, (0, type_graphql_1.Arg)("newPassword")),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], AdminResolver.prototype, "resetUserPassword", null);
__decorate([
    (0, type_graphql_1.Mutation)(() => AdminResponse, { description: "Create admin user if not exists" }),
    __param(0, (0, type_graphql_1.Arg)("email")),
    __param(1, (0, type_graphql_1.Arg)("password")),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], AdminResolver.prototype, "ensureAdminUser", null);
exports.AdminResolver = AdminResolver = __decorate([
    (0, type_graphql_1.Resolver)()
], AdminResolver);
