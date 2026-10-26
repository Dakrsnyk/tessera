import XCTest
@testable import Ardane

/// The nutrients of Premium: many more nutrients (fats, minerals, vitamins, caffeine, alcohol), read from
/// the Canadian Nutrient File, added up without made-up zeros, with targets from recognized references
/// by age and gender, typed targets kept, and data saved before still read. Only the calories, protein,
/// carbohydrates and fat are free.
@MainActor
final class NutritionPremiumTests: XCTestCase {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func temporaryModel(_ directory: URL? = nil) -> AppModel {
        AppModel(store: SharedStore(directory: directory ?? temporaryDirectory()))
    }

    private func bodyFilled(_ model: AppModel) {
        model.setAge(30)
        model.setWeight(70)
        model.update(\.profile) {
            $0.heightCm = 165
            $0.sex = .female
        }
    }

    // MARK: Free and Premium

    func testOnlyTheCaloriesAndTheThreeMacronutrientsAreFree() {
        XCTAssertEqual(Nutrient.allCases.filter { !$0.isPremium }, [.kcal, .protein, .carbs, .fat])
        XCTAssertEqual(NutritionTarget.allCases.filter { !$0.isPremium }, [.kcal, .protein, .carbs, .fat])
        XCTAssertTrue(Nutrient.fiber.isPremium)
        XCTAssertTrue(Nutrient.sodium.isPremium)
        XCTAssertGreaterThanOrEqual(Nutrient.allCases.filter(\.isPremium).count, 30, "Many more nutrients")
        for group in Nutrient.Group.allCases {
            XCTAssertFalse(group.nutrients.isEmpty, "\(group)")
        }
    }

    func testEveryTargetIsTheTargetOfItsNutrientWithItsOwnValue() {
        var goals = NutritionGoals()
        for (index, target) in NutritionTarget.allCases.enumerated() {
            XCTAssertEqual(target.nutrient.rawValue, target.rawValue)
            XCTAssertEqual(target.nutrient.target, target)
            goals[target] = Double(1_000 + index)
        }
        for (index, target) in NutritionTarget.allCases.enumerated() {
            XCTAssertEqual(goals[target], Double(1_000 + index), "\(target) has a value of its own")
        }
        // No recognized daily reference: shown, never given a made-up target.
        for nutrient in [Nutrient.cholesterol, .alcohol, .monounsaturatedFat, .polyunsaturatedFat] {
            XCTAssertNil(nutrient.target)
        }
        XCTAssertTrue(NutritionTarget.transFat.isLimit)
        XCTAssertTrue(NutritionTarget.caffeine.isLimit)
        XCTAssertFalse(NutritionTarget.zinc.isLimit)
    }

    // MARK: Totals

    func testNewNutrientsAddUpAndAnUnknownValueStaysUnknown() throws {
        var almonds = FoodItem(id: "a", name: "Amandes", kcal: 579, protein: 21, carbs: 22, fat: 50, fiber: 12.5, servingGrams: 30, servingName: "30 g", source: .nutrientFile)
        almonds.micros = Micronutrients(magnesiumMg: 270, zincMg: 3.1, phosphorusMg: 481, vitaminEMg: 25.6, riboflavinMg: 1.14)
        var coffee = FoodItem(id: "b", name: "Café", kcal: 1, protein: 0.1, carbs: 0, fat: 0, fiber: 0, servingGrams: 250, servingName: "1 tasse", source: .nutrientFile)
        coffee.micros = Micronutrients(caffeineMg: 40, alcohol: 0)
        let bread = FoodItem(id: "c", name: "Pain", kcal: 265, protein: 9, carbs: 49, fat: 3.2, fiber: 2.7, servingGrams: 50, servingName: "1 tranche", source: .custom)
        var state = NutritionState()
        let now = Date()
        state.log(almonds, grams: 50, meal: .snack, at: now)
        state.log(coffee, grams: 250, meal: .breakfast, at: now)
        state.log(bread, grams: 50, meal: .breakfast, at: now)
        let totals = NutritionMath.totals(state, on: now)

        XCTAssertEqual(try XCTUnwrap(totals.micros.zincMg), 1.55, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(totals.micros.vitaminEMg), 12.8, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(Nutrient.caffeine.value(in: totals)), 100, accuracy: 0.001)
        XCTAssertEqual(Nutrient.alcohol.value(in: totals), 0, "A zero the source gives stays a zero")
        XCTAssertNil(Nutrient.selenium.value(in: totals), "Unknown for every food: never shown as zero")
        XCTAssertNil(Nutrient.omega3.value(in: totals))
        XCTAssertEqual(Nutrient.riboflavin.value(in: totals), totals.micros.riboflavinMg)
        XCTAssertEqual(NutritionTarget.zinc.eaten(totals), totals.micros.zincMg)

        let entries = NutritionMath.entries(state, on: now)
        let zinc = try XCTUnwrap(Nutrient.zinc.foodPath)
        XCTAssertEqual(NutritionMath.coverage(entries, zinc), NutritionMath.Coverage(known: 1, total: 3), "Marked partial")
        XCTAssertNil(Nutrient.fiber.foodPath, "Every food has its fibre")
    }

