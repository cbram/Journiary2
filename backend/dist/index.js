"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("reflect-metadata");
const apollo_server_express_1 = require("apollo-server-express");
const express_1 = __importDefault(require("express"));
const http_1 = __importDefault(require("http"));
const cors_1 = __importDefault(require("cors"));
const type_graphql_1 = require("type-graphql");
const TripResolver_1 = require("./resolvers/TripResolver");
const MemoryResolver_1 = require("./resolvers/MemoryResolver");
const MediaItemResolver_1 = require("./resolvers/MediaItemResolver");
const RoutePointResolver_1 = require("./resolvers/RoutePointResolver");
const database_1 = require("./utils/database");
const minio_1 = require("./utils/minio"); // Import minio helper
require("dotenv/config");
const HelloWorldResolver_1 = require("./resolvers/HelloWorldResolver");
const TagResolver_1 = require("./resolvers/TagResolver");
const TagCategoryResolver_1 = require("./resolvers/TagCategoryResolver");
const BucketListItemResolver_1 = require("./resolvers/BucketListItemResolver");
const GPXResolver_1 = require("./resolvers/GPXResolver");
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const UserResolver_1 = require("./resolvers/UserResolver");
const AdminResolver_1 = require("./resolvers/AdminResolver");
const SyncResolver_1 = require("./resolvers/SyncResolver");
async function startServer() {
    try {
        await database_1.AppDataSource.initialize();
        console.log("✅ Database connection initialized");
    }
    catch (error) {
        console.error("❌ Error during Data Source initialization", error);
        process.exit(1);
    }
    // Ensure MinIO bucket exists before starting the server
    await (0, minio_1.ensureBucketExists)();
    const app = (0, express_1.default)();
    const httpServer = http_1.default.createServer(app);
    const apolloServer = new apollo_server_express_1.ApolloServer({
        schema: await (0, type_graphql_1.buildSchema)({
            resolvers: [
                HelloWorldResolver_1.HelloWorldResolver,
                TripResolver_1.TripResolver,
                MemoryResolver_1.MemoryResolver,
                MediaItemResolver_1.MediaItemResolver,
                RoutePointResolver_1.RoutePointResolver,
                TagResolver_1.TagResolver,
                TagCategoryResolver_1.TagCategoryResolver,
                BucketListItemResolver_1.BucketListItemResolver,
                GPXResolver_1.GPXResolver,
                UserResolver_1.UserResolver,
                AdminResolver_1.AdminResolver,
                SyncResolver_1.SyncResolver
            ],
            validate: false,
        }),
        context: ({ req, res }) => {
            const context = { req, res };
            const authHeader = req.headers.authorization;
            if (authHeader) {
                const token = authHeader.split(' ')[1];
                console.log('🔍 Backend received token:', token?.substring(0, 20) + '...');
                console.log('🔍 Full token:', token);
                if (token) {
                    try {
                        console.log('🔐 Attempting to verify token with secret: "your-super-secret-key"');
                        const decoded = jsonwebtoken_1.default.verify(token, "your-super-secret-key");
                        console.log('✅ JWT verified successfully, userId:', decoded.userId);
                        context.userId = decoded.userId;
                    }
                    catch (err) {
                        console.log('❌ JWT Verification failed:', err.message);
                        console.log('❌ JWT Error details:', err);
                        // No fallback - only accept valid tokens
                    }
                }
                else {
                    console.log('❌ No token found in Authorization header');
                }
            }
            return context;
        },
    });
    await apolloServer.start();
    app.use((0, cors_1.default)());
    app.use(express_1.default.json());
    apolloServer.applyMiddleware({ app: app, path: '/graphql' });
    const PORT = process.env.PORT || 4000;
    httpServer.listen({ port: PORT }, () => {
        console.log(`🚀 Server ready at http://localhost:${PORT}/graphql`);
    });
}
startServer();
