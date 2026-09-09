#if DEBUG
import XCTest
import SetlineCore
@testable import Setline

@MainActor
final class PersistentUIFixtureTests: XCTestCase {
    func testFixtureIdentifierCannotSelectAnArbitraryPathOrResettingDemo() throws {
        XCTAssertNil(try PersistentUIFixture(arguments: []))
        XCTAssertThrowsError(try PersistentUIFixture(arguments: ["--ui-fixture-cleanup"]))
        XCTAssertThrowsError(try PersistentUIFixture(arguments: ["--ui-persistent-fixture"]))
        XCTAssertThrowsError(try PersistentUIFixture(arguments: ["--ui-persistent-fixture", "../../owner.json"]))
        XCTAssertThrowsError(try PersistentUIFixture(arguments: ["--ui-persistent-fixture", UUID().uuidString, "--ui-demo"]))
        let a = try XCTUnwrap(PersistentUIFixture(arguments: ["--ui-persistent-fixture", UUID().uuidString]))
        let b = try XCTUnwrap(PersistentUIFixture(arguments: ["--ui-persistent-fixture", UUID().uuidString]))
        XCTAssertNotEqual(a.directory, b.directory)
        XCTAssertNotEqual(a.defaultsName, b.defaultsName)
    }

    func testExistingMalformedFixtureIsNeverOverwrittenBySeeding() async throws {
        let arguments = ["--ui-persistent-fixture", UUID().uuidString]
        let fixture = try XCTUnwrap(PersistentUIFixture(arguments: arguments))
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        try FileManager.default.createDirectory(at: fixture.directory, withIntermediateDirectories: true)
        let malformed = Data("unreadable synthetic workout".utf8)
        try malformed.write(to: fixture.fileURL)
        let store = SetlineStore(fileURL: fixture.fileURL)
        try await PersistentUIFixture.seedIfRequested(store: store, arguments: arguments)
        XCTAssertEqual(try Data(contentsOf: fixture.fileURL), malformed)
    }

    func testFixtureSeedsOnlyOnceAndRejectsMismatchedStore() async throws {
        let arguments = ["--ui-persistent-fixture", UUID().uuidString]
        let fixture = try XCTUnwrap(PersistentUIFixture(arguments: arguments))
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let store = SetlineStore(fileURL: fixture.fileURL)
        try await PersistentUIFixture.seedIfRequested(store: store, arguments: arguments)
        let original = try Data(contentsOf: fixture.fileURL)
        try await PersistentUIFixture.seedIfRequested(store: store, arguments: arguments)
        XCTAssertEqual(try Data(contentsOf: fixture.fileURL), original)
        do {
            try await PersistentUIFixture.seedIfRequested(store: SetlineStore(fileURL: fixture.directory.appendingPathComponent("wrong.json")), arguments: arguments)
            XCTFail("A fixture must not seed another store")
        } catch PersistentUIFixture.Failure.mismatchedStore {}
    }
    func testCleanupRemovesOnlyItsUUIDAndCannotReseed() async throws {
        let id = UUID().uuidString
        let arguments = ["--ui-persistent-fixture", id]
        let fixture = try XCTUnwrap(PersistentUIFixture(arguments: arguments))
        let sibling = try XCTUnwrap(PersistentUIFixture(arguments: ["--ui-persistent-fixture", UUID().uuidString]))
        defer {
            try? FileManager.default.removeItem(at: fixture.directory)
            try? FileManager.default.removeItem(at: sibling.directory)
            UserDefaults(suiteName: fixture.defaultsName)?.removePersistentDomain(forName: fixture.defaultsName)
        }
        let store = SetlineStore(fileURL: fixture.fileURL)
        try await PersistentUIFixture.seedIfRequested(store: store, arguments: arguments)
        try FileManager.default.createDirectory(at: sibling.directory, withIntermediateDirectories: true)
        let marker = Data("Other fixture stays".utf8)
        try marker.write(to: sibling.fileURL)
        UserDefaults(suiteName: fixture.defaultsName)?.set("synthetic", forKey: "cleanup-test")
        let cleanupArguments = arguments + ["--ui-fixture-cleanup"]
        let cleanup = try XCTUnwrap(PersistentUIFixture(arguments: cleanupArguments))
        let defaults = try cleanup.defaultsForLaunch()
        try await PersistentUIFixture.seedIfRequested(store: store, arguments: cleanupArguments)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.directory.path))
        XCTAssertNil(defaults.string(forKey: "cleanup-test"))
        XCTAssertEqual(try Data(contentsOf: sibling.fileURL), marker)
    }

}
#endif
