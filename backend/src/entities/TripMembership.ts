import { ObjectType, Field, ID, registerEnumType } from "type-graphql";
import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, Unique } from "typeorm";
import { User } from "./User";
import { Trip } from "./Trip";

export enum TripRole {
    OWNER = "owner",
    EDITOR = "editor",
    VIEWER = "viewer",
}

registerEnumType(TripRole, {
    name: "TripRole",
    description: "The role of a user in a trip",
});

@ObjectType()
@Entity()
@Unique(["user", "trip"]) // A user can only have one role per trip
export class TripMembership {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @ManyToOne(() => User, user => user.tripMemberships)
    user!: User;

    @ManyToOne(() => Trip, trip => trip.members)
    trip!: Trip;

    @Field(() => TripRole)
    @Column({
        type: "enum",
        enum: TripRole,
        default: TripRole.VIEWER,
    })
    role!: TripRole;
} 