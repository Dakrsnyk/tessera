import XCTest
@testable import Ardane

/// « Importer mon horaire » with entries that are not weekly classes: shifts of a work schedule, appointments with or without
/// a date, another event, and the teacher read with a class. What is already in the Planning is never erased nor doubled,
/// « Remplacer » only removes the weekly classes, and a teacher already entered is never overwritten.
final class ScheduleImportKindsTests: XCTestCase {
    private func day(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try XCTUnwrap(ScheduleDates.day(year: year, month: month, day: day))
    }

    private func entry(_ title: String, kind: ScheduleKind, day weekday: Int = 2, from start: Int = 14 * 60 + 30,
                       to end: Int = 15 * 60 + 30, room: String? = nil, date: Date? = nil, detail: String? = nil) -> ImportedSlot {
        ImportedSlot(weekday: weekday, startMinute: start, endMinute: end, title: title, room: room, kind: kind, date: date,
                     detail: detail)
    }

    // MARK: Adding

    func testAShiftBecomesAWorkEntryWithoutACourse() {
        let result = ScheduleImportMerge.merge([entry("Caisse", kind: .work, day: 1, from: 9 * 60, to: 17 * 60)], into: StudentState())
        XCTAssertEqual(result.added, 1)
        XCTAssertTrue(result.state.courses.isEmpty, "A shift is not a course")
        let slot = result.state.slots.first
        XCTAssertEqual(slot?.kind, .work)
        XCTAssertEqual(slot?.title, "Caisse")
        XCTAssertNil(slot?.courseID)
        XCTAssertNil(slot?.date, "A weekly shift comes back every week")
        XCTAssertEqual(slot?.weekday, 1)
    }

    func testADatedAppointmentKeepsItsDatePlaceAndPerson() throws {
        let date = try day(2026, 11, 24)
        let result = ScheduleImportMerge.merge([entry("Dentiste", kind: .appointment, day: 5, room: " Clinique du Parc ", date: date,
                                                      detail: "Dr Roy")], into: StudentState())
        XCTAssertEqual(result.added, 1)
        let slot = result.state.slots.first
        XCTAssertEqual(slot?.kind, .appointment)
        XCTAssertEqual(slot?.title, "Dentiste · Dr Roy")
        XCTAssertEqual(slot?.room, "Clinique du Parc")
        XCTAssertEqual(slot?.date, DateMath.startOfDay(date))
        XCTAssertEqual(slot?.weekday, 2, "The weekday follows the date (24 November 2026 is a Tuesday), not the day given")
        XCTAssertTrue(result.state.courses.isEmpty)
    }

    func testAnEntryWithoutATitleIsNamedByItsPersonOrItsKind() {
        XCTAssertTrue(ScheduleImportMerge.isValid(entry("", kind: .work)), "A shift may have no name")
        XCTAssertFalse(ScheduleImportMerge.isValid(entry("", kind: .course)), "A class needs one")
        let result = ScheduleImportMerge.merge([entry("", kind: .appointment, detail: "Me Tremblay"), entry("", kind: .work, day: 3)],
                                               into: StudentState())
        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(result.state.slots.map(\.title), ["Me Tremblay", ""])
        XCTAssertEqual(result.state.title(of: result.state.slots[1]), ScheduleKind.work.title, "The Planning shows its kind")
    }

    func testAnOtherEventAndADatedClass() throws {
        let date = try day(2026, 11, 26)
        let result = ScheduleImportMerge.merge([
            entry("Portes ouvertes", kind: .other, day: 4),
            entry("Chimie", kind: .course, day: 4, from: 8 * 60, to: 10 * 60, date: date)
        ], into: StudentState())
        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(result.state.slots.first?.kind, .other)
        let chemistry = result.state.slots.last
        XCTAssertEqual(chemistry?.kind, .course)
        XCTAssertEqual(chemistry?.courseID, result.state.courses.first?.id)
        XCTAssertEqual(chemistry?.date, DateMath.startOfDay(date), "A class read on a date happens once")
        XCTAssertFalse(chemistry.map(ScheduleImportMerge.isWeeklyClass) ?? true)
    }

    // MARK: No duplicate

    func testTheSameAppointmentIsAddedOnce() throws {
        let date = try day(2026, 11, 24)
        let dentist = entry("Dentiste", kind: .appointment, date: date, detail: "Dr Roy")
        let first = ScheduleImportMerge.merge([dentist, dentist], into: StudentState())
        XCTAssertEqual(first.added, 1, "The same appointment twice in one document")
        let again = ScheduleImportMerge.merge([entry("dentiste", kind: .appointment, date: date, detail: "DR ROY")], into: first.state)
        XCTAssertEqual(again.added, 0, "Importing it again adds nothing")
        XCTAssertEqual(again.state, first.state)
        // Another date, other hours or another kind is another entry.
        let december = try day(2026, 12, 1)
        let other = ScheduleImportMerge.merge([
            entry("Dentiste", kind: .appointment, date: december, detail: "Dr Roy"),
            entry("Dentiste", kind: .appointment, from: 16 * 60, to: 17 * 60, date: date, detail: "Dr Roy"),
            entry("Dentiste", kind: .other, date: date, detail: "Dr Roy")
        ], into: first.state)
        XCTAssertEqual(other.added, 3)
    }

    func testAWeeklyShiftAlreadyThereIsNotDoubled() {
        var state = StudentState()
        state.slots = [ClassSlot(courseID: nil, weekday: 1, startMinute: 9 * 60, endMinute: 17 * 60, kind: .work, title: "Caisse")]
        let result = ScheduleImportMerge.merge([entry("caisse", kind: .work, day: 1, from: 9 * 60, to: 17 * 60),
                                                entry("Caisse", kind: .work, day: 2, from: 9 * 60, to: 17 * 60)], into: state)
        XCTAssertEqual(result.added, 1, "Monday is there, Tuesday is new")
        XCTAssertEqual(result.state.slots.count, 2)
    }

