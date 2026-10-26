import Foundation
import PersonalSyncKit
import SetlineCore
import XCTest
@testable import Setline

@MainActor
final class HubWorkoutSummaryTests: XCTestCase {
    private func fixture() throws -> SetlineDocument {
        var document = SetlineDocument.sample
        document.hubAccountID = "a"
        var template = TwelveWeekProgramme.template(for: .lower, week: 1)
        template.id = UUID()
        template.isBundled = false
        template.name = "Allowed workout name"
        template.detail = "PRIVATE_TEMPLATE_INSTRUCTIONS"
        document.templates.append(template)
        try document.startWorkout(templateID: template.id, at: Date(timeIntervalSince1970: 1_700_000_000))
        try document.completeCurrent(with: [.init(loadMetrics: .init(weight: 43, repetitions: 9))],
                                     workSeconds: 32, at: Date(timeIntervalSince1970: 1_700_000_032))
        try document.finishWorkout(at: Date(timeIntervalSince1970: 1_700_001_500))
        return document
    }

    func testProjectionIsAnAllowlistOfCompletedWorkoutSummaryFields() throws {
        let document = try fixture()
        let record = try XCTUnwrap(HubWorkoutSummary.records(for: document).first)
        let bytes = try XCTUnwrap(record.payload)
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertEqual(Set(envelope.keys), ["recordType", "projection", "entityId", "occurredAt", "data"])
        let summary = try XCTUnwrap(envelope["data"] as? [String: Any])
        XCTAssertEqual(Set(summary.keys), ["name", "startedAt", "durationSeconds", "completedStepCount"])
        XCTAssertEqual(summary["name"] as? String, "Allowed workout name")
        XCTAssertEqual(summary["durationSeconds"] as? Double, 1500)
        XCTAssertEqual(summary["completedStepCount"] as? Int, 1)
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("PRIVATE_TEMPLATE_INSTRUCTIONS"))
        XCTAssertTrue(record.appendOnly)
        XCTAssertEqual(try HubWorkoutSummary.records(for: document), [record])
    }

    func testUnapprovedOtherAccountImportedAndUnfinishedWorkoutsAreNotSent() throws {
        var document = try fixture()
        let original = try XCTUnwrap(document.history.first)
        var other = original
        other.id = UUID(); other.hubAccountID = "b"
        var imported = original
        imported.id = UUID(); imported.hubRecordID = "summary-existing"
        var unfinished = original
        unfinished.id = UUID(); unfinished.completedAt = nil
        document.history += [other, imported, unfinished]
        XCTAssertEqual(try HubWorkoutSummary.records(for: document).count, 1)
        document.hubAccountID = nil
        XCTAssertTrue(try HubWorkoutSummary.records(for: document).isEmpty)
        document.hubAccountID = "a"
        document.activeSession = original
        XCTAssertTrue(try HubWorkoutSummary.records(for: document).isEmpty)
    }

    func testRestoreRetainsCountsWithoutInventingSetsOrReplacingNativeHistory() throws {
        let source = try fixture()
        let record = try XCTUnwrap(HubWorkoutSummary.records(for: source).first)
        var restored = SetlineDocument(hubAccountID: "a")
        try HubWorkoutSummary.apply(record, to: &restored)
        try HubWorkoutSummary.apply(record, to: &restored)
        XCTAssertEqual(restored.history.count, 1)
        XCTAssertEqual(restored.history.first?.hubSummaryCompletedStepCount, 1)
        XCTAssertEqual(restored.history.first?.hubRecordID, record.name)
        XCTAssertTrue(try XCTUnwrap(restored.history.first).steps.isEmpty)
        XCTAssertTrue(try HubWorkoutSummary.records(for: restored).isEmpty, "Imported summaries never echo as native workouts")
        var native = source
        try HubWorkoutSummary.apply(record, to: &native)
        XCTAssertEqual(native, source)
        try HubWorkoutSummary.apply(MirrorRecord(name: record.name, modifiedAt: .now, payload: nil), to: &native)
        XCTAssertEqual(native, source, "A Hub tombstone cannot erase native detail")
    }

    func testLegacyFullSessionRestoresOnlySummaryAndIsNeverReprojected() throws {
        let source = try fixture()
        let original = try XCTUnwrap(source.history.first)
        XCTAssertFalse(original.steps.isEmpty)

        let encodedSession = try SyncEngine.makeEncoder().encode(original)
        let legacyEntity = try XCTUnwrap(JSONSerialization.jsonObject(with: encodedSession) as? [String: Any])
        let legacyPayload = try JSONSerialization.data(withJSONObject: [
            "recordType": "session",
            "entityId": original.id.uuidString.lowercased(),
            "occurredAt": ISO8601DateFormatter().string(from: original.startedAt),
            "data": legacyEntity,
        ], options: [.sortedKeys])
        let legacyRecord = MirrorRecord(
            name: SyncRecord.recordName(kind: .session, entityID: original.id),
            modifiedAt: try XCTUnwrap(original.completedAt), payload: legacyPayload, appendOnly: true
        )

        var restored = SetlineDocument(hubAccountID: "a")
        try HubWorkoutSummary.apply(legacyRecord, to: &restored)
        let summary = try XCTUnwrap(restored.history.first)
        XCTAssertEqual(restored.history.count, 1)
        XCTAssertEqual(summary.id, original.id)
        XCTAssertEqual(summary.templateName, original.templateName)
        XCTAssertEqual(summary.startedAt, original.startedAt)
        XCTAssertEqual(summary.completedAt, original.completedAt)
        XCTAssertEqual(summary.hubSummaryCompletedStepCount, original.completedCount)
        XCTAssertEqual(summary.hubRecordID, legacyRecord.name)
        XCTAssertEqual(summary.hubAccountID, "a")
        XCTAssertTrue(summary.steps.isEmpty, "Legacy Hub set details are not restored")
        XCTAssertNil(summary.rest)

        var native = source
        try HubWorkoutSummary.apply(legacyRecord, to: &native)
        XCTAssertEqual(native, source, "A legacy Hub record cannot overwrite same-ID native history")

        XCTAssertTrue(try HubWorkoutSummary.records(for: restored).isEmpty,
                      "A restored legacy summary must not be re-emitted as a full workout")
    }

    func testMalformedSummaryCannotChangeStoredHistory() throws {
        let source = try fixture()
        let record = try XCTUnwrap(HubWorkoutSummary.records(for: source).first)
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(record.payload)) as? [String: Any])
        var data = try XCTUnwrap(envelope["data"] as? [String: Any])
        data["completedStepCount"] = -1
        envelope["data"] = data
        let malformed = MirrorRecord(name: record.name, modifiedAt: record.modifiedAt,
                                     payload: try JSONSerialization.data(withJSONObject: envelope))
        var target = source
        XCTAssertThrowsError(try HubWorkoutSummary.apply(malformed, to: &target))
        XCTAssertEqual(target, source)
    }

    func testTransportSpecificSnapshotLeavesCloudKitEntitiesIntact() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        try await store.save(fixture())
        let model = AppModel(store: store, restNotifier: SummaryRestNotifier(),
                             syncStateStore: SyncStateStore(fileURL: root.appending(path: "sync.json")), mirror: nil)
        await model.load()
        let cloud = try await model.mirrorRecords()
        let hub = try await model.mirrorRecords(transportID: "hub")
        XCTAssertEqual(hub.count, 1)
        XCTAssertTrue(hub.allSatisfy { HubWorkoutSummary.isSummaryName($0.name) })
        XCTAssertTrue(cloud.contains { SyncEngine.parse($0.name)?.0 == .template })
        XCTAssertTrue(cloud.contains { SyncEngine.parse($0.name)?.0 == .programme })
        let session = try XCTUnwrap(cloud.first { SyncEngine.parse($0.name)?.0 == .session })
        let body = String(decoding: try XCTUnwrap(session.payload), as: UTF8.self)
        XCTAssertTrue(body.contains("\"steps\""))
        XCTAssertTrue(body.contains("\"weight\""))
    }
}

@MainActor
private final class SummaryRestNotifier: RestNotifying {
    func update(for rest: RestState?, nextStep: WorkoutStep?) async {}
}
