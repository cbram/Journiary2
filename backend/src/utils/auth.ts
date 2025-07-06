import { AppDataSource } from "./database";
import { TripMembership, TripRole } from "../entities/TripMembership";
import { MyContext } from "../index";
import { User } from "../entities/User";
import { AuthChecker } from "type-graphql";

/**
 * Checks if a user has access to a specific trip with at least a minimum required role.
 * @param userId The ID of the user to check.
 * @param tripId The ID of the trip to check access for.
 * @param requiredRole The minimum role required for access. Defaults to VIEWER.
 * @returns {Promise<boolean>} True if the user has access, false otherwise.
 */
export async function checkTripAccess(
    userId: string, 
    tripId: string, 
    requiredRole: TripRole = TripRole.VIEWER
): Promise<boolean> {
    
    const roleHierarchy = {
        [TripRole.VIEWER]: 1,
        [TripRole.EDITOR]: 2,
        [TripRole.OWNER]: 3,
    };

    const membership = await AppDataSource.getRepository(TripMembership).findOne({
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

export const authChecker: AuthChecker<MyContext> = async (
    { root, args, context, info },
    roles,
) => {
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
    const user = await User.findOne({ where: { id: context.userId } });
    if (!user) {
        return false;
    }
    
    if (user.roles.some((role: string) => roles.includes(role))) {
        return true;
    }

    return false;
}; 