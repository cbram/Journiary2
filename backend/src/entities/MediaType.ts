import { registerEnumType } from "type-graphql";

export enum MediaType {
    IMAGE = "IMAGE",
    VIDEO = "VIDEO",
    AUDIO = "AUDIO",
    DOCUMENT = "DOCUMENT"
}

registerEnumType(MediaType, {
    name: "MediaType",
    description: "Types of media files",
}); 