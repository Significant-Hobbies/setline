import XCTest

/// Signs a simulator into iCloud so CloudKit can actually run.
///
/// Skipped unless `SETLINE_ICLOUD_APPLE_ID` and `SETLINE_ICLOUD_PASSWORD` are
/// set. CI must never set those: this is a local, two-simulator check, not a
/// gate. Two-factor prompts still need a human if Apple sends a code.
@MainActor
final class SimulatorICloudSignInTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSignIntoICloud() throws {
        let (appleID, password) = try credentials()
        try XCTSkipUnless(
            !appleID.isEmpty && !password.isEmpty,
            "Write Apple ID and password to /tmp/setline-icloud-creds on the simulator first"
        )

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 10))

        if alreadySignedIn(settings) {
            NSLog("Simulator already signed into iCloud")
            return
        }

        tapAppleAccount(settings)
        if alreadySignedIn(settings) { return }

        chooseManualSignInIfOffered(settings)
        fill(appleID, intoFirstFieldOf: settings)
        tapContinue(settings)
        fill(password, intoSecureFieldOf: settings)
        tapContinue(settings)

        dismissPostSignInSheets(settings)

        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline {
            if alreadySignedIn(settings) {
                NSLog("Simulator signed into iCloud")
                return
            }
            if verificationPromptVisible(settings) {
                XCTFail(
                    "Apple asked for two-factor verification. Approve this Mac or enter the code on the simulator, then re-run."
                )
                return
            }
            dismissPostSignInSheets(settings)
            Thread.sleep(forTimeInterval: 2)
        }

        XCTFail("Sign-in did not complete.\n\(settings.debugDescription)")
    }

    /// Two lines on the simulator: Apple ID, then password. Written by the
    /// host script via `simctl spawn` so the secret never appears in xcodebuild.
    private func credentials() throws -> (String, String) {
        let path = "/tmp/setline-icloud-creds"
        guard let body = try? String(contentsOfFile: path, encoding: .utf8) else {
            return ("", "")
        }
        let lines = body.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return ("", "") }
        return (lines[0].trimmingCharacters(in: .whitespaces), lines[1])
    }

    private func alreadySignedIn(_ settings: XCUIApplication) -> Bool {
        if settings.buttons["Sign Out"].exists { return true }
        if settings.staticTexts["Sign Out"].exists { return true }
        let subtitle = settings.staticTexts[
            "Sign in to access your iCloud data, the App Store, Apple services and more."
        ]
        if settings.staticTexts["Apple Account"].exists, !subtitle.exists {
            return true
        }
        return false
    }

    private func tapAppleAccount(_ settings: XCUIApplication) {
        let labels = ["Apple Account", "Sign in to your iPhone", "iCloud"]
        for label in labels {
            let button = settings.buttons[label]
            if button.waitForExistence(timeout: 2) {
                button.tap()
                return
            }
            let cell = settings.cells[label]
            if cell.waitForExistence(timeout: 1) {
                cell.tap()
                return
            }
            let text = settings.staticTexts[label]
            if text.waitForExistence(timeout: 1) {
                text.tap()
                return
            }
        }
    }

    private func chooseManualSignInIfOffered(_ settings: XCUIApplication) {
        for label in ["Sign in Manually", "Sign in with Apple ID", "Use a different Apple Account"] {
            if tapLabeled(label, in: settings, timeout: 3) { return }
        }
        let manual = settings.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Sign in Manually")
        ).firstMatch
        if manual.waitForExistence(timeout: 2) {
            manual.tap()
        }
    }

    @discardableResult
    private func tapLabeled(_ label: String, in settings: XCUIApplication, timeout: TimeInterval) -> Bool {
        for query in [settings.buttons[label], settings.cells[label], settings.staticTexts[label]] {
            if query.waitForExistence(timeout: timeout) {
                query.tap()
                return true
            }
        }
        return false
    }

    private func fill(_ value: String, intoFirstFieldOf settings: XCUIApplication) {
        let field = settings.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No email field on the Apple Account sheet")
        field.tap()
        field.typeText(value)
    }

    private func fill(_ value: String, intoSecureFieldOf settings: XCUIApplication) {
        let field = settings.secureTextFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No password field on the Apple Account sheet")
        field.tap()
        field.typeText(value)
    }

    private func tapContinue(_ settings: XCUIApplication) {
        for label in ["Continue", "Next", "Sign In", "Done"] {
            let button = settings.buttons[label]
            if button.waitForExistence(timeout: 3), button.isEnabled {
                button.tap()
                return
            }
        }
    }

    private func verificationPromptVisible(_ settings: XCUIApplication) -> Bool {
        let markers = [
            "Verification Code",
            "Enter Code",
            "Two-Factor Authentication",
            "Enter the verification code",
            "A message with a verification code",
        ]
        return markers.contains { settings.staticTexts[$0].exists || settings.textFields[$0].exists }
    }

    private func dismissPostSignInSheets(_ settings: XCUIApplication) {
        for label in ["Don't Merge", "Don’t Merge", "Not Now", "Don't Allow", "Don’t Allow", "OK"] {
            let button = settings.buttons[label]
            if button.exists {
                button.tap()
            }
        }
    }
}
