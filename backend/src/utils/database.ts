import "reflect-metadata";
import { DataSource } from "typeorm";
import { Trip } from "../entities/Trip";
import { Memory } from "../entities/Memory";
import { MediaItem } from "../entities/MediaItem";
import { RoutePoint } from "../entities/RoutePoint";
import { Tag } from "../entities/Tag";
import { TagCategory } from "../entities/TagCategory";
import { BucketListItem } from "../entities/BucketListItem";
import { GPXTrack } from "../entities/GPXTrack";
import { TrackSegment } from "../entities/TrackSegment";
import { TrackMetadata } from "../entities/TrackMetadata";
import { User } from "../entities/User";
import { TripMembership } from "../entities/TripMembership";

const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
    throw new Error("DATABASE_URL environment variable is not set.");
}

export const AppDataSource = new DataSource({
    type: "postgres",
    url: databaseUrl,
    synchronize: true, // DEV only: automatically creates the database schema on every application launch
    logging: true,
    entities: [
        Trip, 
        Memory, 
        MediaItem, 
        RoutePoint, 
        Tag, 
        TagCategory, 
        BucketListItem, 
        GPXTrack, 
        TrackSegment, 
        TrackMetadata,
        User,
        TripMembership
    ],
    subscribers: [],
    migrations: [],
}); 