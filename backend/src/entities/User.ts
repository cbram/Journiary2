import { ObjectType, Field, ID } from "type-graphql";
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, OneToMany } from "typeorm";
import { Trip } from "./Trip";
import { Memory } from "./Memory";
import { MediaItem } from "./MediaItem";
import { BucketListItem } from "./BucketListItem";
import { Tag } from "./Tag";
import { TagCategory } from "./TagCategory";
import { RoutePoint } from "./RoutePoint";
import { GPXTrack } from "./GPXTrack";
import { TripMembership } from "./TripMembership";

@ObjectType({ description: "Represents a user of the application" })
@Entity()
export class User {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @Field()
    @Column({ unique: true })
    email!: string;

    @Field()
    @Column({ unique: true })
    username!: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    firstName?: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    lastName?: string;

    @Column()
    password!: string; // This field will not be exposed via @Field() for security

    @Field({ nullable: true })
    @Column({ nullable: true })
    profileImageUrl?: string;

    @Field()
    @Column({ default: true })
    isActive!: boolean;

    @Field()
    @Column({ default: false })
    isEmailVerified!: boolean;

    @Field({ nullable: true })
    @Column({ nullable: true })
    lastLoginAt?: Date;

    @Field()
    @CreateDateColumn()
    createdAt!: Date;

    @Field()
    @UpdateDateColumn()
    updatedAt!: Date;

    // User-owned Trips
    @OneToMany(() => Trip, trip => trip.owner)
    ownedTrips!: Trip[];

    // Trip Memberships (shared trips)
    @OneToMany(() => TripMembership, membership => membership.user)
    tripMemberships!: TripMembership[];

    // User-created Memories
    @OneToMany(() => Memory, memory => memory.creator)
    createdMemories!: Memory[];

    // User-uploaded Media Items
    @OneToMany(() => MediaItem, mediaItem => mediaItem.uploader)
    uploadedMediaItems!: MediaItem[];

    // User-created Bucket List Items
    @OneToMany(() => BucketListItem, item => item.creator)
    createdBucketListItems!: BucketListItem[];

    // User-created Tags
    @OneToMany(() => Tag, tag => tag.creator)
    createdTags!: Tag[];

    // User-created Tag Categories
    @OneToMany(() => TagCategory, category => category.creator)
    createdTagCategories!: TagCategory[];

    // User-recorded Route Points
    @OneToMany(() => RoutePoint, routePoint => routePoint.recorder)
    recordedRoutePoints!: RoutePoint[];

    // User-created GPX Tracks
    @OneToMany(() => GPXTrack, gpxTrack => gpxTrack.creator)
    createdGPXTracks!: GPXTrack[];

    // Computed Fields
    @Field()
    get displayName(): string {
        if (this.firstName && this.lastName) {
            return `${this.firstName} ${this.lastName}`;
        } else if (this.firstName) {
            return this.firstName;
        } else if (this.username) {
            return this.username;
        } else {
            return this.email;
        }
    }

    @Field()
    get initials(): string {
        if (this.firstName && this.lastName) {
            return `${this.firstName.charAt(0)}${this.lastName.charAt(0)}`.toUpperCase();
        } else if (this.firstName) {
            return this.firstName.substring(0, 2).toUpperCase();
        } else if (this.username) {
            return this.username.substring(0, 2).toUpperCase();
        } else {
            return this.email.substring(0, 2).toUpperCase();
        }
    }

    @Field()
    get isOnline(): boolean {
        if (!this.lastLoginAt) return false;
        const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
        return this.lastLoginAt > thirtyMinutesAgo;
    }

    // Helper Methods (not exposed as GraphQL fields)
    
    public updateLastLogin(): void {
        this.lastLoginAt = new Date();
    }

    public markEmailAsVerified(): void {
        this.isEmailVerified = true;
    }

    public deactivate(): void {
        this.isActive = false;
    }

    public reactivate(): void {
        this.isActive = true;
    }
} 