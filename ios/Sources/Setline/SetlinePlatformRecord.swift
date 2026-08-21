import CryptoKit
import Foundation
import PersonalSyncKit
import SetlineCore

enum SetlinePlatformRecord {
  static func session(_ session: WorkoutSession, completedAt: Date) -> JSONValue {
    let minutes = max(0, Int(completedAt.timeIntervalSince(session.startedAt) / 60))
    return .object([
      "title": .string(session.templateName),
      "occurredOn": .string(iso(session.startedAt)),
      "minutes": .number(Double(minutes)),
      "notes": .string("\(session.completedCount) steps completed"),
    ])
  }

  static func session(from change: SyncChange) -> WorkoutSession? {
    guard let object = change.record.objectValue,
      let title = object["title"]?.stringValue,
      let occurred = object["occurredOn"]?.stringValue.flatMap(date)
    else { return nil }
    let minutes = max(0, Int(object["minutes"]?.numberValue ?? 0))
    return WorkoutSession(
        id: stableUUID(change.id),
        context: .init(templateID: stableUUID("template:\(title)"), templateName: title, startedAt: occurred, completedAt: occurred.addingTimeInterval(TimeInterval(minutes * 60))),
        state: .init(steps: [])
    )
  }

  static func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
  private static func date(_ text: String) -> Date? { ISO8601DateFormatter().date(from: text) }

  private static func stableUUID(_ value: String) -> UUID {
    if let uuid = UUID(uuidString: value) { return uuid }
    let bytes = Array(SHA256.hash(data: Data(value.utf8)).prefix(16))
    return UUID(
      uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
      ))
  }
}

extension JSONValue {
  var objectValue: [String: JSONValue]? {
    guard case .object(let value) = self else { return nil }
    return value
  }
  var stringValue: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }
  var numberValue: Double? {
    guard case .number(let value) = self else { return nil }
    return value
  }
}
