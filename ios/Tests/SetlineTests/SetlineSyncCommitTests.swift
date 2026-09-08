import Foundation
import PersonalSyncKit
import SetlineCore
import XCTest
@testable import Setline

@MainActor
final class SetlineSyncCommitTests: XCTestCase {
    func testApprovedHistoryPersistsAndRejectsDifferentAccountDownloads() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(), syncCoordinator: nil, platform: nil)
        await model.load()
        let approved = await model.approveLocalHubHistory(for: "a")
        XCTAssertTrue(approved)
        let persisted = try await store.load()
        XCTAssertEqual(persisted.hubAccountID, "a")
        do {
            try await model.commitPlatformChanges([summary(id: "foreign-workout")], ownerID: "b")
            XCTFail("Another account must not add history")
        } catch SetlineHubOwnershipError.differentAccount {}
        XCTAssertTrue(model.document.history.isEmpty)
        try await model.commitPlatformChanges([summary(id: "a-workout")], ownerID: "a")
        let reopened = try await store.load()
        XCTAssertEqual(reopened.history.first?.hubAccountID, "a")
        XCTAssertEqual(reopened.history.first?.hubRecordID, "a-workout")
        XCTAssertTrue(try reopened.approvedHubHistory(for: "a").isEmpty, "Downloaded summaries must not be re-exported")
    }

    func testFailedApprovalSaveDoesNotClaimOwnershipAndCanRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "workouts.json")
        let store = SetlineStore(fileURL: file)
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(), syncCoordinator: nil, platform: nil)
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
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(), syncCoordinator: nil, platform: nil)
        await model.load()
        let rejected = await model.approveLocalHubHistory(for: "a")
        XCTAssertFalse(rejected)
        let persisted = try await store.load()
        XCTAssertEqual(persisted, model.document)
        XCTAssertNil(persisted.hubAccountID)
        XCTAssertEqual(persisted.activeSession?.id, original.activeSession?.id)
    }

    func testEchoedSummaryCannotReplaceDetailedNativeWorkout() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        var original = SetlineDocument.sample
        let template = try XCTUnwrap(original.templates.first)
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try original.startWorkout(templateID: template.id, at: startedAt)
        try original.completeCurrent(with: [.init(loadMetrics: .init(weight: 40, repetitions: 8))], workSeconds: 32, at: startedAt.addingTimeInterval(32))
        try original.finishWorkout(at: startedAt.addingTimeInterval(1_500))
        let session = try XCTUnwrap(original.history.first)
        try await store.save(original)
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(), syncCoordinator: nil, platform: nil)
        await model.load()
        let change = try summary(id: session.id.uuidString, title: session.templateName)
        try await model.commitPlatformChanges([change])
        let reopened = try await store.load()
        XCTAssertEqual(reopened.history, original.history, "A Hub summary cannot erase recorded sets, order, rest or programme context")
        XCTAssertEqual(model.document.history, original.history)
        let deletion = try summary(id: session.id.uuidString, operation: "delete")
        try await model.commitPlatformChanges([deletion])
        XCTAssertEqual(model.document.history, original.history)
    }

    func testImportedSummaryUpdatesReplaysAndDeletesWithoutReexport() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(), syncCoordinator: nil, platform: nil)
        await model.load()
        let first = try summary(id: "hub-walk")
        try await model.commitPlatformChanges([first, first])
        let edited = try summary(id: "hub-walk", title: "Updated walk")
        try await model.commitPlatformChanges([edited])
        let reloaded = try await store.load()
        XCTAssertEqual(reloaded.history.count, 1)
        let session = try XCTUnwrap(reloaded.history.first)
        XCTAssertEqual(session.hubRecordID, "hub-walk")
        XCTAssertEqual(session.templateName, "Updated walk")
        XCTAssertNil(SetlinePlatformRecord.session(session, completedAt: try XCTUnwrap(session.completedAt)))
        try await model.commitPlatformChanges([summary(id: "hub-walk", operation: "delete")])
        let deleted = try await store.load()
        XCTAssertTrue(deleted.history.isEmpty)
    }

    func testFailedDownloadWriteKeepsCursorAndRetriesIntoHistory() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "workouts.json")
        let store = SetlineStore(fileURL: file)
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(), syncCoordinator: nil, platform: nil)
        await model.load()
        let response = JSONValue.object(["changes": .array([summaryPayload(id: "hub-walk")]), "cursor": .number(1), "hasMore": .bool(false)])
        let transport = SetlineDownloadTransport(response: try JSONEncoder().encode(response))
        let cursorFile = root.appending(path: "cursor.json")
        let coordinator = try PersonalSyncKit.SyncCoordinator(
            client: transport,
            outbox: MutationOutbox(fileURL: root.appending(path: "outbox.json")),
            cursors: SyncCursorStore(fileURL: cursorFile),
            versions: SyncVersionStore(fileURL: root.appending(path: "versions.json")),
            fingerprints: SyncFingerprintStore(fileURL: root.appending(path: "fingerprints.json"))
        )
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        do {
            try await coordinator.synchronize(domain: .setline, deviceId: "test", bearerToken: "synthetic") { changes in
                try await model.commitPlatformChanges(changes)
            }
            XCTFail("Failed app writes must not acknowledge downloads")
        } catch {
            XCTAssertTrue(model.document.history.isEmpty)
        }
        let cursor = try await SyncCursorStore(fileURL: cursorFile).cursor(for: .setline)
        XCTAssertEqual(cursor, 0)
        try FileManager.default.removeItem(at: file)
        try await coordinator.synchronize(domain: .setline, deviceId: "test", bearerToken: "synthetic") { changes in
            try await model.commitPlatformChanges(changes)
        }
        let reopened = try await store.load()
        XCTAssertEqual(reopened.history.map(\.templateName), ["Imported walk"])
        let calls = await transport.requestedCursors
        XCTAssertEqual(calls, [0, 0])
        let committedCursor = try await SyncCursorStore(fileURL: cursorFile).cursor(for: .setline)
        XCTAssertEqual(committedCursor, 1)
    }

    func testDownloadCommitDefersWhileWorkoutIsActive() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        var original = SetlineDocument.sample
        try original.startWorkout(templateID: try XCTUnwrap(original.templates.first).id, at: Date(timeIntervalSince1970: 1_700_000_000))
        try await store.save(original)
        let model = AppModel(store: store, restNotifier: SyncTestRestNotifier(), syncCoordinator: nil, platform: nil)
        await model.load()
        do {
            try await model.commitPlatformChanges([summary(id: "hub-walk")])
            XCTFail("Downloads must defer when a workout started during the request")
        } catch SetlineHubCommitError.localDocumentUnavailable {}
        XCTAssertEqual(model.document.activeSession, original.activeSession)
        XCTAssertTrue(model.document.history.isEmpty)
        let disk = try await store.load()
        XCTAssertEqual(disk.activeSession, original.activeSession)
    }

    func testLegacyWorkoutWithoutProvenanceRemainsNativeOrUnknown() throws {
        let change = try summary(id: "legacy-walk")
        let session = try XCTUnwrap(SetlinePlatformRecord.session(from: change))
        let data = try JSONEncoder().encode(session)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "hubRecordID")
        let legacy = try JSONDecoder().decode(WorkoutSession.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(legacy.hubRecordID)
        XCTAssertEqual(legacy.id, session.id)
    }

    private func summary(id: String, title: String = "Imported walk", operation: String = "upsert") throws -> SyncChange {
        try JSONDecoder().decode(SyncChange.self, from: JSONEncoder().encode(summaryPayload(id: id, title: title, operation: operation)))
    }

    private func summaryPayload(id: String, title: String = "Imported walk", operation: String = "upsert") -> JSONValue {
        .object([
            "cursor": .number(1), "changeId": .string("change-1"), "domain": .string("setline"),
            "id": .string(id), "operation": .string(operation), "version": .number(1),
            "occurredAt": .string("2026-09-08"), "recordedAt": .string("2026-09-08"),
            "originDeviceId": .string("synthetic"), "record": .object([
                "title": .string(title), "occurredOn": .string("2026-09-08T06:00:00Z"),
                "minutes": .number(25), "notes": .string("Imported summary"),
            ]),
        ])
    }
}

@MainActor
private final class SyncTestRestNotifier: RestNotifying {
    func update(for rest: RestState?, nextStep: WorkoutStep?) async {}
}

private actor SetlineDownloadTransport: PersonalSyncTransport {
    let response: Data
    private(set) var requestedCursors: [Int] = []
    init(response: Data) { self.response = response }
    func push(domain: PersonalDomain, deviceId: String, mutations: [SyncMutation], bearerToken: String) async throws -> PushResponse {
        try JSONDecoder().decode(PushResponse.self, from: Data("{\"results\":[]}".utf8))
    }
    func pull(domain: PersonalDomain, cursor: Int, bearerToken: String) async throws -> PullResponse {
        requestedCursors.append(cursor)
        let empty = Data("{\"changes\":[],\"cursor\":1,\"hasMore\":false}".utf8)
        return try JSONDecoder().decode(PullResponse.self, from: cursor == 0 ? response : empty)
    }
}
