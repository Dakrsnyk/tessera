import XCTest
@testable import Ardane

/// The figures of the hybrid Études screens (direction 5, 2026-11-17): the dates to come (exams, homework, end of
/// the session), their groups, the revision goal of an exam, the history of the study sessions and the old saves.
/// No translated text is compared here: the tests run in the language of the simulator.
final class StudiesHybridTests: XCTestCase {
    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    /// Thursday 12 November 2026 at 13:20, the day of the mock-ups.
    private var now: Date { date(11, 12, 13).addingTimeInterval(20 * 60) }

    private func sample() -> (StudentState, Course) {
        var state = StudentState()
        let course = Course(name: "Statistiques")
        state.courses = [course]
        state.exams = [
            Exam(courseID: course.id, title: "Intra", date: date(11, 16, 9), room: "A-101"),
            Exam(courseID: course.id, title: "Passé", date: date(11, 2, 9)),
        ]
        state.assignments = [
            Assignment(courseID: course.id, title: "Rapport", due: date(11, 13, 23)),
            Assignment(courseID: course.id, title: "En retard", due: date(11, 10, 23)),
            Assignment(courseID: course.id, title: "Rendu", due: date(11, 14, 23), isDone: true),
            Assignment(courseID: course.id, title: "Plus tard", due: date(12, 5, 23)),
        ]
        state.semesterStart = date(9, 1)
        state.semesterEnd = date(12, 18)
        return (state, course)
    }

    func testDeadlinesGatherExamsHomeworkAndTheEndOfTheSession() {
        let (state, _) = sample()
        let list = Studies.deadlines(state, at: now)
        // The late homework, tomorrow's, the exam of the 16th, the later homework and the end of the session.
        XCTAssertEqual(list.count, 5, "The passed exam and the homework handed in stay out")
        XCTAssertEqual(list.map(\.date), list.map(\.date).sorted(), "Nearest date first")
        XCTAssertEqual(list.filter(\.isExam).count, 1)
        XCTAssertEqual(list.filter(\.isAssignment).count, 3)
        XCTAssertEqual(list.last?.id, "session")
    }

    func testTheEndOfThePastSessionIsNotADeadline() {
        var (state, _) = sample()
        state.semesterEnd = date(11, 1)
        XCTAssertFalse(Studies.deadlines(state, at: now).contains { $0.id == "session" })
        state.semesterEnd = nil
        XCTAssertFalse(Studies.deadlines(state, at: now).contains { $0.id == "session" })
        state.semesterEnd = date(11, 12, 8)
        XCTAssertTrue(Studies.deadlines(state, at: now).contains { $0.id == "session" }, "The last day still counts")
    }

    func testDeadlinesAreGroupedLikeTheHomeworkPage() {
        let (state, _) = sample()
        let groups = Studies.deadlineGroups(Studies.deadlines(state, at: now), at: now)
        XCTAssertEqual(groups.late.count, 1, "Only homework can be late")
        XCTAssertEqual(groups.thisWeek.count, 2, "Tomorrow's homework and the exam of the 16th")
        XCTAssertEqual(groups.later.count, 2, "The homework of 5 December and the end of the session")
    }

    func testTheExamBadgeCountsDays() {
        XCTAssertEqual(Studies.examBadge(daysLeft: 4), tr("J-\(4)"))
        XCTAssertEqual(Studies.examBadge(daysLeft: 0), tr("Auj."))
        XCTAssertEqual(Studies.examBadge(daysLeft: -2), tr("Auj."))
    }

    func testTheCalendarMarksTheKindsOfDate() {
        let (state, _) = sample()
        let list = Studies.deadlines(state, at: now)
        let examDay = Studies.marks(on: date(11, 16, 15), in: list)
        XCTAssertTrue(examDay.exam)
        XCTAssertFalse(examDay.assignment)
        let homeworkDay = Studies.marks(on: date(11, 13, 8), in: list)
        XCTAssertTrue(homeworkDay.assignment)
        XCTAssertFalse(homeworkDay.exam)
        XCTAssertTrue(Studies.marks(on: date(12, 18, 8), in: list).session)
        let empty = Studies.marks(on: date(11, 20, 8), in: list)
        XCTAssertFalse(empty.exam || empty.assignment || empty.session)
    }

    func testTheRevisionGoalCountsThePast14DaysOfTheCourse() {
        var (state, course) = sample()
        var exam = state.exams[0]
        XCTAssertNil(Studies.examPreparation(state, exam: exam, now: now), "No goal, no figure")
        exam.studyGoalMinutes = 480
        state.logStudy(minutes: 100, courseID: course.id, at: date(11, 10))
        state.logStudy(minutes: 165, courseID: course.id, at: date(11, 11))
        state.logStudy(minutes: 60, courseID: nil, at: date(11, 11))
        state.logStudy(minutes: 90, courseID: course.id, at: date(10, 1))
        let prep = Studies.examPreparation(state, exam: exam, now: now)
        XCTAssertEqual(prep?.studied, 265, "Another course, no course and older sessions do not count")
        XCTAssertEqual(prep?.goal, 480)
        exam.courseID = nil
        XCTAssertNil(Studies.examPreparation(state, exam: exam, now: now), "An exam without a course has no time to read")
    }

    func testAStudySessionIsRemovedOrCorrected() {
        var (state, course) = sample()
        state.logStudy(minutes: 25, courseID: course.id, at: date(11, 10))
        state.logStudy(minutes: 45, courseID: nil, at: date(11, 11))
        let first = state.sessions[0]
        state.updateSession(first, minutes: 30)
        XCTAssertEqual(state.sessions.map(\.minutes), [30, 45])
        state.updateSession(state.sessions[1], minutes: 900)
        XCTAssertEqual(state.sessions[1].minutes, 240, "Four hours at most, like the timer")
        state.updateSession(state.sessions[1], minutes: 0)
        XCTAssertEqual(state.sessions[1].minutes, 1, "A minute at least")
        state.removeSession(state.sessions[0])
        XCTAssertEqual(state.sessions.count, 1)
        XCTAssertEqual(state.sessions[0].courseID, nil)
        // A session that is no longer there changes nothing.
        state.removeSession(first)
        state.updateSession(first, minutes: 99)
        XCTAssertEqual(state.sessions.count, 1)
    }

    func testAnOldExamSaveStillDecodes() throws {
        let json = #"{"id":"4F9D1B7A-2C55-4E0B-9B0F-0A5C5C5C5C01","title":"Intra","date":1000,"room":"B-204"}"#
        let exam = try JSONDecoder().decode(Exam.self, from: Data(json.utf8))
        XCTAssertEqual(exam.title, "Intra")
        XCTAssertEqual(exam.room, "B-204")
        XCTAssertNil(exam.studyGoalMinutes)
        // A broken goal does not lose the exam.
        let broken = #"{"id":"4F9D1B7A-2C55-4E0B-9B0F-0A5C5C5C5C02","title":"Final","date":1000,"studyGoalMinutes":"beaucoup"}"#
        let kept = try JSONDecoder().decode(Exam.self, from: Data(broken.utf8))
        XCTAssertEqual(kept.title, "Final")
        XCTAssertNil(kept.studyGoalMinutes)
    }

    func testTheRevisionGoalSurvivesASaveAndALoad() throws {
        var exam = Exam(courseID: nil, title: "Final", date: date(12, 15, 9))
        exam.studyGoalMinutes = 600
        let data = try JSONEncoder().encode(exam)
        let back = try JSONDecoder().decode(Exam.self, from: data)
        XCTAssertEqual(back.studyGoalMinutes, 600)
        XCTAssertEqual(back, exam)
    }
}
