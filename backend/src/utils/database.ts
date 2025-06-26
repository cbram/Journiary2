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

// Hardcode the connection string to bypass environment variable issues on Unraid
const connectionString = "postgresql://travelcompanion:travelcompanion@db:5432/journiary";

export const AppDataSource = new DataSource({
    type: "postgres",
    url: connectionString,
    synchronize: true, // DEV only: automatically creates the database schema on every application launch
    logging: true,
    entities: [Trip, Memory, MediaItem, RoutePoint, Tag, TagCategory, BucketListItem, GPXTrack, TrackSegment],
    subscribers: [],
    migrations: [],
}); 