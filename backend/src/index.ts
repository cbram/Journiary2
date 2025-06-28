import "reflect-metadata";
import { ApolloServer } from 'apollo-server-express';
import express from 'express';
import http from 'http';
import cors from 'cors';
import { buildSchema } from 'type-graphql';
import { TripResolver } from './resolvers/TripResolver';
import { MemoryResolver } from './resolvers/MemoryResolver';
import { MediaItemResolver } from './resolvers/MediaItemResolver';
import { RoutePointResolver } from './resolvers/RoutePointResolver';
import { AppDataSource } from './utils/database';
import { ensureBucketExists } from './utils/minio'; // Import minio helper
import "dotenv/config";
import { HelloWorldResolver } from "./resolvers/HelloWorldResolver";
import { TagResolver } from "./resolvers/TagResolver";
import { TagCategoryResolver } from "./resolvers/TagCategoryResolver";
import { BucketListItemResolver } from "./resolvers/BucketListItemResolver";
import { GPXResolver } from "./resolvers/GPXResolver";
import jwt from 'jsonwebtoken';
import { UserResolver } from "./resolvers/UserResolver";

export interface MyContext {
    req: any;
    res: any;
    userId?: string;
}

async function startServer() {
    try {
        await AppDataSource.initialize();
        console.log("✅ Database connection initialized");
    } catch (error) {
        console.error("❌ Error during Data Source initialization", error);
        process.exit(1);
    }

    // Ensure MinIO bucket exists before starting the server
    await ensureBucketExists();

    const app = express();
    const httpServer = http.createServer(app);

    const apolloServer = new ApolloServer({
        schema: await buildSchema({
            resolvers: [
                HelloWorldResolver,
                TripResolver,
                MemoryResolver,
                MediaItemResolver,
                RoutePointResolver,
                TagResolver,
                TagCategoryResolver,
                BucketListItemResolver,
                GPXResolver,
                UserResolver
            ],
            validate: false,
        }),
        context: ({ req, res }): MyContext => {
            const context: MyContext = { req, res };
            const authHeader = req.headers.authorization;
            
            // 🐛 DEBUG: Log authentication attempts
            console.log('🔐 Auth Header:', authHeader ? 'Present' : 'Missing');
            
            if (authHeader) {
                const token = authHeader.split(' ')[1];
                console.log('🔑 Token extracted:', token ? `${token.substring(0, 20)}...` : 'Empty');
                
                if (token) {
                    try {
                        const decoded = jwt.verify(token, "your-super-secret-key") as { userId: string };
                        context.userId = decoded.userId;
                        console.log('✅ JWT Verified, userId:', decoded.userId);
                    } catch (err: any) {
                        console.log('❌ JWT Verification failed:', err.message);
                    }
                }
            }
            
            console.log('📝 Context userId:', context.userId || 'undefined');
            return context;
        },
    });

    await apolloServer.start();

    app.use(cors());
    app.use(express.json());

    apolloServer.applyMiddleware({ app: app as any, path: '/graphql' });

    const PORT = process.env.PORT || 4000;
    httpServer.listen({ port: PORT }, () => {
        console.log(`🚀 Server ready at http://localhost:${PORT}/graphql`);
    });
}

startServer(); 