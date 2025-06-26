import { ObjectType, Field, ID, Float, Int } from 'type-graphql';
import { Entity, PrimaryGeneratedColumn, Column, OneToMany } from 'typeorm';
import { Memory } from './Memory';
import { RoutePoint } from './RoutePoint';
import { GPXTrack } from './GPXTrack';

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

    @Field(() => [Memory])
    @OneToMany(() => Memory, (memory: Memory) => memory.trip)
    memories!: Memory[];

    @Field(() => [RoutePoint])
    @OneToMany(() => RoutePoint, (routePoint: RoutePoint) => routePoint.trip)
    routePoints!: RoutePoint[];

    @Field(() => [GPXTrack])
    @OneToMany(() => GPXTrack, gpxTrack => gpxTrack.trip)
    gpxTracks!: GPXTrack[];

    // We will add relationships to Memory, RoutePoint etc. later
} 