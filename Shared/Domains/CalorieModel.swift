import Foundation

/// Estimates the ACTIVE calories of a workout and of the steps of a day.
///
/// Active calories are the energy spent above the resting metabolism (1 MET), so that the resting
/// part of the day is never counted here.
///
/// Health: Ardane neither reads nor writes Apple Health (no HealthKit). Every number here is an
/// independent ESTIMATION, never a measure, and nothing is sent to Health, so nothing can be counted
/// twice on writing. Inside Ardane, the calories of the steps and those of the workouts must never be
/// added without the correction of `stepsCalories(steps:weightKg:minutesInSessions:)`: the minutes
/// of a workout are already counted by the workout.
///
/// Weight: every function takes an optional weight and returns nil without a known weight (> 0): no
/// number is made up. Callers that hold a documented default (`FitnessState.bodyWeightKg`, 70 kg,
/// replaced by the profile weight when it is known) pass it explicitly and label the result as an estimate.
enum CalorieModel {
    // MARK: Constants

    /// MET values from the Compendium of Physical Activities (Ainsworth et al.). 1 MET = resting
    /// energy expenditure, about 1 kcal per kg per hour.
    /// Resistance training with a load, moderate to high effort (≈ 5.0).
    static let loadedSetMET = 5.0
    /// Bodyweight exercises, moderate effort (≈ 3.8).
    static let bodyweightSetMET = 3.8
    /// Resting between sets: standing, changing the weights, walking to the next machine (≈ 2.0, above sitting still).
    static let restMET = 2.0

    /// Seconds of work for one repetition (about 3.5 s: up, down and the pause between).
    static let secondsPerRep = 3.5
    /// Seconds to take position, unrack and breathe, counted as work.
    static let setupSeconds = 15.0
    /// A set lasts at least 25 s and at most 90 s of work.
    static let minWorkSeconds = 25.0
    static let maxWorkSeconds = 90.0
    /// The time between two sets (or the start and the first set) is capped at 10 minutes: a session
    /// left open, or a long pause, does not count hours of inactivity.
    static let maxGapSeconds = 600.0

    /// About 0.04 kcal per step for 70 kg, scaled by weight.
    static let stepKcalPerKg = 0.04 / 70
    /// Hypothesis: during a workout the person moves at most about 30 steps a minute (walking between
    /// sets and machines). These steps are taken out of the day's steps, because the workout's
    /// minutes are already counted by `activeCalories(of:weightKg:)`.
    static let stepsPerMinuteInSession = 30.0

    // MARK: Weight

    /// The weight when it is usable (finite and above 0), else nil.
    static func validWeight(_ weightKg: Double?) -> Double? {
        guard let weight = weightKg, weight.isFinite, weight > 0 else { return nil }
        return weight
    }

    // MARK: Workout

    /// Seconds of work of a set: about 3.5 s per repetition plus the set up, from 25 s to 90 s.
    static func workSeconds(of set: SetLog) -> Double {
        let raw = Double(max(0, set.reps)) * secondsPerRep + setupSeconds
        return min(maxWorkSeconds, max(minWorkSeconds, raw))
    }

    /// The intensity of a set: with a load 5.0, at bodyweight 3.8.
    static func met(of set: SetLog) -> Double {
        set.weight > 0 ? loadedSetMET : bodyweightSetMET
    }

    /// How a session splits into work and rest, and the energy above rest it costs.
    struct Effort: Equatable {
        var workSeconds = 0.0
        var restSeconds = 0.0
        /// Σ (MET − 1) × hours: multiplied by the weight in kg it gives the active kcal.
        var netMETHours = 0.0
        var minutes: Double { (workSeconds + restSeconds) / 60 }
    }

    /// Work time (the sets done) apart from rest time (the rest of the duration), capped.
    /// A passed set (`skipped`) adds no work; a session without a set done has no effort.
    static func effort(of session: WorkoutSession) -> Effort {
        let sets = session.sets.sorted { $0.date < $1.date }
        var effort = Effort()
        var previous = session.start
        for set in sets {
            let gap = min(maxGapSeconds, max(0, set.date.timeIntervalSince(previous)))
            let work = workSeconds(of: set)
            let rest = max(0, gap - work)
            effort.workSeconds += work
            effort.restSeconds += rest
            effort.netMETHours += (met(of: set) - 1) * work / 3_600 + (restMET - 1) * rest / 3_600
            if set.date > previous { previous = set.date }
        }
        return effort
    }

    /// Active kcal of a session: (MET work − 1) × kg × hours of work + (MET rest − 1) × kg × hours of
    /// rest. 0 without a set done; nil without a known weight.
    static func activeCalories(of session: WorkoutSession, weightKg: Double?) -> Double? {
        guard let weight = validWeight(weightKg) else { return nil }
        return max(0, effort(of: session).netMETHours * weight)
    }

    /// Active kcal of the sessions given (a day's, for instance): their sum. Nil without a known weight.
    static func dayCalories(sessions: [WorkoutSession], weightKg: Double?) -> Double? {
        guard let weight = validWeight(weightKg) else { return nil }
        return sessions.reduce(0.0) { $0 + (activeCalories(of: $1, weightKg: weight) ?? 0) }
    }

    /// Minutes counted for the sessions that started on a day (work and capped rest).
    static func minutes(of sessions: [WorkoutSession], on day: Date) -> Double {
        sessions.filter { DateMath.isSameDay($0.start, day) }.reduce(0.0) { $0 + effort(of: $1).minutes }
    }

    // MARK: Steps

    /// Active kcal of the steps of a day, without the steps of the workout minutes (counted by the
    /// workout, so that a minute is never counted twice). Nil without a known weight.
    static func stepsCalories(steps: Int, weightKg: Double?, minutesInSessions: Double = 0) -> Double? {
        guard let weight = validWeight(weightKg) else { return nil }
        let inSessions = Int((max(0, minutesInSessions) * stepsPerMinuteInSession).rounded())
        let counted = max(0, steps - inSessions)
        return Double(counted) * stepKcalPerKg * weight
    }
}
