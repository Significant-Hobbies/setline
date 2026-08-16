import CloudKit
import XCTest

@testable import SetlineCore

/// The record mapping is the part of the CloudKit transport that can be tested
/// without a container: a `CKRecord` can be built and read in a simulator, only the
/// network calls around it cannot. Mapping is also where a silent field drop would
/// do the most damage, so it gets covered here rather than left to a device.
final class CloudKitRecordStoreTests: XCTestCase {
    private let zoneID = CKRecordZone.ID(zoneName: "Training", ownerName: CKCurrentUserDefaultName)

    private func roundTrip(_ record: SyncRecord) throws -> SyncRecord {
        let ckRecord = CloudKitRecordStore.ckRecord(from: record, in: zoneID)
        return try XCTUnwrap(CloudKitRecordStore.syncRecord(from: ckRecord))
    }

    func testEveryFieldSurvivesTheRoundTrip() throws {
        let record = SyncRecord(
            kind: .session,
            entityID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            modifiedAt: Date(timeIntervalSince1970: 1_784_505_600),
            payload: Data("a recorded workout".utf8)
        )

        XCTAssertEqual(try roundTrip(record), record)
    }

    func testATombstoneStaysATombstone() throws {
        let record = SyncRecord(
            kind: .goal,
            entityID: UUID(),
            modifiedAt: Date(timeIntervalSince1970: 1_784_505_600),
            payload: nil
        )

        let restored = try roundTrip(record)

        XCTAssertTrue(restored.isDeleted, "a delete that decodes as content would resurrect it")
        XCTAssertEqual(restored, record)
    }

    func testEveryKindMapsBothWays() throws {
        for kind in SyncRecordKind.allCases {
            let record = SyncRecord(
                kind: kind,
                entityID: UUID(),
                modifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
                payload: Data("x".utf8)
            )
            XCTAssertEqual(try roundTrip(record), record, "\(kind.rawValue) did not survive")
        }
    }

    func testTheRecordNameIsTheIdentityCloudKitStoresItUnder() {
        let record = SyncRecord(kind: .template, entityID: UUID(), modifiedAt: .now, payload: Data())
        let ckRecord = CloudKitRecordStore.ckRecord(from: record, in: zoneID)

        XCTAssertEqual(ckRecord.recordID.recordName, record.recordName)
        XCTAssertEqual(ckRecord.recordID.zoneID, zoneID)
        XCTAssertEqual(ckRecord.recordType, "SyncRecord")
    }

    func testSetlinesOwnTimestampIsStoredRatherThanCloudKitsModificationDate() {
        // The merge compares when a device wrote a value. CloudKit's own
        // modificationDate is when a server accepted it, which is a different thing
        // and would let upload order decide who wins.
        let written = Date(timeIntervalSince1970: 1_700_000_000)
        let ckRecord = CloudKitRecordStore.ckRecord(
            from: SyncRecord(kind: .goal, entityID: UUID(), modifiedAt: written, payload: Data()),
            in: zoneID
        )

        XCTAssertEqual(ckRecord["modifiedAt"] as? Date, written)
    }

    func testAMalformedRemoteRecordIsIgnoredRatherThanCrashing() {
        // Anything could be in a zone: an older client, a partial write, or a field
        // that was renamed. Dropping the record is right; trapping is not.
        let incomplete = CKRecord(
            recordType: "SyncRecord",
            recordID: CKRecord.ID(recordName: "goal-not-a-uuid", zoneID: zoneID)
        )
        XCTAssertNil(CloudKitRecordStore.syncRecord(from: incomplete))

        let unknownKind = CKRecord(
            recordType: "SyncRecord",
            recordID: CKRecord.ID(recordName: "mystery-\(UUID().uuidString)", zoneID: zoneID)
        )
        unknownKind["kind"] = "mystery" as CKRecordValue
        unknownKind["entityID"] = UUID().uuidString as CKRecordValue
        unknownKind["modifiedAt"] = Date() as CKRecordValue
        XCTAssertNil(CloudKitRecordStore.syncRecord(from: unknownKind))
    }

}
