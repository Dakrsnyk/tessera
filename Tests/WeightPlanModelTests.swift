import XCTest
@testable import Ardane

/// Objectif de poids (chantier 15), the model side: accepting a plan puts its calories in force without
/// touching what the user typed, an adjustment is only proposed (accepted, declined or ignored), and a
/// user without a plan keeps exactly the targets they had.
@MainActor
final class WeightPlanModelTests: XCTestCase {
    private let now = Date()

    private func makeModel(aim: NutritionAim? = .lose) -> AppModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let model = AppModel(store: SharedStore(directory: directory))
        model.setAge(35)
        model.setWeight(100)
        model.update(\.profile) {
            $0.heightCm = 180
            $0.sex = .male
            $0.nutritionAim = aim
            $0.calculatedActivity = .active
        }
        model.followCalculatedNutritionGoals()
        return model
    }

    private func date(afterDays days: Int) -> Date {
        DateMath.calendar.date(byAdding: .day, value: days, to: now) ?? now
    }

    /// The targets the calculation gave before any plan.
    private func standardGoals(_ model: AppModel) -> NutritionGoals {
        NutritionCalculator.goals(sex: .male, age: model.age ?? 35, heightCm: 180, weightKg: 100, activity: .active, goal: .lose)
    }

    /// 100 kg to 85 kg in 150 days: a safe goal.
    private func setSafePlan(_ model: AppModel) {
        model.setWeightPlan(targetKg: 85, targetDate: date(afterDays: 150), now: now)
    }

    // MARK: Accepting

    func testAcceptingAPlanAppliesCaloriesAndMacros() throws {
        let model = makeModel()
        setSafePlan(model)
        // Nothing changed yet: a plan is only set.
        XCTAssertEqual(model.nutrition.goals.kcal, standardGoals(model).kcal, accuracy: 0.5)
        XCTAssertNil(model.profile.weightPlan?.acceptedKcal)

        XCTAssertTrue(model.acceptWeightPlan(now: now))
        let accepted = try XCTUnwrap(model.profile.weightPlan?.acceptedKcal)
        XCTAssertLessThan(accepted, standardGoals(model).kcal + 1_000)
        XCTAssertEqual(model.nutrition.goals.kcal, accepted, accuracy: 0.5)
        XCTAssertGreaterThan(model.nutrition.goals.protein, 0)
        XCTAssertNotEqual(model.nutrition.goals.kcal, standardGoals(model).kcal)
        XCTAssertEqual(model.profile.weightPlan?.startDate, now)
        XCTAssertNotNil(model.profile.weightPlan?.startKg)
    }

    func testAcceptingKeepsCustomTargetsAndTheCalculationMode() {
        let model = makeModel()
        model.setNutritionTarget(.protein, 140)
        let customBefore = model.profile.customTargets
        setSafePlan(model)
        XCTAssertTrue(model.acceptWeightPlan(now: now))
        XCTAssertEqual(model.profile.customTargets, customBefore)
        XCTAssertEqual(model.profile.customTargets, [.protein])
        XCTAssertEqual(model.profile.nutritionAuto, true)
        XCTAssertEqual(model.nutrition.goals.protein, 140, accuracy: 0.01)
    }

    func testAcceptingKeepsManualModeManual() throws {
        let model = makeModel()
        model.setNutritionCalculation(false)
        setSafePlan(model)
        XCTAssertTrue(model.acceptWeightPlan(now: now))
        let accepted = try XCTUnwrap(model.profile.weightPlan?.acceptedKcal)
        XCTAssertEqual(model.profile.nutritionAuto, false)
        XCTAssertEqual(model.nutrition.goals.kcal, accepted, accuracy: 0.5)
    }

    func testUserWithoutAPlanKeepsTheirTargets() {
        let model = makeModel()
        XCTAssertNil(model.profile.weightPlan)
        XCTAssertNil(model.activeWeightPlan)
        XCTAssertNil(model.evaluateWeightPlan(now: now))
        XCTAssertNil(model.proposedAdjustment(now: now))
        XCTAssertFalse(model.acceptWeightPlan(now: now))
        let expected = standardGoals(model)
        XCTAssertEqual(model.recommendedNutritionGoals(), expected)
        XCTAssertEqual(model.nutrition.goals.kcal, expected.kcal, accuracy: 0.5)
    }

    func testUnsafeGoalAppliesNothing() {
        let model = makeModel()
        // 30 kg in 4 weeks is far past a prudent pace.
        model.setWeightPlan(targetKg: 70, targetDate: date(afterDays: 28), now: now)
        let before = model.nutrition.goals
        guard case .unsafe(_, let weeks, _, _)? = model.evaluateWeightPlan(now: now) else {
            return XCTFail("Expected .unsafe")
        }
        XCTAssertGreaterThan(weeks, 4)
        XCTAssertFalse(model.acceptWeightPlan(now: now))
        XCTAssertEqual(model.nutrition.goals, before)
        XCTAssertNil(model.profile.weightPlan?.acceptedKcal)
    }

    func testMaintainingAimSetsThePlanAside() {
        let model = makeModel(aim: .maintain)
        setSafePlan(model)
        XCTAssertNil(model.activeWeightPlan)
        XCTAssertFalse(model.acceptWeightPlan(now: now))
        XCTAssertEqual(model.recommendedNutritionGoals()?.kcal ?? 0, NutritionCalculator.goals(sex: .male, age: model.age ?? 35, heightCm: 180, weightKg: 100, activity: .active, goal: .maintain).kcal, accuracy: 0.5)
    }

    func testChangingTheTargetKeepsAcceptedCaloriesUntilAccepted() throws {
        let model = makeModel()
        setSafePlan(model)
        XCTAssertTrue(model.acceptWeightPlan(now: now))
        let accepted = try XCTUnwrap(model.profile.weightPlan?.acceptedKcal)
        model.setWeightPlan(targetKg: 80, targetDate: date(afterDays: 300), now: now)
        XCTAssertEqual(model.profile.weightPlan?.acceptedKcal, accepted)
        XCTAssertEqual(model.nutrition.goals.kcal, accepted, accuracy: 0.5)
    }

    func testSettingAPlanWritesAnAdultSituationSoAManCanLose() {
        let model = makeModel()
        XCTAssertNil(model.profile.lifeStage)
        setSafePlan(model)
        XCTAssertEqual(model.profile.lifeStage, .adult)
        if case .referToProfessional? = model.evaluateWeightPlan(now: now) { XCTFail("A man must be able to lose weight") }
    }

    func testAnswerGivenIsKeptAWomanWithoutAnswerGetsNoPlanAndAMinorIsLeftAlone() {
        let answered = makeModel()
        answered.update(\.profile) { $0.lifeStage = .preferNotToSay }
        setSafePlan(answered)
        XCTAssertEqual(answered.profile.lifeStage, .preferNotToSay)

        // The question is asked of her: nothing is written for her, and no loss is calculated.
        let woman = makeModel()
        woman.update(\.profile) { $0.sex = .female }
        setSafePlan(woman)
        XCTAssertNil(woman.profile.lifeStage)
        if case .referToProfessional? = woman.evaluateWeightPlan(now: now) {} else { XCTFail("No plan without an answer") }
        XCTAssertFalse(woman.acceptWeightPlan(now: now))

        let minor = makeModel()
        minor.setAge(16)
        setSafePlan(minor)
        XCTAssertNil(minor.profile.lifeStage)
        if case .referToProfessional? = minor.evaluateWeightPlan(now: now) {} else { XCTFail("A minor does not lose weight") }
    }

    func testAcceptedCaloriesDoNotSurviveAPlanThatBecomesUncalculable() {
        let model = makeModel()
        setSafePlan(model)
        XCTAssertTrue(model.acceptWeightPlan(now: now))
        XCTAssertNotEqual(model.nutrition.goals.kcal, standardGoals(model).kcal)
        // A pregnancy answer: the calculation goes back to the one of before, and nothing can be applied.
        model.update(\.profile) { $0.lifeStage = .pregnant }
        XCTAssertNil(model.inForceWeightPlanKcal)
        XCTAssertEqual(model.nutrition.goals.kcal, standardGoals(model).kcal, accuracy: 0.5)
        XCTAssertFalse(model.acceptWeightPlan(now: now))
    }

    func testAcceptedCaloriesDoNotSurviveAChangeOfAim() {
        let model = makeModel()
        setSafePlan(model)
        XCTAssertTrue(model.acceptWeightPlan(now: now))
        model.update(\.profile) { $0.nutritionAim = .gain }
        XCTAssertNil(model.inForceWeightPlanKcal)
    }

    // MARK: Adjustment

    /// A plan accepted a month ago, with weigh-ins that did not move: slower than planned.
    private func stalledModel() -> AppModel {
        let model = makeModel()
        setSafePlan(model)
        XCTAssertTrue(model.acceptWeightPlan(now: now))
        // Weigh-ins from 18 days ago to 15 days ahead, so the pause tests find recent ones at both dates.
        var log: [ValuePoint] = []
        for offset in stride(from: -18, through: 15, by: 3) {
            log.append(ValuePoint(date: date(afterDays: offset), value: 100))
        }
        model.update(\.profile) {
            $0.weightLog = log
            $0.weightPlan?.startDate = date(afterDays: -30)
            $0.weightPlan?.startKg = 100
        }
        return model
    }

    func testAdjustmentIsProposedThenAccepted() throws {
        let model = stalledModel()
        let before = model.nutrition.goals.kcal
        let proposal = try XCTUnwrap(model.proposedAdjustment(now: now))
        // Proposing changes nothing.
        XCTAssertEqual(model.nutrition.goals.kcal, before, accuracy: 0.5)
        XCTAssertLessThan(proposal.newKcal, proposal.previousKcal)
        model.acceptAdjustment(proposal, now: now)
        XCTAssertEqual(model.profile.weightPlan?.acceptedKcal, proposal.newKcal)
        XCTAssertEqual(model.nutrition.goals.kcal, proposal.newKcal, accuracy: 0.5)
        // The tracking starts again: no second proposal at once.
        XCTAssertNil(model.proposedAdjustment(now: now))
    }

    func testDeclinedAdjustmentChangesNothingAndPausesProposals() throws {
        let model = stalledModel()
        let kcal = model.nutrition.goals.kcal
        let accepted = model.profile.weightPlan?.acceptedKcal
        XCTAssertNotNil(model.proposedAdjustment(now: now))
        model.dismissAdjustment(now: now)
        XCTAssertEqual(model.profile.weightPlan?.dismissedProposalDate, now)
        XCTAssertNil(model.proposedAdjustment(now: now))
        XCTAssertNil(model.proposedAdjustment(now: date(afterDays: 5)))
        XCTAssertEqual(model.nutrition.goals.kcal, kcal, accuracy: 0.5)
        XCTAssertEqual(model.profile.weightPlan?.acceptedKcal, accepted)
        // After the pause, the proposal comes back.
        XCTAssertNotNil(model.proposedAdjustment(now: date(afterDays: WeightPlanCalculator.proposalPauseDays + 1)))
    }

    func testIgnoredAdjustmentChangesNothing() {
        let model = stalledModel()
        let kcal = model.nutrition.goals.kcal
        let plan = model.profile.weightPlan
        _ = model.proposedAdjustment(now: now)
        _ = model.proposedAdjustment(now: now)
        XCTAssertEqual(model.nutrition.goals.kcal, kcal, accuracy: 0.5)
        XCTAssertEqual(model.profile.weightPlan, plan)
    }

    func testNoAdjustmentBeforeThePlanIsAccepted() {
        let model = makeModel()
        setSafePlan(model)
        XCTAssertNil(model.proposedAdjustment(now: now))
    }

    // MARK: Removing

    func testRemovingThePlanGivesTheCalculationBack() {
        let model = makeModel()
        setSafePlan(model)
        XCTAssertTrue(model.acceptWeightPlan(now: now))
        XCTAssertNotEqual(model.nutrition.goals.kcal, standardGoals(model).kcal)
        model.removeWeightPlan()
        XCTAssertNil(model.profile.weightPlan)
        XCTAssertEqual(model.nutrition.goals.kcal, standardGoals(model).kcal, accuracy: 0.5)
        XCTAssertNil(model.proposedAdjustment(now: now))
    }

    func testPlanSurvivesSavingAndReading() throws {
        let model = makeModel()
        setSafePlan(model)
        XCTAssertTrue(model.acceptWeightPlan(now: now))
        let data = try JSONEncoder().encode(model.profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        XCTAssertEqual(decoded.weightPlan?.acceptedKcal, model.profile.weightPlan?.acceptedKcal)
        XCTAssertEqual(decoded.weightPlan?.targetKg, 85)
    }
}
