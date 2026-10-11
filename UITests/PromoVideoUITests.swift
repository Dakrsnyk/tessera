import XCTest

/// The scenes of the promo videos (TikTok, Instagram): each test plays one moment of the app slowly,
/// like a person would, while the CI records the simulator's screen (`[video]` in the commit message).
/// They check nothing: a missing element only makes the scene shorter, never stops the recording.
final class PromoVideoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
    }

    override func tearDown() {
        app?.terminate()
    }

    // MARK: Helpers

    private func launch(_ screen: String, _ extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_CA", "-screenshotScreen", screen] + extra
        app.launch()
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// A slow drag of the page, like a thumb reading it.
    private func scroll(down: Bool = true, distance: CGFloat = 0.28) {
        let from: CGFloat = down ? 0.7 : 0.35
        let to = down ? from - distance : from + distance
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to))
        start.press(forDuration: 0.08, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
    }

    /// Taps an element once it is there and on screen (scrolling down a little if needed).
    @discardableResult
    private func tap(_ element: XCUIElement, timeout: TimeInterval = 6) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        var drags = 0
        while !element.isHittable && drags < 6 {
            scroll(distance: 0.2)
            drags += 1
        }
        guard element.isHittable else { return false }
        element.tap()
        return true
    }

    /// The buttons of a row at the top of an element (the rounds of a week, the days of a table), left to right.
    private func topButtons(of container: XCUIElement, within height: CGFloat) -> [XCUIElement] {
        container.buttons.allElementsBoundByIndex
            .filter { $0.frame.minY < container.frame.minY + height && $0.frame.width > 10 }
            .sorted { $0.frame.minX < $1.frame.minX }
    }

    /// A horizontal swipe across an element, slow enough to be seen.
    private func swipe(_ element: XCUIElement, left: Bool) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.85 : 0.15, dy: 0.5))
        let end = element.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.15 : 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.05)
    }

    // MARK: Scenes

    /// « Mon Quotidien »: the whole day on one screen, read from top to bottom.
    func testVideoMonQuotidien() {
        launch("home")
        pause(2.5)
        for _ in 0..<4 {
            scroll()
            pause(1.3)
        }
        pause(0.8)
        scroll(down: false, distance: 0.45)
        pause(0.6)
        scroll(down: false, distance: 0.45)
        pause(1.5)
    }

    /// Planning: the week as a table, a day picked, the next week and back.
    func testVideoPlanning() {
        launch("app-planning")
        let table = app.otherElements["week-timetable"]
        guard table.waitForExistence(timeout: 12) else { return }
        pause(2)
        let days = topButtons(of: table, within: 60)
        for index in [1, 3, 5] where days.indices.contains(index) {
            days[index].tap()
            pause(1.1)
        }
        swipe(table, left: true)
        pause(1.6)
        swipe(table, left: false)
        pause(1.2)
        let today = app.buttons["Aujourd'hui"].firstMatch
        if today.exists && today.isHittable { today.tap() }
        pause(1)
        scroll(distance: 0.35)
        pause(1.6)
    }

    /// Fitness: the week in rounds, a day looked at, then the workout under way, a set done.
    func testVideoFitness() {
        launch("app-fitness")
        let week = app.otherElements["week-card"]
        guard week.waitForExistence(timeout: 12) else { return }
        pause(2)
        scroll(distance: 0.18)
        pause(0.8)
        let rounds = topButtons(of: week, within: 90)
        let todayIndex = rounds.firstIndex { $0.isSelected } ?? (rounds.count - 1)
        for index in [0, 1, 2] where rounds.indices.contains(index) && index != todayIndex {
            rounds[index].tap()
            pause(1.1)
        }
        if rounds.indices.contains(todayIndex) { rounds[todayIndex].tap() }
        pause(1)
        scroll(down: false, distance: 0.3)
        pause(0.6)
        if tap(app.buttons["fitness-resume"]) {
            pause(1.6)
            let done = app.buttons["session-set-done"]
            if tap(done) { pause(2.2) }
            if done.exists, done.isHittable { done.tap(); pause(2.2) }
        }
        pause(1)
    }

    /// Nutrition: what is left today, a food added in two taps, the ring that follows.
    func testVideoNutrition() {
        launch("app-nutrition")
        guard app.otherElements["nutrition-hero"].waitForExistence(timeout: 12) else { return }
        pause(2.2)
        if tap(app.buttons["nutrition-search"]) {
            pause(1.4)
            let food = app.buttons.matching(identifier: "food-row").firstMatch
            if tap(food, timeout: 8) {
                pause(1.4)
                let save = app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Enregistrer")).firstMatch
                if save.waitForExistence(timeout: 6) { save.tap() }
            }
        }
        pause(2)
        scroll(distance: 0.3)
        pause(1.3)
        scroll(distance: 0.3)
        pause(1.5)
    }

    /// The Studio: one widget, styles after styles, then palettes.
    func testVideoStudio() {
        launch("studio-content")
        guard app.buttons["studio-theme"].waitForExistence(timeout: 15) else { return }
        pause(1.5)
        app.buttons["studio-theme"].tap()
        pause(1)
        for theme in ["neon", "luxury", "aurora", "paper", "liquidGlass", "sport"] {
            let button = app.buttons["theme-\(theme)"].firstMatch
            if tap(button, timeout: 3) { pause(1.1) }
        }
        let colors = app.buttons["studio-colors"]
        if colors.exists {
            // The sections bar centers the one chosen: go through « Style » first.
            let style = app.buttons["studio-style"]
            if style.exists { style.tap(); pause(0.5) }
            colors.tap()
            pause(0.8)
            for palette in ["ocean", "coral", "sunset"] {
                if tap(app.buttons["palette-\(palette)"].firstMatch, timeout: 3) { pause(1.1) }
            }
        }
        pause(1.2)
    }

    /// Finances: the balance over the month, three months, the year.
    func testVideoFinances() {
        launch("app-finances")
        guard app.otherElements["finances-balance"].waitForExistence(timeout: 12) else { return }
        pause(2.2)
        for period in ["3 mois", "Année", "Mois"] {
            let button = app.segmentedControls.buttons[period].firstMatch
            if button.exists { button.tap(); pause(1.6) }
        }
        scroll(distance: 0.3)
        pause(1.3)
        scroll(distance: 0.3)
        pause(1.5)
    }

    /// The launch: the two halves of the A slide in, the name rises under them.
    func testVideoLaunch() {
        launch("launch")
        pause(4)
    }

    /// « Icône de l'app »: the icons to choose from, read slowly.
    func testVideoIcons() {
        launch("icons")
        pause(2.5)
        scroll(distance: 0.25)
        pause(1.5)
        scroll(down: false, distance: 0.25)
        pause(1.5)
    }

    /// The Store: ready-made Home Screens and packs.
    func testVideoStore() {
        launch("store")
        pause(2.5)
        for _ in 0..<4 {
            scroll(distance: 0.3)
            pause(1.2)
        }
        pause(1)
    }
}
