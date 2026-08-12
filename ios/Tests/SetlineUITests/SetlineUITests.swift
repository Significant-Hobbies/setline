import XCTest

@MainActor
final class SetlineUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testStartsWorkoutAndShowsTimestampRest() {
        let app = XCUIApplication()
        app.launchArguments = ["--fresh-demo"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Follow the plan.\nRecord the truth."].waitForExistence(timeout: 3))
        app.buttons["Start workout"].tap()
        XCTAssertTrue(app.staticTexts["Front squat"].waitForExistence(timeout: 3))

        let weight = app.textFields["Weight"]
        weight.tap()
        weight.typeText("40")
        let reps = app.textFields["Reps"]
        reps.tap()
        reps.typeText("8")
        app.buttons["Record set · start rest"].tap()

        XCTAssertTrue(app.staticTexts["REST · WALL CLOCK"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Start next early"].exists)
    }

    func testCoreTabsAreReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--fresh-demo"]
        app.launch()

        for tab in ["Plan", "History", "You"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.staticTexts[tab].waitForExistence(timeout: 2))
        }
    }

    func testPlanOffersNativeTemplateAuthoring() {
        let app = XCUIApplication()
        app.launchArguments = ["--fresh-demo"]
        app.launch()

        app.tabBars.buttons["Plan"].tap()
        let newTemplate = app.buttons["New template"]
        XCTAssertTrue(newTemplate.waitForExistence(timeout: 3))
        newTemplate.tap()
        XCTAssertTrue(app.navigationBars["New template"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["Name"].exists)
        XCTAssertTrue(app.buttons["Add exercise"].exists)
    }

    func testAccountScreenOffersAppleAlongsideGoogle() {
        let app = XCUIApplication()
        app.launchArguments = ["--fresh-demo"]
        app.launch()

        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.buttons["Connect Google account"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["apple-account-button"].exists)
    }
}
