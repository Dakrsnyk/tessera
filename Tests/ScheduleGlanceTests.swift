import XCTest
@testable import Ardane

/// What the « Horaire » widget of the Lock Screen shows through the day (`ScheduleGlance`): the event in
/// progress, the next one, the end of the day, an empty day, a cancelled class, an exception, overlaps.
@MainActor
final class ScheduleGlanceTests: XCTestCase {
    /// A wall-clock time of the device's time zone in September 2026 (the 7th, 14th, 21st and 28th are Mondays).
    private func monday(_ hour: Int, _ minute: Int = 0, day: Int = 28) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    private struct Fixture {
        var state = StudentState()
        let english: ClassSlot
        let math: ClassSlot

        init() {
            let en = Course(name: "Anglais", colorHex: "D6409F")
            let ma = Course(name: "Maths", colorHex: "3366FF")
            let eng = ClassSlot(courseID: en.id, weekday: 1, startMinute: 12 * 60, endMinute: 15 * 60)
            let mat = ClassSlot(courseID: ma.id, weekday: 1, startMinute: 9 * 60, endMinute: 10 * 60)
            var built = StudentState()
            built.courses = [en, ma]
            built.slots = [eng, mat]
            state = built
            english = eng
            math = mat
        }
    }

    private func name(_ glance: ScheduleGlance.Result, _ state: StudentState) -> String? {
        glance.event.map { state.title(of: $0.slot) }
    }

    func testBeforeTheFirstEventTheFirstIsNext() {
        let f = Fixture()
        let glance = ScheduleGlance.compute(f.state, now: monday(7))
        XCTAssertEqual(glance.phase, .upcoming)
        XCTAssertEqual(name(glance, f.state), "Maths")
        XCTAssertEqual(glance.nextChange, monday(9), "Redraw when Maths starts")
        XCTAssertFalse(glance.dayName.isEmpty)
    }

    func testDuringAnEventItStaysUntilItEnds() {
        let f = Fixture()
        let glance = ScheduleGlance.compute(f.state, now: monday(13))
        XCTAssertEqual(glance.phase, .current)
        XCTAssertEqual(name(glance, f.state), "Anglais")
        XCTAssertEqual(glance.nextChange, monday(15))
        let lastMinute = ScheduleGlance.compute(f.state, now: monday(14, 59))
        XCTAssertEqual(lastMinute.phase, .current)
    }

    func testBetweenTwoEventsTheNextOneShows() {
        let f = Fixture()
        let glance = ScheduleGlance.compute(f.state, now: monday(10, 30))
        XCTAssertEqual(glance.phase, .upcoming)
        XCTAssertEqual(name(glance, f.state), "Anglais")
        let atTheEnd = ScheduleGlance.compute(f.state, now: monday(10))
        XCTAssertEqual(atTheEnd.phase, .upcoming, "The end is exclusive: Maths is over at 10:00")
    }

    func testAfterTheLastEventTheDayIsFinished() {
        let f = Fixture()
        let glance = ScheduleGlance.compute(f.state, now: monday(15))
        XCTAssertEqual(glance.phase, .finished)
        XCTAssertNil(glance.event)
        XCTAssertEqual(glance.nextChange, DateMath.nextMidnight(after: monday(15)))
    }

    func testADayWithoutEventsIsEmpty() {
        let f = Fixture()
        let tuesday = monday(10, day: 29)
        let glance = ScheduleGlance.compute(f.state, now: tuesday)
        XCTAssertEqual(glance.phase, .empty)
        XCTAssertNil(glance.event)
        XCTAssertEqual(ScheduleGlance.compute(StudentState(), now: monday(10)).phase, .empty)
    }

    func testACancelledOccurrenceIsLeftOut() {
        var f = Fixture()
        f.state.setCancelled(true, slot: f.english.id, on: monday(8))
        let glance = ScheduleGlance.compute(f.state, now: monday(10, 30))
        XCTAssertEqual(glance.phase, .finished, "English is cancelled this Monday")
        let otherMonday = ScheduleGlance.compute(f.state, now: monday(10, 30, day: 21))
        XCTAssertEqual(otherMonday.phase, .upcoming, "Only the 28th is cancelled")
        XCTAssertEqual(name(otherMonday, f.state), "Anglais")
    }

