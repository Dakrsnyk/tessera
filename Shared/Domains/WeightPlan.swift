import Foundation

// Objectif de poids (chantier 15): the logic only, no screen. The calories come from the energy the body
// spends (Mifflin-St Jeor × activity, `NutritionCalculator`) and from the weight to change over the time
// given, never from a fixed percentage. Every limit below is an estimate from public guidance, to be
// validated by a health professional before release (see docs/nutrition-objectif-poids.md). Ardane never
// applies a change by itself: the results are proposals the user accepts.

/// The goal the user set: a weight to reach by a date. Kept in `UserProfile.weightPlan`.
struct WeightPlan: Codable, Hashable {
    var targetKg: Double
    /// The (smoothed) weight the plan started from, and the day it started.
    var startKg: Double
    var startDate: Date
    var targetDate: Date
    /// The daily calories the user accepted for this plan (nil: none accepted yet).
    var acceptedKcal: Double?
    /// The day the user declined an adjustment: none is proposed again for two weeks.
    var dismissedProposalDate: Date?

    init(targetKg: Double, startKg: Double, startDate: Date, targetDate: Date,
         acceptedKcal: Double? = nil, dismissedProposalDate: Date? = nil) {
        self.targetKg = targetKg
        self.startKg = startKg
        self.startDate = startDate
        self.targetDate = targetDate
        self.acceptedKcal = acceptedKcal
        self.dismissedProposalDate = dismissedProposalDate
    }

    enum CodingKeys: String, CodingKey {
        case targetKg, startKg, startDate, targetDate, acceptedKcal, dismissedProposalDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        targetKg = c.value(.targetKg, 0.0)
        startKg = c.value(.startKg, 0.0)
        startDate = c.value(.startDate, Date())
        targetDate = c.value(.targetDate, Date())
        acceptedKcal = c.optional(.acceptedKcal)
        dismissedProposalDate = c.optional(.dismissedProposalDate)
    }

    /// What the plan is for, from the weights (a change under half a kilogram is maintenance).
    var aim: NutritionAim {
        if targetKg < startKg - WeightPlanCalculator.minimumChangeKg { return .lose }
        if targetKg > startKg + WeightPlanCalculator.minimumChangeKg { return .gain }
        return .maintain
    }
}

/// The situation that decides how careful the calculation must be. An unknown value read from a newer
/// version is dropped (nil) rather than failing the profile.
enum LifeStage: String, Codable, CaseIterable, Identifiable {
    case adult, minor, pregnant, breastfeeding, preferNotToSay
    var id: String { rawValue }

    var title: String {
        switch self {
        case .adult: tr("Adulte")
        case .minor: tr("Moins de 18 ans")
        case .pregnant: tr("Enceinte")
        case .breastfeeding: tr("Allaitante")
        case .preferNotToSay: tr("Je préfère ne pas répondre")
        }
    }
}

enum WeightPlanCalculator {
    // MARK: Limits (estimates from public guidance, to be validated by a health professional)

