import { ObjectType, Field, ID, Float } from "type-graphql";
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, OneToOne, JoinColumn } from "typeorm";
import { TrackSegment } from "./TrackSegment";

@ObjectType({ description: "Represents metadata for a track segment" })
@Entity()
export class TrackMetadata {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    transportationMode?: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    movementPattern?: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    terrainType?: string;

    @Field({ nullable: true })
    @Column({ nullable: true })
    weatherConditions?: string;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    batteryLevel?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    gpsAccuracy?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    elevationGain?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    elevationLoss?: number;

    @Field(() => Float, { nullable: true })
    @Column("float", { nullable: true })
    pauseDuration?: number;
    
    @Field()
    @CreateDateColumn()
    createdAt!: Date;

    @OneToOne(() => TrackSegment, segment => segment.metadata)
    @JoinColumn()
    trackSegment!: TrackSegment;
} 