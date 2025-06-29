import { ObjectType, Field, ID, Float, Int } from 'type-graphql';
import { Entity, PrimaryGeneratedColumn, Column, OneToMany, ManyToOne } from 'typeorm';
import { Memory } from './Memory';
import { RoutePoint } from './RoutePoint';
import { GPXTrack } from './GPXTrack';
import { TrackSegment } from './TrackSegment';
import { User } from './User';
import { TripMembership } from './TripMembership';
import { BucketListItem } from './BucketListItem';

@ObjectType({ description: "Represents a single journey or trip" })
@Entity()
export class Trip {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @Field()
    @Column()
    name!: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    tripDescription?: string;

    @Field({ nullable: true, description: "The name of the cover image object in the storage (e.g., MinIO)" })
    @Column({ nullable: true })
    coverImageObjectName?: string;

    @Field(() => String, { nullable: true, description: "A temporary URL to view the trip's cover image." })
    coverImageUrl?: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    travelCompanions?: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    visitedCountries?: string;
    
    @Field()
    @Column()
    startDate!: Date;

    @Field({ nullable: true })
    @Column({ nullable: true })
    endDate?: Date;

    @Field()
    @Column({ default: true })
    isActive!: boolean;

    @Field(() => Float)
    @Column({ type: "float", default: 0 })
    totalDistance!: number;

    @Field()
    @Column({ default: true })
    gpsTrackingEnabled!: boolean;

    @Field()
    @Column({ type: "timestamp", default: () => "CURRENT_TIMESTAMP" })
    createdAt!: Date;

    @Field()
    @Column({ type: "timestamp", default: () => "CURRENT_TIMESTAMP", onUpdate: "CURRENT_TIMESTAMP" })
    updatedAt!: Date;

    @ManyToOne(() => User, user => user.ownedTrips)
    owner!: User;

    @OneToMany(() => TripMembership, membership => membership.trip)
    members!: TripMembership[];

    @Field(() => [Memory])
    @OneToMany(() => Memory, memory => memory.trip, { cascade: true })
    memories!: Memory[];

    @Field(() => [RoutePoint])
    @OneToMany(() => RoutePoint, (routePoint: RoutePoint) => routePoint.trip)
    routePoints!: RoutePoint[];

    @Field(() => [GPXTrack])
    @OneToMany(() => GPXTrack, track => track.trip)
    gpxTracks!: GPXTrack[];

    @Field(() => [TrackSegment])
    @OneToMany(() => TrackSegment, segment => segment.trip)
    trackSegments!: TrackSegment[];

    // We will add relationships to Memory, RoutePoint etc. later
} 