import XCTest
@testable import Ardane

/// The figures of the hybrid Habits page (refonte du 2026-11-17): the groups « À faire » / « Faites », the week, the
/// global regularity, the days when everything was done and the rate of each week.
final class HabitsHybridTests: XCTestCase {
    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    /// Thursday 12 November 2026 at noon.
    private var now: Date { date(11, 12) }

    private func habit(_ name: String, days: [(Int, Int)]) -> Habit {
        Habit(name: name, symbol: "checkmark.circle", colorHex: "7FA33A", completedDays: days.map { DateMath.dayKey(date($0.0, $0.1)) })
    }

    func testSplitKeepsTheOrderInEachGroup() {
        let a = habit("A", days: [(11, 12)])
        let b = habit("B", days: [])
        let c = habit("C", days: [(11, 12)])
        let d = habit("D", days: [])
        let groups = HabitsHybrid.split([a, b, c, d], on: now)
        XCTAssertEqual(groups.todo.map(\.name), ["B", "D"])
        XCTAssertEqual(groups.done.map(\.name), ["A", "C"])
    }

    func testLongestStreakTakesTheBestOfTheHabits() {
        let a = habit("A", days: [(11, 11), (11, 12)])
        let b = habit("B", days: [(11, 10), (11, 11), (11, 12)])
        XCTAssertEqual(HabitsHybrid.longestStreak([a, b], asOf: now), 3)
        XCTAssertEqual(HabitsHybrid.longestStreak([], asOf: now), 0)
    }

    func testWeekCellsStopAtTodayAndTotalsCountOnlyDaysGoneBy() {
        // The week of Thursday 12 November: Monday 9 to Sunday 15, the calendar's first weekday permitting.
        let a = habit("A", days: [(11, 9), (11, 10), (11, 12)])
        let cells = HabitsHybrid.weekCells(for: a, weekOf: now, asOf: now)
        XCTAssertEqual(cells.count, 7)
        XCTAssertEqual(cells.compactMap { $0 }.filter { $0 }.count, 3)
        XCTAssertNil(cells[6])
        let totals = HabitsHybrid.weekTotals([a], asOf: now)
        XCTAssertEqual(totals.done, 3)
        XCTAssertEqual(totals.total, cells.compactMap { $0 }.count)
    }

    func testWeekTotalsLookAtTheFirstSixHabitsOnly() {
        let habits = (0..<8).map { habit("H\($0)", days: [(11, 12)]) }
        let one = HabitsHybrid.weekTotals([habits[0]], asOf: now)
        let all = HabitsHybrid.weekTotals(habits, asOf: now)
        XCTAssertEqual(all.total, one.total * 6)
        XCTAssertEqual(all.done, 6)
    }

    func testOverallRateIsNilWithoutAnyDayDoneAndSumsTheHabits() {
        XCTAssertNil(HabitsHybrid.overallRate([habit("A", days: [])], asOf: now))
        // A: first done 2 days ago, done on 3 of... 10 and 12 → 2 of 3. B: done today only → 1 of 1.
        let a = habit("A", days: [(11, 10), (11, 12)])
        let b = habit("B", days: [(11, 12)])
        let rate = HabitsHybrid.overallRate([a, b], asOf: now)
        XCTAssertEqual(rate ?? -1, 3.0 / 4.0, accuracy: 0.0001)
    }

    func testCompleteDaysCountsOnlyDaysWithAHabitStarted() {
        // A starts on the 10th, B on the 11th. 10: A done (complete). 11: A and B done (complete). 12: only A (not).
        let a = habit("A", days: [(11, 10), (11, 11), (11, 12)])
        let b = habit("B", days: [(11, 11)])
        let result = HabitsHybrid.completeDays([a, b], days: 30, asOf: now)
        XCTAssertEqual(result.counted, 3)
        XCTAssertEqual(result.complete, 2)
        let none = HabitsHybrid.completeDays([habit("C", days: [])], days: 30, asOf: now)
        XCTAssertEqual(none.counted, 0)
        XCTAssertEqual(none.complete, 0)
    }

    func testWeeklyRatesEndWithTheCurrentWeek() {
        let a = habit("A", days: [(11, 9), (11, 10), (11, 11), (11, 12)])
        let rates = HabitsHybrid.weeklyRates([a], weeks: 8, asOf: now)
        XCTAssertEqual(rates.count, 8)
        XCTAssertTrue(rates.last?.isCurrent ?? false)
        XCTAssertEqual(rates.filter(\.isCurrent).count, 1)
        // Nothing was counted before the first day done; the current week has its days gone by all done.
        XCTAssertNil(rates.first?.rate)
        XCTAssertNotNil(rates.last?.rate)
        XCTAssertGreaterThan(rates.last?.rate ?? 0, 0.99)
    }

    func testDoneCountInMonthOnlyCountsThatMonth() {
        let a = habit("A", days: [(10, 30), (11, 1), (11, 2), (11, 12), (12, 1)])
        XCTAssertEqual(HabitsHybrid.doneCount(a, inMonthOf: now), 3)
    }

    func testTheHabitFormatIsUnchanged() throws {
        // No new field: a habit still encodes with its five keys (the two optional ones are absent when nil) only.
        let data = try JSONEncoder().encode(habit("A", days: [(11, 12)]))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["id", "name", "symbol", "colorHex", "completedDays"])
    }
}
