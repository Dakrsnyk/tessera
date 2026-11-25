import XCTest
@testable import Ardane

/// « Mon Quotidien » limited to what the person chose: the categories of their interests (empty dotted
/// cards until they give data, never a made-up figure), the ones with data and the ones they added with
/// the « + » at the bottom. What they remove, reorder or resize is kept by the same ids, whether a card
/// is empty or filled.
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
        // « À ne pas oublier » is always there: without any task, it holds only the quick add.
        if case let .reminders(items) = tile { return items.isEmpty }
        return false
    }

    /// What Home builds from an input and the settings (the pure part of `DailyCategories.home`).
    private func home(_ input: DailyBrief.Input, settings: AppSettings = AppSettings(),
                      captions: [DailyBrief.Category: String] = [:]) -> [DailyBrief.Tile] {
        DailyBrief.inDefaultOrder(DailyBrief.completing(DailyBrief.tiles(input), appCaptions: captions,
                                                        empty: DailyCategories.wanted(input: input, settings: settings)))
    }

    /// What is on screen: Home with what the person removed and the order they chose applied.
    private func onScreen(_ input: DailyBrief.Input, settings: AppSettings = AppSettings(),
                          captions: [DailyBrief.Category: String] = [:]) -> [DailyBrief.Tile] {
        DailyBrief.arranged(home(input, settings: settings, captions: captions), order: settings.dailyOrder, hidden: settings.dailyHidden)
    }

    /// Every card Mon Quotidien can show: the Top 3 and Auto are gone (PDG, 2026-11-25).
    private var allIDs: [String] { DailyDefaults.order.map(\.tileID) }

    /// The five cards every account has, even empty (PDG, 2026-11-17), in their fixed order.
    private let five = ["nutrition", "workout", "planning", "habits", "reminders"]

    /// Every card id in the fixed default order (what `arranged` gives without a hand order).
    private var orderedIDs: [String] { DailyDefaults.order.map(\.tileID) }

    /// Settings where the person added every category with the « + » (the complete Home of the first version).
    private var everything: AppSettings {
        var settings = AppSettings()
        for category in DailyBrief.Category.allCases { DailyCategories.add(category, in: &settings) }
        return settings
    }

    // MARK: Profiles

    private func emptyInput() -> DailyBrief.Input { DailyBrief.Input(now: wednesday(9)) }

    private func partialInput() -> DailyBrief.Input {
        var input = DailyBrief.Input(now: wednesday(9))
        input.profile.provided = [.kcalTarget]
        input.nutrition.goals.kcal = 2_400
        input.content.habits = [Habit(name: "Lire", symbol: "book", colorHex: "7FA33A")]
        return input
    }

    private let captions: [DailyBrief.Category: String] = [.business: "1 000 $ ce mois", .travel: "Rome · J-12", .car: "420 km d'autonomie",
                                                         .studies: "1 cours"]

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
        input.content.tasks = [TaskItem(title: "Appeler")]
        input.steps = 4_000
        return input
    }

    // MARK: What shows by default

    func testNoInterestAndNoDataShowsTheFiveDefaultCardsEmptyAndThePlusOffersTheRest() {
        let tiles = onScreen(emptyInput())
        XCTAssertEqual(ids(tiles), five, "Nothing chosen, nothing filled: the five cards of every account, all empty")
        XCTAssertTrue(tiles.allSatisfy(isInvitation), "Never a made-up figure")
        XCTAssertEqual(DailyCategories.addable(shown: tiles), [.studies, .budget, .steps, .business, .travel],
                       "The « + » offers the others, never the Top 3 nor Auto")
        XCTAssertEqual(tiles.last, .reminders([]), "No task: the card holds the quick add, nothing made up")
        for category in DailyBrief.Category.allCases {
            XCTAssertFalse(category.title.isEmpty)
            XCTAssertFalse(category.invitation.isEmpty, "\(category) says what to give")
        }
        XCTAssertEqual(Set(DailyBrief.Category.allCases), [.nutrition, .workout, .planning, .habits, .budget, .priorities,
                                                           .reminders, .steps, .business, .travel, .car, .studies])
    }

    func testTheInterestsOfTheFirstFormShowTheirEmptyCardsWithoutAnyCap() {
        var input = emptyInput()
        input.interests = [.budget, .nutrition, .fitness]
        let tiles = home(input)
        XCTAssertEqual(ids(tiles), five + ["budget"], "The five of every account and the interest, in the default order")
        XCTAssertTrue(tiles.allSatisfy(isInvitation), "No data: only empty cards")

        input.interests = [.student, .habits, .productivity, .business, .travel, .car, .investing, .markets, .life]
        XCTAssertEqual(ids(home(input)), five + ["app-studies", "app-business", "app-travel"],
                       "More than two at once; the spaces without a card add none; a student gets Études")
    }

    func testTheCardsWithDataAreAlwaysThereAndTheInterestsComeAfterThem() {
        let tiles = onScreen(partialInput())
        XCTAssertEqual(ids(tiles), five, "Data, no interest: the filled cards and the empty ones of every account")
        XCTAssertEqual(tiles.filter(isInvitation).count, 3, "Workout, Planning and « À ne pas oublier » are empty; Nutrition and Habits hold data")

        var input = partialInput()
        input.interests = [.fitness, .budget]
        let both = onScreen(input)
        XCTAssertEqual(ids(both), five + ["budget"], "The fixed order, filled or empty")
        XCTAssertEqual(both.filter(isInvitation).count, 4)
        XCTAssertFalse(ids(both).contains { $0.hasPrefix("invite-") })
    }

    func testCompleteProfileHasNoInvitationAndEveryCategory() {
        let tiles = home(completeInput(), captions: captions)
        XCTAssertFalse(tiles.contains(where: isInvitation), "Everything given: no dotted card")
        XCTAssertEqual(Set(ids(tiles)), Set(allIDs))
        XCTAssertEqual(tiles.count, allIDs.count)
        XCTAssertTrue(tiles.contains(.miniApp("travel", caption: "Rome · J-12")), "Voyage and Business show their figure")
        XCTAssertFalse(ids(tiles).contains("app-car"), "Auto is gone, even with a figure")
        XCTAssertTrue(DailyCategories.addable(shown: tiles).isEmpty, "Everything is there: no « + »")
    }

    func testAnEmptyCardKeepsTheIdOfItsCardWithData() {
        let empty = Set(ids(home(emptyInput(), settings: everything)))
        XCTAssertEqual(empty, Set(ids(home(completeInput(), settings: everything, captions: captions))), "Same ids empty or filled")
        XCTAssertEqual(empty, Set(allIDs))
    }

    func testTheRemovedWeatherLeavesNoCardAndOldEntriesAreIgnored() throws {
        XCTAssertFalse(allIDs.contains("weather"), "The weather is no longer a category of Mon Quotidien")
        // Saved by a version that still had the weather: its card, its « + » entry and its interest are ignored.
        let json = #"{"dailyOrder":["weather","nutrition"],"dailyHidden":["weather"],"dailyAdded":["cat-weather","weather","cat-steps"],"dailyCardPages":{"weather":1}}"#
        let old = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(DailyCategories.added(old), [.steps], "Only the categories that still exist")
        let tiles = onScreen(emptyInput(), settings: old)
        XCTAssertFalse(ids(tiles).contains("weather"))
        XCTAssertEqual(ids(tiles), five + ["steps"])
    }

    func testAppModelStartsWithNothingAndFollowsTheInterests() {
        let model = temporaryModel()
        // A new account has the five cards (PDG, 2026-11-17); Planning is the week table, empty: nothing invented.
        XCTAssertEqual(ids(DailyCategories.home(model: model, now: wednesday(9), steps: nil)), five,
                       "A new account without interests: the five default cards")
        model.update(\.profile) { $0.interests = [.sport, .nutrition] }
        let tiles = DailyCategories.home(model: model, now: wednesday(9), steps: nil)
        XCTAssertEqual(ids(tiles), five, "These interests are among the five: nothing more")
        XCTAssertTrue([0, 1, 3, 4].allSatisfy { isInvitation(tiles[$0]) }, "Nothing invented: empty cards")
        guard case let .planning(items) = tiles[2] else { return XCTFail("The schedule is the Planning card") }
        XCTAssertTrue(items.isEmpty, "Nothing planned: an empty week, no made-up item")
    }

    func testAppModelPersonalizesAfterTheFirstEntry() {
        let model = temporaryModel()
        model.setNutritionTargets(kcal: 2_200)
        let tiles = DailyCategories.home(model: model, now: wednesday(9), steps: nil)
        guard case let .nutrition(nutrition)? = tiles.first else { return XCTFail("The calorie target gives the nutrition card first") }
        XCTAssertEqual(nutrition.goals.kcal, 2_200)
        XCTAssertEqual(ids(tiles), five, "No interest: what is filled, and the others of every account")
    }

    /// The week's schedule is on Mon Quotidien for everyone (PDG, 2026-11-16): after the meals and the session, in
    /// place of a dotted Planning card, never twice, and off for good once the person removed it.
    func testTheWeekScheduleShowsForEveryone() {
        let nutrition = DailyBrief.Tile.empty(.nutrition)
        let workout = DailyBrief.Tile.empty(.workout)
        let habits = DailyBrief.Tile.empty(.habits)
        XCTAssertEqual(ids(DailyCategories.withWeekSchedule([])), ["planning"])
        XCTAssertEqual(ids(DailyCategories.withWeekSchedule([nutrition, habits, workout])), ["nutrition", "habits", "workout", "planning"],
                       "Right after the last of the meals and the session")
        XCTAssertEqual(ids(DailyCategories.withWeekSchedule([habits])), ["planning", "habits"], "First when neither is there")
        XCTAssertEqual(ids(DailyCategories.withWeekSchedule([nutrition, .empty(.planning)])), ["nutrition", "planning"],
                       "The week table replaces the dotted Planning card")
        let planned = DailyBrief.Tile.planning(items: [])
        XCTAssertEqual(ids(DailyCategories.withWeekSchedule([planned, nutrition])), ["planning", "nutrition"], "Already there: left where it is")
        let shown = DailyBrief.arranged(DailyCategories.withWeekSchedule([nutrition]), order: [], hidden: ["planning"])
        XCTAssertEqual(ids(shown), ["nutrition"], "Removed by the person, it stays off")
    }

    // MARK: The « + »

    func testAddingACategoryWithThePlusShowsItEmptyAndLeavesTheList() {
        var settings = AppSettings()
        let before = DailyCategories.addable(shown: onScreen(emptyInput(), settings: settings))
        XCTAssertTrue(before.contains(.budget))
        DailyCategories.add(.budget, in: &settings)
        DailyCategories.add(.budget, in: &settings)
        XCTAssertEqual(settings.dailyAdded, ["cat-budget"], "Added once")
        let tiles = onScreen(emptyInput(), settings: settings)
        XCTAssertEqual(ids(tiles), five + ["budget"])
        XCTAssertTrue(isInvitation(tiles[5]), "Nothing filled: an empty card")
        XCTAssertFalse(DailyCategories.addable(shown: tiles).contains(.budget))
        XCTAssertEqual(DailyCategories.addable(shown: tiles).count, before.count - 1)
    }

    func testAnAddedCategoryWithDataShowsItsDataAndTheListShrinksUntilThePlusIsGone() {
        var settings = AppSettings()
        let input = partialInput()
        DailyCategories.add(.nutrition, in: &settings)
        guard case .nutrition? = onScreen(input, settings: settings).first else { return XCTFail("Its data, not an empty card") }
        for category in DailyBrief.Category.allCases { DailyCategories.add(category, in: &settings) }
        let tiles = onScreen(input, settings: settings)
        XCTAssertEqual(Set(ids(tiles)), Set(allIDs))
        XCTAssertTrue(DailyCategories.addable(shown: tiles).isEmpty, "Everything added: the « + » card disappears")
    }

    func testAddingBringsBackARemovedCategory() {
        var input = emptyInput()
        input.interests = [.nutrition]
        var settings = AppSettings()
        DailyCategories.remove(tileID: "nutrition", in: &settings)
        XCTAssertEqual(ids(onScreen(input, settings: settings)), ["workout", "planning", "habits", "reminders"])
        XCTAssertEqual(DailyCategories.addable(shown: onScreen(input, settings: settings)).first, .nutrition, "It is back in the list of the « + »")
        DailyCategories.add(.nutrition, in: &settings)
        XCTAssertFalse(settings.dailyHidden.contains("nutrition"))
        XCTAssertEqual(ids(onScreen(input, settings: settings)), five, "Back at its default place")
    }

    // MARK: Removing

    func testRemovingACardKeepsItOffEvenWhenItReceivesData() {
        var input = emptyInput()
        input.interests = [.nutrition, .habits]
        var settings = AppSettings()
        DailyCategories.remove(tileID: "nutrition", in: &settings)
        XCTAssertEqual(ids(onScreen(input, settings: settings)), ["workout", "planning", "habits", "reminders"])
        // The same card with data: still off.
        var filled = partialInput()
        filled.interests = [.nutrition, .habits]
        XCTAssertEqual(ids(onScreen(filled, settings: settings)), ["workout", "planning", "habits", "reminders"], "Data does not bring a removed card back")
        XCTAssertTrue(DailyCategories.addable(shown: onScreen(filled, settings: settings)).contains(.nutrition))
        // Removing the same one twice records it once.
        DailyCategories.remove(tileID: "nutrition", in: &settings)
        XCTAssertEqual(settings.dailyHidden.filter { $0 == "nutrition" }.count, 1)
    }

    func testRemovingTakesAnAddedCategoryOffTheAddedList() {
        var settings = AppSettings()
        DailyCategories.add(.car, in: &settings)
        XCTAssertEqual(settings.dailyAdded, ["cat-car"])
        DailyCategories.remove(tileID: "app-car", in: &settings)
        XCTAssertTrue(settings.dailyAdded.isEmpty)
        XCTAssertEqual(settings.dailyHidden, ["app-car"], "The id of the card, like the editor's eye")
        XCTAssertFalse(ids(onScreen(emptyInput(), settings: settings)).contains("app-car"))
    }

    func testRemovingAlsoDropsTheOldFormsOfTheSameCategory() {
        var settings = AppSettings()
        settings.dailyAdded = ["business", "cat-business", "quick-productivity", "fitness", "cat-car"]
        DailyCategories.remove(tileID: "app-business", in: &settings)
        XCTAssertEqual(settings.dailyAdded, ["quick-productivity", "fitness", "cat-car"], "Both forms of Business gone, the others kept")
        DailyCategories.remove(tileID: "reminders", in: &settings)
        DailyCategories.remove(tileID: "workout", in: &settings)
        XCTAssertEqual(settings.dailyAdded, ["cat-car"])
        XCTAssertEqual(DailyCategories.added(settings), [.car])
        XCTAssertEqual(Set(settings.dailyHidden), ["app-business", "reminders", "workout"])
    }

    func testTheAutomaticLayoutNeverBringsBackARemovedCategory() {
        // What the editor's « Disposition automatique » does: only the order and the sizes are reset.
        var settings = AppSettings()
        var input = emptyInput()
        input.interests = [.nutrition]
        DailyCategories.remove(tileID: "nutrition", in: &settings)
        settings.dailyOrder = ["nutrition"]
        settings.dailyWide = ["nutrition": true]
        settings.dailyOrder = []
        settings.dailyWide = [:]
        XCTAssertEqual(settings.dailyHidden, ["nutrition"])
        XCTAssertFalse(ids(onScreen(input, settings: settings)).contains("nutrition"))
    }

    func testRemovingNeverTouchesTheMiniAppData() {
        let model = temporaryModel()
        model.setNutritionTargets(kcal: 2_200)
        model.updateSettings { DailyCategories.remove(tileID: "nutrition", in: &$0) }
        XCTAssertEqual(model.nutrition.goals.kcal, 2_200, "Removed from Mon Quotidien, not from the mini-app")
        XCTAssertTrue(model.profile.knows(.kcalTarget))
        let tiles = DailyBrief.arranged(DailyCategories.home(model: model, now: wednesday(9), steps: nil),
                                        order: model.settings.dailyOrder, hidden: model.settings.dailyHidden)
        XCTAssertEqual(ids(tiles), ["workout", "planning", "habits", "reminders"], "The others of every account stay")
        XCTAssertEqual(DailyCategories.addable(shown: tiles).first, .nutrition)
    }

    // MARK: Routes

    func testEveryEmptyCardOpensAMiniAppAndNeverAPagePerCategory() {
        let expected: [DailyBrief.Category: HomeRoute] = [
            .nutrition: .app(.nutrition), .workout: .app(.fitness), .planning: .app(.planning),
            .habits: .app(.planning), .budget: .app(.finances), .priorities: .app(.planning),
            .reminders: .app(.planning), .steps: .page(.fitnessActivity), .studies: .app(.studies),
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
        XCTAssertEqual(InfoArea.student.homeRoute, .app(.studies))
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

    func testAnOldProductiviteEntryNeverBringsBackTheTopThree() {
        var input = emptyInput()
        input.interests = [.productivity]
        var settings = AppSettings()
        settings.dailyAdded = [DailyCategories.productivityKey]
        XCTAssertEqual(DailyCategories.added(settings), [.reminders], "The old Productivité entry stands for « À ne pas oublier »")
        let found = ids(onScreen(input, settings: settings))
        XCTAssertFalse(found.contains("priorities"))
        XCTAssertEqual(found.filter { $0 == "reminders" }.count, 1)
        DailyCategories.remove(tileID: "reminders", in: &settings)
        XCTAssertFalse(settings.dailyAdded.contains(DailyCategories.productivityKey))
        XCTAssertFalse(ids(onScreen(input, settings: settings)).contains("reminders"), "Removed, it stays off")
    }

    // MARK: Hide, show, reorder (the same ids, empty or filled)

    func testHidingAnEmptyCategoryAndShowingItAgain() {
        let tiles = home(emptyInput(), settings: everything)
        let hidden = DailyBrief.arranged(tiles, order: [], hidden: ["budget"])
        XCTAssertEqual(hidden.count, tiles.count - 1)
        XCTAssertFalse(ids(hidden).contains("budget"))
        let shown = DailyBrief.arranged(tiles, order: [], hidden: [])
        XCTAssertEqual(ids(shown), orderedIDs, "The fixed default order")
    }

    func testAHiddenCategoryStaysHiddenWhenItReceivesData() {
        let hidden = ["nutrition", "habits"]
        XCTAssertFalse(ids(DailyBrief.arranged(home(emptyInput(), settings: everything), order: [], hidden: hidden)).contains("nutrition"))
        let filled = DailyBrief.arranged(home(partialInput(), settings: everything), order: [], hidden: hidden)
        XCTAssertFalse(ids(filled).contains("nutrition"), "Data does not bring it back")
        XCTAssertFalse(ids(filled).contains("habits"))
        XCTAssertEqual(filled.count, allIDs.count - 2)
    }

    func testANewCategoryShowsAndAHiddenOneStaysHidden() {
        // Saved by an older version that only knew a few cards: the new ones come after, shown.
        let order = ["workout", "nutrition"]
        let arranged = DailyBrief.arranged(home(emptyInput(), settings: everything), order: order, hidden: ["budget"])
        XCTAssertEqual(ids(arranged).prefix(2), ["workout", "nutrition"])
        XCTAssertTrue(ids(arranged).contains("app-travel"), "A category the settings never heard of shows")
        XCTAssertFalse(ids(arranged).contains("budget"), "A hidden one stays hidden")
        XCTAssertEqual(arranged.count, allIDs.count - 1)
    }

    func testReorderingMovesEmptyAndFilledCardsAlike() {
        let order = ["app-travel", "habits", "nutrition"]
        let empty = DailyBrief.arranged(home(emptyInput(), settings: everything), order: order, hidden: [])
        XCTAssertEqual(ids(empty).prefix(3), ["app-travel", "habits", "nutrition"])
        XCTAssertEqual(empty.count, allIDs.count)
        // The same order once habits and nutrition hold data: same places.
        let filled = DailyBrief.arranged(home(partialInput(), settings: everything), order: order, hidden: [])
        XCTAssertEqual(ids(filled).prefix(3), ["app-travel", "habits", "nutrition"])
        // Moved back to the automatic order: the fixed default order.
        XCTAssertEqual(ids(DailyBrief.arranged(home(emptyInput(), settings: everything), order: [], hidden: [])), orderedIDs)
    }

    func testTheCategoryTogglesOfTheEditorFollowTheCards() {
        var settings = AppSettings()
        var input = emptyInput()
        input.interests = [.nutrition]
        var tiles = home(input, settings: settings)
        XCTAssertTrue(DailyCategories.isShown(.nutrition, available: tiles, settings: settings), "A chosen interest counts as shown")
        XCTAssertFalse(DailyCategories.isShown(.business, available: tiles, settings: settings), "Not chosen: offered by the « + »")
        DailyCategories.set(.business, shown: true, in: &settings)
        tiles = home(input, settings: settings)
        XCTAssertTrue(DailyCategories.isShown(.business, available: tiles, settings: settings))
        XCTAssertTrue(ids(DailyBrief.arranged(tiles, order: [], hidden: settings.dailyHidden)).contains("app-business"))
        DailyCategories.set(.nutrition, shown: false, in: &settings)
        XCTAssertFalse(DailyCategories.isShown(.nutrition, available: tiles, settings: settings))
        XCTAssertFalse(ids(DailyBrief.arranged(tiles, order: [], hidden: settings.dailyHidden)).contains("nutrition"))
        DailyCategories.set(.nutrition, shown: true, in: &settings)
        XCTAssertTrue(ids(DailyBrief.arranged(tiles, order: [], hidden: settings.dailyHidden)).contains("nutrition"))
    }

    // MARK: Persistence

    func testLayoutSettingsRoundTrip() throws {
        var settings = AppSettings()
        settings.dailyOrder = ["car", "nutrition"]
        settings.dailyHidden = ["budget", "app-travel"]
        settings.dailyWide = ["habits": true, "steps": false]
        DailyCategories.add(.workout, in: &settings)
        DailyCategories.add(.steps, in: &settings)
        let data = try JSONEncoder().encode(settings)
        let back = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(back.dailyOrder, ["car", "nutrition"])
        XCTAssertEqual(back.dailyHidden, ["budget", "app-travel"])
        XCTAssertEqual(back.dailyWide, ["habits": true, "steps": false])
        XCTAssertEqual(back.dailyAdded, ["cat-workout", "cat-steps"])
        XCTAssertEqual(DailyCategories.added(back), [.workout, .steps])
    }

    func testOldOrBrokenSettingsStillDecode() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(old.dailyOrder.isEmpty)
        XCTAssertTrue(old.dailyHidden.isEmpty, "Nothing removed by default")
        XCTAssertTrue(old.dailyAdded.isEmpty)
        XCTAssertTrue(DailyCategories.added(old).isEmpty, "Nothing added by default: only the interests and the data show")
        let broken = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"dailyHidden":["budget"],"dailyOrder":"oops","dailyWide":3,"dailyAdded":7}"#.utf8))
        XCTAssertEqual(broken.dailyHidden, ["budget"], "A field out of shape doesn't lose the others")
        XCTAssertTrue(broken.dailyOrder.isEmpty)
        XCTAssertTrue(broken.dailyWide.isEmpty)
        XCTAssertTrue(broken.dailyAdded.isEmpty)
    }

    func testSettingsFromBeforeThePlusKeepWhatTheyHad() throws {
        // A mini-app added from the editor, the Productivité quick add, an entry no one knows: old and new forms.
        let json = #"{"dailyAdded":["business","fitness","quick-productivity","bogus","cat-car","cat-nope","photos"],"dailyHidden":["budget"],"dailyOrder":["car"]}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(DailyCategories.added(settings), [.business, .workout, .reminders, .car], "Unknown entries are ignored, the others kept")
        var input = emptyInput()
        input.interests = [.budget]
        let tiles = onScreen(input, settings: settings)
        XCTAssertEqual(Set(ids(tiles)), Set(five + ["app-business"]), "The five of every account and the added ones; budget stays off, Auto is gone")
        XCTAssertFalse(ids(tiles).contains("budget"), "What was hidden stays hidden")
        XCTAssertEqual(settings.dailyOrder, ["car"])
    }

    func testTheChoicesSurviveARelaunch() {
        let directory = temporaryDirectory()
        let model = temporaryModel(directory)
        model.update(\.profile) { $0.interests = [.sport, .nutrition] }
        model.updateSettings {
            DailyCategories.add(.travel, in: &$0)
            DailyCategories.remove(tileID: "workout", in: &$0)
            $0.dailyOrder = ["app-travel", "nutrition"]
        }
        let relaunched = temporaryModel(directory)
        XCTAssertEqual(relaunched.settings.dailyAdded, ["cat-travel"])
        XCTAssertEqual(relaunched.settings.dailyHidden, ["workout"])
        let tiles = DailyBrief.arranged(DailyCategories.home(model: relaunched, now: wednesday(9), steps: nil),
                                        order: relaunched.settings.dailyOrder, hidden: relaunched.settings.dailyHidden)
        XCTAssertEqual(ids(tiles), ["app-travel", "nutrition", "planning", "habits", "reminders"],
                       "The added card and the interest in their order, the removed one off, then the others in the default order")
        // Data arriving later doesn't bring the removed card back.
        relaunched.update(\.fitness) { $0.routines = [Routine(name: "Jambes", exercises: [ExerciseTemplate(name: "Squat", sets: 2, reps: 8, weight: 80)], weekdays: [3])] }
        let after = DailyBrief.arranged(DailyCategories.home(model: relaunched, now: wednesday(9), steps: nil),
                                        order: relaunched.settings.dailyOrder, hidden: relaunched.settings.dailyHidden)
        XCTAssertFalse(ids(after).contains("workout"))
        XCTAssertTrue(DailyCategories.addable(shown: after).contains(.workout))
    }
}
