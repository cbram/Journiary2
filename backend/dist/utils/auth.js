"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.authChecker = exports.checkTripAccess = void 0;
const database_1 = require("./database");
const TripMembership_1 = require("../entities/TripMembership");
const User_1 = require("../entities/User");
/**
 * Checks if a user has access to a specific trip with at least a minimum required role.
 * @param userId The ID of the user to check.
 * @param tripId The ID of the trip to check access for.
 * @param requiredRole The minimum role required for access. Defaults to VIEWER.
 * @returns {Promise<boolean>} True if the user has access, false otherwise.
 */
async function checkTripAccess(userId, tripId, requiredRole = TripMembership_1.TripRole.VIEWER) {
    const roleHierarchy = {
        [TripMembership_1.TripRole.VIEWER]: 1,
        [TripMembership_1.TripRole.EDITOR]: 2,
        [TripMembership_1.TripRole.OWNER]: 3,
    };
    const membership = await database_1.AppDataSource.getRepository(TripMembership_1.TripMembership).findOne({
        where: {
            user: { id: userId },
            trip: { id: tripId },
        },
    });
    if (!membership) {
        return false; // User is not a member of this trip at all.
    }
    const userLevel = roleHierarchy[membership.role];
    const requiredLevel = roleHierarchy[requiredRole];
    return userLevel >= requiredLevel;
}
exports.checkTripAccess = checkTripAccess;
const authChecker = async ({ root, args, context, info }, roles) => {
    // here we can read the user from context
    // and check his permission in the database
    if (!context.userId) {
        return false;
    }
    // if `@Authorized()`, check only if user is logged in
    if (roles.length === 0) {
        return context.userId !== undefined;
    }
    // if `@Authorized("ADMIN")`, check if user is admin
    const user = await User_1.User.findOne({ where: { id: context.userId } });
    if (!user) {
        return false;
    }
    if (user.roles.some((role) => roles.includes(role))) {
        return true;
    }
    return false;
};
exports.authChecker = authChecker;
