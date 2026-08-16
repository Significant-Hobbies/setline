import XCTest

@testable import SetlineCore

/// An in-memory stand-in for CloudKit, so the round trip can be tested without a
/// container, a network, or an iCloud account.
private actor FakeRemoteStore: RemoteRecordStore {
    private var stored: [String: SyncRecord] = [:]
    private var status: SyncAvailability
    private var failNextSave: Bool = false
    private(set) var saveCount = 0

    init(status: SyncAvailability = .available, seeded: [SyncRecord] = []) {
        self.status = status
        for record in seeded { stored[record.recordName] = record }
    }

    func availability() async -> SyncAvailability { status }

    func changes(since token: Data?) async throws -> RemoteChanges {
        RemoteChanges(
            records: stored.values.sorted { $0.recordName < $1.recordName },
            token: Data("token-\(stored.count)".utf8)
        )
    }

    func save(_ records: [SyncRecord]) async throws {
        saveCount += 1
        if failNextSave {
            failNextSave = false
            throw SyncError.transport("network went away")
        }
        for record in records { stored[record.recordName] = record }
    }

    func setFailNextSave() { failNextSave = true }
    func allRecords() -> [SyncRecord] { stored.values.sorted { $0.recordName < $1.recordName } }
}

final class SyncCoordinatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_784_505_600)
    private var stateURL: URL!

    override func setUpWithError() throws {
        stateURL = URL.temporaryDirectory
            .appending(path: "setline-sync-tests-\(UUID().uuidString)")
            .appending(path: "sync.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: stateURL.deletingLastPathComponent())
    }

    private func coordinator(_ store: RemoteRecordStore) -> SyncCoordinator {
        SyncCoordinator(store: store, state: SyncStateStore(fileURL: stateURL))
    }

    private func document(withGoal target: Double) -> SetlineDocument {
        var document = SetlineDocument.demoWithEvidence
        document.goals = [
            ExerciseGoal(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                exerciseName: "Bench press",
                metric: .estimatedOneRepMax,
                targetValue: target,
                createdAt: Date(timeIntervalSince1970: 1_784_000_000)
            )
        ]
        return document
    }

    // MARK: - Availability

    func testSyncRefusesWithoutAniCloudAccountAndSaysWhy() async throws {
        let coordinator = coordinator(FakeRemoteStore(status: .noAccount))

        do {
            _ = try await coordinator.sync(document(withGoal: 90), now: now)
            XCTFail("sync must not claim success with no account")
        } catch let error as SyncError {
            XCTAssertEqual(error, .unavailable(.noAccount))
            XCTAssertEqual(
                error.errorDescription,
                "Sign in to iCloud in Settings to sync your training between devices."
            )
        }
    }

    func testAnUnprovisionedContainerIsReportedAsSuchRatherThanAsUserError() async throws {
        let coordinator = coordinator(FakeRemoteStore(status: .containerUnavailable))

        do {
            _ = try await coordinator.sync(document(withGoal: 90), now: now)
            XCTFail("sync must not claim success without a container")
        } catch let error as SyncError {
            XCTAssertEqual(error, .unavailable(.containerUnavailable))
        }
    }

    // MARK: - First sync

    func testFirstSyncPushesEverythingAndPullsNothing() async throws {
        let store = FakeRemoteStore()
        let document = document(withGoal: 90)

        let (merged, outcome) = try await coordinator(store).sync(document, now: now)

        XCTAssertGreaterThan(outcome.pushed, 0)
        XCTAssertEqual(outcome.pulled, 0)
        XCTAssertEqual(merged.syncState, .synced)
        XCTAssertEqual(merged.lastSyncedAt, now)
        XCTAssertEqual(merged.history.count, document.history.count, "no workout may be lost")
        XCTAssertEqual(merged.goals, document.goals)
    }

    func testSyncingTwiceWithNoChangesPushesNothingTheSecondTime() async throws {
        let store = FakeRemoteStore()
        let coordinator = coordinator(store)
        let document = document(withGoal: 90)

        _ = try await coordinator.sync(document, now: now)
        let (_, second) = try await coordinator.sync(document, now: now.addingTimeInterval(60))

        XCTAssertFalse(second.changedAnything, "an unchanged document must not keep re-uploading")
    }

    // MARK: - Two devices

    func testASessionRecordedOnAnotherDeviceArrivesWithoutLosingOurOwn() async throws {
        // The remote already holds a workout this device has never seen.
        var theirDocument = SetlineDocument.demoWithEvidence
        let theirSession = try XCTUnwrap(theirDocument.history.first)
        theirDocument.history = [theirSession]
        var theirLedger = SyncLedger()
        let theirRecords = try SyncEngine.records(
            for: theirDocument,
            ledger: &theirLedger,
            now: now.addingTimeInterval(-3600)
        )
        let store = FakeRemoteStore(seeded: theirRecords.filter { $0.kind == .session })

        var mine = SetlineDocument.demoWithEvidence
        let mySession = WorkoutSession(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            templateID: theirSession.templateID,
            templateName: "Upper A",
            startedAt: now,
            completedAt: now.addingTimeInterval(3600),
            steps: [],
            activeIndex: 0
        )
        mine.history = [mySession]

        let (merged, outcome) = try await coordinator(store).sync(mine, now: now)

        XCTAssertTrue(merged.history.contains { $0.id == mySession.id }, "my workout must survive")
        XCTAssertTrue(merged.history.contains { $0.id == theirSession.id }, "theirs must arrive")
        XCTAssertEqual(merged.history.count, 2)
        XCTAssertGreaterThan(outcome.pulled, 0)
    }

    func testALaterEditOnAnotherDeviceWins() async throws {
        let store = FakeRemoteStore()
        let coordinator = coordinator(store)
        _ = try await coordinator.sync(document(withGoal: 90), now: now)

        // Another device raised the same goal's target an hour later.
        let theirs = document(withGoal: 100)
        var theirLedger = SyncLedger()
        let later = now.addingTimeInterval(3600)
        let theirRecords = try SyncEngine.records(for: theirs, ledger: &theirLedger, now: later)
        try await store.save(theirRecords.filter { $0.kind == .goal })

        let (merged, _) = try await coordinator.sync(document(withGoal: 90), now: later)

        XCTAssertEqual(merged.goals.first?.targetValue, 100, "the later edit must win")
    }

    // MARK: - Failure handling

    func testAFailedPushDoesNotClaimSuccessOrAdvanceTheToken() async throws {
        let store = FakeRemoteStore()
        await store.setFailNextSave()
        let coordinator = coordinator(store)

        do {
            _ = try await coordinator.sync(document(withGoal: 90), now: now)
            XCTFail("a failed push must not be reported as a completed sync")
        } catch let error as SyncError {
            guard case .transport = error else { return XCTFail("expected a transport error") }
        }

        // The token was never stored, so the next attempt still owes the same records.
        let (_, retry) = try await coordinator.sync(document(withGoal: 90), now: now)
        XCTAssertGreaterThan(retry.pushed, 0, "the unsent records must still be owed")
    }

    func testUnreadableBookkeepingDoesNotBlockSyncing() async throws {
        try FileManager.default.createDirectory(
            at: stateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: stateURL)

        let (merged, outcome) = try await coordinator(FakeRemoteStore())
            .sync(document(withGoal: 90), now: now)

        XCTAssertEqual(merged.syncState, .synced)
        XCTAssertGreaterThan(outcome.pushed, 0, "a lost ledger costs one full compare, not a sync")
    }

    func testForgettingBookkeepingStopsAWipeFromDeletingRemoteTraining() async throws {
        // Reset local data, or import a file, and the entities that are no longer
        // present would otherwise be tombstoned on the next sync — deleting the same
        // training from iCloud and from every other device.
        let store = FakeRemoteStore()
        let coordinator = coordinator(store)
        _ = try await coordinator.sync(document(withGoal: 90), now: now)
        let remoteGoalsBefore = await store.allRecords().filter { $0.kind == .goal }
        XCTAssertEqual(remoteGoalsBefore.count, 1)

        try await coordinator.forgetBookkeeping()
        _ = try await coordinator.sync(.initial, now: now.addingTimeInterval(60))

        let remoteGoalsAfter = await store.allRecords().filter { $0.kind == .goal }
        XCTAssertEqual(remoteGoalsAfter.count, 1, "a local wipe must not erase iCloud")
        XCTAssertFalse(
            remoteGoalsAfter.contains { $0.isDeleted },
            "no tombstone may be produced for data this device merely forgot"
        )
    }

    func testWithoutForgettingAWipeWouldPropagateAsDeletion() async throws {
        // The inverse of the test above, so the guard above cannot be removed
        // without something failing.
        let store = FakeRemoteStore()
        let coordinator = coordinator(store)
        _ = try await coordinator.sync(document(withGoal: 90), now: now)

        _ = try await coordinator.sync(.initial, now: now.addingTimeInterval(60))

        let goals = await store.allRecords().filter { $0.kind == .goal }
        XCTAssertTrue(
            goals.allSatisfy(\.isDeleted),
            "a deliberate delete does propagate; that is why a wipe must forget first"
        )
    }

    func testTheActiveSessionIsNotSentAndIsNotDisturbedByASync() async throws {
        var document = SetlineDocument.sample
        document.programme = .none
        try document.startWorkout(template: try XCTUnwrap(document.templates.first))
        let activeID = try XCTUnwrap(document.activeSession?.id)

        let (merged, _) = try await coordinator(FakeRemoteStore()).sync(document, now: now)

        XCTAssertEqual(merged.activeSession?.id, activeID, "a workout in progress must be untouched")
        XCTAssertFalse(merged.history.contains { $0.id == activeID })
    }
}
