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
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_CA"] + arguments
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

    /// Switches a Toggle on: since iOS 17 a tap in the middle of a labelled Toggle lands on its label,
    /// so the tap goes to the switch on the right.
    private func turnOn(_ toggle: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        reveal(toggle, what, file: file, line: line)
        func isOn() -> Bool { (toggle.value as? String) == "1" }
        if !isOn() { toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap() }
        if !isOn() { toggle.switches.firstMatch.tap() }
        XCTAssertTrue(isOn(), "\(what) n'a pas pu être activé", file: file, line: line)
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

    /// The « Fermer » of the sheet on top (the screen below can expose one too).
    private func closeSheet(file: StaticString = #filePath, line: UInt = #line) {
        let buttons = app.buttons.matching(NSPredicate(format: "label == %@", "Fermer"))
        let close = buttons.allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(close, "Bouton Fermer introuvable", file: file, line: line)
        close?.tap()
    }

    /// Any element whose label contains a text (list rows merge their texts into one label).
    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

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

    // MARK: Fitness

    func testTheLibraryFindsExercisesAndShowsTheirSheet() {
        launch(["-screenshotScreen", "app-fitness"])
        XCTAssertTrue(app.otherElements["fitness-today"].waitForExistence(timeout: 12), "Mini-app Fitness absente")
        snapshot("fitness")
        tap(app.buttons["fitness-library"], "Bibliothèque d'exercices")
        XCTAssertTrue(app.navigationBars["Exercices"].waitForExistence(timeout: 8), "Bibliothèque absente")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("développé")
        XCTAssertTrue(element(containing: "Développé couché (barre)").waitForExistence(timeout: 5), "La recherche doit proposer les développés")
        XCTAssertTrue(element(containing: "Développé militaire (barre)").exists)
        snapshot("fitness-search")

        // The ⓘ sheet, then back to the list exactly as it was.
        app.buttons.matching(identifier: "exercise-info").firstMatch.tap()
        XCTAssertTrue(app.otherElements["exercise-demo"].waitForExistence(timeout: 8), "Fiche d'exercice absente")
        // The demonstration names the phase of the movement, and offers other angles.
        XCTAssertTrue(app.staticTexts["exercise-demo-phase"].waitForExistence(timeout: 5), "Les phases du mouvement doivent être nommées")
        let angle = app.buttons["exercise-demo-view-1"]
        if angle.waitForExistence(timeout: 3) {
            angle.tap()
            XCTAssertTrue(angle.isSelected, "L'angle choisi est sélectionné")
        }
        snapshot("fitness-exercise-sheet")
        closeSheet()
        XCTAssertTrue(element(containing: "Développé couché (barre)").waitForExistence(timeout: 5), "Retour à la recherche")

        // The exercise page: add it to a session of the program.
        app.buttons.matching(identifier: "exercise-row").firstMatch.tap()
        tap(app.buttons["exercise-add"], "Ajouter à ma séance")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 8), "Feuille d'ajout absente")
        saveButton.tap()
        XCTAssertTrue(app.buttons["exercise-add"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testASessionKeepsItsPlaceWhenTheSheetOpens() {
        launch(["-screenshotScreen", "app-fitness-session"])
        let done = app.buttons["session-set-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 12), "Séance en cours absente")
        snapshot("fitness-session")
        let before = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "séries")).firstMatch.label
        done.tap()
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        let after = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "séries")).firstMatch.label
        XCTAssertNotEqual(before, after, "La série faite doit compter")

        let info = app.buttons["session-info"]
        if info.waitForExistence(timeout: 3) {
            info.tap()
            XCTAssertTrue(app.otherElements["exercise-demo"].waitForExistence(timeout: 8), "Fiche d'exercice absente")
            closeSheet()
            XCTAssertTrue(done.waitForExistence(timeout: 5), "Retour à la séance, au même endroit")
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: Planning

    func testPlanningAddsATaskToTodayAndOpensItsPages() {
        launch(["-screenshotScreen", "app-planning"])
        XCTAssertTrue(app.otherElements["planning-today"].waitForExistence(timeout: 12), "Mini-app Planning absente")
        snapshot("planning")

        tap(app.buttons["planning-new-task"], "Nouvelle tâche")
        let title = app.textFields["task-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8), "Formulaire de tâche absent")
        title.tap()
        title.typeText("Rappeler Léa")
        saveButton.tap()
        XCTAssertTrue(waitForDisappearance(title), "Le formulaire est resté ouvert")
        XCTAssertTrue(element(containing: "Rappeler Léa").waitForExistence(timeout: 8), "La tâche du jour doit apparaître dans la journée")
        snapshot("planning-task-added")

        for (identifier, title) in [("planning-tasks", "Tâches"), ("planning-week", "Semaine"), ("planning-habits", "Habitudes")] {
            tap(app.buttons[identifier], title)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8), "Page \(title) absente")
            snapshot(identifier)
            goBack()
            XCTAssertTrue(app.otherElements["planning-today"].waitForExistence(timeout: 8), "Retour depuis \(title)")
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: Studies

    func testStudiesChecksHomeworkTimesStudyAndOpensItsPages() {
        launch(["-screenshotScreen", "app-studies"])
        let timer = app.otherElements["studies-timer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 12), "Mini-app Études absente")
        snapshot("studies")

        // Homework handed in leaves the list right away.
        let toggles = app.buttons.matching(identifier: "assignment-toggle")
        reveal(toggles.firstMatch, "Devoir à rendre")
        let before = toggles.count
        toggles.firstMatch.tap()
        let fewer = expectation(for: NSPredicate(format: "count == %d", before - 1), evaluatedWith: toggles)
        XCTAssertEqual(XCTWaiter().wait(for: [fewer], timeout: 5), .completed, "Le devoir rendu doit quitter « À rendre »")

        // The study timer starts, then stops (too short to count).
        tap(app.buttons["studies-timer-start"], "Démarrer le chrono")
        let noCourse = app.buttons["Sans cours précis"]
        XCTAssertTrue(noCourse.waitForExistence(timeout: 5), "Choix du cours absent")
        noCourse.tap()
        tap(app.buttons["studies-timer-stop"], "Terminer le chrono")
        XCTAssertTrue(element(containing: "Moins d'une minute").waitForExistence(timeout: 5), "Le chrono doit s'arrêter")

        for (identifier, title) in [("studies-timetable", "Horaire"), ("studies-grades", "Notes"), ("studies-revision", "Révisions")] {
            tap(app.buttons[identifier], title)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8), "Page \(title) absente")
            snapshot(identifier)
            if identifier == "studies-revision" {
                tap(app.buttons["card-reveal"], "Voir la réponse")
                tap(app.buttons["card-known"], "Je savais")
            }
            goBack()
            XCTAssertTrue(timer.waitForExistence(timeout: 8), "Retour depuis \(title)")
        }

        // A course, from the list of courses.
        tap(app.buttons["studies-courses"], "Cours")
        XCTAssertTrue(app.navigationBars["Cours"].waitForExistence(timeout: 8), "Liste des cours absente")
        app.buttons.matching(identifier: "course-row").firstMatch.tap()
        XCTAssertTrue(app.buttons["course-menu"].waitForExistence(timeout: 8), "Page du cours absente")
        snapshot("studies-course")
        goBack()
        goBack()
        XCTAssertTrue(timer.waitForExistence(timeout: 8))
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: Finances

    func testFinancesEditsAnExpenseAndOpensItsPages() {
        launch(["-screenshotScreen", "app-finances"])
        let hero = app.otherElements["finances-hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 12), "Mini-app Finances absente")
        snapshot("finances")

        // An expense of the month: open it, change it, then delete it.
        tap(app.buttons["finances-transactions"], "Opérations")
        XCTAssertTrue(app.navigationBars["Opérations"].waitForExistence(timeout: 8), "Page des opérations absente")
        let rows = app.buttons.matching(identifier: "expense-row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 8), "Aucune dépense du mois")
        // The list loads its rows as they appear: the first one is followed, not the count.
        let first = rows.firstMatch.label
        rows.firstMatch.tap()
        let delete = app.buttons["Supprimer la dépense"]
        XCTAssertTrue(delete.waitForExistence(timeout: 8), "La dépense doit s'ouvrir pour être modifiée")
        snapshot("finances-expense")
        delete.tap()
        XCTAssertTrue(waitForDisappearance(delete), "La fiche de la dépense est restée ouverte")
        let gone = expectation(for: NSPredicate(format: "label != %@", first), evaluatedWith: rows.firstMatch)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "La dépense supprimée doit disparaître")
        goBack()
        XCTAssertTrue(hero.waitForExistence(timeout: 8))

        for (identifier, title) in [("finances-categories", "Catégories"), ("finances-bills", "Factures"), ("finances-trends", "Évolution")] {
            tap(app.buttons[identifier], title)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8), "Page \(title) absente")
            snapshot(identifier)
            goBack()
            XCTAssertTrue(hero.waitForExistence(timeout: 8), "Retour depuis \(title)")
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: Business

    func testBusinessComparesPeriodsAndLetsMeChooseIndicators() {
        launch(["-screenshotScreen", "app-business"])
        let hero = app.otherElements["business-hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 12), "Mini-app Business absente")
        snapshot("business")

        // Another period: the figures follow.
        app.segmentedControls["business-period"].buttons["Semaine"].tap()
        XCTAssertTrue(element(containing: "la semaine dernière").waitForExistence(timeout: 5), "La comparaison doit suivre la période")

        // Choose an indicator: it appears on the dashboard.
        tap(app.buttons["business-choose-kpis"], "Choisir mes indicateurs")
        let visitors = app.buttons["kpi-visitors"]
        XCTAssertTrue(visitors.waitForExistence(timeout: 8), "Liste des indicateurs absente")
        visitors.tap()
        app.buttons["OK"].tap()
        XCTAssertTrue(element(containing: "Visiteurs").waitForExistence(timeout: 8), "L'indicateur choisi doit apparaître")
        snapshot("business-kpis")

        for (identifier, title) in [("business-sales", "Ventes et dépenses"), ("business-results", "Résultats")] {
            tap(app.buttons[identifier], title)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8), "Page \(title) absente")
            snapshot(identifier)
            goBack()
            XCTAssertTrue(hero.waitForExistence(timeout: 8), "Retour depuis \(title)")
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: Travel, Auto, Weather

    func testTravelChecksTheListAndOpensTheProgram() {
        launch(["-screenshotScreen", "app-travel"])
        let hero = app.otherElements["travel-hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 12), "Mini-app Voyage absente")
        snapshot("travel")

        tap(app.buttons["travel-checklist"], "À ne pas oublier")
        let items = app.buttons.matching(identifier: "checklist-item")
        XCTAssertTrue(items.firstMatch.waitForExistence(timeout: 8), "Liste absente")
        let field = app.textFields["checklist-add"]
        field.tap()
        field.typeText("Maillot de bain\n")
        XCTAssertTrue(element(containing: "Maillot de bain").waitForExistence(timeout: 5), "L'élément ajouté doit apparaître")
        snapshot("travel-checklist")
        goBack()
        XCTAssertTrue(hero.waitForExistence(timeout: 8))

        for (identifier, title) in [("travel-budget", "Budget · Lisbonne"), ("travel-program", "Programme")] {
            tap(app.buttons[identifier], title)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8), "Page \(title) absente")
            snapshot(identifier)
            goBack()
            XCTAssertTrue(hero.waitForExistence(timeout: 8), "Retour depuis \(title)")
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testCarShowsTheRangeAndItsPages() {
        launch(["-screenshotScreen", "app-car"])
        let hero = app.otherElements["car-hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 12), "Mini-app Auto absente")
        XCTAssertTrue(element(containing: "Autonomie estimée").exists, "Avec la taille du réservoir, l'autonomie s'affiche")
        snapshot("car")
        for (identifier, title) in [("car-fuel", "Carburant"), ("car-mileage", "Kilométrage")] {
            tap(app.buttons[identifier], title)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8), "Page \(title) absente")
            snapshot(identifier)
            if identifier == "car-fuel" {
                app.buttons.matching(identifier: "fuel-row").firstMatch.tap()
                XCTAssertTrue(app.buttons["Supprimer le plein"].waitForExistence(timeout: 8), "Un plein doit s'ouvrir pour être modifié")
                app.buttons["Annuler"].tap()
            }
            goBack()
            XCTAssertTrue(hero.waitForExistence(timeout: 8), "Retour depuis \(title)")
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Nutrition: the settings at the bottom change the same data as « Mes informations », and the
    /// gender stays visible after a choice, so a wrong tap can be fixed.
    func testNutritionSettingsAreEditedInPlaceAndTheGenderCanBeChanged() {
        launch(["-screenshotScreen", "app-nutrition"])
        tap(app.buttons["miniapp-settings-edit"], "Modifier mes paramètres")
        let female = app.buttons["gender-female"]
        tap(female, "Genre Femme")
        let nonBinary = app.buttons["gender-nonBinary"]
        reveal(nonBinary, "Genre Non binaire")
        XCTAssertTrue(female.exists, "Les choix de genre restent affichés après un choix")
        nonBinary.tap()
        XCTAssertTrue(nonBinary.isSelected || (nonBinary.value as? String) == "1" || app.buttons["gender-reference-neutral"].waitForExistence(timeout: 4),
                      "Le nouveau choix est pris")
        XCTAssertTrue(app.buttons["gender-reference-neutral"].waitForExistence(timeout: 4), "Une référence de calcul est proposée")
        snapshot("nutrition-settings")
        tap(female, "Genre Femme")
        XCTAssertFalse(app.buttons["gender-reference-neutral"].exists, "Femme n'a pas besoin de référence")
    }

    /// « Mon Quotidien »: a swipe changes what a card shows.
    func testAMonQuotidienCardShowsAnotherViewWhenSwiped() {
        launch(["-screenshotScreen", "home"])
        let pager = app.descendants(matching: .any)["daily-pager-nutrition"]
        XCTAssertTrue(pager.waitForExistence(timeout: 12), "La carte Nutrition doit pouvoir changer de vue")
        let dots = app.descendants(matching: .any)["daily-pager-nutrition-dots"]
        reveal(dots, "Points de la carte Nutrition")
        XCTAssertTrue(dots.label.contains("Vue 1 sur 3"), dots.label)
        // Swipe on the card itself, just above its dots.
        let card = dots.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: -60))
        let left = card.withOffset(CGVector(dx: -80, dy: 0))
        let right = card.withOffset(CGVector(dx: 80, dy: 0))
        right.press(forDuration: 0.05, thenDragTo: left, withVelocity: .fast, thenHoldForDuration: 0)
        let moved = expectation(for: NSPredicate(format: "label CONTAINS %@", "Vue 2 sur 3"), evaluatedWith: dots)
        wait(for: [moved], timeout: 5)
        XCTAssertTrue(dots.label.contains("Vue 2 sur 3"), dots.label)
        snapshot("daily-swiped")
        // Kept for the next launch.
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_CA"] + ["-screenshotScreen", "home-info"]
        app.launch()
        let kept = app.descendants(matching: .any)["daily-pager-nutrition-dots"]
        XCTAssertTrue(kept.waitForExistence(timeout: 12))
        XCTAssertTrue(kept.label.contains("Vue 2 sur 3"), "La vue choisie est gardée : \(kept.label)")
    }

    /// Créer: the Lock Screen category lists its widgets, marks the interactive ones and shows the live workout.
    func testTheLockScreenCategoryShowsItsWidgets() {
        launch(["-screenshotScreen", "spaces"])
        tap(app.buttons["create-lockscreen"], "Écran verrouillé")
        XCTAssertTrue(app.descendants(matching: .any)["lock-creator"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.descendants(matching: .any)["lock-workout-preview"].waitForExistence(timeout: 4), "La séance en direct est présentée")
        snapshot("lock-creator")
        turnOn(app.switches["lock-interactive-filter"], "Filtre interactifs")
        XCTAssertTrue(app.buttons["lock-weather"].waitForNonExistence(timeout: 4), "Le filtre ne garde que les widgets interactifs")
        var drags = 0
        while !app.buttons["lock-nextSet"].exists && drags < 10 {
            scrollDownOnce()
            drags += 1
        }
        XCTAssertTrue(app.buttons["lock-nextSet"].exists, "Prochaine série (écran verrouillé) absente")
        XCTAssertFalse(app.buttons["lock-weather"].exists, "Le filtre ne garde que les widgets interactifs")
    }

    /// Home leads to the mini-apps through « Mon Quotidien »: its Nutrition card opens Nutrition.
    func testMonQuotidienOpensAMiniApp() {
        launch(["-screenshotScreen", "home"])
        let nutrition = app.buttons["daily-nutrition-open"]
        reveal(nutrition, "La carte Nutrition de Mon Quotidien")
        nutrition.tap()
        XCTAssertTrue(app.navigationBars["Nutrition"].waitForExistence(timeout: 10), "La mini-app Nutrition doit s'ouvrir")
        snapshot("daily-opens-nutrition")
        XCTAssertEqual(app.state, .runningForeground)
    }
}
