import { ObjectType, Field, ID } from "type-graphql";
import { Entity, PrimaryGeneratedColumn, ManyToOne, OneToMany, JoinColumn } from "typeorm";
import { GPXTrack } from "./GPXTrack";
import { RoutePoint } from "./RoutePoint";

@ObjectType({ description: "A continuous segment of a GPX track, containing a series of points." })
@Entity()
export class TrackSegment {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @ManyToOne(() => GPXTrack, track => track.segments)
    @JoinColumn({ name: "gpxTrackId" })
    gpxTrack!: GPXTrack;

    @Field(() => [RoutePoint])
    @OneToMany(() => RoutePoint, point => point.trackSegment, { cascade: true })
    points!: RoutePoint[];
} 