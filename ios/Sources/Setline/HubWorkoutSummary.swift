import Foundation
import PersonalSyncKit
import SetlineCore

/// The Hub receives this allowlist, never Setline's CloudKit entity envelope.
enum HubWorkoutSummary {
    private static let prefix = "summary-"

    private struct Summary: Codable {
        var name: String
        var startedAt: Date
        var durationSeconds: Double
        var completedStepCount: Int
    }

    private struct Envelope: Codable {
        var recordType = "session"
        var projection = "completed-workout-summary-v1"
        var entityId: String
        var occurredAt: Date
        var data: Summary
    }

    static func isSummaryName(_ name: String) -> Bool {
        name.hasPrefix(prefix) && UUID(uuidString: String(name.dropFirst(prefix.count))) != nil
    }

    static func records(for document: SetlineDocument) throws -> [MirrorRecord] {
        guard document.activeSession == nil, let owner = document.hubAccountID else { return [] }
        return try document.approvedHubHistory(for: owner).compactMap { session in
            guard let end = session.completedAt, end >= session.startedAt else { return nil }
            let seconds = end.timeIntervalSince(session.startedAt)
            guard seconds.isFinite else { return nil }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let payload = try encoder.encode(Envelope(
                entityId: session.id.uuidString.lowercased(), occurredAt: session.startedAt,
                data: Summary(name: session.templateName, startedAt: session.startedAt,
                              durationSeconds: seconds, completedStepCount: session.completedCount)
            ))
            return MirrorRecord(name: prefix + session.id.uuidString.lowercased(),
                                modifiedAt: end, payload: payload, appendOnly: true)
        }
    }

    /// Restored summaries stay visibly incomplete and can never replace native
    /// set history. Older full-session Hub payloads are reduced at this boundary.
    static func apply(_ record: MirrorRecord, to document: inout SetlineDocument) throws {
        guard let owner = document.hubAccountID else { return }
        if record.isDeleted {
            document.history.removeAll { $0.hubRecordID == record.name && $0.hubAccountID == owner }
            return
        }
        guard let payload = record.payload else { return }
        let session: WorkoutSession
        if isSummaryName(record.name) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(Envelope.self, from: payload)
            guard envelope.recordType == "session",
                  envelope.projection == "completed-workout-summary-v1",
                  let id = UUID(uuidString: envelope.entityId),
                  record.name == prefix + id.uuidString.lowercased(),
                  envelope.data.durationSeconds.isFinite, envelope.data.durationSeconds >= 0,
                  envelope.data.completedStepCount >= 0 else {
                throw SetlineMirrorError.invalidEntityPayload
            }
            session = WorkoutSession(id: id, context: .init(
                templateID: id, templateName: envelope.data.name,
                startedAt: envelope.data.startedAt,
                completedAt: envelope.data.startedAt.addingTimeInterval(envelope.data.durationSeconds)
            ), state: .init(steps: []), hubRecordID: record.name, hubAccountID: owner,
                hubSummaryCompletedStepCount: envelope.data.completedStepCount)
        } else {
            // Compatibility with the previous mirror: only completed session
            // summaries are eligible. Templates, goals and plans are ignored.
            guard let (kind, id) = SyncEngine.parse(record.name), kind == .session,
                  let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
                  let data = object["data"] else { return }
            let legacy = try SyncEngine.makeDecoder().decode(WorkoutSession.self,
                from: JSONSerialization.data(withJSONObject: data))
            guard legacy.id == id, let end = legacy.completedAt, end >= legacy.startedAt,
                  legacy.hubAccountID == nil || legacy.hubAccountID == owner else { return }
            session = WorkoutSession(id: id, context: .init(
                templateID: id, templateName: legacy.templateName,
                startedAt: legacy.startedAt, completedAt: end
            ), state: .init(steps: []), hubRecordID: record.name, hubAccountID: owner,
                hubSummaryCompletedStepCount: legacy.completedCount)
        }
        if let index = document.history.firstIndex(where: { $0.id == session.id }) {
            guard document.history[index].hubRecordID != nil,
                  document.history[index].hubAccountID == owner else { return }
            document.history[index] = session
        } else {
            document.history.append(session)
        }
    }
}
