import Foundation
import CoreData

extension TripMembership {
    enum Permission: String, CaseIterable {
        case read, write, admin
    }

    enum Status: String, CaseIterable {
        case pending, accepted, declined
    }

    var permissionEnum: Permission {
        get { Permission(rawValue: permission ?? "read") ?? .read }
        set { permission = newValue.rawValue }
    }

    var statusEnum: Status {
        get { Status(rawValue: status ?? "pending") ?? .pending }
        set { status = newValue.rawValue }
    }

    convenience init(context: NSManagedObjectContext,
                     id: UUID = UUID(),
                     trip: Trip,
                     user: User,
                     permission: Permission,
                     invitedBy: User? = nil,
                     invitedAt: Date? = nil,
                     joinedAt: Date? = nil,
                     status: Status = .pending) {
        self.init(context: context)
        self.id = id
        self.trip = trip
        self.user = user
        self.permission = permission.rawValue
        self.invitedBy = invitedBy
        self.invitedAt = invitedAt
        self.joinedAt = joinedAt
        self.status = status.rawValue
    }
} 