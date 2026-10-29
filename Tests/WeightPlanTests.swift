import XCTest
@testable import Ardane

/// Objectif de poids (chantier 15): safe calories, the alternative duration, the cautious cases, and the
/// tracking that proposes (never applies) an adjustment.
@MainActor
final class WeightPlanTests: XCTestCase {
    private typealias Calc = WeightPlanCalculator

    private let now = DateMath.startOfDay(Date()).addingTimeInterval(12 * 3600)

    private func profile(sex: BodySex = .male, age: Int = 35, height: Double = 180, weight: Double = 100,
                         activity: NutritionCalculator.Activity = .active) -> UserProfile {
        var profile = UserProfile()
        profile.sex = sex
        profile.birthYear = DateMath.calendar.component(.year, from: Date()) - age
        profile.heightCm = height
        profile.weightKg = weight
        profile.calculatedActivity = activity
        profile.lifeStage = .adult
        return profile
    }

    private func evaluate(_ profile: UserProfile, _ aim: NutritionAim, target: Double?, weeks: Int) -> Calc.Outcome {
        Calc.evaluate(Calc.input(profile: profile, aim: aim, targetKg: target, days: weeks * 7, now: now))
    }

    /// The plan of an outcome that gives numbers (the suggested one for `.unsafe`).
    private func numbers(of outcome: Calc.Outcome) -> Calc.Plan? {
        switch outcome {
        case .ok(let plan), .adjusted(let plan, _): plan
        case .unsafe(_, _, _, let suggested): suggested
        case .referToProfessional: nil
        }
    }

    private func isRefer(_ outcome: Calc.Outcome) -> Bool {
        if case .referToProfessional = outcome { return true }
        return false
    }

    // MARK: Scenarios

    func testRealisticLossIsOk() {
        // 100 kg to 85 kg in 5 months (150 days): about 0,7 kg a week.
        let outcome = Calc.evaluate(Calc.input(profile: profile(), aim: .lose, targetKg: 85, days: 150, now: now))
        guard case .ok(let plan) = outcome else { return XCTFail("Expected .ok, got \(outcome)") }
        XCTAssertEqual(plan.weeklyChangeKg, -0.7, accuracy: 0.01)
        XCTAssertEqual(plan.weeklyPercent, -0.7, accuracy: 0.01)
        XCTAssertLessThan(plan.targetKcal, plan.expenditureKcal)
        XCTAssertGreaterThanOrEqual(plan.targetKcal, plan.floorKcal)
        // The deficit comes from the weight and the days: 15 kg × 7 700 / 150 days = 770 kcal a day.
        XCTAssertEqual(plan.expenditureKcal - plan.targetKcal, 770, accuracy: 1)
        XCTAssertEqual(plan.goals.kcal, plan.targetKcal)
        XCTAssertGreaterThan(plan.goals.protein, 0)
        XCTAssertGreaterThan(plan.reachDate, now)
    }

    func testBriskLossWithinLimitsIsAdjusted() {
        // 60 kg to 56 kg in 8 weeks: 0,83 % a week, a 550 kcal deficit (under 25 % of the energy spent).
        let outcome = evaluate(profile(sex: .female, age: 25, height: 170, weight: 60), .lose, target: 56, weeks: 8)
        guard case .adjusted(let plan, let reason) = outcome else { return XCTFail("Expected .adjusted, got \(outcome)") }
        XCTAssertFalse(reason.isEmpty)
        XCTAssertGreaterThanOrEqual(plan.targetKcal, plan.floorKcal)
    }

    func testTooAmbitiousLossIsUnsafeWithAlternative() {
        // 15 kg in 14 weeks is 1,07 % a week.
        let outcome = evaluate(profile(), .lose, target: 85, weeks: 14)
        guard case .unsafe(_, let weeks, let date, let suggested) = outcome else { return XCTFail("Expected .unsafe, got \(outcome)") }
        XCTAssertGreaterThan(weeks, 14)
        XCTAssertLessThanOrEqual(abs(suggested.weeklyPercent), Calc.advisedLossMaxPercent + 0.0001)
        XCTAssertEqual(suggested.reachDate, date)
        XCTAssertGreaterThanOrEqual(suggested.targetKcal, suggested.floorKcal)
    }

