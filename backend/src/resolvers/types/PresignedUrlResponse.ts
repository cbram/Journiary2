import { ObjectType, Field } from "type-graphql";

@ObjectType()
export class PresignedUrlResponse {
    @Field()
    uploadUrl!: string;

    @Field()
    objectName!: string;
} 