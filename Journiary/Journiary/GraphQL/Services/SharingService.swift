import Foundation

class SharingService {
    static let shared = SharingService()
    private init() {}

    // User zu Trip einladen
    func inviteUserToTrip(tripId: String, email: String, permission: Permission) async throws {
        // TODO: GraphQL-Mutation für Einladung implementieren
        throw NSError(domain: "SharingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "inviteUserToTrip ist noch nicht implementiert"])
    }

    // User aus Trip entfernen
    func removeUserFromTrip(tripId: String, userId: String) async throws {
        // TODO: GraphQL-Mutation für Entfernen implementieren
        throw NSError(domain: "SharingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "removeUserFromTrip ist noch nicht implementiert"])
    }

    // Berechtigung eines Users ändern
    func updatePermission(tripId: String, userId: String, permission: Permission) async throws {
        // TODO: GraphQL-Mutation für Berechtigungsänderung implementieren
        throw NSError(domain: "SharingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "updatePermission ist noch nicht implementiert"])
    }

    // Geteilte Trips abrufen
    func getSharedTrips() async throws -> [TripDTO] {
        // TODO: GraphQL-Query für geteilte Trips implementieren
        throw NSError(domain: "SharingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "getSharedTrips ist noch nicht implementiert"])
    }

    // Einladung annehmen
    func acceptInvitation(invitationId: String) async throws {
        // TODO: GraphQL-Mutation für Einladung annehmen implementieren
        throw NSError(domain: "SharingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "acceptInvitation ist noch nicht implementiert"])
    }

    // Einladung ablehnen
    func declineInvitation(invitationId: String) async throws {
        // TODO: GraphQL-Mutation für Einladung ablehnen implementieren
        throw NSError(domain: "SharingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "declineInvitation ist noch nicht implementiert"])
    }
} 