    // MARK: Targets

    func testTheCalculatorGivesThePremiumTargetsByAgeAndGender() {
        let female = NutritionCalculator.goals(sex: .female, age: 30, heightCm: 165, weightKg: 60, activity: .light, goal: .maintain)
        XCTAssertEqual(female.transFatMax, (female.kcal * 0.01 / 9 * 10).rounded() / 10, "Under 1 % of the calories (WHO)")
        XCTAssertEqual(female.caffeineMaxMg, 400, "Health Canada")
        XCTAssertEqual(female.omega3Fat, 1.1)
        XCTAssertEqual(female.omega6Fat, 12)
        XCTAssertEqual(female.zincMg, 8)
        XCTAssertEqual(female.phosphorusMg, 700)
        XCTAssertEqual(female.seleniumMcg, 55)
        XCTAssertEqual(female.copperMg, 0.9)
        XCTAssertEqual(female.manganeseMg, 1.8)
        XCTAssertEqual(female.vitaminEMg, 15)
        XCTAssertEqual(female.vitaminKMcg, 90)
        XCTAssertEqual(female.thiaminMg, 1.1)
        XCTAssertEqual(female.riboflavinMg, 1.1)
        XCTAssertEqual(female.niacinMg, 14)
        XCTAssertEqual(female.pantothenicAcidMg, 5)
        XCTAssertEqual(female.vitaminB6Mg, 1.3)
        XCTAssertEqual(female.cholineMg, 425)

        let male = NutritionCalculator.goals(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .moderate, goal: .maintain)
        XCTAssertEqual(male.zincMg, 11)
        XCTAssertEqual(male.omega3Fat, 1.6)
        XCTAssertEqual(male.omega6Fat, 17)
        XCTAssertEqual(male.manganeseMg, 2.3)
        XCTAssertEqual(male.vitaminKMcg, 120)
        XCTAssertEqual(male.thiaminMg, 1.2)
        XCTAssertEqual(male.riboflavinMg, 1.3)
        XCTAssertEqual(male.niacinMg, 16)
        XCTAssertEqual(male.cholineMg, 550)
        XCTAssertGreaterThan(male.transFatMax, female.transFatMax, "Follows the calories")

        let olderMale = NutritionCalculator.goals(sex: .male, age: 60, heightCm: 180, weightKg: 80, activity: .light, goal: .maintain)
        XCTAssertEqual(olderMale.vitaminB6Mg, 1.7, "Over 50")
        XCTAssertEqual(olderMale.omega6Fat, 14)
        let olderFemale = NutritionCalculator.goals(sex: .female, age: 60, heightCm: 165, weightKg: 60, activity: .light, goal: .maintain)
        XCTAssertEqual(olderFemale.vitaminB6Mg, 1.5)
        XCTAssertEqual(olderFemale.omega6Fat, 11)

        let neutral = NutritionCalculator.goals(sex: .neutral, age: 30, heightCm: 170, weightKg: 70, activity: .light, goal: .maintain)
        XCTAssertEqual(neutral.thiaminMg, 1.2, "1,15 mg, the average of both references, kept to a decimal")
        XCTAssertEqual(neutral.manganeseMg, 2.1)
        XCTAssertEqual(neutral.omega3Fat, 1.4)
        XCTAssertEqual(neutral.zincMg, 10)
        XCTAssertEqual(neutral.ironMg, 13, "Unchanged for the earlier nutrients")
    }

