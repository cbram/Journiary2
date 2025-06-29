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

// Development-Modus: Verwende SQLite wenn keine DATABASE_URL gesetzt ist
const isLocalDevelopment = !databaseUrl;

if (isLocalDevelopment) {
    console.log("🏠 Development-Modus: Verwende lokale SQLite-Datenbank");
} else {
    console.log("🐘 Production-Modus: Verwende PostgreSQL-Datenbank");
}

export const AppDataSource = new DataSource(
    isLocalDevelopment ? {
        // SQLite-Konfiguration für lokale Entwicklung
        type: "sqlite",
        database: "./journiary-dev.sqlite",
        synchronize: true, // DEV only: automatisch Schema erstellen
        logging: false, // Weniger Logs für lokale Entwicklung
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
    } : {
        // PostgreSQL-Konfiguration für Production
        type: "postgres",
        url: databaseUrl,
        synchronize: true,
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
    }
); 