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

        let info = app.buttons["home-info"]
        XCTAssertTrue(info.waitForExistence(timeout: 10), "« Mes informations » absent de l'accueil")
        XCTAssertTrue(app.staticTexts["Bonjour Mathys"].exists || app.staticTexts["Bon après-midi Mathys"].exists || app.staticTexts["Bonsoir Mathys"].exists)
        snapshot("home-after-onboarding")
        tapButton("home-info")
        let fitness = app.buttons["area-fitness"]
        XCTAssertTrue(fitness.waitForExistence(timeout: 8), "Le thème Fitness manque dans Mes informations")
        XCTAssertTrue(fitness.label.contains("80 kg"), "Poids absent : \(fitness.label)")
        XCTAssertTrue(label(of: "area-nutrition").contains("kcal"), "Objectif calorique absent")
        snapshot("info-after-onboarding")

        // Changed once, changed everywhere.
        fitness.tap()
        let weight = app.textFields["data-weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 8))
        weight.tap()
        weight.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "78")
        let back = app.navigationBars.buttons.allElementsBoundByIndex.first { $0.isHittable && $0.frame.minX < 60 }
        XCTAssertNotNil(back)
        back?.tap()
        XCTAssertTrue(label(of: "area-fitness").contains("78 kg"))
    }

    func testSkippingEverythingShowsNothingMadeUp() {
        launch(["-screenshotScreen", "onboarding"])
        tapButton("Continuer")
        tapButton("onboarding-skip")
        // No interest chosen: the interests step ends the first launch.
        tapButton("onboarding-skip")
        XCTAssertTrue(app.buttons["Choisir mes centres d'intérêt"].waitForExistence(timeout: 10), "L'accueil doit inviter à compléter")
        // No target and no budget given: « Mon Quotidien » never makes one up.
        XCTAssertFalse(app.staticTexts["kcal restantes"].exists, "Calories restantes sans objectif donné")
        XCTAssertFalse(app.staticTexts["à dépenser par jour d'ici la fin du mois"].exists, "Budget du jour sans budget donné")
        snapshot("home-skipped")
    }

    // MARK: Home

    func testMesInformationsShowTheUsersValues() {
        launch(["-screenshotScreen", "home"])
        let info = app.buttons["home-info"]
        XCTAssertTrue(info.waitForExistence(timeout: 12))
        info.tap()
        let fitness = app.buttons["area-fitness"]
        XCTAssertTrue(fitness.waitForExistence(timeout: 8))
        XCTAssertTrue(fitness.label.contains("78 kg"), fitness.label)
        XCTAssertTrue(label(of: "area-nutrition").contains("kcal"))
        snapshot("home-info")
    }

    func testMonQuotidienShowsTheDayFromTheUsersData() {
        launch(["-screenshotScreen", "home"])
        XCTAssertTrue(app.otherElements["daily-section"].waitForExistence(timeout: 12), "« Mon Quotidien » absent de l'accueil")
        // The demo person gave a calorie target: what's left today is shown, from their own meals.
        XCTAssertTrue(app.staticTexts["kcal restantes"].waitForExistence(timeout: 5) || app.staticTexts["kcal en trop"].exists)
        XCTAssertFalse(app.buttons["Créer un widget Nutrition"].exists, "La section Créer ne doit plus être sur l'accueil")
        snapshot("home-daily")
    }

    // MARK: Widgets from the Store

    func testTheEditorAsksForWhatTheWidgetNeeds() {
        launch(["-screenshotScreen", "editor-fresh"])
        XCTAssertTrue(app.otherElements["data-kcalTarget"].waitForExistence(timeout: 12), "L'éditeur doit demander l'objectif calorique")
        let example = app.staticTexts["Aperçu avec des données d'exemple"]
        XCTAssertTrue(example.exists, "Sans données, l'aperçu montre un exemple, identifié comme tel")
        snapshot("editor-fresh")
        let kcal = app.textFields["data-kcal"]
        kcal.tap()
        kcal.typeText("2500")
        XCTAssertTrue(waitForDisappearance(example), "Une fois l'objectif donné, l'aperçu montre les vraies données")
        snapshot("editor-own-data")
    }

    func testAPackIsSetWidgetByWidget() {
        launch(["-screenshotScreen", "pack-gym-setup"])
        let step = app.staticTexts["setup-step"]
        XCTAssertTrue(step.waitForExistence(timeout: 15), "La configuration du pack ne s'est pas ouverte")
        XCTAssertEqual(step.label, "Widget 1 sur 6")
        snapshot("pack-step-1")
        for index in 2...6 {
            tapButton("setup-next")
            XCTAssertTrue(app.staticTexts["Widget \(index) sur 6"].waitForExistence(timeout: 5))
        }
        tapButton("setup-next")
        XCTAssertTrue(app.otherElements["setup-summary"].waitForExistence(timeout: 5) || app.staticTexts["Résumé"].exists)
        snapshot("pack-summary")
        tapButton("setup-next")
        XCTAssertTrue(waitForDisappearance(step), "Le pack doit se fermer une fois enregistré")
        XCTAssertEqual(app.state, .runningForeground)
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
