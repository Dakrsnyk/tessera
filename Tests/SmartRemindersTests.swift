import XCTest
@testable import Tessera

final class SmartRemindersTests: XCTestCase {
    private let calendar = DateMath.calendar

    /// Thursday 8 October 2026 at the given hour.
    private func thursday(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour, minute: minute))!
    }

    private func ids(_ reminders: [SmartReminders.Reminder], _ kind: String) -> [String] {
        reminders.map(\.id).filter { $0.hasPrefix(SmartReminders.prefix + kind) }
    }

    func testTheWorkoutReminderComesOnlyOnPlannedDaysAndNotOnceBegun() {
        var fitness = FitnessState()
        // Thursday (4) and Saturday (6).
        let routine = Routine(name: "Haut du corps", exercises: [ExerciseTemplate(name: "Développé couché", sets: 1, reps: 8, weight: 60)], weekdays: [4, 6])
        fitness.routines = [routine]
        let settings = AppSettings()
        var plan = SmartReminders.plan(fitness: fitness, nutrition: NutritionState(), budget: BudgetState(), settings: settings, now: thursday(9))
        let workouts = plan.filter { $0.id.hasPrefix(SmartReminders.prefix + "workout") }
        XCTAssertEqual(workouts.count, 2, "Thursday and Saturday of the coming week")
        XCTAssertEqual(workouts.first?.date, thursday(18))
        XCTAssertTrue(workouts.first?.body.contains("Haut du corps") == true)

        // Begun today: tonight's reminder goes, Saturday's stays.
        fitness.startSession(routine, at: thursday(12))
        _ = fitness.active?.completeSet(at: thursday(12, 5))
        plan = SmartReminders.plan(fitness: fitness, nutrition: NutritionState(), budget: BudgetState(), settings: settings, now: thursday(13))
        XCTAssertEqual(ids(plan, "workout").count, 1)
        XCTAssertFalse(ids(plan, "workout").contains(SmartReminders.prefix + "workout." + DateMath.dayKey(thursday(0))))

        // Past its hour, or turned off: nothing for today.
        var off = settings
        off.remindsWorkout = false
        XCTAssertTrue(ids(SmartReminders.plan(fitness: fitness, nutrition: NutritionState(), budget: BudgetState(), settings: off, now: thursday(9)), "workout").isEmpty)
    }

    func testTheMealReminderIsForSomeoneWhoNotesMealsOnADayWithoutAny() {
        var nutrition = NutritionState()
        let settings = AppSettings()
        XCTAssertTrue(ids(SmartReminders.plan(fitness: FitnessState(), nutrition: nutrition, budget: BudgetState(), settings: settings, now: thursday(9)), "meals").isEmpty,
                      "Someone who doesn't note meals gets no reminder")

        let food = FoodDatabase.all.first!
        nutrition.log(food, grams: 100, meal: .lunch, at: thursday(12).addingTimeInterval(-86_400))
        var plan = SmartReminders.plan(fitness: FitnessState(), nutrition: nutrition, budget: BudgetState(), settings: settings, now: thursday(9))
        XCTAssertEqual(ids(plan, "meals").first, SmartReminders.prefix + "meals." + DateMath.dayKey(thursday(0)))
        XCTAssertEqual(plan.first { $0.id.hasPrefix(SmartReminders.prefix + "meals") }?.date, thursday(20))

        // A meal noted today: nothing tonight, the next days stay planned.
        nutrition.log(food, grams: 100, meal: .lunch, at: thursday(12))
        plan = SmartReminders.plan(fitness: FitnessState(), nutrition: nutrition, budget: BudgetState(), settings: settings, now: thursday(13))
        XCTAssertFalse(ids(plan, "meals").contains(SmartReminders.prefix + "meals." + DateMath.dayKey(thursday(0))))
        XCTAssertEqual(ids(plan, "meals").count, 6)
    }

    func testABillIsRemindedTheDayBefore() {
        var budget = BudgetState()
        let due = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10))!
        budget.bills = [Bill(name: "Loyer", amount: 1_250, anchorDate: due)]
        let plan = SmartReminders.plan(fitness: FitnessState(), nutrition: NutritionState(), budget: budget, settings: AppSettings(), now: thursday(9))
        let bills = plan.filter { $0.id.hasPrefix(SmartReminders.prefix + "bill") }
        XCTAssertEqual(bills.count, 1)
        XCTAssertEqual(bills.first?.date, calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 9)))
        XCTAssertTrue(bills.first?.title.contains("Loyer") == true)
    }

    func testOlderSettingsTurnTheRemindersOn() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(settings.remindsWorkout && settings.remindsMeals && settings.remindsBills)
        XCTAssertEqual(settings.workoutReminderHour, 18)
        XCTAssertEqual(settings.mealReminderHour, 20)
    }
}
