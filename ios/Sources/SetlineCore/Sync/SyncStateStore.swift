import Foundation

/// The record-dating ledger, stored beside the document rather than inside it.
///
/// The ledger is what turns "this entity is no longer here" into a tombstone,
/// and what lets an unchanged entity keep the timestamp of its last real edit.
/// It is sync bookkeeping, not training: keeping it out of `SetlineDocument`
/// means the export a person takes contains their workouts and nothing about
/// how a particular device talked to a server, and importing a file cannot
/// corrupt sync state.
///
/// Transport bookkeeping — pull tokens, pushed fingerprints, the bound owner —
/// lives in `MirrorBookkeepingStore` in PersonalSyncKit; this file only dates
/// records.
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
        // Preserve unreadable deletion evidence instead of silently redating
        // records or losing legacy tombstones. Explicit recovery can reset it.
        return try JSONDecoder().decode(Bookkeeping.self, from: data)
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
