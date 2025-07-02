import { Resolver, Query, Mutation, Arg, FieldResolver, Root, ID, ObjectType, Field, Ctx } from 'type-graphql';
import { Trip } from '../entities/Trip';
import { TripInput } from '../entities/TripInput';
import { UpdateTripInput } from '../entities/UpdateTripInput';
import { Memory } from '../entities/Memory';
import { AppDataSource } from '../utils/database';
import { generatePresignedPutUrl, generatePresignedGetUrl } from '../utils/minio';
import { v4 as uuidv4 } from 'uuid';
import { PresignedUrlResponse } from './types/PresignedUrlResponse';
import { MyContext } from '../index';
import { User } from '../entities/User';
import { AuthenticationError, UserInputError } from 'apollo-server-express';
import { TripMembership, TripRole } from '../entities/TripMembership';
import { checkTripAccess } from '../utils/auth';
import { Not } from 'typeorm';

@ObjectType()
class TripMembershipResponse {
    @Field(() => ID)
    id!: string;

    @Field(() => String)
    tripId!: string;

    @Field(() => String)
    userId!: string;

    @Field(() => TripRole)
    role!: TripRole;

    @Field(() => String)
    status!: string;

    @Field(() => User)
    user!: User;

    @Field(() => Trip, { nullable: true })
    trip?: Trip;

    @Field(() => Date)
    createdAt!: Date;
}

@Resolver(Trip)
export class TripResolver {

    @Query(() => [Trip], { description: "Get all trips the logged-in user is a member of" })
    async trips(@Ctx() { userId }: MyContext): Promise<Trip[]> {
        if (!userId) {
            return [];
        }

        // Find all memberships for the user and return the associated trips
        const memberships = await AppDataSource.getRepository(TripMembership).find({
            where: { user: { id: userId } },
            relations: ["trip"],
        });

        return memberships.map(m => m.trip);
    }

