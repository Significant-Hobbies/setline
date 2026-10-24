import Foundation
import SetlineCore
import XCTest

@testable import Setline

@MainActor
final class SetlineWorkoutFidelityTests: XCTestCase {
    func testFinishedHistoryPreservesAnExplicitDeferral() async throws {
        let fixture = try LocalWorkoutFixture()
        defer { fixture.cleanup() }

        await fixture.model.load()
        let template = authoredTemplate(name: "Deferral fidelity", rests: [45, 75, 105])
        let templateSaved = await fixture.model.saveTemplate(template)
        XCTAssertTrue(templateSaved)
        await fixture.model.startWorkout(template)

        let deferredID = try XCTUnwrap(fixture.model.document.activeSession?.currentStep?.id)
        await fixture.model.deferCurrent()
        XCTAssertEqual(fixture.model.document.activeSession?.steps.last?.status, .deferred)
        await fixture.model.finishWorkout()

        let reopened = AppModel(store: fixture.store, mirror: nil)
        await reopened.load()
        let saved = try XCTUnwrap(reopened.document.history.first)
        let deferred = try XCTUnwrap(saved.steps.first { $0.id == deferredID })
        XCTAssertEqual(deferred.status, .deferred, "Saving a finished workout must not turn Do later into Skip")
        XCTAssertEqual(saved.steps.filter { $0.status == .skipped }.count, 2)
    }

    func testThreeAuthoredSessionLedgersAndCorrectionRepeatSurviveLocalRecovery() async throws {
        let fixture = try LocalWorkoutFixture()
        defer { fixture.cleanup() }

        await fixture.model.load()
        let queueTemplate = authoredTemplate(name: "Queue deviations", rests: [45, 75, 105])
        let interruptedTemplate = authoredTemplate(name: "Interrupted deferral", rests: [35, 65, 95])
        let timedTemplate = timedTemplate(name: "Timed mobility", rests: [0, 30, 0])
        for template in [queueTemplate, interruptedTemplate, timedTemplate] {
            let saved = await fixture.model.saveTemplate(template)
            XCTAssertTrue(saved)
        }

        // Case 1: partial/drop segments, adjusted rest, explicit skip, and a
        // session-only extra set retain distinct performed and authored slots.
        await fixture.model.startWorkout(queueTemplate)
        await fixture.model.completeCurrent(segments: [
            SetSegment(loadMetrics: .init(weight: 40, repetitions: 5)),
            SetSegment(loadMetrics: .init(weight: 30, repetitions: 2)),
        ])
        let firstRest = try XCTUnwrap(fixture.model.document.activeSession?.rest)
        XCTAssertEqual(firstRest.authoredSeconds, 45)
        await fixture.model.adjustRest(by: 15)
        XCTAssertEqual(fixture.model.document.activeSession?.rest?.adjustedSeconds, 60)
        await fixture.model.endRest()
        await fixture.model.skipCurrent()
        await fixture.model.addExtraSet()
        await fixture.model.completeCurrent(segments: [SetSegment(loadMetrics: .init(weight: 50, repetitions: 4))])
        await fixture.model.completeCurrent(segments: [SetSegment(loadMetrics: .init(weight: 45, repetitions: 3))])
        await fixture.model.finishWorkout()

        // Case 2: one completed set is in its authored rest when the process is
        // interrupted. Reopening the same local store recovers the timer and
        // queue; the user defers the next set, then completes the later one.
        await fixture.model.startWorkout(interruptedTemplate)
        let interruptedID = try XCTUnwrap(fixture.model.document.activeSession?.id)
        await fixture.model.completeCurrent(segments: [SetSegment(loadMetrics: .init(weight: 42, repetitions: 6))])
        let interruptedRest = try XCTUnwrap(fixture.model.document.activeSession?.rest)
        XCTAssertEqual(interruptedRest.authoredSeconds, 35)
        let resumed = AppModel(store: fixture.store, mirror: nil)
        await resumed.load()
        XCTAssertEqual(resumed.document.activeSession?.id, interruptedID)
        XCTAssertEqual(resumed.document.activeSession?.rest, interruptedRest)
        await resumed.endRest()
        let deferredID = try XCTUnwrap(resumed.document.activeSession?.currentStep?.id)
        await resumed.deferCurrent()
        await resumed.completeCurrent(segments: [SetSegment(loadMetrics: .init(weight: 52, repetitions: 5))])
        await resumed.finishWorkout()

        // Case 3: activity-specific timed results survive an interruption and
        // remain separate from the authored time target and rest prescription.
        await resumed.startWorkout(timedTemplate)
        await resumed.completeCurrent(segments: [SetSegment(enduranceMetrics: .init(durationSeconds: 123))])
        let resumedTimed = AppModel(store: fixture.store, mirror: nil)
        await resumedTimed.load()
        XCTAssertEqual(resumedTimed.document.activeSession?.currentStep?.exerciseName, "Fixture mobility")
        await resumedTimed.completeCurrent(segments: [SetSegment(enduranceMetrics: .init(durationSeconds: 118))])
        let timedRest = try XCTUnwrap(resumedTimed.document.activeSession?.rest)
        XCTAssertEqual(timedRest.authoredSeconds, 30)
        await resumedTimed.adjustRest(by: 15)
        XCTAssertEqual(resumedTimed.document.activeSession?.rest?.adjustedSeconds, 45)
        await resumedTimed.endRest()
        await resumedTimed.completeCurrent(segments: [SetSegment(enduranceMetrics: .init(durationSeconds: 110))])
        await resumedTimed.finishWorkout()

        // Repeat the selected correction on the same authored template under a
        // new session ID, including another interruption/reopen before saving.
        await resumedTimed.startWorkout(interruptedTemplate)
        let repeatID = try XCTUnwrap(resumedTimed.document.activeSession?.id)
        await resumedTimed.deferCurrent()
        let repeated = AppModel(store: fixture.store, mirror: nil)
        await repeated.load()
        XCTAssertEqual(repeated.document.activeSession?.id, repeatID)
        await repeated.completeCurrent(segments: [SetSegment(loadMetrics: .init(weight: 42, repetitions: 6))])
        await repeated.completeCurrent(segments: [SetSegment(loadMetrics: .init(weight: 52, repetitions: 5))])
        await repeated.finishWorkout()

        let persistedModel = AppModel(store: fixture.store, mirror: nil)
        await persistedModel.load()
        let history = persistedModel.document.history
        XCTAssertEqual(history.count, 4)
        XCTAssertEqual(Set(history.map(\.id)).count, 4, "Three authored cases plus a new correction-repeat session")

        let queue = try XCTUnwrap(history.first { $0.templateName == queueTemplate.name })
        XCTAssertEqual(queue.steps.map(\.authoredPosition), [0, 1, 2, 2])
        XCTAssertEqual(queue.steps.map(\.status), [.complete, .skipped, .complete, .complete])
        XCTAssertEqual(queue.steps.first?.segments.count, 2)
        XCTAssertTrue(queue.steps.last?.isExtra == true)
        XCTAssertEqual(fixture.model.document.templates.first { $0.id == queueTemplate.id }, queueTemplate)

        let interrupted = try XCTUnwrap(history.first { $0.id == interruptedID })
        let deferred = try XCTUnwrap(interrupted.steps.first { $0.id == deferredID })
        XCTAssertEqual(deferred.status, .deferred)
        XCTAssertEqual(deferred.authoredPosition, 1)
        XCTAssertEqual(interrupted.steps.filter { $0.status == .skipped }.count, 0)

        let timed = try XCTUnwrap(history.first { $0.templateName == timedTemplate.name })
        XCTAssertEqual(timed.steps.compactMap { $0.segments.first?.durationSeconds }, [123, 118, 110])
        XCTAssertEqual(timed.steps.map(\.rest.timerSeconds), [0, 30, 0])

        let repeatedSession = try XCTUnwrap(history.first { $0.id == repeatID })
        XCTAssertEqual(repeatedSession.steps.first?.status, .complete)
        XCTAssertEqual(repeatedSession.steps.first { $0.authoredPosition == 0 }?.status, .deferred)
        XCTAssertEqual(repeatedSession.completedWorkingSetCount, 2)
    }
}

