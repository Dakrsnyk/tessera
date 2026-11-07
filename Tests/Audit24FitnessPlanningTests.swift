import XCTest
@testable import Ardane

/// Non-regression tests of the pre-publication audit (24.C-C): Fitness, Habits (data), Productivity, Planning, Studies.
final class Audit24FitnessPlanningTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func routine() -> Routine {
        Routine(name: "Haut du corps", exercises: [
            ExerciseTemplate(name: "Développé", sets: 3, reps: 8, weight: 60),
            ExerciseTemplate(name: "Tirage", sets: 2, reps: 10, weight: 40)
        ])
    }

    // MARK: F-06 · tolerant decoding

    func testHabitFromAnOlderFormatWithoutAFieldIsStillRead() throws {
        let habit = try decode(Habit.self, #"{"name":"Lire","symbol":"book","colorHex":"7FA33A"}"#)
        XCTAssertEqual(habit.name, "Lire")
        XCTAssertEqual(habit.completedDays, [])
        XCTAssertNil(habit.reminderHour)
        // The whole list survives too: the habit is not lost with the state.
        let content = try decode(ContentState.self, #"{"habits":[{"name":"Lire","symbol":"book","colorHex":"7FA33A"}]}"#)
        XCTAssertEqual(content.habits.count, 1)
        XCTAssertEqual(content.habits.first?.name, "Lire")
    }

    func testHabitEncodedFormatIsUnchanged() throws {
        var habit = Habit(name: "Lire", symbol: "book", colorHex: "7FA33A", completedDays: ["2026-01-01"], reminderHour: 8, reminderMinute: 30)
        habit.toggle(on: t0)
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(habit)) as? [String: Any]
        XCTAssertEqual(Set(object?.keys.map { $0 } ?? []), ["id", "name", "symbol", "colorHex", "completedDays", "reminderHour", "reminderMinute"])
        XCTAssertEqual(try JSONDecoder().decode(Habit.self, from: JSONEncoder().encode(habit)), habit)
    }

    func testProductivityAndStudyTypesReadTheirHistoricalKeysOnly() throws {
        let project = try decode(Project.self, #"{"name":"Mémoire"}"#)
        XCTAssertEqual(project.colorHex, "3366FF")
        XCTAssertEqual(project.tasks, [])
        let counter = try decode(CounterItem.self, #"{"name":"Café"}"#)
        XCTAssertEqual(counter.step, 1)
        XCTAssertTrue(counter.resetsDaily)
        let course = try decode(Course.self, #"{"name":"Maths"}"#)
        XCTAssertEqual(course.colorHex, "D6409F")
        XCTAssertEqual(course.credits, 3)
        let exam = try decode(Exam.self, #"{"title":"Final","date":1000}"#)
        XCTAssertEqual(exam.title, "Final")
        XCTAssertEqual(exam.room, "")
        let card = try decode(Flashcard.self, #"{"front":"a","back":"b"}"#)
        XCTAssertEqual(card.box, 1)
        let grade = try decode(Grade.self, #"{"title":"Examen","score":80}"#)
        XCTAssertEqual(grade.maxScore, 100)
        let session = try decode(StudySession.self, #"{"minutes":25}"#)
        XCTAssertEqual(session.minutes, 25)
    }

    // MARK: F-02 · due date

    func testDueSwitchedOnWithoutTouchingThePickerIsSaved() {
        var task = TaskItem(title: "Rendre le devoir")
        task.repeats = .weekly
        let saved = task.normalizedForSave(hasDue: true, now: t0)
        XCTAssertEqual(saved.due, DateMath.startOfDay(t0))
        XCTAssertEqual(saved.repeats, .weekly, "The repeat is no longer lost")
        let timed = TaskItem(title: "Appeler", hasTime: true).normalizedForSave(hasDue: true, now: t0)
        XCTAssertEqual(timed.due, t0)
    }

    func testDueSwitchedOffClearsDateTimeAndRepeat() {
        let task = TaskItem(title: "x", due: t0, hasTime: true, repeats: .daily)
        let saved = task.normalizedForSave(hasDue: false, now: t0)
        XCTAssertNil(saved.due)
        XCTAssertFalse(saved.hasTime)
        XCTAssertEqual(saved.repeats, .never)
        let kept = TaskItem(title: "y", due: t0.addingTimeInterval(86_400)).normalizedForSave(hasDue: true, now: t0)
        XCTAssertEqual(kept.due, t0.addingTimeInterval(86_400), "A date the person chose is kept")
    }

    // MARK: F-03 · idle session

    func testIdleSessionIsClosedWithoutCountingTheInactivity() {
        var state = FitnessState()
        state.routines = [routine()]
        state.startSession(routine(), at: t0)
        XCTAssertTrue(state.completeNextSet(at: t0.addingTimeInterval(60)))
        XCTAssertFalse(state.closeIdleSession(at: t0.addingTimeInterval(2 * 3600)), "Two hours of rest is not abandonment")
        XCTAssertNotNil(state.active)
        let later = t0.addingTimeInterval(26 * 3600)
        XCTAssertTrue(state.closeIdleSession(at: later))
        XCTAssertNil(state.active)
        XCTAssertEqual(state.history.count, 1)
        XCTAssertEqual(state.history[0].sets.count, 1, "No set is lost")
        XCTAssertEqual(state.history[0].duration, 60, accuracy: 0.5)
    }

    func testFinishingAnIdleSessionLaterStillBoundsItsDuration() {
        var state = FitnessState()
        state.startSession(routine(), at: t0)
        state.completeNextSet(at: t0.addingTimeInterval(120))
        state.finishActive(at: t0.addingTimeInterval(30 * 3600))
        XCTAssertEqual(state.history.last?.duration ?? 0, 120, accuracy: 0.5)
    }

    func testIdleSessionWithoutSetIsDroppedAndAStaleButtonDoesNothing() {
        var state = FitnessState()
        state.routines = [routine()]
        state.startSession(routine(), at: t0)
        let stale = state.position
        let later = t0.addingTimeInterval(5 * 3600)
        XCTAssertFalse(state.press(.completeSet, expecting: stale, at: later))
        XCTAssertNil(state.active)
        XCTAssertTrue(state.history.isEmpty, "A session without any set counts for nothing")
    }

    func testLiveActivityIgnoresAnIdleSession() {
        var state = FitnessState()
        state.startSession(routine(), at: t0)
        XCTAssertNotNil(WorkoutLiveActivity.content(for: state, now: t0.addingTimeInterval(600)))
        XCTAssertNil(WorkoutLiveActivity.content(for: state, now: t0.addingTimeInterval(4 * 3600)))
    }

    // MARK: F-04 · rest alert

    func testRestAlertIsOnlyPlannedForARestStillToCome() {
        XCTAssertEqual(RestNotifier.interval(until: t0.addingTimeInterval(90), now: t0) ?? 0, 90, accuracy: 0.001)
        XCTAssertNil(RestNotifier.interval(until: t0, now: t0))
        XCTAssertNil(RestNotifier.interval(until: t0.addingTimeInterval(-5), now: t0))
    }

    // MARK: F-05 · records beyond 300 sessions

    func testRecordsSurviveBeyondThreeHundredSessions() {
        var state = FitnessState()
        for index in 0..<301 {
            let date = t0.addingTimeInterval(Double(index) * 86_400)
            let set = index == 0
                ? SetLog(exercise: "Squat", reps: 5, weight: 200, date: date)
                : SetLog(exercise: "Curl", reps: 10, weight: 10, date: date)
            state.active = WorkoutSession(routineName: "S\(index)", exercises: [], start: date, sets: [set])
            state.finishActive(at: date.addingTimeInterval(600))
        }
        XCTAssertEqual(state.history.count, 301, "Nothing is dropped at 300")
        let records = FitnessMath.records(state)
        XCTAssertEqual(records.first(where: { $0.exercise == "Squat" })?.weight, 200)
    }

    // MARK: F-08 · « Passer cet exercice »

    func testDoubleTapOnSkipExerciseSkipsOnlyOne() {
        var state = FitnessState()
        state.startSession(routine(), at: t0)
        state.completeNextSet(at: t0.addingTimeInterval(30))
        let drawn = state.position
        XCTAssertTrue(state.skipExercise(at: t0.addingTimeInterval(40), expecting: drawn))
        XCTAssertFalse(state.skipExercise(at: t0.addingTimeInterval(41), expecting: drawn), "The second tap on the same drawing is ignored")
        XCTAssertEqual(state.active?.exerciseIndex, 1)
    }

    func testSkippingTheLastExerciseArchivesTheFinishedSession() {
        var state = FitnessState()
        state.startSession(routine(), at: t0)
        state.completeNextSet(at: t0.addingTimeInterval(30))
        XCTAssertTrue(state.skipExercise(at: t0.addingTimeInterval(40)))
        XCTAssertTrue(state.skipExercise(at: t0.addingTimeInterval(50)))
        XCTAssertNil(state.active)
        XCTAssertEqual(state.history.count, 1)
    }
}
