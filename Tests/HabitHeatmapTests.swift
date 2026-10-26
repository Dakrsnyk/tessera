import XCTest
@testable import Ardane

/// The habits' contribution grid: the data of the cells, the layout that fills a widget, the percentage.
final class HabitHeatmapTests: XCTestCase {
    /// Wednesday 30 September 2026, noon.
    private let today = DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 12))!

    private func day(_ offset: Int) -> Date {
        DateMath.calendar.date(byAdding: .day, value: offset, to: today)!
    }

    private func habit(doneOffsets: [Int]) -> Habit {
        var habit = Habit(name: "Lire", symbol: "book", colorHex: "7FA33A")
        habit.completedDays = doneOffsets.map { DateMath.dayKey(day($0)) }
        return habit
    }

    func testTheGridHasTheRequestedWeeksOfSevenDays() {
        let grid = HabitHeatmap.weeks(for: habit(doneOffsets: []), columns: 5, asOf: today)
        XCTAssertEqual(grid.count, 5)
        XCTAssertTrue(grid.allSatisfy { $0.count == 7 })
        XCTAssertTrue(HabitHeatmap.weeks(for: habit(doneOffsets: []), columns: 0, asOf: today).isEmpty)
    }

    func testDaysStillToComeAreNotDrawnAndTodayIsTheLastDrawnCell() {
        let grid = HabitHeatmap.weeks(for: habit(doneOffsets: [0]), columns: 3, asOf: today)
        let week = DateMath.week(containing: today)
        let todayIndex = week.firstIndex { DateMath.isSameDay($0, today) }!
        let lastColumn = grid[2]
        XCTAssertEqual(lastColumn.filter { $0 == nil }.count, 6 - todayIndex, "Only the days after today are empty")
        XCTAssertEqual(lastColumn[todayIndex], true, "Today is done")
        XCTAssertTrue(grid[0].allSatisfy { $0 != nil }, "A week long past has no day to come")
    }

    func testOnlyTheDaysDoneAreCountedAndNothingIsMadeUp() {
        XCTAssertEqual(HabitHeatmap.doneCount(HabitHeatmap.weeks(for: habit(doneOffsets: []), columns: 8, asOf: today)), 0)
        let done = habit(doneOffsets: [0, -1, -3, -9, -20])
        XCTAssertEqual(HabitHeatmap.doneCount(HabitHeatmap.weeks(for: done, columns: 8, asOf: today)), 5)
        // A day done long before the window is not shown.
        let old = habit(doneOffsets: [-200])
        XCTAssertEqual(HabitHeatmap.doneCount(HabitHeatmap.weeks(for: old, columns: 4, asOf: today)), 0)
    }

    func testTheRecentRowEndsTodayOldestFirst() {
        let row = HabitHeatmap.recent(for: habit(doneOffsets: [0, -2]), days: 5, asOf: today)
        XCTAssertEqual(row.count, 5)
        XCTAssertTrue(row.allSatisfy { $0.count == 1 })
        XCTAssertEqual(row.map { $0[0] }, [false, false, true, false, true])
        XCTAssertTrue(HabitHeatmap.recent(for: habit(doneOffsets: []), days: 0, asOf: today).isEmpty)
    }

    func testTheLayoutUsesSevenRowsOnlyWhenTheHeightAllowsIt() {
        let short = HabitHeatmap.layout(width: 300, height: 20)
        XCTAssertEqual(short.rows, 1, "Too short for seven readable rows")
        XCTAssertTrue((15...60).contains(short.columns))
        let tall = HabitHeatmap.layout(width: 300, height: 80)
        XCTAssertEqual(tall.rows, 7)
        XCTAssertTrue((2...53).contains(tall.columns))
        let none = HabitHeatmap.layout(width: 0, height: 80)
        XCTAssertEqual(none.rows, 1)
        XCTAssertEqual(none.columns, 1)
    }

    func testTheCellsFollowTheLayout() {
        let sample = habit(doneOffsets: [0])
        let weeks = HabitHeatmap.cells(for: sample, layout: (rows: 7, columns: 4), asOf: today)
        XCTAssertEqual(weeks.count, 4)
        XCTAssertTrue(weeks.allSatisfy { $0.count == 7 })
        let recent = HabitHeatmap.cells(for: sample, layout: (rows: 1, columns: 10), asOf: today)
        XCTAssertEqual(recent.count, 10)
        XCTAssertTrue(recent.allSatisfy { $0.count == 1 })
    }

    func testTheAspectRatioFollowsTheGrid() {
        XCTAssertEqual(HabitHeatmap.aspectRatio(columns: 0, rows: 7), 1)
        let square = HabitHeatmap.aspectRatio(columns: 7, rows: 7)
        XCTAssertEqual(square, 1, accuracy: 0.0001)
        XCTAssertGreaterThan(HabitHeatmap.aspectRatio(columns: 20, rows: 7), 2)
    }

    func testThePercentageExistsOnlyOnceTheHabitWasDone() {
        XCTAssertNil(HabitHeatmap.rate(of: habit(doneOffsets: []), asOf: today), "No history: no made-up percentage")
        XCTAssertEqual(HabitHeatmap.rate(of: habit(doneOffsets: [0]), asOf: today) ?? -1, 1, accuracy: 0.0001)
        // Done yesterday, not today: two days since the first one, one done.
        XCTAssertEqual(HabitHeatmap.rate(of: habit(doneOffsets: [-1]), asOf: today) ?? -1, 0.5, accuracy: 0.0001)
    }
}
