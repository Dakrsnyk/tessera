import XCTest
@testable import Ardane

/// Audit prépublication 24 (Nutrition) : un test de non-régression par constat corrigé, sur le vrai code.
final class Audit24NutritionTests: XCTestCase {

    private func food(id: String = "custom.test", kcal: Double = 100, protein: Double = 5, carbs: Double = 10, fat: Double = 2,
                      unknownMacros: Set<MacroField>? = nil) -> FoodItem {
        FoodItem(id: id, name: "Test", brand: nil, kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: 1,
                 servingGrams: 100, servingName: "100 g", source: .custom, barcode: nil, unknownMacros: unknownMacros)
    }

    // N-05 : une quantité énorme ne plante pas et reste bornée.
    func testLoggedGramsAreClampedAndHugeStoredGramsDoNotCrash() {
        var state = NutritionState()
        let yesterday = Date().addingTimeInterval(-86_400)
        state.log(food(), grams: 1e19, meal: .lunch, at: yesterday)
        state.log(food(id: "b"), grams: .nan, meal: .lunch, at: yesterday)
        state.log(food(id: "c"), grams: -5, meal: .lunch, at: yesterday)
        XCTAssertEqual(state.entries.count, 1, "NaN et négatif sont refusés")
        XCTAssertEqual(state.entries[0].grams, NutritionState.maxGrams)

        // Une donnée déjà enregistrée et aberrante s'affiche sans plantage.
        state.entries.append(FoodEntry(date: yesterday.addingTimeInterval(60), meal: .lunch, food: food(id: "d"), grams: 1e300))
        state.entries.append(FoodEntry(date: yesterday.addingTimeInterval(120), meal: .lunch, food: food(id: "e"), grams: .infinity))
        let past = NutritionMath.previousMeals(.lunch, state, before: Date(), limit: 3)
        XCTAssertFalse(past.isEmpty)
        XCTAssertFalse(TF.int(past[0].totals.kcal).isEmpty)

        let id = state.entries[0].id
        state.updateEntry(id, grams: 1e19)
        XCTAssertEqual(state.entries[0].grams, NutritionState.maxGrams)
        state.updateEntry(id, grams: -3)
        XCTAssertEqual(state.entries[0].grams, NutritionState.maxGrams, "Une quantité refusée ne change rien")
    }

    // N-01 : une macro inconnue rend le total incomplet (jour, repas, moyennes).
    func testTotalsStayIncompleteWithAnUnknownMacro() {
        var state = NutritionState()
        let now = Date()
        state.log(food(unknownMacros: [.protein]), grams: 100, meal: .lunch, at: now)
        state.log(food(id: "ok"), grams: 100, meal: .lunch, at: now)
        XCTAssertTrue(NutritionMath.totals(state, on: now).isIncomplete)
        XCTAssertTrue(NutritionMath.totals(of: .lunch, state, on: now).isIncomplete)
        XCTAssertTrue(NutritionMath.stats(state, from: now, to: now).averages.isIncomplete)
        XCTAssertEqual(NutritionTotals().marked("5", incomplete: true), "≥ 5")
        XCTAssertEqual(NutritionTotals().marked("5", incomplete: false), "5")
    }

    // N-02 : des fibres absentes restent inconnues.
    func testMissingFiberIsUnknownNotZero() throws {
        let page = #"{"hits":[{"code":"1","nutriments":{"energy-kcal_100g":100,"proteins_100g":4,"carbohydrates_100g":5,"fat_100g":3},"product_name":"Sans fibres"},{"code":"2","nutriments":{"energy-kcal_100g":100,"proteins_100g":4,"carbohydrates_100g":5,"fat_100g":3,"fiber_100g":2},"product_name":"Avec fibres"}]}"#
        let foods = try OpenFoodFacts.searchResults(fromResponse: Data(page.utf8), statusCode: 200)
        XCTAssertEqual(foods.count, 2)
        XCTAssertNil(foods[0].knownFiber)
        XCTAssertEqual(try XCTUnwrap(foods[1].knownFiber), 2, accuracy: 0.001)
        XCTAssertTrue(foods[0].nutrients(grams: 100).isFiberIncomplete)
        XCTAssertFalse(foods[1].nutrients(grams: 100).isFiberIncomplete)
        let sum = foods[0].nutrients(grams: 100) + foods[1].nutrients(grams: 100)
        XCTAssertTrue(sum.isFiberIncomplete)
        XCTAssertFalse(sum.isIncomplete, "Les macros, elles, sont connues")
    }

