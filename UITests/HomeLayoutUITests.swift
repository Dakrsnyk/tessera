import XCTest

/// Non-regression: « Mon Quotidien » stays fixed. In English and German (longer texts), every card sits
/// inside the screen, and a sideways swipe over the page moves nothing. These tests live in
/// `ProfileUITests` so the existing CI filters (`[daily]`) run them.
extension ProfileUITests {
    func testHomeStaysFixedInEnglish() {
        assertHomeStaysFixed(language: "en", locale: "en_US")
    }

    func testHomeStaysFixedInGerman() {
        assertHomeStaysFixed(language: "de", locale: "de_DE")
    }

    /// Edit mode of « Mon Quotidien » (long press, like the Home screen of iOS): the « OK » and the round
    /// « − » of the wide Nutrition card show, the size button flips to « + » once tapped, « OK » ends the mode.
    func testDailyEditModeResizesAndEnds() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_CA", "-screenshotScreen", "home"]
        app.launch()
        addTeardownBlock { app.terminate() }

        let card = app.descendants(matching: .any)["daily-nutrition"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 12), "Carte Nutrition absente")
        // As on the Home Screen: a long press opens the card's menu, « Organiser… » makes the cards wiggle.
        card.press(forDuration: 1.2)
        let organize = app.buttons["Organiser…"]
        XCTAssertTrue(organize.waitForExistence(timeout: 5), "L'appui long n'ouvre pas le menu de la carte")
        organize.tap()

        let done = app.buttons["daily-edit-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "« Organiser… » n'ouvre pas le mode édition")
        let shrink = app.buttons["daily-shrink-nutrition"]
        XCTAssertTrue(shrink.waitForExistence(timeout: 5), "Pas de « − » sur la carte large")
        shrink.tap()
        XCTAssertTrue(app.buttons["daily-grow-nutrition"].waitForExistence(timeout: 5), "Le « + » n'apparaît pas une fois la carte rétrécie")

        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "« OK » ne ferme pas le mode édition")
        XCTAssertFalse(app.buttons["daily-grow-nutrition"].exists, "Le « + » reste hors du mode édition")
    }

    /// Edit mode: a card held half a second then dragged onto its neighbour takes its place (and back, so the
    /// order the other tests see is unchanged), and a quick swipe over a card scrolls Home instead of lifting it
    /// (remark of 2026-11-05 on Build 340, `DailyHoldToMove`).
    func testDailyEditModeMovesHeldCardsAndScrollsOnSwipe() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_CA", "-screenshotScreen", "home"]
        app.launch()
        addTeardownBlock { app.terminate() }

        let nutritionCard = app.descendants(matching: .any)["daily-nutrition"].firstMatch
        XCTAssertTrue(nutritionCard.waitForExistence(timeout: 12), "Carte Nutrition absente")
        nutritionCard.press(forDuration: 1.2)
        let organize = app.buttons["Organiser…"]
        XCTAssertTrue(organize.waitForExistence(timeout: 5), "L'appui long n'ouvre pas le menu de la carte")
        organize.tap()
        let done = app.buttons["daily-edit-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "« Organiser… » n'ouvre pas le mode édition")
        Thread.sleep(forTimeInterval: 0.6)

        // Each card is found by its « × » (top left corner of the card, outside its pages): the identifiers of the
        // cards' contents sit inside their horizontal pages and can be off screen (Build 343).
        let screen = app.windows.firstMatch.frame
        func corner(_ id: String) -> XCUIElement { app.buttons["daily-remove-\(id)"] }
        let nutrition = corner("nutrition")
        XCTAssertTrue(nutrition.waitForExistence(timeout: 5), "Pas de « × » sur la carte Nutrition en mode édition")
        /// Away from the top and the bottom of the screen, where Home would scroll by itself under a held card.
        func inMiddle(_ frame: CGRect) -> Bool {
            frame.minY > screen.height * 0.18 && frame.minY < screen.height * 0.6
        }
        /// Reading order of two cards from their corners: by row, then left to right (the wiggle tilts a little).
        func comesBefore(_ a: CGRect, _ b: CGRect) -> Bool {
            abs(a.minY - b.minY) < 20 ? a.minX < b.minX : a.minY < b.minY
        }
        /// A point well inside the card, away from its « × » and its « + » / « − ».
        func inside(_ corner: XCUIElement) -> XCUICoordinate {
            corner.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 66, dy: 76))
        }
        let others = ["planning", "workout", "habits", "steps", "budget", "priorities", "reminders"]
            .map(corner)
            .filter { $0.exists && inMiddle($0.frame) }
        guard inMiddle(nutrition.frame), let neighbour = others.min(by: {
            abs($0.frame.minY - nutrition.frame.minY) < abs($1.frame.minY - nutrition.frame.minY)
        }) else {
            throw XCTSkip("Pas deux cartes au milieu de l'écran sur ce simulateur : \(nutrition.frame)")
        }
        let nutritionFirst = comesBefore(nutrition.frame, neighbour.frame)

        /// Holds the Nutrition card, drags it onto the neighbour, waits for the drop.
        func moveNutritionOntoNeighbour() {
            inside(nutrition).press(forDuration: 0.9, thenDragTo: inside(neighbour), withVelocity: .slow, thenHoldForDuration: 0.6)
            Thread.sleep(forTimeInterval: 1.0)
        }

        moveNutritionOntoNeighbour()
        XCTAssertNotEqual(comesBefore(nutrition.frame, neighbour.frame), nutritionFirst,
                          "La carte maintenue puis glissée ne prend pas la place de sa voisine : \(nutrition.frame) / \(neighbour.frame)")
        XCTAssertTrue(done.exists, "Le déplacement a fermé le mode édition")
        moveNutritionOntoNeighbour()
        XCTAssertEqual(comesBefore(nutrition.frame, neighbour.frame), nutritionFirst, "La carte ne revient pas à sa place")

        // A quick swipe up over the card: Home scrolls, nothing is lifted or moved.
        let top = nutrition.frame.minY
        let start = inside(nutrition)
        let end = start.withOffset(CGVector(dx: 0, dy: -240))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.1)
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertLessThan(nutrition.frame.minY, top - 60, "Un balayage sur une carte ne fait pas défiler l'accueil en mode édition")
        XCTAssertEqual(comesBefore(nutrition.frame, neighbour.frame), nutritionFirst, "Le balayage a déplacé une carte")
        XCTAssertTrue(done.exists, "Le balayage a fermé le mode édition")
    }

    private func assertHomeStaysFixed(language: String, locale: String, file: StaticString = #filePath, line: UInt = #line) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-screenshotScreen", "home"]
        app.launch()
        addTeardownBlock { app.terminate() }

        let section = app.otherElements["daily-section"]
        XCTAssertTrue(section.waitForExistence(timeout: 12), "« Mon Quotidien » absent (\(language))", file: file, line: line)
        // The Nutrition card carries the longest buttons; the others are checked when they are on the page.
        XCTAssertTrue(app.buttons["daily-nutrition-open"].waitForExistence(timeout: 5), "Carte Nutrition absente (\(language))", file: file, line: line)

        let screen = app.windows.firstMatch.frame
        let identifiers = ["daily-title", "daily-section", "daily-nutrition", "daily-nutrition-open", "daily-scan",
                           "daily-add-category", "home-info"]

        /// The frame of every element of the list that is on the page right now.
        func frames() -> [String: CGRect] {
            var found: [String: CGRect] = [:]
            for identifier in identifiers {
                let element = app.descendants(matching: .any)[identifier].firstMatch
                if element.exists { found[identifier] = element.frame }
            }
            return found
        }

        func assertInside(_ frames: [String: CGRect], _ moment: String) {
            XCTAssertGreaterThanOrEqual(frames.count, 4, "Trop peu d'éléments trouvés (\(language), \(moment)) : \(frames.keys.sorted())", file: file, line: line)
            for (identifier, frame) in frames {
                XCTAssertGreaterThanOrEqual(frame.minX, -0.5, "\(identifier) dépasse à gauche (\(language), \(moment)) : \(frame)", file: file, line: line)
                XCTAssertLessThanOrEqual(frame.maxX, screen.width + 1, "\(identifier) dépasse à droite (\(language), \(moment)) : \(frame)", file: file, line: line)
            }
        }

        let before = frames()
        assertInside(before, "au départ")

        // A sideways drag over the title (not over a card with its own pager), both ways.
        let titleY = (before["daily-title"]?.midY ?? screen.height * 0.25) / screen.height
        let left = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: titleY))
        let right = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: titleY))
        left.press(forDuration: 0.05, thenDragTo: right)
        Thread.sleep(forTimeInterval: 0.6)
        right.press(forDuration: 0.05, thenDragTo: left)
        Thread.sleep(forTimeInterval: 0.6)

        let after = frames()
        assertInside(after, "après le balayage")
        for (identifier, frame) in before {
            guard let moved = after[identifier] else { continue }
            XCTAssertEqual(moved.minX, frame.minX, accuracy: 1, "\(identifier) a glissé de côté (\(language))", file: file, line: line)
            XCTAssertEqual(moved.maxX, frame.maxX, accuracy: 1, "\(identifier) a glissé de côté (\(language))", file: file, line: line)
        }
    }
}
