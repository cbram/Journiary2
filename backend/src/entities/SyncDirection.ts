import { registerEnumType } from "type-graphql";

export enum SyncDirection {
    UPLOAD = "UPLOAD",
    DOWNLOAD = "DOWNLOAD",
    BIDIRECTIONAL = "BIDIRECTIONAL"
}

registerEnumType(SyncDirection, {
    name: "SyncDirection",
    description: "Synchronization direction",
}); 