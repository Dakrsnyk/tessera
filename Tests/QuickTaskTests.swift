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

    func testTheOldQuickAddEntryStandsForTheRemindersCard() {
        var settings = AppSettings()
        settings.dailyAdded = [DailyCategories.productivityKey]
        XCTAssertEqual(DailyCategories.added(settings), [.reminders], "The Productivité entry counts as an added category")
        // The Top 3 is gone (PDG, 2026-11-25): « À ne pas oublier » is one of the five cards of every account
        // (`wanted`), with or without this entry.
        let input = DailyBrief.Input(now: now)
        XCTAssertEqual(DailyCategories.wanted(input: input, settings: settings),
                       [.nutrition, .workout, .planning, .habits, .reminders])
    }

    func testTheReservedEntryIsNotAMiniApp() {
        XCTAssertNil(MiniApp(rawValue: DailyCategories.productivityKey))
    }
}
