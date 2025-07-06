"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SyncDirection = void 0;
const type_graphql_1 = require("type-graphql");
var SyncDirection;
(function (SyncDirection) {
    SyncDirection["UPLOAD"] = "UPLOAD";
    SyncDirection["DOWNLOAD"] = "DOWNLOAD";
    SyncDirection["BIDIRECTIONAL"] = "BIDIRECTIONAL";
})(SyncDirection || (exports.SyncDirection = SyncDirection = {}));
(0, type_graphql_1.registerEnumType)(SyncDirection, {
    name: "SyncDirection",
    description: "Synchronization direction",
});
