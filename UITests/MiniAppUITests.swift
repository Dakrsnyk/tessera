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
        let before = rows.count
        rows.firstMatch.tap()
        let delete = app.buttons["Supprimer la dépense"]
        XCTAssertTrue(delete.waitForExistence(timeout: 8), "La dépense doit s'ouvrir pour être modifiée")
        snapshot("finances-expense")
        delete.tap()
        XCTAssertTrue(waitForDisappearance(delete), "La fiche de la dépense est restée ouverte")
        let fewer = expectation(for: NSPredicate(format: "count == %d", before - 1), evaluatedWith: rows)
        XCTAssertEqual(XCTWaiter().wait(for: [fewer], timeout: 5), .completed, "La dépense supprimée doit disparaître")
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

    func testHomeListsTheMiniAppsAndTheWeatherOpens() {
        launch(["-screenshotScreen", "home"])
        reveal(app.buttons["mini-apps-all"], "« Mes mini-apps » sur l'accueil")
        let chips = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "mini-app-"))
        XCTAssertGreaterThanOrEqual(chips.count, 3, "Les mini-apps avec des données doivent être proposées")
        snapshot("home-mini-apps")
        tap(app.buttons["mini-apps-all"], "Toutes les mini-apps")
        let weather = app.buttons["all-apps-weather"]
        XCTAssertTrue(weather.waitForExistence(timeout: 8), "La liste de toutes les mini-apps doit s'ouvrir")
        weather.tap()
        XCTAssertTrue(app.navigationBars["Météo"].waitForExistence(timeout: 10), "La météo détaillée doit s'ouvrir")
        snapshot("weather")
        XCTAssertEqual(app.state, .runningForeground)
    }
}
