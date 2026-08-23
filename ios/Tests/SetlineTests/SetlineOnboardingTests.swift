import SetlineCore
import XCTest

@testable import Setline

final class SetlineOnboardingTests: XCTestCase {
    func testFreshBundledDocumentPresentsOnboarding() {
        XCTAssertTrue(SetlineOnboardingPolicy.shouldPresent(document: .initial, completed: false))
    }

    func testCompletionBypassesOnboarding() {
        XCTAssertFalse(SetlineOnboardingPolicy.shouldPresent(document: .initial, completed: true))
    }

    func testActiveWorkoutDefersIllustratedOrientation() throws {
        var document = SetlineDocument.initial
        let template = TwelveWeekProgramme.template(for: .lower, week: 1)
        try document.startWorkout(template: template)
        XCTAssertFalse(SetlineOnboardingPolicy.shouldPresent(document: document, completed: false))
        XCTAssertTrue(SetlineOnboardingPolicy.hasExistingData(document))
    }

    func testExistingOwnerReceivesIllustratedOrientationOnceIdle() {
        XCTAssertTrue(SetlineOnboardingPolicy.shouldPresent(document: .sample, completed: false))
        XCTAssertTrue(SetlineOnboardingPolicy.hasExistingData(.sample))
        XCTAssertFalse(SetlineOnboardingPolicy.shouldPresent(document: .sample, completed: true))
    }
}
