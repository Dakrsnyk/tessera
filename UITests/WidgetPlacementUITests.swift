import XCTest

/// Places Tessera widgets the way a person would, on a simulated iPhone, and keeps a
/// screenshot of every step. Springboard labels are matched in English and French.
final class WidgetPlacementUITests: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() {
        continueAfterFailure = true
    }

    // MARK: Helpers

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func button(_ labels: [String], in app: XCUIApplication, timeout: TimeInterval = 4) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for label in labels {
                let exact = app.buttons[label]
                if exact.exists { return exact }
                let partial = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
                if partial.exists { return partial }
            }
            Thread.sleep(forTimeInterval: 0.4)
        } while Date() < deadline
        return nil
    }

    private func launchTesseraOnce() {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotScreen", "home"]
        app.launch()
        Thread.sleep(forTimeInterval: 3)
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
    }

    private func searchTessera() {
        let field = springboard.searchFields.firstMatch
        if field.waitForExistence(timeout: 4) {
            field.tap()
            field.typeText("Tessera")
            Thread.sleep(forTimeInterval: 2)
        }
    }

    // MARK: Home Screen

    func testAddWidgetToHomeScreen() throws {
        launchTesseraOnce()
        springboard.swipeLeft()
        Thread.sleep(forTimeInterval: 1)
        snapshot("home-1-empty-page")

        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).press(forDuration: 1.6)
        Thread.sleep(forTimeInterval: 1)
        snapshot("home-2-edit-mode")

        if let edit = button(["Edit", "Modifier"], in: springboard) {
            edit.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        snapshot("home-3-edit-menu")

        let add = button(["Add Widget", "Ajouter un widget"], in: springboard)
        XCTAssertNotNil(add, "The Add Widget button was not found")
        add?.tap()
        Thread.sleep(forTimeInterval: 2)
        snapshot("home-4-gallery")

        searchTessera()
        snapshot("home-5-search")

        let result = springboard.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Tessera")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5), "Tessera is not listed in the widget gallery")
        result.tap()
        Thread.sleep(forTimeInterval: 2)
        snapshot("home-6-tessera-widgets")

        let addThis = button(["Add Widget", "Ajouter le widget", "Ajouter un widget"], in: springboard)
        XCTAssertNotNil(addThis, "The button to add the Tessera widget was not found")
        addThis?.tap()
        Thread.sleep(forTimeInterval: 2)
        snapshot("home-7-added")

        if let done = button(["Done", "OK", "Terminé"], in: springboard) {
            done.tap()
        } else {
            XCUIDevice.shared.press(.home)
        }
        Thread.sleep(forTimeInterval: 3)
        snapshot("home-8-result")
    }

    // MARK: Lock Screen

    func testAddWidgetToLockScreen() throws {
        launchTesseraOnce()
        let lock = NSSelectorFromString("pressLockButton")
        guard XCUIDevice.shared.responds(to: lock) else {
            throw XCTSkip("This simulator cannot lock the screen from a test")
        }
        _ = XCUIDevice.shared.perform(lock)
        Thread.sleep(forTimeInterval: 2)
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        snapshot("lock-1-lock-screen")

        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.8)
        Thread.sleep(forTimeInterval: 2)
        snapshot("lock-2-long-press")

        if let customize = button(["Customize", "Personnaliser"], in: springboard, timeout: 5) {
            customize.tap()
            Thread.sleep(forTimeInterval: 2)
        }
        snapshot("lock-3-customize")

        if let lockScreen = button(["Lock Screen", "Écran verrouillé"], in: springboard, timeout: 3) {
            lockScreen.tap()
            Thread.sleep(forTimeInterval: 2)
        }
        snapshot("lock-4-editor")

        if let addWidgets = button(["Add Widgets", "Ajouter des widgets", "Add Widget"], in: springboard, timeout: 4) {
            addWidgets.tap()
        } else {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)).tap()
        }
        Thread.sleep(forTimeInterval: 2)
        snapshot("lock-5-widget-sheet")

        let tessera = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Tessera")).firstMatch
        let tesseraText = springboard.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Tessera")).firstMatch
        if !tessera.exists && !tesseraText.exists {
            springboard.swipeUp()
            Thread.sleep(forTimeInterval: 1)
        }
        let found = tessera.exists ? tessera : tesseraText
        XCTAssertTrue(found.waitForExistence(timeout: 4), "Tessera is not offered for the Lock Screen")
        found.tap()
        Thread.sleep(forTimeInterval: 2)
        snapshot("lock-6-tessera-widgets")

        let firstWidget = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Progression")).firstMatch
        if firstWidget.exists {
            firstWidget.tap()
        } else {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.7)).tap()
        }
        Thread.sleep(forTimeInterval: 2)
        snapshot("lock-7-added")

        if let done = button(["Done", "OK", "Terminé"], in: springboard, timeout: 3) {
            done.tap()
            Thread.sleep(forTimeInterval: 2)
        }
        if let done = button(["Done", "OK", "Terminé"], in: springboard, timeout: 2) {
            done.tap()
            Thread.sleep(forTimeInterval: 2)
        }
        snapshot("lock-8-result")
    }
}
