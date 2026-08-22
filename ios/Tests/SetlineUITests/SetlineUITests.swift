import XCTest

@MainActor
final class SetlineUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// `--ui-demo` pins a fixed fixture so these tests never depend on which day of
    /// the authored twelve-week block today happens to be.
    private func launch(_ arguments: [String] = ["--ui-demo"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// Starts with the real bundled programme but bypasses first-run onboarding.
    ///
    /// `--fresh-demo` deliberately uses an empty local document. On a clean CI
    /// simulator that also qualifies for onboarding, so tests of the settled app
    /// must explicitly provide the completion default rather than inherit state
    /// left behind by an earlier test or a developer's simulator.
    private func launchFreshSettledApp() -> XCUIApplication {
        launch(["--fresh-demo", "-setline.onboarding.completed.v1", "YES"])
    }

    /// The decimal keypad has no return key, so the player supplies a Done button
    /// above it. Entry is unusable without one, which is why this taps the real
    /// control rather than working around its absence.
    private func dismissKeyboard(_ app: XCUIApplication) {
        guard app.keyboards.count > 0 else { return }
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 2) {
            done.tap()
        }
    }

    /// Records the current set and waits for the authored rest to start.
    ///
    /// The record button sits below a set timer and a variable number of segment
    /// rows, so it may need scrolling into reach. Retrying around the observable
    /// outcome — the rest board appearing — keeps this from depending on where the
    /// button happens to land.
    private func recordSetAndWaitForRest(_ app: XCUIApplication) {
        let rest = app.staticTexts["REST · WALL CLOCK"]
        for _ in 0..<3 {
            dismissKeyboard(app)
            let record = app.buttons["Record set · start rest"]
            guard record.waitForExistence(timeout: 3), record.isHittable else {
                app.swipeUp()
                continue
            }
            record.tap()
            if rest.waitForExistence(timeout: 5) { return }
        }
        XCTFail("Recording the set did not start the authored rest period")
    }

    private func text(_ app: XCUIApplication, containing fragment: String) -> XCUIElement {
        app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", fragment)
        ).firstMatch
    }

    /// Brings an element into view before acting on it, the way a person would.
    ///
    /// History and session receipts scroll, and how far down a row sits depends on
    /// how much summary content sits above it. Waiting for existence alone is not
    /// enough: SwiftUI has not built the row yet, so the wait expires on content
    /// that is genuinely there.
    ///
    /// Pass `hittable` for something about to be tapped — an off-screen row cannot be
    /// tapped reliably. Plain existence is right for an assertion, where a built but
    /// scrolled-past label is proof enough that the value is present.
    @discardableResult
    private func scrollUntil(
        _ app: XCUIApplication,
        _ element: XCUIElement,
        scanning direction: ScanDirection,
        hittable: Bool = false
    ) -> Bool {
        func satisfied() -> Bool { hittable ? element.isHittable : element.exists }
        // Give SwiftUI a moment to build the cell before moving anything: a lazily
        // built list can hold a real value that is not in the hierarchy yet, and
        // scrolling first would walk away from a row already just above the fold.
        if element.waitForExistence(timeout: 2), satisfied() { return true }
        // Then scan the way the content lies. Sweeping both directions blindly costs
        // eight useless swipes per lookup, which tripled this suite's runtime.
        for _ in 0..<8 {
            switch direction {
            case .down: app.swipeUp()
            case .up: app.swipeDown()
            }
            if satisfied() { return true }
        }
        return satisfied()
    }

    /// Which way the wanted element lies from the current scroll position.
    private enum ScanDirection {
        /// Further down the list, so the content moves up.
        case down
        /// Back towards the top, where a freshly pushed screen starts.
        case up
    }

    /// Opens a recorded session from History by tapping its row rather than any text
    /// that happens to mention the workout's name.
    private func openHistorySession(_ app: XCUIApplication, named name: String) {
        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()

        // A NavigationLink is a button; the summary sections above the list also
        // contain this text, and tapping one of those navigates nowhere.
        let row = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", name)
        ).firstMatch
        XCTAssertTrue(
            scrollUntil(app, row, scanning: .down, hittable: true),
            "No history row for \(name) was reachable"
        )
        row.tap()
    }

    func testStartsWorkoutAndShowsTimestampRest() {
        let app = launch()

        XCTAssertTrue(app.staticTexts["Follow the plan.\nRecord the truth."].waitForExistence(timeout: 3))
        app.buttons["Start workout"].tap()
        XCTAssertTrue(app.staticTexts["Front squat"].waitForExistence(timeout: 3))

        let reps = app.textFields["Reps"]
        reps.tap()
        reps.typeText("8")
        let weight = app.textFields["Weight"]
        weight.tap()
        weight.typeText("40")
        recordSetAndWaitForRest(app)

        XCTAssertTrue(app.buttons["Start next early"].exists)
    }

    func testSetTimerRunsIndependentlyOfRest() {
        let app = launch()

        app.buttons["Start workout"].tap()
        XCTAssertTrue(app.staticTexts["SET TIMER"].waitForExistence(timeout: 3))
        let start = app.buttons["Start set"]
        XCTAssertTrue(start.exists)
        start.tap()
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 2))
        app.buttons["Stop"].tap()
        XCTAssertTrue(app.buttons["Start set"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Reset"].exists)
    }

    /// The headline requirement: `5 reps × 40 kg` then `2 reps × 30 kg`, recorded as
    /// one set, surviving all the way into the session receipt.
    func testRecordsTwoSegmentsAsOneSetAndKeepsBothInTheReceipt() {
        let app = launch()

        app.buttons["Start workout"].tap()
        XCTAssertTrue(app.staticTexts["Front squat"].waitForExistence(timeout: 3))

        app.buttons["Type it"].tap()
        let shorthand = app.textFields["Shorthand set entry"]
        XCTAssertTrue(shorthand.waitForExistence(timeout: 5))
        shorthand.tap()
        shorthand.typeText("5x40, 2x30")

        // The interpretation is shown before anything is recorded.
        let reading = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Reads as:")
        ).firstMatch
        XCTAssertTrue(reading.waitForExistence(timeout: 5))

        app.buttons["Apply to segments"].tap()
        XCTAssertTrue(app.staticTexts["SEGMENT 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["All 2 segments record as one set."].exists)

        recordSetAndWaitForRest(app)

        app.buttons["Finish"].tap()
        app.buttons["Finish and save"].tap()

        openHistorySession(app, named: "Lower strength")

        let recorded = text(app, containing: "5 × 40 kg + 2 × 30 kg")
        XCTAssertTrue(
            scrollUntil(app, recorded, scanning: .up),
            "Both segments must survive into the receipt as one set"
        )
    }

    func testCoreTabsAreReachable() {
        let app = launch()

        for tab in ["Plan", "History", "You", "Exercises"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.staticTexts[tab].waitForExistence(timeout: 2))
        }
    }

    func testAuthoredBlockDrivesTodayOnAFreshInstall() {
        let app = launchFreshSettledApp()

        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(
            app.staticTexts["12-Week Strength, Cardio & Mobility Plan"].waitForExistence(timeout: 3)
        )
        // Checkpoints are part of the authored block, not an afterthought.
        XCTAssertTrue(app.staticTexts["Baseline"].exists)
        XCTAssertTrue(app.staticTexts["End of block"].exists)
    }

    func testOnboardingStartsRealWorkoutAndRecordsFirstSet() {
        let app = launch(["--onboarding-demo"])

        XCTAssertTrue(app.staticTexts["Follow the plan.\nRecord the truth."].waitForExistence(timeout: 5))
        app.buttons["Use the bundled programme"].tap()
        XCTAssertTrue(app.staticTexts["REVIEW BEFORE YOU START"].waitForExistence(timeout: 3))
        app.buttons["Start this session"].tap()

        XCTAssertTrue(app.staticTexts["Easy treadmill, bike or rower"].waitForExistence(timeout: 5))
        let duration = app.textFields["Duration"]
        duration.tap()
        duration.typeText("3")
        dismissKeyboard(app)
        app.buttons["Record set · start rest"].tap()
        XCTAssertTrue(app.staticTexts["Knee-to-wall ankle rocks"].waitForExistence(timeout: 5))
        app.buttons["Return to Today"].tap()

        XCTAssertTrue(app.staticTexts["Your workout is underway."].waitForExistence(timeout: 5))
        app.buttons["See Today"].tap()
        XCTAssertTrue(app.staticTexts["WORKOUT IN PROGRESS"].waitForExistence(timeout: 5))
    }

    func testOnboardingCanConfigureLaterWithoutStartingAWorkout() {
        let app = launch(["--onboarding-demo"])

        app.buttons["Configure later"].tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Workout in progress"].exists)
    }

    func testTodaySessionCanBeReviewedBeforeStarting() {
        let app = launchFreshSettledApp()

        let review = app.buttons["Review the session first"]
        XCTAssertTrue(review.waitForExistence(timeout: 3))
        review.tap()
        XCTAssertTrue(text(app, containing: "Authored rules").waitForExistence(timeout: 5))
    }

    func testExercisesTabExplainsItselfBeforeAnyEvidenceExists() {
        let app = launch()

        app.tabBars.buttons["Exercises"].tap()
        XCTAssertTrue(app.staticTexts["No recorded working sets"].waitForExistence(timeout: 3))
        let setTarget = app.buttons["Set a target from the catalogue"]
        XCTAssertTrue(setTarget.exists)
        setTarget.tap()
        XCTAssertTrue(app.navigationBars["Movement library"].waitForExistence(timeout: 3))
    }

    /// With four weeks of recorded evidence, an exercise shows its measured
    /// current value, the authored target, and a trend that is actually drawn.
    func testExerciseDetailShowsCurrentTargetAndTrend() {
        let app = launch(["--evidence-demo", "--exercises-demo"])

        let bench = text(app, containing: "Bench press")
        XCTAssertTrue(bench.waitForExistence(timeout: 5))
        bench.tap()

        XCTAssertTrue(text(app, containing: "Current · measured").waitForExistence(timeout: 5))
        // 72.5 kg is the heaviest recorded top set in the seeded evidence.
        XCTAssertTrue(text(app, containing: "72.5 kg").exists)
        XCTAssertTrue(text(app, containing: "Ideal · authored").exists)
        XCTAssertTrue(text(app, containing: "90 kg").exists)

        // Every measured value must name the session that produced it.
        XCTAssertTrue(text(app, containing: "Upper ·").exists)

        // The trend is only drawn from two comparable sessions upward.
        let chart = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", "trend across")
        ).firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "The trend chart should render from four sessions")
    }

    func testProgressionSuggestionCitesItsEvidence() {
        let app = launch(["--evidence-demo", "--history-demo"])

        XCTAssertTrue(text(app, containing: "Next-session suggestions").waitForExistence(timeout: 5))
        // The most recent bench session was 8, 7, 7 at 72.5 kg — mid-range, so the
        // load holds and repetitions go up.
        XCTAssertTrue(text(app, containing: "8, 7, 7 at 72.5 kg").exists)
        XCTAssertTrue(text(app, containing: "ADD REPS").exists)
        // The pulldown hit 10, 10, 10 at the top of its range, so load advances.
        XCTAssertTrue(text(app, containing: "ADD LOAD").exists)
    }

    func testPlanOffersNativeTemplateAuthoring() {
        let app = launch()

        app.tabBars.buttons["Plan"].tap()
        let newTemplate = app.buttons["New template"]
        XCTAssertTrue(newTemplate.waitForExistence(timeout: 3))
        newTemplate.tap()
        XCTAssertTrue(app.navigationBars["New template"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Name"].exists)
        let addExercise = app.buttons["Add exercise"]
        if !addExercise.exists { app.swipeUp() }
        XCTAssertTrue(addExercise.waitForExistence(timeout: 3))
    }

    func testStorageScreenStatesWhereTrainingLivesWithoutOfferingAnAccount() {
        let app = launch()

        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.staticTexts["On this iPhone"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["STORAGE"].exists)
        XCTAssertTrue(app.buttons["Export complete Setline data"].exists)
        // There is no account, so nothing may invite the user to sign in.
        XCTAssertFalse(app.buttons["Connect Google account"].exists)
        XCTAssertFalse(app.buttons["apple-account-button"].exists)
    }
}
