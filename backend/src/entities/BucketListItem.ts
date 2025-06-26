import { ObjectType, Field, ID, Float } from "type-graphql";
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, OneToOne, JoinColumn } from "typeorm";
import { Memory } from "./Memory";

@ObjectType({ description: "Represents an item on a user's bucket list" })
@Entity()
export class BucketListItem {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @Field()
    @Column()
    title!: string;

    @Field({ nullable: true })
    @Column("text", { nullable: true })
    description?: string;

    @Field()
    @Column({ default: false })
    isCompleted!: boolean;

    @Field({ nullable: true })
    @Column({ type: "timestamp", nullable: true })
    completedAt?: Date;
    
    @Field({ nullable: true })
    @Column({ type: "timestamp", nullable: true })
    targetDate?: Date;

    @Field(() => Float, { nullable: true })
    @Column("double precision", { nullable: true })
    latitude?: number;

    @Field(() => Float, { nullable: true })
    @Column("double precision", { nullable: true })
    longitude?: number;

    @Field()
    @CreateDateColumn()
    createdAt!: Date;

    // The memory that fulfilled this bucket list item
    @Field(() => Memory, { nullable: true })
    @OneToOne(() => Memory, { nullable: true })
    @JoinColumn()
    completionMemory?: Memory;

    @Field(() => ID, { nullable: true })
    @Column({ nullable: true })
    completionMemoryId?: string;
} 