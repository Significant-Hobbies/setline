import Foundation
import SetlineCore
import XCTest

@testable import Setline

@MainActor
final class SetlineLocalSaveTests: XCTestCase {
    func testFailedTemplateSaveCannotReportSuccessAndCanRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blocker = root.appending(path: "blocked")
        try Data("not a directory".utf8).write(to: blocker)
        let store = SetlineStore(fileURL: blocker.appending(path: "workouts.json"))
        let model = AppModel(store: store, syncCoordinator: nil, platform: nil)
        await model.load()
        var draft = TwelveWeekProgramme.template(for: .lower, week: 1)
        draft.id = UUID()
        draft.name = "Synthetic programme"
        await model.saveTemplate(draft)
        XCTAssertNotEqual(model.message, "Template saved.")
        XCTAssertFalse(model.document.templates.contains { $0.id == draft.id })
        try FileManager.default.removeItem(at: blocker)
        await model.saveTemplate(draft)
        XCTAssertEqual(model.message, "Template saved.")
        let reloaded = try await store.load()
        XCTAssertTrue(reloaded.templates.contains { $0.id == draft.id })
    }

    func testConcurrentMeasurementsDoNotOverwriteEachOther() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SetlineStore(fileURL: root.appending(path: "workouts.json"))
        let model = AppModel(store: store, syncCoordinator: nil, platform: nil)
        await model.load()
        async let first: Void = model.updateBenchmarkNumber("synthetic", field: "first", value: 11)
        async let second: Void = model.updateBenchmarkNumber("synthetic", field: "second", value: 22)
        _ = await (first, second)
        let reloaded = try await store.load()
        XCTAssertEqual(reloaded.benchmarks.metrics["synthetic"]?.numbers["first"], 11)
        XCTAssertEqual(reloaded.benchmarks.metrics["synthetic"]?.numbers["second"], 22)
    }

    func testFailedLoadDoesNotAllowAnInitialDocumentToOverwriteTheFile() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appending(path: "workouts.json")
        let original = Data("unreadable retained workout history".utf8)
        try original.write(to: file)
        let model = AppModel(store: SetlineStore(fileURL: file), syncCoordinator: nil, platform: nil)
        await model.load()
        await model.updateBenchmarkNumber("synthetic", field: "first", value: 11)
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
    func testFailedWorkoutWritePreservesSessionAndRetrySurvivesReload() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "workouts.json")
        let backup = root.appending(path: "retained.json")
        let store = SetlineStore(fileURL: file)
        var initial = SetlineDocument.sample
        let template = try XCTUnwrap(initial.templates.first)
        try initial.startWorkout(templateID: template.id)
        try await store.save(initial)
        let model = AppModel(store: store, syncCoordinator: nil, platform: nil)
        await model.load()
        model.isWorkoutPresented = true
        let previous = model.document.activeSession
        let previousHistory = model.document.history
        try FileManager.default.moveItem(at: file, to: backup)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        let segments = [SetSegment(loadMetrics: .init(weight: 40, repetitions: 8))]
        await model.completeCurrent(segments: segments)
        XCTAssertEqual(model.document.activeSession, previous)
        await model.finishWorkout()
        XCTAssertEqual(model.document.activeSession, previous)
        XCTAssertEqual(model.document.history, previousHistory)
        XCTAssertTrue(model.isWorkoutPresented)

        try FileManager.default.removeItem(at: file)
        try FileManager.default.moveItem(at: backup, to: file)
        await model.completeCurrent(segments: segments)
        let reloaded = try await store.load()
        XCTAssertEqual(reloaded.activeSession?.steps.first?.segments, segments)
        XCTAssertNotNil(reloaded.activeSession?.rest)
        XCTAssertEqual(reloaded.templates.first, template)
        await model.finishWorkout()
        let finished = try await store.load()
        XCTAssertNil(finished.activeSession)
        XCTAssertFalse(model.isWorkoutPresented)
        XCTAssertEqual(finished.history.first?.steps.first?.segments, segments)
        XCTAssertEqual(finished.templates.first, template)
    }

    func testFailedGoalAndCheckInSavesKeepPriorValues() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "workouts.json")
        let store = SetlineStore(fileURL: file)
        let model = AppModel(store: store, syncCoordinator: nil, platform: nil)
        await model.load()
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        let goal = ExerciseGoal(exerciseName: "Bench press", metric: .topSetLoad, targetValue: 80)
        let failed = await model.saveGoal(goal)
        XCTAssertFalse(failed)
        XCTAssertFalse(model.document.goals.contains { $0.id == goal.id })
        XCTAssertNotEqual(model.message, "Target saved.")
        await model.saveBenchmarkCheckIn(date: .now)
        XCTAssertTrue(model.document.benchmarks.history.isEmpty)
        XCTAssertNotEqual(model.message, "Check-in saved.")
        try FileManager.default.removeItem(at: file)
        let saved = await model.saveGoal(goal)
        XCTAssertTrue(saved)
        await model.saveBenchmarkCheckIn(date: .now)
        let reloaded = try await store.load()
        XCTAssertTrue(reloaded.goals.contains { $0.id == goal.id })
        XCTAssertEqual(reloaded.benchmarks.history.count, 1)
    }

    func testExplicitBackupRestoreRecoversUnreadableFileAndAllowsLaterEdits() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appending(path: "workouts.json")
        let original = Data("unreadable retained document".utf8)
        try original.write(to: file)
        let store = SetlineStore(fileURL: file)
        let model = AppModel(store: store, syncCoordinator: nil, platform: nil)
        await model.load()
        XCTAssertFalse(model.hasLoadedDocument)
        await model.prepareImport(Data("invalid backup".utf8))
        XCTAssertNil(model.importPreview)
        XCTAssertEqual(try Data(contentsOf: file), original)
        let backupDocument = SetlineDocument.sample
        let backup = try await store.export(backupDocument)
        await model.prepareImport(backup)
        XCTAssertTrue(model.isImportConfirmationPresented)
        XCTAssertEqual(try Data(contentsOf: file), original, "Preview cannot replace the retained file")
        await model.confirmImport()
        XCTAssertTrue(model.hasLoadedDocument)
        XCTAssertNil(model.importPreview)
        XCTAssertFalse(model.isImportConfirmationPresented)
        XCTAssertEqual(model.document.templates, backupDocument.templates)
        await model.updateBenchmarkNumber("synthetic", field: "afterRestore", value: 33)
        let reloaded = try await store.load()
        XCTAssertEqual(reloaded.benchmarks.metrics["synthetic"]?.numbers["afterRestore"], 33)
        let exported = await model.exportData()
        XCTAssertNotNil(exported)
    }

}