    func testAPremiumTargetTypedByHandIsKeptAndTheOthersFollow() {
        let model = temporaryModel()
        bodyFilled(model)
        XCTAssertEqual(model.nutrition.goals.cholineMg, 425)
        model.setNutritionTarget(.zinc, 15)
        XCTAssertTrue(model.profile.customTargets.contains(.zinc))
        model.setWeight(64)
        XCTAssertEqual(model.nutrition.goals.zincMg, 15, "Kept as typed")
        XCTAssertEqual(model.recommendedNutritionGoals()?.zincMg, 8, "The recommendation shown beside it")
        model.resetNutritionTarget(.zinc)
        model.followCalculatedNutritionGoals()
        XCTAssertEqual(model.nutrition.goals.zincMg, 8)
    }

    func testTargetsSavedBeforeThePremiumNutrientsFollowTheCalculationWithoutLosingTypedOnes() throws {
        let directory = temporaryDirectory()
        let store = SharedStore(directory: directory)
        var profile = UserProfile()
        profile.migrated = true
        profile.heightCm = 165
        profile.weightKg = 60
        profile.birthYear = DateMath.calendar.component(.year, from: Date()) - 30
        profile.sex = .female
        profile.nutritionAuto = true
        profile.provided = [.kcalTarget, .proteinTarget, .carbsTarget, .fatTarget]
        profile.customTargets = [.iron]
        store.save(profile)
        // Saved by an earlier version: no key for the nutrients of Premium, iron typed by hand.
        let old = #"{"goals":{"kcal":1900,"protein":90,"carbs":220,"fat":60,"fiber":27,"ironMg":25,"vitaminDMcg":15},"entries":[]}"#
        let saved = try JSONDecoder().decode(NutritionState.self, from: Data(old.utf8))
        XCTAssertEqual(saved.goals.zincMg, NutritionGoals().zincMg, "Read with the default first")
        store.save(saved)

        let model = temporaryModel(directory)
        model.followCalculatedNutritionGoals()
        XCTAssertEqual(model.nutrition.goals.zincMg, 8, "Then calculated for the person")
        XCTAssertEqual(model.nutrition.goals.omega3Fat, 1.1)
        XCTAssertEqual(model.nutrition.goals.caffeineMaxMg, 400)
        XCTAssertEqual(model.nutrition.goals.ironMg, 25, "Typed by hand: never replaced")
    }

    func testAPremiumTargetShowsOnlyOnceItIsThePersonsOwn() {
        let model = temporaryModel()
        XCTAssertNil(model.recommendedNutritionGoals())
        XCTAssertNil(model.shownNutritionTarget(.zinc, recommended: nil), "The built-in default is not the person's target")
        XCTAssertNil(model.shownNutritionTarget(.fiber, recommended: nil))
        model.setNutritionTarget(.vitaminK, 100)
        XCTAssertEqual(model.shownNutritionTarget(.vitaminK, recommended: nil), 100, "Typed by hand: the person's own")

        bodyFilled(model)
        let recommended = model.recommendedNutritionGoals()
        XCTAssertNotNil(recommended)
        XCTAssertEqual(model.shownNutritionTarget(.zinc, recommended: recommended), 8)
        XCTAssertEqual(model.shownNutritionTarget(.vitaminK, recommended: recommended), 100)

        model.setNutritionCalculation(false)
        XCTAssertEqual(model.shownNutritionTarget(.zinc, recommended: recommended), 8, "Kept as they are, the person's own")
    }

    func testAFoodShowsItsCaffeineAndAlcoholOnlyWhenItHasSome() {
        var spinach = FoodItem(id: "s", name: "Épinards", kcal: 23, protein: 2.9, carbs: 3.6, fat: 0.4, fiber: 2.2, servingGrams: 100, servingName: "100 g", source: .nutrientFile)
        spinach.micros = Micronutrients(ironMg: 2.7, zincMg: 0, caffeineMg: 0, alcohol: 0)
        let totals = spinach.nutrients(grams: 100)
        XCTAssertFalse(FoodNutrientSections.shows(.caffeine, in: totals), "No « Caféine 0 mg » on spinach")
        XCTAssertFalse(FoodNutrientSections.shows(.alcohol, in: totals))
        XCTAssertEqual(Nutrient.caffeine.value(in: totals), 0, "Still a known zero for the day's totals")
        XCTAssertTrue(FoodNutrientSections.shows(.iron, in: totals))
        XCTAssertTrue(FoodNutrientSections.shows(.zinc, in: totals), "Another zero the source gives is shown")
        XCTAssertFalse(FoodNutrientSections.shows(.selenium, in: totals), "Unknown: not shown")
        var coffee = spinach
        coffee.micros = Micronutrients(caffeineMg: 40, alcohol: 0)
        XCTAssertTrue(FoodNutrientSections.shows(.caffeine, in: coffee.nutrients(grams: 250)))
    }

