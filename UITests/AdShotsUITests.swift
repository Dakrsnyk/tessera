import UIKit
import XCTest

/// Real states of the app for the ad films, kept as lossless PNG files by the CI (`[adkit]` in the commit
/// message): each scene drives the app like a person would, and at each moment worth keeping it writes
/// « ADSHOT <name> » in the test log, then holds still while the CI, which watches the log, takes a
/// screenshot of the simulator (`xcrun simctl io screenshot`, report/adkit/shots/<name>.png).
/// They check nothing: a missing element only skips a shot, never stops the scene.
final class AdShotsUITests: XCTestCase {
    private var app: XCUIApplication!

    /// The app style of the films: Corail, the colors of Ardane's icon.
    private static let style = "sapphire"

    /// `AD_APPEARANCE=dark` (`TEST_RUNNER_AD_APPEARANCE` for xcodebuild): the same scenes in that appearance,
    /// each shot named `<name>-dark`. The main film shows the app in Dark appearance, floating in black.
    private static let appearance = ProcessInfo.processInfo.environment["AD_APPEARANCE"].flatMap { $0.isEmpty ? nil : $0 }

    override func setUp() {
        continueAfterFailure = true
    }

    override func tearDown() {
        app?.terminate()
    }

    // MARK: Helpers

    private func launch(_ screen: String, _ extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_CA", "-screenshotScreen", screen,
                               "-screenshotStyle", Self.style]
            + (Self.appearance.map { ["-screenshotAppearance", $0] } ?? []) + extra
        app.launch()
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// The moment to keep: the marker in the log (an activity, and a plain line in case activities are
    /// not printed), then the app left alone while the CI takes its screenshot. The test also keeps its
    /// own lossless copy of the screen in the result bundle (an attachment the CI exports), in case the
    /// log reaches the CI late.
    private func shot(_ base: String, hold: TimeInterval = 2.2) {
        let name = Self.appearance.map { "\(base)-\($0)" } ?? base
        let start = Date()
        XCTContext.runActivity(named: "ADSHOT \(name)") { _ in }
        print("ADSHOT \(name)")
        fflush(stdout)
        let screen = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(uniformTypeIdentifier: "public.png", name: "ADSHOT \(name)", payload: screen.pngRepresentation, userInfo: nil)
        attachment.lifetime = .keepAlways
        add(attachment)
        pause(max(0.3, hold - Date().timeIntervalSince(start)))
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

    /// A horizontal swipe across an element, slow enough to be seen.
    private func swipe(_ element: XCUIElement, left: Bool) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.85 : 0.15, dy: 0.5))
        let end = element.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.15 : 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.05)
    }

    /// A button of the Studio's settings, brought on screen above the save bar (« Enregistrer le widget »)
    /// by short drags under the fixed preview, then tapped. The grids are lazy: a tile further down only
    /// exists once the grid has scrolled near it.
    @discardableResult
    private func studioTap(_ identifier: String) -> Bool {
        let button = app.buttons[identifier].firstMatch
        let height = app.frame.height > 200 ? app.frame.height : 874
        // On screen and not under the save bar at the bottom (as StudioUITests.tapButton checks).
        func reachable() -> Bool {
            button.exists && button.isHittable && button.frame.maxY < height - 125
        }
        var drags = 0
        while !reachable() && drags < 14 {
            // Down to what is below (or not created yet), up to what scrolled away above.
            let isAbove = button.exists && button.frame.midY < height * 0.5
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: isAbove ? 0.55 : 0.74))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: isAbove ? 0.74 : 0.55))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
            drags += 1
        }
        guard reachable() else { return false }
        button.tap()
        return true
    }

    /// A section of the Studio: the bar centers the chip chosen, so going one section at a time keeps the next one on screen.
    private func studioSection(_ name: String) -> Bool {
        let chip = app.buttons["studio-\(name)"].firstMatch
        guard chip.waitForExistence(timeout: 5), chip.isHittable else { return false }
        chip.tap()
        pause(0.9)
        return true
    }

    /// The share of strongly colored pixels in an element: a filled check circle is mostly color, an empty one a thin ring.
    private func colorShare(_ element: XCUIElement) -> Double {
        guard let image = element.screenshot().image.cgImage else { return 0 }
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return 0 }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return 0 }
        var colored = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = Int(pixels[index]), green = Int(pixels[index + 1]), blue = Int(pixels[index + 2])
            if max(red, green, blue) - min(red, green, blue) > 60 { colored += 1 }
        }
        return Double(colored) / Double(width * height)
    }

    // MARK: Scenes

    /// Fitness: the workout under way (two sets done, the rest running), then « Série faite » again and again.
    func testAdFitnessSession() {
        launch("app-fitness-session")
        let done = app.buttons["session-set-done"]
        guard done.waitForExistence(timeout: 15) else { return }
        pause(1.5)
        shot("session-0")
        for index in 1...3 {
            guard tap(done, timeout: 3) else { break }
            // The set joins the list, the rest starts again.
            pause(1.2)
            shot("session-\(index)")
        }
        // The whole session under the current set.
        scroll(distance: 0.35)
        pause(1)
        shot("session-list")
    }

    /// Nutrition: what is left today, a food added in two taps, the ring that follows.
    func testAdNutritionAdd() {
        launch("app-nutrition")
        guard app.otherElements["nutrition-hero"].waitForExistence(timeout: 12) else { return }
        pause(1.5)
        shot("nut-0")
        guard tap(app.buttons["nutrition-search"]) else { return }
        pause(1.4)
        shot("nut-1")
        let food = app.buttons.matching(identifier: "food-row").firstMatch
        guard tap(food, timeout: 8) else { return }
        pause(1.4)
        shot("nut-2")
        let save = app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Enregistrer")).firstMatch
        guard save.waitForExistence(timeout: 6) else { return }
        save.tap()
        // The sheet closes and the ring turns to the new total.
        pause(1.8)
        shot("nut-3")
    }

    /// Finances: the balance over the month, three months, the year.
    func testAdFinancesPeriods() {
        launch("app-finances")
        guard app.otherElements["finances-balance"].waitForExistence(timeout: 12) else { return }
        pause(1.5)
        shot("fin-mois")
        for (period, name) in [("3 mois", "fin-3mois"), ("Année", "fin-annee")] {
            let button = app.segmentedControls.buttons[period].firstMatch
            guard button.exists else { continue }
            button.tap()
            pause(1.2)
            shot(name)
        }
    }

    /// The Studio: complete themes, then styles, then palettes, on the same widget.
    func testAdStudio() {
        launch("studio-content")
        guard app.buttons["studio-theme"].waitForExistence(timeout: 15) else { return }
        pause(1.5)
        shot("studio-content")
        // « Thème »: the StylePreset grid (preset-<id>).
        if studioSection("theme") {
            for preset in ["midnight", "ocean", "sunset", "cyber", "luxury"] where studioTap("preset-\(preset)") {
                pause(1)
                shot("studio-preset-\(preset)")
            }
        }
        // « Style »: the 57 styles (theme-<ThemeID>), a lazy grid, in its order so it only scrolls down.
        if studioSection("style") {
            for theme in ["aurora", "liquidGlass", "neon", "editorial", "luxury", "paper", "synthwave", "space"] where studioTap("theme-\(theme)") {
                pause(1)
                shot("studio-style-\(theme)")
            }
        }
        // « Couleurs »: palettes (palette-<id>).
        if studioSection("colors") {
            for palette in ["ocean", "coral", "sunset", "gold", "neon"] where studioTap("palette-\(palette)") {
                pause(1)
                shot("studio-palette-\(palette)")
            }
        }
    }

    /// Planning: the week as a table, then the next week.
    func testAdPlanning() {
        launch("app-planning")
        let table = app.otherElements["week-timetable"]
        guard table.waitForExistence(timeout: 12) else { return }
        pause(1.5)
        shot("plan-0")
        swipe(table, left: true)
        pause(1.6)
        shot("plan-1")
    }

    /// Habits: today's habits, then the first one not done yet checked.
    func testAdHabits() {
        launch("app-planning-habits")
        let switcher = app.otherElements["day-switcher"]
        guard switcher.waitForExistence(timeout: 12) else { return }
        pause(1.5)
        shot("hab-0")
        // The round checks on the left of each habit, under the day switcher and above the tab bar, top to bottom.
        let top = switcher.frame.maxY
        let bottom = app.frame.height - 100
        let checks = app.buttons.allElementsBoundByIndex
            .filter { button in
                let frame = button.frame
                return button.exists && frame.minY > top && frame.maxY < bottom && frame.width < 70 && frame.height < 70
                    && frame.minX < app.frame.width * 0.3
            }
            .sorted { $0.frame.minY < $1.frame.minY }
        let shares = checks.map { colorShare($0) }
        // Not done: a thin ring, much less color than a filled check (Sport, in the demo data).
        guard let low = shares.min(), let high = shares.max(), low < high * 0.75 else { return }
        let middle = (low + high) / 2
        guard let target = shares.firstIndex(where: { $0 < middle }), checks[target].isHittable else { return }
        checks[target].tap()
        pause(1)
        shot("hab-1")
    }

    /// The exercise library read slowly, then two exercise sheets with their demonstration seen at 3/4.
    func testAdExerciseLibrary() {
        launch("app-fitness-library")
        _ = app.searchFields.firstMatch.waitForExistence(timeout: 12)
        pause(1.8)
        shot("lib-0")
        for index in 1...3 {
            scroll(distance: 0.3)
            pause(0.9)
            shot("lib-\(index)")
        }
        app.terminate()
        for (index, exercise) in ["bench-press", "back-squat"].enumerated() {
            launch("app-fitness-exercise-\(exercise)")
            let canvas = app.descendants(matching: .any).matching(identifier: "exercise-demo-canvas").firstMatch
            guard canvas.waitForExistence(timeout: 12) else {
                app.terminate()
                continue
            }
            // The angle that shows the bar best (3/4 is the second view of these two).
            let angle = app.buttons["exercise-demo-view-1"].firstMatch
            if angle.waitForExistence(timeout: 3), angle.isHittable { angle.tap() }
            pause(1.6)
            shot("ex-\(index)")
            app.terminate()
        }
    }
}
