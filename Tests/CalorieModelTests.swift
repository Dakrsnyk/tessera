import XCTest
@testable import Ardane

/// The estimate of the active calories: work apart from rest, capped, no number without a weight,
/// no passed or deleted set counted, and no step counted again during a workout.
final class CalorieModelTests: XCTestCase {
    private let calendar = DateMath.calendar

    /// Thursday 8 October 2026, 9:00.
    private var start: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 9, minute: 0))!
    }

    private func at(_ seconds: Double, from base: Date? = nil) -> Date {
        (base ?? start).addingTimeInterval(seconds)
    }

    private func set(_ seconds: Double, reps: Int = 10, weight: Double = 40, from base: Date? = nil) -> SetLog {
        SetLog(exercise: "Squat", reps: reps, weight: weight, date: at(seconds, from: base))
    }

    private func session(from base: Date? = nil, sets: [SetLog]) -> WorkoutSession {
        WorkoutSession(routineName: "Test", exercises: [], start: base ?? start, sets: sets)
    }

    /// `count` sets, one every `gap` seconds.
    private func regular(count: Int, gap: Double, weight: Double = 40, reps: Int = 10) -> WorkoutSession {
        session(sets: (1...count).map { set(Double($0) * gap, reps: reps, weight: weight) })
    }

    // MARK: Session

    func testSessionWithoutSetIsZero() {
        XCTAssertEqual(CalorieModel.activeCalories(of: session(sets: []), weightKg: 75), 0)
        XCTAssertEqual(CalorieModel.effort(of: session(sets: [])), CalorieModel.Effort())
    }

    func testUnknownWeightGivesNoNumber() {
        let done = regular(count: 4, gap: 120)
        XCTAssertNil(CalorieModel.activeCalories(of: done, weightKg: nil))
        XCTAssertNil(CalorieModel.activeCalories(of: done, weightKg: 0))
        XCTAssertNil(CalorieModel.activeCalories(of: done, weightKg: -5))
        XCTAssertNil(CalorieModel.activeCalories(of: done, weightKg: .nan))
        XCTAssertNil(CalorieModel.dayCalories(sessions: [done], weightKg: nil))
        XCTAssertNil(CalorieModel.stepsCalories(steps: 5_000, weightKg: nil))
    }

    func testLongerSessionBurnsMore() throws {
        let short = try XCTUnwrap(CalorieModel.activeCalories(of: regular(count: 4, gap: 120), weightKg: 75))
        let long = try XCTUnwrap(CalorieModel.activeCalories(of: regular(count: 12, gap: 120), weightKg: 75))
        XCTAssertGreaterThan(short, 0)
        XCTAssertGreaterThan(long, short)
    }

    func testHeavierWeightOfThePersonBurnsMore() throws {
        let done = regular(count: 8, gap: 120)
        let light = try XCTUnwrap(CalorieModel.activeCalories(of: done, weightKg: 60))
        let heavy = try XCTUnwrap(CalorieModel.activeCalories(of: done, weightKg: 90))
        XCTAssertEqual(heavy / light, 1.5, accuracy: 1e-9)
    }

    func testLoadedSetsBurnMoreThanBodyweightSets() throws {
        let loaded = try XCTUnwrap(CalorieModel.activeCalories(of: regular(count: 8, gap: 120, weight: 60), weightKg: 75))
        let bodyweight = try XCTUnwrap(CalorieModel.activeCalories(of: regular(count: 8, gap: 120, weight: 0), weightKg: 75))
        XCTAssertGreaterThan(loaded, bodyweight)
        XCTAssertEqual(CalorieModel.met(of: set(0, weight: 0)), 3.8)
        XCTAssertEqual(CalorieModel.met(of: set(0, weight: 20)), 5.0)
    }

    func testRestCountsLessThanWork() throws {
        // One set done after 5 minutes: mostly rest.
        let one = session(sets: [set(300)])
        let effort = CalorieModel.effort(of: one)
        XCTAssertGreaterThan(effort.restSeconds, effort.workSeconds)
        let kcal = try XCTUnwrap(CalorieModel.activeCalories(of: one, weightKg: 75))
        // All the same minutes at the work intensity would cost more.
        let allWork = (CalorieModel.loadedSetMET - 1) * 75 * effort.minutes / 60
        XCTAssertLessThan(kcal, allWork)
        XCTAssertGreaterThan(kcal, 0)
        XCTAssertEqual(effort.workSeconds + effort.restSeconds, 300, accuracy: 1e-9)
    }

    func testSessionLeftOpenDoesNotCountHoursOfInactivity() throws {
        let open = session(sets: [set(120), set(120 + 5 * 3_600)])
        let capped = session(sets: [set(120), set(120 + 600)])
        let openEffort = CalorieModel.effort(of: open)
        XCTAssertLessThanOrEqual(openEffort.minutes, 2 + 10 + 1e-9, "2 minutes then at most 10 more")
        let openKcal = try XCTUnwrap(CalorieModel.activeCalories(of: open, weightKg: 75))
        let cappedKcal = try XCTUnwrap(CalorieModel.activeCalories(of: capped, weightKg: 75))
        XCTAssertEqual(openKcal, cappedKcal, accuracy: 1e-9)
        // Neither does the old end date: a session with a late end counts only the sets.
        var late = session(sets: [set(120)])
        late.end = at(10 * 3_600)
        XCTAssertEqual(try XCTUnwrap(CalorieModel.activeCalories(of: late, weightKg: 75)),
                       try XCTUnwrap(CalorieModel.activeCalories(of: session(sets: [set(120)]), weightKg: 75)), accuracy: 1e-9)
    }

    func testPassedSetsAddNothing() throws {
        let plain = regular(count: 4, gap: 120)
        var withSkips = plain
        withSkips.skipped = [
            SkippedSet(exerciseIndex: 0, setIndex: 1, afterSets: 1, date: at(150)),
            SkippedSet(exerciseIndex: 1, setIndex: 0, afterSets: 4, date: at(900)),
        ]
        withSkips.end = at(900)
        XCTAssertEqual(try XCTUnwrap(CalorieModel.activeCalories(of: withSkips, weightKg: 75)),
                       try XCTUnwrap(CalorieModel.activeCalories(of: plain, weightKg: 75)), accuracy: 1e-9)
        var onlySkips = session(sets: [])
        onlySkips.skipped = [SkippedSet(exerciseIndex: 0, setIndex: 0, afterSets: 0, date: at(60))]
        XCTAssertEqual(CalorieModel.activeCalories(of: onlySkips, weightKg: 75), 0)
    }

    func testWorkSecondsOfASet() {
        XCTAssertEqual(CalorieModel.workSeconds(of: set(0, reps: 1)), 25, "At least 25 s")
        XCTAssertEqual(CalorieModel.workSeconds(of: set(0, reps: 10)), 50, accuracy: 1e-9)
        XCTAssertEqual(CalorieModel.workSeconds(of: set(0, reps: 100)), 90, "At most 90 s")
        XCTAssertEqual(CalorieModel.workSeconds(of: set(0, reps: -3)), 25)
    }

    func testTypicalHourIsPlausible() throws {
        // 20 sets of 10 over 60 minutes, 75 kg: an estimate of the active calories, far under the 375 kcal
        // of the old "5 MET for the whole duration" and over the resting level.
        let hour = regular(count: 20, gap: 180)
        let kcal = try XCTUnwrap(CalorieModel.activeCalories(of: hour, weightKg: 75))
        XCTAssertGreaterThan(kcal, 80)
        XCTAssertLessThan(kcal, 300)
        XCTAssertEqual(CalorieModel.effort(of: hour).minutes, 60, accuracy: 1e-9)
    }

    // MARK: Day

    func testDayIsTheSumOfItsSessions() throws {
        let morning = regular(count: 6, gap: 120)
        let evening = session(from: at(9 * 3_600), sets: (1...5).map { set(Double($0) * 100, weight: 0, from: at(9 * 3_600)) })
        let sum = try XCTUnwrap(CalorieModel.activeCalories(of: morning, weightKg: 75))
            + XCTUnwrap(CalorieModel.activeCalories(of: evening, weightKg: 75))
        XCTAssertEqual(try XCTUnwrap(CalorieModel.dayCalories(sessions: [morning, evening], weightKg: 75)), sum, accuracy: 1e-9)

        var state = FitnessState()
        state.bodyWeightKg = 75
        state.history = [morning, evening]
        XCTAssertEqual(FitnessMath.caloriesBurned(state, on: start), sum, accuracy: 1e-9)
        XCTAssertEqual(FitnessMath.caloriesBurned(state, on: at(-86_400)), 0, "Nothing the day before")
        XCTAssertEqual(FitnessMath.caloriesThisWeek(state, weekOf: start), sum, accuracy: 1e-9)
        XCTAssertEqual(CalorieModel.dayCalories(sessions: [], weightKg: 75), 0)
    }

    func testDeletedOrUnstartedSessionIsZero() throws {
        var state = FitnessState()
        state.bodyWeightKg = 75
        let done = regular(count: 4, gap: 120)
        state.history = [done]
        XCTAssertGreaterThan(FitnessMath.caloriesBurned(state, on: start), 0)

        XCTAssertTrue(state.deleteSession(id: done.id))
        XCTAssertEqual(FitnessMath.caloriesBurned(state, on: start), 0)

        // A session under way without a set done is not a session yet.
        state.active = session(sets: [])
        XCTAssertEqual(FitnessMath.caloriesBurned(state, on: start), 0)
    }

    func testBodyWeightOfTheStateIsUsed() throws {
        var state = FitnessState()
        state.history = [regular(count: 4, gap: 120)]
        state.bodyWeightKg = 60
        let light = FitnessMath.caloriesBurned(state, on: start)
        state.bodyWeightKg = 90
        let heavy = FitnessMath.caloriesBurned(state, on: start)
        XCTAssertGreaterThan(light, 0)
        XCTAssertEqual(heavy / light, 1.5, accuracy: 1e-9)
    }

    // MARK: Steps

    func testStepsOfTheWorkoutAreNotCountedTwice() throws {
        let walking = try XCTUnwrap(CalorieModel.stepsCalories(steps: 6_000, weightKg: 70))
        XCTAssertEqual(walking, 240, accuracy: 1e-9, "0.04 kcal per step for 70 kg")

        // 60 minutes of workout take 60 × 30 = 1 800 steps out.
        let withWorkout = try XCTUnwrap(CalorieModel.stepsCalories(steps: 6_000, weightKg: 70, minutesInSessions: 60))
        let expected = try XCTUnwrap(CalorieModel.stepsCalories(steps: 4_200, weightKg: 70))
        XCTAssertEqual(withWorkout, expected, accuracy: 1e-9)
        XCTAssertLessThan(withWorkout, walking)

        // Never negative, whatever the minutes.
        XCTAssertEqual(CalorieModel.stepsCalories(steps: 500, weightKg: 70, minutesInSessions: 600), 0)
        XCTAssertEqual(CalorieModel.stepsCalories(steps: 0, weightKg: 70), 0)
        XCTAssertEqual(CalorieModel.stepsCalories(steps: 1_000, weightKg: 70, minutesInSessions: -10),
                       CalorieModel.stepsCalories(steps: 1_000, weightKg: 70))
    }

    func testMinutesOfTheDayCountOnlyThatDay() {
        let today = regular(count: 3, gap: 120)
        let yesterday = session(from: at(-86_400), sets: [set(600, from: at(-86_400))])
        XCTAssertEqual(CalorieModel.minutes(of: [today, yesterday], on: start), 6, accuracy: 1e-9)
        XCTAssertEqual(CalorieModel.minutes(of: [today, yesterday], on: at(86_400)), 0)
    }
}