    @Query(() => Trip, { nullable: true, description: "Get a single trip by ID." })
    async trip(
        @Arg("id", () => ID) id: string,
        @Ctx() { userId }: MyContext
    ): Promise<Trip | null> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to view this trip.");
        }
        
        // 🔐 SECURITY: Check if user has access to this trip
        if (!(await checkTripAccess(userId, id, TripRole.VIEWER))) {
            throw new AuthenticationError("You don't have permission to view this trip.");
        }
        
        const trip = await AppDataSource.getRepository(Trip).findOne({ where: { id } });
        if (!trip) {
            return null;
        }
        return trip;
    }

    @Query(() => [TripMembershipResponse], { description: "Get all members of a trip" })
    async getTripMembers(
        @Arg("tripId", () => ID) tripId: string,
        @Ctx() { userId }: MyContext
    ): Promise<TripMembershipResponse[]> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to view trip members.");
        }

        // Check if user has access to this trip
        if (!(await checkTripAccess(userId, tripId, TripRole.VIEWER))) {
            throw new AuthenticationError("You don't have permission to view this trip's members.");
        }

        const memberships = await AppDataSource.getRepository(TripMembership).find({
            where: { trip: { id: tripId } },
            relations: ["user"],
        });

        return memberships.map(membership => ({
            id: membership.id,
            tripId: tripId,
            userId: membership.user.id,
            role: membership.role,
            status: "accepted", // Default status for existing memberships
            user: membership.user,
            trip: undefined, // Not needed for this query
            createdAt: membership.createdAt
        }));
    }

    @Mutation(() => TripMembershipResponse, { description: "Invite a user to a trip by email" })
    async inviteUserToTrip(
        @Arg("tripId", () => ID) tripId: string,
        @Arg("email") email: string,
        @Arg("role", () => TripRole, { defaultValue: TripRole.VIEWER }) role: TripRole,
        @Ctx() { userId }: MyContext
    ): Promise<TripMembershipResponse> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to invite users.");
        }

        // Check if user has permission to invite (must be at least EDITOR)
        if (!(await checkTripAccess(userId, tripId, TripRole.EDITOR))) {
            throw new AuthenticationError("You don't have permission to invite users to this trip.");
        }

        // Find the user by email
        const userToInvite = await AppDataSource.getRepository(User).findOne({
            where: { email: email.toLowerCase() }
        });

        if (!userToInvite) {
            throw new UserInputError("User with this email not found.");
        }

        // Check if user is already a member
        const existingMembership = await AppDataSource.getRepository(TripMembership).findOne({
            where: {
                user: { id: userToInvite.id },
                trip: { id: tripId }
            }
        });

        if (existingMembership) {
            throw new UserInputError("User is already a member of this trip.");
        }

        // Get the trip
        const trip = await AppDataSource.getRepository(Trip).findOne({
            where: { id: tripId }
        });

        if (!trip) {
            throw new UserInputError("Trip not found.");
        }

        // Create membership with PENDING status (user needs to accept first)
        const membership = AppDataSource.getRepository(TripMembership).create({
            user: userToInvite,
            trip: trip,
            role: TripRole.PENDING // All invitations start as pending
        });

        const savedMembership = await AppDataSource.getRepository(TripMembership).save(membership);

        return {
            id: savedMembership.id,
            tripId: tripId,
            userId: userToInvite.id,
            role: role,
            status: "pending",
            user: userToInvite,
            trip: undefined, // Not needed for this mutation
            createdAt: savedMembership.createdAt
        };
    }

    @Mutation(() => Boolean, { description: "Remove a user from a trip" })
    async removeUserFromTrip(
        @Arg("tripId", () => ID) tripId: string,
        @Arg("userId", () => ID) userIdToRemove: string,
        @Ctx() { userId }: MyContext
    ): Promise<boolean> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to remove users.");
        }

        // Check if user has permission to remove members (must be at least EDITOR)
        if (!(await checkTripAccess(userId, tripId, TripRole.EDITOR))) {
            throw new AuthenticationError("You don't have permission to remove users from this trip.");
        }

        // Cannot remove the owner
        const membershipToRemove = await AppDataSource.getRepository(TripMembership).findOne({
            where: {
                user: { id: userIdToRemove },
                trip: { id: tripId }
            }
        });

        if (!membershipToRemove) {
            throw new UserInputError("User is not a member of this trip.");
        }

        if (membershipToRemove.role === TripRole.OWNER) {
            throw new UserInputError("Cannot remove the owner of the trip.");
        }

        await AppDataSource.getRepository(TripMembership).remove(membershipToRemove);
        return true;
    }

    @Mutation(() => TripMembershipResponse, { description: "Update a user's role in a trip" })
    async updateUserRole(
        @Arg("tripId", () => ID) tripId: string,
        @Arg("userId", () => ID) userIdToUpdate: string,
        @Arg("newRole", () => TripRole) newRole: TripRole,
        @Ctx() { userId }: MyContext
    ): Promise<TripMembershipResponse> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to update user roles.");
        }

        // Check if user has permission to update roles (must be OWNER)
        if (!(await checkTripAccess(userId, tripId, TripRole.OWNER))) {
            throw new AuthenticationError("You must be the owner to update user roles.");
        }

        const membershipToUpdate = await AppDataSource.getRepository(TripMembership).findOne({
            where: {
                user: { id: userIdToUpdate },
                trip: { id: tripId }
            },
            relations: ["user"]
        });

        if (!membershipToUpdate) {
            throw new UserInputError("User is not a member of this trip.");
        }

        // Cannot change owner role
        if (membershipToUpdate.role === TripRole.OWNER) {
            throw new UserInputError("Cannot change the owner's role.");
        }

        membershipToUpdate.role = newRole;
        const updatedMembership = await AppDataSource.getRepository(TripMembership).save(membershipToUpdate);

        return {
            id: updatedMembership.id,
            tripId: tripId,
            userId: userIdToUpdate,
            role: newRole,
            status: "accepted",
            user: membershipToUpdate.user,
            trip: undefined, // Not needed for this mutation
            createdAt: updatedMembership.createdAt
        };
    }

    @Mutation(() => Trip, { description: "Create a new trip" })
    async createTrip(
        @Arg("input") input: TripInput,
        @Ctx() { userId }: MyContext
    ): Promise<Trip> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to create a trip.");
        }
        
        const user = await AppDataSource.getRepository(User).findOneBy({ id: userId });
        if (!user) {
            throw new AuthenticationError("User not found.");
        }

        const tripRepository = AppDataSource.getRepository(Trip);
        const membershipRepository = AppDataSource.getRepository(TripMembership);

        // Create a new trip instance
        const trip = tripRepository.create(input);

        // Use a transaction to save both the trip and the membership
        try {
            await AppDataSource.transaction(async (transactionalEntityManager) => {
                // First save the trip to get its ID
                const savedTrip = await transactionalEntityManager.save(Trip, trip);
                
                // Now create membership with the saved trip
                const membership = membershipRepository.create({
                    user: user,
                    trip: savedTrip,
                    role: TripRole.OWNER,
                });
                
                // Save the membership
                await transactionalEntityManager.save(TripMembership, membership);
                
                // Update the trip reference for return
                Object.assign(trip, savedTrip);
            });
            return trip;
        } catch (error) {
            console.error("Error creating trip with membership:", error);
            throw new Error("Could not create trip.");
        }
    }

    @Mutation(() => Trip, { description: "Update an existing trip" })
    async updateTrip(
        @Arg("id", () => ID) id: string,
        @Arg("input") input: UpdateTripInput,
        @Ctx() { userId }: MyContext
    ): Promise<Trip | null> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in.");
        }
        if (!(await checkTripAccess(userId, id, TripRole.EDITOR))) {
            throw new AuthenticationError("You don't have permission to edit this trip.");
        }

        const trip = await AppDataSource.getRepository(Trip).findOne({ where: { id } });
        if (!trip) {
            return null; // Or throw a NotFoundError
        }

        Object.assign(trip, input);
        await AppDataSource.getRepository(Trip).save(trip);
        return trip;
    }

    @Mutation(() => PresignedUrlResponse, { description: "Generate a pre-signed URL to upload a trip cover image" })
    async generateTripCoverImageUploadUrl(
        @Arg("tripId", () => ID) tripId: string,
        @Arg("contentType") contentType: string
    ): Promise<PresignedUrlResponse> {
        try {
            // Basic content type validation
            const extension = contentType.split('/')[1];
            if (!extension || !['jpeg', 'png', 'jpg', 'webp'].includes(extension)) {
                throw new Error("Invalid content type. Only jpeg, jpg, png, and webp are allowed.");
            }

            const objectName = `trip-${tripId}/cover-${uuidv4()}.${extension}`;
            const uploadUrl = await generatePresignedPutUrl(objectName, contentType);

            return { uploadUrl, objectName };
        } catch (error) {
            console.error("Error generating upload URL:", error);
            throw new Error("Could not generate upload URL.");
        }
    }

    @Mutation(() => Trip, { description: "Assign a new cover image to a trip after upload" })
    async assignCoverImageToTrip(
        @Arg("tripId", () => ID) tripId: string,
        @Arg("objectName") objectName: string
    ): Promise<Trip> {
        const tripRepository = AppDataSource.getRepository(Trip);
        try {
            const trip = await tripRepository.findOneBy({ id: tripId });
            if (!trip) {
                throw new Error("Trip not found.");
            }

            // Optional: Check if the object actually exists in Minio before assigning

            trip.coverImageObjectName = objectName;
            await tripRepository.save(trip);
            return trip;
        } catch (error) {
            console.error("Error assigning cover image:", error);
            throw new Error("Could not assign cover image.");
        }
    }

    @Mutation(() => Boolean, { description: "Delete a trip" })
    async deleteTrip(
        @Arg("id", () => ID) id: string,
        @Ctx() { userId }: MyContext
    ): Promise<boolean> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in.");
        }
        if (!(await checkTripAccess(userId, id, TripRole.OWNER))) {
            throw new AuthenticationError("You must be an owner to delete this trip.");
        }
        
        // Use transaction to ensure proper cleanup order
        try {
            await AppDataSource.transaction(async (transactionalEntityManager) => {
                // First delete all trip memberships
                await transactionalEntityManager.delete(TripMembership, { trip: { id } });
                
                // Then delete the trip itself
                await transactionalEntityManager.delete(Trip, { id });
            });
            
            return true;
        } catch (error) {
            console.error("Error deleting trip:", error);
            throw new Error("Could not delete trip.");
        }
    }

    @FieldResolver(() => [Memory])
    async memories(@Root() trip: Trip): Promise<Memory[]> {
        try {
            const memoryRepository = AppDataSource.getRepository(Memory);
            return await memoryRepository.find({ where: { trip: { id: trip.id } } });
        } catch (error) {
            console.error(`Error fetching memories for trip ${trip.id}:`, error);
            throw new Error("Could not fetch memories for the trip.");
        }
    }

    @FieldResolver(() => String, { nullable: true })
    async coverImageUrl(@Root() trip: Trip): Promise<string | null> {
        if (!trip.coverImageObjectName) return null;
        try {
            return generatePresignedGetUrl(trip.coverImageObjectName, 1800); // 30 minutes expiry
        } catch (error) {
            console.error(`Failed to get cover image URL for ${trip.coverImageObjectName}`, error);
            return null;
        }
    }

    @Query(() => [TripMembershipResponse], { description: "Get pending invitations for current user" })
    async getPendingInvitations(
        @Ctx() { userId }: MyContext
    ): Promise<TripMembershipResponse[]> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to view invitations.");
        }

        const pendingMemberships = await AppDataSource.getRepository(TripMembership).find({
            where: {
                user: { id: userId },
                role: TripRole.PENDING // We need to add this status
            },
            relations: ['user', 'trip']
        });

        return pendingMemberships.map(membership => ({
            id: membership.id,
            tripId: membership.trip.id,
            userId: membership.user.id,
            role: membership.role,
            status: "pending",
            user: membership.user,
            trip: membership.trip,
            createdAt: membership.createdAt
        }));
    }

    @Mutation(() => TripMembershipResponse, { description: "Accept a pending trip invitation" })
    async acceptInvitation(
        @Arg("tripId", () => ID) tripId: string,
        @Ctx() { userId }: MyContext
    ): Promise<TripMembershipResponse> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to accept invitations.");
        }

        // Find pending membership
        const membership = await AppDataSource.getRepository(TripMembership).findOne({
            where: {
                user: { id: userId },
                trip: { id: tripId },
                role: TripRole.PENDING
            },
            relations: ['user', 'trip']
        });

        if (!membership) {
            throw new UserInputError("No pending invitation found for this trip.");
        }

        // Update membership to VIEWER (default after acceptance)
        membership.role = TripRole.VIEWER;
        const updatedMembership = await AppDataSource.getRepository(TripMembership).save(membership);

        return {
            id: updatedMembership.id,
            tripId: updatedMembership.trip.id,
            userId: updatedMembership.user.id,
            role: updatedMembership.role,
            status: "accepted",
            user: updatedMembership.user,
            trip: updatedMembership.trip,
            createdAt: updatedMembership.createdAt
        };
    }

    @Mutation(() => Boolean, { description: "Decline a pending trip invitation" })
    async declineInvitation(
        @Arg("tripId", () => ID) tripId: string,
        @Ctx() { userId }: MyContext
    ): Promise<boolean> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to decline invitations.");
        }

        // Find and delete pending membership
        const result = await AppDataSource.getRepository(TripMembership).delete({
            user: { id: userId },
            trip: { id: tripId },
            role: TripRole.PENDING
        });

        return result.affected ? result.affected > 0 : false;
    }

    @Query(() => [Trip], { description: "Get all trips the user has access to (owned + shared)" })
    async getAccessibleTrips(
        @Ctx() { userId }: MyContext
    ): Promise<Trip[]> {
        if (!userId) {
            throw new AuthenticationError("You must be logged in to view trips.");
        }

        // Get all trips where user is either owner or member (not pending)
        const memberships = await AppDataSource.getRepository(TripMembership).find({
            where: {
                user: { id: userId },
                // Exclude pending invitations
                role: Not(TripRole.PENDING)
            },
            relations: ['trip']
        });

        return memberships.map(membership => membership.trip);
    }
} 