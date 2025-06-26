import { ObjectType, Field, ID } from "type-graphql";
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, OneToMany } from "typeorm";
import { Trip } from "./Trip";
import { TrackSegment } from "./TrackSegment";

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

    @Field()
    @CreateDateColumn()
    createdAt!: Date;

    @ManyToOne(() => Trip, trip => trip.gpxTracks)
    trip!: Trip;

    @Field(() => ID)
    @Column()
    tripId!: string;

    @Field(() => [TrackSegment])
    @OneToMany(() => TrackSegment, segment => segment.gpxTrack, { cascade: true })
    segments!: TrackSegment[];
} 