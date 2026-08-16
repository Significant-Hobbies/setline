import XCTest

@testable import SetlineCore

/// The merge is the only part of syncing that can silently destroy recorded
/// training, so these tests are about loss and determinism rather than plumbing.
final class SyncEngineTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 1_784_505_600)

    private func record(
        _ kind: SyncRecordKind,
        _ id: UUID,
        at offset: TimeInterval,
        payload: String? = "a"
    ) -> SyncRecord {
        SyncRecord(
            kind: kind,
            entityID: id,
            modifiedAt: epoch.addingTimeInterval(offset),
            payload: payload.map { Data($0.utf8) }
        )
    }

    // MARK: - History

    func testHistoryFromTwoDevicesUnionsRatherThanReplacing() {
        let mine = record(.session, UUID(), at: 0)
        let theirs = record(.session, UUID(), at: 10)

        let result = SyncEngine.merge(local: [mine], remote: [theirs])

        XCTAssertEqual(result.merged.count, 2, "both workouts must survive")
        XCTAssertEqual(result.toPush, [mine])
        XCTAssertEqual(result.toPull, [theirs])
    }

    func testACompletedSessionSurvivesATombstone() {
        // Nothing in the app deletes a workout, so a session tombstone can only be
        // corruption or a stale device. It must never win.
        let id = UUID()
        let real = record(.session, id, at: 0)
        let deletion = record(.session, id, at: 999, payload: nil)

        XCTAssertEqual(SyncEngine.merge(local: [real], remote: [deletion]).merged, [real])
        XCTAssertEqual(SyncEngine.merge(local: [deletion], remote: [real]).merged, [real])
    }

    // MARK: - Last writer wins

    func testLaterEditWinsForTemplatesAndGoals() {
        let id = UUID()
        let older = record(.template, id, at: 0, payload: "old")
        let newer = record(.template, id, at: 60, payload: "new")

        let result = SyncEngine.merge(local: [older], remote: [newer])

        XCTAssertEqual(result.merged, [newer])
        XCTAssertEqual(result.toPull, [newer], "the local copy is behind and must be replaced")
        XCTAssertTrue(result.toPush.isEmpty)
    }

    func testADeleteWinsOverAnOlderEdit() {
        let id = UUID()
        let edit = record(.goal, id, at: 0, payload: "target")
        let deletion = record(.goal, id, at: 60, payload: nil)

        XCTAssertEqual(SyncEngine.merge(local: [edit], remote: [deletion]).merged, [deletion])
    }

    func testAnEditAfterADeleteResurrectsTheEntity() {
        // Re-creating a goal after deleting it elsewhere is a legitimate action.
        let id = UUID()
        let deletion = record(.goal, id, at: 0, payload: nil)
        let edit = record(.goal, id, at: 60, payload: "target")

        XCTAssertEqual(SyncEngine.merge(local: [deletion], remote: [edit]).merged, [edit])
    }

    // MARK: - Determinism

    func testIdenticalTimestampsResolveTheSameWayOnBothDevices() {
        let id = UUID()
        let mine = record(.template, id, at: 0, payload: "aaa")
        let theirs = record(.template, id, at: 0, payload: "bbb")

        let onMyPhone = SyncEngine.merge(local: [mine], remote: [theirs]).merged
        let onTheirPhone = SyncEngine.merge(local: [theirs], remote: [mine]).merged

        XCTAssertEqual(onMyPhone, onTheirPhone, "a tie must not depend on which side you are")
    }

    func testMergingAnAlreadyMergedResultChangesNothing() {
        let templateID = UUID()
        let local = [record(.session, UUID(), at: 0), record(.template, templateID, at: 5)]
        let remote = [record(.session, UUID(), at: 10), record(.template, templateID, at: 20, payload: "b")]

        let first = SyncEngine.merge(local: local, remote: remote)
        let second = SyncEngine.merge(local: first.merged, remote: first.merged)

        XCTAssertEqual(second.merged, first.merged)
        XCTAssertTrue(second.isUpToDate, "a settled merge must not keep proposing work")
    }

    func testAnEmptyRemoteIsTreatedAsAFirstSyncNotAsDeletion() {
        let local = [record(.session, UUID(), at: 0), record(.goal, UUID(), at: 1)]

        let result = SyncEngine.merge(local: local, remote: [])

        XCTAssertEqual(result.merged.count, 2)
        XCTAssertEqual(result.toPush.count, 2)
        XCTAssertTrue(result.toPull.isEmpty)
    }

    // MARK: - Ledger

    func testAnUnchangedRecordKeepsItsOriginalDate() throws {
        var document = SetlineDocument.sample
        document.goals = [ExerciseGoal(exerciseName: "Bench press", metric: .estimatedOneRepMax, targetValue: 90)]
        var ledger = SyncLedger()

        let first = try SyncEngine.records(for: document, ledger: &ledger, now: epoch)
        let second = try SyncEngine.records(
            for: document,
            ledger: &ledger,
            now: epoch.addingTimeInterval(3600)
        )

        XCTAssertEqual(
            first.map(\.modifiedAt),
            second.map(\.modifiedAt),
            "re-reading a document must not make every record look freshly edited"
        )
    }

    func testAnEditedRecordTakesTheNewDate() throws {
        var document = SetlineDocument.sample
        let goal = ExerciseGoal(exerciseName: "Bench press", metric: .estimatedOneRepMax, targetValue: 90)
        document.goals = [goal]
        var ledger = SyncLedger()
        _ = try SyncEngine.records(for: document, ledger: &ledger, now: epoch)

        var edited = goal
        edited.targetValue = 95
        document.goals = [edited]
        let later = epoch.addingTimeInterval(3600)
        let records = try SyncEngine.records(for: document, ledger: &ledger, now: later)

        let goalRecord = try XCTUnwrap(records.first { $0.kind == .goal })
        XCTAssertEqual(goalRecord.modifiedAt, later)
    }

    func testDeletingAGoalProducesATombstoneSoTheDeleteTravels() throws {
        var document = SetlineDocument.sample
        let goal = ExerciseGoal(exerciseName: "Bench press", metric: .estimatedOneRepMax, targetValue: 90)
        document.goals = [goal]
        var ledger = SyncLedger()
        _ = try SyncEngine.records(for: document, ledger: &ledger, now: epoch)

        document.goals = []
        let later = epoch.addingTimeInterval(60)
        _ = try SyncEngine.records(for: document, ledger: &ledger, now: later)
        let tombstones = SyncEngine.tombstones(for: document, ledger: &ledger, now: later)

        XCTAssertEqual(tombstones.count, 1)
        XCTAssertEqual(tombstones.first?.entityID, goal.id)
        XCTAssertTrue(tombstones.first?.isDeleted == true)
    }

    func testATombstoneIsNotReissuedOnEverySync() throws {
        var document = SetlineDocument.sample
        document.goals = [ExerciseGoal(exerciseName: "Bench press", metric: .estimatedOneRepMax, targetValue: 90)]
        var ledger = SyncLedger()
        _ = try SyncEngine.records(for: document, ledger: &ledger, now: epoch)

        document.goals = []
        let later = epoch.addingTimeInterval(60)
        XCTAssertEqual(SyncEngine.tombstones(for: document, ledger: &ledger, now: later).count, 1)
        XCTAssertTrue(
            SyncEngine.tombstones(for: document, ledger: &ledger, now: later.addingTimeInterval(60)).isEmpty,
            "a delete already recorded must not keep being re-announced"
        )
    }

    // MARK: - Round trip

    func testADocumentSurvivesEncodingToRecordsAndBack() throws {
        var document = SetlineDocument.demoWithEvidence
        document.goals = [ExerciseGoal(exerciseName: "Bench press", metric: .estimatedOneRepMax, targetValue: 90)]
        var ledger = SyncLedger()

        let records = try SyncEngine.records(for: document, ledger: &ledger, now: epoch)
        let restored = try SyncEngine.document(from: records, applyingTo: document)

        XCTAssertEqual(restored.history.count, document.history.count)
        XCTAssertEqual(Set(restored.history.map(\.id)), Set(document.history.map(\.id)))
        XCTAssertEqual(restored.goals, document.goals)
        XCTAssertEqual(restored.programme, document.programme)
        XCTAssertEqual(
            Set(restored.templates.map(\.id)),
            Set(document.templates.map(\.id)),
            "bundled templates come from the app, custom ones from records; both must be present"
        )
    }

    func testTheActiveSessionIsNeverSynced() throws {
        var document = SetlineDocument.sample
        document.programme = .none
        let template = try XCTUnwrap(document.templates.first)
        try document.startWorkout(template: template)
        XCTAssertNotNil(document.activeSession)
        var ledger = SyncLedger()

        let records = try SyncEngine.records(for: document, ledger: &ledger, now: epoch)
        let activeIDs = Set(records.filter { $0.kind == .session }.map(\.entityID))

        XCTAssertFalse(
            activeIDs.contains(try XCTUnwrap(document.activeSession?.id)),
            "a workout in progress belongs to the phone running it"
        )
    }

    func testBundledTemplatesAreNotSyncedAsRecords() throws {
        var document = SetlineDocument.sample
        var ledger = SyncLedger()
        XCTAssertTrue(document.templates.contains { $0.isBundled })

        let records = try SyncEngine.records(for: document, ledger: &ledger, now: epoch)
        let syncedTemplateIDs = Set(records.filter { $0.kind == .template }.map(\.entityID))
        let bundledIDs = Set(document.templates.filter(\.isBundled).map(\.id))

        XCTAssertTrue(
            syncedTemplateIDs.isDisjoint(with: bundledIDs),
            "shipping content should not travel through a person's iCloud account"
        )
        document.templates = []
        _ = try SyncEngine.records(for: document, ledger: &ledger, now: epoch)
        XCTAssertTrue(
            SyncEngine.tombstones(for: document, ledger: &ledger, now: epoch).isEmpty,
            "a bundled template that was never a record cannot become a tombstone"
        )
    }

    func testRecordNamesRoundTripThroughParsing() {
        let id = UUID()
        for kind in SyncRecordKind.allCases {
            let name = SyncRecord.recordName(kind: kind, entityID: id)
            let parsed = SyncEngine.parse(name)
            XCTAssertEqual(parsed?.0, kind)
            XCTAssertEqual(parsed?.1, id)
        }
    }
}
