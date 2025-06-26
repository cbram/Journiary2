import { AppDataSource } from "./database";
import { TripMembership, TripRole } from "../entities/TripMembership";

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