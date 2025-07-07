import { Field, InputType, ID } from "type-graphql";

@InputType({ description: "Input data for updating a GPXTrack" })
export class UpdateGPXTrackInput {
    @Field({ nullable: true, description: "The name of the GPX track" })
    name?: string;

    @Field({ nullable: true, description: "The name of the uploaded GPX file in the object storage" })
    gpxFileObjectName?: string;
    
    @Field({ nullable: true })
    originalFilename?: string;

    @Field(() => ID, { nullable: true, description: "Optional ID of the memory this GPX track is associated with" })
    memoryId?: string;
    
    @Field({ nullable: true })
    creator?: string;

    @Field({ nullable: true })
    trackType?: string;
} 