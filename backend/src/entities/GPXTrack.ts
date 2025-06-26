import { ObjectType, Field, ID, Float, Int } from "type-graphql";
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, OneToMany, OneToOne } from "typeorm";
import { Trip } from "./Trip";
import { TrackSegment } from "./TrackSegment";
import { Memory } from "./Memory";

@ObjectType({ description: "Represents a GPX track, which is a collection of track segments" })
@Entity()
export class GPXTrack {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @Field()
    @Column()
    name!: string;

    @Field({ nullable: true })
    @Column("text", { nullable: true })
    description?: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    originalFilename?: string;

    @Field({ nullable: true, description: "The name of the GPX file object in the storage (e.g., MinIO)" })
    @Column({ nullable: true })
    gpxFileObjectName?: string;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    totalDistance?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    totalDuration?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    averageSpeed?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    maxSpeed?: number;
    
    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    elevationGain?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    elevationLoss?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    minElevation?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    maxElevation?: number;

    @Field(() => Int, { nullable: true })
    @Column({ nullable: true })
    totalPoints?: number;

    @Field({ nullable: true })
    @Column({ nullable: true })
    startTime?: Date;

    @Field({ nullable: true })
    @Column({ nullable: true })
    endTime?: Date;

    @Field({ nullable: true })
    @Column({ nullable: true })
    creator?: string;
    
    @Field({ nullable: true })
    @Column({ nullable: true })
    trackType?: string;

    @Field()
    @CreateDateColumn()
    createdAt!: Date;

    @ManyToOne(() => Trip, trip => trip.gpxTracks)
    trip!: Trip;

    @Field(() => ID)
    @Column()
    tripId!: string;

    @Field(() => String, { nullable: true, description: "A temporary URL to download the GPX file." })
    downloadUrl?: string;

    @Field(() => [TrackSegment])
    @OneToMany(() => TrackSegment, segment => segment.gpxTrack, { cascade: true })
    segments!: TrackSegment[];

    @OneToOne(() => Memory, memory => memory.gpxTrack, { nullable: true })
    memory?: Memory;
} 