    /// Energy stored in a kilogram of body weight, the usual approximation (Wishnofsky, 1958). It
    /// overestimates the cost of gaining muscle; the gain limits below stay prudent for that reason.
    static let kcalPerKg = 7_700.0
    /// Loss: at most 1 % of the body weight a week (the 0,5 to 1 kg a week of the NIH and the Canadian
    /// obesity guidelines, expressed as a share of the weight); advised pace 0,5 to 0,75 %.
    static let maxLossPercentPerWeek = 1.0
    static let advisedLossMinPercent = 0.5
    static let advisedLossMaxPercent = 0.75
    /// Gain: at most about 0,5 % a week (advised 0,25 to 0,5 %, the lean gain pace of sports nutrition
    /// guidance) and a surplus of 500 kcal a day at most.
    static let maxGainPercentPerWeek = 0.5
    static let advisedGainMinPercent = 0.25
    static let advisedGainMaxPercent = 0.5
    static let maxSurplusKcal = 500.0
    /// A deficit stays under 25 % of the energy spent, except at the advised pace (0,75 %/week or less,
    /// where the calorie floor is the guard): 0,75 % of 100 kg is a 770 kcal deficit.
    static let maxDeficitFraction = 0.25
    /// Calorie floors a day, by calculation reference (the usual minimums of unsupervised diets). For the
    /// average of both references, the higher one.
    static let femaleFloorKcal = 1_200.0
    static let maleFloorKcal = 1_500.0
    /// The floor already applied by `NutritionCalculator.goals` (never lower).
    static let existingFloorKcal = 1_400.0
    /// And never under 80 % of the resting energy.
    static let restingFloorFraction = 0.8
    /// The ceiling: the energy spent + 500 kcal.
    static let ceilingMarginKcal = 500.0
    /// Under this margin between the energy spent and the floor, a loss is not worth proposing.
    static let minimumUsefulDeficitKcal = 100.0
    /// A change under this is maintenance; a target within it of the weight is not a goal.
    static let minimumChangeKg = 0.5
    /// A suggested duration longer than this is not suggested (two years).
    static let maxSuggestedWeeks = 104
    /// Under this body mass index (WHO), no loss is calculated.
    static let lowBMI = 18.5
    /// From this body mass index (WHO obesity threshold), no weight gain is proposed.
    static let highBMI = 30.0
    /// Accepted ranges; outside, the data are considered wrong.
    static let ageRange = 10...100
    static let heightRange = 120.0...230.0
    static let weightRange = 30.0...300.0

    // MARK: Tracking constants

    /// Days of the moving average.
    static let smoothingDays = 7
    /// Days of weigh-ins read to estimate the real pace, the span they must cover, and how many are needed.
    static let lookbackDays = 28
    static let minimumSpanDays = 14
    static let minimumWeighIns = 6
    /// An adjustment is proposed only when the real pace differs from the planned one by this share.
    static let deviationThreshold = 0.25
    /// For maintenance: a drift of this % of the weight a week.
    static let maintainDriftPercent = 0.25
    /// No new proposal for this many days after one was declined.
    static let proposalPauseDays = 14
    /// A proposal closer than this to the current calories is not worth making.
    static let minimumProposalChangeKcal = 50.0

    // MARK: Types

    /// Everything the calculation needs. Missing values give `.referToProfessional`.
    struct Input: Hashable {
        var sex: NutritionCalculator.Sex?
        var age: Int?
        /// True when the age comes from the birth year only (it can be one year too high): the test of
        /// minority then reads the age minus one.
        var ageIsApproximate = false
        var heightCm: Double?
        var weightKg: Double?
        var activity: NutritionCalculator.Activity = .sedentary
        var lifeStage: LifeStage = .adult
        var aim: NutritionAim = .maintain
        var targetKg: Double?
        /// Days from `now` to the target date.
        var days: Int = 0
        var now: Date = Date()
    }

    /// A computed plan: all the numbers the recap shows.
    struct Plan: Hashable {
        var aim: NutritionAim
        var startKg: Double
        var targetKg: Double
        var days: Int
        /// Signed: negative to lose.
        var weeklyChangeKg: Double
        /// Signed share of the body weight, in percent.
        var weeklyPercent: Double
        var restingKcal: Double
        /// The energy spent in a day (resting × activity).
        var expenditureKcal: Double
        /// Signed: target calories − energy spent.
        var dailyDeltaKcal: Double
        var targetKcal: Double
        /// The estimated day the target weight is reached.
        var reachDate: Date
        /// The floor and ceiling that applied.
        var floorKcal: Double
        var ceilingKcal: Double
        /// Calories and macronutrients (the same system as the rest of Nutrition).
        var goals: NutritionGoals
    }

