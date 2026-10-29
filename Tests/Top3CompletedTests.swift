import XCTest
@testable import Ardane

/// Top 3: a validated task leaves the active tasks, the widget and Mon Quotidien, but stays stored with its
/// completion date (« Mes tâches réalisées »).
@MainActor
final class Top3CompletedTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func state(with titles: [String]) -> ProductivityState {
        var state = ProductivityState()
        for (index, title) in titles.enumerated() {
            XCTAssertTrue(state.addQuickTask(title, on: now.addingTimeInterval(Double(index) * 10)))
        }
        return state
    }

    func testValidatingATaskMovesItToTheHistoryWithItsDate() throws {
        var state = state(with: ["A", "B"])
        let id = try XCTUnwrap(state.priorities.first?.id)
        let done = now.addingTimeInterval(500)
        state.togglePriority(id, on: done)
        XCTAssertEqual(state.activePriorities.map(\.title), ["B"])
        XCTAssertEqual(state.completedPriorities.map(\.title), ["A"])
        XCTAssertEqual(state.completedPriorities.first?.completedAt, done)
        XCTAssertEqual(DailyBrief.priorityChecks(state, now: done).map(\.title), ["B"], "Gone from Mon Quotidien")
        XCTAssertEqual(ProductivityTiles.priorities(state, now: done).rows.map(\.title), ["B"], "Gone from the widget")
    }

    func testSeveralValidationsInARowKeepEverythingOnceAndMostRecentFirst() throws {
        var state = state(with: ["A", "B", "C"])
        let ids = state.priorities.map(\.id)
        state.togglePriority(ids[1], on: now.addingTimeInterval(100))
        state.togglePriority(ids[0], on: now.addingTimeInterval(200))
        state.togglePriority(ids[2], on: now.addingTimeInterval(300))
        XCTAssertTrue(state.activePriorities.isEmpty)
        XCTAssertEqual(state.completedPriorities.map(\.title), ["C", "A", "B"])
        XCTAssertEqual(state.priorities.count, 3, "Nothing is deleted")
        XCTAssertEqual(Set(state.priorities.map(\.id)).count, 3, "No duplicate")
    }

    func testRoomIsFreedForNewTasksAndNothingIsLost() {
        var state = state(with: ["A", "B", "C"])
        XCTAssertFalse(state.addQuickTask("D", on: now.addingTimeInterval(1_000)), "Full Top 3")
        state.togglePriority(state.priorities[0].id, on: now.addingTimeInterval(1_100))
        XCTAssertTrue(state.addQuickTask("D", on: now.addingTimeInterval(1_200)))
        XCTAssertEqual(state.activePriorities.map(\.title), ["B", "C", "D"])
        XCTAssertEqual(state.completedPriorities.map(\.title), ["A"])
    }

    func testUncheckingACompletedTaskPutsItBackWithoutDuplicate() throws {
        var state = state(with: ["A", "B"])
        let id = try XCTUnwrap(state.priorities.first?.id)
        state.togglePriority(id, on: now.addingTimeInterval(100))
        state.togglePriority(id, on: now.addingTimeInterval(200))
        XCTAssertEqual(state.activePriorities.map(\.title), ["A", "B"])
        XCTAssertTrue(state.completedPriorities.isEmpty)
        XCTAssertNil(state.priorities[0].completedAt)
        XCTAssertEqual(state.priorities.count, 2)
    }

    func testRoundTripKeepsTheHistoryAfterRelaunch() throws {
        var state = state(with: ["A", "B"])
        let id = try XCTUnwrap(state.priorities.first?.id)
        let done = now.addingTimeInterval(500)
        state.togglePriority(id, on: done)

        let encoder = JSONEncoder()
        let decoded = try JSONDecoder().decode(ProductivityState.self, from: encoder.encode(state))
        XCTAssertEqual(decoded.activePriorities.map(\.title), ["B"])
        XCTAssertEqual(decoded.completedPriorities.map(\.title), ["A"])
        XCTAssertEqual(decoded.completedPriorities.first?.completedAt, done)

        // Through the real store, as the app and the widgets share it.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SharedStore(directory: directory)
        store.save(state)
        let reloaded = store.state(ProductivityState.self)
        XCTAssertEqual(reloaded.completedPriorities.map(\.title), ["A"])
        XCTAssertEqual(reloaded.activePriorities.map(\.title), ["B"])
    }

    func testOldJSONWithoutCompletedAtStillDecodes() throws {
        let json = """
        {"priorities":[
          {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"Active"},
          {"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","title":"Cochée avant","doneDayKey":"2026-10-01"}
        ]}
        """
        let state = try JSONDecoder().decode(ProductivityState.self, from: Data(json.utf8))
        XCTAssertEqual(state.activePriorities.map(\.title), ["Active"])
        XCTAssertEqual(state.completedPriorities.map(\.title), ["Cochée avant"], "Old done task is in the history")
        XCTAssertNil(state.completedPriorities.first?.completedAt, "…without a date")
    }

    func testDatedTasksComeBeforeUndatedOnes() throws {
        let json = """
        {"priorities":[{"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","title":"Sans date","doneDayKey":"2026-10-01"}]}
        """
        var state = try JSONDecoder().decode(ProductivityState.self, from: Data(json.utf8))
        XCTAssertTrue(state.addQuickTask("Récente", on: now))
        state.togglePriority(try XCTUnwrap(state.activePriorities.first?.id), on: now.addingTimeInterval(60))
        XCTAssertEqual(state.completedPriorities.map(\.title), ["Récente", "Sans date"])
    }

    func testRestoringIsRefusedWhileTheTopThreeIsFull() throws {
        var state = state(with: ["A", "B", "C"])
        let first = state.priorities[0].id
        state.togglePriority(first, on: now.addingTimeInterval(100))
        XCTAssertTrue(state.addQuickTask("D", on: now.addingTimeInterval(200)))
        state.togglePriority(first, on: now.addingTimeInterval(300))
        XCTAssertEqual(state.activePriorities.count, ProductivityState.maxPriorities)
        XCTAssertEqual(state.completedPriorities.map(\.title), ["A"], "Still in the history, not lost")
    }
}
