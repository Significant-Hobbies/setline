import Foundation
import PersonalSyncKit
import SetlineCore
import XCTest
@testable import Setline

@MainActor
final class SetlineCallerSyncTests: XCTestCase {
    func testActualApprovalRejectsHeldAResponseAfterSwitchToB() async throws {
        let f = try SetlineCallerFixture()
        defer { f.cleanup() }
        await f.tokens.save("account-a")
        await f.model.load()
        await f.model.restoreAccountIfIdle()
        try await f.connection.sync.enqueue(recordId: "queued-a", occurredAt: "2026-09-09", record: .string("A only"))
        let approval = Task { await f.model.approveHubAccount() }
        await fulfillment(of: [f.entered], timeout: 5)
        XCTAssertEqual(f.model.document.hubAccountID, "a")
        await f.tokens.save("account-b")
        await f.model.account?.restore()
        f.released.continuation.finish()
        await approval.value
        await f.model.approveHubAccount()
        await f.model.syncWithPlatform(announcing: true, recoverMissingRecords: true)
        XCTAssertEqual(f.model.account?.session?.userId, "b")
        XCTAssertEqual(f.model.document.hubAccountID, "a")
        XCTAssertTrue(f.model.document.history.isEmpty)
        XCTAssertNil(f.model.hubSyncSnapshot.lastSuccessfulAt)
        XCTAssertNotEqual(f.model.message, "Significant Hobbies Hub is up to date.")
        let pending = await f.connection.sync.pendingMutationCount()
        XCTAssertEqual(pending, 1)
        let requests = await f.requests.snapshot()
        XCTAssertEqual(requests, ["Bearer account-a"])
        let reopened = try await f.store.load()
        XCTAssertEqual(reopened.hubAccountID, "a")
        XCTAssertTrue(reopened.history.isEmpty)
        let cursor = try await SyncCursorStore(fileURL: f.root.appending(path: "sync/personal-sync-cursors.json")).cursor(for: .setline)
        XCTAssertEqual(cursor, 0)
    }

    func testHeldDownloadDefersForWorkoutThenRetryPreservesRecordedSetsAfterReopen() async throws {
        let f = try SetlineCallerFixture()
        defer { f.cleanup() }
        await f.tokens.save("account-a")
        await f.model.load()
        await f.model.restoreAccountIfIdle()
        let approval = Task { await f.model.approveHubAccount() }
        await fulfillment(of: [f.entered], timeout: 5)
        let template = try XCTUnwrap(SetlineDocument.sample.templates.first)
        await f.model.startWorkout(template)
        let segments = [SetSegment(loadMetrics: .init(weight: 40, repetitions: 8))]
        await f.model.completeCurrent(segments: segments)
        let active = try XCTUnwrap(f.model.document.activeSession)
        XCTAssertEqual(active.steps.first?.segments, segments)
        f.released.continuation.finish()
        await approval.value
        XCTAssertEqual(f.model.document.activeSession, active)
        XCTAssertTrue(f.model.document.history.isEmpty)
        XCTAssertNil(f.model.hubSyncSnapshot.lastSuccessfulAt)
        let cursorBeforeRetry = try await SyncCursorStore(fileURL: f.root.appending(path: "sync/personal-sync-cursors.json")).cursor(for: .setline)
        XCTAssertEqual(cursorBeforeRetry, 0)
        let storedActive = try await f.store.load()
        XCTAssertEqual(storedActive.activeSession?.steps.first?.segments, segments)

        // Finish offline, then reopen before explicitly retrying account sync.
        await f.model.account?.signOut()
        await f.model.finishWorkout()
        let reopened = f.makeModel()
        await reopened.load()
        XCTAssertNil(reopened.document.activeSession)
        XCTAssertEqual(reopened.document.history.first?.steps.first?.segments, segments)
        await f.tokens.save("account-a")
        await reopened.restoreAccountIfIdle()
        await reopened.syncWithPlatform(announcing: true, recoverMissingRecords: true)
        let persisted = try await f.store.load()
        XCTAssertNil(persisted.activeSession)
        XCTAssertEqual(persisted.history.count, 2)
        let native = try XCTUnwrap(persisted.history.first { $0.id == active.id })
        XCTAssertEqual(native.steps.first?.segments, segments)
        XCTAssertNil(native.hubRecordID)
        XCTAssertEqual(native.hubAccountID, "a")
        XCTAssertEqual(persisted.history.filter { $0.hubRecordID == "remote-summary" }.count, 1)
        XCTAssertNotNil(reopened.hubSyncSnapshot.lastSuccessfulAt)
        let cursorAfterRetry = try await SyncCursorStore(fileURL: f.root.appending(path: "sync/personal-sync-cursors.json")).cursor(for: .setline)
        XCTAssertEqual(cursorAfterRetry, 10)
    }
}