    enum Outcome: Hashable {
        /// Safe and within the advised pace.
        case ok(Plan)
        /// Valid, with a remark (a brisk pace, or maintenance only for a minor).
        case adjusted(Plan, reason: String)
        /// Impossible to reach safely: a longer duration (and the plan for it) is suggested instead.
        case unsafe(reason: String, suggestedWeeks: Int, suggestedDate: Date, suggestedPlan: Plan)
        /// No reliable or prudent calculation: no number is given.
        case referToProfessional(reason: String)
    }

    // MARK: Safety bounds

    /// The lowest daily calories ever proposed.
    static func minimumKcal(sex: NutritionCalculator.Sex, restingKcal: Double) -> Double {
        let byReference: Double
        switch sex {
        case .female: byReference = femaleFloorKcal
        case .male, .neutral: byReference = maleFloorKcal
        }
        return max(byReference, restingKcal * restingFloorFraction, existingFloorKcal)
    }

    /// The highest daily calories ever proposed.
    static func maximumKcal(expenditureKcal: Double) -> Double {
        expenditureKcal + ceilingMarginKcal
    }

    static func bmi(weightKg: Double, heightCm: Double) -> Double {
        weightKg / pow(heightCm / 100, 2)
    }

    // MARK: Calculation

    /// The input from the profile. `weightKg`: the weight to start from (default: the 7-day average, else
    /// the current weight). The activity defaults to sedentary, the prudent reading, when never chosen.
    static func input(profile: UserProfile, birthday: Date? = nil, aim: NutritionAim, targetKg: Double?, days: Int,
                      weightKg: Double? = nil, now: Date = Date()) -> Input {
        Input(sex: profile.calculatorSex,
              age: profile.age(birthday: birthday, now: now),
              ageIsApproximate: birthday == nil,
              heightCm: profile.heightCm,
              weightKg: weightKg ?? smoothedWeight(profile.weightLog, now: now) ?? profile.weightKg,
              activity: profile.calculatedActivity ?? .sedentary,
              // Never asked (nil) = not declared: no loss or gain is calculated, as for « préfère ne pas répondre ».
              lifeStage: profile.lifeStage ?? .preferNotToSay,
              aim: aim, targetKg: targetKg, days: days, now: now)
    }

    /// Days between `now` and a target date (can be zero or negative).
    static func days(until date: Date, from now: Date = Date()) -> Int {
        DateMath.daysBetween(now, date)
    }

