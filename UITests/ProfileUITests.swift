import XCTest

/// The first launch, « Mes informations », the scanner opened from a Nutrition widget, and the settings
/// of each widget in « Créer », as a person would use them.
final class ProfileUITests: XCTestCase {
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
        shot.name = "profile-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func type(_ text: String, into identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 8), "Champ \(identifier) introuvable", file: file, line: line)
        var swipes = 0
        while !field.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        field.tap()
        field.typeText(text)
    }

    private func tapButton(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Bouton « \(label) » introuvable", file: file, line: line)
        var swipes = 0
        while !button.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        button.tap()
    }

    private func label(of identifier: String) -> String {
        let element = app.buttons[identifier].firstMatch
        _ = element.waitForExistence(timeout: 8)
        return element.label
    }

    // MARK: First launch

    func testFirstLaunchAsksOnlyWhatMattersAndFillsMesInformations() {
        launch(["-screenshotScreen", "onboarding"])
        // Step 0: the style, as before.
        tapButton("Continuer")
        // Step 1: the name.
        type("Mathys", into: "identity-first-name")
        snapshot("identity")
        tapButton("onboarding-continue")
        // Step 2: interests.
        tapButton("interest-sport")
        tapButton("interest-nutrition")
        snapshot("interests")
        tapButton("onboarding-continue")
        // Step 3: only the pages of the chosen interests.
        XCTAssertTrue(app.staticTexts["Sport"].waitForExistence(timeout: 8))
        tapButton("Prise de masse")
        type("80", into: "profile-weight")
        snapshot("sport")
        tapButton("onboarding-continue")
        XCTAssertTrue(app.staticTexts["Nutrition"].waitForExistence(timeout: 8))
        type("2500", into: "target-kcal")
        // Everything else can be skipped: the last page ends the first launch.
        tapButton("onboarding-skip")

        let sport = app.buttons["info-sport"]
        XCTAssertTrue(sport.waitForExistence(timeout: 10), "« Mes informations » absent de l'accueil")
        XCTAssertTrue(sport.label.contains("80 kg"), "Poids absent : \(sport.label)")
        XCTAssertTrue(sport.label.contains("Prise de masse"))
        XCTAssertTrue(sport.label.contains("À compléter"), "La taille et l'âge manquent")
        XCTAssertTrue(label(of: "info-nutrition").contains("Calories"))
        XCTAssertTrue(app.staticTexts["Bonjour Mathys"].exists || app.staticTexts["Bon après-midi Mathys"].exists || app.staticTexts["Bonsoir Mathys"].exists)
        snapshot("home-after-onboarding")

        // Changed once, changed everywhere.
        sport.tap()
        let weight = app.textFields["profile-weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 8))
        weight.tap()
        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "78")
        tapButton("OK")
        XCTAssertTrue(label(of: "info-sport").contains("78 kg"))
    }

    func testSkippingEverythingShowsNothingMadeUp() {
        launch(["-screenshotScreen", "onboarding"])
        tapButton("Continuer")
        tapButton("onboarding-skip")
        // No interest chosen: the interests step ends the first launch.
        tapButton("onboarding-skip")
        XCTAssertTrue(app.buttons["Choisir mes centres d'intérêt"].waitForExistence(timeout: 10), "L'accueil doit inviter à compléter, sans valeurs inventées")
        snapshot("home-skipped")
    }

    // MARK: Home

    func testMesInformationsShowTheUsersValues() {
        launch(["-screenshotScreen", "home"])
        let sport = app.buttons["info-sport"]
        XCTAssertTrue(sport.waitForExistence(timeout: 12))
        XCTAssertTrue(sport.label.contains("78 kg"), sport.label)
        XCTAssertTrue(label(of: "info-nutrition").contains("kcal"))
        snapshot("home-info")
    }

    // MARK: Scanner

    func testTheNutritionWidgetOpensTheScannerOrTheSearch() {
        launch(["-screenshotScreen", "scan-food"])
        // The simulator has no camera: the search is the fallback, ready to log a food.
        let food = app.buttons.matching(identifier: "food-row").firstMatch
        XCTAssertTrue(food.waitForExistence(timeout: 12), "L'écran d'ajout d'aliment ne s'est pas ouvert")
        snapshot("scan-fallback")
        food.tap()
        let save = app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Enregistrer")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 8))
        save.tap()
        XCTAssertTrue(waitForDisappearance(food), "L'ajout doit se fermer d'un geste")
        XCTAssertEqual(app.state, .runningForeground)
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter.wait(for: [gone], timeout: timeout) == .completed
    }

    // MARK: Créer

    func testEachWidgetOfACombinedWidgetCanBeSet() {
        launch(["-screenshotScreen", "creator-nutrition", "-screenshotCreatorFormat", "medium"])
        let part = app.buttons["part-caloriesLeft"]
        XCTAssertTrue(part.waitForExistence(timeout: 15), "Réglages par widget absents du format Moyen")
        var swipes = 0
        while !part.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        part.tap()
        let name = app.textFields["Nom du widget"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 8))
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + "Mes calories")
        snapshot("part-settings")
        let back = app.navigationBars.buttons.allElementsBoundByIndex.first { $0.isHittable && $0.frame.minX < 60 && $0.label != "Annuler" }
        XCTAssertNotNil(back)
        back?.tap()
        XCTAssertTrue(label(of: "part-caloriesLeft").contains("Mes calories"))
        XCTAssertTrue(app.segmentedControls.buttons["Moyen"].isSelected, "Le format choisi est gardé")
    }
}
