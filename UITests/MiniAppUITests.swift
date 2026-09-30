import XCTest

/// The mini-apps reached from Home: a card of « Mon Quotidien » opens a whole mini-app, where the
/// person reads, adds, changes and removes their data without going back to Home.
final class MiniAppUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        app?.terminate()
    }

    // MARK: Helpers

    private func launch(_ arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
    }

    private func snapshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "mini-app-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func isReachable(_ element: XCUIElement) -> Bool {
        element.exists && element.isHittable
    }

    private func scrollDownOnce() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    @discardableResult
    private func reveal(_ element: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        _ = element.waitForExistence(timeout: 8)
        var drags = 0
        while !isReachable(element) && drags < 16 {
            scrollDownOnce()
            drags += 1
            _ = element.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(isReachable(element), "\(what) introuvable", file: file, line: line)
        return element
    }

    private func tap(_ element: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        reveal(element, what, file: file, line: line).tap()
    }

    private var saveButton: XCUIElement {
        let buttons = app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Enregistrer"))
        return buttons.allElementsBoundByIndex.first { $0.isHittable } ?? buttons.firstMatch
    }

    private func goBack(file: StaticString = #filePath, line: UInt = #line) {
        let back = app.navigationBars.buttons.allElementsBoundByIndex.first {
            $0.isHittable && $0.frame.minX < 60 && $0.label != "Annuler"
        }
        XCTAssertNotNil(back, "Bouton retour introuvable", file: file, line: line)
        back?.tap()
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    private var entryRows: XCUIElementQuery { app.buttons.matching(identifier: "entry-row") }

    // MARK: Nutrition

    func testNutritionOpensFromHomeAndManagesAMeal() {
        launch(["-screenshotScreen", "home"])
        tap(app.buttons["daily-nutrition-open"], "Carte Nutrition de « Mon Quotidien »")
        XCTAssertTrue(app.otherElements["nutrition-hero"].waitForExistence(timeout: 8), "La mini-app Nutrition ne s'est pas ouverte")
        snapshot("nutrition")

        // A meal: its foods, then add one, change it and remove it, all without leaving the mini-app.
        tap(app.buttons["meal-breakfast"], "Repas du déjeuner")
        XCTAssertTrue(app.navigationBars["Déjeuner"].waitForExistence(timeout: 8), "Page du repas absente")
        _ = app.buttons["meal-add"].waitForExistence(timeout: 5)
        let before = entryRows.count
        tap(app.buttons["meal-add"], "Ajouter un aliment")
        let food = app.buttons.matching(identifier: "food-row").firstMatch
        tap(food, "Premier aliment proposé")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 8), "Feuille de quantité absente")
        snapshot("nutrition-quantity")
        saveButton.tap()
        XCTAssertTrue(waitForDisappearance(food), "La recherche d'aliments est restée ouverte")
        XCTAssertTrue(app.buttons["meal-add"].waitForExistence(timeout: 8))
        XCTAssertEqual(entryRows.count, before + 1, "L'aliment ajouté doit apparaître dans le repas")
        snapshot("nutrition-meal")

        tap(entryRows.firstMatch, "Aliment du repas")
        tap(app.buttons["entry-delete"], "Retirer de ce repas")
        XCTAssertTrue(app.buttons["meal-add"].waitForExistence(timeout: 8))
        XCTAssertEqual(entryRows.count, before, "L'aliment retiré doit disparaître du repas")

        goBack()
        XCTAssertTrue(app.otherElements["nutrition-hero"].waitForExistence(timeout: 8), "Retour au tableau de bord Nutrition")
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testNutritionPagesOpenAndComeBack() {
        launch(["-screenshotScreen", "app-nutrition"])
        XCTAssertTrue(app.otherElements["nutrition-hero"].waitForExistence(timeout: 12), "Mini-app Nutrition absente")
        for (identifier, title) in [("nutrition-nutrients", "Nutriments"), ("nutrition-saved", "Mes repas"), ("nutrition-history", "Historique")] {
            tap(app.buttons[identifier], title)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8), "Page \(title) absente")
            snapshot(identifier)
            goBack()
            XCTAssertTrue(app.otherElements["nutrition-hero"].waitForExistence(timeout: 8), "Retour depuis \(title)")
        }
        XCTAssertEqual(app.state, .runningForeground)
    }
}
