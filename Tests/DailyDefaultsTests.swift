import XCTest
@testable import Ardane

/// The default layout of « Mon Quotidien » (PDG, 2026-11-17): a fixed order for every account, Nutrition,
/// Fitness, Planning, Habitudes and Top 3 across the width, then the other cards at half width; the move of the
/// settings saved before to this layout, once.
@MainActor
final class DailyDefaultsTests: XCTestCase {
    private let five = ["nutrition", "workout", "planning", "habits", "priorities"]

    private func wednesday(_ hour: Int) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: hour))!
    }

    /// What is on screen for an input and the settings (the pure part of `DailyCategories.home`, then what the
    /// person removed and ordered).
    private func screen(_ input: DailyBrief.Input, settings: AppSettings = AppSettings()) -> [DailyBrief.Tile] {
        let completed = DailyBrief.completing(DailyBrief.tiles(input), empty: DailyCategories.wanted(input: input, settings: settings))
        let home = DailyBrief.inDefaultOrder(DailyCategories.withWeekSchedule(completed))
        return DailyBrief.arranged(home, order: settings.dailyOrder, hidden: settings.dailyHidden)
    }

    private func ids(_ tiles: [DailyBrief.Tile]) -> [String] { tiles.map(\.id) }

    private func isWide(_ tile: DailyBrief.Tile, _ settings: AppSettings = AppSettings()) -> Bool {
        DailyLayoutRules.size(of: tile, wide: settings.dailyWide) == .wide
    }

    /// A busy account: meals, a session, habits, steps, a budget and tasks, so that the scores have a say.
    private func busyInput(at date: Date, running: Bool = false) -> DailyBrief.Input {
        var input = DailyBrief.Input(now: date)
        input.profile.provided = [.kcalTarget, .monthlyBudget]
        input.nutrition.goals.kcal = 2_400
        input.content.habits = [Habit(name: "Lire", symbol: "book", colorHex: "7FA33A")]
        let routine = Routine(name: "Jambes", exercises: [ExerciseTemplate(name: "Squat", sets: 2, reps: 8, weight: 80)], weekdays: [3])
        input.fitness.routines = [routine]
        if running { input.fitness.startSession(routine, at: date) }
        input.steps = 4_000
        input.interests = [.budget, .nutrition, .fitness]
        return input
    }

    // MARK: Fixed order

    func testTheOrderIsTheSameAtEveryHour() {
        for hour in [9, 14, 21] {
            let tiles = screen(busyInput(at: wednesday(hour)))
            let found = ids(tiles)
            XCTAssertEqual(Array(found.prefix(5)), five, "hour \(hour)")
            XCTAssertEqual(found, found.sorted { rank($0) < rank($1) }, "hour \(hour)")
            XCTAssertTrue(found.contains("budget") && found.contains("steps"), "hour \(hour)")
        }
    }

    func testASessionInProgressDoesNotJumpTheQueue() {
        for hour in [9, 14, 21] {
            let tiles = screen(busyInput(at: wednesday(hour), running: true))
            XCTAssertEqual(Array(ids(tiles).prefix(5)), five, "hour \(hour)")
        }
    }

    private func rank(_ id: String) -> Int {
        DailyBrief.Category(tileID: id).flatMap { DailyDefaults.order.firstIndex(of: $0) } ?? DailyDefaults.order.count
    }

    // MARK: A new account

    func testANewAccountHasTheFiveCardsAcrossTheWidth() {
        let tiles = screen(DailyBrief.Input(now: wednesday(9)))
        XCTAssertEqual(ids(tiles), five)
        XCTAssertTrue(tiles.allSatisfy { isWide($0) })
    }

    func testOtherInterestsComeAtHalfWidthAfterTheTop3() {
        var input = DailyBrief.Input(now: wednesday(9))
        input.interests = [.car, .budget, .travel, .student, .business]
        let tiles = screen(input)
        let found = ids(tiles)
        XCTAssertEqual(Array(found.prefix(5)), five)
        XCTAssertEqual(Set(found.dropFirst(5)), ["app-studies", "budget", "app-business", "app-travel", "app-car"])
        for tile in tiles.dropFirst(5) { XCTAssertFalse(isWide(tile), tile.id) }
        for tile in tiles.prefix(5) { XCTAssertTrue(isWide(tile), tile.id) }
    }

    func testPlanningDoesNotDependOnTheSurvey() {
        var input = DailyBrief.Input(now: wednesday(9))
        input.interests = [.nutrition]
        XCTAssertTrue(ids(screen(input)).contains("planning"))
        input.interests = [.student]
        XCTAssertEqual(ids(screen(input)).filter { $0 == "planning" }.count, 1)
    }

    func testStudentsWithClassesSeeStudiesWithoutChoosingIt() {
        var input = DailyBrief.Input(now: wednesday(9))
        XCTAssertFalse(ids(screen(input)).contains("app-studies"))
        input.student.courses = [Course(name: "Mathématiques")]
        XCTAssertTrue(ids(screen(input)).contains("app-studies"))
    }

    func testNoDuplicateIdentifier() {
        var input = busyInput(at: wednesday(9), running: true)
        input.interests = Space.allCases
        input.student.courses = [Course(name: "Mathématiques")]
        var settings = AppSettings()
        for category in DailyBrief.Category.allCases { DailyCategories.add(category, in: &settings) }
        let found = ids(screen(input, settings: settings))
        XCTAssertEqual(found.count, Set(found).count, "\(found)")
        XCTAssertEqual(found.filter { $0 == "planning" }.count, 1)
    }

    func testEveryCategoryIsInTheDefaultOrderOnce() {
        XCTAssertEqual(Set(DailyDefaults.order), Set(DailyBrief.Category.allCases))
        XCTAssertEqual(DailyDefaults.order.count, DailyBrief.Category.allCases.count)
        XCTAssertEqual(Array(DailyDefaults.order.prefix(5)), [.nutrition, .workout, .planning, .habits, .priorities])
    }

    // MARK: What the person removed

    func testARemovedCardStaysRemovedWithDataAndIsOfferedByThePlus() {
        var input = busyInput(at: wednesday(9))
        input.content.habits = [Habit(name: "Lire", symbol: "book", colorHex: "7FA33A")]
        var settings = AppSettings()
        DailyCategories.remove(tileID: "habits", in: &settings)
        DailyCategories.remove(tileID: "planning", in: &settings)
        let tiles = screen(input, settings: settings)
        XCTAssertFalse(ids(tiles).contains("habits"))
        XCTAssertFalse(ids(tiles).contains("planning"))
        let addable = DailyCategories.addable(shown: tiles)
        XCTAssertTrue(addable.contains(.habits))
        XCTAssertTrue(addable.contains(.planning))
        // Put back with the « + »: it comes back, at its default place.
        DailyCategories.add(.habits, in: &settings)
        XCTAssertTrue(ids(screen(input, settings: settings)).contains("habits"))
    }

    func testTheHandOrderStillWinsOverTheDefault() {
        var settings = AppSettings()
        settings.dailyOrder = ["priorities", "nutrition"]
        let tiles = screen(DailyBrief.Input(now: wednesday(9)), settings: settings)
        XCTAssertEqual(Array(ids(tiles).prefix(2)), ["priorities", "nutrition"])
    }

    // MARK: Migration

    func testMigrationClearsOrderAndSizesButKeepsTheRest() {
        var settings = AppSettings()
        settings.dailyOrder = ["budget", "nutrition"]
        settings.dailyWide = ["workout": false, "budget": true]
        settings.dailyHidden = ["habits"]
        settings.dailyAdded = ["cat-travel"]
        settings.dailyCardPages = ["nutrition": 1]
        XCTAssertEqual(settings.dailyLayoutVersion, 0)

        XCTAssertTrue(DailyDefaults.migrate(&settings))
        XCTAssertEqual(settings.dailyLayoutVersion, DailyDefaults.layoutVersion)
        XCTAssertTrue(settings.dailyOrder.isEmpty)
        XCTAssertTrue(settings.dailyWide.isEmpty)
        XCTAssertEqual(settings.dailyHidden, ["habits"])
        XCTAssertEqual(settings.dailyAdded, ["cat-travel"])
        XCTAssertEqual(settings.dailyCardPages, ["nutrition": 1])
    }

    func testMigrationRunsOnlyOnce() {
        var settings = AppSettings()
        XCTAssertTrue(DailyDefaults.migrate(&settings))
        // The person arranges Home again: a second pass must not undo it.
        settings.dailyOrder = ["priorities"]
        settings.dailyWide = ["budget": true]
        let before = settings
        XCTAssertFalse(DailyDefaults.migrate(&settings))
        XCTAssertEqual(settings, before)
    }

    func testOldSettingsWithoutTheVersionDecodeAsVersionZero() throws {
        let old = #"{"dailyOrder":["budget"],"dailyHidden":["habits"],"dailyWide":{"workout":false},"dailyAdded":["cat-car"]}"#
        var settings = try JSONDecoder().decode(AppSettings.self, from: Data(old.utf8))
        XCTAssertEqual(settings.dailyLayoutVersion, 0)
        XCTAssertEqual(settings.dailyOrder, ["budget"])
        DailyDefaults.migrate(&settings)
        XCTAssertTrue(settings.dailyOrder.isEmpty)
        XCTAssertEqual(settings.dailyHidden, ["habits"])
        XCTAssertEqual(settings.dailyAdded, ["cat-car"])
        // The version is saved and read back.
        let again = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(again.dailyLayoutVersion, DailyDefaults.layoutVersion)
    }

    func testTheModelMigratesThroughTheNormalSaving() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let model = AppModel(store: SharedStore(directory: directory))
        // The model migrated when it loaded: an account from before the new order is at version 0 again.
        model.updateSettings { $0.dailyLayoutVersion = 0; $0.dailyOrder = ["budget"]; $0.dailyWide = ["workout": false] }
        model.migrateDailyLayout()
        XCTAssertTrue(model.settings.dailyOrder.isEmpty)
        XCTAssertTrue(model.settings.dailyWide.isEmpty)
        XCTAssertEqual(model.settings.dailyLayoutVersion, DailyDefaults.layoutVersion)
        model.updateSettings { $0.dailyOrder = ["steps"] }
        model.migrateDailyLayout()
        XCTAssertEqual(model.settings.dailyOrder, ["steps"])
    }
}
