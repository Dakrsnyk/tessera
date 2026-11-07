import Foundation

/// The safety bounds of the targets that the app calculates by itself (« Mes besoins », followed when the body
/// or the aim changes). They are the ones of the weight goal (chantier 15, `WeightPlanCalculator`), read from
/// there and never copied: a minor, a pregnancy or a breastfeeding, a body mass index under 18,5 (no loss) or from
/// 30 (no gain), body data outside the accepted ranges, and the lowest calories ever proposed. Pure: nothing is read
/// from the model, so that the rule is tested alone.
enum NutritionSafety {
    /// Whether the age, the height and the weight are inside the ranges the calculation accepts; outside them
    /// the data are considered wrong and no target is calculated.
    static func isInRange(age: Int, heightCm: Double, weightKg: Double) -> Bool {
        WeightPlanCalculator.ageRange.contains(age)
            && WeightPlanCalculator.heightRange.contains(heightCm)
            && WeightPlanCalculator.weightRange.contains(weightKg)
    }

    /// The aim the automatic calculation may apply. A loss or a gain only for an adult in a safe situation
    /// (maintaining otherwise: no −15 % and no +10 %), the same refusals as `WeightPlanCalculator.evaluate`.
    /// `lifeStage` nil (never asked) is not a refusal here: the person chose the aim herself or himself, and the
    /// calories floor below still holds.
    static func allowedGoal(_ requested: NutritionCalculator.Goal, heightCm: Double, weightKg: Double, isMinor: Bool,
                            lifeStage: LifeStage?) -> NutritionCalculator.Goal {
        guard requested != .maintain else { return .maintain }
        if isMinor { return .maintain }
        switch lifeStage {
        case .minor?, .pregnant?, .breastfeeding?: return .maintain
        default: break
        }
        guard heightCm > 0, weightKg > 0 else { return .maintain }
        let bmi = WeightPlanCalculator.bmi(weightKg: weightKg, heightCm: heightCm)
        if requested == .lose && bmi < WeightPlanCalculator.lowBMI { return .maintain }
        if requested == .gain && bmi >= WeightPlanCalculator.highBMI { return .maintain }
        return requested
    }

    /// The lowest daily calories a loss may propose for this body: the floors of the weight goal (by calculation
    /// reference, 80 % of the resting energy, and the 1 400 of the calculator), rounded up.
    static func minimumKcal(sex: NutritionCalculator.Sex, age: Int, heightCm: Double, weightKg: Double) -> Double {
        let resting = NutritionCalculator.breakdown(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg,
                                                    activity: .sedentary, goal: .maintain).restingKcal
        return WeightPlanCalculator.minimumKcal(sex: sex, restingKcal: resting).rounded(.up)
    }

    /// Every daily target from the body, the activity and the aim, within the bounds. Nil when the body data are
    /// outside the accepted ranges. `goal` is the aim to apply (see `allowedGoal`). A loss never goes under the
    /// calories floor: the floor then leads the macronutrients, as calories typed by hand would. `typed`
    /// (calories the person typed or accepted for a weight goal, already checked) is never changed.
    static func goals(sex: NutritionCalculator.Sex, age: Int, heightCm: Double, weightKg: Double,
                      activity: NutritionCalculator.Activity, goal: NutritionCalculator.Goal,
                      kcal typed: Double? = nil) -> NutritionGoals? {
        guard isInRange(age: age, heightCm: heightCm, weightKg: weightKg) else { return nil }
        let plain = NutritionCalculator.goals(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg,
                                              activity: activity, goal: goal, kcal: typed)
        guard typed == nil, goal == .lose else { return plain }
        let floor = minimumKcal(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg)
        guard plain.kcal < floor else { return plain }
        return NutritionCalculator.goals(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg,
                                         activity: activity, goal: goal, kcal: floor)
    }
}