    func testAnEntryTypedByHandWithoutThePersonIsNotDoubled() throws {
        let date = try day(2026, 11, 24)
        var state = StudentState()
        state.slots = [ClassSlot(courseID: nil, weekday: 2, startMinute: 14 * 60 + 30, endMinute: 15 * 60 + 30, kind: .appointment,
                                 title: "Dentiste", date: date)]
        let result = ScheduleImportMerge.merge([entry("Dentiste", kind: .appointment, date: date, detail: "Dr Roy")], into: state)
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.state, state)
    }

    // MARK: Replace

    func testAddOrReplaceIsAskedOnlyWhenTheImportBringsWeeklyClasses() throws {
        var state = StudentState()
        let course = Course(name: "Chimie")
        state.courses = [course]
        state.slots = [ClassSlot(courseID: course.id, weekday: 1, startMinute: 8 * 60, endMinute: 9 * 60)]
        let tuesday = try day(2026, 11, 24)
        let appointment = entry("Dentiste", kind: .appointment, date: tuesday)
        let shift = entry("Caisse", kind: .work, day: 6)
        let weekly = entry("Physique", kind: .course, day: 3)
        var unticked = weekly
        unticked.isSelected = false
        XCTAssertFalse(ScheduleImportMerge.asksAddOrReplace([appointment, shift], state: state),
                       "Shifts and appointments only: added directly, « Remplacer » would erase the classes for nothing")
        XCTAssertFalse(ScheduleImportMerge.asksAddOrReplace([appointment, unticked], state: state))
        XCTAssertTrue(ScheduleImportMerge.asksAddOrReplace([appointment, weekly], state: state))
        XCTAssertFalse(ScheduleImportMerge.asksAddOrReplace([weekly], state: StudentState()), "Nothing to replace")
    }

    func testReplaceRemovesOnlyTheWeeklyClassesAndKeepsAppointmentsAndShifts() throws {
        var state = StudentState()
        let course = Course(name: "Chimie")
        state.courses = [course]
        let tuesday = try day(2026, 11, 24)
        let thursday = try day(2026, 11, 26)
        let dentist = ClassSlot(courseID: nil, weekday: 2, startMinute: 14 * 60 + 30, endMinute: 15 * 60 + 30, kind: .appointment,
                                title: "Dentiste · Dr Roy", date: tuesday)
        let shift = ClassSlot(courseID: nil, weekday: 6, startMinute: 9 * 60, endMinute: 17 * 60, kind: .work, title: "Caisse")
        state.slots = [ClassSlot(courseID: course.id, weekday: 1, startMinute: 8 * 60, endMinute: 9 * 60), dentist, shift]
        let result = ScheduleImportMerge.replace([
            entry("Physique", kind: .course, day: 3, from: 10 * 60, to: 11 * 60),
            entry("Notaire", kind: .appointment, day: 4, date: thursday, detail: "Me Tremblay")
        ], in: state)
        XCTAssertEqual(result.added, 2)
        XCTAssertTrue(result.state.slots.contains(dentist), "An appointment already there is kept")
        XCTAssertTrue(result.state.slots.contains(shift), "A shift already there is kept")
        XCTAssertEqual(result.state.slots.filter(ScheduleImportMerge.isWeeklyClass).map(\.weekday), [3], "Only the old weekly classes go")
        XCTAssertTrue(result.state.slots.contains { $0.kind == .appointment && $0.title == "Notaire · Me Tremblay" })
        XCTAssertTrue(result.state.courses.contains { $0.name == "Chimie" }, "Courses are kept")
    }

    // MARK: Teacher

    func testATeacherReadFillsANewCourseAndAnEmptyTeacherButNeverReplacesOne() {
        var state = StudentState()
        let empty = Course(name: "Chimie")
        let taught = Course(name: "Physique", teacher: "Mme Roy")
        state.courses = [empty, taught]
        let result = ScheduleImportMerge.merge([
            entry("Chimie", kind: .course, day: 1, from: 8 * 60, to: 9 * 60, detail: "M. Gagnon"),
            entry("Physique", kind: .course, day: 2, from: 8 * 60, to: 9 * 60, detail: "Dr Martin"),
            entry("Biologie", kind: .course, day: 3, from: 8 * 60, to: 9 * 60, detail: "Dupont J.")
        ], into: state)
        XCTAssertEqual(result.added, 3)
        XCTAssertEqual(result.state.courses.first { $0.name == "Chimie" }?.teacher, "M. Gagnon", "An empty teacher is filled")
        XCTAssertEqual(result.state.courses.first { $0.name == "Physique" }?.teacher, "Mme Roy", "A teacher entered is never replaced")
        XCTAssertEqual(result.state.courses.first { $0.name == "Biologie" }?.teacher, "Dupont J.", "A new course gets the teacher read")
        XCTAssertEqual(result.state.courses.count, 3)
    }

    func testATeacherIsFilledEvenWhenTheClassIsAlreadyThere() {
        var state = StudentState()
        let course = Course(name: "Chimie")
        state.courses = [course]
        state.slots = [ClassSlot(courseID: course.id, weekday: 1, startMinute: 8 * 60, endMinute: 9 * 60)]
        let result = ScheduleImportMerge.merge([entry("Chimie", kind: .course, day: 1, from: 8 * 60, to: 9 * 60, detail: "M. Gagnon")],
                                               into: state)
        XCTAssertEqual(result.added, 0, "The class is not doubled")
        XCTAssertEqual(result.state.courses.first?.teacher, "M. Gagnon")
    }
}
