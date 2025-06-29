import { ObjectType, Field, ID, Int } from 'type-graphql';
import { Entity, PrimaryGeneratedColumn, Column, ManyToOne } from 'typeorm';
import { Memory } from './Memory';
import { User } from './User';

@ObjectType({ description: "Represents a media file (photo, video, etc.) associated with a memory" })
@Entity()
export class MediaItem {
    @Field(() => ID)
    @PrimaryGeneratedColumn("uuid")
    id!: string;

    @Field({ description: "The type of media, e.g., 'photo', 'video'." })
    @Column()
    mediaType!: string;

    @Field()
    @Column()
    timestamp!: Date;

    @Field(() => Int, { description: "The order of this item within the memory's media list" })
    @Column()
    order!: number;

    @Field({ description: "The name of the object in the storage (e.g., MinIO)" })
    @Column()
    objectName!: string;

    @Field(() => Int, { description: "File size in bytes" })
    @Column()
    filesize!: number;

    @Field({ nullable: true, description: "For videos, the duration in seconds." })
    @Column({ nullable: true })
    duration?: number;

    @Field({ nullable: true, description: "The name of the thumbnail object in the storage (e.g., MinIO)" })
    @Column({ nullable: true })
    thumbnailObjectName?: string;

    @ManyToOne(() => User, user => user.uploadedMediaItems)
    uploader!: User;

    @Field(() => Memory)
    @ManyToOne(() => Memory, (memory: Memory) => memory.mediaItems)
    memory!: Memory;
} 