    // MARK: Saved data

    func testFoodsAndGoalsSavedBeforeStillRead() throws {
        let food = try JSONDecoder().decode(FoodItem.self, from: Data(#"{"id":"x","name":"Lait","kcal":64,"protein":3.3,"carbs":4.8,"fat":3.3,"fiber":0,"servingGrams":250,"servingName":"1 tasse","source":"nutrientFile","micros":{"potassiumMg":150,"calciumMg":120}}"#.utf8))
        let micros = try XCTUnwrap(food.micros)
        XCTAssertEqual(micros.calciumMg, 120)
        XCTAssertNil(micros.zincMg)
        XCTAssertNil(micros.caffeineMg)

        let goals = try JSONDecoder().decode(NutritionGoals.self, from: Data(#"{"kcal":2500,"protein":150,"ironMg":18}"#.utf8))
        XCTAssertEqual(goals.ironMg, 18)
        XCTAssertEqual(goals.cholineMg, NutritionGoals().cholineMg)
        XCTAssertEqual(goals.transFatMax, NutritionGoals().transFatMax)

        var changed = NutritionGoals()
        changed.seleniumMcg = 70
        changed.caffeineMaxMg = 200
        let back = try JSONDecoder().decode(NutritionGoals.self, from: JSONEncoder().encode(changed))
        XCTAssertEqual(back, changed)

        var item = food
        item.micros?.vitaminKMcg = 0.3
        item.micros?.alcohol = 4
        let decoded = try JSONDecoder().decode(FoodItem.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(decoded, item)

        let profile = try JSONDecoder().decode(UserProfile.self, from: Data(#"{"customTargets":["zinc","caffeine","kcal"]}"#.utf8))
        XCTAssertEqual(profile.customTargets, [.zinc, .caffeine, .kcal])
    }

    // MARK: Canadian Nutrient File

    func testTheNutrientFileGivesTheNewNutrientsOnlyWhereItHasThem() throws {
        guard !NutrientFile.isEmpty else { return XCTFail("cnf-foods.json missing from the app") }
        let espresso = try XCTUnwrap(NutrientFile.search("espresso").first { $0.id == "cnf.4779" })
        XCTAssertEqual(espresso.micros?.caffeineMg, 212)
        XCTAssertEqual(espresso.micros?.alcohol, 0)
        XCTAssertNil(espresso.micros?.omega3Fat, "No value in the file: unknown")
        let spinach = try XCTUnwrap(NutrientFile.search("spinach raw").first { $0.id == "cnf.2213" })
        XCTAssertEqual(try XCTUnwrap(spinach.micros?.vitaminKMcg), 482.9, accuracy: 0.01)
        XCTAssertEqual(spinach.micros?.potassiumMg, 558, "The earlier columns are still read")
        let napa = try XCTUnwrap(NutrientFile.search("napa").first { $0.id == "cnf.501098" })
        XCTAssertNil(napa.micros, "A row without any added value")
    }

    // MARK: Widgets

    func testTheMacrosWidgetShowsTheFibreOnlyWithPremium() {
        var state = NutritionState()
        let now = Date()
        state.log(FoodItem(id: "a", name: "Pomme", kcal: 52, protein: 0.3, carbs: 14, fat: 0.2, fiber: 2.4, servingGrams: 180, servingName: "1", source: .builtin), grams: 180, meal: .snack, at: now)
        let premium = NutritionTiles.macros(state, now: now, compact: false)
        let free = NutritionTiles.macros(state, now: now, compact: false, showsFiber: false)
        XCTAssertNotEqual(premium.caption, free.caption)
        XCTAssertEqual(free.caption, tr("sur \(TF.int(state.goals.kcal))"))
        XCTAssertEqual(free.rows.count, premium.rows.count, "The three macronutrients stay free")
    }
}
