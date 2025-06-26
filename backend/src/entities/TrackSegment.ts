import { ObjectType, Field, ID, Float, Int } from "type-graphql";
import { Entity, PrimaryGeneratedColumn, ManyToOne, OneToMany, JoinColumn, Column, OneToOne } from "typeorm";
import { GPXTrack } from "./GPXTrack";
import { RoutePoint } from "./RoutePoint";
import { TrackMetadata } from "./TrackMetadata";
import { Trip } from "./Trip";

@ObjectType({ description: "A continuous segment of a GPX track, containing a series of points." })
@Entity()
export class TrackSegment {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @ManyToOne(() => GPXTrack, track => track.segments)
    @JoinColumn({ name: "gpxTrackId" })
    gpxTrack!: GPXTrack;

    @ManyToOne(() => Trip, trip => trip.trackSegments, { nullable: true })
    trip?: Trip;

    @Field(() => [RoutePoint])
    @OneToMany(() => RoutePoint, point => point.trackSegment, { cascade: true })
    points!: RoutePoint[];

    @Field({ nullable: true })
    @Column({ nullable: true })
    segmentType?: string;

    @Column({ type: "bytea", nullable: true })
    encodedData?: Buffer;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    compressionRatio?: number;

    @Field({ nullable: true })
    @Column({ nullable: true })
    startDate?: Date;

    @Field({ nullable: true })
    @Column({ nullable: true })
    endDate?: Date;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    distance?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    averageSpeed?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    maxSpeed?: number;

    @Field(() => Int, { nullable: true })
    @Column({ nullable: true })
    originalPointCount?: number;

    @Field({ nullable: true })
    @Column({ nullable: true })
    isCompressed?: boolean;

    @Field({ nullable: true })
    @Column({ nullable: true })
    qualityLevel?: string;

    @Field(() => TrackMetadata, { nullable: true })
    @OneToOne(() => TrackMetadata, metadata => metadata.trackSegment, { cascade: true, nullable: true })
    metadata?: TrackMetadata;
} 