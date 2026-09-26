import Foundation
import PersonalSyncKit
import SetlineCore
import XCTest
@testable import Setline

@MainActor
final class SetlineCallerSyncTests: XCTestCase {
    func testAccountSwitchMidSyncKeepsBoundDocumentAndBlocksPushToNewAccount() async throws {
        let f = try SetlineCallerFixture()
        defer { f.cleanup() }
        await f.tokens.save("account-a")
        await f.model.load()
        await f.model.restoreAccountIfIdle()
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
        // The session changed while HTTP was held: the stale reply cannot commit.
        XCTAssertTrue(f.model.document.history.isEmpty)
        // The account switch then closed the Hub leg: nothing was pushed to
        // account B.
        XCTAssertNil(f.model.hubSyncSnapshot.lastSuccessfulAt)
        XCTAssertNotEqual(f.model.message, "Significant Hobbies Hub is up to date.")
        let requests = await f.requests.snapshot()
        XCTAssertTrue(requests.isEmpty, "No mutation may be pushed to the switched account")
        let reopened = try await f.store.load()
        XCTAssertEqual(reopened.hubAccountID, "a")
        XCTAssertTrue(reopened.history.isEmpty)
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
        // The uncommitted download was never acknowledged.
        let bookkeeping = try MirrorBookkeepingStore(fileURL: f.root.appending(path: "sync/mirror.json"))
        let tokenBeforeRetry = try await bookkeeping.load().pullTokens["hub"]
        XCTAssertNil(tokenBeforeRetry)
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
        XCTAssertEqual(native.hubAccountID, "a")
        XCTAssertTrue(persisted.history.contains { $0.id == f.remoteSessionID })
        XCTAssertNotNil(reopened.hubSyncSnapshot.lastSuccessfulAt)
        let tokenAfterRetry = try await bookkeeping.load().pullTokens["hub"]
        XCTAssertEqual(tokenAfterRetry.map { String(decoding: $0, as: UTF8.self) }, "10")
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
    let connection: PersonalMirrorConnection
    let store: SetlineStore
    let defaults: UserDefaults
    let defaultsName = "SetlineCallerTests-" + UUID().uuidString
    let remoteSessionID = UUID()
    lazy var model = makeModel()

    init() throws {
        defaults = UserDefaults(suiteName: defaultsName)!
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CallerProtocol.self]
        session = URLSession(configuration: configuration)
        let identity = PersonalIdentityClient(
            baseURL: URL(string: "https://identity.invalid")!,
            session: session, tokenStore: tokens
        )
        store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        let hub = HubMirrorTransport(
            domain: .setline,
            deviceId: "synthetic",
            client: PersonalSyncClient(baseURL: URL(string: "https://sync.invalid")!, session: session),
            versions: try SyncVersionStore(fileURL: root.appending(path: "sync/versions.json")),
            account: { try await identity.verifiedSyncAccount() },
            accountGate: { [store] verified in
                (try? await store.load())?.hubAccountID == verified.userID
            },
            appendOnly: { name in SyncEngine.parse(name)?.0.isAppendOnly ?? false }
        )
        let runtime = MirrorRuntime(
            transports: [hub],
            store: try MirrorBookkeepingStore(fileURL: root.appending(path: "sync/mirror.json"))
        )
        connection = PersonalMirrorConnection(
            identity: identity,
            runtime: runtime,
            account: PersonalAccountModel(
                identity: identity,
                callbackScheme: "setline",
                identityURL: URL(string: "https://identity.invalid")!
            )
        )
        let entered = entered, released = released, requests = requests
        let remoteSession = WorkoutSession(
            id: remoteSessionID,
            context: .init(
                templateID: UUID(), templateName: "Synthetic remote walk",
                startedAt: Date(timeIntervalSince1970: 1_757_433_600),
                completedAt: Date(timeIntervalSince1970: 1_757_435_100)
            ),
            state: .init(steps: [])
        )
        let entity = try XCTUnwrap(
            JSONSerialization.jsonObject(with: SyncEngine.makeEncoder().encode(remoteSession)) as? [String: Any]
        )
        let recordBody = try String(
            decoding: JSONSerialization.data(
                withJSONObject: [
                    "recordType": "session",
                    "entityId": remoteSessionID.uuidString.lowercased(),
                    "occurredAt": "2026-09-09T06:00:00Z",
                    "data": entity,
                ],
                options: [.sortedKeys]
            ),
            as: UTF8.self
        )
        let recordName = SyncRecord.recordName(kind: .session, entityID: remoteSessionID)
        CallerProtocol.handler = { request in
            let token = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if request.url!.path.hasSuffix("session") {
                let id = token.contains("account-b") ? "b" : "a"
                return "{\"userId\":\"\(id)\",\"email\":\"\(id)@example.invalid\"}"
            }
            if request.url!.path.hasSuffix("push") {
                await requests.record(token)
                let body = request.httpBody ?? request.httpBodyStream.map { stream -> Data in
                    stream.open()
                    defer { stream.close() }
                    var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
                    while stream.hasBytesAvailable {
                        let count = stream.read(&buffer, maxLength: buffer.count)
                        guard count > 0 else { break }
                        data.append(buffer, count: count)
                    }
                    return data
                } ?? Data()
                let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
                let mutations = object?["mutations"] as? [[String: Any]] ?? []
                let results = mutations.map { mutation in
                    ["id": mutation["id"]!, "idempotencyKey": mutation["idempotencyKey"]!,
                     "status": "accepted", "version": 1, "cursor": 10] as [String: Any]
                }
                return String(decoding: try! JSONSerialization.data(withJSONObject: ["results": results]), as: UTF8.self)
            }
            entered.fulfill()
            for await _ in released.stream { break }
            return "{\"changes\":[{\"cursor\":10,\"changeId\":\"remote-session\",\"domain\":\"setline\",\"id\":\"\(recordName)\",\"operation\":\"upsert\",\"version\":1,\"occurredAt\":\"2026-09-09\",\"recordedAt\":\"2026-09-09\",\"originDeviceId\":\"other\",\"record\":\(recordBody)}],\"cursor\":10,\"hasMore\":false}"
        }
    }

    func makeModel() -> AppModel {
        AppModel(
            store: store,
            restNotifier: CallerRestNotifier(),
            syncStateStore: SyncStateStore(fileURL: root.appending(path: "sync/setline-sync.json")),
            mirror: connection,
            hubSyncStatusStore: HubSyncStatusStore(defaults: defaults)
        )
    }

    func cleanup() {
        released.continuation.finish()
        session.invalidateAndCancel()
        CallerProtocol.handler = nil
        defaults.removePersistentDomain(forName: defaultsName)
        try? FileManager.default.removeItem(at: root)
    }
}