    static func evaluate(_ input: Input) -> Outcome {
        let stage = input.lifeStage
        if stage == .pregnant || stage == .breastfeeding { return .referToProfessional(reason: pregnancyReason) }
        guard let age = input.age, ageRange.contains(age),
              let sex = input.sex,
              let height = input.heightCm, heightRange.contains(height),
              let weight = input.weightKg, weightRange.contains(weight) else {
            return .referToProfessional(reason: missingDataReason)
        }
        let steps = NutritionCalculator.breakdown(sex: sex, age: age, heightCm: height, weightKg: weight,
                                                  activity: input.activity, goal: input.aim.calculatorGoal)
        let resting = steps.restingKcal
        let expenditure = steps.dailyKcal
        let floor = minimumKcal(sex: sex, restingKcal: resting)
        let ceiling = maximumKcal(expenditureKcal: expenditure)
        guard resting > 0, expenditure > 0, floor <= ceiling else {
            return .referToProfessional(reason: missingDataReason)
        }
        let context = Context(input: input, sex: sex, age: age, heightCm: height, weightKg: weight,
                              restingKcal: resting, expenditureKcal: expenditure, floorKcal: floor, ceilingKcal: ceiling)

        // Maintenance below the floor would mean eating more than the body spends: not proposed.
        if input.aim == .maintain && expenditure < floor { return .referToProfessional(reason: belowFloorReason) }

        // A minor: no loss and no gain, only the maintenance (as an indication). An age from the birth
        // year alone can be one too high, so one year is taken off for this test.
        let ageForMinority = input.ageIsApproximate ? age - 1 : age
        if ageForMinority < 18 || stage == .minor {
            guard input.aim == .maintain else { return .referToProfessional(reason: minorReason) }
            return .adjusted(context.maintenancePlan(), reason: minorMaintenanceReason)
        }
        if input.aim != .maintain && stage == .preferNotToSay { return .referToProfessional(reason: unspecifiedStageReason) }
        let currentBMI = bmi(weightKg: weight, heightCm: height)
        if input.aim == .lose && currentBMI < lowBMI { return .referToProfessional(reason: lowBMIReason) }
        // No weight gain is proposed from a body mass index of 30 (obesity, WHO).
        if input.aim == .gain && currentBMI >= highBMI { return .referToProfessional(reason: highBMIReason) }
        if input.aim == .maintain { return .ok(context.maintenancePlan()) }

        // Loss or gain.
        guard let target = input.targetKg, weightRange.contains(target), input.days >= 1 else {
            return .referToProfessional(reason: inconsistentGoalReason)
        }
        let change = target - weight
        if input.aim == .lose, change > -minimumChangeKg { return .referToProfessional(reason: inconsistentGoalReason) }
        if input.aim == .gain, change < minimumChangeKg { return .referToProfessional(reason: inconsistentGoalReason) }
        if bmi(weightKg: target, heightCm: height) < lowBMI { return .referToProfessional(reason: lowTargetBMIReason) }

        let amount = abs(change)
        let weeklyKg = amount / Double(input.days) * 7
        let percent = weeklyKg / weight * 100
        let dailyKcal = amount * kcalPerKg / Double(input.days)
        let eps = 1e-9

        if input.aim == .lose {
            let room = expenditure - floor
            guard room >= minimumUsefulDeficitKcal else { return .referToProfessional(reason: noMarginReason) }
            let allowed = percent <= advisedLossMaxPercent + eps ? room : min(room, expenditure * maxDeficitFraction)
            if percent <= maxLossPercentPerWeek + eps && dailyKcal <= allowed + eps {
                let plan = context.plan(target: target, days: input.days)
                return percent <= advisedLossMaxPercent + eps ? .ok(plan) : .adjusted(plan, reason: briskLossReason)
            }
            // Too fast: the fewest weeks that keep the advised pace and the calorie room.
            let safeKgPerWeek = min(advisedLossMaxPercent / 100 * weight, room * 7 / kcalPerKg)
            return unsafeOutcome(context: context, target: target, amount: amount, safeKgPerWeek: safeKgPerWeek,
                                 reason: unsafeLossReason)
        }

        // Gain.
        let room = min(maxSurplusKcal, ceiling - expenditure)
        if percent <= maxGainPercentPerWeek + eps && dailyKcal <= room + eps {
            return .ok(context.plan(target: target, days: input.days))
        }
        let safeKgPerWeek = min(advisedGainMaxPercent / 100 * weight, room * 7 / kcalPerKg)
        return unsafeOutcome(context: context, target: target, amount: amount, safeKgPerWeek: safeKgPerWeek,
                             reason: unsafeGainReason)
    }

    /// The alternative duration for a goal that is too fast: no calorie figure is computed for the
    /// requested pace, only for the safe one.
    private static func unsafeOutcome(context: Context, target: Double, amount: Double, safeKgPerWeek: Double, reason: String) -> Outcome {
        guard safeKgPerWeek > 0 else { return .referToProfessional(reason: noMarginReason) }
        // The 1e-9 keeps an exact result (12 kg at 0,6 kg a week) from rounding up to one week more.
        let weeks = Int((amount / safeKgPerWeek - 1e-9).rounded(.up))
        guard weeks >= 1, weeks <= maxSuggestedWeeks else { return .referToProfessional(reason: tooLongReason) }
        let plan = context.plan(target: target, days: weeks * 7)
        return .unsafe(reason: reason, suggestedWeeks: weeks, suggestedDate: plan.reachDate, suggestedPlan: plan)
    }

