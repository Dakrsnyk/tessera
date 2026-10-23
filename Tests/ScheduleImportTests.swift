import XCTest
@testable import Tessera

/// « Importer mon horaire »: the classes read from a photo or a PDF become classes of the schedule, with
/// their course made when missing, and what is already there is never erased or doubled.
final class ScheduleImportTests: XCTestCase {
    private func slot(_ title: String, day: Int = 1, from start: Int = 9 * 60, to end: Int = 10 * 60 + 30,
                      room: String? = nil, selected: Bool = true) -> ImportedSlot {
        ImportedSlot(weekday: day, startMinute: start, endMinute: end, title: title, room: room, isSelected: selected)
    }

    func testAClassBecomesAWeeklySlotAndItsCourse() {
        let result = ScheduleImportMerge.merge([slot("Chimie", day: 3, from: 8 * 60 + 30, to: 10 * 60 + 20, room: " B-12 ")], into: StudentState())
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.state.courses.map(\.name), ["Chimie"])
        let created = result.state.slots.first
        XCTAssertEqual(created?.courseID, result.state.courses.first?.id)
        XCTAssertEqual(created?.weekday, 3)
        XCTAssertEqual(created?.startMinute, 8 * 60 + 30)
        XCTAssertEqual(created?.endMinute, 10 * 60 + 20)
        XCTAssertEqual(created?.room, "B-12", "The room without the spaces around it")
        XCTAssertEqual(created?.kind, .course)
        XCTAssertNil(created?.date, "A class of the timetable comes back every week")
    }

    func testAnExistingCourseIsReusedWhateverItsCase() {
        var state = StudentState()
        let course = Course(name: "Mathématiques")
        state.courses = [course]
        let result = ScheduleImportMerge.merge([slot(" MATHEMATIQUES "), slot("mathématiques", day: 4)], into: state)
        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(result.state.courses.count, 1, "No second course with the same name")
        XCTAssertEqual(result.state.slots.map(\.courseID), [course.id, course.id])
    }

    func testTwoClassesOfTheSameNewCourseMakeOneCourse() {
        let result = ScheduleImportMerge.merge([slot("Physique", day: 1), slot("Physique", day: 3)], into: StudentState())
        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(result.state.courses.count, 1)
        XCTAssertEqual(result.state.slots.count, 2)
    }

    func testAnIdenticalSlotIsNotAddedTwice() {
        var state = StudentState()
        let course = Course(name: "Chimie")
        state.courses = [course]
        state.slots = [ClassSlot(courseID: course.id, weekday: 1, startMinute: 9 * 60, endMinute: 10 * 60 + 30, room: "A-1")]
        let first = ScheduleImportMerge.merge([slot("chimie"), slot("Chimie", day: 2)], into: state)
        XCTAssertEqual(first.added, 1, "Monday 9:00 is already there, Tuesday is new")
        XCTAssertEqual(first.state.slots.count, 2)
        // Importing the same photo again adds nothing.
        let again = ScheduleImportMerge.merge([slot("chimie"), slot("Chimie", day: 2)], into: first.state)
        XCTAssertEqual(again.added, 0)
        XCTAssertEqual(again.state, first.state)
        // The same class twice in one photo is added once.
        let twice = ScheduleImportMerge.merge([slot("Anglais"), slot("Anglais")], into: StudentState())
        XCTAssertEqual(twice.added, 1)
    }

    func testOtherHoursOrDaysAreNotDuplicates() {
        var state = StudentState()
        let course = Course(name: "Chimie")
        state.courses = [course]
        state.slots = [ClassSlot(courseID: course.id, weekday: 1, startMinute: 9 * 60, endMinute: 10 * 60)]
        let result = ScheduleImportMerge.merge([slot("Chimie", day: 1, from: 9 * 60, to: 11 * 60), slot("Chimie", day: 1, from: 13 * 60, to: 14 * 60)], into: state)
        XCTAssertEqual(result.added, 2)
    }

    func testExistingEntriesStayUntouched() {
        var state = StudentState()
        let course = Course(name: "Chimie", colorHex: "3366FF", teacher: "Mme Roy", credits: 4)
        let dentist = ClassSlot(courseID: nil, weekday: 2, startMinute: 9 * 60, endMinute: 10 * 60, kind: .appointment, title: "Dentiste")
        let once = ClassSlot(courseID: course.id, weekday: 1, startMinute: 9 * 60, endMinute: 10 * 60 + 30, date: Date(timeIntervalSince1970: 1_800_000_000))
        state.courses = [course]
        state.slots = [dentist, once]
        let result = ScheduleImportMerge.merge([slot("Chimie")], into: state)
        XCTAssertEqual(result.added, 1, "A class of one day only is not the weekly class")
        XCTAssertEqual(Array(result.state.slots.prefix(2)), [dentist, once], "Nothing existing is removed or changed")
        XCTAssertEqual(result.state.courses, [course])
    }

    func testUntickedOrInvalidSlotsAreLeftOut() {
        let result = ScheduleImportMerge.merge([
            slot("Décoché", selected: false),
            slot("   "),
            slot("Fin avant début", from: 10 * 60, to: 9 * 60),
            slot("Durée nulle", from: 9 * 60, to: 9 * 60),
            slot("Jour inconnu", day: 8),
            slot("Valide", day: 5),
        ], into: StudentState())
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.state.courses.map(\.name), ["Valide"], "No course made for a slot left out")
        XCTAssertEqual(ScheduleImportMerge.importable([slot("A"), slot("B", selected: false)]).count, 1)
    }

    func testAnEmptyImportChangesNothing() {
        var state = StudentState()
        state.courses = [Course(name: "Chimie")]
        let result = ScheduleImportMerge.merge([], into: state)
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.state, state)
    }

    func testNewCoursesGetDifferentColors() {
        let result = ScheduleImportMerge.merge([slot("A"), slot("B", day: 2), slot("C", day: 3)], into: StudentState())
        XCTAssertEqual(Set(result.state.courses.map(\.colorHex)).count, 3)
    }
}
