"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Permission = void 0;
const type_graphql_1 = require("type-graphql");
var Permission;
(function (Permission) {
    Permission["READ"] = "READ";
    Permission["WRITE"] = "WRITE";
    Permission["ADMIN"] = "ADMIN";
})(Permission = exports.Permission || (exports.Permission = {}));
(0, type_graphql_1.registerEnumType)(Permission, {
    name: "Permission",
    description: "User permission levels for trips",
});
