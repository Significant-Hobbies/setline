import XCTest
@testable import SetlineCore

final class SetlineCoreTests: XCTestCase {
    func testSessionSnapshotKeepsAuthoredOrderWhenTemplateChanges() throws {
        var document = SetlineDocument.sample
        let templateID = try XCTUnwrap(document.templates.first?.id)
        let authoredNames = try XCTUnwrap(document.templates.first).exercises.flatMap { exercise in
            exercise.sets.map { _ in exercise.name }
        }

        try document.startWorkout(templateID: templateID, at: Date(timeIntervalSince1970: 100))
        document.templates[0].exercises[0].name = "Changed later"

        XCTAssertEqual(document.activeSession?.steps.map(\.exerciseName), authoredNames)
    }

    func testDropSegmentsRemainOrderedInsideOnePlannedSet() throws {
        var document = SetlineDocument.sample
        let templateID = try XCTUnwrap(document.templates.first?.id)
        try document.startWorkout(templateID: templateID)

        let segments = [
            SetSegment(weight: 60, repetitions: 5),
            SetSegment(weight: 50, repetitions: 3),
        ]
        try document.completeCurrent(with: segments, at: Date(timeIntervalSince1970: 500))

        XCTAssertEqual(document.activeSession?.steps.first?.segments, segments)
        XCTAssertEqual(document.activeSession?.steps.first?.status, .complete)
    }

    func testDeferringChangesQueueButRetainsAuthoredPosition() throws {
        var document = SetlineDocument.sample
        let templateID = try XCTUnwrap(document.templates.first?.id)
        try document.startWorkout(templateID: templateID)
        let firstID = try XCTUnwrap(document.activeSession?.steps.first?.id)

        try document.deferCurrent()

        XCTAssertEqual(document.activeSession?.steps.last?.id, firstID)
        XCTAssertEqual(document.activeSession?.steps.last?.authoredPosition, 0)
        XCTAssertEqual(document.activeSession?.steps.last?.status, .deferred)
    }

    func testExtraSetDoesNotModifyTemplate() throws {
        var document = SetlineDocument.sample
        let template = try XCTUnwrap(document.templates.first)
        let originalSetCount = template.exercises.flatMap(\.sets).count
        try document.startWorkout(templateID: template.id)

        try document.addExtraSet()

        XCTAssertEqual(document.activeSession?.steps.count, originalSetCount + 1)
        XCTAssertEqual(document.templates.first?.exercises.flatMap(\.sets).count, originalSetCount)
        XCTAssertTrue(document.activeSession?.steps[1].isExtra == true)
    }

    func testRestUsesWallClockTimestamps() throws {
        var document = SetlineDocument.sample
        let templateID = try XCTUnwrap(document.templates.first?.id)
        let start = Date(timeIntervalSince1970: 1_000)
        try document.startWorkout(templateID: templateID, at: start)
        try document.completeCurrent(
            with: [SetSegment(weight: 40, repetitions: 8)],
            at: start
        )
        let rest = try XCTUnwrap(document.activeSession?.rest)

        XCTAssertEqual(rest.remaining(at: start.addingTimeInterval(17)), rest.adjustedSeconds - 17)
        XCTAssertEqual(rest.actual(at: start.addingTimeInterval(31)), 31)
    }

    func testPersistenceRestoresActiveSession() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let url = directory.appending(path: "setline.json")
        let store = SetlineStore(fileURL: url)
        var document = SetlineDocument.sample
        let templateID = try XCTUnwrap(document.templates.first?.id)
        let timestamp = Date(timeIntervalSince1970: 10_000)
        try document.startWorkout(templateID: templateID, at: timestamp)
        try document.completeCurrent(with: [SetSegment(weight: 40, repetitions: 8)], at: timestamp)

        try await store.save(document)
        let restored = try await store.load()

        XCTAssertEqual(restored, document)
        XCTAssertNotNil(restored.activeSession?.rest)
    }

    func testDuplicateTemplateIsIndependent() throws {
        var document = SetlineDocument.sample
        let original = try XCTUnwrap(document.templates.first)
        try document.duplicateTemplate(original.id)

        let copy = try XCTUnwrap(document.templates.last)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertNotEqual(copy.exercises.first?.id, original.exercises.first?.id)
        XCTAssertFalse(copy.isBundled)
    }

    func testProgressionRequiresComparableEvidence() {
        let step = WorkoutStep(
            plannedSetID: UUID(),
            exerciseName: "Front squat",
            cue: "",
            label: "Working",
            kind: .strength,
            target: "60 kg × 5",
            authoredPosition: 0,
            restSeconds: 120,
            status: .complete,
            segments: [SetSegment(weight: 60, repetitions: 5)]
        )
        let history = [
            WorkoutSession(templateID: UUID(), templateName: "A", startedAt: .now, completedAt: .now, steps: [step]),
            WorkoutSession(templateID: UUID(), templateName: "A", startedAt: .now, completedAt: .now, steps: [step]),
        ]

        let recommendation = ProgressionEngine.recommendation(for: "Front squat", history: history)

        XCTAssertEqual(recommendation?.previousWeight, 60)
        XCTAssertEqual(recommendation?.recommendedWeight, 62.5)
        XCTAssertTrue(recommendation?.rationale.contains("session only") == true)
    }
}
