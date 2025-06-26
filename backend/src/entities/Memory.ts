import { ObjectType, Field, ID, Float } from 'type-graphql';
import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, ManyToMany, JoinTable } from 'typeorm';
import { Trip } from './Trip';
import { MediaItem } from './MediaItem';
import { Tag } from './Tag';

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

    @Field(() => [MediaItem], { description: "A list of media items associated with this memory" })
    @OneToMany(() => MediaItem, (mediaItem: MediaItem) => mediaItem.memory)
    mediaItems!: MediaItem[];

    @Field(() => [Tag])
    @ManyToMany(() => Tag, tag => tag.memories)
    @JoinTable()
    tags!: Tag[];

    @ManyToOne(() => Trip, (trip: Trip) => trip.memories)
    trip!: Trip;

    @Field(() => ID)
    @Column()
    tripId!: string;
} 