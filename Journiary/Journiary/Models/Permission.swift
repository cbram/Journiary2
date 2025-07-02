import Foundation
import CloudKit

enum Permission: String, CaseIterable, Codable, Equatable {
    case read
    case write
    case admin

    // Prüft, ob die aktuelle Permission mindestens die geforderte Permission ist
    func hasPermission(_ required: Permission) -> Bool {
        switch (self, required) {
        case (.admin, _): return true
        case (.write, .write), (.write, .read): return true
        case (.read, .read): return true
        default: return false
        }
    }

    // Lokalisierte Beschreibung
    var localizedDescription: String {
        switch self {
        case .read: return NSLocalizedString("Nur Lesen", comment: "Permission: Read")
        case .write: return NSLocalizedString("Bearbeiten", comment: "Permission: Write")
        case .admin: return NSLocalizedString("Administrator", comment: "Permission: Admin")
        }
    }

    // Mapping zu CloudKit
    var ckSharePermission: CKShare.ParticipantPermission {
        switch self {
        case .read: return .readOnly
        case .write: return .readWrite
        case .admin: return .unknown // CloudKit kennt kein echtes Admin
        }
    }

    // Mapping von CloudKit
    static func from(ckPermission: CKShare.ParticipantPermission) -> Permission {
        switch ckPermission {
        case .readOnly: return .read
        case .readWrite: return .write
        default: return .read // Fallback
        }
    }
} 