private actor CallerTokens: PersonalBearerTokenStore {
    private var token: String?
    func load() -> String? { token }
    func save(_ token: String) { self.token = token }
    func delete() { token = nil }
}

private actor CallerRequests {
    private var pushes: [String] = []
    func record(_ token: String) { pushes.append(token) }
    func snapshot() -> [String] { pushes }
}

private final class CallerProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) async -> String)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Task {
            guard let handler = Self.handler else { return }
            let body = await handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

@MainActor
private final class CallerRestNotifier: RestNotifying {
    func update(for rest: RestState?, nextStep: WorkoutStep?) async {}
}

@MainActor
private final class SetlineCallerFixture {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let tokens = CallerTokens()
    let requests = CallerRequests()
    let entered = XCTestExpectation(description: "Actual caller reaches held pull")
    let released = AsyncStream<Void>.makeStream()
    let session: URLSession
    let connection: PersonalPlatformConnection
    let store: SetlineStore
    let defaults: UserDefaults
    let defaultsName = "SetlineCallerTests-" + UUID().uuidString
    lazy var model = makeModel()

    init() throws {
        defaults = UserDefaults(suiteName: defaultsName)!
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CallerProtocol.self]
        session = URLSession(configuration: configuration)
        let identity = PersonalIdentityClient(baseURL: URL(string: "https://identity.invalid")!, session: session, tokenStore: tokens)
        let sync = try PersonalSyncRuntime(domain: .setline, deviceId: "synthetic", supportDirectory: root.appending(path: "sync"), identity: identity, client: PersonalSyncClient(baseURL: URL(string: "https://sync.invalid")!, session: session))
        connection = PersonalPlatformConnection(identity: identity, sync: sync)
        store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        let entered = entered, released = released, requests = requests
        CallerProtocol.handler = { request in
            let token = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if request.url!.path.hasSuffix("session") {
                let id = token.contains("account-b") ? "b" : "a"
                return "{\"userId\":\"\(id)\",\"email\":\"\(id)@example.invalid\"}"
            }
            if request.url!.path.hasSuffix("push") {
                await requests.record(token)
                return #"{"results":[]}"#
            }
            entered.fulfill()
            for await _ in released.stream { break }
            return #"{"changes":[{"cursor":10,"changeId":"remote-summary","domain":"setline","id":"remote-summary","operation":"upsert","version":1,"occurredAt":"2026-09-09","recordedAt":"2026-09-09","originDeviceId":"other","record":{"title":"Synthetic remote walk","occurredOn":"2026-09-09T06:00:00.123Z","minutes":25,"notes":"Synthetic summary"}}],"cursor":10,"hasMore":false}"#
        }
    }

    func makeModel() -> AppModel {
        AppModel(store: store, restNotifier: CallerRestNotifier(), syncCoordinator: nil, platform: connection, hubSyncStatusStore: HubSyncStatusStore(defaults: defaults))
    }

    func cleanup() {
        released.continuation.finish()
        session.invalidateAndCancel()
        CallerProtocol.handler = nil
        defaults.removePersistentDomain(forName: defaultsName)
        try? FileManager.default.removeItem(at: root)
    }
}
