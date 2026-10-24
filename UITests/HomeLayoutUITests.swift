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
