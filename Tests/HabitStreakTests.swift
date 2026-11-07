import XCTest
@testable import Ardane

/// Habit streaks (`Habit.streak(asOf:)` and `bestStreak`): a missed day breaks the run, today not done yet
/// doesn't, and a run goes through the days the clocks change and through the new year.
final class HabitStreakTests: XCTestCase {
    private var cal: Calendar { DateMath.calendar }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func daysBefore(_ offset: Int, _ today: Date) -> Date {
        cal.date(byAdding: .day, value: -offset, to: today)!
    }

    private func makeHabit(doneOffsets offsets: [Int], today: Date) -> Habit {
        var habit = Habit(name: "Lire", symbol: "book.fill", colorHex: "2F8F7A")
        for offset in offsets { habit.toggle(on: daysBefore(offset, today)) }
        return habit
    }

    func testAMissedDayBreaksTheStreak() {
        let today = day(2026, 5, 20)
        let habit = makeHabit(doneOffsets: [0, 1, 3, 4, 5], today: today)
        XCTAssertEqual(habit.streak(asOf: today), 2, "The run stops at the missed day, whatever came before it")
        XCTAssertEqual(habit.bestStreak, 3, "The best run is the older one of three days")
    }

    func testTodayNotDoneYetKeepsYesterdaysStreakButAMissedYesterdayEndsIt() {
        let today = day(2026, 5, 20)
        let doneUntilYesterday = makeHabit(doneOffsets: [1, 2, 3], today: today)
        XCTAssertEqual(doneUntilYesterday.streak(asOf: today), 3)
        let missedYesterday = makeHabit(doneOffsets: [2, 3, 4], today: today)
        XCTAssertEqual(missedYesterday.streak(asOf: today), 0, "Yesterday and today both missed: no streak")
        XCTAssertEqual(missedYesterday.bestStreak, 3, "The record stays")
    }

    func testAStreakGoesThroughTheDaysTheClocksChange() {
        // 29 consecutive days from 5 March to 2 April 2026 cover the changes of the United States (8 March)
        // and of Europe (29 March), whichever time zone the iPhone is in.
        let today = day(2026, 4, 2)
        let habit = makeHabit(doneOffsets: Array(0..<29), today: today)
        XCTAssertEqual(DateMath.dayKey(daysBefore(28, today)), "2026-03-05")
        XCTAssertEqual(habit.streak(asOf: today), 29)
        XCTAssertEqual(habit.bestStreak, 29)
        XCTAssertEqual(Set(habit.completedDays).count, 29, "One key per calendar day, none twice")
    }

    func testAStreakGoesThroughTheNewYear() {
        let today = day(2026, 1, 2)
        let habit = makeHabit(doneOffsets: [0, 1, 2, 3], today: today)
        XCTAssertEqual(habit.completedDays.sorted(), ["2025-12-30", "2025-12-31", "2026-01-01", "2026-01-02"])
        XCTAssertEqual(habit.streak(asOf: today), 4)
    }

    func testTogglingADayTwiceUndoesItAndSplitsTheRun() {
        let today = day(2026, 5, 20)
        var habit = makeHabit(doneOffsets: [0, 1, 2], today: today)
        XCTAssertEqual(habit.streak(asOf: today), 3)
        habit.toggle(on: daysBefore(1, today))
        XCTAssertEqual(habit.streak(asOf: today), 1, "Removing yesterday leaves only today")
        XCTAssertEqual(habit.bestStreak, 1)
        habit.toggle(on: daysBefore(1, today))
        XCTAssertEqual(habit.streak(asOf: today), 3, "Done again: the run is whole")
        XCTAssertEqual(habit.completedDays.count, 3)
    }

    func testNothingDoneAndUnreadableDaysGiveNoStreak() {
        let today = day(2026, 5, 20)
        var habit = Habit(name: "Lire", symbol: "book.fill", colorHex: "2F8F7A")
        XCTAssertEqual(habit.streak(asOf: today), 0)
        XCTAssertEqual(habit.bestStreak, 0)
        XCTAssertNil(habit.regularity(days: 30, asOf: today), "Nothing is made up before the first day done")
        habit.completedDays = ["pas-une-date", ""]
        XCTAssertEqual(habit.streak(asOf: today), 0)
        XCTAssertEqual(habit.bestStreak, 0, "A damaged key is ignored, never counted")
    }

    func testTheStreakIsTheSameAfterSavingAndReading() throws {
        let today = day(2026, 5, 20)
        let habit = makeHabit(doneOffsets: [0, 1, 2, 4], today: today)
        let data = try JSONEncoder().encode(habit)
        let reread = try JSONDecoder().decode(Habit.self, from: data)
        XCTAssertEqual(reread, habit)
        XCTAssertEqual(reread.streak(asOf: today), 3)
        XCTAssertEqual(reread.bestStreak, 3)
    }

    func testTheLogStaysBoundedAtFourHundredDays() {
        let today = day(2026, 5, 20)
        // Logged day after day, oldest first, as it is lived.
        let habit = makeHabit(doneOffsets: Array((0..<410).reversed()), today: today)
        XCTAssertEqual(habit.completedDays.count, 400)
        XCTAssertEqual(habit.streak(asOf: today), 400, "The most recent days are kept, so the streak is not cut")
    }
}
