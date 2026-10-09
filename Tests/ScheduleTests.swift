import XCTest
@testable import Tessera

/// The Planning schedule: entries every week or once on a date, and a weekly entry cancelled one day only.
final class ScheduleTests: XCTestCase {
    /// A day of 2026 at 9:00 (30 September and 7 October are Wednesdays).
    private func day(_ day: Int, month: Int = 9) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 9))!
    }

    func testAnEventOnceFallsOnItsDateOnly() {
        var state = StudentState()
        state.slots = [ClassSlot(courseID: nil, weekday: 3, startMinute: 600, endMinute: 660, kind: .appointment, title: "Dentiste",
                                 date: DateMath.startOfDay(day(30)))]
        XCTAssertEqual(StudentMath.occurrences(state, on: day(30)).map(\.slot.title), ["Dentiste"])
        XCTAssertTrue(StudentMath.occurrences(state, on: day(7, month: 10)).isEmpty, "Not the Wednesday after")
    }

    func testAWeeklyClassCancelledOnceComesBackTheWeekAfter() {
        var state = StudentState()
        let slot = ClassSlot(courseID: nil, weekday: 3, startMinute: 600, endMinute: 660)
        state.slots = [slot]
        state.setCancelled(true, slot: slot.id, on: day(30))
        XCTAssertTrue(StudentMath.occurrences(state, on: day(30)).isEmpty)
        XCTAssertEqual(StudentMath.occurrences(state, on: day(30), includingCancelled: true).first?.isCancelled, true)
        XCTAssertEqual(StudentMath.occurrences(state, on: day(7, month: 10)).count, 1)
        let next = StudentMath.nextClass(state, at: day(30))
        XCTAssertTrue(next.map { DateMath.isSameDay($0.start, day(7, month: 10)) } ?? false, "The next class is the week after")
        state.setCancelled(false, slot: slot.id, on: day(30))
        XCTAssertEqual(StudentMath.occurrences(state, on: day(30)).count, 1)
    }

    /// Entries saved before events could happen once come back every week.
    func testEntriesSavedBeforeComeBackEveryWeek() throws {
        let json = #"{"weekday": 2, "startMinute": 480, "endMinute": 540, "room": "B-12"}"#
        let slot = try JSONDecoder().decode(ClassSlot.self, from: Data(json.utf8))
        XCTAssertNil(slot.date)
        XCTAssertTrue(slot.skippedDays.isEmpty)
        XCTAssertEqual(slot.kind, .course)
    }
}
