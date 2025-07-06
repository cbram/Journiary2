"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MediaType = void 0;
const type_graphql_1 = require("type-graphql");
var MediaType;
(function (MediaType) {
    MediaType["IMAGE"] = "IMAGE";
    MediaType["VIDEO"] = "VIDEO";
    MediaType["AUDIO"] = "AUDIO";
    MediaType["DOCUMENT"] = "DOCUMENT";
})(MediaType || (exports.MediaType = MediaType = {}));
(0, type_graphql_1.registerEnumType)(MediaType, {
    name: "MediaType",
    description: "Types of media files",
});
