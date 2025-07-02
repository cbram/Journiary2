import { ObjectType, Field } from "type-graphql";

@ObjectType()
export class PresignedUrlResponse {
    @Field()
    uploadUrl!: string;

    /**
     * Download-URL für GET-Requests. Optional, weil Upload-URLs keine Download-URL benötigen.
     */
    @Field({ name: "downloadUrl", nullable: true })
    downloadUrl?: string;

    @Field(() => Number, { nullable: true })
    expiresIn?: number;

    @Field({ name: "objectKey" })
    objectName!: string;
} 