import XCTest
@testable import Ardane

final class EncouragementsTests: XCTestCase {
    private let calendar = DateMath.calendar
    private let settings = AppSettings()

    /// Thursday 8 October 2026 at the given hour.
    private func thursday(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour, minute: minute))!
    }

    /// 100 kcal per 100 g, with the protein and carbs asked.
    private func food(protein: Double = 5, carbs: Double = 8) -> FoodItem {
        FoodItem(id: "test.encourage", name: "Test", brand: nil, kcal: 100, protein: protein, carbs: carbs, fat: 3, fiber: 0,
                 servingGrams: 100, servingName: "100 g", source: .custom)
    }

    /// What `Encouragements.consider` keeps: the tip taken back is struck, the new one counted.
    private func apply(_ outcome: Encouragements.Outcome?, to log: inout EncouragementLog, now: Date) {
        guard let outcome else { return }
        log.entries.removeAll { outcome.cancelled.contains($0.id) }
        if let message = outcome.message { log.record(message, now: now) }
    }

    private func entry(_ kind: Encouragements.Kind, at date: Date) -> EncouragementLog.Entry {
        EncouragementLog.Entry(kindName: kind.rawValue, id: Encouragements.prefix + kind.rawValue + "." + DateMath.dayKey(date), date: date)
    }

    private func meal(_ state: NutritionState, grams: Double, _ type: MealType, at date: Date, food item: FoodItem? = nil) -> NutritionState {
        var copy = state
        copy.log(item ?? food(), grams: grams, meal: type, at: date)
        return copy
    }

    // MARK: Meals

    func testTheMealTipComesOnceADayFromTheSecondMeal() {
        var log = EncouragementLog()
        let empty = NutritionState()
        // The first meal of the morning: too early to say anything.
        let breakfast = meal(empty, grams: 500, .breakfast, at: thursday(8, 30))
        XCTAssertNil(Encouragements.message(from: empty, to: breakfast, settings: settings, now: thursday(8, 30), log: log))

        // The second meal: what's left for the day (2 200 − 1 200), ten minutes later.
        let lunch = meal(breakfast, grams: 700, .lunch, at: thursday(12, 30))
        let outcome = Encouragements.evaluate(from: breakfast, to: lunch, settings: settings, now: thursday(12, 30), log: log)
        XCTAssertEqual(outcome?.message?.kind, .meal)
        XCTAssertEqual(outcome?.message?.date, thursday(12, 40))
        XCTAssertTrue(outcome?.message?.body.contains("1") == true)
        apply(outcome, to: &log, now: thursday(12, 30))

        // Another food of the same meal while the tip waits: the tip is replaced, not doubled.
        let more = meal(lunch, grams: 100, .lunch, at: thursday(12, 35))
        let replaced = Encouragements.evaluate(from: lunch, to: more, settings: settings, now: thursday(12, 35), log: log)
        XCTAssertEqual(replaced?.cancelled, [outcome?.message?.id].compactMap { $0 })
        XCTAssertEqual(replaced?.message?.id, outcome?.message?.id)
        apply(replaced, to: &log, now: thursday(12, 35))
        XCTAssertEqual(log.entries.count, 1)

        // A snack in the afternoon: no second meal tip today.
        let snack = meal(more, grams: 100, .snack, at: thursday(16))
        XCTAssertNil(Encouragements.message(from: more, to: snack, settings: settings, now: thursday(16), log: log))

        // A food removed: nothing either.
        XCTAssertNil(Encouragements.message(from: lunch, to: breakfast, settings: settings, now: thursday(17), log: EncouragementLog()))
    }

    func testTooManyCarbsForTooLittleProteinGivesATip() {
        let empty = NutritionState()
        let starchy = food(protein: 2, carbs: 60)
        let breakfast = meal(empty, grams: 300, .breakfast, at: thursday(8), food: starchy)
        let lunch = meal(breakfast, grams: 300, .lunch, at: thursday(12, 30), food: starchy)
        let message = Encouragements.message(from: breakfast, to: lunch, settings: settings, now: thursday(12, 30), log: EncouragementLog())
        XCTAssertEqual(message?.kind, .meal)
        XCTAssertTrue(message?.body.contains("protéines") == true)
    }

    func testTheCalorieGoalReached() {
        let breakfast = meal(NutritionState(), grams: 1_000, .breakfast, at: thursday(8))
        let dinner = meal(breakfast, grams: 1_200, .dinner, at: thursday(19))
        let message = Encouragements.message(from: breakfast, to: dinner, settings: settings, now: thursday(19), log: EncouragementLog())
        XCTAssertEqual(message?.kind, .calorieGoal)
    }

    // MARK: Rules

    func testNothingAtNight() {
        let breakfast = meal(NutritionState(), grams: 500, .breakfast, at: thursday(8))
        let late = meal(breakfast, grams: 700, .dinner, at: thursday(22, 30))
        XCTAssertNil(Encouragements.message(from: breakfast, to: late, settings: settings, now: thursday(22, 30), log: EncouragementLog()))
        // Ten minutes later would be after 22:00: skipped, not queued.
        let evening = meal(breakfast, grams: 700, .dinner, at: thursday(21, 55))
        XCTAssertNil(Encouragements.message(from: breakfast, to: evening, settings: settings, now: thursday(21, 55), log: EncouragementLog()))
        XCTAssertFalse(Encouragements.allows(.workout, at: thursday(7, 30), now: thursday(7, 30), log: EncouragementLog()))
        XCTAssertTrue(Encouragements.allows(.workout, at: thursday(8), now: thursday(8), log: EncouragementLog()))
    }

    func testTwoADayAtMostAndThreeHoursApart() {
        var log = EncouragementLog()
        log.entries = [entry(.meal, at: thursday(10))]
        XCTAssertFalse(Encouragements.allows(.longStudy, at: thursday(12), now: thursday(12), log: log), "Three hours apart")
        XCTAssertTrue(Encouragements.allows(.longStudy, at: thursday(13, 30), now: thursday(13, 30), log: log))
        log.entries.append(entry(.workout, at: thursday(14)))
        XCTAssertFalse(Encouragements.allows(.longStudy, at: thursday(19), now: thursday(19), log: log), "Two a day at most")
        // The next day: allowed again, but not the same kind within its cooldown.
        let friday = thursday(19).addingTimeInterval(86_400)
        XCTAssertTrue(Encouragements.allows(.longStudy, at: friday, now: friday, log: log))
        XCTAssertFalse(Encouragements.allows(.progress, at: thursday(14).addingTimeInterval(86_400), now: friday, log: log),
                       "A record and a workout share the same rhythm")
    }

    func testTurnedOffSendsNothing() {
        var off = AppSettings()
        off.encourages = false
        let breakfast = meal(NutritionState(), grams: 500, .breakfast, at: thursday(8))
        let lunch = meal(breakfast, grams: 700, .lunch, at: thursday(12, 30))
        XCTAssertNil(Encouragements.evaluate(from: breakfast, to: lunch, settings: off, now: thursday(12, 30), log: EncouragementLog()))
    }

    func testOlderSettingsTurnTheEncouragementsOn() throws {
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(decoded.encourages)
    }

    // MARK: Workouts

    private let bench = "Développé couché"

    /// The state while the last set is done, and once the session is saved.
    private func session(after state: FitnessState, weight: Double, at date: Date) -> (during: FitnessState, after: FitnessState) {
        var copy = state
        let routine = Routine(name: "Haut du corps", exercises: [ExerciseTemplate(name: bench, sets: 1, reps: 8, weight: weight)])
        copy.startSession(routine, at: date.addingTimeInterval(-3_600))
        _ = copy.active?.completeSet(at: date)
        let during = copy
        copy.finishActive(at: date)
        return (during, copy)
    }

    func testARecordReplacesTheWorkoutMessage() {
        let lastWeek = thursday(18).addingTimeInterval(-7 * 86_400)
        let base = session(after: FitnessState(), weight: 60, at: lastWeek).after

        let stronger = session(after: base, weight: 70, at: thursday(18))
        let record = Encouragements.message(from: stronger.during, to: stronger.after, settings: settings, now: thursday(18, 1), log: EncouragementLog())
        XCTAssertEqual(record?.kind, .progress)
        XCTAssertTrue(record?.body.contains(bench) == true)
        XCTAssertTrue(record?.body.contains("70") == true)

        let same = session(after: base, weight: 60, at: thursday(18))
        let plain = Encouragements.message(from: same.during, to: same.after, settings: settings, now: thursday(18, 1), log: EncouragementLog())
        XCTAssertEqual(plain?.kind, .workout)
    }

    func testACancelledWorkoutSaysNothing() {
        let done = session(after: FitnessState(), weight: 60, at: thursday(9)).after
        var during = done
        let routine = Routine(name: "Haut du corps", exercises: [ExerciseTemplate(name: bench, sets: 3, reps: 8, weight: 80)])
        during.startSession(routine, at: thursday(18))
        _ = during.active?.completeSet(at: thursday(18, 5))
        // Cancelled: the session is dropped, the history stays as it was.
        var cancelled = during
        cancelled.active = nil
        XCTAssertNil(Encouragements.message(from: during, to: cancelled, settings: settings, now: thursday(18, 6), log: EncouragementLog()))
        // A set done, the session going on: nothing yet.
        var next = during
        _ = next.active?.completeSet(at: thursday(18, 8))
        XCTAssertNil(Encouragements.message(from: during, to: next, settings: settings, now: thursday(18, 8), log: EncouragementLog()))
    }

    // MARK: Studies

    func testALongStudyDay() {
        var before = StudentState()
        before.logStudy(minutes: 60, courseID: nil, at: thursday(10))
        var after = before
        after.logStudy(minutes: 40, courseID: nil, at: thursday(11))
        let message = Encouragements.message(from: before, to: after, settings: settings, now: thursday(11), log: EncouragementLog())
        XCTAssertEqual(message?.kind, .longStudy)
        XCTAssertTrue(message?.body.contains("pause") == true)

        // Short: nothing.
        var short = StudentState()
        short.logStudy(minutes: 30, courseID: nil, at: thursday(11))
        XCTAssertNil(Encouragements.message(from: StudentState(), to: short, settings: settings, now: thursday(11), log: EncouragementLog()))
    }

    func testTheWeeklyStudyGoalReached() {
        var before = StudentState()
        before.weeklyStudyGoalHours = 1
        before.logStudy(minutes: 40, courseID: nil, at: thursday(10))
        var after = before
        after.logStudy(minutes: 30, courseID: nil, at: thursday(15))
        XCTAssertEqual(Encouragements.message(from: before, to: after, settings: settings, now: thursday(15), log: EncouragementLog())?.kind, .weeklyStudy)
    }
}
