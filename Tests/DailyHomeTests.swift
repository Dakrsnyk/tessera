import XCTest
@testable import Tessera

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
        return false
    }

    /// What Home builds from an input and the settings (the pure part of `DailyCategories.home`).
    private func home(_ input: DailyBrief.Input, settings: AppSettings = AppSettings(),
                      captions: [DailyBrief.Category: String] = [:]) -> [DailyBrief.Tile] {
        DailyBrief.completing(DailyBrief.tiles(input), weather: input.weather, appCaptions: captions,
                              empty: DailyCategories.wanted(input: input, settings: settings))
    }

    /// What is on screen: Home with what the person removed and the order they chose applied.
    private func onScreen(_ input: DailyBrief.Input, settings: AppSettings = AppSettings(),
                          captions: [DailyBrief.Category: String] = [:]) -> [DailyBrief.Tile] {
        DailyBrief.arranged(home(input, settings: settings, captions: captions), order: settings.dailyOrder, hidden: settings.dailyHidden)
    }

    private var allIDs: [String] { DailyBrief.Category.allCases.map(\.tileID) }

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

    // MARK: What shows by default

    func testNoInterestAndNoDataShowsNothingButThePlus() {
        let tiles = onScreen(emptyInput())
        XCTAssertTrue(tiles.isEmpty, "Nothing chosen, nothing filled: no card, never a figure")
        XCTAssertEqual(DailyCategories.addable(shown: tiles), DailyBrief.Category.defaultOrder, "The « + » offers every category")
        for category in DailyBrief.Category.allCases {
            XCTAssertFalse(category.title.isEmpty)
            XCTAssertFalse(category.invitation.isEmpty, "\(category) says what to give")
        }
        XCTAssertEqual(Set(DailyBrief.Category.allCases), [.nutrition, .workout, .planning, .habits, .budget, .priorities,
                                                           .reminders, .steps, .weather, .business, .travel, .car])
    }

    func testTheInterestsOfTheFirstFormShowTheirEmptyCardsWithoutAnyCap() {
        var input = emptyInput()
        input.interests = [.budget, .nutrition, .fitness]
        let tiles = home(input)
        XCTAssertEqual(ids(tiles), ["nutrition", "workout", "budget"], "Three interests, three cards, in the default order")
        XCTAssertTrue(tiles.allSatisfy(isInvitation), "No data: only empty cards")

        input.interests = [.student, .habits, .productivity, .business, .travel, .car, .investing, .markets, .life]
        XCTAssertEqual(ids(home(input)), ["planning", "habits", "priorities", "app-business", "app-travel", "app-car"],
                       "More than two at once; the spaces without a card add none")
    }

    func testTheWeatherInterestShowsItsEmptyCardAndNothingElseDoes() {
        var input = emptyInput()
        XCTAssertTrue(home(input).isEmpty)
        input.interestedInWeather = true
        XCTAssertEqual(ids(home(input)), ["weather"])
        XCTAssertTrue(isInvitation(home(input)[0]))
    }

    func testTheCardsWithDataAreAlwaysThereAndTheInterestsComeAfterThem() {
        let tiles = home(partialInput())
        XCTAssertEqual(ids(tiles), ["nutrition", "habits"], "Data, no interest: only what is filled, nothing invented around it")
        XCTAssertFalse(tiles.contains(where: isInvitation))

        var input = partialInput()
        input.interests = [.fitness, .budget]
        let both = home(input)
        XCTAssertEqual(ids(both), ["nutrition", "habits", "workout", "budget"], "The filled cards first, then the empty ones")
        XCTAssertEqual(both.filter(isInvitation).count, 2)
        XCTAssertFalse(ids(both).contains { $0.hasPrefix("invite-") })
    }

    func testCompleteProfileHasNoInvitationAndEveryCategory() {
        let tiles = home(completeInput(), captions: captions)
        XCTAssertFalse(tiles.contains(where: isInvitation), "Everything given: no dotted card")
        XCTAssertEqual(Set(ids(tiles)), Set(allIDs))
        XCTAssertEqual(tiles.count, allIDs.count)
        XCTAssertTrue(tiles.contains(.miniApp("travel", caption: "Rome · J-12")), "Voyage, Auto and Business show their figure")
        XCTAssertTrue(ids(tiles).contains("weather"))
        XCTAssertTrue(DailyCategories.addable(shown: tiles).isEmpty, "Everything is there: no « + »")
    }

    func testAnEmptyCardKeepsTheIdOfItsCardWithData() {
        let empty = Set(ids(home(emptyInput(), settings: everything)))
        XCTAssertEqual(empty, Set(ids(home(completeInput(), settings: everything, captions: captions))), "Same ids empty or filled")
        XCTAssertEqual(empty, Set(allIDs))
    }

    func testTheWeatherOnlyShowsWithRealWeatherOrTheInterest() {
        XCTAssertFalse(ids(home(emptyInput())).contains("weather"))
        XCTAssertTrue(isInvitation(home(emptyInput(), settings: everything).first { $0.id == "weather" }!))
        var input = emptyInput()
        input.weather = SampleData.weather(now: input.now)
        guard case .weather? = home(input).first(where: { $0.id == "weather" }) else { return XCTFail("The weather card") }
    }

    func testAppModelStartsWithNothingAndFollowsTheInterests() {
        let model = temporaryModel()
        XCTAssertTrue(DailyCategories.home(model: model, now: wednesday(9), steps: nil).isEmpty, "A new account without interests: no card")
        model.update(\.profile) { $0.interests = [.sport, .nutrition] }
        let tiles = DailyCategories.home(model: model, now: wednesday(9), steps: nil)
        XCTAssertEqual(ids(tiles), ["nutrition", "workout"])
        XCTAssertTrue(tiles.allSatisfy(isInvitation), "Nothing invented: empty cards")
    }

    func testAppModelPersonalizesAfterTheFirstEntry() {
        let model = temporaryModel()
        model.setNutritionTargets(kcal: 2_200)
        let tiles = DailyCategories.home(model: model, now: wednesday(9), steps: nil)
        guard case let .nutrition(nutrition)? = tiles.first else { return XCTFail("The calorie target gives the nutrition card first") }
        XCTAssertEqual(nutrition.goals.kcal, 2_200)
        XCTAssertEqual(tiles.count, 1, "No interest: only what is filled")
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
        XCTAssertEqual(ids(tiles), ["budget"])
        XCTAssertTrue(isInvitation(tiles[0]), "Nothing filled: an empty card")
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
        XCTAssertTrue(onScreen(input, settings: settings).isEmpty)
        XCTAssertEqual(DailyCategories.addable(shown: onScreen(input, settings: settings)).first, .nutrition, "It is back in the list of the « + »")
        DailyCategories.add(.nutrition, in: &settings)
        XCTAssertFalse(settings.dailyHidden.contains("nutrition"))
        XCTAssertEqual(ids(onScreen(input, settings: settings)), ["nutrition"])
    }

    // MARK: Removing

    func testRemovingACardKeepsItOffEvenWhenItReceivesData() {
        var input = emptyInput()
        input.interests = [.nutrition, .habits]
        var settings = AppSettings()
        DailyCategories.remove(tileID: "nutrition", in: &settings)
        XCTAssertEqual(ids(onScreen(input, settings: settings)), ["habits"])
        // The same card with data: still off.
        var filled = partialInput()
        filled.interests = [.nutrition, .habits]
        XCTAssertEqual(ids(onScreen(filled, settings: settings)), ["habits"], "Data does not bring a removed card back")
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
        DailyCategories.remove(tileID: "priorities", in: &settings)
        DailyCategories.remove(tileID: "workout", in: &settings)
        XCTAssertEqual(settings.dailyAdded, ["cat-car"])
        XCTAssertEqual(DailyCategories.added(settings), [.car])
        XCTAssertEqual(Set(settings.dailyHidden), ["app-business", "priorities", "workout"])
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
        XCTAssertTrue(onScreen(input, settings: settings).isEmpty)
    }

    func testRemovingNeverTouchesTheMiniAppData() {
        let model = temporaryModel()
        model.setNutritionTargets(kcal: 2_200)
        model.updateSettings { DailyCategories.remove(tileID: "nutrition", in: &$0) }
        XCTAssertEqual(model.nutrition.goals.kcal, 2_200, "Removed from Mon Quotidien, not from the mini-app")
        XCTAssertTrue(model.profile.knows(.kcalTarget))
        let tiles = DailyBrief.arranged(DailyCategories.home(model: model, now: wednesday(9), steps: nil),
                                        order: model.settings.dailyOrder, hidden: model.settings.dailyHidden)
        XCTAssertTrue(tiles.isEmpty)
        XCTAssertEqual(DailyCategories.addable(shown: tiles).first, .nutrition)
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
        var input = emptyInput()
        input.interests = [.productivity]
        var settings = AppSettings()
        DailyCategories.setProductivity(shown: true, hasTasks: false, in: &settings)
        XCTAssertTrue(ids(onScreen(input, settings: settings)).contains("priorities"))
        DailyCategories.setProductivity(shown: false, hasTasks: false, in: &settings)
        XCTAssertTrue(settings.dailyHidden.contains("priorities"))
        XCTAssertFalse(ids(onScreen(input, settings: settings)).contains("priorities"), "No empty card behind an « off » switch")
        DailyCategories.setProductivity(shown: true, hasTasks: false, in: &settings)
        XCTAssertFalse(settings.dailyHidden.contains("priorities"))
    }

    // MARK: Hide, show, reorder (the same ids, empty or filled)

    func testHidingAnEmptyCategoryAndShowingItAgain() {
        let tiles = home(emptyInput(), settings: everything)
        let hidden = DailyBrief.arranged(tiles, order: [], hidden: ["budget"])
        XCTAssertEqual(hidden.count, tiles.count - 1)
        XCTAssertFalse(ids(hidden).contains("budget"))
        let shown = DailyBrief.arranged(tiles, order: [], hidden: [])
        XCTAssertEqual(ids(shown), allIDs)
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
        XCTAssertTrue(ids(arranged).contains("app-car"), "A category the settings never heard of shows")
        XCTAssertTrue(ids(arranged).contains("weather"))
        XCTAssertFalse(ids(arranged).contains("budget"), "A hidden one stays hidden")
        XCTAssertEqual(arranged.count, allIDs.count - 1)
    }

    func testReorderingMovesEmptyAndFilledCardsAlike() {
        let order = ["app-car", "habits", "nutrition"]
        let empty = DailyBrief.arranged(home(emptyInput(), settings: everything), order: order, hidden: [])
        XCTAssertEqual(ids(empty).prefix(3), ["app-car", "habits", "nutrition"])
        XCTAssertEqual(empty.count, allIDs.count)
        // The same order once habits and nutrition hold data: same places.
        let filled = DailyBrief.arranged(home(partialInput(), settings: everything), order: order, hidden: [])
        XCTAssertEqual(ids(filled).prefix(3), ["app-car", "habits", "nutrition"])
        // Moved back to the automatic order: the filled cards first, then the empty ones.
        XCTAssertEqual(ids(DailyBrief.arranged(home(emptyInput(), settings: everything), order: [], hidden: [])), allIDs)
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
        DailyCategories.add(.weather, in: &settings)
        DailyCategories.add(.steps, in: &settings)
        let data = try JSONEncoder().encode(settings)
        let back = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(back.dailyOrder, ["car", "nutrition"])
        XCTAssertEqual(back.dailyHidden, ["budget", "app-travel"])
        XCTAssertEqual(back.dailyWide, ["habits": true, "steps": false])
        XCTAssertEqual(back.dailyAdded, ["cat-weather", "cat-steps"])
        XCTAssertEqual(DailyCategories.added(back), [.weather, .steps])
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
        XCTAssertEqual(DailyCategories.added(settings), [.business, .workout, .priorities, .car], "Unknown entries are ignored, the others kept")
        var input = emptyInput()
        input.interests = [.budget]
        let tiles = onScreen(input, settings: settings)
        XCTAssertEqual(Set(ids(tiles)), ["app-business", "workout", "priorities", "app-car"])
        XCTAssertFalse(ids(tiles).contains("budget"), "What was hidden stays hidden")
        XCTAssertEqual(settings.dailyOrder, ["car"])
    }

    func testTheChoicesSurviveARelaunch() {
        let directory = temporaryDirectory()
        let model = temporaryModel(directory)
        model.update(\.profile) { $0.interests = [.sport, .nutrition] }
        model.updateSettings {
            DailyCategories.add(.car, in: &$0)
            DailyCategories.remove(tileID: "workout", in: &$0)
            $0.dailyOrder = ["app-car", "nutrition"]
        }
        let relaunched = temporaryModel(directory)
        XCTAssertEqual(relaunched.settings.dailyAdded, ["cat-car"])
        XCTAssertEqual(relaunched.settings.dailyHidden, ["workout"])
        let tiles = DailyBrief.arranged(DailyCategories.home(model: relaunched, now: wednesday(9), steps: nil),
                                        order: relaunched.settings.dailyOrder, hidden: relaunched.settings.dailyHidden)
        XCTAssertEqual(ids(tiles), ["app-car", "nutrition"], "The added card, the interest, the removed one off, in their order")
        // Data arriving later doesn't bring the removed card back.
        relaunched.update(\.fitness) { $0.routines = [Routine(name: "Jambes", exercises: [ExerciseTemplate(name: "Squat", sets: 2, reps: 8, weight: 80)], weekdays: [3])] }
        let after = DailyBrief.arranged(DailyCategories.home(model: relaunched, now: wednesday(9), steps: nil),
                                        order: relaunched.settings.dailyOrder, hidden: relaunched.settings.dailyHidden)
        XCTAssertFalse(ids(after).contains("workout"))
        XCTAssertTrue(DailyCategories.addable(shown: after).contains(.workout))
    }
}
