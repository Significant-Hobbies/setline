import Foundation

/// Turns a document into records, merges records from two devices, and turns the
/// result back into a document.
///
/// Every function here is pure. The merge is the part of syncing that can lose
/// somebody's training, so it is deliberately separated from anything that touches
/// the network, a container, or a clock it does not control: `now` is always passed
/// in. CloudKit transport sits on top of this and holds no merge rules of its own.
public enum SyncEngine {
    /// The outcome of reconciling local and remote records.
    public struct MergeResult: Equatable, Sendable {
        /// Everything that should exist after the merge, on both sides.
        public var merged: [SyncRecord]
        /// Records the remote is missing or holds an older version of.
        public var toPush: [SyncRecord]
        /// Records the local side is missing or holds an older version of.
        public var toPull: [SyncRecord]

        public init(merged: [SyncRecord], toPush: [SyncRecord], toPull: [SyncRecord]) {
            self.merged = merged
            self.toPush = toPush
            self.toPull = toPull
        }

        public var isUpToDate: Bool { toPush.isEmpty && toPull.isEmpty }
    }

    // MARK: - Document to records

    /// Encodes a document as records, dating each one through the ledger.
    ///
    /// The active session is deliberately excluded. A workout in progress belongs
    /// to the phone in your hand: syncing it would let a second device advance or
    /// finish a session you are still doing.
    public static func records(
        for document: SetlineDocument,
        ledger: inout SyncLedger,
        now: Date
    ) throws -> [SyncRecord] {
        let encoder = makeEncoder()
        var records: [SyncRecord] = []

        for template in document.templates where !template.isBundled {
            records.append(
                SyncRecord(
                    kind: .template,
                    entityID: template.id,
                    modifiedAt: now,
                    payload: try encoder.encode(template)
                )
            )
        }
        for session in document.history {
            records.append(
                SyncRecord(
                    kind: .session,
                    entityID: session.id,
                    modifiedAt: now,
                    payload: try encoder.encode(session)
                )
            )
        }
        for goal in document.goals {
            records.append(
                SyncRecord(
                    kind: .goal,
                    entityID: goal.id,
                    modifiedAt: now,
                    payload: try encoder.encode(goal)
                )
            )
        }
        records.append(
            SyncRecord(
                kind: .programme,
                entityID: SyncRecordKind.singletonID,
                modifiedAt: now,
                payload: try encoder.encode(document.programme)
            )
        )

        // Stamp after building, so an unchanged payload keeps its original date.
        return records.map { record in
            var dated = record
            dated.modifiedAt = ledger.stamp(record, now: now)
            return dated
        }
    }

    /// Records for entities that existed at the last sync and are now gone.
    ///
    /// Without these a delete never propagates: the other device still holds the
    /// entity and pushes it straight back. Bundled templates are never records, and
    /// history is append-only, so neither can produce a tombstone.
    public static func tombstones(
        for document: SetlineDocument,
        ledger: inout SyncLedger,
        now: Date
    ) -> [SyncRecord] {
        var live: Set<String> = []
        for template in document.templates where !template.isBundled {
            live.insert(SyncRecord.recordName(kind: .template, entityID: template.id))
        }
        for goal in document.goals {
            live.insert(SyncRecord.recordName(kind: .goal, entityID: goal.id))
        }

        var tombstones: [SyncRecord] = []
        for (recordName, stamp) in ledger.stamps {
            guard let (kind, entityID) = parse(recordName) else { continue }
            guard kind == .template || kind == .goal else { continue }
            guard !live.contains(recordName) else { continue }
            guard stamp.fingerprint != "deleted" else { continue }
            var tombstone = SyncRecord(kind: kind, entityID: entityID, modifiedAt: now, payload: nil)
            tombstone.modifiedAt = ledger.stamp(tombstone, now: now)
            tombstones.append(tombstone)
        }
        return tombstones.sorted { $0.recordName < $1.recordName }
    }

    // MARK: - Merge

