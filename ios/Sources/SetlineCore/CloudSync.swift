import Foundation

/// The versioned document exchanged by native Setline clients.
/// Device-only synchronization metadata is deliberately excluded so a successful
/// sync never creates another document change by itself.
public struct SetlineCloudDocument: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var templates: [WorkoutTemplate]
    public var programme: ProgrammeSelection
    public var activeSession: WorkoutSession?
    public var history: [WorkoutSession]

    public init(document: SetlineDocument) {
        schemaVersion = document.schemaVersion
        templates = document.templates
        programme = document.programme
        activeSession = document.activeSession
        history = document.history
    }

    public func localDocument(
        syncState: SyncState = .synced,
        lastSyncedAt: Date = .now
    ) -> SetlineDocument {
        SetlineDocument(
            schemaVersion: schemaVersion,
            templates: templates,
            programme: programme,
            activeSession: activeSession,
            history: history,
            syncState: syncState,
            lastSyncedAt: lastSyncedAt
        )
    }
}

public struct SetlineCloudSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var document: SetlineCloudDocument
    public var revision: Int

    public init(document: SetlineCloudDocument, revision: Int) {
        self.document = document
        self.revision = revision
    }

    public var id: Int { revision }
}
