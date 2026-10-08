import Foundation
import PersonalSyncKit
import SetlineCore
import XCTest
@testable import Setline

@MainActor
final class SetlineSyncCommitTests: XCTestCase {
    func testMirrorSnapshotCarriesEntitiesTombstonesAndEnvelopeFields() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        let syncStore = SyncStateStore(fileURL: root.appending(path: "sync.json"))
        var document = SetlineDocument.sample
        var template = TwelveWeekProgramme.template(for: .lower, week: 1)
        template.id = UUID()
        template.name = "Synthetic lift"
        template.isBundled = false
        document.templates.append(template)
        try document.startWorkout(templateID: template.id, at: Date(timeIntervalSince1970: 1_700_000_000))
        try document.completeCurrent(
            with: [.init(loadMetrics: .init(weight: 40, repetitions: 8))],
            workSeconds: 32,
            at: Date(timeIntervalSince1970: 1_700_000_032)
        )
        try document.finishWorkout(at: Date(timeIntervalSince1970: 1_700_001_500))
        let session = try XCTUnwrap(document.history.first)
        try await store.save(document)
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(), syncStateStore: syncStore, mirror: nil)
        await model.load()

        var records = try await model.mirrorRecords()
        var byName = Dictionary(uniqueKeysWithValues: records.map { ($0.name, $0) })
        let sessionRecord = try XCTUnwrap(byName[SyncRecord.recordName(kind: .session, entityID: session.id)])
        XCTAssertTrue(sessionRecord.appendOnly)
        XCTAssertFalse(sessionRecord.isDeleted)
        let envelope = try XCTUnwrap(
            JSONSerialization.jsonObject(with: XCTUnwrap(sessionRecord.payload)) as? [String: Any]
        )
        XCTAssertEqual(envelope["recordType"] as? String, "session")
        XCTAssertEqual(envelope["entityId"] as? String, session.id.uuidString.lowercased())
        XCTAssertNotNil(envelope["occurredAt"] as? String)
        XCTAssertNotNil(envelope["data"] as? [String: Any])
        XCTAssertNotNil(byName[SyncRecord.recordName(kind: .template, entityID: template.id)])
        XCTAssertNotNil(byName[SyncRecord.recordName(kind: .programme, entityID: SyncRecordKind.singletonID)])

        // Deleting a template produces a tombstone in the next snapshot.
        try await model.commitMirrorRecords([
            MirrorRecord(
                name: SyncRecord.recordName(kind: .template, entityID: template.id),
                modifiedAt: .now, payload: nil
            ),
        ])
        records = try await model.mirrorRecords()
        byName = Dictionary(uniqueKeysWithValues: records.map { ($0.name, $0) })
        let tombstone = try XCTUnwrap(byName[SyncRecord.recordName(kind: .template, entityID: template.id)])
        XCTAssertTrue(tombstone.isDeleted)
        XCTAssertFalse(tombstone.appendOnly)
    }

    func testPulledSessionAppliesAndReplaysIdempotently() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        let model = AppModel(
            store: store, restNotifier: SyncTestRestNotifier(),
            syncStateStore: SyncStateStore(fileURL: root.appending(path: "sync.json")),
            mirror: nil
        )
        await model.load()
        let session = try makeSession()
        let record = try envelope(.session, entityID: session.id, entity: session)
        let transport = SetlinePullFixture(records: [record])
        let runtime = MirrorRuntime(
            transports: [transport],
            store: try MirrorBookkeepingStore(fileURL: root.appending(path: "mirror.json"))
        )
        _ = try await runtime.synchronize(records: { try await model.mirrorRecords() }) {
            try await model.commitMirrorRecords($0)
        }
        var reopened = try await store.load()
        XCTAssertEqual(reopened.history.map(\.id), [session.id])
        // A replayed pull commits nothing twice.
        _ = try await runtime.synchronize(records: { try await model.mirrorRecords() }) {
            try await model.commitMirrorRecords($0)
        }
        reopened = try await store.load()
        XCTAssertEqual(reopened.history.count, 1)
    }

    func testFailedApplyKeepsPullTokenAndRetriesIntoHistory() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let appFile = root.appending(path: "workouts.json")
        let store = SetlineStore(fileURL: appFile)
        let model = AppModel(
            store: store, restNotifier: SyncTestRestNotifier(),
            syncStateStore: SyncStateStore(fileURL: root.appending(path: "sync.json")),
            mirror: nil
        )
        await model.load()
        let session = try makeSession()
        let transport = SetlinePullFixture(records: [
            try envelope(.session, entityID: session.id, entity: session),
        ])
        let runtime = MirrorRuntime(
            transports: [transport],
            store: try MirrorBookkeepingStore(fileURL: root.appending(path: "mirror.json"))
        )
        try FileManager.default.createDirectory(at: appFile, withIntermediateDirectories: true)
        let failed = try await runtime.synchronize(records: { try await model.mirrorRecords() }) {
            try await model.commitMirrorRecords($0)
        }
        XCTAssertFalse(failed.isComplete, "A failed app write must not acknowledge the download")
        XCTAssertTrue(model.document.history.isEmpty)
        try FileManager.default.removeItem(at: appFile)
        let retried = try await runtime.synchronize(records: { try await model.mirrorRecords() }) {
            try await model.commitMirrorRecords($0)
        }
        XCTAssertTrue(retried.isComplete)
        let reopened = try await store.load()
        XCTAssertEqual(reopened.history.map(\.id), [session.id])
        // Both passes saw an empty pull token: the failed first apply left the
        // download retryable.
        let pullTokens = await transport.pullTokens
        XCTAssertEqual(pullTokens, [nil, nil])
    }

    func testPulledTombstonesRemoveTemplatesAndGoals() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        var document = SetlineDocument.sample
        var template = TwelveWeekProgramme.template(for: .lower, week: 1)
        template.id = UUID()
        template.isBundled = false
        document.templates.append(template)
        let goal = ExerciseGoal(
            id: UUID(), exerciseName: "Synthetic goal",
            metric: .estimatedOneRepMax, targetValue: 100,
            timing: .init(createdAt: .now)
        )
        document.goals.append(goal)
        try await store.save(document)
        let model = AppModel(
            store: store, restNotifier: SyncTestRestNotifier(),
            syncStateStore: SyncStateStore(fileURL: root.appending(path: "sync.json")),
            mirror: nil
        )
        await model.load()
        try await model.commitMirrorRecords([
            MirrorRecord(name: SyncRecord.recordName(kind: .template, entityID: template.id), modifiedAt: .now, payload: nil),
            MirrorRecord(name: SyncRecord.recordName(kind: .goal, entityID: goal.id), modifiedAt: .now, payload: nil),
        ])
        XCTAssertFalse(model.document.templates.contains { $0.id == template.id })
        XCTAssertTrue(model.document.goals.isEmpty)
        let reopened = try await store.load()
        XCTAssertFalse(reopened.templates.contains { $0.id == template.id })
        XCTAssertTrue(reopened.goals.isEmpty)
    }

    func testForeignRecordNamesNeverTouchTheDocument() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        let model = AppModel(
            store: store, restNotifier: SyncTestRestNotifier(),
            syncStateStore: SyncStateStore(fileURL: root.appending(path: "sync.json")),
            mirror: nil
        )
        await model.load()
        // A legacy Hub summary name (bare id, no kind prefix) cannot parse to
        // an entity record and is left alone.
        try await model.commitMirrorRecords([
            MirrorRecord(name: "hub-walk", modifiedAt: .now, payload: Data("{}".utf8)),
            MirrorRecord(name: UUID().uuidString.lowercased(), modifiedAt: .now, payload: Data("{}".utf8)),
        ])
        XCTAssertTrue(model.document.history.isEmpty)
        let stored = try await store.load()
        XCTAssertEqual(stored, model.document)
    }

    func testSessionTombstoneCannotEraseHistory() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        var document = SetlineDocument.sample
        let template = try XCTUnwrap(document.templates.first)
        try document.startWorkout(templateID: template.id, at: Date(timeIntervalSince1970: 1_700_000_000))
        try document.completeCurrent(
            with: [.init(loadMetrics: .init(weight: 40, repetitions: 8))],
            workSeconds: 32,
            at: Date(timeIntervalSince1970: 1_700_000_032)
        )
        try document.finishWorkout(at: Date(timeIntervalSince1970: 1_700_001_500))
        let session = try XCTUnwrap(document.history.first)
        try await store.save(document)
        let model = AppModel(
            store: store, restNotifier: SyncTestRestNotifier(),
            syncStateStore: SyncStateStore(fileURL: root.appending(path: "sync.json")),
            mirror: nil
        )
        await model.load()
        try await model.commitMirrorRecords([
            MirrorRecord(
                name: SyncRecord.recordName(kind: .session, entityID: session.id),
                modifiedAt: .now, payload: nil
            ),
        ])
        // History is append-only: a tombstone for a session is ignored, so a
        // remote deletion can never erase a recorded workout.
        XCTAssertEqual(model.document.history.map(\.id), [session.id])
        let stored = try await store.load()
        XCTAssertEqual(stored.history.map(\.id), [session.id])
    }

    func testStaleRemoteCannotResurrectLocalDeletion() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        var document = SetlineDocument.sample
        var template = TwelveWeekProgramme.template(for: .lower, week: 1)
        template.id = UUID()
        template.isBundled = false
        document.templates.append(template)
        try await store.save(document)
        let model = AppModel(
            store: store, restNotifier: SyncTestRestNotifier(),
            syncStateStore: SyncStateStore(fileURL: root.appending(path: "sync.json")),
            mirror: nil
        )
        await model.load()
        _ = try await model.mirrorRecords() // teach the ledger the template existed
        try await model.commitMirrorRecords([
            MirrorRecord(
                name: SyncRecord.recordName(kind: .template, entityID: template.id),
                modifiedAt: .now, payload: nil
            ),
        ])
        let stale = try envelope(
            .template, entityID: template.id, entity: template,
            modifiedAt: Date(timeIntervalSince1970: 1_600_000_000)
        )
        let transport = SetlinePullFixture(records: [stale])
        let runtime = MirrorRuntime(
            transports: [transport],
            store: try MirrorBookkeepingStore(fileURL: root.appending(path: "mirror.json"))
        )
        _ = try await runtime.synchronize(records: { try await model.mirrorRecords() }) {
            try await model.commitMirrorRecords($0)
        }
        XCTAssertFalse(model.document.templates.contains { $0.id == template.id })
        let pushed = await transport.pushed
        XCTAssertTrue(pushed.contains { $0.name == SyncRecord.recordName(kind: .template, entityID: template.id) && $0.isDeleted },
                      "The tombstone must reach the remote, not be overwritten by it")
    }

    func testTombstoneReplaySurvivesBookkeepingReopen() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        let syncFile = root.appending(path: "sync.json")
        var document = SetlineDocument.sample
        var template = TwelveWeekProgramme.template(for: .lower, week: 1)
        template.id = UUID()
        template.isBundled = false
        document.templates.append(template)
        try await store.save(document)
        let model = AppModel(
            store: store, restNotifier: SyncTestRestNotifier(),
            syncStateStore: SyncStateStore(fileURL: syncFile),
            mirror: nil
        )
        await model.load()
        _ = try await model.mirrorRecords() // teach the ledger the template existed
        try await model.commitMirrorRecords([
            MirrorRecord(
                name: SyncRecord.recordName(kind: .template, entityID: template.id),
                modifiedAt: .now, payload: nil
            ),
        ])
        let name = SyncRecord.recordName(kind: .template, entityID: template.id)
        let afterDelete = try await model.mirrorRecords()
        let first = try XCTUnwrap(afterDelete.first { $0.name == name })
        XCTAssertTrue(first.isDeleted)

        // A relaunched model reads the same document and bookkeeping files.
        let reopened = AppModel(
            store: store, restNotifier: SyncTestRestNotifier(),
            syncStateStore: SyncStateStore(fileURL: syncFile),
            mirror: nil
        )
        await reopened.load()
        let replayedSnapshot = try await reopened.mirrorRecords()
        let replayed = try XCTUnwrap(replayedSnapshot.first { $0.name == name })
        XCTAssertEqual(
            replayed, first,
            "a recorded delete must still travel after reopen, dated when it was deleted rather than redated on every snapshot"
        )
        let secondSnapshot = try await reopened.mirrorRecords()
        let replayedAgain = try XCTUnwrap(secondSnapshot.first { $0.name == name })
        XCTAssertEqual(replayedAgain, first, "successive snapshots must replay the exact tombstone")
    }

    func testTombstoneRetriesReachCloudKitAfterAHubOnlySuccess() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        var document = SetlineDocument.sample
        var template = TwelveWeekProgramme.template(for: .lower, week: 1)
        template.id = UUID()
        template.isBundled = false
        document.templates.append(template)
        try await store.save(document)
        let model = AppModel(
            store: store, restNotifier: SyncTestRestNotifier(),
            syncStateStore: SyncStateStore(fileURL: root.appending(path: "sync.json")),
            mirror: nil
        )
        await model.load()
        _ = try await model.mirrorRecords() // teach the ledger the template existed
        try await model.commitMirrorRecords([
            MirrorRecord(
                name: SyncRecord.recordName(kind: .template, entityID: template.id),
                modifiedAt: .now, payload: nil
            ),
        ])

        // The Hub is reachable; CloudKit holds the pre-delete copy and refuses
        // pushes, so the first pass can only deliver the tombstone to the Hub.
        let hub = SetlineRemoteFixture(id: "hub", records: [])
        let stale = try envelope(
            .template, entityID: template.id, entity: template,
            modifiedAt: Date(timeIntervalSince1970: 1_600_000_000)
        )
        let cloudkit = SetlineRemoteFixture(id: "cloudkit", records: [stale])
        await cloudkit.setFailPushes(true)
        let runtime = MirrorRuntime(
            transports: [hub, cloudkit],
            store: try MirrorBookkeepingStore(fileURL: root.appending(path: "mirror.json"))
        )

        // The pending-change count reads the same snapshot the passes do; it
        // must not be able to consume the tombstone before either remote sees it.
        _ = try await runtime.unpushedCount(transportID: "hub", records: model.mirrorRecords())
        let first = try await runtime.synchronize(records: { try await model.mirrorRecords() }) {
            try await model.commitMirrorRecords($0)
        }
        XCTAssertNil(first.transports.first { $0.transportID == "hub" }?.failure)
        XCTAssertNotNil(first.transports.first { $0.transportID == "cloudkit" }?.failure)
        XCTAssertFalse(
            model.document.templates.contains { $0.id == template.id },
            "the unreachable remote's stale copy must not undo the delete while its push is refused"
        )

        await cloudkit.setFailPushes(false)
        let retried = try await runtime.synchronize(records: { try await model.mirrorRecords() }) {
            try await model.commitMirrorRecords($0)
        }
        XCTAssertTrue(retried.isComplete)

        let name = SyncRecord.recordName(kind: .template, entityID: template.id)
        let hubPushed = await hub.pushed
        let cloudPushed = await cloudkit.pushed
        XCTAssertTrue(
            hubPushed.contains { $0.name == name && $0.isDeleted },
            "the Hub accepted the tombstone on the first pass"
        )
        XCTAssertTrue(
            cloudPushed.contains { $0.name == name && $0.isDeleted },
            "the retry must still carry the tombstone CloudKit missed"
        )
        XCTAssertFalse(model.document.templates.contains { $0.id == template.id })
        let persisted = try await store.load()
        XCTAssertFalse(
            persisted.templates.contains { $0.id == template.id },
            "the old CloudKit copy must never resurrect the deleted template"
        )
    }

    func testPreviouslyUnknownDeletionSurvivesSecondRemoteAndReopen() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        try await store.save(.sample)
        let syncFile = root.appending(path: "sync.json")
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(),
                             syncStateStore: SyncStateStore(fileURL: syncFile), mirror: nil)
        await model.load()
        var template = TwelveWeekProgramme.template(for: .lower, week: 1)
        template.id = UUID()
        template.isBundled = false
        let name = SyncRecord.recordName(kind: .template, entityID: template.id)
        let deletedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let tombstone = MirrorRecord(name: name, modifiedAt: deletedAt, payload: nil)
        let stale = try envelope(.template, entityID: template.id, entity: template,
                                 modifiedAt: deletedAt.addingTimeInterval(-60))
        let hub = SetlineRemoteFixture(id: "hub", records: [tombstone])
        let cloudkit = SetlineRemoteFixture(id: "cloudkit", records: [stale])
        let runtime = MirrorRuntime(transports: [hub, cloudkit],
                                    store: MirrorBookkeepingStore(fileURL: root.appending(path: "mirror.json")))
        let outcome = try await runtime.synchronize(records: { try await model.mirrorRecords() }) {
            try await model.commitMirrorRecords($0)
        }
        XCTAssertTrue(outcome.isComplete)
        XCTAssertFalse(model.document.templates.contains { $0.id == template.id })
        let cloudPushed = await cloudkit.pushed
        XCTAssertTrue(cloudPushed.contains { $0.name == name && $0.isDeleted })
        let reopened = AppModel(store: store, restNotifier: SyncTestRestNotifier(),
                                syncStateStore: SyncStateStore(fileURL: syncFile), mirror: nil)
        await reopened.load()
        let snapshot = try await reopened.mirrorRecords()
        XCTAssertEqual(snapshot.first { $0.name == name }, tombstone)
    }

    func testDeletionKeepsSubsecondOrderingAndIgnoredBundledUpsertAfterReopen() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(), mirror: nil)
        await model.load()
        var template = TwelveWeekProgramme.template(for: .lower, week: 1)
        template.id = UUID()
        let name = SyncRecord.recordName(kind: .template, entityID: template.id)
        let deletedAt = Date(timeIntervalSince1970: 1_800_000_000.75)
        let deletion = MirrorRecord(name: name, modifiedAt: deletedAt, payload: nil)
        try await model.commitMirrorRecords([deletion])
        // Bundled templates are ignored, even if newer: they cannot erase a delete.
        template.isBundled = true
        try await model.commitMirrorRecords([
            envelope(.template, entityID: template.id, entity: template,
                     modifiedAt: deletedAt.addingTimeInterval(10)),
        ])
        let reopened = AppModel(store: store, restNotifier: SyncTestRestNotifier(),
                                syncStateStore: SyncStateStore(fileURL: root.appending(path: "fresh-ledger.json")),
                                mirror: nil)
        await reopened.load()
        template.isBundled = false
        try await reopened.commitMirrorRecords([
            envelope(.template, entityID: template.id, entity: template,
                     modifiedAt: Date(timeIntervalSince1970: 1_800_000_000.5)),
        ])
        XCTAssertFalse(reopened.document.templates.contains { $0.id == template.id })
        let records = try await reopened.mirrorRecords()
        XCTAssertEqual(records.first { $0.name == name }, deletion)
        // Equal-time live winners follow the shared merge policy.
        try await reopened.commitMirrorRecords([
            envelope(.template, entityID: template.id, entity: template, modifiedAt: deletedAt),
        ])
        XCTAssertTrue(reopened.document.templates.contains { $0.id == template.id })
        XCTAssertNil(reopened.document.syncDeletionDates[name])
    }

    func testLocalGoalDeletionPersistsBeforeAnySnapshotAndFailedSaveCanRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "workouts.json")
        let store = SetlineStore(fileURL: file)
        var original = SetlineDocument.initial
        let goal = ExerciseGoal(exerciseName: "Bench press", metric: .topSetLoad, targetValue: 80)
        original.goals.append(goal)
        try await store.save(original)
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(), mirror: nil)
        await model.load()
        let backup = root.appending(path: "original.json")
        try FileManager.default.moveItem(at: file, to: backup)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        await model.deleteGoal(goal)
        XCTAssertTrue(model.document.goals.contains { $0.id == goal.id })
        XCTAssertTrue(model.document.syncDeletionDates.isEmpty)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.moveItem(at: backup, to: file)
        await model.deleteGoal(goal)
        let reopened = AppModel(store: store, restNotifier: SyncTestRestNotifier(),
                                syncStateStore: SyncStateStore(fileURL: root.appending(path: "fresh-ledger.json")),
                                mirror: nil)
        await reopened.load()
        XCTAssertFalse(reopened.document.goals.contains { $0.id == goal.id })
        let records = try await reopened.mirrorRecords()
        let name = SyncRecord.recordName(kind: .goal, entityID: goal.id)
        XCTAssertTrue(try XCTUnwrap(records.first { $0.name == name }).isDeleted)
    }

    func testSavedLocalDeletionInvalidatesAnOlderMirrorSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        var original = SetlineDocument.initial
        let goal = ExerciseGoal(exerciseName: "Bench press", metric: .topSetLoad, targetValue: 80)
        original.goals = [goal]
        try await store.save(original)
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(), mirror: nil)
        await model.load()
        let pass = model.makeMirrorPass()
        await model.deleteGoal(goal)
        do {
            try await model.commitMirrorRecords([
                envelope(.goal, entityID: goal.id, entity: goal),
            ], pass: pass)
            XCTFail("A winner merged against an old document must retry")
        } catch {}
        XCTAssertTrue(model.document.goals.isEmpty)
        let saved = try await store.load()
        XCTAssertTrue(saved.goals.isEmpty)
    }

    func testDownloadCommitDefersWhileWorkoutIsActive() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        var original = SetlineDocument.sample
        try original.startWorkout(
            templateID: try XCTUnwrap(original.templates.first).id,
            at: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try await store.save(original)
        let model = AppModel(
            store: store, restNotifier: SyncTestRestNotifier(),
            syncStateStore: SyncStateStore(fileURL: root.appending(path: "sync.json")),
            mirror: nil
        )
        await model.load()
        do {
            try await model.commitMirrorRecords([
                MirrorRecord(name: "hub-walk", modifiedAt: .now, payload: Data("{}".utf8)),
            ])
            XCTFail("Downloads must defer while a workout is active")
        } catch SetlineHubCommitError.localDocumentUnavailable {}
        XCTAssertEqual(model.document.activeSession, original.activeSession)
        let disk = try await store.load()
        XCTAssertEqual(disk.activeSession, original.activeSession)
    }

    func testApprovedHistoryPersistsAndDifferentAccountCannotRebind() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        let model = AppModel(
            store: store, restNotifier: SyncTestRestNotifier(),
            syncStateStore: SyncStateStore(fileURL: root.appending(path: "sync.json")),
            mirror: nil
        )
        await model.load()
        let approved = await model.approveLocalHubHistory(for: "a")
        XCTAssertTrue(approved)
        let persisted = try await store.load()
        XCTAssertEqual(persisted.hubAccountID, "a")
        let rebound = await model.approveLocalHubHistory(for: "b")
        XCTAssertFalse(rebound)
        XCTAssertEqual(model.document.hubAccountID, "a")
    }

    func testFailedApprovalSaveDoesNotClaimOwnershipAndCanRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "workouts.json")
        let store = SetlineStore(fileURL: file)
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(), mirror: nil)
        await model.load()
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        let failed = await model.approveLocalHubHistory(for: "a")
        XCTAssertFalse(failed)
        XCTAssertNil(model.document.hubAccountID)
        try FileManager.default.removeItem(at: file)
        let retried = await model.approveLocalHubHistory(for: "a")
        XCTAssertTrue(retried)
        let reopened = try await store.load()
        XCTAssertEqual(reopened.hubAccountID, "a")
    }

    func testActiveWorkoutBlocksApprovalWithoutChangingItsSavedState() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        var original = SetlineDocument.sample
        try original.startWorkout(template: XCTUnwrap(original.templates.first))
        try await store.save(original)
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(), mirror: nil)
        await model.load()
        let rejected = await model.approveLocalHubHistory(for: "a")
        XCTAssertFalse(rejected)
        let persisted = try await store.load()
        XCTAssertEqual(persisted, model.document)
        XCTAssertNil(persisted.hubAccountID)
        XCTAssertEqual(persisted.activeSession?.id, original.activeSession?.id)
    }

    func testLegacySessionDecodesWithoutProvenance() throws {
        let session = WorkoutSession(
            context: .init(templateID: UUID(), templateName: "Synthetic", startedAt: .now),
            state: .init(steps: [])
        )
        let data = try SyncEngine.makeEncoder().encode(session)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "hubRecordID")
        let legacy = try SyncEngine.makeDecoder().decode(
            WorkoutSession.self, from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertNil(legacy.hubRecordID)
        XCTAssertEqual(legacy.id, session.id)
    }

    // MARK: - Fixtures

    private func makeSession() throws -> WorkoutSession {
        var document = SetlineDocument.sample
        let template = try XCTUnwrap(document.templates.first)
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try document.startWorkout(templateID: template.id, at: startedAt)
        try document.completeCurrent(
            with: [.init(loadMetrics: .init(weight: 40, repetitions: 8))],
            workSeconds: 32,
            at: startedAt.addingTimeInterval(32)
        )
        try document.finishWorkout(at: startedAt.addingTimeInterval(1_500))
        return try XCTUnwrap(document.history.first)
    }

    private func envelope(
        _ kind: SyncRecordKind,
        entityID: UUID,
        entity: some Encodable,
        occurredAt: Date = .now,
        modifiedAt: Date = .now
    ) throws -> MirrorRecord {
        let raw = try SyncEngine.makeEncoder().encode(entity)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        let payload = try JSONSerialization.data(
            withJSONObject: [
                "recordType": kind.rawValue,
                "entityId": entityID.uuidString.lowercased(),
                "occurredAt": ISO8601DateFormatter().string(from: occurredAt),
                "data": object,
            ],
            options: [.sortedKeys]
        )
        return MirrorRecord(
            name: SyncRecord.recordName(kind: kind, entityID: entityID),
            modifiedAt: modifiedAt,
            payload: payload,
            appendOnly: kind.isAppendOnly
        )
    }
}