@MainActor
private final class LocalWorkoutFixture {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    lazy var store = SetlineStore(fileURL: root.appending(path: "setline.json"))
    lazy var model = AppModel(store: store, mirror: nil)

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

private func authoredTemplate(name: String, rests: [Int]) -> WorkoutTemplate {
    let sets = rests.enumerated().map { index, rest in
        PlannedSet(
            label: "Set \(index + 1)",
            kind: .strength,
            target: SetTarget(
                repTarget: .init(repsLow: 5 + index),
                load: .absolute(kilograms: 40 + Double(index * 5))
            ),
            rest: RestRange(rest)
        )
    }
    return WorkoutTemplate(
        name: name,
        detail: "Disposable authored fixture",
        isBundled: false,
        exercises: [Exercise(name: "Fixture squat", cue: "Controlled", sets: sets)]
    )
}

private func timedTemplate(name: String, rests: [Int]) -> WorkoutTemplate {
    let sets = rests.enumerated().map { index, rest in
        PlannedSet(
            label: "Interval \(index + 1)",
            kind: .timed,
            target: SetTarget(timeTarget: .init(timeSeconds: 90 + index * 15)),
            rest: RestRange(rest),
            config: .init(stepType: .mobility)
        )
    }
    return WorkoutTemplate(
        name: name,
        detail: "Disposable timed fixture",
        isBundled: false,
        exercises: [Exercise(name: "Fixture mobility", cue: "Use a comfortable range", sets: sets, pillars: [.mobility])]
    )
}
