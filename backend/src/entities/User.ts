import { ObjectType, Field, ID } from "type-graphql";
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, OneToMany } from "typeorm";
import { Trip } from "./Trip";
import { BucketListItem } from "./BucketListItem";
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

    @Column()
    password!: string; // This field will not be exposed via @Field() for security

    @Field()
    @CreateDateColumn()
    createdAt!: Date;

    @Field()
    @UpdateDateColumn()
    updatedAt!: Date;

    /* This will be replaced by a ManyToMany relationship through TripMembership
    // A user can have multiple trips
    @OneToMany(() => Trip, trip => trip.user)
    trips!: Trip[];
    */

    @OneToMany(() => TripMembership, membership => membership.user)
    tripMemberships!: TripMembership[];

    // A user can have multiple bucket list items
    @OneToMany(() => BucketListItem, item => item.user)
    bucketListItems!: BucketListItem[];
} 