    /// The numbers shared by the plans of one evaluation.
    private struct Context {
        let input: Input
        let sex: NutritionCalculator.Sex
        let age: Int
        let heightCm: Double
        let weightKg: Double
        let restingKcal: Double
        let expenditureKcal: Double
        let floorKcal: Double
        let ceilingKcal: Double

        /// The plan reaching `target` in `days`. The calories are rounded toward the safe side and kept
        /// between the floor and the ceiling (a last guard: the callers have already checked the pace).
        func plan(target: Double, days: Int) -> Plan {
            let aim = input.aim
            let amount = abs(target - weightKg)
            let daily = amount * WeightPlanCalculator.kcalPerKg / Double(max(days, 1))
            let sign: Double = aim == .lose ? -1 : 1
            var kcal = expenditureKcal + sign * daily
            kcal = aim == .lose ? kcal.rounded(.up) : kcal.rounded(.down)
            kcal = min(max(kcal, floorKcal.rounded(.up)), ceilingKcal.rounded(.down))
            let weekly = sign * amount / Double(max(days, 1)) * 7
            return Plan(aim: aim, startKg: weightKg, targetKg: target, days: days,
                        weeklyChangeKg: weekly, weeklyPercent: weekly / weightKg * 100,
                        restingKcal: restingKcal, expenditureKcal: expenditureKcal, dailyDeltaKcal: kcal - expenditureKcal,
                        targetKcal: kcal, reachDate: Self.date(afterDays: days, from: input.now),
                        floorKcal: floorKcal, ceilingKcal: ceilingKcal, goals: goals(kcal: kcal))
        }

        /// Maintenance: the energy spent, within the floor and the ceiling.
        func maintenancePlan() -> Plan {
            let kcal = min(max(expenditureKcal, floorKcal.rounded(.up)), ceilingKcal.rounded(.down))
            return Plan(aim: .maintain, startKg: weightKg, targetKg: weightKg, days: max(input.days, 0),
                        weeklyChangeKg: 0, weeklyPercent: 0, restingKcal: restingKcal, expenditureKcal: expenditureKcal,
                        dailyDeltaKcal: kcal - expenditureKcal, targetKcal: kcal, reachDate: input.now,
                        floorKcal: floorKcal, ceilingKcal: ceilingKcal, goals: goals(kcal: kcal))
        }

        func goals(kcal: Double) -> NutritionGoals {
            NutritionCalculator.goals(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg,
                                      activity: input.activity, goal: input.aim.calculatorGoal, kcal: kcal)
        }

        static func date(afterDays days: Int, from now: Date) -> Date {
            DateMath.calendar.date(byAdding: .day, value: days, to: now) ?? now.addingTimeInterval(Double(days) * 86_400)
        }
    }

    // MARK: Smoothing and tracking

