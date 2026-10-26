import XCTest
@testable import Ardane

/// « Supprimer la séance »: a session recorded by mistake leaves the history, as if it had never been
/// done: the day's routine can be started again and everything derived from the history is recomputed.
final class WorkoutDeleteTests: XCTestCase {
    private let calendar = DateMath.calendar

    /// Thursday 8 October 2026 at the given hour.
    private func thursday(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour, minute: minute))!
    }

    /// Monday 5 October 2026 at the given hour (same week).
    private func monday(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: hour, minute: minute))!
    }

    private func makeState() -> FitnessState {
        var state = FitnessState()
        state.weeklyGoal = 2
        // Monday (1) and Thursday (4).
        state.routines = [Routine(name: "Haut du corps", exercises: [
            ExerciseTemplate(name: "Développé couché", sets: 1, reps: 8, weight: 60, restSeconds: 60),
        ], weekdays: [1, 4])]
        return state
    }

    /// Monday's session (60 kg) and Thursday morning's one, heavier (80 kg).
    private func stateWithTwoSessions() -> FitnessState {
        var state = makeState()
        state.completeNextSet(at: monday(9))
        XCTAssertNil(state.active)
        state.routines[0].exercises[0].weight = 80
        state.completeNextSet(at: thursday(9))
        XCTAssertNil(state.active)
        XCTAssertEqual(state.history.count, 2)
        return state
    }

    func testDeletingTodaysSessionMakesItAsIfNeverDone() throws {
        var state = stateWithTwoSessions()
        let now = thursday(10)
        let today = try XCTUnwrap(state.history.last)

        XCTAssertEqual(FitnessMath.workouts(inWeekOf: now, state), 2)
        XCTAssertEqual(FitnessMath.weekStreak(state, until: now), 1)
        XCTAssertEqual(FitnessMath.records(state).first?.weight, 80)
        XCTAssertGreaterThan(FitnessMath.weeklyVolume(state, weekOf: now)[3], 0)
        var input = DailyBrief.Input(now: now)
        input.fitness = state
        XCTAssertEqual(DailyBrief.workoutTile(input)?.stage, .done(sets: 1, volume: today.volume))

        XCTAssertTrue(state.deleteSession(id: today.id))

        XCTAssertEqual(state.history.count, 1)
        XCTAssertNil(state.active)
        XCTAssertFalse(FitnessMath.sessions(state).contains { $0.id == today.id })
        XCTAssertEqual(FitnessMath.workouts(inWeekOf: now, state), 1, "No longer counted in the week")
        XCTAssertEqual(FitnessMath.weekStreak(state, until: now), 0, "The goal of 2 is no longer met")
        XCTAssertEqual(FitnessMath.records(state).first?.weight, 60, "The 80 kg record leaves with it")
        XCTAssertEqual(FitnessMath.weeklyVolume(state, weekOf: now)[3], 0)
        XCTAssertEqual(FitnessMath.caloriesBurned(state, on: now), 0)
        XCTAssertEqual(FitnessMath.trainedDays(inWeekOf: now, state), [true, false, false, false, false, false, false])

        // Today's routine is to do again: planned, and a set starts it anew.
        input.fitness = state
        XCTAssertEqual(DailyBrief.workoutTile(input)?.stage, .planned)
        state.completeNextSet(at: thursday(11))
        XCTAssertEqual(state.history.count, 2, "Started again and finished (one set)")
        XCTAssertEqual(FitnessMath.workouts(inWeekOf: now, state), 2)
    }

    func testTheReminderOfTheDayComesBackAfterDeletingTodaysSession() throws {
        var state = makeState()
        state.completeNextSet(at: thursday(9))
        let settings = AppSettings()
        let todayID = SmartReminders.prefix + "workout." + DateMath.dayKey(thursday(0))
        func reminders() -> [String] {
            SmartReminders.plan(fitness: state, nutrition: NutritionState(), budget: BudgetState(), settings: settings, now: thursday(10))
                .map(\.id)
        }
        XCTAssertFalse(reminders().contains(todayID))
        XCTAssertTrue(state.deleteSession(id: try XCTUnwrap(state.history.last?.id)))
        XCTAssertTrue(reminders().contains(todayID))
    }

    func testDeletingTheSessionThatCaughtUpADayMakesThatDayMissedAgain() throws {
        var state = makeState()
        state.startSession(state.routines[0], at: thursday(9), catchingUp: monday(0))
        state.completeNextSet(at: thursday(9, 5))
        XCTAssertNotNil(FitnessMath.catchUp(of: monday(0), state))
        XCTAssertTrue(state.deleteSession(id: try XCTUnwrap(state.history.last?.id)))
        XCTAssertNil(FitnessMath.catchUp(of: monday(0), state))
    }

    func testDeletingTheSessionInProgressCancelsIt() throws {
        var state = makeState()
        state.routines[0].exercises[0].sets = 3
        state.completeNextSet(at: thursday(9))
        let active = try XCTUnwrap(state.active)
        XCTAssertTrue(FitnessMath.sessions(state).contains { $0.id == active.id }, "Listed once it has a set")

        XCTAssertTrue(state.deleteSession(id: active.id))
        XCTAssertNil(state.active)
        XCTAssertTrue(FitnessMath.sessions(state).isEmpty)
        XCTAssertEqual(FitnessMath.workouts(inWeekOf: thursday(10), state), 0)
    }

    func testDeletingAnUnknownSessionChangesNothing() {
        var state = stateWithTwoSessions()
        let before = state
        XCTAssertFalse(state.deleteSession(id: UUID()))
        XCTAssertEqual(state, before)
    }
}
