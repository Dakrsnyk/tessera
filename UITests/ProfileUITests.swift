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

    /// Text shown by the Nutrition card of « Mon Quotidien » (its figures sit inside the link to the mini-app).
    private func nutritionShows(_ text: String) -> Bool {
        let link = app.buttons["daily-nutrition-open"]
        return app.staticTexts[text].exists || (link.exists && link.label.contains(text))
    }

    private func launch(_ arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_CA"] + arguments
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

        // Then the tour of the app, step by step, on the app itself.
        let step = app.staticTexts["tutorial-step"]
        XCTAssertTrue(step.waitForExistence(timeout: 10), "Le tutoriel doit suivre les premières questions")
        XCTAssertEqual(step.label, "Étape 1 sur 10")
        XCTAssertTrue(app.staticTexts["Bienvenue, Mathys !"].exists, "Le tutoriel accueille par le prénom")
        snapshot("tutorial-welcome")
        for number in 2...10 {
            app.buttons["tutorial-next"].tap()
            XCTAssertTrue(waitForLabel(step, "Étape \(number) sur 10"), "Étape \(number) du tutoriel absente")
            if number == 2 { snapshot("tutorial-daily") }
            if number == 6 {
                // The Studio in miniature works: a color repaints the widget, the arrow takes it back.
                app.buttons["tutorial-color-FF6B57"].tap()
                let bravo = app.descendants(matching: .any).matching(identifier: "tutorial-bravo").firstMatch
                XCTAssertTrue(bravo.waitForExistence(timeout: 4), "Essayer une couleur doit être salué")
                snapshot("tutorial-studio")
            }
        }
        app.buttons["tutorial-next"].tap()
        XCTAssertTrue(waitForDisappearance(step), "« Terminer » ferme le tutoriel")

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
        // The tour can be skipped as a whole, from its first step.
        let skipAll = app.buttons["tutorial-skip-all"]
        XCTAssertTrue(skipAll.waitForExistence(timeout: 10), "Le tutoriel doit suivre les premières questions")
        skipAll.tap()
        XCTAssertTrue(waitForDisappearance(skipAll), "« Passer le tutoriel » le ferme")
        XCTAssertTrue(app.buttons["Choisir mes centres d'intérêt"].waitForExistence(timeout: 10), "L'accueil doit inviter à compléter")
        // No target and no budget given: « Mon Quotidien » never makes one up.
        XCTAssertFalse(nutritionShows("kcal restantes"), "Calories restantes sans objectif donné")
        XCTAssertFalse(app.staticTexts["à dépenser par jour d'ici la fin du mois"].exists, "Budget du jour sans budget donné")
        snapshot("home-skipped")
    }

    /// The tutorial again from Réglages: each step can be skipped, several at once, or the whole tour left.
    func testTheTutorialReplaysFromSettingsAndEachStepCanBeSkipped() {
        launch(["-screenshotScreen", "settings"])
        // In « Aide », near the end of the settings list: rows further down are made as it scrolls.
        let replay = app.buttons["settings-tutorial"]
        XCTAssertTrue(app.navigationBars.buttons["OK"].firstMatch.waitForExistence(timeout: 12) || app.staticTexts["Mon profil"].exists, "Réglages absents")
        var swipes = 0
        while !(replay.exists && replay.isHittable) && swipes < 12 {
            app.swipeUp()
            swipes += 1
        }
        replay.tap()
        let step = app.staticTexts["tutorial-step"]
        XCTAssertTrue(step.waitForExistence(timeout: 10), "Réglages doit relancer le tutoriel")
        XCTAssertEqual(step.label, "Étape 1 sur 10")
        app.buttons["tutorial-next"].tap()
        XCTAssertTrue(waitForLabel(step, "Étape 2 sur 10"))
        XCTAssertTrue(app.navigationBars["Tessera"].exists || app.staticTexts["Mon Quotidien"].exists, "L'étape montre l'accueil")
        app.buttons["tutorial-skip"].tap()
        XCTAssertTrue(waitForLabel(step, "Étape 3 sur 10"), "« Passer l'étape » mène à la suivante")
        // Straight to the Store: several steps skipped at once.
        app.buttons["Aller à l'étape 7 : Le Store"].tap()
        XCTAssertTrue(waitForLabel(step, "Étape 7 sur 10"))
        XCTAssertTrue(app.tabBars.buttons["Store"].isSelected || app.navigationBars["Store"].waitForExistence(timeout: 5), "L'étape montre le Store")
        snapshot("tutorial-store")
        app.buttons["tutorial-close"].tap()
        XCTAssertTrue(waitForDisappearance(step), "La croix quitte le tutoriel")
        XCTAssertEqual(app.state, .runningForeground)
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 6) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
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
        XCTAssertTrue(app.buttons["daily-nutrition-open"].waitForExistence(timeout: 5), "La carte Nutrition doit ouvrir la mini-app")
        XCTAssertTrue(nutritionShows("kcal restantes") || nutritionShows("kcal en trop"), app.buttons["daily-nutrition-open"].label)
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

    /// A pack opens in the Studio with all its widgets: each one can be chosen, then all are saved together.
    func testAPackOpensInTheStudio() {
        launch(["-screenshotScreen", "pack-gym-setup"])
        let first = app.buttons["studio-widget-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 15), "Le pack ne s'est pas ouvert dans le Studio")
        XCTAssertTrue(first.isSelected, "Le premier widget du pack est celui qu'on règle d'abord")
        snapshot("pack-studio")
        for index in 2...6 {
            let chip = app.buttons["studio-widget-\(index)"]
            XCTAssertTrue(chip.waitForExistence(timeout: 5), "Widget \(index) du pack absent")
            // The row of widgets scrolls sideways: a short drag from the chip just chosen brings the next one.
            // (Its frame is known even off screen: no hit test on an element that isn't visible.)
            let width = app.frame.width > 100 ? app.frame.width : 402
            let row = chip.frame.midY
            var drags = 0
            while chip.frame.midX > width - 40 && drags < 6 {
                let origin = app.coordinate(withNormalizedOffset: .zero)
                let start = origin.withOffset(CGVector(dx: width * 0.75, dy: row))
                let end = origin.withOffset(CGVector(dx: width * 0.35, dy: row))
                start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
                drags += 1
            }
            chip.tap()
            let selected = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: chip)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 4), .completed, "Le widget \(index) ne s'ouvre pas")
        }
        snapshot("pack-studio-last")
        tapButton("Enregistrer les 6 widgets")
        XCTAssertTrue(waitForDisappearance(first), "Le pack doit se fermer une fois enregistré")
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
        // First the selection, then the Studio.
        let next = app.buttons["creator-continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 15), "Le créateur n'a pas de bouton pour passer au Studio")
        XCTAssertTrue(app.segmentedControls.buttons["Moyen"].isSelected)
        next.tap()
        let part = app.buttons["part-caloriesLeft"]
        XCTAssertTrue(part.waitForExistence(timeout: 10), "Réglages par widget absents du Studio")
        var swipes = 0
        while !part.isHittable && swipes < 8 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            swipes += 1
        }
        part.tap()
        let name = app.textFields["Nom du widget"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 8))
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + "Mes calories")
        snapshot("part-settings")
        goBack()
        XCTAssertTrue(label(of: "part-caloriesLeft").contains("Mes calories"))
        snapshot("creator-studio")
        // Back to the selection: the size chosen is kept.
        goBack()
        XCTAssertTrue(app.segmentedControls.buttons["Moyen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["Moyen"].isSelected, "Le format choisi est gardé")
    }

    private func goBack() {
        let back = app.navigationBars.buttons.allElementsBoundByIndex.first { $0.isHittable && $0.frame.minX < 60 && $0.label != "Annuler" }
        XCTAssertNotNil(back, "Bouton retour absent")
        back?.tap()
    }
}
