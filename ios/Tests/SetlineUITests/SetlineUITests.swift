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

    /// The decimal keypad has no return key and can cover the record button, so
    /// focus is dropped by tapping a non-interactive label before acting.
    private func dismissKeyboard(_ app: XCUIApplication) {
        if app.keyboards.count > 0 {
            app.staticTexts["TARGET"].tap()
        }
    }

    private func tapRecord(_ app: XCUIApplication) {
        dismissKeyboard(app)
        let record = app.buttons["Record set · start rest"]
        XCTAssertTrue(record.waitForExistence(timeout: 2))
        if !record.isHittable { app.swipeUp() }
        record.tap()
    }

    private func text(_ app: XCUIApplication, containing fragment: String) -> XCUIElement {
        app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", fragment)
        ).firstMatch
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
        tapRecord(app)

        XCTAssertTrue(app.staticTexts["REST · WALL CLOCK"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(shorthand.waitForExistence(timeout: 2))
        shorthand.tap()
        shorthand.typeText("5x40, 2x30")

        // The interpretation is shown before anything is recorded.
        let reading = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Reads as:")
        ).firstMatch
        XCTAssertTrue(reading.waitForExistence(timeout: 2))

        app.buttons["Apply to segments"].tap()
        XCTAssertTrue(app.staticTexts["SEGMENT 2"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["All 2 segments record as one set."].exists)

        tapRecord(app)
        XCTAssertTrue(app.staticTexts["REST · WALL CLOCK"].waitForExistence(timeout: 5))

        app.buttons["Finish"].tap()
        app.buttons["Finish and save"].tap()

        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()

        let session = text(app, containing: "Lower strength")
        XCTAssertTrue(session.waitForExistence(timeout: 5))
        session.tap()

        let recorded = text(app, containing: "5 × 40 kg + 2 × 30 kg")
        XCTAssertTrue(
            recorded.waitForExistence(timeout: 5),
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
        let app = launch(["--fresh-demo"])

        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(
            app.staticTexts["12-Week Strength, Cardio & Mobility Plan"].waitForExistence(timeout: 3)
        )
        // Checkpoints are part of the authored block, not an afterthought.
        XCTAssertTrue(app.staticTexts["Baseline"].exists)
        XCTAssertTrue(app.staticTexts["End of block"].exists)
    }

    func testTodaySessionCanBeReviewedBeforeStarting() {
        let app = launch(["--fresh-demo"])

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

    func testAccountScreenOffersAppleAlongsideGoogle() {
        let app = launch()

        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.buttons["Connect Google account"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["apple-account-button"].exists)
    }
}
