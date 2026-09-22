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
