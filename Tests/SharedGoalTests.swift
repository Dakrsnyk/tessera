import XCTest
@testable import Ardane

/// Un seul objectif pour Sport et Nutrition (2026-11-17): the energy and the protein of each goal, the old
/// goals unchanged, the safety bounds for every goal, the older accounts read as before, values set by hand
/// never written over, the pregnancy question for any loss or gain, and the activity labels.
@MainActor
final class SharedGoalTests: XCTestCase {
    private func makeModel(goal: FitnessGoal? = nil, activity: NutritionCalculator.Activity = .moderate) -> AppModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let model = AppModel(store: SharedStore(directory: directory))
        model.setAge(30)
        model.setWeight(80)
        model.update(\.profile) {
            $0.heightCm = 180
            $0.sex = .male
            $0.calculatedActivity = activity
        }
        model.setGoal(goal)
        model.followCalculatedNutritionGoals()
        return model
    }

    private func decode(_ json: String) throws -> UserProfile {
        try JSONDecoder().decode(UserProfile.self, from: Data(json.utf8))
    }

    /// A man of 30, 180 cm, 80 kg, moderately active: 1 780 kcal at rest, 2 759 spent a day.
    private func goals(_ goal: NutritionCalculator.Goal) -> NutritionGoals {
        NutritionCalculator.goals(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .moderate, goal: goal)
    }

    // MARK: Energy and protein of each goal

    func testEnergyAndProteinOfEachGoal() {
        let expected: [(NutritionCalculator.Goal, Double, Double)] = [
            (.lose, 2_345, 144),
            (.cut, 2_207, 176),
            (.maintain, 2_759, 128),
            (.recomposition, 2_759, 160),
            (.gain, 3_035, 160),
            (.massGain, 3_173, 160),
            (.performance, 2_759, 128),
        ]
        for (goal, kcal, protein) in expected {
            let result = goals(goal)
            XCTAssertEqual(result.kcal, kcal, accuracy: 0.5, "\(goal) kcal")
            XCTAssertEqual(result.protein, protein, accuracy: 0.5, "\(goal) protein")
            // Fat 28 % of the calories, the carbohydrates are the rest: unchanged.
            XCTAssertEqual(result.fat, (kcal * 0.28 / 9).rounded(), accuracy: 0.5, "\(goal) fat")
            XCTAssertEqual(result.carbs, ((kcal - protein * 4 - result.fat * 9) / 4).rounded(), accuracy: 0.5, "\(goal) carbs")
        }
    }

    func testAnotherBodyForTheNewGoals() {
        // A woman of 28, 165 cm, 60 kg, lightly active: 1 330 at rest, 1 829 spent.
        func result(_ goal: NutritionCalculator.Goal) -> NutritionGoals {
            NutritionCalculator.goals(sex: .female, age: 28, heightCm: 165, weightKg: 60, activity: .light, goal: goal)
        }
        let spent = (1_330.25 * 1.375).rounded()
        XCTAssertEqual(result(.maintain).kcal, spent, accuracy: 0.5)
        XCTAssertEqual(result(.cut).kcal, (spent * 0.8).rounded(), accuracy: 0.5)
        // 2,2 g/kg would be 132 g, but the protein stays within 35 % of the calories (1 463 kcal: 128 g).
        XCTAssertEqual(result(.cut).protein, 128, accuracy: 0.5)
        XCTAssertEqual(result(.massGain).kcal, (spent * 1.15).rounded(), accuracy: 0.5)
        XCTAssertEqual(result(.massGain).protein, 120, accuracy: 0.5)
        XCTAssertEqual(result(.recomposition).protein, 120, accuracy: 0.5)
        XCTAssertEqual(result(.performance).protein, 96, accuracy: 0.5)
        // Performance asks 1,6 g/kg even when the activity is low (maintaining asks 1,2 there).
        XCTAssertEqual(result(.maintain).protein, 72, accuracy: 0.5)
    }

    func testAMassGainSurplusIsCappedAt500() {
        // 185 cm, 100 kg, very active: 3 469 kcal spent, 15 % would be 520.
        let capped = NutritionCalculator.goals(sex: .male, age: 30, heightCm: 185, weightKg: 100, activity: .active, goal: .massGain)
        XCTAssertEqual(capped.kcal, 3_969, accuracy: 1)
        let steps = NutritionCalculator.breakdown(sex: .male, age: 30, heightCm: 185, weightKg: 100, activity: .active, goal: .massGain)
        XCTAssertEqual(steps.dailyKcal, 3_469, accuracy: 0.5)
        XCTAssertLessThan(steps.goalAdjustment, 0.15)
        // Under the cap, the full 15 %.
        XCTAssertEqual(NutritionCalculator.breakdown(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .moderate, goal: .massGain).goalAdjustment, 0.15, accuracy: 0.0001)
    }

    func testTheThreeOlderGoalsKeepTheirNumbers() {
        XCTAssertEqual(goals(.lose).kcal, 2_345, accuracy: 0.5)
        XCTAssertEqual(goals(.lose).protein, 144, accuracy: 0.5)
        XCTAssertEqual(goals(.maintain).kcal, 2_759, accuracy: 0.5)
        XCTAssertEqual(goals(.gain).kcal, 3_035, accuracy: 0.5)
        XCTAssertEqual(goals(.gain).protein, 160, accuracy: 0.5)
        // Maintaining still asks less protein for a low activity.
        let sedentary = NutritionCalculator.goals(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .sedentary, goal: .maintain)
        XCTAssertEqual(sedentary.protein, 96, accuracy: 0.5)
        // Goals of the weight plan and of the older aims map to the same calculation as before.
        XCTAssertEqual(NutritionAim.lose.calculatorGoal, .lose)
        XCTAssertEqual(NutritionAim.maintain.calculatorGoal, .maintain)
        XCTAssertEqual(NutritionAim.gain.calculatorGoal, .gain)
    }

    func testEveryGoalMapsToACalculation() {
        let expected: [FitnessGoal: NutritionCalculator.Goal] = [
            .weightLoss: .lose, .cut: .cut, .maintain: .maintain, .recomposition: .recomposition,
            .muscleGain: .gain, .strength: .gain, .bulk: .massGain, .performance: .performance, .endurance: .performance,
        ]
        XCTAssertEqual(Set(expected.keys), Set(FitnessGoal.allCases))
        XCTAssertEqual(Set(FitnessGoal.displayOrder), Set(FitnessGoal.allCases))
        for (goal, calculation) in expected { XCTAssertEqual(goal.calculatorGoal, calculation, "\(goal)") }
        // The saved values never changed name.
        for name in ["bulk", "weightLoss", "cut", "performance", "maintain", "strength", "endurance", "muscleGain", "recomposition"] {
            XCTAssertNotNil(FitnessGoal(rawValue: name), name)
        }
    }

    // MARK: Safety

    func testEveryDeficitAndSurplusGoesThroughTheSafetyRefusals() {
        for goal in [NutritionCalculator.Goal.lose, .cut, .gain, .massGain, .recomposition, .performance] {
            XCTAssertEqual(NutritionSafety.allowedGoal(goal, heightCm: 175, weightKg: 70, isMinor: true, lifeStage: nil), .maintain, "minor \(goal)")
            XCTAssertEqual(NutritionSafety.allowedGoal(goal, heightCm: 175, weightKg: 70, isMinor: false, lifeStage: .pregnant), .maintain, "pregnant \(goal)")
            XCTAssertEqual(NutritionSafety.allowedGoal(goal, heightCm: 175, weightKg: 70, isMinor: false, lifeStage: .breastfeeding), .maintain, "breastfeeding \(goal)")
            XCTAssertEqual(NutritionSafety.allowedGoal(goal, heightCm: 175, weightKg: 70, isMinor: false, lifeStage: .adult), goal, "adult \(goal)")
        }
        // A low body mass index (17,96): no deficit, a gain is fine. From 30: no surplus.
        XCTAssertEqual(NutritionSafety.allowedGoal(.cut, heightCm: 175, weightKg: 55, isMinor: false, lifeStage: .adult), .maintain)
        XCTAssertEqual(NutritionSafety.allowedGoal(.lose, heightCm: 175, weightKg: 55, isMinor: false, lifeStage: .adult), .maintain)
        XCTAssertEqual(NutritionSafety.allowedGoal(.massGain, heightCm: 175, weightKg: 55, isMinor: false, lifeStage: .adult), .massGain)
        XCTAssertEqual(NutritionSafety.allowedGoal(.massGain, heightCm: 175, weightKg: 100, isMinor: false, lifeStage: .adult), .maintain)
        XCTAssertEqual(NutritionSafety.allowedGoal(.gain, heightCm: 175, weightKg: 100, isMinor: false, lifeStage: .adult), .maintain)
    }

    func testACutNeverGoesUnderTheCaloriesFloor() throws {
        // 55 kg, 1,60 m, 60 years, sedentary: 1 506 spent, 80 % is 1 205, under the floor of 1 500.
        let cut = try XCTUnwrap(NutritionSafety.goals(sex: .male, age: 60, heightCm: 160, weightKg: 55, activity: .sedentary, goal: .cut))
        XCTAssertEqual(cut.kcal, NutritionSafety.minimumKcal(sex: .male, age: 60, heightCm: 160, weightKg: 55), accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(cut.kcal, 1_400)
        // Typed calories are never changed.
        XCTAssertEqual(NutritionSafety.goals(sex: .male, age: 60, heightCm: 160, weightKg: 55, activity: .sedentary, goal: .cut, kcal: 1_200)?.kcal, 1_200)
        // Body data outside the ranges: nothing.
        XCTAssertNil(NutritionSafety.goals(sex: .male, age: 8, heightCm: 130, weightKg: 30, activity: .light, goal: .cut))
    }

    func testAMinorAndAPregnancyGetNoSurplusOrDeficitFromAnyGoalOfTheList() {
        for goal in FitnessGoal.allCases {
            let minor = makeModel(goal: goal)
            minor.setAge(16)
            XCTAssertEqual(minor.nutritionGoal, .maintain, "minor \(goal)")
            let pregnant = makeModel(goal: goal)
            pregnant.update(\.profile) { $0.sex = .female; $0.lifeStage = .pregnant }
            XCTAssertEqual(pregnant.nutritionGoal, .maintain, "pregnant \(goal)")
        }
    }

    // MARK: Older accounts

    func testAnAccountWithOnlyTheSportGoalIsUnchanged() throws {
        let profile = try decode(#"{"fitnessGoal":"cut"}"#)
        XCTAssertEqual(profile.goal, .cut)
        XCTAssertEqual(profile.aim, .lose)
        XCTAssertNil(profile.nutritionAim, "The older field is not written by reading")
        XCTAssertEqual(try decode(#"{"fitnessGoal":"bulk"}"#).aim, .gain)
        XCTAssertEqual(try decode(#"{"fitnessGoal":"performance"}"#).aim, .maintain)
    }

    func testAnAccountWithOnlyTheNutritionAimIsRead() throws {
        XCTAssertEqual(try decode(#"{"nutritionAim":"lose"}"#).goal, .weightLoss)
        XCTAssertEqual(try decode(#"{"nutritionAim":"maintain"}"#).goal, .maintain)
        XCTAssertEqual(try decode(#"{"nutritionAim":"gain"}"#).goal, .muscleGain)
        XCTAssertNil(try decode("{}").goal)
        XCTAssertNil(try decode("{}").targetsGoal)
    }

    func testAgreeingFieldsGiveTheSportGoalAndContradictingOnesTheOlderCalculation() throws {
        XCTAssertEqual(try decode(#"{"fitnessGoal":"bulk","nutritionAim":"gain"}"#).goal, .bulk)
        XCTAssertEqual(try decode(#"{"fitnessGoal":"cut","nutritionAim":"lose"}"#).goal, .cut)
        // The two disagree: the nutrition aim wins, as the calculation always read it.
        let year = DateMath.calendar.component(.year, from: Date())
        let contradicting = try decode(#"{"fitnessGoal":"bulk","nutritionAim":"lose","birthYear":\#(year - 30),"heightCm":180,"weightKg":80,"sex":"male","calculatedActivity":1.55}"#)
        XCTAssertEqual(contradicting.goal?.calculatorGoal, .lose)
        let model = makeModel()
        model.update(\.profile) { $0 = contradicting }
        XCTAssertEqual(model.nutritionGoal, .lose)
        XCTAssertEqual(model.recommendedNutritionGoals()?.kcal ?? 0, goals(.lose).kcal, accuracy: 0.5)
        XCTAssertEqual(model.recommendedNutritionGoals()?.protein ?? 0, goals(.lose).protein, accuracy: 0.5)
    }

    func testChoosingAgainWritesBothFieldsAndEndsTheContradiction() throws {
        var profile = try decode(#"{"fitnessGoal":"bulk","nutritionAim":"lose"}"#)
        profile.setGoal(.bulk)
        XCTAssertEqual(profile.goal, .bulk)
        XCTAssertEqual(profile.fitnessGoal, .bulk)
        XCTAssertEqual(profile.nutritionAim, .gain)
        profile.setGoal(nil)
        XCTAssertNil(profile.goal)
    }

    func testTheGoalIsKeptAfterSavingAndReading() throws {
        var profile = UserProfile()
        profile.setGoal(.recomposition)
        profile.targetsGoal = .recomposition
        let data = try JSONEncoder().encode(profile)
        let back = try JSONDecoder().decode(UserProfile.self, from: data)
        XCTAssertEqual(back.goal, .recomposition)
        XCTAssertEqual(back.targetsGoal, .recomposition)
    }

    // MARK: The goal changes

    func testCalculatedTargetsFollowTheNewGoal() {
        let model = makeModel(goal: .maintain)
        XCTAssertEqual(model.nutrition.goals.kcal, 2_759, accuracy: 0.5)
        model.setGoal(.bulk)
        XCTAssertEqual(model.nutrition.goals.kcal, 3_173, accuracy: 0.5)
        XCTAssertEqual(model.nutrition.goals.protein, 160, accuracy: 0.5)
        XCTAssertEqual(model.profile.targetsGoal, .bulk)
        XCTAssertNil(model.goalChangeProposal, "Nothing to propose: the targets already follow")
        // The older field follows the goal.
        XCTAssertEqual(model.profile.nutritionAim, .gain)
    }

    func testCustomTargetsAreNeverWrittenAndTheNewCalculationIsProposed() throws {
        let model = makeModel(goal: .maintain)
        model.setNutritionTarget(.kcal, 2_500)
        XCTAssertEqual(model.profile.customTargets, [.kcal])
        model.setGoal(.cut)
        XCTAssertEqual(model.nutrition.goals.kcal, 2_500, accuracy: 0.01, "The calories typed by hand stay")
        XCTAssertEqual(model.profile.customTargets, [.kcal])
        let proposal = try XCTUnwrap(model.goalChangeProposal)
        XCTAssertEqual(proposal.kcal, 2_207, accuracy: 0.5)
        XCTAssertEqual(proposal.protein, 176, accuracy: 0.5)
        // Nothing was applied by the proposal itself.
        XCTAssertEqual(model.nutrition.goals.kcal, 2_500, accuracy: 0.01)
        model.useGoalChangeProposal()
        XCTAssertEqual(model.nutrition.goals.kcal, 2_207, accuracy: 0.5)
        XCTAssertNil(model.goalChangeProposal)
        XCTAssertEqual(model.profile.targetsGoal, .cut)
    }

    func testManualTargetsAreNeverWrittenWhenTheGoalChanges() throws {
        let model = makeModel(goal: .maintain)
        model.setNutritionCalculation(false)
        let before = model.nutrition.goals
        model.setGoal(.cut)
        XCTAssertEqual(model.nutrition.goals, before, "Nothing written")
        XCTAssertEqual(model.profile.nutritionAuto, false)
        XCTAssertNotNil(model.goalChangeProposal)
        // « Garder mes valeurs »: still nothing written, and the proposal goes away.
        model.keepNutritionTargets()
        XCTAssertEqual(model.nutrition.goals, before)
        XCTAssertNil(model.goalChangeProposal)
        // Another change proposes again; « Utiliser ce calcul » writes the four values and keeps the manual mode.
        model.setGoal(.bulk)
        XCTAssertNotNil(model.goalChangeProposal)
        model.useGoalChangeProposal()
        XCTAssertEqual(model.nutrition.goals.kcal, 3_173, accuracy: 0.5)
        XCTAssertEqual(model.nutrition.goals.protein, 160, accuracy: 0.5)
        XCTAssertEqual(model.profile.nutritionAuto, false)
        XCTAssertNil(model.goalChangeProposal)
    }

    func testTheFirstChangeOfAnOlderAccountIsProposedToo() {
        // An older account: custom calories, a goal, but no goal noted for the targets yet.
        let model = makeModel(goal: .maintain)
        model.setNutritionTarget(.kcal, 2_500)
        model.profile.targetsGoal = nil
        model.setGoal(.cut)
        XCTAssertNotNil(model.goalChangeProposal, "The first change is proposed, not noted as if nothing changed")
        XCTAssertEqual(model.nutrition.goals.kcal, 2_500, accuracy: 0.01)
    }

    func testChoosingAGoalForTheFirstTimeProposesWhenTargetsAreCustom() {
        let model = makeModel(goal: nil)
        model.setNutritionTarget(.kcal, 2_500)
        model.setGoal(.cut)
        XCTAssertNotNil(model.goalChangeProposal, "Until then the calculation was maintaining")
        XCTAssertEqual(model.nutrition.goals.kcal, 2_500, accuracy: 0.01)
        // Without custom targets, the first goal is simply followed.
        let plain = makeModel(goal: nil)
        plain.setGoal(.cut)
        XCTAssertNil(plain.goalChangeProposal)
        XCTAssertEqual(plain.nutrition.goals.kcal, 2_207, accuracy: 0.5)
    }

    func testACutWithAnAcceptedPlanShowsTheSameProteinAsTheTargets() throws {
        let now = Date()
        let model = makeModel(goal: .cut)
        let end = DateMath.calendar.date(byAdding: .day, value: 150, to: now) ?? now
        model.setWeightPlan(targetKg: 72, targetDate: end, now: now)
        XCTAssertTrue(model.acceptWeightPlan(now: now))
        let outcome = try XCTUnwrap(model.evaluateWeightPlan(now: now))
        let plan: WeightPlanCalculator.Plan
        switch outcome {
        case .ok(let value), .adjusted(let value, _): plan = value
        default: return XCTFail("The plan should be calculable")
        }
        XCTAssertEqual(plan.goals.protein, model.nutrition.goals.protein, accuracy: 0.5)
        XCTAssertEqual(model.nutrition.goals.protein, 176, accuracy: 0.5, "2,2 g/kg for a cut")
    }

    func testAGoalThatChangesNothingProposesNothing() {
        let model = makeModel(goal: .endurance)
        model.setNutritionCalculation(false)
        model.setGoal(.performance)
        XCTAssertNil(model.goalChangeProposal, "Same calculation, same numbers")
    }

    // MARK: The pregnancy question

    func testThePregnancyQuestionIsAskedForALossChosenInSport() throws {
        var profile = UserProfile()
        profile.sex = .female
        // Chosen in Sport (the sport field only): asked.
        profile.fitnessGoal = .weightLoss
        XCTAssertTrue(profile.asksLifeStage)
        profile.fitnessGoal = .cut
        XCTAssertTrue(profile.asksLifeStage)
        profile.fitnessGoal = .bulk
        XCTAssertTrue(profile.asksLifeStage)
        // Chosen in Nutrition (the older field only): asked.
        profile.fitnessGoal = nil
        profile.nutritionAim = .lose
        XCTAssertTrue(profile.asksLifeStage)
        // Maintaining goals, and men: not asked.
        profile.setGoal(.maintain)
        XCTAssertFalse(profile.asksLifeStage)
        profile.setGoal(.recomposition)
        XCTAssertFalse(profile.asksLifeStage)
        profile.setGoal(.weightLoss)
        profile.sex = .male
        XCTAssertFalse(profile.asksLifeStage)
        // The weight goal is available for a loss chosen in Sport too.
        let model = makeModel(goal: .weightLoss)
        model.setWeightPlan(targetKg: 72)
        XCTAssertNotNil(model.activeWeightPlan)
    }

    // MARK: The activity

    func testTheActivityLabelsMatchTheWorkoutsCalculation() {
        let model = makeModel(goal: nil)
        model.update(\.profile) { $0.calculatedActivity = nil }
        let expected: [Int: NutritionCalculator.Activity] = [1: .sedentary, 2: .light, 3: .light, 4: .moderate, 5: .moderate, 6: .active, 7: .active]
        for (count, level) in expected {
            model.setWeeklyWorkouts(count)
            XCTAssertEqual(model.activityFromWorkouts, level, "\(count) workouts")
            XCTAssertEqual(NutritionCalculator.Activity.forWorkouts(perWeek: count), level)
        }
        XCTAssertEqual(NutritionCalculator.Activity.forWorkouts(perWeek: 0), .sedentary)
        // The old labels said « 1–3 », « 3–5 » and « 6–7 »: none of them is left.
        let titles = NutritionCalculator.Activity.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count)
        for title in titles {
            XCTAssertFalse(title.contains("1–3") || title.contains("3–5") || title.contains("6–7"), title)
        }
    }

    // MARK: The interests

    func testPlanningIsTheNameOfTheProductivityInterest() {
        XCTAssertEqual(Interest.productivity.rawValue, "productivity")
        XCTAssertEqual(ProfileTopic.productivity.rawValue, "productivity")
        XCTAssertEqual(Interest.productivity.title, tr("Planning"))
        XCTAssertEqual(ProfileTopic.productivity.title, tr("Planning"))
        XCTAssertEqual(Interest.studies.title, tr("Études"))
        XCTAssertNotNil(Interest.studies.hint)
        XCTAssertNotNil(Interest.productivity.hint)
        XCTAssertNil(Interest.sport.hint)
    }
}