    /// Reconciles two sets of records without ever dropping recorded training.
    public static func merge(local: [SyncRecord], remote: [SyncRecord]) -> MergeResult {
        var merged: [String: SyncRecord] = [:]
        var toPush: [SyncRecord] = []
        var toPull: [SyncRecord] = []

        let localByName = Dictionary(local.map { ($0.recordName, $0) }, uniquingKeysWith: winner)
        let remoteByName = Dictionary(remote.map { ($0.recordName, $0) }, uniquingKeysWith: winner)

        for name in Set(localByName.keys).union(remoteByName.keys).sorted() {
            switch (localByName[name], remoteByName[name]) {
            case let (.some(mine), .some(theirs)):
                let chosen = winner(mine, theirs)
                merged[name] = chosen
                if chosen != theirs { toPush.append(chosen) }
                if chosen != mine { toPull.append(chosen) }
            case let (.some(mine), .none):
                merged[name] = mine
                toPush.append(mine)
            case let (.none, .some(theirs)):
                merged[name] = theirs
                toPull.append(theirs)
            case (.none, .none):
                continue
            }
        }

        return MergeResult(
            merged: merged.values.sorted { $0.recordName < $1.recordName },
            toPush: toPush.sorted { $0.recordName < $1.recordName },
            toPull: toPull.sorted { $0.recordName < $1.recordName }
        )
    }

    /// Picks between two versions of the same record.
    ///
    /// Append-only kinds keep whichever version has content, so a session cannot be
    /// erased by a device whose clock is wrong or which never saw it. Everything else
    /// is last-writer-wins, and an exact timestamp tie is broken on payload bytes so
    /// two devices merging the same pair always reach the same answer rather than
    /// disagreeing forever.
    private static func winner(_ left: SyncRecord, _ right: SyncRecord) -> SyncRecord {
        if left == right { return left }
        if left.kind.isAppendOnly {
            if left.isDeleted != right.isDeleted { return left.isDeleted ? right : left }
        }
        if left.modifiedAt != right.modifiedAt {
            return left.modifiedAt > right.modifiedAt ? left : right
        }
        let leftBytes = left.payload ?? Data()
        let rightBytes = right.payload ?? Data()
        if leftBytes.count != rightBytes.count {
            return leftBytes.count > rightBytes.count ? left : right
        }
        return leftBytes.lexicographicallyPrecedes(rightBytes) ? right : left
    }

    // MARK: - Records to document

    /// Rebuilds a document from merged records, keeping the parts of local state
    /// that are not synced: the active session, and the bundled templates that ship
    /// with the app rather than travelling between devices.
    public static func document(
        from records: [SyncRecord],
        applyingTo local: SetlineDocument
    ) throws -> SetlineDocument {
        let decoder = makeDecoder()
        var templates = local.templates.filter(\.isBundled)
        var history: [WorkoutSession] = []
        var goals: [ExerciseGoal] = []
        var programme = local.programme

        for record in records.sorted(by: { $0.recordName < $1.recordName }) {
            guard let payload = record.payload else { continue }
            switch record.kind {
            case .template:
                templates.append(try decoder.decode(WorkoutTemplate.self, from: payload))
            case .session:
                history.append(try decoder.decode(WorkoutSession.self, from: payload))
            case .goal:
                goals.append(try decoder.decode(ExerciseGoal.self, from: payload))
            case .programme:
                programme = try decoder.decode(ProgrammeSelection.self, from: payload)
            }
        }

        var merged = local
        merged.templates = templates
        // Newest first, matching how history is presented everywhere else.
        merged.history = history.sorted { $0.startedAt > $1.startedAt }
        merged.goals = goals.sorted { $0.createdAt < $1.createdAt }
        merged.programme = programme
        return merged
    }

    // MARK: - Helpers

    static func parse(_ recordName: String) -> (SyncRecordKind, UUID)? {
        guard let separator = recordName.firstIndex(of: "-") else { return nil }
        let rawKind = String(recordName[recordName.startIndex..<separator])
        let rawID = String(recordName[recordName.index(after: separator)...])
        guard let kind = SyncRecordKind(rawValue: rawKind), let id = UUID(uuidString: rawID) else {
            return nil
        }
        return (kind, id)
    }

    /// Sync payloads are internal, so they are encoded for exactness rather than
    /// for reading.
    ///
    /// The export format uses ISO 8601, which truncates to whole seconds. That is
    /// right for a file a person might open, but wrong here: a truncated date does
    /// not decode back to the value it came from, so a record would look edited
    /// every time it made the trip and two edits inside one second would tie on
    /// timestamp and fall through to an arbitrary tie-break.
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSinceReferenceDate)
        }
        // Sorted keys keep the payload byte-identical for identical values, which is
        // what lets fingerprinting detect a real edit rather than a re-encode.
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let seconds = try decoder.singleValueContainer().decode(Double.self)
            return Date(timeIntervalSinceReferenceDate: seconds)
        }
        return decoder
    }
}
