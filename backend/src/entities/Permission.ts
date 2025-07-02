import { registerEnumType } from "type-graphql";

export enum Permission {
    READ = "READ",
    WRITE = "WRITE", 
    ADMIN = "ADMIN"
}

registerEnumType(Permission, {
    name: "Permission",
    description: "User permission levels for trips",
}); 