    func testImpossibleLossInOneWeekIsUnsafeAndNeverExtreme() {
        let outcome = evaluate(profile(), .lose, target: 85, weeks: 1)
        guard case .unsafe(let reason, let weeks, _, let suggested) = outcome else { return XCTFail("Expected .unsafe, got \(outcome)") }
        XCTAssertFalse(reason.isEmpty)
        XCTAssertEqual(weeks, 20, "15 kg at 0,75 kg a week")
        XCTAssertGreaterThanOrEqual(suggested.targetKcal, suggested.floorKcal)
        XCTAssertGreaterThanOrEqual(suggested.targetKcal, 1_400)
    }

    func testGainAndMaintain() {
        let lean = profile(age: 30, height: 175, weight: 70, activity: .moderate)
        guard case .ok(let gain) = evaluate(lean, .gain, target: 73, weeks: 12) else { return XCTFail("Expected a calm gain to be .ok") }
        XCTAssertGreaterThan(gain.targetKcal, gain.expenditureKcal)
        XCTAssertLessThanOrEqual(gain.dailyDeltaKcal, Calc.maxSurplusKcal)

        guard case .unsafe(_, let weeks, _, let suggested) = evaluate(lean, .gain, target: 80, weeks: 8) else {
            return XCTFail("10 kg in 8 weeks must be unsafe")
        }
        XCTAssertGreaterThan(weeks, 8)
        XCTAssertLessThanOrEqual(suggested.targetKcal, suggested.ceilingKcal)

        guard case .ok(let steady) = evaluate(lean, .maintain, target: nil, weeks: 0) else { return XCTFail("Expected maintenance to be .ok") }
        XCTAssertEqual(steady.dailyDeltaKcal, 0, accuracy: 1)
        XCTAssertEqual(steady.weeklyChangeKg, 0)
    }

    func testMinorGetsNoLossOrGain() {
        let teen = profile(age: 15, height: 170, weight: 65)
        XCTAssertTrue(isRefer(evaluate(teen, .lose, target: 60, weeks: 20)))
        XCTAssertTrue(isRefer(evaluate(teen, .gain, target: 70, weeks: 20)))
        guard case .adjusted(let plan, _) = evaluate(teen, .maintain, target: nil, weeks: 0) else {
            return XCTFail("A minor gets maintenance only")
        }
        XCTAssertEqual(plan.weeklyChangeKg, 0)
        var declared = profile(age: 40)
        declared.lifeStage = .minor
        XCTAssertTrue(isRefer(evaluate(declared, .lose, target: 90, weeks: 20)))
        XCTAssertTrue(declared.isMinor)
        XCTAssertTrue(profile(age: 17).isMinor)
        XCTAssertFalse(profile(age: 30).isMinor)
    }

    func testPregnancyAndBreastfeedingAreReferred() {
        for stage in [LifeStage.pregnant, .breastfeeding] {
            var person = profile(sex: .female, age: 30, height: 165, weight: 75)
            person.lifeStage = stage
            XCTAssertTrue(isRefer(evaluate(person, .lose, target: 68, weeks: 20)), "\(stage)")
            XCTAssertTrue(isRefer(evaluate(person, .gain, target: 80, weeks: 20)), "\(stage)")
            XCTAssertTrue(isRefer(evaluate(person, .maintain, target: nil, weeks: 0)), "\(stage)")
        }
    }

    func testPreferNotToSayGetsNoDeficit() {
        var person = profile()
        person.lifeStage = .preferNotToSay
        XCTAssertTrue(isRefer(evaluate(person, .lose, target: 90, weeks: 20)))
        guard case .ok = evaluate(person, .maintain, target: nil, weeks: 0) else { return XCTFail("Maintenance stays possible") }
    }

    func testUndeclaredLifeStageGetsNoLossOrGain() {
        var person = profile()
        person.lifeStage = nil
        XCTAssertTrue(isRefer(evaluate(person, .lose, target: 90, weeks: 20)))
        XCTAssertTrue(isRefer(evaluate(person, .gain, target: 105, weeks: 20)))
        guard case .ok = evaluate(person, .maintain, target: nil, weeks: 0) else { return XCTFail("Maintenance stays possible") }
    }

