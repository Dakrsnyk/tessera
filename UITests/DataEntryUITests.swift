import XCTest

/// Entering data while a widget is being made: a food logged or a workout recorded from « Mes données »
/// (space creator) or « Données de l'espace » (widget editor) must leave that widget exactly as it was,
/// and the app must keep running.
final class DataEntryUITests: XCTestCase {
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
        shot.name = "data-entry-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func isReachable(_ element: XCUIElement) -> Bool {
        element.exists && element.isHittable
    }

    /// A short drag without momentum: a fast swipe can carry a short list well past the element
    /// (the Studio's settings sit under a fixed preview). It starts mid-screen, above the keyboard.
    private func scrollDownOnce() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.34))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    /// Waits for the element, scrolling down to it when it is further down (lists only build the rows
    /// on screen). Only ever scrolls down: a swipe down at the top of a sheet would close it.
    @discardableResult
    private func reveal(_ element: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        _ = element.waitForExistence(timeout: 6)
        var swipes = 0
        while !isReachable(element) && swipes < 20 {
            scrollDownOnce()
            swipes += 1
            _ = element.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(isReachable(element), "\(what) introuvable", file: file, line: line)
        return element
    }

    private func tap(_ element: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        reveal(element, what, file: file, line: line).tap()
    }

    /// The « Enregistrer » button of the form on top.
    private var saveButton: XCUIElement {
        let buttons = app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Enregistrer"))
        return buttons.allElementsBoundByIndex.first { $0.isHittable } ?? buttons.firstMatch
    }

    /// Back to the previous page of the navigation stack on top.
    private func goBack(file: StaticString = #filePath, line: UInt = #line) {
        let back = app.navigationBars.buttons.allElementsBoundByIndex.first {
            $0.isHittable && $0.frame.minX < 60 && $0.label != "Annuler"
        }
        XCTAssertNotNil(back, "Bouton retour introuvable", file: file, line: line)
        back?.tap()
    }

    private func assertRunning(_ step: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(app.state, .runningForeground, "L'app s'est arrêtée : \(step)", file: file, line: line)
    }

    /// Logs the first suggested food: search, quantity, save. Both sheets close in one motion.
    private func logFood() {
        tap(app.buttons["Ajouter un aliment"], "Ajouter un aliment")
        let food = app.buttons.matching(identifier: "food-row").firstMatch
        tap(food, "Premier aliment proposé")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 8), "Feuille de quantité absente")
        snapshot("food-quantity")
        saveButton.tap()
        // Back on the data page, with no sheet left over it.
        XCTAssertTrue(app.buttons["Ajouter un aliment"].waitForExistence(timeout: 8))
        XCTAssertTrue(waitForDisappearance(food), "La recherche d'aliments est restée ouverte")
        assertRunning("après l'ajout d'un aliment")
    }

    /// Logs two sets of today's workout (starting it if needed), then creates a routine.
    private func recordWorkout(named name: String) {
        let setDone = app.buttons["Série faite"]
        if !setDone.waitForExistence(timeout: 4) {
            tap(app.buttons["Commencer la séance"], "Commencer la séance")
        }
        tap(setDone, "Série faite")
        // Some days the session holds a single set left: the next one starts again.
        if !setDone.waitForExistence(timeout: 3) {
            tap(app.buttons["Commencer la séance"], "Commencer la séance (2e)")
        }
        tap(setDone, "Série faite (2e)")
        assertRunning("après deux séries")
        snapshot("workout-sets")

        tap(app.buttons["Nouvelle séance"], "Nouvelle séance")
        let nameField = app.textFields["routine-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 8), "Formulaire de séance absent")
        nameField.tap()
        nameField.typeText(name)
        let exercise = app.textFields.matching(identifier: "exercise-name").firstMatch
        exercise.tap()
        exercise.typeText("Squat")
        snapshot("routine-form")
        saveButton.tap()
        XCTAssertTrue(waitForDisappearance(nameField), "Le formulaire de séance est resté ouvert")
        let created = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(created.waitForExistence(timeout: 8), "La séance créée n'apparaît pas")
        assertRunning("après l'enregistrement de la séance")
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter.wait(for: [gone], timeout: timeout) == .completed
    }

    // MARK: Space creator

    func testCreatorKeepsItsWidgetWhileLoggingFood() {
        launch(["-screenshotScreen", "creator-nutrition", "-screenshotCreatorFormat", "medium"])
        let data = app.buttons["space-data"]
        XCTAssertTrue(data.waitForExistence(timeout: 15), "Créateur Nutrition absent")
        // A choice of the person, different from what the creator opens with.
        let large = app.segmentedControls.buttons["Grand"]
        tap(large, "Taille Grand")
        XCTAssertTrue(large.isSelected)

        data.tap()
        logFood()
        logFood()
        goBack()

        XCTAssertTrue(data.waitForExistence(timeout: 8), "Le créateur s'est fermé")
        XCTAssertTrue(app.segmentedControls.buttons["Grand"].isSelected, "Le widget en cours est reparti de zéro")
        assertRunning("retour au créateur")
        snapshot("creator-after-food")
    }

    func testCreatorKeepsItsWidgetWhileRecordingAWorkout() {
        launch(["-screenshotScreen", "creator-fitness", "-screenshotCreatorFormat", "medium"])
        let data = app.buttons["space-data"]
        XCTAssertTrue(data.waitForExistence(timeout: 15), "Créateur Fitness absent")
        let large = app.segmentedControls.buttons["Grand"]
        tap(large, "Taille Grand")

        data.tap()
        recordWorkout(named: "Jambes créateur")
        goBack()

        XCTAssertTrue(data.waitForExistence(timeout: 8), "Le créateur s'est fermé")
        XCTAssertTrue(app.segmentedControls.buttons["Grand"].isSelected, "Le widget en cours est reparti de zéro")
        assertRunning("retour au créateur")
        snapshot("creator-after-workout")
    }

    // MARK: Widget editor

    func testEditorKeepsItsChangesWhileLoggingFood() {
        launch(["-screenshotScreen", "editor-v2"])
        let name = app.textFields["widget-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15), "Éditeur absent")
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        // Return closes the keyboard: dragging on a field still being edited moves its cursor
        // instead of scrolling the Studio's settings.
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40) + "Mon widget test\n")

        // Above the Studio's save bar: a tap under it would save the widget instead.
        let spaceData = reveal(app.buttons["space-data"], "Données de l'espace")
        let height = app.frame.height.isFinite && app.frame.height > 200 ? app.frame.height : 874
        var extra = 0
        while spaceData.frame.maxY > height - 160 && extra < 5 {
            scrollDownOnce()
            extra += 1
        }
        spaceData.tap()
        logFood()
        goBack()

        XCTAssertTrue(name.waitForExistence(timeout: 8), "L'éditeur s'est fermé")
        XCTAssertEqual(name.value as? String, "Mon widget test", "Les modifications du widget ont été perdues")
        assertRunning("retour à l'éditeur")
        snapshot("editor-after-food")
    }

    // MARK: Espaces tab

    func testFitnessSpaceRecordsAWorkout() {
        launch(["-screenshotScreen", "space-fitness"])
        XCTAssertTrue(app.navigationBars["Fitness"].waitForExistence(timeout: 15), "Espace Fitness absent")
        recordWorkout(named: "Jambes espace")
    }

    func testNutritionSpaceLogsFood() {
        launch(["-screenshotScreen", "space-nutrition"])
        XCTAssertTrue(app.navigationBars["Nutrition"].waitForExistence(timeout: 15), "Espace Nutrition absent")
        logFood()
        logFood()
    }
}
