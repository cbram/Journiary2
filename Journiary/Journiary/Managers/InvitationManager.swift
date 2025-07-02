import Foundation
import Combine

@MainActor
class Invitation: Identifiable, ObservableObject {
    let id: String
    let email: String
    let tripId: String
    let permission: Permission
    @Published var status: Status
    
    enum Status: String, CaseIterable {
        case pending, accepted, declined
    }
    
    init(id: String = UUID().uuidString, email: String, tripId: String, permission: Permission, status: Status = .pending) {
        self.id = id
        self.email = email
        self.tripId = tripId
        self.permission = permission
        self.status = status
    }
}

@MainActor
class InvitationManager: ObservableObject {
    @Published var pendingInvitations: [Invitation] = []
    
    // Einladung versenden
    func sendInvitation(email: String, tripId: String, permission: Permission) async throws {
        guard Self.isValidEmail(email) else {
            throw NSError(domain: "InvitationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ungültige E-Mail-Adresse"])
        }
        // TODO: User-Lookup und Einladung via SharingService
        // Platzhalter: Einladung lokal anlegen
        let invitation = Invitation(email: email, tripId: tripId, permission: permission)
        self.pendingInvitations.append(invitation)
    }
    
    // Einladung annehmen/ablehnen
    func handleInvitationResponse(accepted: Bool, invitation: Invitation) async throws {
        // TODO: Backend-Call via SharingService
        invitation.status = accepted ? .accepted : .declined
        // Optional: Aus pendingInvitations entfernen
        self.pendingInvitations.removeAll { $0.id == invitation.id }
    }
    
    // Email-Validierung
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    // User-Lookup (Platzhalter)
    func lookupUser(byEmail email: String) async -> Bool {
        // TODO: Implementiere echten User-Lookup via Backend
        return true // Platzhalter: Immer erfolgreich
    }
} 