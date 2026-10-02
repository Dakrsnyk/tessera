import XCTest

/// The Widget Studio as a person uses it: a theme, a palette undone and redone, the main color, a border,
/// a saved look, then the widget saved and reopened with everything kept.
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
        let height = app.frame.height > 200 ? app.frame.height : 874
        // Reachable: on screen and not under the save bar at the bottom (the toolbar arrows are at the top).
        func reachable() -> Bool {
            button.isHittable && (button.frame.maxY < height - 125 || button.frame.maxY < 140)
        }
        var swipes = 0
        while !reachable() && swipes < 12 {
            // A short drag without momentum over the settings, under the fixed preview: up to reach
            // what is below, down to come back to what scrolled away above.
            let isAbove = button.frame.midY < height * 0.5
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: isAbove ? 0.55 : 0.72))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: isAbove ? 0.72 : 0.55))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            swipes += 1
        }
        button.tap()
    }

    private static let sections = ["content", "theme", "style", "colors", "background", "border", "chart", "density", "myStyles"]

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
            // A chip at the edge of the bar can miss its first tap while the bar is still moving.
            if !waitForSelection(identifier) { app.buttons[identifier].firstMatch.tap() }
            XCTAssertTrue(waitForSelection(identifier),"La section \(Self.sections[index]) ne s'ouvre pas", file: file, line: line)
        }
    }

    func testTheStudioChangesTheWidgetAndKeepsItAll() {
        launch(["-screenshotScreen", "studio-content"])
        let name = app.textFields["widget-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15), "Le Studio ne s'est pas ouvert")
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + "Studio test\n")

        section("theme")
        tapButton("preset-midnight")
        snapshot("theme")

        // A palette changes every color; the arrows take it back and bring it again.
        section("colors")
        tapButton("palette-ocean")
        XCTAssertTrue(waitForSelection("palette-ocean"), "La palette choisie n'est pas sélectionnée")
        snapshot("palette")
        tapButton("studio-undo")
        XCTAssertTrue(waitForSelection("palette-ocean", selected: false), "Retour en arrière n'a pas annulé la palette")
        tapButton("studio-redo")
        XCTAssertTrue(waitForSelection("palette-ocean"), "Retour en avant n'a pas rétabli la palette")
        // The main color repaints the whole widget, palette included.
        tapButton("main-FF6B57")
        XCTAssertTrue(waitForSelection("main-FF6B57"), "La couleur principale n'est pas sélectionnée")
        XCTAssertTrue(waitForSelection("palette-ocean", selected: false), "La couleur principale remplace la palette")
        snapshot("main-color")
        tapButton("studio-undo")
        XCTAssertTrue(waitForSelection("palette-ocean"), "Retour en arrière rend la palette")

        section("border")
        tapButton("border-dashed")
        XCTAssertTrue(waitForSelection("border-dashed"), "La bordure choisie n'est pas sélectionnée")

        section("myStyles")
        let styleName = app.textFields["style-name"]
        XCTAssertTrue(styleName.waitForExistence(timeout: 5))
        styleName.tap()
        styleName.typeText("Nuit test\n")
        tapButton("style-save")
        XCTAssertTrue(app.buttons["style-apply-Nuit test"].waitForExistence(timeout: 5), "Le style enregistré apparaît dans Mes styles")
        snapshot("my-styles")

        // The save bar stays at the bottom, always in reach.
        app.buttons["Enregistrer le widget"].firstMatch.tap()
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
        section("colors")
        XCTAssertTrue(app.buttons["palette-ocean"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForSelection("palette-ocean"), "La palette est gardée")
        section("border")
        XCTAssertTrue(app.buttons["border-dashed"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForSelection("border-dashed"), "La bordure est gardée")
        section("myStyles")
        XCTAssertTrue(app.buttons["style-apply-Nuit test"].waitForExistence(timeout: 5), "Mes styles sont gardés")
        snapshot("reopened")
    }

    func testEverySectionOpens() {
        launch(["-screenshotScreen", "studio-content"])
        XCTAssertTrue(app.textFields["widget-name"].waitForExistence(timeout: 15))
        for name in ["theme", "style", "colors", "background", "border", "chart", "density", "myStyles", "content"] {
            section(name)
            XCTAssertTrue(app.buttons["studio-\(name)"].isSelected, "La section \(name) ne s'ouvre pas")
            XCTAssertEqual(app.state, .runningForeground, "Section \(name)")
        }
        // Only what the person asked to keep: no shape, text, icons, layout or depth sections.
        for gone in ["themes", "depth", "shape", "text", "icons", "layout"] {
            XCTAssertFalse(app.buttons["studio-\(gone)"].exists, "La section \(gone) ne devrait plus exister")
        }
    }

    /// Widgets made together (a creation, a pack) are edited one after the other and share their look.
    func testWidgetsMadeTogetherShareTheirLook() {
        launch(["-screenshotScreen", "studio-multi"])
        let first = app.buttons["studio-widget-1"]
        let second = app.buttons["studio-widget-2"]
        XCTAssertTrue(second.waitForExistence(timeout: 15), "Le Studio n'a pas ouvert les widgets créés ensemble")
        XCTAssertTrue(app.buttons["studio-share-look"].isSelected, "Des widgets créés ensemble partagent leur style")
        tapButton("palette-neon")
        XCTAssertTrue(waitForSelection("palette-neon"), "La palette choisie n'est pas sélectionnée")
        second.tap()
        XCTAssertTrue(waitForSelection("studio-widget-2"), "Le deuxième widget ne s'ouvre pas")
        XCTAssertTrue(waitForSelection("palette-neon"), "La palette est passée au deuxième widget")
        snapshot("multi")
        // Undone for all of them at once.
        tapButton("studio-undo")
        XCTAssertTrue(waitForSelection("palette-neon", selected: false), "Retour en arrière n'a pas annulé la palette")
        first.tap()
        XCTAssertTrue(waitForSelection("studio-widget-1"))
        XCTAssertTrue(waitForSelection("palette-neon", selected: false), "Retour en arrière vaut pour tous les widgets")
        XCTAssertTrue(app.buttons["Enregistrer les 3 widgets"].exists, "Les widgets s'enregistrent ensemble")
    }

    /// A widget without a chart has no « Graphique » section.
    func testTheChartSectionOnlyShowsWithAChart() {
        launch(["-screenshotScreen", "studio-note"])
        XCTAssertTrue(app.buttons["studio-colors"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["studio-chart"].exists, "Une note n'a pas de graphique")
    }

    /// Waits for a choice to show as selected, or not (the state is updated with an animation).
    private func waitForSelection(_ identifier: String, selected: Bool = true, timeout: TimeInterval = 4) -> Bool {
        let predicate = NSPredicate(format: "isSelected == %@", NSNumber(value: selected))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.buttons[identifier].firstMatch)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
