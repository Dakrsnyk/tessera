import XCTest
@testable import Ardane

/// The Planning series: one occurrence deleted or changed alone, the color of an entry, and the single
/// function (`ClassSlot.resolved(on:)`, via `StudentMath.occurrences`) every display reads.
@MainActor
final class PlanningOccurrenceTests: XCTestCase {
    /// A day of 2026 at 9:00 (28 September and 5 October are Mondays).
    private func day(_ day: Int, month: Int = 9) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 9))!
    }

    private func englishState() -> (StudentState, ClassSlot) {
        var state = StudentState()
        let course = Course(name: "Anglais", colorHex: "D6409F")
        state.courses = [course]
        let slot = ClassSlot(courseID: course.id, weekday: 1, startMinute: 9 * 60, endMinute: 10 * 60 + 30, room: "B-12")
        state.slots = [slot]
        return (state, slot)
    }

    func testASeriesFallsEveryWeek() {
        let (state, slot) = englishState()
        XCTAssertEqual(StudentMath.occurrences(state, on: day(28)).count, 1)
        XCTAssertEqual(StudentMath.occurrences(state, on: day(5, month: 10)).count, 1)
        XCTAssertNotNil(slot.resolved(on: day(28)))
        XCTAssertNil(slot.resolved(on: day(29)), "Not on a Tuesday")
    }

    func testDeletingOneOccurrenceKeepsTheOthers() {
        var (state, slot) = englishState()
        state.deleteOccurrence(slot: slot.id, on: day(28))
        XCTAssertTrue(StudentMath.occurrences(state, on: day(28)).isEmpty)
        XCTAssertEqual(StudentMath.occurrences(state, on: day(5, month: 10)).count, 1)
        XCTAssertEqual(state.slots.count, 1, "The series stays")
        slot = state.slots[0]
        XCTAssertNil(slot.resolved(on: day(28)))
    }

    func testDeletingTheSeriesRemovesEverything() {
        var (state, slot) = englishState()
        state.deleteSeries(slot: slot.id)
        XCTAssertTrue(state.slots.isEmpty)
        XCTAssertTrue(StudentMath.occurrences(state, on: day(5, month: 10)).isEmpty)
    }

    func testAOneOffEventIsRemovedByASimpleDeletion() {
        var state = StudentState()
        let once = ClassSlot(courseID: nil, weekday: 1, startMinute: 600, endMinute: 660, kind: .appointment, title: "Dentiste", date: DateMath.startOfDay(day(28)))
        state.slots = [once]
        state.deleteOccurrence(slot: once.id, on: day(28))
        XCTAssertTrue(state.slots.isEmpty)
    }

    func testAnExceptionChangesOneMondayOnly() {
        var (state, slot) = englishState()
        var exception = ClassOverride()
        exception.title = "Examen"
        exception.startMinute = 10 * 60
        exception.endMinute = 12 * 60
        exception.room = "Gymnase"
        exception.colorHex = "E5484D"
        state.setOverride(exception, slot: slot.id, on: day(28))
        slot = state.slots[0]

        let changed = StudentMath.occurrences(state, on: day(28)).first
        XCTAssertEqual(changed.map { state.title(of: $0.slot) }, "Examen")
        XCTAssertEqual(changed?.slot.startMinute, 10 * 60)
        XCTAssertEqual(changed?.slot.endMinute, 12 * 60)
        XCTAssertEqual(changed?.slot.room, "Gymnase")
        XCTAssertEqual(changed.map { state.colorHex(of: $0.slot) }, "E5484D")
        XCTAssertEqual(changed?.base.startMinute, 9 * 60, "The stored series is untouched")

        let next = StudentMath.occurrences(state, on: day(5, month: 10)).first
        XCTAssertEqual(next.map { state.title(of: $0.slot) }, "Anglais")
        XCTAssertEqual(next?.slot.startMinute, 9 * 60)
        XCTAssertEqual(next?.slot.room, "B-12")
        XCTAssertEqual(next.map { state.colorHex(of: $0.slot) }, "D6409F")
        XCTAssertEqual(slot.resolved(on: day(28))?.room, "Gymnase")
    }

    func testAnExceptionBuiltFromAnEditedCopy() {
        let (_, slot) = englishState()
        var edited = slot
        edited.title = "Examen"
        edited.startMinute = 14 * 60
        edited.endMinute = 16 * 60
        let exception = slot.override(making: edited)
        XCTAssertEqual(exception?.title, "Examen")
        XCTAssertEqual(exception?.startMinute, 14 * 60)
        XCTAssertNil(exception?.room, "What didn't change stays out")
        XCTAssertNil(slot.override(making: slot))
    }

    func testAnInvalidExceptionTimeIsIgnored() {
        var (state, slot) = englishState()
        var exception = ClassOverride()
        exception.startMinute = 12 * 60
        exception.endMinute = 11 * 60
        state.setOverride(exception, slot: slot.id, on: day(28))
        slot = state.slots[0]
        XCTAssertEqual(slot.resolved(on: day(28))?.startMinute, 9 * 60)
    }

    func testTheColorIsTheTypeOneUnlessChosen() {
        var state = StudentState()
        var work = ClassSlot(courseID: nil, weekday: 1, startMinute: 600, endMinute: 660, kind: .work, title: "Boulot")
        XCTAssertEqual(state.colorHex(of: work), ScheduleKind.work.colorHex)
        work.colorHex = "12A594"
        XCTAssertEqual(state.colorHex(of: work), "12A594")
        state.slots = [work]
        let shown = StudentMath.occurrences(state, on: day(28)).first
        XCTAssertEqual(shown.map { state.colorHex(of: $0.slot) }, "12A594")
        let (classes, english) = englishState()
        XCTAssertEqual(classes.colorHex(of: english), "D6409F", "A class keeps its course's color")
    }

    func testTheHourHoldsAcrossAClockChange() {
        let (state, _) = englishState()
        // 8 March 2026 is the spring change in North America; 2 and 9 March are Mondays.
        let before = StudentMath.occurrences(state, on: day(2, month: 3)).first
        let after = StudentMath.occurrences(state, on: day(9, month: 3)).first
        XCTAssertEqual(before.map { DateMath.calendar.component(.hour, from: $0.start) }, 9)
        XCTAssertEqual(after.map { DateMath.calendar.component(.hour, from: $0.start) }, 9)
        XCTAssertEqual(after.map { DateMath.calendar.component(.minute, from: $0.end) }, 30)
    }

    func testOldDataWithoutTheNewFieldsStillReads() throws {
        let json = #"{"weekday": 2, "startMinute": 480, "endMinute": 540, "room": "B-12", "skippedDays": ["2026-09-29"]}"#
        let slot = try JSONDecoder().decode(ClassSlot.self, from: Data(json.utf8))
        XCTAssertNil(slot.colorHex)
        XCTAssertTrue(slot.overrides.isEmpty)
        XCTAssertEqual(slot.skippedDays, ["2026-09-29"])
    }

    func testExceptionsAndColorSurviveASaveAndReload() throws {
        var (state, slot) = englishState()
        slot.colorHex = "3366FF"
        state.slots = [slot]
        var exception = ClassOverride()
        exception.title = "Examen"
        state.setOverride(exception, slot: slot.id, on: day(28))
        let data = try JSONEncoder().encode(state)
        let back = try JSONDecoder().decode(StudentState.self, from: data)
        XCTAssertEqual(back.slots.first?.colorHex, "3366FF")
        XCTAssertEqual(back.slots.first?.overrides[DateMath.dayKey(day(28))]?.title, "Examen")
        XCTAssertEqual(StudentMath.occurrences(back, on: day(28)).first.map { back.title(of: $0.slot) }, "Examen")
    }
}
