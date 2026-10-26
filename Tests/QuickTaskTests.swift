import XCTest
@testable import Ardane

/// The Productivité card of Mon Quotidien: quick add of a task for today, and its reserved entry in the settings.
@MainActor
final class QuickTaskTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func temporaryModel() -> AppModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return AppModel(store: SharedStore(directory: directory))
    }

    func testQuickAddKeepsTheTrimmedTitle() {
        var state = ProductivityState()
        XCTAssertTrue(state.addQuickTask("  Appeler le dentiste \n", on: now))
        XCTAssertEqual(state.priorities.map(\.title), ["Appeler le dentiste"])
        XCTAssertFalse(state.priorities[0].isDone(on: now))
    }

    func testEmptyOrBlankTitleAddsNothing() {
        var state = ProductivityState()
        XCTAssertFalse(state.addQuickTask("", on: now))
        XCTAssertFalse(state.addQuickTask("   \n ", on: now))
        XCTAssertTrue(state.priorities.isEmpty)
    }

    func testSameTitleWithinASecondIsIgnoredButNotLater() {
        var state = ProductivityState()
        XCTAssertTrue(state.addQuickTask("Payer le loyer", on: now))
        XCTAssertFalse(state.addQuickTask("payer le loyer ", on: now.addingTimeInterval(0.4)), "A double tap adds one task")
        XCTAssertEqual(state.priorities.count, 1)
        XCTAssertTrue(state.addQuickTask("Payer le loyer", on: now.addingTimeInterval(5)))
        XCTAssertEqual(state.priorities.count, 2)
    }

    func testTopThreeIsNeverExceeded() {
        var state = ProductivityState()
        for index in 0..<ProductivityState.maxPriorities {
            XCTAssertTrue(state.addQuickTask("Tâche \(index)", on: now.addingTimeInterval(Double(index) * 10)))
        }
        XCTAssertFalse(state.addQuickTask("Une de trop", on: now.addingTimeInterval(100)))
        XCTAssertEqual(state.priorities.count, ProductivityState.maxPriorities)
    }

    func testAQuickTaskCanBeCheckedAndUnchecked() throws {
        var state = ProductivityState()
        XCTAssertTrue(state.addQuickTask("Envoyer le devis", on: now))
        let id = try XCTUnwrap(state.priorities.first?.id)
        state.togglePriority(id, on: now)
        XCTAssertTrue(state.priorities[0].isDone(on: now))
        XCTAssertEqual(DailyBrief.priorityChecks(state, now: now).map(\.isDone), [true])
        state.togglePriority(id, on: now)
        XCTAssertFalse(state.priorities[0].isDone(on: now))
    }

    func testSavedTasksWithoutCreationDateStillDecode() throws {
        let json = #"{"priorities":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"Ancienne tâche"}]}"#
        let state = try JSONDecoder().decode(ProductivityState.self, from: Data(json.utf8))
        XCTAssertEqual(state.priorities.map(\.title), ["Ancienne tâche"])
        XCTAssertNil(state.priorities[0].createdAt)
        var copy = state
        XCTAssertTrue(copy.addQuickTask("Ancienne tâche", on: now), "Without a creation date, nothing counts as a double tap")
    }

    func testSettingsWithoutTheProductivityEntryStayUntouched() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertFalse(settings.dailyAdded.contains(DailyCategories.productivityKey))
        XCTAssertTrue(DailyCategories.adding(settings.dailyAdded, to: [], model: temporaryModel(), now: now).isEmpty,
                      "Not added: no card without tasks")
    }

    func testAddedProductiviteShowsEvenWithoutTasks() {
        var settings = AppSettings()
        let before = settings.dailyHidden
        DailyCategories.setProductivity(shown: true, hasTasks: false, in: &settings)
        XCTAssertEqual(settings.dailyAdded, [DailyCategories.productivityKey])
        let tiles = DailyCategories.adding(settings.dailyAdded, to: [], model: temporaryModel(), now: now)
        XCTAssertEqual(tiles.map(\.id), ["priorities"])
        XCTAssertTrue(DailyCategories.isProductivityShown(settings: settings))
        // Added twice: still one entry; taken off with no task: the (empty) Top 3 card is hidden for real.
        DailyCategories.setProductivity(shown: true, hasTasks: false, in: &settings)
        XCTAssertEqual(settings.dailyAdded.count, 1)
        XCTAssertEqual(settings.dailyHidden, before, "Shown: nothing hidden")
        DailyCategories.setProductivity(shown: false, hasTasks: false, in: &settings)
        XCTAssertTrue(settings.dailyAdded.isEmpty)
        XCTAssertEqual(settings.dailyHidden, before + ["priorities"], "The empty card must not stay behind an « off » switch")
        XCTAssertFalse(DailyCategories.isProductivityShown(settings: settings))
    }

    func testTakingProductiviteOffHidesTheTopThreeOnlyWhileItHoldsTasks() {
        var settings = AppSettings()
        DailyCategories.setProductivity(shown: true, hasTasks: true, in: &settings)
        DailyCategories.setProductivity(shown: false, hasTasks: true, in: &settings)
        XCTAssertTrue(settings.dailyAdded.isEmpty)
        XCTAssertTrue(settings.dailyHidden.contains("priorities"), "With tasks it would still show: hidden for real")
    }

    func testProductiviteAndPlanningDoNotMoveEachOther() {
        let top3 = DailyBrief.Tile.priorities([DailyBrief.Check(id: "a", title: "Une tâche", isDone: false)])
        var settings = AppSettings()
        // Planning is off (all its cards hidden); Productivité is added.
        DailyCategories.set(.planning, shown: false, in: &settings)
        DailyCategories.setProductivity(shown: true, hasTasks: true, in: &settings)
        XCTAssertTrue(DailyCategories.isProductivityShown(settings: settings))
        XCTAssertFalse(DailyCategories.isShown(.planning, available: [top3], settings: settings),
                       "The Top 3 shown for Productivité doesn't switch Planning on")
        // Turning Planning off again keeps the Productivité card.
        DailyCategories.set(.planning, shown: false, in: &settings)
        XCTAssertFalse(settings.dailyHidden.contains("priorities"))
        XCTAssertTrue(DailyCategories.isProductivityShown(settings: settings))
    }

    func testExistingTopThreeIsNotDuplicated() {
        let existing = DailyBrief.Tile.priorities([DailyBrief.Check(id: "a", title: "Une tâche", isDone: false)])
        let tiles = DailyCategories.adding([DailyCategories.productivityKey], to: [existing], model: temporaryModel(), now: now)
        XCTAssertEqual(tiles.map(\.id), ["priorities"])
    }

    func testTheQuickAddEntryKeepsTheTopThreeOnMonQuotidienWithoutInterest() {
        var settings = AppSettings()
        DailyCategories.setProductivity(shown: true, hasTasks: false, in: &settings)
        XCTAssertEqual(DailyCategories.added(settings), [.priorities], "The Productivité entry counts as an added category")
        // No interest, no task: the card still shows (empty Top 3 with its quick add), until it is taken off.
        let input = DailyBrief.Input(now: now)
        XCTAssertEqual(DailyCategories.wanted(input: input, settings: settings), [.priorities])
        DailyCategories.setProductivity(shown: false, hasTasks: false, in: &settings)
        XCTAssertTrue(DailyCategories.added(settings).isEmpty)
    }

    func testTheReservedEntryIsNotAMiniApp() {
        XCTAssertNil(MiniApp(rawValue: DailyCategories.productivityKey))
    }
}
