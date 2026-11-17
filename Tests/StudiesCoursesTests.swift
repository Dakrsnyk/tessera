import XCTest
@testable import Ardane

/// One course per name: a course added by hand and the same course read from a timetable (photo, PDF) are one
/// course, whichever comes first; an existing course keeps its fields, only its empty ones are completed.
final class StudiesCoursesTests: XCTestCase {
    func testKeyIgnoresCaseAccentsSpacesAndPunctuation() {
        XCTAssertEqual(CourseMatch.key("Mathématiques 101"), CourseMatch.key("  mathematiques   101 "))
        XCTAssertEqual(CourseMatch.key("Intro. à la bio"), CourseMatch.key("INTRO A LA BIO"))
        XCTAssertEqual(CourseMatch.key("Histoire-Géo"), CourseMatch.key("histoire géo"))
        XCTAssertEqual(CourseMatch.key("Anglais (B2)"), "anglais b2")
        XCTAssertNotEqual(CourseMatch.key("Maths 101"), CourseMatch.key("Maths 102"))
        XCTAssertEqual(CourseMatch.key("  ...  "), "")
    }

    func testByHandThenScannedIsOneCourse() {
        var state = StudentState()
        state.courses.append(Course(name: "Biologie"))
        let scanned = state.ensureCourse(named: "  biologie ", teacher: "Mme Roy")
        XCTAssertEqual(state.courses.count, 1)
        XCTAssertEqual(scanned, state.courses[0].id)
        XCTAssertEqual(state.courses[0].teacher, "Mme Roy", "The empty teacher is completed")
    }

    func testScannedThenByHandIsOneCourse() {
        var state = StudentState()
        let first = state.ensureCourse(named: "Histoire", teacher: "M. Gagnon", colorHex: "3366FF")
        let second = state.ensureCourse(named: "HISTOIRE", teacher: "Autre", colorHex: "E5484D")
        XCTAssertEqual(first, second)
        XCTAssertEqual(state.courses.count, 1)
        XCTAssertEqual(state.courses[0].teacher, "M. Gagnon", "A filled field is never overwritten")
        XCTAssertEqual(state.courses[0].colorHex, "3366FF")
        XCTAssertEqual(state.course(matching: "histoire")?.id, first)
    }

    func testNewNameCreatesACourse() {
        var state = StudentState()
        state.ensureCourse(named: "Chimie")
        let other = state.ensureCourse(named: "Physique", teacher: "Mme Roy", colorHex: "30A46C")
        XCTAssertEqual(state.courses.count, 2)
        XCTAssertEqual(state.course(other)?.colorHex, "30A46C")
        XCTAssertNil(state.course(matching: "Géographie"))
        XCTAssertNil(state.course(matching: "   "))
    }

    func testOldStudentJSONStillReads() throws {
        let id = UUID()
        let json = """
        {"courses":[{"id":"\(id.uuidString)","name":"Maths","teacher":"M. Roy"}],"exams":[{"title":"Final","date":0}],"weeklyStudyGoalHours":8}
        """
        let state = try JSONDecoder().decode(StudentState.self, from: Data(json.utf8))
        XCTAssertEqual(state.courses.count, 1)
        XCTAssertEqual(state.courses[0].id, id)
        XCTAssertEqual(state.courses[0].credits, 3)
        XCTAssertEqual(state.exams.count, 1)
        XCTAssertEqual(state.weeklyStudyGoalHours, 8)
        XCTAssertEqual(state.course(matching: "maths")?.id, id)
    }
}
