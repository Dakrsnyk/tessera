import XCTest
@testable import Tessera

/// The study timer on the Lock Screen: what its Live Activity shows.
final class StudyLiveActivityTests: XCTestCase {
    /// Wednesday 14 October 2026, 19 h: the middle of a week.
    private let now = DateMath.calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 19))!

    func testNoTimerNoLiveActivity() {
        XCTAssertNil(StudyLiveActivity.content(for: StudentState(), now: now))
    }

    func testTheLiveActivityShowsTheCourseAndTheWeek() throws {
        let course = Course(name: "Chimie", colorHex: "3366FF")
        var state = StudentState()
        state.courses = [course]
        state.weeklyStudyGoalHours = 10
        state.logStudy(minutes: 90, courseID: course.id, at: now.addingTimeInterval(-3 * 3600))
        state.logStudy(minutes: 30, courseID: nil, at: now.addingTimeInterval(-3600))
        // Two weeks ago: not in this week.
        state.logStudy(minutes: 60, courseID: nil, at: now.addingTimeInterval(-14 * 86_400))
        let start = now.addingTimeInterval(-600)
        state.startTimer(courseID: course.id, at: start)

        let content = try XCTUnwrap(StudyLiveActivity.content(for: state, now: now))
        XCTAssertEqual(content.0.courseName, "Chimie")
        XCTAssertEqual(content.0.colorHex, "3366FF")
        XCTAssertEqual(content.1.start, start)
        XCTAssertEqual(content.1.weekMinutesBefore, 120, "The running timer is not counted twice")
        XCTAssertEqual(content.1.weeklyGoalMinutes, 600)
        XCTAssertEqual(content.1.cap.timeIntervalSince(start), 4 * 3600, accuracy: 1)
    }

    func testATimerWithoutCourse() throws {
        var state = StudentState()
        state.weeklyStudyGoalHours = 2.5
        state.startTimer(courseID: nil, at: now)
        let content = try XCTUnwrap(StudyLiveActivity.content(for: state, now: now))
        XCTAssertEqual(content.0.courseName, "Étude")
        XCTAssertEqual(content.0.colorHex, ScheduleKind.course.colorHex)
        XCTAssertEqual(content.1.weekMinutesBefore, 0)
        XCTAssertEqual(content.1.weeklyGoalMinutes, 150)
    }

    func testStoppingOrCancellingEndsTheLiveActivity() {
        var state = StudentState()
        state.startTimer(courseID: nil, at: now)
        XCTAssertEqual(state.stopTimer(at: now.addingTimeInterval(25 * 60)), 25)
        XCTAssertNil(StudyLiveActivity.content(for: state, now: now))
        state.startTimer(courseID: nil, at: now)
        state.timerStart = nil
        state.timerCourseID = nil
        XCTAssertNil(StudyLiveActivity.content(for: state, now: now))
        XCTAssertEqual(state.sessions.count, 1, "Cancelling logs nothing")
    }
}
