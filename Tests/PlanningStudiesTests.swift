import XCTest
@testable import Tessera

/// The Planning and Studies mini-apps: tasks with a priority, a date and a repeat; one day gathered
/// from every part of Tessera; homework, exams, grades and study time that add up.
@MainActor
final class PlanningStudiesTests: XCTestCase {
    private func temporaryModel() -> AppModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return AppModel(store: SharedStore(directory: directory))
    }

    /// Wednesday 30 September 2026 at the given hour.
    private func wednesday(_ hour: Int, _ minute: Int = 0) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: hour, minute: minute))!
    }

    // MARK: Tasks

    func testARepeatingTaskComesBackAndGoesAwayIfUnchecked() {
        var content = ContentState()
        let today = DateMath.startOfDay(wednesday(9))
        content.tasks = [TaskItem(title: "Arroser", priority: .medium, due: today, repeats: .daily)]
        let id = content.tasks[0].id
        content.toggleTask(id, at: wednesday(10))
        XCTAssertEqual(content.tasks.count, 2)
        let next = content.tasks[1]
        XCTAssertFalse(next.isDone)
        XCTAssertEqual(next.priority, .medium)
        XCTAssertTrue(next.isDue(on: wednesday(12).addingTimeInterval(86_400)))
        // Unchecked by mistake: the next occurrence goes away with it.
        content.toggleTask(id, at: wednesday(10))
        XCTAssertEqual(content.tasks.count, 1, "Unchecking removes the copy it had created")
        XCTAssertFalse(content.tasks[0].isDone)

        // In the week, Friday comes after Thursday, Monday after Friday.
        let friday = DateMath.calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 9))!
        let monday = TaskRepeat.weekdays.next(after: friday)!
        XCTAssertEqual(FitnessMath.isoWeekday(monday), 1)
    }

    func testOverdueAndOlderTasksStillOpen() throws {
        let yesterday = wednesday(9).addingTimeInterval(-86_400)
        XCTAssertTrue(TaskItem(title: "A", due: yesterday).isOverdue(at: wednesday(9)))
        XCTAssertFalse(TaskItem(title: "B", due: DateMath.startOfDay(wednesday(9))).isOverdue(at: wednesday(22)), "Due today without a time: not late today")
        XCTAssertTrue(TaskItem(title: "C", due: wednesday(8), hasTime: true).isOverdue(at: wednesday(9)))
        XCTAssertFalse(TaskItem(title: "D", isDone: true, due: yesterday).isOverdue(at: wednesday(9)))

        let json = #"{"id":"8A1B2C3D-0000-0000-0000-000000000002","title":"Ancienne tâche","isDone":false,"createdAt":0}"#
        let task = try JSONDecoder().decode(TaskItem.self, from: Data(json.utf8))
        XCTAssertEqual(task.title, "Ancienne tâche")
        XCTAssertEqual(task.priority, .none)
        XCTAssertNil(task.due)
        XCTAssertEqual(task.repeats, .never)
    }

    func testADayGathersEveryPartInOrder() {
        let model = temporaryModel()
        let now = wednesday(7)
        let course = Course(name: "Chimie", colorHex: "3366FF")
        model.update(\.student) { state in
            state.courses = [course]
            state.slots = [ClassSlot(courseID: course.id, weekday: 3, startMinute: 10 * 60, endMinute: 12 * 60, room: "B-12")]
            state.assignments = [Assignment(courseID: course.id, title: "Labo", due: wednesday(23, 59))]
            state.exams = [Exam(courseID: course.id, title: "Quiz", date: wednesday(14))]
        }
        model.updateContent { content in
            content.tasks = [TaskItem(title: "Courses", due: DateMath.startOfDay(now)), TaskItem(title: "Appel", due: wednesday(9), hasTime: true), TaskItem(title: "Demain", due: wednesday(9).addingTimeInterval(86_400))]
        }
        let event = EventSnapshot(id: "e", title: "Dentiste", start: wednesday(16), end: wednesday(17), isAllDay: false, colorHex: "FF6B57")
        let items = Agenda.items(on: now, model: model, events: [event])
        XCTAssertEqual(items.filter { $0.start != nil }.map(\.title), ["Appel", "Chimie", "Examen : Quiz", "Dentiste"])
        XCTAssertEqual(Set(items.filter { $0.start == nil }.map(\.title)), ["Courses", "Labo"], "Things of the day without a time come first")
        XCTAssertFalse(items.contains { $0.title == "Demain" })
        XCTAssertNotNil(items.first { $0.title == "Appel" }?.taskID)
        XCTAssertNotNil(items.first { $0.title == "Labo" }?.assignmentID)

        let week = Agenda.week(containing: now, model: model, events: [])
        XCTAssertEqual(week.count, 7)
        XCTAssertTrue(week[3].items.contains { $0.title == "Demain" })
    }

    // MARK: Studies

    func testHomeworkIsSortedByWhenItIsDue() {
        var state = StudentState()
        let now = wednesday(12)
        state.assignments = [
            Assignment(title: "Plus tard", due: now.addingTimeInterval(10 * 86_400)),
            Assignment(title: "En retard", due: now.addingTimeInterval(-3_600)),
            Assignment(title: "Demain", due: now.addingTimeInterval(86_400)),
            Assignment(title: "Rendu", due: now.addingTimeInterval(-86_400), isDone: true),
        ]
        let groups = StudentMath.assignmentGroups(state, at: now)
        XCTAssertEqual(groups.late.map(\.title), ["En retard"])
        XCTAssertEqual(groups.thisWeek.map(\.title), ["Demain"])
        XCTAssertEqual(groups.later.map(\.title), ["Plus tard"])
    }

    func testWhatItTakesToReachAGoal() {
        var state = StudentState()
        let course = Course(name: "Maths")
        state.courses = [course]
        // 16/20 for 20 % and 70/100 for 30 %: 50 % of the course evaluated, 74 % so far.
        state.grades = [
            Grade(courseID: course.id, title: "Quiz", score: 16, maxScore: 20, weight: 20),
            Grade(courseID: course.id, title: "Intra", score: 70, maxScore: 100, weight: 30),
        ]
        XCTAssertEqual(StudentMath.courseAverage(state, course: course.id)!, 74, accuracy: 0.01)
        XCTAssertEqual(StudentMath.evaluatedWeight(state, course: course.id), 50)
        // 80 % in the end: (16 + 21 + x × 50) / 100 = 80 → x = 86 %.
        XCTAssertEqual(StudentMath.neededAverage(state, course: course.id, target: 80)!, 86, accuracy: 0.01)
        XCTAssertLessThan(StudentMath.neededAverage(state, course: course.id, target: 30)!, 0, "Already reached")
        XCTAssertGreaterThan(StudentMath.neededAverage(state, course: course.id, target: 95)!, 100, "Out of reach")
        state.grades.append(Grade(courseID: course.id, title: "Final", score: 90, maxScore: 100, weight: 50))
        XCTAssertNil(StudentMath.neededAverage(state, course: course.id, target: 80), "Nothing left to evaluate")
    }

    func testTheStudyTimerAddsItsTimeToTheWeek() {
        var state = StudentState()
        let course = Course(name: "Bio")
        state.courses = [course]
        state.startTimer(courseID: course.id, at: wednesday(19))
        XCTAssertEqual(state.stopTimer(at: wednesday(19, 50)), 50)
        XCTAssertNil(state.timerStart)
        XCTAssertEqual(StudentMath.studyMinutes(state, weekOf: wednesday(20)), 50)
        XCTAssertEqual(StudentMath.studyMinutes(state, course: course.id, from: wednesday(0), to: wednesday(23)), 50)
        // Too short to count.
        state.startTimer(courseID: nil, at: wednesday(20))
        XCTAssertEqual(state.stopTimer(at: wednesday(20).addingTimeInterval(20)), 0)
        XCTAssertEqual(state.sessions.count, 1)
        // Forgotten overnight: capped.
        state.startTimer(courseID: nil, at: wednesday(8))
        XCTAssertEqual(state.stopTimer(at: wednesday(23)), 240)

        let weeks = StudentMath.studyByWeek(state, weeks: 4, at: wednesday(21))
        XCTAssertEqual(weeks.count, 4)
        XCTAssertEqual(weeks.last?.minutes, 290)
        XCTAssertEqual(weeks.first?.minutes, 0)

        // The timer survives the app closing, and older saves open without it.
        let back = try? JSONDecoder().decode(StudentState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(back?.sessions.count, 2)
        let old = try? JSONDecoder().decode(StudentState.self, from: Data(#"{"courses":[],"weeklyStudyGoalHours":8}"#.utf8))
        XCTAssertNil(old?.timerStart)
        XCTAssertEqual(old?.weeklyStudyGoalHours, 8)
    }

    func testDeletingACourseKeepsItsGrades() {
        var state = StudentState()
        let course = Course(name: "Histoire")
        state.courses = [course]
        state.slots = [ClassSlot(courseID: course.id, weekday: 1, startMinute: 480, endMinute: 600)]
        state.grades = [Grade(courseID: course.id, title: "Exposé", score: 18, maxScore: 20)]
        state.exams = [Exam(courseID: course.id, title: "Final", date: wednesday(9))]
        state.deleteCourse(course.id)
        XCTAssertTrue(state.courses.isEmpty)
        XCTAssertTrue(state.slots.isEmpty)
        XCTAssertEqual(state.grades.count, 1)
        XCTAssertNil(state.grades[0].courseID)
        XCTAssertNil(state.exams[0].courseID)
    }
}
