import XCTest

/// The Widget Studio as a person uses it: a theme, a palette undone and redone, the main color, a border,
/// a saved look, then the widget saved and reopened with everything kept. And the way into it: Créer opens on a
/// start screen, the Studio is pushed on it, and « + » joins widgets into one.
final class StudioUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        app?.terminate()
    }

    private func launch(_ arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_CA"] + arguments
        app.launch()
    }

    private func snapshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "studio-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Taps a button by identifier, scrolling the Studio's settings (below the preview) until it's reachable.
    private func tapButton(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        reveal(identifier, file: file, line: line).tap()
    }

    /// Scrolls the Studio's settings until the button is on screen (the settings go back to the top each time
    /// another widget is chosen) and returns it. A choice below the fold keeps its old accessibility state.
    @discardableResult
    private func reveal(_ identifier: String, bottomMargin: CGFloat = 125, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        reveal(element: app.buttons[identifier].firstMatch, named: identifier, bottomMargin: bottomMargin, file: file, line: line)
    }

    /// The same for any element (the name field): scrolled to as a person would, then left to settle.
    @discardableResult
    private func reveal(element button: XCUIElement, named identifier: String, bottomMargin: CGFloat = 125,
                        file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let height = app.frame.height > 200 ? app.frame.height : 874
        if !button.waitForExistence(timeout: 8) {
            // A lazy grid lets go of what scrolled away (the main colors once the palettes below are reached):
            // look above first, then below.
            var tries = 0
            while !button.exists && tries < 12 {
                drag(in: scrollArea(height: height, bottomMargin: bottomMargin), up: tries >= 4)
                tries += 1
            }
        }
        XCTAssertTrue(button.waitForExistence(timeout: 4), "Bouton « \(identifier) » introuvable", file: file, line: line)
        // Reachable: on screen and not under the save bar at the bottom (the toolbar arrows are at the top).
        func reachable() -> Bool {
            button.exists && button.isHittable && (button.frame.maxY < height - bottomMargin || button.frame.maxY < 140)
        }
        var swipes = 0
        var lastUp = true
        while !reachable() && swipes < 12 {
            // A short drag without momentum inside the settings (in the Studio they sit under the preview, the
            // chapters and the row of tools; a drag on that row would scroll nothing): up to reach what is below,
            // down to come back to what scrolled away above.
            let area = scrollArea(height: height, bottomMargin: bottomMargin)
            let up: Bool
            if button.exists {
                let frame = button.frame
                up = frame.maxY > area.maxY ? true : (frame.minY < area.minY ? false : frame.midY > area.midY)
            } else {
                // A lazy list let it go once it scrolled past: come back the other way.
                up = !lastUp
            }
            drag(in: area, up: up)
            lastUp = up
            swipes += 1
            // A drag in the settings raises them (a spring): touch the button where it ends up, not on its way.
            settle(button)
        }
        return button
    }

    /// Waits until the element stops moving (the settings rising or coming back down), at most about 3 seconds.
    private func settle(_ element: XCUIElement) {
        var last = element.exists ? element.frame : .zero
        for _ in 0..<12 {
            Thread.sleep(forTimeInterval: 0.25)
            let frame = element.exists ? element.frame : .zero
            if frame == last { return }
            last = frame
        }
    }

    /// A short drag without momentum inside an area: up brings what is below, down what is above.
    private func drag(in area: CGRect, up: Bool) {
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let low = origin.withOffset(CGVector(dx: area.midX, dy: area.minY + area.height * 0.7))
        let high = origin.withOffset(CGVector(dx: area.midX, dy: area.minY + area.height * 0.3))
        (up ? low : high).press(forDuration: 0.05, thenDragTo: up ? high : low, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    /// The visible part of the page that scrolls: the tallest scroll view, above the save bar.
    private func scrollArea(height: CGFloat, bottomMargin: CGFloat) -> CGRect {
        let width = app.frame.width > 100 ? app.frame.width : 402
        var views = app.scrollViews.allElementsBoundByIndex.filter { $0.frame.height > 120 && $0.frame.width > 200 }
        // In the Studio the settings are under the panel's handle; the screen it was opened over (Home, Créer)
        // also scrolls, across the whole window: only the scroll views below the handle count.
        let handle = app.buttons["studio-panel-handle"]
        if handle.exists {
            let settings = views.filter { $0.frame.minY >= handle.frame.maxY - 4 }
            if !settings.isEmpty { views = settings }
        }
        guard let tallest = views.max(by: { $0.frame.height < $1.frame.height }) else {
            return CGRect(x: 0, y: height * 0.5, width: width, height: height * 0.3)
        }
        let top = max(tallest.frame.minY, 0)
        let bottom = min(tallest.frame.maxY, height - bottomMargin)
        return CGRect(x: max(tallest.frame.minX, 0), y: top, width: min(tallest.frame.width, width), height: max(bottom - top, 80))
    }

    // MARK: Helpers of the chapters and of the widgets inside

    /// Any element (a container, a button…) by identifier.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Waits until a condition holds (the Studio animates its panels).
    private func waitUntil(timeout: TimeInterval = 8, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }

    /// The widgets inside the widget, listed in « Contenu » (« part-<kind> »): not the buttons of a widget's panel
    /// (« part-close », « part-replace », « part-remove ») nor the move buttons of « Disposition ».
    private func partRows() -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'part-' AND NOT (identifier IN %@) AND NOT (identifier BEGINSWITH 'part-up-') AND NOT (identifier BEGINSWITH 'part-down-')",
            ["part-close", "part-replace", "part-remove"]
        ))
    }

    /// Opens a chapter of the Studio (« content », « layout », « style ») and waits for it to be the one selected.
    private func chapter(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let identifier = "studio-chapter-\(name)"
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "Chapitre « \(name) » introuvable", file: file, line: line)
        if !button.isSelected { button.tap() }
        XCTAssertTrue(waitForSelection(identifier), "Le chapitre \(name) ne s'ouvre pas", file: file, line: line)
    }

    /// In the choice of a widget to add, taps the first one that can be added now: not faded (a faded one says why
    /// in its accessibility value) and not a Premium one.
    private func tapFirstAddable(prefix: String = "add-kind-", file: StaticString = #filePath, line: UInt = #line) {
        let tiles = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10), "Le choix d'un widget à ajouter ne s'ouvre pas", file: file, line: line)
        let addable = tiles.allElementsBoundByIndex.filter { (($0.value as? String) ?? "").isEmpty }
        guard let pick = addable.first else {
            return XCTFail("Aucun widget ne peut être ajouté (tous estompés ou Premium)", file: file, line: line)
        }
        // The save bar sits above the tab bar in Créer: more room under the tile.
        reveal(pick.identifier, bottomMargin: 210, file: file, line: line).tap()
    }

    /// Back to the previous page of the navigation stack (Créer pushes its Studio on the start screen).
    private func goBack(file: StaticString = #filePath, line: UInt = #line) {
        let back = app.navigationBars.buttons.allElementsBoundByIndex.first {
            $0.isHittable && $0.frame.minX < 60 && $0.label != "Annuler"
        }
        XCTAssertNotNil(back, "Bouton retour absent", file: file, line: line)
        back?.tap()
    }

    // MARK: Créer

    /// Créer starts with the size (« taille d'abord »): Petit, Moyen, Grand and a link to the Lock Screen, nothing else.
    func testCreateOpensOnTheSizes() {
        launch(["-screenshotScreen", "spaces"])
        XCTAssertTrue(app.buttons["create-size-medium"].waitForExistence(timeout: 15), "Créer n'ouvre pas sur le choix de la taille")
        XCTAssertTrue(element("create-start").exists, "La page des tailles n'est pas identifiée")
        for identifier in ["create-size-small", "create-size-large", "create-lock"] {
            XCTAssertTrue(app.buttons[identifier].exists, "« \(identifier) » absent de la page des tailles")
        }
        // Not the Studio: no chapters, no « Changer de widget ».
        XCTAssertFalse(app.buttons["studio-chapter-content"].exists, "Créer ne doit pas s'ouvrir sur le Studio")
        XCTAssertFalse(app.buttons["create-change"].exists)
        snapshot("create-start")
    }

    /// Size, then category, then the widgets: goes to the page of the widgets of a category.
    private func openPicks(size: String, category: String, file: StaticString = #filePath, line: UInt = #line) {
        let sizeCard = app.buttons["create-size-\(size)"]
        XCTAssertTrue(sizeCard.waitForExistence(timeout: 15), "Taille « \(size) » absente", file: file, line: line)
        sizeCard.tap()
        reveal("create-category-\(category)", file: file, line: line).tap()
        XCTAssertTrue(element("create-places").waitForExistence(timeout: 8), "La page des widgets ne s'ouvre pas", file: file, line: line)
    }

    /// Moyen: the first widget fills the widget, a second one combines them; the others are then refused (2 at most).
    /// « Personnaliser le widget » opens the Studio on ONE widget with the two inside; back returns to the picks.
    func testMediumPicksTwoWidgetsIntoOneWidget() {
        launch(["-screenshotScreen", "spaces"])
        openPicks(size: "medium", category: "space-fitness")
        let go = app.buttons["create-pick-go"]
        XCTAssertTrue(go.exists, "« Personnaliser le widget » absent en Moyen")
        XCTAssertFalse(go.isEnabled, "Rien de choisi : pas encore de widget à personnaliser")
        reveal("create-pick-nextSet", bottomMargin: 210).tap()
        XCTAssertTrue(waitUntil { go.isEnabled }, "Un seul widget en Moyen fait déjà un widget (sa version moyenne)")
        reveal("create-pick-trainingStreak", bottomMargin: 210).tap()
        XCTAssertTrue(waitUntil { self.element("create-places").label.contains("Combiné") }, "Deux widgets : « Combiné · 2 widgets »")
        XCTAssertFalse(app.buttons["create-pick-todaysWorkout"].isEnabled, "Un 3e widget est refusé en Moyen (2 au plus)")
        snapshot("create-pick-medium")
        go.tap()
        XCTAssertTrue(app.buttons["studio-chapter-content"].waitForExistence(timeout: 10), "« Personnaliser le widget » n'ouvre pas le Studio")
        XCTAssertTrue(waitUntil { partRows().count == 2 }, "Le Studio n'a pas un seul widget avec les 2 dedans (lignes : \(partRows().count))")
        goBack()
        XCTAssertTrue(go.waitForExistence(timeout: 8), "Le retour ne ramène pas aux widgets choisis")
    }

    /// Petit: one widget; the touch opens the Studio at once. There, « + » still joins a second widget.
    func testSmallTouchOpensTheStudioThenAddAWidget() {
        launch(["-screenshotScreen", "spaces"])
        openPicks(size: "small", category: "space-fitness")
        XCTAssertFalse(app.buttons["create-pick-go"].exists, "Pas de bouton en Petit : le toucher ouvre le Studio")
        reveal("create-pick-nextSet", bottomMargin: 210).tap()
        XCTAssertTrue(app.buttons["studio-chapter-content"].waitForExistence(timeout: 10), "Le toucher en Petit n'ouvre pas le Studio")
        XCTAssertTrue(partRows().firstMatch.waitForExistence(timeout: 8), "« Dans ce widget » est vide")
        XCTAssertEqual(partRows().count, 1, "Petit : un seul widget")
        let add = app.buttons["stage-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 8), "Le « + » de la scène est absent")
        add.tap()
        tapFirstAddable()
        XCTAssertTrue(waitUntil { partRows().count == 2 }, "Le widget ajouté n'est pas dans le widget réuni (lignes : \(partRows().count))")
        XCTAssertTrue(app.buttons["stage-part-0"].exists && app.buttons["stage-part-1"].exists, "Une zone par widget sur la scène")
        snapshot("create-combine")
    }

    /// A save in Créer shows the add guide once the widget has flown away; closing it leaves Créer on the sizes.
    func testSavingInCreateShowsTheAddGuideThenStaysInCreate() {
        launch(["-screenshotScreen", "spaces"])
        openPicks(size: "small", category: "space-fitness")
        reveal("create-pick-nextSet", bottomMargin: 210).tap()
        XCTAssertTrue(app.buttons["create-change"].waitForExistence(timeout: 15), "« Petit » n'ouvre pas le Studio")
        let save = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Enregistrer")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 8), "Bouton Enregistrer absent")
        save.tap()
        let understood = app.buttons["Compris"]
        XCTAssertTrue(understood.waitForExistence(timeout: 15), "Le guide d'ajout n'apparaît pas après l'enregistrement")
        understood.tap()
        XCTAssertTrue(app.buttons["create-size-medium"].waitForExistence(timeout: 8), "Créer ne revient pas sur le choix de la taille")
        XCTAssertTrue(app.buttons["create-change"].waitForNonExistence(timeout: 8), "Le Studio est resté ouvert après l'enregistrement")
        snapshot("create-after-save")
    }

    /// « Changer de widget » goes back to the categories at the same size; another category's widget comes back to
    /// the Studio. No sheet that makes separate widgets.
    func testChangeWidgetGoesBackToTheCategories() {
        launch(["-screenshotScreen", "spaces"])
        openPicks(size: "medium", category: "space-fitness")
        reveal("create-pick-nextSet", bottomMargin: 210).tap()
        app.buttons["create-pick-go"].tap()
        let change = app.buttons["create-change"]
        XCTAssertTrue(change.waitForExistence(timeout: 10), "Le Studio n'est pas ouvert")
        change.tap()
        XCTAssertTrue(app.buttons["create-category-space-nutrition"].waitForExistence(timeout: 8) || reveal("create-category-space-nutrition").exists,
                      "« Changer de widget » ne ramène pas aux catégories")
        XCTAssertFalse(app.buttons["creator-continue"].exists, "Plus de feuille qui fait des widgets séparés")
        reveal("create-category-space-nutrition").tap()
        XCTAssertTrue(element("create-places").waitForExistence(timeout: 8), "La page des widgets ne s'ouvre pas")
        reveal("create-pick-caloriesLeft", bottomMargin: 210).tap()
        app.buttons["create-pick-go"].tap()
        XCTAssertTrue(app.buttons["studio-chapter-content"].waitForExistence(timeout: 10), "Le Studio n'est pas revenu")
        snapshot("create-atelier")
    }




    /// A ready combined widget (Nutrition, Moyen): « Disposition » reorders its widgets; a third widget makes it
    /// Grand with a note and « Annuler », which takes the addition back.
    func testCombinedWidgetLayoutAndThirdWidgetNote() {
        launch(["-screenshotScreen", "creator-nutrition"])
        XCTAssertTrue(app.buttons["studio-chapter-content"].waitForExistence(timeout: 15), "Le Studio ne s'ouvre pas sur la composition de l'espace")
        XCTAssertTrue(waitUntil { partRows().count == 2 }, "La composition « Pour toi » réunit deux widgets (lignes : \(partRows().count))")
        XCTAssertTrue(app.buttons["part-caloriesLeft"].exists)

        // « Suivant › » leads to « Disposition ».
        let next = app.buttons["studio-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 8), "« Suivant » absent")
        next.tap()
        XCTAssertTrue(waitForSelection("studio-chapter-layout"), "« Suivant » n'ouvre pas « Disposition »")
        let other = app.buttons["layout-plan-1"]
        XCTAssertTrue(other.waitForExistence(timeout: 8), "Aucune autre disposition proposée")
        let firstBefore = app.buttons["stage-part-0"].label
        let secondBefore = app.buttons["stage-part-1"].label
        XCTAssertNotEqual(firstBefore, secondBefore)
        other.tap()
        XCTAssertTrue(waitUntil { app.buttons["stage-part-0"].label == secondBefore }, "La disposition choisie ne change pas l'ordre des widgets")
        XCTAssertEqual(app.buttons["stage-part-1"].label, firstBefore)
        snapshot("create-layout")

        // A third widget: the size grows, the note says so and offers to undo.
        let add = app.buttons["stage-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 8), "Le « + » de la scène est absent")
        add.tap()
        tapFirstAddable()
        XCTAssertTrue(element("combo-note").waitForExistence(timeout: 8), "Pas de bandeau quand le widget passe en Grand")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Passé en Grand")).firstMatch.exists, "Le bandeau ne dit pas que le widget passe en Grand")
        XCTAssertTrue(waitUntil { partRows().count == 3 }, "Le troisième widget n'est pas dans le widget (lignes : \(partRows().count))")
        snapshot("create-grand")
        let undo = app.buttons["combo-note-undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "« Annuler » absent du bandeau")
        undo.tap()
        XCTAssertTrue(waitUntil { partRows().count == 2 }, "« Annuler » ne retire pas le troisième widget (lignes : \(partRows().count))")
        XCTAssertTrue(element("combo-note").waitForNonExistence(timeout: 8), "Le bandeau reste après « Annuler »")
        // The order chosen before the addition is kept by the undo.
        XCTAssertEqual(app.buttons["stage-part-0"].label, secondBefore)
    }

    /// « Sur mon écran » shows the widget on a Home Screen; the back button returns to the Studio.
    func testOnMyScreenOpensAndComesBack() {
        launch(["-screenshotScreen", "studio-content"])
        let eye = app.buttons["studio-on-my-screen"]
        XCTAssertTrue(eye.waitForExistence(timeout: 15), "« Sur mon écran » absent de la scène")
        eye.tap()
        XCTAssertTrue(element("home-preview").waitForExistence(timeout: 8), "« Sur mon écran » ne s'ouvre pas")
        XCTAssertTrue(app.buttons["home-preview-save"].exists, "« Enregistrer le widget » absent de « Sur mon écran »")
        snapshot("on-my-screen")
        app.buttons["home-preview-back"].tap()
        XCTAssertTrue(app.buttons["home-preview-back"].waitForNonExistence(timeout: 8), "« Sur mon écran » ne se ferme pas")
        XCTAssertTrue(app.textFields["widget-name"].waitForExistence(timeout: 8), "Le Studio n'est pas revenu")
    }

    /// A setting changed or the settings scrolled: they rise over most of the screen and the widget shrinks above
    /// them, still in view. The handle, the small widget or a pull from their top brings them back down.
    func testSettingsRiseAndComeBackDown() {
        launch(["-screenshotScreen", "studio-content"])
        let handle = app.buttons["studio-panel-handle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 15), "La poignée des réglages est absente")
        XCTAssertEqual(handle.label, "Agrandir les réglages", "Le Studio s'ouvre réglages repliés, grand widget")
        let widget = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Aperçu du widget")).firstMatch
        XCTAssertTrue(widget.waitForExistence(timeout: 8), "L'aperçu du widget est absent")
        settle(handle)
        let large = widget.frame.height
        let height = app.frame.height > 200 ? app.frame.height : 874

        // A setting changed: the settings rise, the widget stays on screen, smaller.
        section("theme")
        settle(handle)
        XCTAssertEqual(handle.label, "Agrandir les réglages", "Ouvrir « Style » ne doit pas faire monter les réglages")
        // Measured in the same chapter as the raised settings: « Style » adds its row of tools above them.
        let lowered = scrollArea(height: height, bottomMargin: 125)
        tapButton("preset-midnight")
        XCTAssertTrue(waitUntil { handle.label == "Agrandir l'aperçu" }, "Les réglages ne montent pas quand on change un réglage")
        XCTAssertTrue(waitUntil { widget.frame.height < large * 0.8 }, "Le widget ne rapetisse pas quand les réglages montent")
        // The settings rise with a spring: measured where they end up, not on their way.
        settle(handle)
        XCTAssertTrue(widget.frame.minY > 0 && widget.frame.height > 40, "Le widget n'est plus visible quand les réglages montent")
        XCTAssertGreaterThan(scrollArea(height: height, bottomMargin: 125).height, lowered.height + 60, "Les réglages ne prennent pas plus de place")
        snapshot("panel-raised")

        // The handle brings the large widget back.
        handle.tap()
        XCTAssertTrue(waitUntil { handle.label == "Agrandir les réglages" }, "La poignée ne redescend pas les réglages")
        XCTAssertTrue(waitUntil { widget.frame.height > large * 0.95 }, "Le widget ne reprend pas sa taille")
        settle(handle)

        // Scrolled down, the settings rise; pulled down from their top, they come back down.
        drag(in: scrollArea(height: height, bottomMargin: 125), up: true)
        XCTAssertTrue(waitUntil { handle.label == "Agrandir l'aperçu" }, "Les réglages ne montent pas quand on les fait défiler")
        settle(handle)
        // Opened from the Store or Home, the Studio is a sheet: pulled at their top, iOS moves the sheet, not the
        // settings (run 4a5245b: content at its top, still raised after a 330-point pull). The app follows the
        // finger on the settings instead.
        var pulls = 0
        while handle.label != "Agrandir les réglages" && pulls < 3 {
            drag(in: scrollArea(height: height, bottomMargin: 125), up: false)
            pulls += 1
            settle(handle)
        }
        XCTAssertEqual(handle.label, "Agrandir les réglages", "Tirés vers le bas depuis leur haut, les réglages ne redescendent pas (\(pulls) tirages)")
        XCTAssertTrue(waitUntil { widget.frame.height > large * 0.95 }, "Le widget ne reprend pas sa taille")
    }




    // MARK: Chapters and tools

    /// The tools of « Style » (the row under the chapters): « Taille » and « Contenu » are in the chapter « Contenu ».
    private static let styleTools = ["theme", "style", "colors", "background", "border", "chart", "density", "myStyles"]

    /// The tools are in a horizontal bar that centers the tool chosen: going one tool at a time, the next one is
    /// always on screen. Opens the chapter « Style » first.
    private func section(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let target = Self.styleTools.firstIndex(of: name) else { return XCTFail("Section \(name)", file: file, line: line) }
        chapter("style", file: file, line: line)
        XCTAssertTrue(app.buttons["studio-\(name)"].waitForExistence(timeout: 8), "Section « \(name) » introuvable", file: file, line: line)
        var index = Self.styleTools.firstIndex { app.buttons["studio-\($0)"].isSelected } ?? 0
        while index != target {
            index += target > index ? 1 : -1
            let identifier = "studio-\(Self.styleTools[index])"
            app.buttons[identifier].firstMatch.tap()
            // A chip at the edge of the bar can miss its first tap while the bar is still moving.
            if !waitForSelection(identifier) { app.buttons[identifier].firstMatch.tap() }
            XCTAssertTrue(waitForSelection(identifier), "La section \(Self.styleTools[index]) ne s'ouvre pas", file: file, line: line)
        }
    }

    func testTheStudioChangesTheWidgetAndKeepsItAll() {
        launch(["-screenshotScreen", "studio-content"])
        let name = app.textFields["widget-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15), "Le Studio ne s'est pas ouvert")
        // The name is below the screen at first: scrolled to as a person would (the settings rise), then touched
        // where it ends up. A direct tap scrolled it itself and landed where the field was before the rise.
        reveal(element: name, named: "widget-name").tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + "Studio test\n")

        section("theme")
        tapButton("preset-midnight")
        snapshot("theme")

        // A palette changes every color; the arrows take it back and bring it again.
        section("colors")
        tapButton("palette-ocean")
        XCTAssertTrue(waitForSelection("palette-ocean"), "La palette choisie n'est pas sélectionnée")
        snapshot("palette")
        tapButton("studio-undo")
        XCTAssertTrue(waitForSelection("palette-ocean", selected: false), "Retour en arrière n'a pas annulé la palette")
        tapButton("studio-redo")
        XCTAssertTrue(waitForSelection("palette-ocean"), "Retour en avant n'a pas rétabli la palette")
        // The main color repaints the whole widget, palette included.
        tapButton("main-FF6B57")
        XCTAssertTrue(waitForSelection("main-FF6B57"), "La couleur principale n'est pas sélectionnée")
        XCTAssertTrue(waitForSelection("palette-ocean", selected: false), "La couleur principale remplace la palette")
        snapshot("main-color")
        tapButton("studio-undo")
        XCTAssertTrue(waitForSelection("palette-ocean"), "Retour en arrière rend la palette")

        section("border")
        tapButton("border-dashed")
        XCTAssertTrue(waitForSelection("border-dashed"), "La bordure choisie n'est pas sélectionnée")

        section("myStyles")
        let styleName = app.textFields["style-name"]
        XCTAssertTrue(styleName.waitForExistence(timeout: 5))
        styleName.tap()
        styleName.typeText("Nuit test\n")
        tapButton("style-save")
        XCTAssertTrue(app.buttons["style-apply-Nuit test"].waitForExistence(timeout: 5), "Le style enregistré apparaît dans Mes styles")
        snapshot("my-styles")

        // The save bar stays at the bottom, always in reach.
        app.buttons["Enregistrer le widget"].firstMatch.tap()
        XCTAssertTrue(waitForDisappearance(name), "Le Studio se ferme une fois le widget enregistré")
        XCTAssertEqual(app.state, .runningForeground)

        // Reopened from « Mes widgets »: every setting is still there.
        app.terminate()
        launch(["-screenshotScreen", "mywidgets"])
        let edit = app.buttons["carousel-edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15), "Mes widgets absent")
        XCTAssertTrue(app.staticTexts["Studio test"].waitForExistence(timeout: 5), "Le widget enregistré est en tête de Mes widgets")
        edit.tap()
        XCTAssertTrue(app.textFields["widget-name"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["widget-name"].value as? String, "Studio test")
        section("colors")
        XCTAssertTrue(app.buttons["palette-ocean"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForSelection("palette-ocean"), "La palette est gardée")
        section("border")
        XCTAssertTrue(app.buttons["border-dashed"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForSelection("border-dashed"), "La bordure est gardée")
        section("myStyles")
        XCTAssertTrue(app.buttons["style-apply-Nuit test"].waitForExistence(timeout: 5), "Mes styles sont gardés")
        snapshot("reopened")
    }

    func testEverySectionOpens() {
        launch(["-screenshotScreen", "studio-content"])
        XCTAssertTrue(app.textFields["widget-name"].waitForExistence(timeout: 15))
        // « Contenu » holds the size and the content, and the widgets inside.
        XCTAssertTrue(waitForSelection("studio-chapter-content"), "Le Studio s'ouvre sur « Contenu »")
        XCTAssertTrue(element("studio-size").exists, "La taille est dans « Contenu »")
        XCTAssertTrue(element("studio-content").exists, "Le contenu est dans « Contenu »")
        // « Style »: every tool opens; « Taille » and « Contenu » are no longer tools of the row.
        for name in Self.styleTools {
            section(name)
            XCTAssertTrue(app.buttons["studio-\(name)"].isSelected, "La section \(name) ne s'ouvre pas")
            XCTAssertEqual(app.state, .runningForeground, "Section \(name)")
        }
        XCTAssertFalse(app.buttons["studio-size"].exists, "« Taille » n'est plus un outil de « Style »")
        XCTAssertFalse(app.buttons["studio-content"].exists, "« Contenu » n'est plus un outil de « Style »")
        // « Disposition »: a widget alone has nothing to lay out, and offers to add one.
        chapter("layout")
        XCTAssertTrue(app.buttons["layout-add"].waitForExistence(timeout: 8), "« Disposition » d'un widget seul propose d'ajouter un widget")
        // A chapter already seen says « Fait »: it doesn't pass for the chapter open (its check mark is hidden).
        let seen = app.buttons["studio-chapter-content"]
        XCTAssertFalse(seen.isSelected, "Un chapitre déjà vu passe pour le chapitre ouvert")
        XCTAssertEqual(seen.value as? String, "Fait", "Un chapitre déjà vu ne dit pas « Fait »")
        chapter("content")
        XCTAssertTrue(element("studio-size").waitForExistence(timeout: 8))
        // Only what the person asked to keep: no shape, text, icons, layout or depth sections.
        for gone in ["themes", "depth", "shape", "text", "icons", "layout"] {
            XCTAssertFalse(app.buttons["studio-\(gone)"].exists, "La section \(gone) ne devrait plus exister")
        }
    }

    /// Widgets made together (a creation, a pack) are edited one after the other and share their look.
    func testWidgetsMadeTogetherShareTheirLook() {
        launch(["-screenshotScreen", "studio-multi"])
        let first = app.buttons["studio-widget-1"]
        let second = app.buttons["studio-widget-2"]
        XCTAssertTrue(second.waitForExistence(timeout: 15), "Le Studio n'a pas ouvert les widgets créés ensemble")
        XCTAssertTrue(app.buttons["studio-share-look"].isSelected, "Des widgets créés ensemble partagent leur style")
        // The request opens on « Couleurs »: the chapter « Style », on that tool.
        tapButton("palette-neon")
        XCTAssertTrue(waitForSelection("palette-neon"), "La palette choisie n'est pas sélectionnée")
        second.tap()
        XCTAssertTrue(waitForSelection("studio-widget-2"), "Le deuxième widget ne s'ouvre pas")
        XCTAssertTrue(waitForSelection("palette-neon"), "La palette est passée au deuxième widget")
        snapshot("multi")
        // Undone for all of them at once.
        tapButton("studio-undo")
        // The settings are back at the top after choosing the second widget: the palette is below the fold,
        // so it is brought on screen before its state is read.
        reveal("palette-neon")
        if !waitForSelection("palette-neon", selected: false) {
            let diagnostic = XCTAttachment(string: app.debugDescription)
            diagnostic.name = "diagnostic-undo-palette"
            diagnostic.lifetime = .keepAlways
            add(diagnostic)
            snapshot("undo-palette-failed")
        }
        XCTAssertTrue(waitForSelection("palette-neon", selected: false), "Retour en arrière n'a pas annulé la palette")
        first.tap()
        XCTAssertTrue(waitForSelection("studio-widget-1"))
        reveal("palette-neon")
        XCTAssertTrue(waitForSelection("palette-neon", selected: false), "Retour en arrière vaut pour tous les widgets")
        XCTAssertTrue(app.buttons["Enregistrer les 3 widgets"].exists, "Les widgets s'enregistrent ensemble")
    }

    /// A widget without a chart has no « Graphique » section.
    func testTheChartSectionOnlyShowsWithAChart() {
        launch(["-screenshotScreen", "studio-note"])
        // « studio-note » opens on « Contenu »: the tools are in the chapter « Style ».
        XCTAssertTrue(app.buttons["studio-chapter-style"].waitForExistence(timeout: 15))
        chapter("style")
        XCTAssertTrue(app.buttons["studio-colors"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["studio-chart"].exists, "Une note n'a pas de graphique")
    }

    /// Waits for a choice to show as selected, or not (the state is updated with an animation).
    private func waitForSelection(_ identifier: String, selected: Bool = true, timeout: TimeInterval = 4) -> Bool {
        let predicate = NSPredicate(format: "isSelected == %@", NSNumber(value: selected))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.buttons[identifier].firstMatch)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
