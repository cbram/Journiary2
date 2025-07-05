import { ObjectType, Field, ID } from "type-graphql";
import { Trip } from "../../entities/Trip";
import { Memory } from "../../entities/Memory";
import { Tag } from "../../entities/Tag";
import { TagCategory } from "../../entities/TagCategory";
import { MediaItem } from "../../entities/MediaItem";
import { GPXTrack } from "../../entities/GPXTrack";
import { BucketListItem } from "../../entities/BucketListItem";

@ObjectType()
export class DeletedIds {
    @Field(() => [ID])
    trips!: string[];

    @Field(() => [ID])
    memories!: string[];

    @Field(() => [ID])
    tags!: string[];

    @Field(() => [ID])
    tagCategories!: string[];

    @Field(() => [ID])
    mediaItems!: string[];

    @Field(() => [ID])
    gpxTracks!: string[];

    @Field(() => [ID])
    bucketListItems!: string[];
}


@ObjectType()
export class SyncResponse {
    @Field(() => [Trip])
    trips!: Trip[];

    @Field(() => [Memory])
    memories!: Memory[];

    @Field(() => [Tag])
    tags!: Tag[];

    @Field(() => [TagCategory])
    tagCategories!: TagCategory[];

    @Field(() => [MediaItem])
    mediaItems!: MediaItem[];

    @Field(() => [GPXTrack])
    gpxTracks!: GPXTrack[];

    @Field(() => [BucketListItem])
    bucketListItems!: BucketListItem[];

    @Field(() => DeletedIds)
    deleted!: DeletedIds;

    @Field()
    serverTimestamp!: Date;
} 