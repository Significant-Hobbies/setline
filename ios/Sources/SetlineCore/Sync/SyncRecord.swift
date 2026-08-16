import Foundation

/// One synchronisable unit of training.
///
/// Setline syncs per record rather than as one document. A whole-document copy
/// forces a person to choose between two versions of their training whenever two
/// devices both wrote, which is a decision no one can make correctly mid-workout.
/// Per record, the common cases resolve themselves: two phones that recorded
/// different sessions simply end up with both.
///
/// The payload is the entity encoded exactly as the local document encodes it, so
/// there is one serialisation format rather than a second, drifting one.
public struct SyncRecord: Equatable, Sendable {
    public var kind: SyncRecordKind
    /// Identity of the entity, or `SyncRecordKind.singletonID` for the one-per-account
    /// records such as the programme selection.
    public var entityID: UUID
    /// When this version was written. Comparable across devices only as well as
    /// their clocks are, which is why history never resolves by time.
    public var modifiedAt: Date
    /// Absent for a tombstone: the record exists to say the entity was deleted.
    public var payload: Data?

    public init(kind: SyncRecordKind, entityID: UUID, modifiedAt: Date, payload: Data?) {
        self.kind = kind
        self.entityID = entityID
        self.modifiedAt = modifiedAt
        self.payload = payload
    }

    public var isDeleted: Bool { payload == nil }

    /// Stable, collision-free name for the record in its zone.
    public var recordName: String { Self.recordName(kind: kind, entityID: entityID) }

    public static func recordName(kind: SyncRecordKind, entityID: UUID) -> String {
        "\(kind.rawValue)-\(entityID.uuidString)"
    }
}

public enum SyncRecordKind: String, Codable, Sendable, CaseIterable {
    case template
    case session
    case goal
    case programme

    /// History is a log of things that happened. A completed session is never
    /// edited and never deleted, so merging it is a union and time never decides
    /// anything — which also means a wrong device clock cannot lose a workout.
    public var isAppendOnly: Bool { self == .session }

    /// The identity used by kinds that have exactly one record.
    public static let singletonID = UUID(uuidString: "5E71C0DE-0000-0000-0000-00000000FFFF")!
}

/// Remembers what each record looked like when it was last written, so a local
/// edit can be dated without every domain type carrying an `updatedAt` field.
///
/// Adding `updatedAt` to `WorkoutTemplate` and `ExerciseGoal` would have put sync
/// bookkeeping inside the training model, where it would need maintaining by every
/// call site that mutates one and would be wrong the moment a call site forgot.
/// Fingerprinting the encoded payload cannot be forgotten.
public struct SyncLedger: Codable, Equatable, Sendable {
    public struct Stamp: Codable, Equatable, Sendable {
        public var fingerprint: String
        public var modifiedAt: Date

        public init(fingerprint: String, modifiedAt: Date) {
            self.fingerprint = fingerprint
            self.modifiedAt = modifiedAt
        }
    }

    public var stamps: [String: Stamp]

    public init(stamps: [String: Stamp] = [:]) {
        self.stamps = stamps
    }

    /// Dates a record: unchanged payloads keep the timestamp they already had, so
    /// re-reading a document does not make every record look freshly edited and
    /// win every merge.
    public mutating func stamp(_ record: SyncRecord, now: Date) -> Date {
        let fingerprint = Self.fingerprint(of: record.payload)
        if let existing = stamps[record.recordName], existing.fingerprint == fingerprint {
            return existing.modifiedAt
        }
        stamps[record.recordName] = Stamp(fingerprint: fingerprint, modifiedAt: now)
        return now
    }

    static func fingerprint(of payload: Data?) -> String {
        guard let payload else { return "deleted" }
        // Not a cryptographic digest: this only has to change when the bytes do,
        // and it must stay identical across OS versions, so no Hasher seeding.
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in payload {
            hash ^= UInt64(byte)
            hash = hash.multipliedReportingOverflow(by: 0x100_0000_01b3).partialValue
        }
        return String(hash, radix: 16)
    }
}
