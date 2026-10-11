import XCTest

/// Walks through every screen at 2pm (via `-demoTime`) and attaches a screenshot of each, in light
/// mode, dark mode and an accessibility text size. CI exports them from the result bundle so the
/// screens can be checked against the mockup.
///
/// The steps tolerate missing elements, so a layout change gives fewer screenshots rather than a
/// failing build. Tests run in name order: the first one completes onboarding for the others.
@MainActor
final class ScreenshotTests: XCTestCase {
    func test1LightJourney() {
        continueAfterFailure = true
        XCUIDevice.shared.appearance = .light
        let app = launch()

        let save = app.buttons["Save profile"]
        if save.waitForExistence(timeout: 10) {
            snap("01 onboarding")
            // The profile shown in the mockup.
            choose("A lot", for: "Loud noise", in: app)
            choose("A lot", for: "Sudden sounds", in: app)
            choose("A bit", for: "Strong smells", in: app)
            snap("02 onboarding filled")
            save.tap()
        }
        allowLocationIfAsked()
        waitForMap(app)
        snap("03 map")

        if tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marlow Street Library")).firstMatch) {
            pause(2)
            snap("04 place top")
            app.swipeUp()
            pause(1)
            snap("05 place chart")
            app.swipeUp()
            pause(1)
            snap("06 place how it feels")
            app.swipeUp()
            pause(1)
            snap("07 place good to know")
            app.swipeDown()
            app.swipeDown()
            app.swipeDown()
            pause(1)
            if tap(app.buttons["Directions"]) {
                pause(5)
                snap("08 directions")
            }
            tap(app.buttons["Close"])
            pause(1)
        }

        if tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "How's the tide where you are")).firstMatch) {
            pause(2)
            snap("09 check-in")
            tap(app.buttons["Calm"].firstMatch)
            tap(app.buttons["Chatter"].firstMatch)
            snap("10 check-in chosen")
            tap(app.buttons["Cancel"])
            pause(1)
        }

        if tap(app.buttons["Find low water"]) {
            pause(6)
            snap("11 find low water")
            if tap(app.buttons["Show a card"]) {
                pause(1)
                snap("12 staff card")
                tap(app.buttons["Close card"])
                pause(1)
            }
            tap(app.buttons["Close"])
            pause(1)
        }

        if tap(app.buttons["Tide profile"]) {
            pause(1)
            snap("13 profile")
            tap(app.buttons["Back to map without saving"])
        }
    }

    func test2DarkMode() {
        continueAfterFailure = true
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        let app = launch()
        completeOnboardingIfNeeded(app)
        allowLocationIfAsked()
        waitForMap(app)
        snap("21 dark map")
        if tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marlow Street Library")).firstMatch) {
            pause(2)
            snap("22 dark place top")
            app.swipeUp()
            pause(1)
            snap("23 dark place chart")
            tap(app.buttons["Close"])
        }
        if tap(app.buttons["Tide profile"]) {
            pause(1)
            snap("24 dark profile")
            tap(app.buttons["Back to map without saving"])
        }
    }

    func test3LargeText() {
        continueAfterFailure = true
        XCUIDevice.shared.appearance = .light
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])
        completeOnboardingIfNeeded(app)
        allowLocationIfAsked()
        waitForMap(app)
        snap("31 large map")
        app.swipeUp()
        pause(1)
        snap("32 large sheet raised")
        if tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marlow Street Library")).firstMatch) {
            pause(2)
            snap("33 large place top")
            app.swipeUp()
            pause(1)
            snap("34 large place actions")
            app.swipeUp()
            pause(1)
            snap("35 large place how it feels")
            tap(app.buttons["Close"])
            pause(1)
        }
        if tap(app.buttons["Tide profile"]) {
            pause(1)
            snap("36 large profile")
            app.swipeUp()
            pause(1)
            snap("37 large profile alerts")
            tap(app.buttons["Back to map without saving"])
        }
        if tap(app.buttons["Find low water"]) {
            pause(6)
            snap("38 large find low water")
            tap(app.buttons["Close"])
        }
    }

    // MARK: Helpers

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoTime", "14:00"] + extra
        app.launch()
        return app
    }

    private func completeOnboardingIfNeeded(_ app: XCUIApplication) {
        let save = app.buttons["Save profile"]
        if save.waitForExistence(timeout: 5) {
            save.tap()
        }
    }

    private func choose(_ option: String, for factor: String, in app: XCUIApplication) {
        let control = app.segmentedControls.matching(NSPredicate(format: "label == %@ OR identifier == %@", factor, factor)).firstMatch
        if control.waitForExistence(timeout: 2) {
            tap(control.buttons[option])
        }
    }

    /// Accepts the location prompt so the map shows the simulator's location.
    private func allowLocationIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons.matching(NSPredicate(format: "label CONTAINS %@", "While Using")).firstMatch
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
        }
    }

    private func waitForMap(_ app: XCUIApplication) {
        _ = app.buttons["Find low water"].waitForExistence(timeout: 15)
        // Give map tiles and the location fix time to arrive.
        pause(6)
    }

    @discardableResult
    private func tap(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 5), element.isHittable else { return false }
        element.tap()
        return true
    }

    private func pause(_ seconds: UInt32) {
        sleep(seconds)
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
