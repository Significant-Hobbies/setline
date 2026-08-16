import Foundation

/// Runs one sync: read local, fetch remote, merge, push what is missing, and hand
/// back the reconciled document.
///
/// The coordinator owns no merge rules — those live in `SyncEngine`, which is pure.
/// What lives here is sequencing and the sync bookkeeping that has to survive a
/// relaunch: the ledger that dates records, and the server change token.
public actor SyncCoordinator {
    private let store: RemoteRecordStore
    private let state: SyncStateStore

    public init(store: RemoteRecordStore, state: SyncStateStore = SyncStateStore()) {
        self.store = store
        self.state = state
    }

    public func availability() async -> SyncAvailability {
        await store.availability()
    }

    /// Forgets what was last synced from this device.
    ///
    /// Must be called whenever local data is wiped or wholesale replaced. The ledger
    /// is what turns "this entity is no longer here" into a tombstone, so a reset
    /// with a surviving ledger would sync itself as a deletion of everything and
    /// erase the same training from iCloud and every other device. Forgetting costs
    /// one full compare; not forgetting costs the data.
    public func forgetBookkeeping() async throws {
        try await state.reset()
    }

    /// Reconciles a document with iCloud and returns the merged result.
    ///
    /// Throws only when nothing could be done. A partial sync is not silently
    /// reported as success, because "synced" is a claim about where a person's
    /// training is.
    public func sync(_ document: SetlineDocument, now: Date = .now) async throws -> (
        document: SetlineDocument, outcome: SyncOutcome
    ) {
        let availability = await store.availability()
        guard availability.isAvailable else { throw SyncError.unavailable(availability) }

        var bookkeeping = try await state.load()

        var local = try SyncEngine.records(for: document, ledger: &bookkeeping.ledger, now: now)
        local.append(
            contentsOf: SyncEngine.tombstones(for: document, ledger: &bookkeeping.ledger, now: now)
        )

        let remote: RemoteChanges
        do {
            remote = try await store.changes(since: bookkeeping.changeToken)
        } catch {
            throw SyncError.transport(error.localizedDescription)
        }

        let result = SyncEngine.merge(local: local, remote: remote.records)

        if !result.toPush.isEmpty {
            do {
                try await store.save(result.toPush)
            } catch {
                throw SyncError.transport(error.localizedDescription)
            }
        }

        // A token is only worth keeping once its changes have been applied and
        // everything owed to the server has been accepted. Saving it earlier would
        // skip those records forever on the next run.
        bookkeeping.changeToken = remote.token
        bookkeeping.lastSyncedAt = now
        try await state.save(bookkeeping)

        var merged = try SyncEngine.document(from: result.merged, applyingTo: document)
        merged.syncState = .synced
        merged.lastSyncedAt = now

        return (
            merged,
            SyncOutcome(pushed: result.toPush.count, pulled: result.toPull.count, completedAt: now)
        )
    }
}

/// The ledger and change token, stored beside the document rather than inside it.
///
/// These are sync bookkeeping, not training. Keeping them out of `SetlineDocument`
/// means the export a person takes contains their workouts and nothing about how a
/// particular device talked to a server, and importing a file cannot corrupt sync
/// state.
public actor SyncStateStore {
    public struct Bookkeeping: Codable, Equatable, Sendable {
        public var ledger: SyncLedger
        public var changeToken: Data?
        public var lastSyncedAt: Date?

        public init(
            ledger: SyncLedger = SyncLedger(),
            changeToken: Data? = nil,
            lastSyncedAt: Date? = nil
        ) {
            self.ledger = ledger
            self.changeToken = changeToken
            self.lastSyncedAt = lastSyncedAt
        }
    }

    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? SetlineFiles.syncBookkeeping
    }

    public func load() throws -> Bookkeeping {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return Bookkeeping() }
        let data = try Data(contentsOf: fileURL)
        // Unreadable bookkeeping is recoverable: dropping it costs one full compare,
        // never a workout. So it must not be allowed to block syncing.
        return (try? JSONDecoder().decode(Bookkeeping.self, from: data)) ?? Bookkeeping()
    }

    public func save(_ bookkeeping: Bookkeeping) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(bookkeeping)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    public func reset() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
