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
                GPXResolver
            ],
            validate: false,
        }),
        context: ({ req, res }) => ({ req, res }),
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