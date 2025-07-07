import { ObjectType, Field, ID, Float } from "type-graphql";
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, OneToMany, ManyToOne } from "typeorm";
import { Memory } from "./Memory";
import { User } from "./User";

@ObjectType()
@Entity()
export class BucketListItem {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @Field()
    @Column()
    name!: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    country?: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    region?: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    type?: string;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    latitude1?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    longitude1?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    latitude2?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    longitude2?: number;

    @Field()
    @Column({ default: false })
    isDone!: boolean;

    @Field()
    @CreateDateColumn()
    createdAt!: Date;

    @Field()
    @Column({ type: "timestamp", default: () => "CURRENT_TIMESTAMP" })
    updatedAt!: Date;

    @ManyToOne(() => User, user => user.createdBucketListItems)
    creator!: User;

    @Field({ nullable: true })
    @Column({ type: "timestamp", nullable: true })
    completedAt?: Date;

    @Field(() => [Memory], { nullable: true })
    @OneToMany(() => Memory, memory => memory.bucketListItem)
    memories?: Memory[];
} 