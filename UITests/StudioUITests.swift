import XCTest

/// The Widget Studio as a person uses it: a theme, a border, a layout, a saved look, then the widget
/// saved and reopened with everything kept.
final class StudioUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        app?.terminate()
    }

    private func launch(_ arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
    }

    private func snapshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "studio-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Taps a button by identifier, scrolling the Studio's settings (below the preview) until it's reachable.
    private func tapButton(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[identifier].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Bouton « \(identifier) » introuvable", file: file, line: line)
        var swipes = 0
        while !button.isHittable && swipes < 12 {
            // A short drag without momentum over the settings, under the fixed preview.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            swipes += 1
        }
        button.tap()
    }

    private static let sections = ["content", "themes", "style", "colors", "background", "border", "depth", "shape", "text", "icons", "layout", "chart", "density", "myStyles"]

    /// The sections are in a horizontal bar that centers the section chosen: going one section at a
    /// time, the next one is always on screen.
    private func section(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let target = Self.sections.firstIndex(of: name) else { return XCTFail("Section \(name)", file: file, line: line) }
        XCTAssertTrue(app.buttons["studio-\(name)"].waitForExistence(timeout: 8), "Section « \(name) » introuvable", file: file, line: line)
        var index = Self.sections.firstIndex { app.buttons["studio-\($0)"].isSelected } ?? 0
        while index != target {
            index += target > index ? 1 : -1
            let identifier = "studio-\(Self.sections[index])"
            app.buttons[identifier].firstMatch.tap()
            XCTAssertTrue(waitForSelection(identifier), "La section \(Self.sections[index]) ne s'ouvre pas", file: file, line: line)
        }
    }

    func testTheStudioChangesTheWidgetAndKeepsItAll() {
        launch(["-screenshotScreen", "studio-content"])
        let name = app.textFields["widget-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15), "Le Studio ne s'est pas ouvert")
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + "Studio test\n")

        section("themes")
        tapButton("preset-midnight")
        snapshot("theme")

        section("border")
        tapButton("border-dashed")
        XCTAssertTrue(waitForSelection("border-dashed"), "La bordure choisie n'est pas sélectionnée")

        section("layout")
        tapButton("layout-minimal")
        XCTAssertTrue(waitForSelection("layout-minimal"), "La disposition choisie n'est pas sélectionnée")
        snapshot("layout")

        section("myStyles")
        let styleName = app.textFields["style-name"]
        XCTAssertTrue(styleName.waitForExistence(timeout: 5))
        styleName.tap()
        styleName.typeText("Nuit test\n")
        tapButton("style-save")
        XCTAssertTrue(app.buttons["style-apply-Nuit test"].waitForExistence(timeout: 5), "Le style enregistré apparaît dans Mes styles")
        snapshot("my-styles")

        tapButton("Enregistrer le widget")
        XCTAssertTrue(waitForDisappearance(name), "Le Studio se ferme une fois le widget enregistré")
        XCTAssertEqual(app.state, .runningForeground)

        // Reopened from « Mes widgets »: every setting is still there.
        app.terminate()
        launch(["-screenshotScreen", "mywidgets"])
        let edit = app.buttons["carousel-edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15), "Mes widgets absent")
        XCTAssertTrue(app.staticTexts["Studio test"].waitForExistence(timeout: 5), "Le widget enregistré est en tête de Mes widgets")
        edit.tap()
        XCTAssertTrue(app.textFields["widget-name"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["widget-name"].value as? String, "Studio test")
        section("border")
        XCTAssertTrue(app.buttons["border-dashed"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForSelection("border-dashed"), "La bordure est gardée")
        section("layout")
        XCTAssertTrue(app.buttons["layout-minimal"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForSelection("layout-minimal"), "La disposition est gardée")
        section("myStyles")
        XCTAssertTrue(app.buttons["style-apply-Nuit test"].waitForExistence(timeout: 5), "Mes styles sont gardés")
        snapshot("reopened")
    }

    func testEverySectionOpens() {
        launch(["-screenshotScreen", "studio-content"])
        XCTAssertTrue(app.textFields["widget-name"].waitForExistence(timeout: 15))
        for name in ["themes", "style", "colors", "background", "border", "depth", "shape", "text", "icons", "layout", "chart", "density", "myStyles", "content"] {
            section(name)
            XCTAssertTrue(app.buttons["studio-\(name)"].isSelected, "La section \(name) ne s'ouvre pas")
            XCTAssertEqual(app.state, .runningForeground, "Section \(name)")
        }
    }

    /// Waits for a choice to show as selected (the state is updated with an animation).
    private func waitForSelection(_ identifier: String, timeout: TimeInterval = 4) -> Bool {
        let predicate = NSPredicate(format: "isSelected == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.buttons[identifier].firstMatch)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