    /// The mean of the weigh-ins of the last 7 days (nil when there is none).
    static func smoothedWeight(_ log: [ValuePoint], now: Date = Date()) -> Double? {
        let end = DateMath.nextMidnight(after: now)
        let start = DateMath.calendar.date(byAdding: .day, value: -smoothingDays, to: end) ?? end.addingTimeInterval(-7 * 86_400)
        let values = log.filter { $0.date >= start && $0.date < end && $0.value > 0 }.map(\.value)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Each weigh-in replaced by the mean of the weigh-ins of the 7 days up to it (the weight curve to draw).
    static func movingAverage(_ log: [ValuePoint]) -> [ValuePoint] {
        let points = log.filter { $0.value > 0 }.sorted { $0.date < $1.date }
        return points.map { point in
            let from = point.date.addingTimeInterval(-Double(smoothingDays) * 86_400)
            let window = points.filter { $0.date > from && $0.date <= point.date }.map(\.value)
            return ValuePoint(date: point.date, value: window.reduce(0, +) / Double(max(window.count, 1)))
        }
    }

    /// The real pace in kilograms a week (negative: losing), nil when the data are not enough: at least
    /// 6 weigh-ins over 14 days or more within the last 28 days (and since `since`). It is the median of
    /// the slopes between every pair of weigh-ins at least 3 days apart (Theil-Sen), so a single odd
    /// weigh-in, such as a day of water retention, does not move it.
    static func observedWeeklyChange(_ log: [ValuePoint], since: Date? = nil, now: Date = Date()) -> Double? {
        let end = DateMath.nextMidnight(after: now)
        var start = DateMath.calendar.date(byAdding: .day, value: -lookbackDays, to: end) ?? end.addingTimeInterval(-28 * 86_400)
        if let since { start = max(start, DateMath.startOfDay(since)) }
        let points = log.filter { $0.date >= start && $0.date < end && $0.value > 0 }.sorted { $0.date < $1.date }
        guard points.count >= minimumWeighIns, let first = points.first, let last = points.last,
              DateMath.daysBetween(first.date, last.date) >= minimumSpanDays - 1 else { return nil }
        var slopes: [Double] = []
        for i in 0..<points.count {
            for j in (i + 1)..<points.count {
                let gap = points[j].date.timeIntervalSince(points[i].date) / 86_400
                if gap >= 3 { slopes.append((points[j].value - points[i].value) / gap) }
            }
        }
        guard let slope = median(slopes) else { return nil }
        return slope * 7
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }

    enum Progress: Hashable {
        case notEnoughData, onTrack
        /// Moving less than planned (or against the goal).
        case slower
        /// Moving faster than planned.
        case faster
        /// Maintenance, but the weight drifts.
        case drifting
    }

    struct Tracking: Hashable {
        var smoothedKg: Double?
        /// Kilograms a week, signed; nil when there are not enough weigh-ins.
        var observedWeeklyKg: Double?
        var expectedWeeklyKg: Double
        var status: Progress
    }

    /// The planned pace in kilograms a week, signed (from the plan's start to its target).
    static func expectedWeeklyChange(_ plan: WeightPlan) -> Double {
        let days = max(DateMath.daysBetween(plan.startDate, plan.targetDate), 1)
        if plan.aim == .maintain { return 0 }
        return (plan.targetKg - plan.startKg) / Double(days) * 7
    }

    /// The real pace against the planned one. Never changes anything.
    static func tracking(plan: WeightPlan, log: [ValuePoint], now: Date = Date()) -> Tracking {
        let expected = expectedWeeklyChange(plan)
        let smoothed = smoothedWeight(log, now: now)
        guard let observed = observedWeeklyChange(log, since: plan.startDate, now: now) else {
            return Tracking(smoothedKg: smoothed, observedWeeklyKg: nil, expectedWeeklyKg: expected, status: .notEnoughData)
        }
        let status: Progress
        if plan.aim == .maintain {
            let limit = maintainDriftPercent / 100 * (smoothed ?? plan.startKg)
            status = abs(observed) >= limit ? .drifting : .onTrack
        } else {
            let ratio = observed / expected
            if ratio <= 1 - deviationThreshold { status = .slower }
            else if ratio >= 1 + deviationThreshold { status = .faster }
            else { status = .onTrack }
        }
        return Tracking(smoothedKg: smoothed, observedWeeklyKg: observed, expectedWeeklyKg: expected, status: status)
    }

    /// The needs again from the smoothed weight, the current activity and the days left (when the weight
    /// or the activity changed). A goal already reached becomes maintenance.
    static func reevaluate(plan: WeightPlan, profile: UserProfile, birthday: Date? = nil, now: Date = Date()) -> Outcome {
        let weight = smoothedWeight(profile.weightLog, now: now) ?? profile.weightKg
        let left = days(until: plan.targetDate, from: now)
        var aim = plan.aim
        if let weight {
            if aim == .lose && weight <= plan.targetKg + minimumChangeKg { aim = .maintain }
            if aim == .gain && weight >= plan.targetKg - minimumChangeKg { aim = .maintain }
        }
        if left < 1 { aim = .maintain }
        let base = input(profile: profile, birthday: birthday, aim: aim, targetKg: plan.targetKg, days: left,
                         weightKg: weight, now: now)
        return evaluate(base)
    }

    /// A proposed change of the daily calories. Nothing is applied: the user accepts or declines.
    struct Proposal: Hashable {
        var previousKcal: Double
        var newKcal: Double
        var reason: String
        var status: Progress
        var observedWeeklyKg: Double
        var expectedWeeklyKg: Double
        /// True when the safety bounds kept the change smaller than the pace would call for.
        var limitedBySafety: Bool
        var goals: NutritionGoals
    }

    /// A new calorie target, only when the real pace has differed from the planned one by 25 % or more
    /// over 14 days or more (never for an isolated weigh-in), and never past the safety bounds. Nil when
    /// nothing should change, when the data are not enough, when a proposal was declined within 14 days,
    /// or when no reliable calculation exists (a minor, a pregnancy…).
    /// `currentKcal`: the calories followed now (default: the plan's accepted calories).
    static func proposeAdjustment(plan: WeightPlan, profile: UserProfile, birthday: Date? = nil,
                                  currentKcal: Double? = nil, now: Date = Date()) -> Proposal? {
        if let declined = plan.dismissedProposalDate, DateMath.daysBetween(declined, now) < proposalPauseDays { return nil }
        let tracked = tracking(plan: plan, log: profile.weightLog, now: now)
        guard let observed = tracked.observedWeeklyKg, let smoothed = tracked.smoothedKg,
              tracked.status != .onTrack, tracked.status != .notEnoughData else { return nil }
        guard !profile.isMinor(birthday: birthday, now: now) else { return nil }

        let current: Plan
        switch reevaluate(plan: plan, profile: profile, birthday: birthday, now: now) {
        case .ok(let value), .adjusted(let value, _): current = value
        case .unsafe(_, _, _, let suggested): current = suggested
        case .referToProfessional: return nil
        }
        let previous = currentKcal ?? plan.acceptedKcal ?? current.targetKcal

        // What the body really spends, if the calories followed are the ones given.
        let spent = previous - observed * kcalPerKg / 7
        let remainingKg = plan.targetKg - smoothed
        let left = max(days(until: plan.targetDate, from: now), 1)
        let wanted = remainingKg * kcalPerKg / Double(left)
        var limited = false
        var delta = 0.0
        switch current.aim {
        case .lose where remainingKg < 0:
            let byPace = advisedLossMaxPercent / 100 * smoothed * kcalPerKg / 7
            let magnitude = min(-wanted, byPace, max(spent - current.floorKcal, 0))
            limited = magnitude < -wanted
            delta = -magnitude
        case .gain where remainingKg > 0:
            let byPace = advisedGainMaxPercent / 100 * smoothed * kcalPerKg / 7
            let magnitude = min(wanted, byPace, maxSurplusKcal)
            limited = magnitude < wanted
            delta = magnitude
        default:
            delta = 0
        }
        var proposed = spent + delta
        proposed = current.aim == .gain ? proposed.rounded(.down) : proposed.rounded(.up)
        let bounded = min(max(proposed, current.floorKcal.rounded(.up)), current.ceilingKcal.rounded(.down))
        if bounded != proposed { limited = true }
        guard abs(bounded - previous) >= minimumProposalChangeKcal else { return nil }

        let reason: String
        switch tracked.status {
        case .slower: reason = slowerReason
        case .faster: reason = fasterReason
        default: reason = driftingReason
        }
        return Proposal(previousKcal: previous, newKcal: bounded, reason: reason, status: tracked.status,
                        observedWeeklyKg: observed, expectedWeeklyKg: tracked.expectedWeeklyKg,
                        limitedBySafety: limited, goals: macros(for: current, kcal: bounded, profile: profile, weightKg: smoothed, birthday: birthday, now: now))
    }

    /// The macronutrients of the same body and activity as `plan`, for other calories.
    private static func macros(for plan: Plan, kcal: Double, profile: UserProfile, weightKg: Double, birthday: Date?, now: Date) -> NutritionGoals {
        NutritionCalculator.goals(sex: profile.calculatorSex ?? .neutral, age: profile.age(birthday: birthday, now: now) ?? 30,
                                  heightCm: profile.heightCm ?? 170, weightKg: weightKg,
                                  activity: profile.calculatedActivity ?? .sedentary, goal: plan.aim.calculatorGoal, kcal: kcal)
    }

    // MARK: Texts (keys for tr, in French)

    static var pregnancyReason: String {
        tr("Pendant la grossesse ou l'allaitement, les besoins changent : parle à un professionnel de santé avant tout objectif de poids.")
    }
    static var minorReason: String {
        tr("Pour ton âge, Ardane ne calcule pas d'objectif de poids : parle à un professionnel de santé.")
    }
    static var minorMaintenanceReason: String {
        tr("Pour ton âge, seul le maintien est calculé, à titre indicatif. Parle à un professionnel de santé de ton alimentation.")
    }
    static var unspecifiedStageReason: String {
        tr("Sans cette information, Ardane ne propose pas de perte ni de prise de poids. Précise ta situation ou parle à un professionnel de santé.")
    }
    static var highBMIReason: String {
        tr("Ton poids actuel est déjà élevé pour ta taille : Ardane ne propose pas de prise de poids. Parle à un professionnel de santé.")
    }
    static var belowFloorReason: String {
        tr("Tes besoins estimés sont sous le minimum de calories d'Ardane : parle à un professionnel de santé.")
    }
    static var lowBMIReason: String {
        tr("Ton poids actuel est déjà bas pour ta taille : Ardane ne propose pas de perte de poids. Parle à un professionnel de santé.")
    }
    static var lowTargetBMIReason: String {
        tr("Le poids cible est trop bas pour ta taille : parle à un professionnel de santé.")
    }
    static var missingDataReason: String {
        tr("Il manque des informations (âge, taille, poids ou sexe de calcul) ou elles semblent erronées : Ardane ne peut pas calculer un objectif fiable.")
    }
    static var inconsistentGoalReason: String {
        tr("Le poids cible ou la date ne correspond pas à l'objectif choisi.")
    }
    static var noMarginReason: String {
        tr("Tes besoins estimés laissent trop peu de marge pour changer de poids en sécurité : parle à un professionnel de santé.")
    }
    static var tooLongReason: String {
        tr("Cet objectif demanderait plus de deux ans en restant prudent : parle à un professionnel de santé.")
    }
    static var unsafeLossReason: String {
        tr("Objectif impossible à atteindre de manière sûre : perdre autant de poids aussi vite dépasse un rythme prudent.")
    }
    static var unsafeGainReason: String {
        tr("Objectif impossible à atteindre de manière sûre : prendre autant de poids aussi vite dépasse un rythme prudent.")
    }
    static var briskLossReason: String {
        tr("Rythme soutenu mais dans les limites : plus de 0,75 % du poids par semaine demande de la rigueur.")
    }
    static var slowerReason: String {
        tr("Ton poids évolue plus lentement que prévu depuis au moins deux semaines. Voici un ajustement progressif, à accepter si tu le souhaites.")
    }
    static var fasterReason: String {
        tr("Ton poids évolue plus vite que prévu depuis au moins deux semaines. Voici un ajustement progressif, à accepter si tu le souhaites.")
    }
    static var driftingReason: String {
        tr("Ton poids s'écarte de ton poids stable depuis au moins deux semaines. Voici un ajustement progressif, à accepter si tu le souhaites.")
    }
}
