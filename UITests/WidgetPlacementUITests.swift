import XCTest

/// Places Tessera widgets the way a person would, on a simulated iPhone, and keeps a
/// screenshot (and the accessibility tree) of every step. Labels are matched in English and French.
final class WidgetPlacementUITests: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    /// The Lock Screen editor runs in its own process, not in SpringBoard.
    private let posterBoard = XCUIApplication(bundleIdentifier: "com.apple.PosterBoard")

    /// Gallery names of the V2 widgets tried on the Lock Screen, in the order they appear.
    private let lockScreenV2Names = ["Nutrition", "Dates et lune", "Priorités et projets", "Suivi d'habitudes", "Tableaux de bord"]

    override func setUp() {
        continueAfterFailure = true
    }

    // MARK: Helpers

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Only the Lock Screen test looks inside PosterBoard: querying it while it has no window fails the test.
    private var searchesPosterBoard = false

    private var systemApps: [XCUIApplication] {
        searchesPosterBoard ? [springboard, posterBoard] : [springboard]
    }

    private func snapshot(_ name: String, tree: Bool = false) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        guard tree else { return }
        for app in systemApps {
            let text = XCTAttachment(string: app.debugDescription)
            text.name = "\(name)-tree-\(app == posterBoard ? "posterboard" : "springboard")"
            text.lifetime = .keepAlways
            add(text)
        }
    }

    /// Finds an element by exact label first, then by partial label, in SpringBoard and PosterBoard.
    private func element(
        _ labels: [String],
        types: [XCUIElement.ElementType] = [.button, .menuItem, .cell],
        timeout: TimeInterval = 4
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for app in systemApps {
                for type in types {
                    for label in labels {
                        let exact = app.descendants(matching: type)
                            .matching(NSPredicate(format: "label ==[c] %@ OR identifier ==[c] %@", label, label))
                            .firstMatch
                        if exact.exists { return exact }
                    }
                }
            }
            for app in systemApps {
                for type in types {
                    for label in labels {
                        let partial = app.descendants(matching: type)
                            .matching(NSPredicate(format: "label CONTAINS[c] %@ AND NOT (label CONTAINS[c] 'No Results') AND NOT (label CONTAINS[c] 'Aucun')", label))
                            .firstMatch
                        if partial.exists { return partial }
                    }
                }
            }
            pause(0.4)
        } while Date() < deadline
        return nil
    }

    /// Taps the first matching element; when nothing matches, taps `fallback` (a point on screen) if given.
    @discardableResult
    private func tap(
        _ labels: [String],
        types: [XCUIElement.ElementType] = [.button, .menuItem, .cell],
        timeout: TimeInterval = 4,
        fallback: CGVector? = nil
    ) -> Bool {
        if let found = element(labels, types: types, timeout: timeout) {
            found.tap()
            return true
        }
        if let fallback {
            springboard.coordinate(withNormalizedOffset: fallback).tap()
        }
        return false
    }

    /// Flicks the widget pages of the gallery until the preview of one of `names` is on screen.
    /// The system labels each preview "Tessera, <widget name>". `height` is where the previews are, from 0 to 1.
    private func swipeToWidget(_ names: [String], height: CGFloat, maxSwipes: Int, prefix: String) -> XCUIElement? {
        let wanted = NSPredicate(format: "label IN %@", names.map { "Tessera, \($0)" } as NSArray)
        for step in 0...maxSwipes {
            for app in systemApps {
                let preview = app.buttons.matching(wanted).firstMatch
                if preview.exists && preview.isHittable { return preview }
            }
            guard step < maxSwipes else { break }
            // A short press followed by a fast move pages the gallery; a long press would pick the widget up instead.
            let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: height))
            let end = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: height))
            start.press(forDuration: 0.01, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
            pause(0.7)
            if step % 10 == 9 { snapshot("\(prefix)-swipe-\(step + 1)") }
        }
        return nil
    }

    /// Launching the app once registers its widget extension with the system.
    private func launchTesseraOnce() {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotScreen", "home"]
        app.launch()
        pause(3)
        XCUIDevice.shared.press(.home)
        pause(2)
    }

    /// From the Home Screen to the Tessera page of the widget gallery.
    private func openTesseraGallery(_ prefix: String) {
        launchTesseraOnce()
        // A second press brings back the first page; its lower part is empty on a fresh simulator.
        XCUIDevice.shared.press(.home)
        pause(1.5)
        snapshot("\(prefix)-1-home-screen")

        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).press(forDuration: 1.8)
        pause(1.5)
        snapshot("\(prefix)-2-edit-mode", tree: true)

        // iOS 18 and later: "Edit" then "Add Widget". iOS 17: a "+" button labelled "Add Widget".
        // A press that lands on an icon opens its menu first: "Edit Home Screen", then "Edit".
        for _ in 0..<2 where element(["Add Widget", "Ajouter un widget"], timeout: 1) == nil {
            tap(["Edit", "Modifier"], fallback: CGVector(dx: 0.1, dy: 0.04))
            pause(1.2)
        }
        snapshot("\(prefix)-3-edit-menu", tree: true)

        XCTAssertTrue(tap(["Add Widget", "Ajouter un widget", "Ajouter des widgets"]), "The Add Widget button was not found")
        pause(2.5)
        snapshot("\(prefix)-4-gallery", tree: true)

        let field = springboard.searchFields.firstMatch
        if field.waitForExistence(timeout: 4) {
            field.tap()
            field.typeText("Tessera")
            pause(2)
        }
        snapshot("\(prefix)-5-search", tree: true)

        let listed = tap(["Tessera"], types: [.cell, .button, .staticText, .other], timeout: 5)
        XCTAssertTrue(listed, "Tessera is not listed in the widget gallery")
        pause(2.5)
        snapshot("\(prefix)-6-tessera-widgets", tree: true)
    }

    /// Adds the widget shown in the gallery, leaves edit mode and waits for the first render.
    private func addShownWidget(_ prefix: String) {
        let added = tap(["Add Widget", "Ajouter le widget", "Ajouter un widget"], types: [.button])
        XCTAssertTrue(added, "The button that adds the Tessera widget was not found")
        pause(2.5)
        snapshot("\(prefix)-7-added")

        if !tap(["Done", "OK", "Terminé"], timeout: 2) {
            XCUIDevice.shared.press(.home)
        }
        pause(4)
        snapshot("\(prefix)-8-result", tree: true)
        // The first render of a new widget can take a while on a busy simulator.
        pause(30)
        snapshot("\(prefix)-9-rendered", tree: true)
    }

    // MARK: Home Screen

    /// The first widget of the gallery (Horloge, one of the original widgets).
    func testAddWidgetToHomeScreen() throws {
        openTesseraGallery("home")
        addShownWidget("home")
    }

    /// A V2 widget: the gallery is paged until the Nutrition widget is shown.
    /// Runs after the test above (alphabetical order), so the Home Screen ends with both widgets.
    func testAddWidgetToHomeScreenV2() throws {
        openTesseraGallery("home-v2")
        let found = swipeToWidget(["Nutrition"], height: 0.58, maxSwipes: 75, prefix: "home-v2")
        snapshot("home-v2-6b-nutrition", tree: true)
        XCTAssertNotNil(found, "The Nutrition widget was not found in the Tessera gallery")
        guard found != nil else { return }
        addShownWidget("home-v2")
    }

    // MARK: Lock Screen

    func testAddWidgetToLockScreen() throws {
        searchesPosterBoard = true
        launchTesseraOnce()
        let lock = NSSelectorFromString("pressLockButton")
        guard XCUIDevice.shared.responds(to: lock) else {
            throw XCTSkip("This simulator cannot lock the screen from a test")
        }
        _ = XCUIDevice.shared.perform(lock)
        pause(2)
        XCUIDevice.shared.press(.home)
        pause(2)
        snapshot("lock-1-lock-screen")

        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.8)
        pause(2)
        snapshot("lock-2-wallpapers", tree: true)

        tap(["Customize", "Personnaliser"], timeout: 4, fallback: CGVector(dx: 0.5, dy: 0.93))
        pause(2.5)
        snapshot("lock-3-choose-screen", tree: true)

        // Since iOS 17 the system asks which screen to customize: the Lock Screen is on the left.
        tap(["Lock Screen", "Écran verrouillé", "Écran de verrouillage"], types: [.button, .cell, .other, .staticText], timeout: 3, fallback: CGVector(dx: 0.28, dy: 0.5))
        pause(2.5)
        snapshot("lock-4-editor", tree: true)

        tap(["Add Widgets", "Ajouter des widgets", "Add Widget", "Ajouter un widget"], types: [.button, .other], timeout: 3, fallback: CGVector(dx: 0.5, dy: 0.32))
        pause(2.5)
        snapshot("lock-5-widget-sheet", tree: true)

        var offered = tap(["Tessera"], types: [.cell, .button, .staticText, .other], timeout: 3)
        if !offered {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
                .press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            pause(1.5)
            offered = tap(["Tessera"], types: [.cell, .button, .staticText, .other], timeout: 3)
        }
        XCTAssertTrue(offered, "Tessera is not offered for the Lock Screen")
        pause(2.5)
        snapshot("lock-6-tessera-widgets", tree: true)

        // An original widget first (the sheet stays open after a tap)…
        let names = ["Progression", "Compte à rebours", "Météo", "Tâches", "Focus", "Hydratation", "À venir", "Crypto"]
        tap(names, types: [.button, .cell, .other], timeout: 3, fallback: CGVector(dx: 0.3, dy: 0.72))
        pause(2.5)
        snapshot("lock-7-added", tree: true)

        // …then a V2 widget, a few pages further.
        let v2 = swipeToWidget(lockScreenV2Names, height: 0.71, maxSwipes: 25, prefix: "lock-v2")
        XCTAssertNotNil(v2, "No V2 widget was found in the Lock Screen gallery")
        v2?.tap()
        pause(2.5)
        snapshot("lock-7b-v2-added", tree: true)

        // Close the widget page, then the widget list, then save the Lock Screen.
        tap(["Close", "Fermer"], timeout: 2)
        pause(1.5)
        if !tap(["Close", "Fermer"], timeout: 2) {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        }
        pause(1.5)
        snapshot("lock-8-editor-with-widget", tree: true)
        tap(["Done", "OK", "Terminé"], timeout: 3)
        pause(3)
        snapshot("lock-9-result", tree: true)
        // Back on the wallpaper gallery: a tap on the current wallpaper returns to the Lock Screen.
        if element(["Customize", "Personnaliser"], timeout: 2) != nil {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
            pause(3)
        }
        snapshot("lock-10-lock-screen")
        pause(25)
        snapshot("lock-11-rendered", tree: true)
    }
}
