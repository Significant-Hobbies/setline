import Foundation

/// Whether syncing is possible at all, and why not when it is not.
///
/// Every case is something the interface has to be able to say out loud. "Sync is
/// off" with no reason is the state that makes people distrust a sync feature.
public enum SyncAvailability: Equatable, Sendable {
    case available
    /// No iCloud account on the device, or the user is signed out.
    case noAccount
    /// Signed in but restricted, e.g. by Screen Time or a managed device.
    case restricted
    /// The app is not provisioned for CloudKit yet.
    case containerUnavailable
    case unknown(String)

    public var isAvailable: Bool { self == .available }
}

/// Errors worth telling a person about, as opposed to retrying silently.
public enum SyncError: LocalizedError, Equatable {
    case unavailable(SyncAvailability)
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable(.noAccount):
            "Sign in to iCloud in Settings to sync your training between devices."
        case .unavailable(.restricted):
            "iCloud is restricted on this device, so Setline cannot sync."
        case .unavailable(.containerUnavailable):
            "Setline's iCloud container is not available on this build."
        case let .unavailable(.unknown(detail)):
            "iCloud is unavailable: \(detail)"
        case .unavailable(.available):
            nil
        case let .transport(detail):
            "Sync could not finish: \(detail)"
        }
    }
}