    func testBirthYearAloneCanOverestimateTheAge() {
        // Born in December 2008, read in October 2026: 17 years old, though the years differ by 18.
        let october = DateMath.calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)) ?? now
        var person = profile(age: 18)
        person.birthYear = 2008
        XCTAssertTrue(person.isMinor(birthday: nil, now: october))
        let outcome = Calc.evaluate(Calc.input(profile: person, aim: .lose, targetKg: 90, days: 140, now: october))
        XCTAssertTrue(isRefer(outcome))
        // With an exact birthday (18 years old since September), the adult path applies.
        let birthday = DateMath.calendar.date(from: DateComponents(year: 2008, month: 9, day: 1, hour: 12))
        XCTAssertFalse(person.isMinor(birthday: birthday, now: october))
    }

    func testReevaluationSwitchesToMaintenanceNearTheTarget() {
        let points = log(days: 14, start: 80.3, perDay: 0)
        guard case .ok(let again) = Calc.reevaluate(plan: plan, profile: trackedProfile(log: points), now: now) else {
            return XCTFail("0,3 kg from the target is maintenance")
        }
        XCTAssertEqual(again.aim, .maintain)
    }

    func testGainFromAHighBMIIsReferred() {
        // 100 kg at 170 cm is a body mass index of 34,6.
        XCTAssertTrue(isRefer(evaluate(profile(height: 170, weight: 100), .gain, target: 105, weeks: 20)))
    }

    func testMaintenanceBelowTheFloorIsReferred() {
        // 45 kg, 150 cm, 80 years old, sedentary: the energy spent (about 990 kcal) is under the 1 400 floor.
        let frail = profile(sex: .female, age: 80, height: 150, weight: 45, activity: .sedentary)
        XCTAssertTrue(isRefer(evaluate(frail, .maintain, target: nil, weeks: 0)))
    }

    func testAlternativeDurationIsExactForOtherWeights() {
        // 80 kg to 68 kg in 2 weeks: the safe pace is 0,75 % of 80 kg = 0,6 kg a week, so exactly 20 weeks.
        guard case .unsafe(_, let weeks, _, _) = evaluate(profile(weight: 80), .lose, target: 68, weeks: 2) else {
            return XCTFail("Expected .unsafe")
        }
        XCTAssertEqual(weeks, 20)
    }

    func testLowBMIIsReferred() {
        // 50 kg at 175 cm is a body mass index of 16,3.
        XCTAssertTrue(isRefer(evaluate(profile(height: 175, weight: 50), .lose, target: 47, weeks: 20)))
        // The target itself is too low: 55 kg at 175 cm is 17,96.
        XCTAssertTrue(isRefer(evaluate(profile(height: 175, weight: 60), .lose, target: 55, weeks: 30)))
    }

    func testMissingOrWrongDataIsReferred() {
        var noSex = profile()
        noSex.sex = nil
        XCTAssertTrue(isRefer(evaluate(noSex, .lose, target: 90, weeks: 20)))
        var noHeight = profile()
        noHeight.heightCm = nil
        XCTAssertTrue(isRefer(evaluate(noHeight, .lose, target: 90, weeks: 20)))
        var noAge = profile()
        noAge.birthYear = nil
        XCTAssertTrue(isRefer(evaluate(noAge, .maintain, target: nil, weeks: 0)))
        XCTAssertTrue(isRefer(evaluate(profile(height: 20), .lose, target: 90, weeks: 20)))
        XCTAssertTrue(isRefer(evaluate(profile(), .lose, target: nil, weeks: 20)))
        XCTAssertTrue(isRefer(evaluate(profile(), .lose, target: 105, weeks: 20)), "A loss aimed above the weight")
        XCTAssertTrue(isRefer(evaluate(profile(), .gain, target: 90, weeks: 20)), "A gain aimed below the weight")
        XCTAssertTrue(isRefer(Calc.evaluate(Calc.input(profile: profile(), aim: .lose, targetKg: 90, days: 0, now: now))))
    }

    // MARK: Safety grid

    func testNoPlanEverGoesBelowTheFloorOrAboveTheCeiling() {
        var checked = 0
        for weight in [40.0, 55, 70, 85, 100, 130, 170, 200] {
            for height in [150.0, 165, 180, 195] {
                for age in [18, 30, 45, 65, 90] {
                    for sex in NutritionCalculator.Sex.allCases {
                        for activity in [NutritionCalculator.Activity.sedentary, .active] {
                            let steps = NutritionCalculator.breakdown(sex: sex, age: age, heightCm: height, weightKg: weight,
                                                                      activity: activity, goal: .maintain)
                            let floor = Calc.minimumKcal(sex: sex, restingKcal: steps.restingKcal)
                            let ceiling = Calc.maximumKcal(expenditureKcal: steps.dailyKcal)
                            for weeks in [1, 4, 8, 13, 26, 52, 104] {
                                let cases: [(NutritionAim, Double)] = [(.lose, 0.9), (.lose, 0.7), (.lose, 0.5), (.gain, 1.05), (.gain, 1.3)]
                                for (aim, factor) in cases {
                                    let input = Calc.Input(sex: sex, age: age, heightCm: height, weightKg: weight, activity: activity,
                                                           lifeStage: .adult, aim: aim, targetKg: weight * factor, days: weeks * 7, now: now)
                                    let outcome = Calc.evaluate(input)
                                    checked += 1
                                    guard let plan = self.numbers(of: outcome) else { continue }
                                    let label = "\(aim) \(weight) kg \(height) cm \(age) y \(sex) \(activity) \(weeks) w"
                                    XCTAssertGreaterThanOrEqual(plan.targetKcal, floor, label)
                                    XCTAssertLessThanOrEqual(plan.targetKcal, ceiling, label)
                                    XCTAssertEqual(plan.goals.kcal, plan.targetKcal, label)
                                    if aim == .lose {
                                        XCTAssertGreaterThanOrEqual(plan.weeklyPercent, -Calc.maxLossPercentPerWeek - 0.0001, label)
                                    } else {
                                        XCTAssertLessThanOrEqual(plan.weeklyPercent, Calc.maxGainPercentPerWeek + 0.0001, label)
                                        XCTAssertLessThanOrEqual(plan.dailyDeltaKcal, Calc.maxSurplusKcal + 1, label)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(checked, 10_000)
    }

    // MARK: Saved data

    func testOldProfilesDecodeWithoutThePlan() throws {
        let old = try JSONDecoder().decode(UserProfile.self, from: Data(#"{"weightKg":80,"interests":["sport"]}"#.utf8))
        XCTAssertNil(old.weightPlan)
        XCTAssertNil(old.lifeStage)
        XCTAssertEqual(old.weightKg, 80)
        let odd = try JSONDecoder().decode(UserProfile.self, from: Data(#"{"lifeStage":"alien","weightPlan":{"targetKg":70}}"#.utf8))
        XCTAssertNil(odd.lifeStage)
        XCTAssertEqual(odd.weightPlan?.targetKg, 70)
        XCTAssertNil(odd.weightPlan?.acceptedKcal)
    }

    func testPlanSurvivesSaving() throws {
        var saved = UserProfile()
        saved.lifeStage = .adult
        saved.weightPlan = WeightPlan(targetKg: 85, startKg: 100, startDate: now, targetDate: now.addingTimeInterval(150 * 86_400),
                                      acceptedKcal: 2_600, dismissedProposalDate: nil)
        let data = try JSONEncoder().encode(saved)
        XCTAssertEqual(try JSONDecoder().decode(UserProfile.self, from: data), saved)
        XCTAssertEqual(saved.weightPlan?.aim, .lose)
    }

    // MARK: Tracking

    /// Daily weigh-ins for the last `days` days ending today, from `start` kg by `perDay` kg.
    private func log(days: Int, start: Double, perDay: Double) -> [ValuePoint] {
        (0...days).map { index in
            let date = DateMath.calendar.date(byAdding: .day, value: index - days, to: now) ?? now
            return ValuePoint(date: date, value: start + perDay * Double(index))
        }
    }

    private func trackedProfile(log: [ValuePoint]) -> UserProfile {
        var person = profile(weight: log.last?.value ?? 88)
        person.weightLog = log
        return person
    }

    /// A loss plan of 0,5 kg a week that started 28 days ago.
    private var plan: WeightPlan {
        let start = DateMath.calendar.date(byAdding: .day, value: -28, to: now) ?? now
        let end = DateMath.calendar.date(byAdding: .day, value: 112, to: now) ?? now
        return WeightPlan(targetKg: 80, startKg: 90, startDate: start, targetDate: end, acceptedKcal: 2_800)
    }

    func testMovingAverageSmoothsAnIsolatedPeak() {
        var points = log(days: 14, start: 90, perDay: 0)
        points[points.count - 2].value = 93
        let smoothed = Calc.smoothedWeight(points, now: now)
        XCTAssertNotNil(smoothed)
        XCTAssertEqual(smoothed ?? 0, 90 + 3.0 / 7, accuracy: 0.01)
        let curve = Calc.movingAverage(points)
        XCTAssertEqual(curve.count, points.count)
        XCTAssertEqual(curve[3].value, 90, accuracy: 0.001)
        XCTAssertLessThan(curve.last?.value ?? 100, 91)
    }

    func testObservedPaceNeedsTwoWeeks() {
        XCTAssertNil(Calc.observedWeeklyChange(log(days: 8, start: 90, perDay: -0.07), now: now))
        let pace = Calc.observedWeeklyChange(log(days: 28, start: 90, perDay: -0.5 / 7), now: now)
        XCTAssertEqual(pace ?? 0, -0.5, accuracy: 0.01)
    }

    func testOnTrackProposesNothing() {
        let points = log(days: 28, start: 90, perDay: -0.5 / 7)
        let tracked = Calc.tracking(plan: plan, log: points, now: now)
        XCTAssertEqual(tracked.status, .onTrack)
        XCTAssertNil(Calc.proposeAdjustment(plan: plan, profile: trackedProfile(log: points), now: now))
    }

    func testAnIsolatedPeakDoesNotTriggerAnAdjustment() {
        var points = log(days: 28, start: 90, perDay: -0.5 / 7)
        points[points.count - 2].value += 3
        XCTAssertNil(Calc.proposeAdjustment(plan: plan, profile: trackedProfile(log: points), now: now))
    }

    func testNotEnoughDataProposesNothing() {
        let points = log(days: 6, start: 90, perDay: -0.01)
        XCTAssertEqual(Calc.tracking(plan: plan, log: points, now: now).status, .notEnoughData)
        XCTAssertNil(Calc.proposeAdjustment(plan: plan, profile: trackedProfile(log: points), now: now))
    }

    func testAPersistentlySlowerPaceProposesLowerCaloriesWithinTheBounds() {
        let points = log(days: 28, start: 90, perDay: -0.2 / 7)
        let person = trackedProfile(log: points)
        XCTAssertEqual(Calc.tracking(plan: plan, log: points, now: now).status, .slower)
        guard let proposal = Calc.proposeAdjustment(plan: plan, profile: person, now: now) else { return XCTFail("Expected a proposal") }
        XCTAssertEqual(proposal.previousKcal, 2_800)
        XCTAssertLessThan(proposal.newKcal, proposal.previousKcal)
        XCTAssertGreaterThanOrEqual(proposal.newKcal, Calc.minimumKcal(sex: .male, restingKcal: 1_900))
        XCTAssertEqual(proposal.goals.kcal, proposal.newKcal)
        XCTAssertFalse(proposal.reason.isEmpty)
        // Nothing was applied.
        XCTAssertEqual(person.weightPlan, nil)
    }

    func testAFasterPaceProposesMoreCalories() {
        let points = log(days: 28, start: 90, perDay: -1.0 / 7)
        guard let proposal = Calc.proposeAdjustment(plan: plan, profile: trackedProfile(log: points), now: now) else {
            return XCTFail("Expected a proposal")
        }
        XCTAssertEqual(Calc.tracking(plan: plan, log: points, now: now).status, .faster)
        XCTAssertGreaterThan(proposal.newKcal, proposal.previousKcal)
    }

    func testADeclinedProposalPausesTheNext() {
        var declined = plan
        declined.dismissedProposalDate = DateMath.calendar.date(byAdding: .day, value: -3, to: now)
        let points = log(days: 28, start: 90, perDay: -0.2 / 7)
        XCTAssertNil(Calc.proposeAdjustment(plan: declined, profile: trackedProfile(log: points), now: now))
    }

    func testNeedsRestartFromTheSmoothedWeight() {
        let points = log(days: 14, start: 90, perDay: -0.1)
        let person = trackedProfile(log: points)
        guard case .ok(let again) = Calc.reevaluate(plan: plan, profile: person, now: now)
            else { return XCTFail("The loss is still to do") }
        XCTAssertEqual(again.startKg, Calc.smoothedWeight(points, now: now) ?? 0, accuracy: 0.001)
    }
}
