import XCTest
@testable import Tessera

/// The small back arrow of the workout (Lock Screen, Dynamic Island, widget, app): a « Série faite »
/// touched by mistake is taken back, and a session started by mistake is cancelled without counting.
final class WorkoutUndoTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func makeState() -> FitnessState {
        var state = FitnessState()
        state.weeklyGoal = 3
        state.routines = [Routine(name: "Haut du corps", exercises: [
            ExerciseTemplate(name: "A", sets: 2, reps: 10, weight: 50, restSeconds: 60),
            ExerciseTemplate(name: "B", sets: 1, reps: 8, weight: 20, restSeconds: 60),
        ])]
        return state
    }

    private func at(_ minutes: Double) -> Date { start.addingTimeInterval(minutes * 60) }

    func testUndoingAMiddleSetGoesBackToIt() {
        var state = makeState()
        state.completeNextSet(at: at(0))
        state.completeNextSet(at: at(2))
        // A done twice: now on B.
        XCTAssertEqual(state.active?.exerciseIndex, 1)
        XCTAssertEqual(state.active?.setIndex, 0)

        XCTAssertTrue(state.undoLastSet(at: at(3)))
        XCTAssertEqual(state.active?.sets.count, 1)
        XCTAssertEqual(state.active?.exerciseIndex, 0, "Back on A")
        XCTAssertEqual(state.active?.setIndex, 1, "Its second set")
        XCTAssertNil(state.active?.restEndsAt, "No rest after an undo")
        XCTAssertNil(state.active?.restPausedRemaining)

        XCTAssertTrue(state.undoLastSet(at: at(3)))
        XCTAssertEqual(state.active?.sets.count, 0)
        XCTAssertEqual(state.active?.exerciseIndex, 0)
        XCTAssertEqual(state.active?.setIndex, 0)
        XCTAssertNotNil(state.active, "A session left without sets stays in progress (« Annuler la séance » removes it)")
        XCTAssertTrue(state.activeHasNoSets)
        XCTAssertFalse(state.canUndoLastSet(at: at(3)))
    }

    func testUndoAfterThePausedRestClearsIt() {
        var state = makeState()
        state.completeNextSet(at: at(0))
        state.pauseRest(at: at(0.5))
        XCTAssertNotNil(state.active?.restPausedRemaining)
        state.undoLastSet(at: at(1))
        XCTAssertNil(state.active?.restPausedRemaining)
        XCTAssertNil(state.active?.restEndsAt)
    }

    func testUndoAfterTheLastSetBringsTheSessionBack() {
        var state = makeState()
        state.completeNextSet(at: at(0))
        state.completeNextSet(at: at(2))
        state.completeNextSet(at: at(4))
        // The last set finished the session: it is in the history.
        XCTAssertNil(state.active)
        XCTAssertEqual(state.history.count, 1)
        XCTAssertEqual(FitnessMath.workouts(inWeekOf: at(4), state), 1)
        XCTAssertTrue(state.canUndoLastSet(at: at(5)))

        XCTAssertTrue(state.undoLastSet(at: at(5)))
        XCTAssertTrue(state.history.isEmpty, "No longer done")
        XCTAssertEqual(state.active?.sets.count, 2)
        XCTAssertEqual(state.active?.exerciseIndex, 1, "Back on B")
        XCTAssertEqual(state.active?.setIndex, 0)
        XCTAssertNil(state.active?.end, "In progress again")
        XCTAssertFalse(state.active?.isFinished ?? true)
        XCTAssertNotNil(WorkoutLiveActivity.content(for: state, now: at(5)), "Its Live Activity comes back")

        // Done again: one session, not two.
        state.completeNextSet(at: at(6))
        XCTAssertNil(state.active)
        XCTAssertEqual(state.history.count, 1)
        XCTAssertEqual(state.history.first?.sets.count, 3)
    }

    func testASessionFinishedLongAgoOrByHandIsNotReopened() {
        var late = makeState()
        late.completeNextSet(at: at(0))
        late.completeNextSet(at: at(2))
        late.completeNextSet(at: at(4))
        XCTAssertFalse(late.canUndoLastSet(at: at(4 + 61)))
        XCTAssertFalse(late.undoLastSet(at: at(4 + 61)))
        XCTAssertEqual(late.history.count, 1)

        var byHand = makeState()
        byHand.completeNextSet(at: at(0))
        byHand.finishActive(at: at(10))
        XCTAssertFalse(byHand.undoLastSet(at: at(11)), "« Terminer la séance » is a choice, not a mistake")
        XCTAssertEqual(byHand.history.count, 1)
    }

    func testUndoWithoutAnySetDoesNothing() {
        var empty = makeState()
        let untouched = empty
        XCTAssertFalse(empty.undoLastSet(at: at(0)))
        XCTAssertEqual(empty, untouched)

        var started = makeState()
        let routine = started.routines[0]
        started.startSession(routine, at: at(0))
        let before = started
        XCTAssertFalse(started.undoLastSet(at: at(1)))
        XCTAssertEqual(started, before)
    }

    func testACancelledSessionCountsForNothing() {
        var state = makeState()
        let week = FitnessMath.workouts(inWeekOf: at(0), state)
        state.completeNextSet(at: at(0))
        state.completeNextSet(at: at(2))
        XCTAssertEqual(FitnessMath.workouts(inWeekOf: at(2), state), week + 1, "Half done counts while in progress")

        state.cancelActive()
        XCTAssertNil(state.active)
        XCTAssertTrue(state.history.isEmpty, "Never in the history")
        XCTAssertEqual(FitnessMath.workouts(inWeekOf: at(2), state), week)
        XCTAssertTrue(FitnessMath.sessions(state).isEmpty)
        XCTAssertTrue(FitnessMath.records(state).isEmpty)
        XCTAssertEqual(FitnessMath.caloriesBurned(state, on: at(2)), 0)
        XCTAssertEqual(FitnessMath.weekStreak(state, until: at(2)), 0)
        XCTAssertNil(WorkoutLiveActivity.content(for: state, now: at(2)), "Its Live Activity ends")
        XCTAssertFalse(state.canUndoLastSet(at: at(3)), "Nothing to take back after a cancel")
    }

    func testASessionStartedByMistakeIsCancelled() {
        var state = makeState()
        let missed = at(-24 * 60)
        let routine = state.routines[0]
        state.startSession(routine, at: at(0), catchingUp: missed)
        XCTAssertNotNil(FitnessMath.catchUp(of: missed, state))
        XCTAssertTrue(state.activeHasNoSets)

        state.cancelActive()
        XCTAssertNil(FitnessMath.catchUp(of: missed, state), "The missed day is missed again, not caught up")
        XCTAssertTrue(state.history.isEmpty)
        XCTAssertFalse(state.activeHasNoSets)
    }

    func testTheBackButtonOfTheLiveActivity() {
        var state = makeState()
        let routine = state.routines[0]
        state.startSession(routine, at: at(0))
        let empty = WorkoutLiveActivity.content(for: state, now: at(0))?.1
        XCTAssertEqual(empty?.undoesSet, false)
        XCTAssertEqual(empty?.backSymbol, "xmark")

        state.completeNextSet(at: at(1))
        let one = WorkoutLiveActivity.content(for: state, now: at(1))?.1
        XCTAssertEqual(one?.undoesSet, true)
        XCTAssertEqual(one?.backSymbol, "arrow.uturn.backward")
    }
}
