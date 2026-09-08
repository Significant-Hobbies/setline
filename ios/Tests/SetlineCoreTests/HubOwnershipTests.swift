import XCTest
@testable import SetlineCore

final class HubOwnershipTests: XCTestCase {
    private func workout(owner: String? = nil) -> WorkoutSession {
        WorkoutSession(context: .init(templateID: UUID(), templateName: "Synthetic", startedAt: .now, completedAt: .now), state: .init(steps: []), hubAccountID: owner)
    }

    func testApprovalAdoptsOnlyUnownedHistoryAndNeverReassignsImportedWorkouts() throws {
        let unowned = workout()
        let other = workout(owner: "b")
        var document = SetlineDocument(history: [unowned, other])
        try document.approveHubHistory(for: "a")
        XCTAssertEqual(document.hubAccountID, "a")
        XCTAssertEqual(document.history.map(\.hubAccountID), ["a", "b"])
        XCTAssertEqual(try document.approvedHubHistory(for: "a").map(\.id), [unowned.id])
        XCTAssertThrowsError(try document.approveHubHistory(for: "b"))
        XCTAssertEqual(document.hubAccountID, "a")
    }

    func testOwnershipSurvivesExistingICloudRecordPayloadRoundTrip() throws {
        let session = workout(owner: "b")
        var ledger = SyncLedger()
        let records = try SyncEngine.records(for: SetlineDocument(history: [session]), ledger: &ledger, now: .now)
        let local = SetlineDocument(hubAccountID: "a")
        let restored = try SyncEngine.document(from: records, applyingTo: local)
        XCTAssertEqual(restored.hubAccountID, "a")
        XCTAssertEqual(restored.history.first?.hubAccountID, "b")
        XCTAssertTrue(try restored.approvedHubHistory(for: "a").isEmpty)
    }

    func testApprovalIsRefusedDuringActiveWorkoutWithoutMutatingHistory() throws {
        let session = workout()
        var document = SetlineDocument(activeSession: session, history: [workout()])
        let before = document
        XCTAssertThrowsError(try document.approveHubHistory(for: "a"))
        XCTAssertEqual(document, before)
    }

    func testLocalWorkoutInheritsApprovedOwnerWithoutNetwork() throws {
        var document = SetlineDocument(hubAccountID: "a")
        let template = WorkoutTemplate(id: UUID(), name: "Synthetic", detail: "Test", isBundled: false, exercises: [])
        try document.startWorkout(template: template)
        XCTAssertEqual(document.activeSession?.hubAccountID, "a")
        try document.finishWorkout()
        XCTAssertEqual(document.history.first?.hubAccountID, "a")
    }

    func testLegacyJSONIsUnownedAndNeedsExplicitApproval() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(SetlineDocument(history: [workout(owner: "a")], hubAccountID: "a"))) as? [String: Any])
        payload.removeValue(forKey: "hubAccountID")
        var history = try XCTUnwrap(payload["history"] as? [[String: Any]])
        history[0].removeValue(forKey: "hubAccountID")
        payload["history"] = history
        let legacy = try decoder.decode(SetlineDocument.self, from: JSONSerialization.data(withJSONObject: payload))
        XCTAssertNil(legacy.hubAccountID)
        XCTAssertNil(legacy.history.first?.hubAccountID)
        XCTAssertThrowsError(try legacy.approvedHubHistory(for: "a"))
    }
}
