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

        if tap(row("Marlow Street Library", in: app)) {
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
            if tap(app.buttons["How's the tide?"]) {
                pause(2)
                snap("09 check-in")
                tap(app.buttons["Calm"].firstMatch)
                tap(app.buttons["Chatter"].firstMatch)
                snap("10 check-in chosen")
                app.swipeUp()
                pause(1)
                snap("10b check-in sound")
                tap(app.buttons["Cancel"])
                pause(2)
            }
            app.swipeDown()
            app.swipeDown()
            app.swipeDown()
            pause(1)
            if tap(app.buttons["Directions"]) {
                pause(5)
                snap("08 directions")
            }
            tap(app.buttons["Close"])
            pause(2)
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
        if tap(row("Marlow Street Library", in: app)) {
            pause(2)
            snap("22 dark place top")
            app.swipeUp()
            pause(1)
            snap("23 dark place chart")
            tap(app.buttons["Close"])
            pause(2)
        }
        if tap(app.buttons["Tide profile"]) {
            pause(1)
            snap("24 dark profile")
            tap(app.buttons["Back to map without saving"])
            pause(2)
        }
        if tap(app.buttons["Find low water"]) {
            pause(6)
            snap("25 dark find low water")
            tap(app.buttons["Close"])
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
        if tap(row("Marlow Street Library", in: app)) {
            pause(2)
            snap("33 large place top")
            app.swipeUp()
            pause(1)
            snap("34 large place actions")
            app.swipeUp()
            pause(1)
            snap("35 large place how it feels")
            app.swipeDown()
            app.swipeDown()
            app.swipeDown()
            pause(1)
            tap(app.buttons["Close"])
            pause(2)
        }
        if tap(app.buttons["Tide profile"]) {
            pause(1)
            snap("36 large profile")
            app.swipeUp()
            pause(1)
            snap("37 large profile alerts")
            tap(app.buttons["Back to map without saving"])
            pause(2)
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

    /// Factors in the order the profile lists them.
    private static let factors = ["Loud noise", "Sudden sounds", "Bright or flickering light", "Crowds", "Strong smells"]

    private func choose(_ option: String, for factor: String, in app: XCUIApplication) {
        guard let index = Self.factors.firstIndex(of: factor) else { return }
        let named = app.segmentedControls.matching(NSPredicate(format: "label == %@", factor)).firstMatch
        if named.waitForExistence(timeout: 2), tap(named.buttons[option]) {
            return
        }
        if app.segmentedControls.count == Self.factors.count, tap(app.segmentedControls.element(boundBy: index).buttons[option]) {
            return
        }
        // Each row has one button per option, in factor order.
        let buttons = app.buttons.matching(identifier: option)
        if buttons.count >= Self.factors.count {
            tap(buttons.element(boundBy: index))
        }
    }

    /// A row in the sheet's list, rather than the pin, which reads "Name, calm until…".
    private func row(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name), Calm")).firstMatch
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
