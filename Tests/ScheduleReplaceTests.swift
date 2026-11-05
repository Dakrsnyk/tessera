import XCTest
@testable import Ardane

/// « Ajouter ou remplacer »: replacing removes only the weekly classes, never the other entries or the courses.
final class ScheduleReplaceTests: XCTestCase {
    private func imported(_ title: String, day: Int = 1) -> ImportedSlot {
        ImportedSlot(weekday: day, startMinute: 9 * 60, endMinute: 10 * 60, title: title)
    }

    private func stateWithSchedule() -> StudentState {
        var state = StudentState()
        let course = Course(name: "Chimie")
        state.courses = [course]
        state.slots = [
            ClassSlot(courseID: course.id, weekday: 2, startMinute: 8 * 60, endMinute: 9 * 60),
            ClassSlot(courseID: nil, weekday: 3, startMinute: 18 * 60, endMinute: 19 * 60, kind: .work, title: "Épicerie"),
            ClassSlot(courseID: nil, weekday: 4, startMinute: 12 * 60, endMinute: 13 * 60, kind: .appointment, title: "Dentiste", date: Date()),
        ]
        return state
    }

    func testHasScheduleOnlyWithAWeeklyClass() {
        XCTAssertFalse(ScheduleImportMerge.hasSchedule(StudentState()))
        var state = stateWithSchedule()
        XCTAssertTrue(ScheduleImportMerge.hasSchedule(state))
        state.slots.removeAll { ScheduleImportMerge.isWeeklyClass($0) }
        XCTAssertFalse(ScheduleImportMerge.hasSchedule(state), "Work and appointments are not a schedule")
    }

    func testReplaceRemovesOldClassesButKeepsEventsAndCourses() {
        let state = stateWithSchedule()
        let result = ScheduleImportMerge.replace([imported("Physique")], in: state)
        XCTAssertEqual(result.added, 1)
        let classes = result.state.slots.filter(ScheduleImportMerge.isWeeklyClass)
        XCTAssertEqual(classes.count, 1)
        XCTAssertEqual(classes.first?.weekday, 1)
        XCTAssertEqual(result.state.slots.filter { $0.kind == .work }.count, 1)
        XCTAssertEqual(result.state.slots.filter { $0.kind == .appointment }.count, 1)
        XCTAssertTrue(result.state.courses.contains { $0.name == "Chimie" }, "Courses are kept")
        XCTAssertTrue(result.state.courses.contains { $0.name == "Physique" })
    }

    func testReplaceWithTheSameClassKeepsOneAndAddIsNotDoubled() {
        let state = stateWithSchedule()
        let same = ImportedSlot(weekday: 2, startMinute: 8 * 60, endMinute: 9 * 60, title: "Chimie")
        let replaced = ScheduleImportMerge.replace([same], in: state)
        XCTAssertEqual(replaced.state.slots.filter(ScheduleImportMerge.isWeeklyClass).count, 1)
        let added = ScheduleImportMerge.merge([same], into: state)
        XCTAssertEqual(added.added, 0, "Adding the same class does not double it")
        XCTAssertEqual(added.state.slots.filter(ScheduleImportMerge.isWeeklyClass).count, 1)
    }

    func testReplaceDoesNotChangeOtherData() {
        var state = stateWithSchedule()
        state.exams = [Exam(courseID: state.courses[0].id, title: "Final", date: Date())]
        let result = ScheduleImportMerge.replace([imported("Physique")], in: state)
        XCTAssertEqual(result.state.exams, state.exams)
    }
}
