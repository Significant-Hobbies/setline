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