    func testAnExceptionReplacesTheCourse() {
        var f = Fixture()
        var exception = ClassOverride()
        exception.title = "Examen"
        exception.startMinute = 13 * 60
        exception.endMinute = 16 * 60
        f.state.setOverride(exception, slot: f.english.id, on: monday(8))
        let before = ScheduleGlance.compute(f.state, now: monday(12, 30))
        XCTAssertEqual(before.phase, .upcoming, "The exception moved the class to 13:00")
        XCTAssertEqual(name(before, f.state), "Examen")
        let during = ScheduleGlance.compute(f.state, now: monday(15, 30))
        XCTAssertEqual(during.phase, .current)
        XCTAssertEqual(name(during, f.state), "Examen")
        // Another Monday keeps the course.
        let other = ScheduleGlance.compute(f.state, now: monday(12, 30, day: 21))
        XCTAssertEqual(name(other, f.state), "Anglais")
    }

    func testOverlapShowsTheEventThatEndsLast() {
        var f = Fixture()
        let long = ClassSlot(courseID: nil, weekday: 1, startMinute: 11 * 60, endMinute: 16 * 60, kind: .appointment, title: "Stage")
        f.state.slots.append(long)
        // 13:00: English (until 15:00) and the internship (until 16:00) are both in progress.
        let glance = ScheduleGlance.compute(f.state, now: monday(13))
        XCTAssertEqual(glance.phase, .current)
        XCTAssertEqual(name(glance, f.state), "Stage")
        XCTAssertEqual(glance.nextChange, monday(15), "Still redrawn when the other one ends")
        // Two events ending together: the one that started first.
        var tie = Fixture()
        tie.state.slots.append(ClassSlot(courseID: nil, weekday: 1, startMinute: 13 * 60, endMinute: 15 * 60, kind: .appointment, title: "Rendez-vous"))
        XCTAssertEqual(name(ScheduleGlance.compute(tie.state, now: monday(13, 30)), tie.state), "Anglais")
    }

    func testTransitionsListEveryStartAndEndThenMidnight() {
        let f = Fixture()
        let now = monday(8)
        let dates = ScheduleGlance.transitions(f.state, from: now)
        XCTAssertEqual(dates.first, now)
        XCTAssertEqual(dates, dates.sorted())
        XCTAssertEqual(Set(dates).count, dates.count)
        for expected in [monday(9), monday(10), monday(12), monday(15), DateMath.nextMidnight(after: now)] {
            XCTAssertTrue(dates.contains(expected))
        }
    }

    func testTheDayChangesAtMidnight() {
        let f = Fixture()
        let lateMonday = monday(23, 59)
        XCTAssertEqual(ScheduleGlance.compute(f.state, now: lateMonday).phase, .finished)
        let midnight = DateMath.nextMidnight(after: lateMonday)
        XCTAssertEqual(ScheduleGlance.compute(f.state, now: midnight).phase, .empty, "Tuesday has nothing")
        XCTAssertEqual(ScheduleGlance.compute(f.state, now: lateMonday).nextChange, midnight)
    }

    func testHoursStayWallClockTimesWhateverTheOffset() {
        // 9:00 is 9:00 on the days the clocks change (the occurrence is built from the wall clock).
        let f = Fixture()
        for day in [DateComponents(year: 2026, month: 3, day: 9), DateComponents(year: 2026, month: 11, day: 2), DateComponents(year: 2026, month: 10, day: 26)] {
            var parts = day
            parts.hour = 7
            guard let morning = DateMath.calendar.date(from: parts) else { continue }
            let glance = ScheduleGlance.compute(f.state, now: morning)
            guard let event = glance.event else { return XCTFail("A Monday has events") }
            XCTAssertEqual(DateMath.calendar.component(.hour, from: event.start), 9)
            XCTAssertEqual(DateMath.calendar.component(.minute, from: event.start), 0)
            XCTAssertEqual(glance.nextChange, event.start)
        }
    }
}
