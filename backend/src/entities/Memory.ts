import { ObjectType, Field, ID, Float } from 'type-graphql';
import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, ManyToMany, JoinTable, OneToOne, JoinColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';
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

    /**
     * Inhalt des Eintrags.
     * Legacy-Feldname: `text`  – Neuer Alias: `content`
     */
    @Field({ nullable: true })
    @Column("text", { nullable: true })
    text?: string;

    // Alias-Feld `content` für neue iOS-Versionen
    @Field(() => String, { name: "content", nullable: true })
    get content(): string | undefined {
        return this.text;
    }

    /**
     * Zeitpunkt des Memories.
     * Legacy-Feldname: `timestamp` – Neuer Alias: `date`
     */
    @Field()
    @Column({ type: "timestamp", default: () => "CURRENT_TIMESTAMP" })
    timestamp!: Date;

    @Field(() => Date, { name: "date" })
    get date(): Date {
        return this.timestamp;
    }

    @Field(() => Float)
    @Column("double precision")
    latitude!: number;

    @Field(() => Float)
    @Column("double precision")
    longitude!: number;

    /**
     * Name/Adresse des Standorts.
     * Legacy-Feldname: `locationName` – Neuer Alias: `address`
     */
    @Field({ nullable: true })
    @Column({ nullable: true })
    locationName?: string;

    @Field(() => String, { name: "address", nullable: true })
    get address(): string | undefined {
        return this.locationName;
    }

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

    /**
     * Automatische Zeitstempel – werden von TypeORM gesetzt. Benötigt für iOS-Felder `createdAt`, `updatedAt`.
     */
    @Field()
    @CreateDateColumn()
    createdAt!: Date;

    @Field()
    @UpdateDateColumn()
    updatedAt!: Date;

    /**
     * Alias-Feld – liefert die ID des Erstellers als `userId`, wie im iOS-Schema erwartet.
     * Wird mittels Getter bereitgestellt, ohne ein eigenes DB-Feld anzulegen.
     */
    @Field(() => ID, { name: "userId" })
    get userId(): string {
        return this.creator?.id ?? "unknown";
    }
} 