import { ObjectType, Field, ID, Float } from 'type-graphql';
import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, ManyToMany, JoinTable, OneToOne, JoinColumn } from 'typeorm';
import { Trip } from './Trip';
import { MediaItem } from './MediaItem';
import { Tag } from './Tag';
import { GPXTrack } from './GPXTrack';
import { BucketListItem } from './BucketListItem';
import { User } from './User';

@ObjectType({ description: "Represents a single memory or event within a trip" })
@Entity()
export class Memory {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @Field()
    @Column()
    title!: string;

    @Field({ nullable: true })
    @Column("text", { nullable: true })
    text?: string;
    
    @Field()
    @Column()
    timestamp!: Date;

    @Field(() => Float)
    @Column("double precision")
    latitude!: number;

    @Field(() => Float)
    @Column("double precision")
    longitude!: number;

    @Field({ nullable: true })
    @Column({ nullable: true })
    locationName?: string;

    @Field({ nullable: true, description: "JSON string containing weather data" })
    @Column("text", { nullable: true })
    weatherJSON?: string;

    @Field(() => [MediaItem], { description: "A list of media items associated with this memory" })
    @OneToMany(() => MediaItem, (mediaItem: MediaItem) => mediaItem.memory)
    mediaItems!: MediaItem[];

    @Field(() => [Tag])
    @ManyToMany(() => Tag, tag => tag.memories)
    @JoinTable()
    tags!: Tag[];

    @ManyToOne(() => User, user => user.createdMemories)
    creator!: User;

    @ManyToOne(() => Trip, (trip: Trip) => trip.memories)
    trip!: Trip;

    @Field(() => ID)
    @Column()
    tripId!: string;

    @Field(() => GPXTrack, { nullable: true })
    @OneToOne(() => GPXTrack, gpxTrack => gpxTrack.memory, { cascade: true, nullable: true })
    @JoinColumn()
    gpxTrack?: GPXTrack;

    @ManyToOne(() => BucketListItem, item => item.memories, { nullable: true })
    bucketListItem?: BucketListItem;
} 