import { ObjectType, Field, ID, Int } from 'type-graphql';
import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { Memory } from './Memory';
import { User } from './User';

@ObjectType({ description: "Represents a media file (photo, video, etc.) associated with a memory" })
@Entity()
export class MediaItem {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    /**
     * MIME Type des Mediums. Wird im iOS-Schema als `mimeType` abgefragt.
     */
    @Field({ name: "mimeType" })
    @Column()
    mediaType!: string;

    @Field()
    @Column()
    timestamp!: Date;

    @Field(() => Int, { description: "The order of this item within the memory's media list" })
    @Column()
    order!: number;

    /**
     * Name/Key des Objekts im Storage (z. B. MinIO). In der iOS-App wird dieses Feld als `s3Key` abgefragt.
     * Ein zusätzliches Alias‐Feld `filename` wird in der Resolver-Schicht bereitgestellt, um doppelte Dekoratoren zu vermeiden.
     */
    @Field({ name: "s3Key" })
    @Column()
    objectName!: string;

    @Field(() => Int, { name: "fileSize", description: "File size in bytes" })
    @Column()
    filesize!: number;

    @Field({ nullable: true, description: "For videos, the duration in seconds." })
    @Column({ nullable: true })
    duration?: number;

    @Field({ name: "thumbnailS3Key", nullable: true, description: "The name of the thumbnail object in the storage (e.g., MinIO)" })
    @Column({ nullable: true })
    thumbnailObjectName?: string;

    @ManyToOne(() => User, user => user.uploadedMediaItems)
    uploader!: User;

    @Field(() => Memory)
    @ManyToOne(() => Memory, (memory: Memory) => memory.mediaItems)
    memory!: Memory;

    /**
     * Automatische Zeitstempel zur Kompatibilität mit iOS-Schema
     */
    @Field()
    @CreateDateColumn()
    createdAt!: Date;

    @Field()
    @UpdateDateColumn()
    updatedAt!: Date;
} 