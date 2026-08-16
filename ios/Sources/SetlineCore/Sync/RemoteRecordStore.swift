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

/// What a sync round trip changed.
public struct SyncOutcome: Equatable, Sendable {
    public var pushed: Int
    public var pulled: Int
    public var completedAt: Date

    public init(pushed: Int, pulled: Int, completedAt: Date) {
        self.pushed = pushed
        self.pulled = pulled
        self.completedAt = completedAt
    }

    public var changedAnything: Bool { pushed > 0 || pulled > 0 }
}

/// A batch of remote changes plus the token that resumes from after them.
///
/// There is deliberately no "this was a full resync" flag. The merge never infers a
/// deletion from a record's absence — only from an explicit tombstone — so refetching
/// everything is indistinguishable from an incremental fetch, and nothing downstream
/// needs to know which happened.
public struct RemoteChanges: Equatable, Sendable {
    public var records: [SyncRecord]
    public var token: Data?

    public init(records: [SyncRecord], token: Data?) {
        self.records = records
        self.token = token
    }
}

/// The transport, kept behind a protocol so the merge and the round-trip logic are
/// testable without a container, a network, or an iCloud account.
public protocol RemoteRecordStore: Sendable {
    func availability() async -> SyncAvailability
    /// Records changed since `token`. A nil token means "everything".
    func changes(since token: Data?) async throws -> RemoteChanges
    func save(_ records: [SyncRecord]) async throws
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
