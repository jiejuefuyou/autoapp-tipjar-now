import XCTest

/// fastlane snapshot driver. -FASTLANE_SNAPSHOT makes the app skip onboarding
/// (TipJarNowApp.init) and seed two QR-renderable tip methods
/// (TipJarStore.init), so every shot shows the app genuinely in use
/// (Apple 2.3.3 / lesson #44 — this app was rejected for non-real shots).
///
/// Navigation is positional (toolbar indices) or via stable
/// accessibilityIdentifier, guarded so it works in all 8 capture languages;
/// sheets close with a language-independent swipe.
final class TipJarNowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testScreenshots() {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-FASTLANE_SNAPSHOT", "YES", "-ui_testing"]
        app.launch()
        sleep(2)

        // 1) Hero: the populated QR tip card (seeded PayPal method) + the
        //    method-switcher pills (two methods seeded).
        snapshot("01-TipCard")

        // 2) Share Card composer (themed card + theme chooser).
        let shareCard = app.buttons["home.shareCard"]
        if shareCard.waitForExistence(timeout: 5) {
            shareCard.tap()
            sleep(2)
            snapshot("02-ShareCard")
            app.swipeDown(velocity: .fast)
            sleep(1)
        }

        // Toolbar layout: leading [0] Settings (gear), [1] Pro (sandbox user is
        // never premium); trailing = the method menu.
        let navBar = app.navigationBars.firstMatch
        _ = navBar.waitForExistence(timeout: 5)

        // 3) Settings sheet.
        if navBar.buttons.count >= 1 {
            navBar.buttons.element(boundBy: 0).tap()
            sleep(2)
            snapshot("03-Settings")
            app.swipeDown(velocity: .fast)
            sleep(1)
        }

        // 4) Paywall via the leading Pro button.
        if navBar.buttons.count >= 2 {
            navBar.buttons.element(boundBy: 1).tap()
            sleep(2)
            snapshot("04-Paywall")
        }
    }
}
