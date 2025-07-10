"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppDataSource = void 0;
require("reflect-metadata");
const typeorm_1 = require("typeorm");
const Trip_1 = require("../entities/Trip");
const Memory_1 = require("../entities/Memory");
const MediaItem_1 = require("../entities/MediaItem");
const RoutePoint_1 = require("../entities/RoutePoint");
const Tag_1 = require("../entities/Tag");
const TagCategory_1 = require("../entities/TagCategory");
const BucketListItem_1 = require("../entities/BucketListItem");
const GPXTrack_1 = require("../entities/GPXTrack");
const TrackSegment_1 = require("../entities/TrackSegment");
const TrackMetadata_1 = require("../entities/TrackMetadata");
const User_1 = require("../entities/User");
const TripMembership_1 = require("../entities/TripMembership");
const DeletionLog_1 = require("../entities/DeletionLog");
const ConflictTypes_1 = require("../types/ConflictTypes");
const databaseUrl = process.env.DATABASE_URL;
// Development-Modus: Verwende SQLite wenn keine DATABASE_URL gesetzt ist
const isLocalDevelopment = !databaseUrl;
if (isLocalDevelopment) {
    console.log("🏠 Development-Modus: Verwende lokale SQLite-Datenbank");
}
else {
    console.log("🐘 Production-Modus: Verwende PostgreSQL-Datenbank");
}
exports.AppDataSource = new typeorm_1.DataSource(isLocalDevelopment ? {
    // SQLite-Konfiguration für lokale Entwicklung
    type: "sqlite",
    database: "./journiary-dev.sqlite",
    synchronize: true,
    logging: false,
    entities: [
        Trip_1.Trip,
        Memory_1.Memory,
        MediaItem_1.MediaItem,
        RoutePoint_1.RoutePoint,
        Tag_1.Tag,
        TagCategory_1.TagCategory,
        BucketListItem_1.BucketListItem,
        GPXTrack_1.GPXTrack,
        TrackSegment_1.TrackSegment,
        TrackMetadata_1.TrackMetadata,
        User_1.User,
        TripMembership_1.TripMembership,
        DeletionLog_1.DeletionLog,
        ConflictTypes_1.ConflictLog,
        ConflictTypes_1.DeviceRegistry
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
        Trip_1.Trip,
        Memory_1.Memory,
        MediaItem_1.MediaItem,
        RoutePoint_1.RoutePoint,
        Tag_1.Tag,
        TagCategory_1.TagCategory,
        BucketListItem_1.BucketListItem,
        GPXTrack_1.GPXTrack,
        TrackSegment_1.TrackSegment,
        TrackMetadata_1.TrackMetadata,
        User_1.User,
        TripMembership_1.TripMembership,
        DeletionLog_1.DeletionLog,
        ConflictTypes_1.ConflictLog,
        ConflictTypes_1.DeviceRegistry
    ],
    subscribers: [],
    migrations: [],
});
