import { ObjectType, Field, ID, Float } from 'type-graphql';
import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, CreateDateColumn } from 'typeorm';
import { Trip } from './Trip';
import { TrackSegment } from './TrackSegment';
import { User } from './User';

@ObjectType({ description: "Represents a single GPS point on a route" })
@Entity()
export class RoutePoint {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @Field(() => Float)
    @Column("double precision")
    latitude!: number;

    @Field(() => Float)
    @Column("double precision")
    longitude!: number;

    @Field(() => Float, { nullable: true })
    @Column("double precision", { nullable: true })
    altitude?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    speed?: number;

    @Field()
    @Column()
    timestamp!: Date;

    @ManyToOne(() => User, user => user.recordedRoutePoints)
    recorder!: User;

    @ManyToOne(() => Trip, (trip: Trip) => trip.routePoints)
    trip!: Trip; 

    @ManyToOne(() => TrackSegment, segment => segment.points, { nullable: true })
    trackSegment?: TrackSegment;

    @Field()
    @CreateDateColumn()
    created_at!: Date;
} 