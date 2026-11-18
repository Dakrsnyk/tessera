import XCTest
@testable import Ardane

/// The data behind the hybrid Fitness page: the rest shortened or lengthened by 15 s, and the set done from the page.
final class FitnessHybridTests: XCTestCase {
    private let now = DateMath.calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 19, minute: 5))!

    private func state(rest: Int = 60) -> FitnessState {
        var state = FitnessState()
        let routine = Routine(name: "Haut du corps", exercises: [ExerciseTemplate(name: "Développé couché", sets: 3, reps: 10, weight: 60, restSeconds: rest)])
        state.startSession(routine, at: now)
        return state
    }

    func testARestLengthensAndShortensByFifteenSeconds() {
        var state = state()
        _ = state.active?.completeSet(at: now)
        let end = state.active?.restEndsAt
        XCTAssertEqual(end, now.addingTimeInterval(60))
        state.adjustRest(by: 15, at: now)
        XCTAssertEqual(state.active?.restEndsAt, now.addingTimeInterval(75))
        state.adjustRest(by: -15, at: now)
        state.adjustRest(by: -15, at: now)
        XCTAssertEqual(state.active?.restEndsAt, now.addingTimeInterval(45))
    }

    func testARestNeverGoesBeforeNowNorBeyondAnHour() {
        var state = state(rest: 20)
        _ = state.active?.completeSet(at: now)
        state.adjustRest(by: -15, at: now.addingTimeInterval(10))
        XCTAssertEqual(state.active?.restEndsAt, now.addingTimeInterval(10), "Not before now: the rest reads « Prêt »")
        var long = self.state(rest: 3_500)
        _ = long.active?.completeSet(at: now)
        long.adjustRest(by: 600, at: now)
        XCTAssertEqual(long.active?.restEndsAt, now.addingTimeInterval(3_600))
    }

    func testNothingChangesWithoutARunningRest() {
        var state = state()
        state.adjustRest(by: 15, at: now)
        XCTAssertNil(state.active?.restEndsAt, "No rest before the first set")
        _ = state.active?.completeSet(at: now)
        state.pauseRest(at: now.addingTimeInterval(10))
        let left = state.active?.restPausedRemaining
        state.adjustRest(by: 15, at: now.addingTimeInterval(11))
        XCTAssertNil(state.active?.restEndsAt, "A paused rest is not moved")
        XCTAssertEqual(state.active?.restPausedRemaining, left)
        var over = self.state()
        _ = over.active?.completeSet(at: now)
        over.adjustRest(by: 15, at: now.addingTimeInterval(120))
        XCTAssertEqual(over.active?.restEndsAt, now.addingTimeInterval(60), "A rest already over stays over")
    }

    func testASetDoneFromThePageIsTheSetAsPlanned() {
        var state = state()
        _ = state.active?.completeSet(at: now)
        XCTAssertEqual(state.active?.sets.count, 1)
        XCTAssertEqual(state.active?.sets.last?.reps, 10)
        XCTAssertEqual(state.active?.sets.last?.weight, 60)
        XCTAssertEqual(state.active?.setIndex, 1)
    }
}
