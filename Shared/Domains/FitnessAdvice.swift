import Foundation

/// What the Fitness questions propose from what the person already said (age, weight, height, goal, level), so
/// the page is not the same for everyone (PDG, 2026-11-22): the goals that fit the body first, none that is
/// unsafe for a minor, and a number of sessions a week that fits the level, the goal and the age. Only advice:
/// every answer stays the person's choice.
enum FitnessAdvice {
    /// The body mass index, nil without both the weight and the height.
    static func bmi(weightKg: Double?, heightCm: Double?) -> Double? {
        guard let weightKg, let heightCm, weightKg > 0, heightCm > 0 else { return nil }
        let metres = heightCm / 100
        return weightKg / (metres * metres)
    }

    /// The goals offered, in the order shown: under 18, no cut and no bulk; the ones that fit the body come first
    /// (a loss or a recomposition above a BMI of 25, a gain under 18.5), the others keep their usual order.
    static func goals(bmi: Double?, isMinor: Bool) -> [FitnessGoal] {
        var goals = FitnessGoal.displayOrder
        if isMinor { goals.removeAll { $0 == .cut || $0 == .bulk } }
        let first = suggestedFirst(bmi: bmi)
        return first.filter(goals.contains) + goals.filter { !first.contains($0) }
    }

    /// The goals put first for this body, empty when nothing stands out (or the body is not known).
    static func suggestedFirst(bmi: Double?) -> [FitnessGoal] {
        guard let bmi else { return [] }
        if bmi >= 25 { return [.weightLoss, .recomposition] }
        if bmi < 18.5 { return [.muscleGain, .bulk] }
        return []
    }

    /// The sessions a week that fit: from the level (2 to 3 for a beginner, 3 to 4, 4 to 5 when advanced), one
    /// more for endurance or performance, at most 3 from 60 years old and at most 4 under 18. Nil without a level.
    static func sessions(level: FitnessLevel?, goal: FitnessGoal?, age: Int?, isMinor: Bool) -> ClosedRange<Int>? {
        guard let level else { return nil }
        var low: Int
        var high: Int
        switch level {
        case .beginner: (low, high) = (2, 3)
        case .intermediate: (low, high) = (3, 4)
        case .advanced: (low, high) = (4, 5)
        }
        if goal == .endurance || goal == .performance { high += 1 }
        if let age, age >= 60 { high = min(high, 3) }
        if isMinor { high = min(high, 4) }
        low = min(low, high)
        return low...high
    }
}
