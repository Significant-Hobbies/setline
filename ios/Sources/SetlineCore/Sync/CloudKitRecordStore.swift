import CloudKit
import Foundation

/// CloudKit transport for `SyncRecord`, in the user's private database.
///
/// Private database only: Setline's records are one person's training, so there is
/// no shared or public zone and no server-side logic that could read them. A custom
/// zone rather than the default one, because only a custom zone supports fetching
/// changes by token — the default zone would force a full compare on every sync.
///
/// This type holds no merge rules. It moves records and reports whether iCloud is
/// usable; `SyncEngine` decides what wins.
public struct CloudKitRecordStore: RemoteRecordStore {
    public static let containerIdentifier = "iCloud.com.significanthobbies.setline"
    static let zoneName = "Training"
    static let recordType = "SyncRecord"

    private let container: CKContainer
    private let zoneID: CKRecordZone.ID

    public init(containerIdentifier: String = CloudKitRecordStore.containerIdentifier) {
        container = CKContainer(identifier: containerIdentifier)
        zoneID = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    private var database: CKDatabase { container.privateCloudDatabase }

    public func availability() async -> SyncAvailability {
        do {
            switch try await container.accountStatus() {
            case .available:
                return .available
            case .noAccount:
                return .noAccount
            case .restricted:
                return .restricted
            case .couldNotDetermine:
                return .unknown("iCloud status could not be determined")
            case .temporarilyUnavailable:
                return .unknown("iCloud is temporarily unavailable")
            @unknown default:
                return .unknown("Unrecognised iCloud status")
            }
        } catch {
            // A missing container reads as an error here rather than a status, and it
            // means the build is not provisioned rather than that the user did
            // anything wrong. Saying so beats a generic failure.
            return .containerUnavailable
        }
    }

    public func changes(since token: Data?) async throws -> RemoteChanges {
        try await ensureZoneExists()

        var serverToken: CKServerChangeToken?
        if let token {
            serverToken = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self,
                from: token
            )
        }

        do {
            return try await fetchChanges(since: serverToken)
        } catch let error as CKError where error.code == .changeTokenExpired {
            // The server no longer recognises the token, so everything is refetched.
            // That is safe precisely because absence never means deletion here: only
            // an explicit tombstone removes anything.
            return try await fetchChanges(since: nil)
        }
    }

    private func fetchChanges(since token: CKServerChangeToken?) async throws -> RemoteChanges {
        var records: [SyncRecord] = []
        var deletedNames: [String] = []
        var nextToken: CKServerChangeToken?
        var cursor = token
        var hasMore = true

        while hasMore {
            let result = try await database.recordZoneChanges(inZoneWith: zoneID, since: cursor)
            for modification in result.modificationResultsByID.values {
                guard let record = try? modification.get().record else { continue }
                if let mapped = Self.syncRecord(from: record) { records.append(mapped) }
            }
            // CloudKit deletions are how a purge shows up. Setline expresses deletion
            // as a tombstone record instead, so a hard delete carries no timestamp to
            // merge on; it is recorded at the fetch time it was observed.
            deletedNames.append(contentsOf: result.deletions.map(\.recordID.recordName))
            nextToken = result.changeToken
            cursor = result.changeToken
            hasMore = result.moreComing
        }

        for name in deletedNames {
            guard let (kind, entityID) = SyncEngine.parse(name), !kind.isAppendOnly else { continue }
            records.append(
                SyncRecord(kind: kind, entityID: entityID, modifiedAt: .now, payload: nil)
            )
        }

        return RemoteChanges(
            records: records,
            token: nextToken.flatMap {
                try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
            }
        )
    }

    public func save(_ records: [SyncRecord]) async throws {
        guard !records.isEmpty else { return }
        try await ensureZoneExists()
        // CloudKit caps a single operation at 400 changes; batching keeps a large
        // first sync from failing wholesale.
        for batch in stride(from: 0, to: records.count, by: 300).map({ offset in
            Array(records[offset..<min(offset + 300, records.count)])
        }) {
            _ = try await database.modifyRecords(
                saving: batch.map { Self.ckRecord(from: $0, in: zoneID) },
                deleting: [],
                savePolicy: .changedKeys,
                atomically: false
            )
        }
    }

    private func ensureZoneExists() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            _ = try await database.modifyRecordZones(saving: [zone], deleting: [])
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Already there, which is the normal case after the first run.
            return
        }
    }

    // MARK: - Mapping

    static func ckRecord(from record: SyncRecord, in zoneID: CKRecordZone.ID) -> CKRecord {
        let id = CKRecord.ID(recordName: record.recordName, zoneID: zoneID)
        let ckRecord = CKRecord(recordType: recordType, recordID: id)
        ckRecord["kind"] = record.kind.rawValue as CKRecordValue
        ckRecord["entityID"] = record.entityID.uuidString as CKRecordValue
        // Setline's own timestamp, not CloudKit's modification date: the merge has to
        // compare when a device wrote a value, not when a server accepted it.
        ckRecord["modifiedAt"] = record.modifiedAt as CKRecordValue
        ckRecord["payload"] = record.payload as CKRecordValue?
        return ckRecord
    }

    static func syncRecord(from ckRecord: CKRecord) -> SyncRecord? {
        guard let rawKind = ckRecord["kind"] as? String,
              let kind = SyncRecordKind(rawValue: rawKind),
              let rawID = ckRecord["entityID"] as? String,
              let entityID = UUID(uuidString: rawID),
              let modifiedAt = ckRecord["modifiedAt"] as? Date
        else { return nil }
        return SyncRecord(
            kind: kind,
            entityID: entityID,
            modifiedAt: modifiedAt,
            payload: ckRecord["payload"] as? Data
        )
    }
}
