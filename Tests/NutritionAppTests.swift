import XCTest
@testable import Tessera

/// The Nutrition mini-app: meals changed in place, meals kept and taken back, nutrients never made up,
/// averages over the days actually noted, ideas that fit what is left, one weight history.
final class NutritionAppTests: XCTestCase {
    /// Wednesday 30 September 2026 at the given hour.
    private func wednesday(_ hour: Int, dayOffset: Int = 0) -> Date {
        let base = DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: hour))!
        return DateMath.calendar.date(byAdding: .day, value: dayOffset, to: base)!
    }

    private func food(_ id: String) -> FoodItem {
        FoodDatabase.item("builtin.\(id)")!
    }

    func testAMealIsChangedAndEmptiedInPlace() {
        var state = NutritionState()
        let now = wednesday(8)
        state.log(food("oats"), grams: 60, meal: .breakfast, at: now)
        state.log(food("banana"), grams: 120, meal: .breakfast, at: now)
        let banana = NutritionMath.entries(state, on: now).first { $0.food.id == "builtin.banana" }!
        state.updateEntry(banana.id, grams: 60, meal: .snack)
        let moved = NutritionMath.entries(state, on: now).first { $0.id == banana.id }!
        XCTAssertEqual(moved.grams, 60)
        XCTAssertEqual(moved.meal, .snack)
        state.updateEntry(banana.id, grams: 0)
        XCTAssertEqual(NutritionMath.entries(state, on: now).first { $0.id == banana.id }?.grams, 60, "A zero quantity is ignored")
        state.deleteEntry(banana.id)
        XCTAssertEqual(NutritionMath.entries(state, on: now).map(\.food.id), ["builtin.oats"])
    }

    func testMealsAreKeptAndTakenBack() throws {
        var state = NutritionState()
        let yesterday = wednesday(12, dayOffset: -1)
        let today = wednesday(12)
        state.log(food("chicken"), grams: 150, meal: .lunch, at: yesterday)
        state.log(food("rice"), grams: 180, meal: .lunch, at: yesterday)

        let previous = NutritionMath.previousMeals(.lunch, state, before: today)
        XCTAssertEqual(previous.count, 1)
        XCTAssertEqual(previous.first?.items.map(\.food.id), ["builtin.chicken", "builtin.rice"])

        state.log(try XCTUnwrap(previous.first).items, meal: .lunch, on: today, at: today)
        XCTAssertEqual(NutritionMath.totals(state, on: today).kcal, NutritionMath.totals(state, on: yesterday).kcal, accuracy: 0.01)

        let saved = try XCTUnwrap(state.saveMeal(.lunch, on: yesterday, name: "  Bol poulet  "))
        XCTAssertEqual(saved.name, "Bol poulet")
        XCTAssertEqual(state.savedMeals.count, 1)
        XCTAssertNil(state.saveMeal(.dinner, on: yesterday, name: "Vide"), "An empty meal isn't saved")

        // A food added to an earlier day stays on that day.
        let date = NutritionMath.entryDate(for: .dinner, on: yesterday, now: today)
        XCTAssertTrue(DateMath.isSameDay(date, yesterday))
        XCTAssertEqual(DateMath.calendar.component(.hour, from: date), 19)
    }

    func testNutrientsAreNeverMadeUp() {
        var state = NutritionState()
        let now = wednesday(13)
        var plain = food("chicken")
        plain.sugars = nil
        plain.sodiumMg = nil
        state.log(plain, grams: 100, meal: .lunch, at: now)
        XCTAssertNil(NutritionMath.totals(state, on: now).sugars, "No food gave its sugars: unknown, not zero")

        state.log(food("yogurt"), grams: 100, meal: .lunch, at: now)
        let totals = NutritionMath.totals(state, on: now)
        XCTAssertEqual(totals.sugars ?? -1, 15, accuracy: 0.01)
        let coverage = NutritionMath.coverage(NutritionMath.entries(state, on: now), \.sugars)
        XCTAssertEqual(coverage, NutritionMath.Coverage(known: 1, total: 2))
        XCTAssertFalse(coverage.isComplete)
    }

    func testGoalsSavedBeforeTheLimitsKeepTheirValues() throws {
        let old = #"{"goals":{"kcal":2600,"protein":160,"carbs":280,"fat":80,"fiber":35},"entries":[]}"#
        let state = try JSONDecoder().decode(NutritionState.self, from: Data(old.utf8))
        XCTAssertEqual(state.goals.kcal, 2_600)
        XCTAssertEqual(state.goals.protein, 160)
        XCTAssertEqual(state.goals.sodiumMaxMg, 2_300)
        XCTAssertTrue(state.savedMeals.isEmpty)

        var saved = NutritionState()
        saved.savedMeals = [SavedMeal(name: "Test", items: [SavedMeal.Item(food: food("egg"), grams: 100)])]
        saved.goals.sugarsMax = 40
        let data = try JSONEncoder().encode(saved)
        let back = try JSONDecoder().decode(NutritionState.self, from: data)
        XCTAssertEqual(back.savedMeals.first?.items.first?.grams, 100)
        XCTAssertEqual(back.goals.sugarsMax, 40)
    }

    func testAveragesCountOnlyTheDaysNoted() {
        var state = NutritionState()
        state.goals.kcal = 2_000
        let start = wednesday(12, dayOffset: -3)
        // Day -3 and day -1 noted, day -2 empty.
        state.log(food("pasta"), grams: 1_265, meal: .lunch, at: wednesday(12, dayOffset: -3))
        state.log(food("pasta"), grams: 1_000, meal: .lunch, at: wednesday(12, dayOffset: -1))
        let stats = NutritionMath.stats(state, from: start, to: wednesday(12, dayOffset: -1))
        XCTAssertEqual(stats.days.count, 3)
        XCTAssertEqual(stats.trackedDays, 2)
        XCTAssertEqual(stats.averages.kcal, (1_265 + 1_000) * 1.58 / 2, accuracy: 1)
        XCTAssertEqual(stats.daysOnTarget, 1, "Only ~2 000 kcal is within 10 % of the goal")
        XCTAssertEqual(stats.kcalPerDay[1], 0)
    }

    func testIdeasFitWhatIsLeft() {
        for idea in NutritionMath.mealIdeas(for: 600) {
            XCTAssertLessThanOrEqual(idea.totals.kcal, 600)
            XCTAssertEqual(FoodDatabase.category(of: idea.food), .dishes)
        }
        XCTAssertFalse(NutritionMath.mealIdeas(for: 700).isEmpty)
        for idea in NutritionMath.proteinIdeas(within: 250) {
            XCTAssertLessThanOrEqual(idea.totals.kcal, 250)
            XCTAssertGreaterThanOrEqual(idea.food.protein, 8)
        }
        XCTAssertFalse(NutritionMath.fiberIdeas(within: nil).isEmpty)

        // What is left comes only from targets the person gave.
        var state = NutritionState()
        state.log(food("chicken"), grams: 100, meal: .lunch, at: wednesday(12))
        let unknown = NutritionMath.remaining(state, on: wednesday(12), knowsKcal: false, knowsProtein: false)
        XCTAssertNil(unknown.kcal)
        XCTAssertNil(unknown.protein)
    }

    func testTheFoodTableIsRichAndFindsWhatPeopleType() {
        XCTAssertGreaterThan(FoodDatabase.all.count, 190)
        XCTAssertEqual(Set(FoodDatabase.all.map(\.id)).count, FoodDatabase.all.count, "Each food once")
        for category in FoodCategory.allCases {
            XCTAssertFalse(FoodDatabase.foods(in: category).isEmpty, "\(category)")
        }
        XCTAssertTrue(FoodDatabase.search("poulet").first.map { FoodDatabase.normalized($0.name).contains("poulet") } ?? false)
        XCTAssertTrue(FoodDatabase.search("chips").contains { $0.id == "builtin.chips" }, "Chips → croustilles")
        XCTAssertTrue(FoodDatabase.search("oeuf").contains { $0.id == "builtin.egg" }, "oeuf finds Œuf")
        XCTAssertTrue(FoodDatabase.search("yaourt").contains { $0.id == "builtin.greekyogurt" })
        XCTAssertTrue(FoodDatabase.search("pates bl").contains { $0.id == "builtin.wholepasta" }, "Several word beginnings")
        XCTAssertEqual(FoodDatabase.search("banane").first?.id, "builtin.banana")
        for item in FoodDatabase.all {
            XCTAssertGreaterThanOrEqual(item.kcal, 0)
            XCTAssertLessThanOrEqual(item.protein + item.carbs + item.fat, 101, item.name)
        }
    }

    func testOneWeightHistory() {
        var profile = UserProfile()
        let monday = wednesday(8, dayOffset: -2)
        profile.recordWeight(80, at: monday)
        profile.recordWeight(79.6, at: monday.addingTimeInterval(3_600))
        profile.recordWeight(79.2, at: wednesday(8))
        XCTAssertEqual(profile.weightLog.map(\.value), [79.6, 79.2], "One value a day, the last one wins")
        XCTAssertEqual(profile.weightKg, 79.2)
        profile.recordWeight(nil)
        XCTAssertNil(profile.weightKg)
        XCTAssertEqual(profile.weightLog.count, 2, "Clearing the weight keeps the history")
        XCTAssertEqual(profile.weights(from: monday, to: wednesday(20)).count, 2)
    }
}
