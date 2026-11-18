import XCTest
@testable import Ardane

/// The data behind the hybrid Nutrition page: the calorie goal dated « depuis le … » and a saved meal changed in place.
final class NutritionHybridTests: XCTestCase {
    private func date(_ month: Int, _ day: Int) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private func food(_ id: String, kcal: Double = 100) -> FoodItem {
        FoodItem(id: id, name: id, brand: nil, kcal: kcal, protein: 5, carbs: 10, fat: 2, fiber: 1,
                 servingGrams: 100, servingName: "100 g", source: .custom, barcode: nil)
    }

    // MARK: The goal, dated

    func testTheFirstGoalIsRememberedWithoutADate() {
        var state = NutritionState()
        XCTAssertTrue(state.trackGoalChange(now: date(11, 5)))
        XCTAssertEqual(state.kcalGoalSeen, state.goals.kcal)
        XCTAssertNil(state.kcalGoalSince, "The first goal is not a change: no invented date")
    }

    func testAChangedGoalIsDatedAndAnUnchangedOneIsNot() {
        var state = NutritionState()
        state.trackGoalChange(now: date(11, 1))
        XCTAssertFalse(state.trackGoalChange(now: date(11, 2)), "Nothing changed")
        state.goals.kcal = 2_000
        XCTAssertTrue(state.trackGoalChange(now: date(11, 5)))
        XCTAssertEqual(state.kcalGoalSeen, 2_000)
        XCTAssertEqual(state.kcalGoalSince, date(11, 5))
        XCTAssertFalse(state.trackGoalChange(now: date(11, 9)))
        XCTAssertEqual(state.kcalGoalSince, date(11, 5), "The date stays the day of the change")
    }

    func testAnOldSaveWithoutTheGoalFieldsStillDecodes() throws {
        let data = try JSONEncoder().encode(NutritionState())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "kcalGoalSeen")
        object.removeValue(forKey: "kcalGoalSince")
        let old = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(NutritionState.self, from: old)
        XCTAssertNil(decoded.kcalGoalSeen)
        XCTAssertNil(decoded.kcalGoalSince)
    }

    func testTheGoalFieldsSurviveASaveAndALoad() throws {
        var state = NutritionState()
        state.trackGoalChange(now: date(11, 1))
        state.goals.kcal = 1_900
        state.trackGoalChange(now: date(11, 6))
        let decoded = try JSONDecoder().decode(NutritionState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.kcalGoalSeen, 1_900)
        XCTAssertEqual(decoded.kcalGoalSince, date(11, 6))
    }

    // MARK: A saved meal, changed

    func testASavedMealIsRenamedAndItsFoodsChanged() {
        var state = NutritionState()
        let saved = SavedMeal(name: "Bol", items: [.init(food: food("riz"), grams: 150), .init(food: food("poulet"), grams: 120)])
        state.savedMeals = [saved]
        XCTAssertTrue(state.updateSavedMeal(saved.id, name: "  Bol poulet et riz ", items: [.init(food: food("poulet"), grams: 200)]))
        XCTAssertEqual(state.savedMeals.first?.name, "Bol poulet et riz")
        XCTAssertEqual(state.savedMeals.first?.items.count, 1)
        XCTAssertEqual(state.savedMeals.first?.items.first?.grams, 200)
        XCTAssertEqual(state.savedMeals.first?.id, saved.id, "Same meal, same id")
    }

    func testASavedMealKeepsItsNameWhenTheNewOneIsEmptyAndRefusesNoFood() {
        var state = NutritionState()
        let saved = SavedMeal(name: "Bol", items: [.init(food: food("riz"), grams: 150)])
        state.savedMeals = [saved]
        XCTAssertTrue(state.updateSavedMeal(saved.id, name: "   ", items: [.init(food: food("riz"), grams: 100)]))
        XCTAssertEqual(state.savedMeals.first?.name, "Bol")
        XCTAssertFalse(state.updateSavedMeal(saved.id, name: "Vide", items: []), "A meal without a food is refused")
        XCTAssertFalse(state.updateSavedMeal(saved.id, name: "Vide", items: [.init(food: food("riz"), grams: 0)]), "A quantity of zero is not a food")
        XCTAssertEqual(state.savedMeals.first?.items.first?.grams, 100)
        XCTAssertFalse(state.updateSavedMeal(UUID(), name: "Autre", items: [.init(food: food("riz"), grams: 50)]), "Unknown meal")
    }
}
