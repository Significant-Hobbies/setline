import Foundation
import PersonalSyncKit
import SetlineCore
import XCTest

@testable import Setline

final class SetlinePlatformRecordTests: XCTestCase {
  func testSessionProducesTheDomainContract() throws {
    let startedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-21T06:00:00Z"))
    let session = WorkoutSession(
        id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        context: .init(templateID: UUID(), templateName: "Lower strength", startedAt: startedAt, completedAt: startedAt.addingTimeInterval(1_859)),
        state: .init(steps: [])
    )

    guard
      case .object(let record) = SetlinePlatformRecord.session(
        session,
        completedAt: try XCTUnwrap(session.completedAt)
      )
    else {
      return XCTFail("Expected an object record")
    }

    XCTAssertEqual(record["title"], .string("Lower strength"))
    XCTAssertEqual(record["occurredOn"], .string("2026-08-21T06:00:00Z"))
    XCTAssertEqual(record["minutes"], .number(30))
    XCTAssertEqual(record["notes"], .string("0 steps completed"))
  }

  func testRemoteRecordBecomesAStableCompletedSession() throws {
    let change = try decodeChange(
      id: "pace-created-session",
      record: """
        {"title":"Morning walk","occurredOn":"2026-08-21T07:15:00Z","minutes":25,"notes":"Easy pace"}
        """
    )

    let first = try XCTUnwrap(SetlinePlatformRecord.session(from: change))
    let second = try XCTUnwrap(SetlinePlatformRecord.session(from: change))

    XCTAssertEqual(first.id, second.id)
    XCTAssertEqual(first.templateName, "Morning walk")
    XCTAssertEqual(
      first.startedAt, try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-21T07:15:00Z")))
    XCTAssertEqual(first.completedAt?.timeIntervalSince(first.startedAt), 1_500)
    XCTAssertTrue(first.steps.isEmpty)
  }

  func testMalformedRemoteRecordIsIgnored() throws {
    let missingTitle = try decodeChange(id: "missing-title", record: "{\"minutes\":10}")
    let invalidDate = try decodeChange(
      id: "invalid-date",
      record: "{\"title\":\"Walk\",\"occurredOn\":\"not-a-date\"}"
    )

    XCTAssertNil(SetlinePlatformRecord.session(from: missingTitle))
    XCTAssertNil(SetlinePlatformRecord.session(from: invalidDate))
  }

  private func decodeChange(id: String, record: String) throws -> SyncChange {
    let payload = """
      {"cursor":1,"changeId":"change-1","domain":"setline","id":"\(id)","operation":"upsert","version":1,"occurredAt":"2026-08-21T07:15:00Z","recordedAt":"2026-08-21T07:15:01Z","originDeviceId":"pace","record":\(record)}
      """
    return try JSONDecoder().decode(SyncChange.self, from: Data(payload.utf8))
  }
}