    // N-06 : un aliment perso se corrige puis se supprime (les repas notés le gardent).
    func testCustomFoodCanBeEditedAndDeleted() {
        var state = NutritionState()
        let mine = food(kcal: 5000 / 10)
        state.customFoods = [mine]
        state.favorites = [mine]
        state.recentFoods = [mine]
        state.log(mine, grams: 100, meal: .lunch)
        var fixed = mine
        fixed.kcal = 120
        fixed.name = "Corrigé"
        XCTAssertTrue(state.updateCustomFood(fixed))
        XCTAssertEqual(state.customFoods[0].kcal, 120)
        XCTAssertEqual(state.favorites[0].name, "Corrigé")
        XCTAssertEqual(state.recentFoods[0].name, "Corrigé")
        XCTAssertFalse(state.updateCustomFood(food(id: "custom.unknown")), "Un aliment hors de la liste n'est pas ajouté")
        state.deleteCustomFood(mine.id)
        XCTAssertTrue(state.customFoods.isEmpty)
        XCTAssertTrue(state.favorites.isEmpty)
        XCTAssertTrue(state.recentFoods.isEmpty)
        XCTAssertEqual(state.entries.count, 1, "Le repas déjà noté garde l'aliment")
    }

    // N-07 : valeurs négatives ou impossibles refusées, 0 kcal à confirmer.
    func testCustomFoodValidation() {
        XCTAssertEqual(CustomFoodValidation.blockingProblem(kcal: -1, protein: 0, carbs: 0, fat: 0), .negative)
        XCTAssertEqual(CustomFoodValidation.blockingProblem(kcal: 100, protein: -2, carbs: 0, fat: 0), .negative)
        XCTAssertEqual(CustomFoodValidation.blockingProblem(kcal: .nan, protein: 0, carbs: 0, fat: 0), .negative)
        XCTAssertEqual(CustomFoodValidation.blockingProblem(kcal: 5_000, protein: 0, carbs: 0, fat: 0), .outOfRange)
        XCTAssertEqual(CustomFoodValidation.blockingProblem(kcal: 100, protein: 150, carbs: 0, fat: 0), .outOfRange)
        XCTAssertNil(CustomFoodValidation.blockingProblem(kcal: 52, protein: 0.3, carbs: 14, fat: 0.2))
        XCTAssertEqual(CustomFoodValidation.warning(kcal: 0, protein: 0, carbs: 0, fat: 0), .zeroEnergy)
        XCTAssertEqual(CustomFoodValidation.warning(kcal: 400, protein: 0, carbs: 1, fat: 0), .energyMismatch)
        XCTAssertNil(CustomFoodValidation.warning(kcal: 52, protein: 0.3, carbs: 14, fat: 0.2))
        var state = NutritionState()
        let mine = food()
        state.customFoods = [mine]
        var bad = mine
        bad.kcal = -50
        XCTAssertFalse(state.updateCustomFood(bad))
        XCTAssertEqual(state.customFoods[0].kcal, 100)
    }

    // N-01 : les tuiles de widgets marquent un total incomplet, et seulement lui.
    func testTilesMarkAnIncompleteTotal() {
        var state = NutritionState()
        let now = Date()
        state.log(food(unknownMacros: [.protein]), grams: 100, meal: .lunch, at: now)
        let marked = NutritionTiles.macroRows(NutritionMath.totals(state, on: now), goals: state.goals)
        XCTAssertTrue(marked.allSatisfy { ($0.value ?? "").hasPrefix(NutritionTotals.minimumMarker) })

        var complete = NutritionState()
        complete.log(food(), grams: 100, meal: .lunch, at: now)
        let plain = NutritionTiles.macroRows(NutritionMath.totals(complete, on: now), goals: complete.goals)
        XCTAssertTrue(plain.allSatisfy { !($0.value ?? "").contains("≥") })
        XCTAssertFalse(NutritionTiles.proteinLeft(complete, now: now).value.contains("≤"))
        XCTAssertTrue(NutritionTiles.proteinLeft(state, now: now).value.hasPrefix("≤"))
    }

    // N-05 : la quantité d'un aliment perso borne aussi une saisie énorme à la sauvegarde.
    func testQuickLogAndUpdateStayInsideTheLimits() {
        var state = NutritionState()
        state.log(food(), grams: 6_000, meal: .snack)
        XCTAssertEqual(state.entries[0].grams, 5_000)
        XCTAssertNil(NutritionState.safeGrams(.nan))
        XCTAssertNil(NutritionState.safeGrams(0))
        XCTAssertEqual(NutritionState.safeGrams(.infinity), 5_000)
    }
}
