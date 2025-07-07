import { Field, InputType, Int } from "type-graphql";

@InputType({ description: "Input data for updating a MediaItem" })
export class UpdateMediaItemInput {
    @Field({ nullable: true, description: "The name of the object in the storage (e.g., from createUploadUrl)" })
    objectName?: string;

    @Field({ nullable: true, description: "The name of the thumbnail object in the storage" })
    thumbnailObjectName?: string;

    @Field({ nullable: true, description: "The type of media, e.g., 'image', 'video'." })
    mediaType?: string;
    
    @Field({ nullable: true, description: "The timestamp of when the media was created" })
    timestamp?: Date;

    @Field(() => Int, { nullable: true, description: "The order of this item within the memory's media list" })
    order?: number;

    @Field(() => Int, { nullable: true, description: "File size in bytes" })
    filesize?: number;

    @Field(() => Int, { nullable: true, description: "For videos, the duration in seconds." })
    duration?: number;
} 