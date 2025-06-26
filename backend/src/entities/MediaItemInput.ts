import { Field, InputType, Int } from "type-graphql";

@InputType({ description: "Input data for creating a new MediaItem" })
export class MediaItemInput {
    @Field({ description: "The name of the object in the storage (e.g., from createUploadUrl)" })
    objectName!: string;

    @Field({ description: "The ID of the memory this media item belongs to" })
    memoryId!: string;

    @Field({ description: "The type of media, e.g., 'image', 'video'." })
    mediaType!: string;
    
    @Field({ description: "The timestamp of when the media was created" })
    timestamp!: Date;

    @Field(() => Int, { description: "The order of this item within the memory's media list" })
    order!: number;

    @Field(() => Int, { description: "File size in bytes" })
    filesize!: number;

    @Field(() => Int, { nullable: true, description: "For videos, the duration in seconds." })
    duration?: number;
} 