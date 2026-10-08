import XCTest
@testable import Tessera

/// « Mon Quotidien » and the data widgets ask for: only what the person entered, the right thing at
/// the right moment, one place for each value, example data only where nothing was given.
@MainActor
final class DailyBriefTests: XCTestCase {
    private func temporaryModel() -> AppModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return AppModel(store: SharedStore(directory: directory))
    }

    /// Wednesday 30 September 2026 at the given hour.
    private func wednesday(_ hour: Int, _ minute: Int = 0) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: hour, minute: minute))!
    }

    private func ids(_ tiles: [DailyBrief.Tile]) -> [String] { tiles.map(\.id) }

    // MARK: Nothing made up

    func testNothingEnteredShowsNoFigure() {
        var input = DailyBrief.Input(now: wednesday(9))
        XCTAssertTrue(DailyBrief.tiles(input).isEmpty, "Without data, « Mon Quotidien » stays empty")
        // With interests but nothing entered: only discreet invitations, never numbers.
        input.interests = [.nutrition, .budget, .fitness]
        let tiles = DailyBrief.tiles(input)
        XCTAssertEqual(ids(tiles), ["invite-nutrition", "invite-budget"], "At most two invitations")
    }

    func testCaloriesLeftOnlyWithTheUsersTarget() {
        var input = DailyBrief.Input(now: wednesday(13))
        let food = try! XCTUnwrap(FoodDatabase.search("").first { $0.kcal > 50 }, "The built-in foods")
        input.nutrition.entries = [FoodEntry(date: wednesday(12), meal: .lunch, food: food, grams: 150)]
        guard case let .nutrition(eaten)? = DailyBrief.tiles(input).first else { return XCTFail("A food logged today shows") }
        XCTAssertNil(eaten.kcalLeft, "No target given: no « kcal restantes »")
        XCTAssertGreaterThan(eaten.eaten.kcal, 0)

        input.profile.provided = [.kcalTarget]
        input.nutrition.goals.kcal = 2_500
        guard case let .nutrition(withTarget)? = DailyBrief.tiles(input).first(where: { $0.id == "nutrition" }) else { return XCTFail() }
        XCTAssertEqual(withTarget.kcalLeft ?? 0, 2_500 - withTarget.eaten.kcal, accuracy: 0.1)
        XCTAssertNotNil(withTarget.nextMeal, "The next meal is suggested once the target is known")
    }

    func testWaterAndBudgetNeverUseDefaultGoals() {
        var input = DailyBrief.Input(now: wednesday(15))
        input.content.hydration.add(3, on: input.now)
        input.budget.expenses = [Expense(amount: 12, categoryID: nil, date: input.now)]
        let tiles = DailyBrief.tiles(input)
        XCTAssertTrue(tiles.contains(.water(glasses: 3, goal: nil)), "3 glasses, no goal made up")
        XCTAssertTrue(tiles.contains(.budget(spentToday: 12, perDayLeft: nil)), "Spent today, no budget made up")
    }

    // MARK: The right thing at the right moment

    private func dayInput(at date: Date) -> DailyBrief.Input {
        var input = DailyBrief.Input(now: date)
        input.weather = SampleData.weather(now: date)
        let course = Course(name: "Mathématiques")
        input.student.courses = [course]
        input.student.slots = [ClassSlot(courseID: course.id, weekday: 3, startMinute: 14 * 60, endMinute: 15 * 60 + 30, room: "B-204")]
        input.profile.provided = [.kcalTarget]
        input.nutrition.goals.kcal = 2_400
        input.content.habits = [Habit(name: "Lire", symbol: "book", colorHex: "7FA33A")]
        return input
    }

    func testMealsComeFirstThenClassesAndTheWeatherInTheMorning() {
        let tiles = DailyBrief.tiles(dayInput(at: wednesday(8)))
        XCTAssertEqual(ids(tiles).prefix(3), ["nutrition", "classes", "weather"])
        guard case let .classes(title, items)? = tiles.first(where: { $0.id == "classes" }) else { return XCTFail() }
        XCTAssertEqual(title, "Cours aujourd'hui")
        XCTAssertEqual(items.first?.title, "Mathématiques")
        XCTAssertEqual(items.first?.time, "14:00")
    }

    func testEveningStartsWithWhatIsLeftToEatAndTheHabits() {
        let tiles = DailyBrief.tiles(dayInput(at: wednesday(20)))
        XCTAssertEqual(ids(tiles).prefix(2), ["nutrition", "habits"])
        XCTAssertFalse(ids(tiles).contains("classes"), "No class tomorrow (Thursday): nothing to show")
    }

    func testAnExamTodayComesFirst() {
        var input = dayInput(at: wednesday(9))
        input.student.exams = [Exam(title: "Chimie", date: wednesday(16), room: "A-110")]
        let tiles = DailyBrief.tiles(input)
        guard case let .reminders(items)? = tiles.first(where: { $0.id == "reminders" }) else { return XCTFail("The exam is a reminder") }
        XCTAssertEqual(items.first?.title, "Examen : Chimie")
        XCTAssertEqual(items.first?.when, "Aujourd'hui 16:00")
        guard case let .classes(_, classes)? = tiles.first(where: { $0.id == "classes" }) else { return XCTFail() }
        XCTAssertTrue(classes.contains { $0.isHighlighted && $0.title == "Examen : Chimie" })
    }

    func testTheWorkoutFollowsTheSession() {
        var input = DailyBrief.Input(now: wednesday(17))
        let legs = Routine(name: "Jambes", exercises: [ExerciseTemplate(name: "Squat", sets: 2, reps: 8, weight: 80)], weekdays: [3])
        let upper = Routine(name: "Haut du corps", exercises: [ExerciseTemplate(name: "Développé", sets: 3, reps: 10, weight: 50)], weekdays: [5])
        input.fitness.routines = [upper, legs]
        guard case let .workout(planned)? = DailyBrief.tiles(input).first else { return XCTFail() }
        XCTAssertEqual(planned.name, "Jambes")
        XCTAssertEqual(planned.stage, .planned)
        XCTAssertEqual(planned.totalSets, 2)

        input.fitness.completeNextSet(at: input.now)
        guard case let .workout(running)? = DailyBrief.tiles(input).first else { return XCTFail() }
        guard case let .inProgress(exercise, set, sets, _, weight, _) = running.stage else { return XCTFail("\(running.stage)") }
        XCTAssertEqual(exercise, "Squat")
        XCTAssertEqual(set, 2)
        XCTAssertEqual(sets, 2)
        XCTAssertEqual(weight, 80)

        // Thursday: no session planned, Friday's is announced.
        var thursday = DailyBrief.Input(now: wednesday(9).addingTimeInterval(86_400))
        thursday.fitness.routines = [upper, legs]
        guard case let .workout(rest)? = DailyBrief.tiles(thursday).first else { return XCTFail() }
        XCTAssertEqual(rest.stage, .rest(nextName: "Haut du corps", nextDay: "Demain"))
    }

    func testRowsPairHalfTiles() {
        let tiles: [DailyBrief.Tile] = [.water(glasses: 1, goal: 8), .invite(.budget), .habits(done: 0, items: []), .steps(steps: 10, goal: nil), .budget(spentToday: 3, perDayLeft: nil)]
        let rows = DailyBrief.rows(tiles).map { $0.map(\.id) }
        XCTAssertEqual(rows, [["invite-budget"], ["water", "habits"], ["steps", "budget"]])
    }

    // MARK: One place for each value, example data only without it

    func testEveryWidgetKnowsWhatItNeeds() {
        XCTAssertEqual(WidgetKind.caloriesLeft.dataItems, [.kcalTarget, .meals])
        XCTAssertEqual(WidgetKind.clock.dataItems, [])
        let combo = Fusion.merge([WidgetDesign(kind: .caloriesLeft, format: .small), WidgetDesign(kind: .macros, format: .small)])!
        XCTAssertEqual(combo.dataItems, [.kcalTarget, .meals, .macroTargets], "A combined widget asks each thing once")
        for kind in WidgetKind.allCases {
            XCTAssertEqual(Set(kind.dataItems).count, kind.dataItems.count, "\(kind) repeats an item")
        }
    }

    func testPreviewsShowExamplesUntilTheDataIsGiven() {
        let model = temporaryModel()
        let calories = WidgetDesign(kind: .caloriesLeft)
        XCTAssertFalse(model.hasOwnData(for: calories), "No target yet: example data")
        XCTAssertFalse(model.previewPayload(for: calories).domains.nutrition.entries.isEmpty, "The example shows meals the person never logged")
        model.setNutritionTargets(kcal: 2_500)
        XCTAssertTrue(model.hasOwnData(for: calories), "Target given: the person's own widget, even before eating")
        XCTAssertEqual(model.previewPayload(for: calories).domains.nutrition.goals.kcal, 2_500)
        XCTAssertTrue(model.hasOwnData(for: WidgetDesign(kind: .clock)), "A clock needs nothing")
        XCTAssertFalse(model.hasOwnData(for: WidgetDesign(kind: .mealsToday)), "Only a log: example until a meal is logged")
    }

    func testAValueGivenForOneWidgetServesTheOthers() {
        let model = temporaryModel()
        XCTAssertEqual(model.missingItems(WidgetKind.caloriesLeft.dataItems), [.kcalTarget])
        model.setNutritionTargets(kcal: 2_200)
        // The next widget of a pack finds it filled, and so does « Mes informations ».
        XCTAssertTrue(model.missingItems(WidgetKind.nextMeal.dataItems).isEmpty)
        XCTAssertEqual(model.summary(.kcalTarget), "\(Fmt.number(2_200)) kcal par jour")
        XCTAssertEqual(DailyBrief.nutritionTile(DailyBrief.Input(model: model, steps: nil))?.goals.kcal, 2_200)
    }

    func testDefaultsNeverCountAsGiven() {
        let model = temporaryModel()
        for item in [DataItem.kcalTarget, .weeklyWorkouts, .monthlyBudget, .hydrationGoal, .focusGoal, .businessGoal, .carName, .stepGoal, .weight] {
            XCTAssertFalse(model.isFilled(item), "\(item) counts as given without the person")
        }
        XCTAssertEqual(model.completion.filled, 0)
    }
}
