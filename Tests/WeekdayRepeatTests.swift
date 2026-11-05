import XCTest
@testable import Ardane

/// The days-of-the-week repeat of an event: order of the pills, which days an event falls on, the summary,
/// the change of time, and data saved before the choice of days.
final class WeekdayRepeatTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int, _ hour: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    func testOrderStartsOnMondayOrSunday() {
        XCTAssertEqual(WeekdayRepeat.ordered(firstWeekday: 2), [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(WeekdayRepeat.ordered(firstWeekday: 1), [7, 1, 2, 3, 4, 5, 6])
        XCTAssertEqual(WeekdayRepeat.ordered(firstWeekday: 7), [6, 7, 1, 2, 3, 4, 5])
    }

    func testNormalizedDropsDoublesAndInvalidDays() {
        XCTAssertEqual(WeekdayRepeat.normalized([3, 1, 3, 0, 9, 7]), [1, 3, 7])
    }

    func testOccurrencesFallOnChosenDaysEveryWeek() {
        let days = [1, 3]                                    // lundi, mercredi
        XCTAssertTrue(WeekdayRepeat.occurs(on: day(2026, 11, 2), weekdays: days))      // lundi
        XCTAssertTrue(WeekdayRepeat.occurs(on: day(2026, 11, 4), weekdays: days))      // mercredi
        XCTAssertFalse(WeekdayRepeat.occurs(on: day(2026, 11, 3), weekdays: days))     // mardi
        XCTAssertTrue(WeekdayRepeat.occurs(on: day(2026, 11, 16), weekdays: days))     // lundi, 2 semaines plus tard
        XCTAssertFalse(WeekdayRepeat.occurs(on: day(2026, 11, 3), weekdays: [Int]()))
    }

    func testSundayStartDoesNotChangeWhichDaysOccur() {
        // The first day of the week only orders the pills: Sunday 1 November is the 7th ISO day either way.
        XCTAssertTrue(WeekdayRepeat.occurs(on: day(2026, 11, 1), weekdays: [7]))
        XCTAssertFalse(WeekdayRepeat.occurs(on: day(2026, 11, 1), weekdays: [1]))
    }

    func testChangeOfTimeKeepsTheWeekday() {
        // Daylight saving ended Sunday 1 November 2026 (Montréal): the days around it keep their weekday,
        // at any hour of the day.
        for hour in [0, 1, 2, 23] {
            XCTAssertTrue(WeekdayRepeat.occurs(on: day(2026, 11, 1, hour), weekdays: [7]))
            XCTAssertTrue(WeekdayRepeat.occurs(on: day(2026, 11, 2, hour), weekdays: [1]))
            XCTAssertTrue(WeekdayRepeat.occurs(on: day(2026, 10, 31, hour), weekdays: [6]))
        }
    }

    func testSummaryShapes() {
        XCTAssertEqual(WeekdayRepeat.summary([Int]()), tr("Une seule fois"))
        XCTAssertEqual(WeekdayRepeat.summary(1...7), tr("Tous les jours"))
        XCTAssertFalse(WeekdayRepeat.summary([1, 3]).isEmpty)
        XCTAssertNotEqual(WeekdayRepeat.summary([1]), WeekdayRepeat.summary([1, 3]))
        // The order of the choice does not change the text.
        XCTAssertEqual(WeekdayRepeat.summary([3, 1]), WeekdayRepeat.summary([1, 3]))
    }

    // MARK: ClassSlot

    func testAppointmentOnMondayAndWednesdayFallsOnBothNotTuesday() {
        var slot = ClassSlot(courseID: nil, weekday: 1, startMinute: 600, endMinute: 660, kind: .appointment, title: "Dentiste")
        slot.extraWeekdays = [3]
        XCTAssertNotNil(slot.resolved(on: day(2026, 11, 2)))
        XCTAssertNotNil(slot.resolved(on: day(2026, 11, 4)))
        XCTAssertNil(slot.resolved(on: day(2026, 11, 3)))
        XCTAssertNotNil(slot.resolved(on: day(2026, 11, 9)))
        // Cancelling one Wednesday leaves the Monday and the other Wednesdays.
        slot.skippedDays = [DateMath.dayKey(day(2026, 11, 4))]
        XCTAssertNil(slot.resolved(on: day(2026, 11, 4)))
        XCTAssertNotNil(slot.resolved(on: day(2026, 11, 2)))
        XCTAssertNotNil(slot.resolved(on: day(2026, 11, 11)))
    }

    func testOldSlotWithoutTheFieldDecodesAsOneDay() throws {
        let json = #"{"weekday":2,"startMinute":480,"endMinute":540}"#
        let slot = try JSONDecoder().decode(ClassSlot.self, from: Data(json.utf8))
        XCTAssertEqual(slot.extraWeekdays, [])
        XCTAssertNotNil(slot.resolved(on: day(2026, 11, 3)))
        XCTAssertNil(slot.resolved(on: day(2026, 11, 4)))
    }

    func testExtraWeekdaysSurviveEncodingAndBadValuesAreDropped() throws {
        var slot = ClassSlot(courseID: nil, weekday: 5, startMinute: 480, endMinute: 540, kind: .other, title: "Sport")
        slot.extraWeekdays = [6, 7]
        let back = try JSONDecoder().decode(ClassSlot.self, from: JSONEncoder().encode(slot))
        XCTAssertEqual(back.extraWeekdays, [6, 7])
        let odd = #"{"weekday":2,"extraWeekdays":[9,4,4,0],"startMinute":480,"endMinute":540}"#
        XCTAssertEqual(try JSONDecoder().decode(ClassSlot.self, from: Data(odd.utf8)).extraWeekdays, [4])
    }

    /// A class on Monday and Wednesday: two hours a week, and an import of its Wednesday is not added again.
    func testARepeatedSlotCountsEachDayAndIsNotImportedTwice() {
        let course = UUID()
        var slot = ClassSlot(courseID: course, weekday: 1, startMinute: 480, endMinute: 540)
        slot.extraWeekdays = [3]
        XCTAssertEqual(slot.weekdays, [1, 3])
        XCTAssertFalse(slot.weekdaysText.isEmpty)
        var state = StudentState()
        state.slots = [slot]
        XCTAssertEqual(StudentMath.weeklyClassMinutes(state, course: course), 120)
        let single = ClassSlot(courseID: course, weekday: 2, startMinute: 480, endMinute: 540)
        XCTAssertEqual(single.weekdays, [2])
    }
}