@MainActor
private final class SyncTestRestNotifier: RestNotifying {
    func update(for rest: RestState?, nextStep: WorkoutStep?) async {}
}

private actor SetlinePullFixture: MirrorTransport {
    let id = "hub"
    private(set) var pullTokens: [Data?] = []
    private(set) var pushed: [MirrorRecord] = []
    let records: [MirrorRecord]

    init(records: [MirrorRecord]) { self.records = records }

    func availability() async -> MirrorAvailability { .available }
    func push(_ records: [MirrorRecord]) async throws { pushed.append(contentsOf: records) }
    func pull(since token: Data?) async throws -> MirrorPullPage {
        pullTokens.append(token)
        return MirrorPullPage(records: token == nil ? records : [], nextToken: Data("t".utf8))
    }
}

/// A remote that keeps what it accepted and can refuse pushes, so one leg of a
/// dual-mirror pass can succeed while the other stays pending for a retry.
private actor SetlineRemoteFixture: MirrorTransport {
    let id: String
    private(set) var pushed: [MirrorRecord] = []
    private var records: [MirrorRecord]
    private var failPushes = false

    init(id: String, records: [MirrorRecord]) {
        self.id = id
        self.records = records
    }

    func setFailPushes(_ value: Bool) { failPushes = value }

    func availability() async -> MirrorAvailability { .available }
    func push(_ records: [MirrorRecord]) async throws {
        if failPushes { throw MirrorSyncError.unavailable("synthetic outage") }
        pushed.append(contentsOf: records)
        for record in records {
            if let index = self.records.firstIndex(where: { $0.name == record.name }) {
                self.records[index] = record
            } else {
                self.records.append(record)
            }
        }
    }
    func pull(since token: Data?) async throws -> MirrorPullPage {
        MirrorPullPage(records: token == nil ? records : [], nextToken: Data("t".utf8))
    }
}
