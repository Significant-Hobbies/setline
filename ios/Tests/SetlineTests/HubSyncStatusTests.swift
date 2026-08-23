import XCTest
@testable import Setline

final class HubSyncStatusTests: XCTestCase {
    @MainActor
    func testFailurePersistsUntilASuccessClearsIt() throws {
        let suiteName = "HubSyncStatusTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let failure = Date(timeIntervalSince1970: 100)
        let success = Date(timeIntervalSince1970: 200)
        let store = HubSyncStatusStore(defaults: defaults)

        XCTAssertEqual(store.recordFailure(at: failure).lastFailedAt, failure)
        XCTAssertEqual(HubSyncStatusStore(defaults: defaults).load().lastFailedAt, failure)

        let recovered = store.recordSuccess(at: success)
        XCTAssertEqual(recovered.lastSuccessfulAt, success)
        XCTAssertNil(recovered.lastFailedAt)
        XCTAssertEqual(HubSyncStatusStore(defaults: defaults).load(), recovered)
    }

    func testStatusWordingPrioritizesRetryAndQueuedWork() {
        let failed = HubSyncSnapshot(
            lastSuccessfulAt: Date(timeIntervalSince1970: 100),
            lastFailedAt: Date(timeIntervalSince1970: 200)
        )
        XCTAssertEqual(
            HubSyncPresentation.statusTitle(
                snapshot: failed,
                pendingCount: 2,
                isSyncing: false,
                isSignedIn: true
            ),
            "Retry needed"
        )
        XCTAssertEqual(HubSyncPresentation.pendingSummary(1), "1 workout summary pending")
        XCTAssertEqual(HubSyncPresentation.pendingSummary(2), "2 workout summaries pending")
    }

    func testSuccessfulAndSignedOutStatesStayDistinct() {
        XCTAssertEqual(
            HubSyncPresentation.statusTitle(
                snapshot: .empty,
                pendingCount: 0,
                isSyncing: false,
                isSignedIn: false
            ),
            "Not connected"
        )
        XCTAssertEqual(
            HubSyncPresentation.statusTitle(
                snapshot: HubSyncSnapshot(
                    lastSuccessfulAt: Date(timeIntervalSince1970: 100),
                    lastFailedAt: nil
                ),
                pendingCount: 0,
                isSyncing: false,
                isSignedIn: true
            ),
            "Up to date"
        )
    }

    func testDisclosuresKeepDeviceContinuityAndHubVisibilityDistinct() {
        XCTAssertTrue(SyncDisclosure.iCloudPurpose.contains("Apple devices"))
        XCTAssertTrue(SyncDisclosure.iCloudScope.contains("custom plans and templates"))
        XCTAssertTrue(SyncDisclosure.iCloudScope.contains("does not sync an active workout"))
        XCTAssertTrue(SyncDisclosure.hubPurpose.contains("Significant Hobbies"))
        XCTAssertTrue(SyncDisclosure.hubPurpose.contains("summaries only"))
        XCTAssertTrue(SyncDisclosure.hubScope.contains("completed-step count"))
        XCTAssertTrue(SyncDisclosure.hubScope.contains("does not include set-by-set details"))
    }
}
