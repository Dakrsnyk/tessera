import XCTest
@testable import Tessera

/// « Mon Quotidien » complete from the first launch: every category shows, as an empty dotted card
/// until the person gives data (never a made-up figure), and what they hide, reorder or resize
/// is kept by the same ids whether a card is empty or filled.
@MainActor
final class DailyHomeTests: XCTestCase {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func temporaryModel(_ directory: URL? = nil) -> AppModel {
        AppModel(store: SharedStore(directory: directory ?? temporaryDirectory()))
    }

    /// Wednesday 30 September 2026 at the given hour.
    private func wednesday(_ hour: Int) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: hour))!
    }

    private func ids(_ tiles: [DailyBrief.Tile]) -> [String] { tiles.map(\.id) }

    private func isInvitation(_ tile: DailyBrief.Tile) -> Bool {
        if case .empty = tile { return true }
        return false
    }

    /// What Home builds from an input (the pure part of `DailyCategories.home`).
    private func home(_ input: DailyBrief.Input, captions: [DailyBrief.Category: String] = [:]) -> [DailyBrief.Tile] {
        DailyBrief.completing(DailyBrief.tiles(input), weather: input.weather, appCaptions: captions)
    }

    private var allIDs: [String] { DailyBrief.Category.allCases.map(\.tileID) }

    // MARK: Profiles

    private func emptyInput() -> DailyBrief.Input { DailyBrief.Input(now: wednesday(9)) }

    private func partialInput() -> DailyBrief.Input {
        var input = DailyBrief.Input(now: wednesday(9))
        input.profile.provided = [.kcalTarget]
        input.nutrition.goals.kcal = 2_400
        input.content.habits = [Habit(name: "Lire", symbol: "book", colorHex: "7FA33A")]
        return input
    }

    private let captions: [DailyBrief.Category: String] = [.business: "1 000 $ ce mois", .travel: "Rome · J-12", .car: "420 km d'autonomie"]

    private func completeInput() -> DailyBrief.Input {
        var input = DailyBrief.Input(now: wednesday(9))
        input.profile.provided = [.kcalTarget]
        input.nutrition.goals.kcal = 2_400
        input.fitness.routines = [Routine(name: "Jambes", exercises: [ExerciseTemplate(name: "Squat", sets: 2, reps: 8, weight: 80)], weekdays: [3])]
        let course = Course(name: "Mathématiques")
        input.student.courses = [course]
        input.student.slots = [ClassSlot(courseID: course.id, weekday: 3, startMinute: 14 * 60, endMinute: 15 * 60 + 30, room: "B-204")]
        input.student.exams = [Exam(title: "Chimie", date: wednesday(16), room: "A-110")]
        input.content.habits = [Habit(name: "Lire", symbol: "book", colorHex: "7FA33A")]
        input.budget.expenses = [Expense(amount: 12, categoryID: nil, date: input.now)]
        input.productivity.addQuickTask("Appeler", on: input.now)
        input.steps = 4_000
        input.weather = SampleData.weather(now: input.now)
        return input
    }

    func testEmptyProfileShowsEveryCategoryAsAnInvitationAndNothingMadeUp() {
        let tiles = home(emptyInput())
        XCTAssertEqual(ids(tiles), allIDs, "Every category, in the default order")
        XCTAssertTrue(tiles.allSatisfy(isInvitation), "No data: only empty cards, never a figure")
        for category in DailyBrief.Category.allCases {
            XCTAssertFalse(category.title.isEmpty)
            XCTAssertFalse(category.invitation.isEmpty, "\(category) says what to give")
        }
        XCTAssertEqual(Set(DailyBrief.Category.allCases), [.nutrition, .workout, .planning, .habits, .budget, .priorities,
                                                           .reminders, .steps, .weather, .business, .travel, .car])
        // The old short list of invitations (from the interests) gives way to the complete one.
        var interested = emptyInput()
        interested.interests = [.nutrition, .budget, .fitness]
        XCTAssertEqual(ids(home(interested)), allIDs)
    }

    func testPartialProfilePersonalizesWhatIsFilledAndInvitesTheRest() {
        let tiles = home(partialInput())
        XCTAssertEqual(Set(ids(tiles)), Set(allIDs), "Same categories as before: nothing added, nothing lost")
        XCTAssertEqual(tiles.count, allIDs.count, "One card for each category")
        let filled = tiles.filter { !isInvitation($0) }
        XCTAssertEqual(Set(ids(filled)), ["nutrition", "habits"])
        XCTAssertEqual(tiles.filter(isInvitation).count, allIDs.count - 2)
        XCTAssertTrue(ids(tiles).prefix(2).allSatisfy { ["nutrition", "habits"].contains($0) }, "The filled cards come first")
        XCTAssertFalse(ids(tiles).contains { $0.hasPrefix("invite-") })
    }

    func testCompleteProfileHasNoInvitation() {
        let tiles = home(completeInput(), captions: captions)
        XCTAssertFalse(tiles.contains(where: isInvitation), "Everything given: no dotted card")
        XCTAssertEqual(Set(ids(tiles)), Set(allIDs))
        XCTAssertEqual(tiles.count, allIDs.count)
        XCTAssertTrue(tiles.contains(.miniApp("travel", caption: "Rome · J-12")), "Voyage, Auto and Business show their figure")
        XCTAssertTrue(ids(tiles).contains("weather"))
    }

    func testAnEmptyCardKeepsTheIdOfItsCardWithData() {
        let empty = Set(ids(home(emptyInput())))
        XCTAssertEqual(empty, Set(ids(home(completeInput(), captions: captions))), "Same ids empty or filled")
    }

    func testTheWeatherOnlyShowsWithRealWeather() {
        XCTAssertTrue(isInvitation(home(emptyInput()).first { $0.id == "weather" }!))
        var input = emptyInput()
        input.weather = SampleData.weather(now: input.now)
        guard case .weather? = home(input).first(where: { $0.id == "weather" }) else { return XCTFail("The weather card") }
    }

    func testAppModelBuildsTheCompleteHomeFromNothing() {
        let model = temporaryModel()
        let tiles = DailyCategories.home(model: model, now: wednesday(9), steps: nil)
        XCTAssertEqual(ids(tiles), allIDs)
        XCTAssertTrue(tiles.allSatisfy(isInvitation), "A new account: every card empty, nothing invented")
    }

    func testAppModelPersonalizesAfterTheFirstEntry() {
        let model = temporaryModel()
        model.setNutritionTargets(kcal: 2_200)
        let tiles = DailyCategories.home(model: model, now: wednesday(9), steps: nil)
        guard case let .nutrition(nutrition)? = tiles.first else { return XCTFail("The calorie target gives the nutrition card first") }
        XCTAssertEqual(nutrition.goals.kcal, 2_200)
        XCTAssertEqual(tiles.filter(isInvitation).count, allIDs.count - 1)
    }

    // MARK: Routes

    func testEveryEmptyCardOpensAMiniAppAndNeverAPagePerCategory() {
        let expected: [DailyBrief.Category: HomeRoute] = [
            .nutrition: .app(.nutrition), .workout: .app(.fitness), .planning: .app(.planning),
            .habits: .app(.planning), .budget: .app(.finances), .priorities: .app(.planning),
            .reminders: .app(.planning), .steps: .page(.fitnessActivity), .weather: .app(.weather),
            .business: .app(.business), .travel: .app(.travel), .car: .app(.car)
        ]
        XCTAssertEqual(Set(expected.keys), Set(DailyBrief.Category.allCases), "Every category has a destination")
        for category in DailyBrief.Category.allCases {
            XCTAssertEqual(category.route, expected[category], "\(category)")
            if case .infoArea = category.route { XCTFail("\(category) opens the old page « Tes données »") }
        }
    }

    func testEveryInfoAreaHasADestinationOutsideTheOldPage() {
        XCTAssertEqual(InfoArea.nutrition.homeRoute, .app(.nutrition))
        XCTAssertEqual(InfoArea.fitness.homeRoute, .app(.fitness))
        XCTAssertEqual(InfoArea.student.homeRoute, .app(.planning))
        XCTAssertEqual(InfoArea.habits.homeRoute, .app(.planning))
        XCTAssertEqual(InfoArea.productivity.homeRoute, .app(.planning))
        XCTAssertEqual(InfoArea.budget.homeRoute, .app(.finances))
        XCTAssertEqual(InfoArea.general.homeRoute, .info, "The general settings stay in « Mes informations »")
        for area in InfoArea.allCases {
            if case .infoArea = area.homeRoute { XCTFail("\(area) opens the old page") }
        }
    }

    func testTheFillInCardOpensTheFirstMiniAppWithSomethingMissing() {
        let model = temporaryModel()
        XCTAssertEqual(model.firstMissingInfoRoute, .info, "No interest: the general information")
        model.update(\.profile) { $0.interests = [.sport] }
        XCTAssertEqual(model.firstMissingInfoRoute, .app(.fitness))
    }

    func testTheFillInCardSkipsMiniAppsWhoseMissingItemsNoBlockShows() {
        // Only Planning's tasks and Finances' bills are missing: neither mini-app asks for them in « À remplir ».
        for app in [MiniApp.planning, .finances] {
            let missing = [DataItem.tasks, .bills]
            XCTAssertTrue(missing.allSatisfy { !app.toFillItems.contains($0) }, "\(app.rawValue)")
        }
        // The chosen mini-app always has a block for what is missing.
        let model = temporaryModel()
        model.update(\.profile) { $0.interests = [.sport, .nutrition, .budget, .productivity] }
        guard case let .app(app) = model.firstMissingInfoRoute else { return XCTFail("A mini-app with something to fill in") }
        XCTAssertTrue(model.completion.missing.contains { app.toFillItems.contains($0) && $0.area.miniApp == app })
    }

    func testTakingProductiviteOffHidesTheEmptyTopThree() {
        var settings = AppSettings()
        DailyCategories.setProductivity(shown: true, hasTasks: false, in: &settings)
        DailyCategories.setProductivity(shown: false, hasTasks: false, in: &settings)
        XCTAssertTrue(settings.dailyHidden.contains("priorities"))
        let tiles = DailyBrief.arranged(home(emptyInput()), order: settings.dailyOrder, hidden: settings.dailyHidden)
        XCTAssertFalse(ids(tiles).contains("priorities"), "No empty card behind an « off » switch")
        DailyCategories.setProductivity(shown: true, hasTasks: false, in: &settings)
        XCTAssertFalse(settings.dailyHidden.contains("priorities"))
    }

    // MARK: Hide, show, reorder

    func testHidingAnEmptyCategoryAndShowingItAgain() {
        let tiles = home(emptyInput())
        let hidden = DailyBrief.arranged(tiles, order: [], hidden: ["budget"])
        XCTAssertEqual(hidden.count, tiles.count - 1)
        XCTAssertFalse(ids(hidden).contains("budget"))
        let shown = DailyBrief.arranged(tiles, order: [], hidden: [])
        XCTAssertEqual(ids(shown), allIDs)
    }

    func testAHiddenCategoryStaysHiddenWhenItReceivesData() {
        let hidden = ["nutrition", "habits"]
        XCTAssertFalse(ids(DailyBrief.arranged(home(emptyInput()), order: [], hidden: hidden)).contains("nutrition"))
        let filled = DailyBrief.arranged(home(partialInput()), order: [], hidden: hidden)
        XCTAssertFalse(ids(filled).contains("nutrition"), "Data does not bring it back")
        XCTAssertFalse(ids(filled).contains("habits"))
        XCTAssertEqual(filled.count, allIDs.count - 2)
    }

    func testANewCategoryShowsAndAHiddenOneStaysHidden() {
        // Saved by an older version that only knew a few cards: the new ones come after, shown.
        let order = ["workout", "nutrition"]
        let arranged = DailyBrief.arranged(home(emptyInput()), order: order, hidden: ["budget"])
        XCTAssertEqual(ids(arranged).prefix(2), ["workout", "nutrition"])
        XCTAssertTrue(ids(arranged).contains("app-car"), "A category the settings never heard of shows")
        XCTAssertTrue(ids(arranged).contains("weather"))
        XCTAssertFalse(ids(arranged).contains("budget"), "A hidden one stays hidden")
        XCTAssertEqual(arranged.count, allIDs.count - 1)
    }

    func testReorderingMovesEmptyAndFilledCardsAlike() {
        let order = ["app-car", "habits", "nutrition"]
        let empty = DailyBrief.arranged(home(emptyInput()), order: order, hidden: [])
        XCTAssertEqual(ids(empty).prefix(3), ["app-car", "habits", "nutrition"])
        XCTAssertEqual(empty.count, allIDs.count)
        // The same order once habits and nutrition hold data: same places.
        let filled = DailyBrief.arranged(home(partialInput()), order: order, hidden: [])
        XCTAssertEqual(ids(filled).prefix(3), ["app-car", "habits", "nutrition"])
        // Moved back to the automatic order: the filled cards first, then the empty ones.
        XCTAssertEqual(ids(DailyBrief.arranged(home(emptyInput()), order: [], hidden: [])), allIDs)
    }

    func testTheCategoryTogglesOfTheEditorFollowTheCards() {
        var settings = AppSettings()
        let tiles = home(emptyInput())
        XCTAssertTrue(DailyCategories.isShown(.nutrition, available: tiles, settings: settings), "An empty card counts as shown")
        XCTAssertTrue(DailyCategories.isShown(.business, available: tiles, settings: settings))
        DailyCategories.set(.nutrition, shown: false, in: &settings)
        DailyCategories.set(.business, shown: false, in: &settings)
        XCTAssertFalse(DailyCategories.isShown(.nutrition, available: tiles, settings: settings))
        XCTAssertFalse(DailyCategories.isShown(.business, available: tiles, settings: settings))
        XCTAssertFalse(ids(DailyBrief.arranged(tiles, order: [], hidden: settings.dailyHidden)).contains("app-business"))
        DailyCategories.set(.business, shown: true, in: &settings)
        XCTAssertTrue(DailyCategories.isShown(.business, available: tiles, settings: settings))
        XCTAssertTrue(ids(DailyBrief.arranged(tiles, order: [], hidden: settings.dailyHidden)).contains("app-business"))
    }

    // MARK: Persistence

    func testLayoutSettingsRoundTrip() throws {
        var settings = AppSettings()
        settings.dailyOrder = ["car", "nutrition"]
        settings.dailyHidden = ["budget", "app-travel"]
        settings.dailyWide = ["habits": true, "steps": false]
        let data = try JSONEncoder().encode(settings)
        let back = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(back.dailyOrder, ["car", "nutrition"])
        XCTAssertEqual(back.dailyHidden, ["budget", "app-travel"])
        XCTAssertEqual(back.dailyWide, ["habits": true, "steps": false])
    }

    func testOldOrBrokenSettingsStillDecode() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(old.dailyOrder.isEmpty)
        XCTAssertTrue(old.dailyHidden.isEmpty, "Nothing hidden by default: every category shows")
        let broken = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"dailyHidden":["budget"],"dailyOrder":"oops","dailyWide":3}"#.utf8))
        XCTAssertEqual(broken.dailyHidden, ["budget"], "A field out of shape doesn't lose the others")
        XCTAssertTrue(broken.dailyOrder.isEmpty)
        XCTAssertTrue(broken.dailyWide.isEmpty)
    }

    func testTheLayoutSurvivesARelaunch() {
        let directory = temporaryDirectory()
        let model = temporaryModel(directory)
        model.updateSettings {
            $0.dailyOrder = ["steps", "nutrition"]
            $0.dailyHidden = ["budget"]
        }
        let relaunched = temporaryModel(directory)
        XCTAssertEqual(relaunched.settings.dailyOrder, ["steps", "nutrition"])
        XCTAssertEqual(relaunched.settings.dailyHidden, ["budget"])
        let tiles = DailyBrief.arranged(DailyCategories.home(model: relaunched, now: wednesday(9), steps: nil),
                                        order: relaunched.settings.dailyOrder, hidden: relaunched.settings.dailyHidden)
        XCTAssertEqual(ids(tiles).prefix(2), ["steps", "nutrition"])
        XCTAssertFalse(ids(tiles).contains("budget"))
        // Data arriving later doesn't bring the hidden card back.
        relaunched.update(\.budget) { $0.expenses = [Expense(amount: 5, categoryID: nil, date: wednesday(9))] }
        let after = DailyBrief.arranged(DailyCategories.home(model: relaunched, now: wednesday(9), steps: nil),
                                        order: relaunched.settings.dailyOrder, hidden: relaunched.settings.dailyHidden)
        XCTAssertFalse(ids(after).contains("budget"))
    }
}
