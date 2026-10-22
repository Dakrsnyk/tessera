import XCTest
@testable import Tessera

/// The week selector: each day reads as selected, today, gone by or to come, on the real calendar.
final class WeekSelectorTests: XCTestCase {
    /// Wednesday 30 September 2026, noon.
    private let now = DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 12))!

    private func day(_ offset: Int) -> Date {
        DateMath.calendar.date(byAdding: .day, value: offset, to: now)!
    }

    func testTheSelectedDayWinsOverToday() {
        XCTAssertEqual(WeekDayKind.of(now, selected: now, now: now), .selected)
        XCTAssertEqual(WeekDayKind.of(day(-2), selected: day(-2), now: now), .selected)
    }

    func testTodayIsTodayWhenAnotherDayIsSelected() {
        XCTAssertEqual(WeekDayKind.of(now, selected: day(-1), now: now), .today)
    }

    func testDaysBeforeAndAfterToday() {
        XCTAssertEqual(WeekDayKind.of(day(-1), selected: now, now: now), .past)
        XCTAssertEqual(WeekDayKind.of(day(-30), selected: now, now: now), .past)
        XCTAssertEqual(WeekDayKind.of(day(1), selected: now, now: now), .future)
        XCTAssertEqual(WeekDayKind.of(day(40), selected: now, now: now), .future)
    }

    func testTheTimeOfDayDoesNotMatter() {
        let earlyToday = DateMath.startOfDay(now)
        let lateToday = day(0).addingTimeInterval(8 * 3_600)
        XCTAssertEqual(WeekDayKind.of(earlyToday, selected: day(-1), now: lateToday), .today)
    }

    func testAWeekHasSevenConsecutiveDaysContainingTheSelectedOne() {
        let week = DateMath.week(containing: now)
        XCTAssertEqual(week.count, 7)
        XCTAssertTrue(week.contains { DateMath.isSameDay($0, now) })
        for (a, b) in zip(week, week.dropFirst()) {
            XCTAssertEqual(DateMath.daysBetween(a, b), 1, "Consecutive days")
        }
    }

    func testMovingByAWeekKeepsTheWeekdayAndNeverPassesTodayWhenTheFutureIsClosed() {
        let next = WeekTitle.shifted(now, by: 1, allowsFuture: true, now: now)
        XCTAssertEqual(DateMath.daysBetween(now, next), 7)
        let capped = WeekTitle.shifted(now, by: 1, allowsFuture: false, now: now)
        XCTAssertTrue(DateMath.isSameDay(capped, now), "A log never goes past today")
        let previous = WeekTitle.shifted(now, by: -1, allowsFuture: false, now: now)
        XCTAssertEqual(DateMath.daysBetween(previous, now), 7)
    }
}
