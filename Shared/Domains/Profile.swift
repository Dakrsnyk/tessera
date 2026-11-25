import Foundation

// « Mes informations »: what the user tells Ardane about themselves, entered once and reused by every
// widget. Each fact has exactly one home. Most live here, in `UserProfile`; the ones a space already
// keeps (nutrition targets, weekly workouts, monthly budget…) stay in that space's data, and the profile
// only records that the user actually gave them, so a default value is never shown as theirs.

/// What the user is interested in, picked at the first launch. It decides which questions are asked and
/// what Ardane puts forward first, never what it hides.
enum Interest: String, Codable, CaseIterable, Identifiable {
    case sport, nutrition, finance, budget, business, studies, productivity, travel, car, design, wellbeing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sport: tr("Sport")
        case .nutrition: tr("Nutrition")
        case .finance: tr("Finance")
        case .budget: tr("Budget")
        case .business: tr("Business")
        case .studies: tr("Études")
        // « Planning » since 2026-11-17 (the saved value stays `productivity`).
        case .productivity: tr("Planning")
        case .travel: tr("Voyage")
        case .car: tr("Automobile")
        case .design: tr("Design")
        case .wellbeing: tr("Bien-être")
        }
    }

    /// The tiles of the grid of interests. Finance is no longer offered (PDG, 2026-11-22): Business leads to the
    /// finances page; an older account that picked it still sees its tile, to be able to untick it.
    static func offered(keeping selection: [Interest]) -> [Interest] {
        // Auto is removed (PDG, 2026-11-25): never offered, even to an account that had picked it.
        allCases.filter { $0 != .car && ($0 != .finance || selection.contains(.finance)) }
    }

    var symbol: String {
        switch self {
        case .sport: "dumbbell.fill"
        case .nutrition: "fork.knife"
        case .finance: "chart.line.uptrend.xyaxis"
        case .budget: "creditcard.fill"
        case .business: "briefcase.fill"
        case .studies: "graduationcap.fill"
        case .productivity: "checklist"
        case .travel: "airplane"
        case .car: "car.fill"
        case .design: "paintpalette.fill"
        case .wellbeing: "heart.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .sport: "E5484D"
        case .nutrition: "F08A24"
        case .finance: "8C6CFF"
        case .budget: "2F8F7A"
        case .business: "C28A12"
        case .studies: "D6409F"
        case .productivity: "6B7280"
        case .travel: "12A4B5"
        case .car: "4B5563"
        case .design: "E0567A"
        case .wellbeing: "7FA33A"
        }
    }

    /// The spaces of « Créer » this interest puts forward.
    var spaces: [Space] {
        switch self {
        case .sport: [.fitness]
        case .nutrition: [.nutrition]
        case .finance: [.investing, .markets]
        case .budget: [.budget]
        // Business takes over the finance spaces since Finance left the grid (2026-11-22).
        case .business: [.business, .investing, .markets]
        case .studies: [.student]
        case .productivity: [.productivity]
        case .travel: [.travel]
        case .car: [.car]
        case .design: []
        case .wellbeing: [.habits, .life]
        }
    }

    /// The Store categories it puts forward.
    var categories: [WidgetCategory] {
        switch self {
        case .sport: [.fitness]
        case .nutrition: [.nutrition]
        case .finance: [.investing, .markets]
        case .budget: [.finance]
        case .business: [.business, .investing, .markets]
        case .studies: [.student]
        case .productivity: [.productivity]
        case .travel: [.travel]
        case .car: [.car]
        case .design: [.time]
        case .wellbeing: [.wellbeing]
        }
    }

    /// The pages of questions it leads to (finance and budget share theirs; Business also leads to the
    /// finances page since 2026-11-22). Empty when there is nothing worth asking.
    var topics: [ProfileTopic] {
        switch self {
        case .sport: [.sport]
        case .nutrition: [.nutrition]
        case .finance, .budget: [.money]
        case .business: [.business, .money]
        case .studies: [.studies]
        case .productivity: [.productivity]
        case .car: [.car]
        case .wellbeing: [.wellbeing]
        case .travel, .design: []
        }
    }
}

/// A group of personal information: one page of questions, one card of « Mes informations ».
enum ProfileTopic: String, Codable, CaseIterable, Identifiable {
    case sport, nutrition, money, business, productivity, studies, car, wellbeing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sport: tr("Sport")
        case .nutrition: tr("Nutrition")
        case .money: tr("Finances")
        case .business: tr("Business")
        case .productivity: tr("Planning")
        case .studies: tr("Études")
        case .car: tr("Automobile")
        case .wellbeing: tr("Bien-être")
        }
    }

    var symbol: String {
        switch self {
        case .sport: "dumbbell.fill"
        case .nutrition: "fork.knife"
        case .money: "banknote.fill"
        case .business: "briefcase.fill"
        case .productivity: "checklist"
        case .studies: "graduationcap.fill"
        case .car: "car.fill"
        case .wellbeing: "heart.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .sport: "E5484D"
        case .nutrition: "F08A24"
        case .money: "2F8F7A"
        case .business: "C28A12"
        case .productivity: "6B7280"
        case .studies: "D6409F"
        case .car: "4B5563"
        case .wellbeing: "7FA33A"
        }
    }

    /// One line under the page title, saying what the answers are for.
    var purpose: String {
        switch self {
        case .sport: tr("Pour des widgets Fitness à ton niveau, et des calories brûlées estimées avec ton poids.")
        case .nutrition: tr("Tes objectifs du jour : les widgets Nutrition comptent ce qu'il te reste.")
        case .money: tr("Ton budget et ton épargne, repris par les widgets Budget et Finances.")
        case .business: tr("Ton activité et ton objectif, suivis par les widgets Business.")
        case .productivity: tr("Ce que tu veux accomplir, pour des widgets qui t'y ramènent.")
        case .studies: tr("Ton programme et ton rythme de travail.")
        case .car: tr("Ta voiture et son kilométrage, pour suivre pleins et entretiens.")
        case .wellbeing: tr("Une première habitude à suivre.")
        }
    }
}

/// The one goal of the person, shared by Sport and Nutrition (`UserProfile.goal`). The saved values never
/// change name: `muscleGain` and `recomposition` came after the others.
enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case bulk, weightLoss, cut, performance, maintain, strength, endurance
    case muscleGain, recomposition
    var id: String { rawValue }

    var title: String {
        switch self {
        case .bulk: tr("Prise de masse")
        case .weightLoss: tr("Perte de poids")
        case .cut: tr("Sèche")
        case .performance: tr("Performance")
        case .maintain: tr("Maintien")
        case .strength: tr("Force")
        case .endurance: tr("Endurance")
        case .muscleGain: tr("Prise de muscle")
        case .recomposition: tr("Recomposition corporelle")
        }
    }

    /// The order of the list shown in Sport and in Nutrition (the same one): lose, keep, build, perform.
    static let displayOrder: [FitnessGoal] = [.weightLoss, .cut, .maintain, .recomposition, .muscleGain, .bulk, .strength, .performance, .endurance]

    /// The coarse aim that goes with it (loss, maintaining, gain): what the weight goal and the older
    /// `UserProfile.nutritionAim` speak of.
    var nutritionAim: NutritionAim {
        switch self {
        case .bulk, .strength, .muscleGain: .gain
        case .weightLoss, .cut: .lose
        case .performance, .maintain, .endurance, .recomposition: .maintain
        }
    }

    /// How the daily needs are calculated for it (`NutritionCalculator.Goal`).
    var calculatorGoal: NutritionCalculator.Goal {
        switch self {
        case .weightLoss: .lose
        case .cut: .cut
        case .maintain: .maintain
        case .recomposition: .recomposition
        case .muscleGain, .strength: .gain
        case .bulk: .massGain
        case .performance, .endurance: .performance
        }
    }

    /// The goal an older account's `nutritionAim` stood for.
    static func from(_ aim: NutritionAim) -> FitnessGoal {
        switch aim {
        case .lose: .weightLoss
        case .maintain: .maintain
        case .gain: .muscleGain
        }
    }
}

/// What the training side of the goal aims at, beside the weight (« Perte de poids et force »). Nil: the weight
/// only. Kept apart from `FitnessGoal` so the calculation and the older accounts are unchanged.
enum GoalFocus: String, Codable, CaseIterable, Identifiable {
    case strength, endurance
    var id: String { rawValue }

    /// The focus a goal already says by itself (« Force », « Endurance »).
    static func implied(by goal: FitnessGoal?) -> GoalFocus? {
        switch goal {
        case .strength: .strength
        case .endurance: .endurance
        default: nil
        }
    }
}

/// One answer of « Ton objectif » in Nutrition: the weight and, when it matters, the training side together
/// (PDG, 2026-11-22). Saved as the shared goal (`UserProfile.goal`, which the calculation reads) and its focus.
struct NutritionGoalChoice: Identifiable, Hashable {
    let goal: FitnessGoal
    let focus: GoalFocus?
    let title: String

    var id: String { goal.rawValue + "-" + (focus?.rawValue ?? "none") }

    static var all: [NutritionGoalChoice] {
        [
            NutritionGoalChoice(goal: .weightLoss, focus: nil, title: tr("Perte de poids")),
            NutritionGoalChoice(goal: .weightLoss, focus: .strength, title: tr("Perte de poids et force")),
            NutritionGoalChoice(goal: .weightLoss, focus: .endurance, title: tr("Perte de poids et endurance")),
            NutritionGoalChoice(goal: .maintain, focus: nil, title: tr("Maintien du poids")),
            NutritionGoalChoice(goal: .maintain, focus: .strength, title: tr("Maintien du poids et force")),
            NutritionGoalChoice(goal: .endurance, focus: .endurance, title: tr("Maintien du poids et endurance")),
            NutritionGoalChoice(goal: .recomposition, focus: nil, title: tr("Recomposition corporelle")),
            NutritionGoalChoice(goal: .muscleGain, focus: nil, title: tr("Prise de muscle")),
            NutritionGoalChoice(goal: .strength, focus: .strength, title: tr("Prise de muscle et force")),
            NutritionGoalChoice(goal: .bulk, focus: nil, title: tr("Prise de masse")),
        ]
    }

    /// The choice the profile stands for, nil when its goal was picked elsewhere without a match (Sèche…).
    static func current(_ profile: UserProfile) -> NutritionGoalChoice? {
        guard let goal = profile.goal else { return nil }
        let focus = profile.goalFocus ?? GoalFocus.implied(by: goal)
        return all.first { $0.goal == goal && $0.focus == focus }
    }
}

enum FitnessLevel: String, Codable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: tr("Débutant")
        case .intermediate: tr("Intermédiaire")
        case .advanced: tr("Avancé")
        }
    }
}

enum NutritionAim: String, Codable, CaseIterable, Identifiable {
    case lose, maintain, gain
    var id: String { rawValue }

    var title: String {
        switch self {
        case .lose: tr("Perdre du poids")
        case .maintain: tr("Maintenir")
        case .gain: tr("Prendre du muscle")
        }
    }

    var calculatorGoal: NutritionCalculator.Goal {
        switch self {
        case .lose: .lose
        case .maintain: .maintain
        case .gain: .gain
        }
    }
}

/// The user's gender as they describe it. It can be changed at any time.
enum BodySex: String, Codable, CaseIterable, Identifiable {
    case female, male, nonBinary, other, undisclosed
    var id: String { rawValue }

    var title: String {
        switch self {
        case .female: tr("Femme")
        case .male: tr("Homme")
        case .nonBinary: tr("Non binaire")
        case .other: tr("Autre")
        case .undisclosed: tr("Je préfère ne pas répondre")
        }
    }

    /// Whether the calorie formula can use it directly (else the user's chosen reference, or the average).
    var isBinary: Bool { self == .female || self == .male }

    var calculatorSex: NutritionCalculator.Sex {
        switch self {
        case .female: .female
        case .male: .male
        case .nonBinary, .other, .undisclosed: .neutral
        }
    }
}

/// Facts kept in a space's own data (their only copy), once the user has given them.
enum ProvidedFact: String, Codable, CaseIterable {
    case kcalTarget, proteinTarget, carbsTarget, fatTarget
    case weeklyWorkouts, monthlyBudget, businessName, businessGoal, focusGoal, hydrationGoal, carName
    /// The study hours a week of Études (`StudentState.weeklyStudyGoalHours`).
    case studyGoal
}

struct UserProfile: Codable, Hashable {
    // Identity. The first name is `AppSettings.profileName`, shown since the first versions.
    var lastName = ""

    var interests: [Interest] = []
    /// Pages of questions the user chose to skip: « Mes informations » offers to complete them.
    var skippedTopics: [ProfileTopic] = []

    // Body. The age comes from the birthday of « Ma vie » when it is set, else from the birth year.
    var birthYear: Int?
    var heightCm: Double?
    var weightKg: Double?
    /// Every weight given, one per day (the last one of the day wins): Nutrition and Fitness draw it.
    var weightLog: [ValuePoint] = []
    var sex: BodySex?
    /// Free words when the user chose « Autre » (optional).
    var genderDetail = ""
    /// For non-binary answers: the reference the calorie formula uses (nil = the average of both).
    var calculationSex: NutritionCalculator.Sex?

    // Sport (the workouts per week are `FitnessState.weeklyGoal`).
    /// The goal, shared by Sport and Nutrition (read it through `goal`, which also takes an older account's
    /// `nutritionAim` into account).
    var fitnessGoal: FitnessGoal?
    /// The training side chosen with the goal in Nutrition (« … et force »), nil for the weight only. Cleared
    /// when the goal changes.
    var goalFocus: GoalFocus?
    var fitnessLevel: FitnessLevel?
    /// Steps a day, for « Mon Quotidien » (the steps come from the iPhone's motion sensor).
    var stepGoal: Int?

    // Nutrition (the daily targets are `NutritionState.goals`).
    /// Older versions kept the nutrition aim here, apart from the sport goal. Still read (see `goal`), and
    /// now written along with the goal as the aim that goes with it, so it never contradicts it.
    var nutritionAim: NutritionAim?
    /// The goal the daily targets were last calculated or reviewed for. When the goal changes while some
    /// targets are the person's own, Nutrition proposes the new calculation instead of applying it.
    var targetsGoal: FitnessGoal?
    /// The activity level chosen for the calculation (older versions: set by « Calculer pour moi »).
    var calculatedActivity: NutritionCalculator.Activity?
    /// Whether the daily targets follow the calculation (body, aim, activity). Nil: decided by what an
    /// older version kept (calculated targets, or none yet: calculated; targets typed by hand: kept).
    var nutritionAuto: Bool?
    /// Targets typed by hand while the others follow the calculation: never replaced by it.
    var customTargets: Set<NutritionTarget> = []
    /// The weight goal (target, dates, accepted calories), nil until the user sets one.
    var weightPlan: WeightPlan?
    /// The situation that makes the weight calculation more careful. Nil = never asked: read as « préfère
    /// ne pas répondre » (no loss or gain calculated, maintenance only) until the user answers.
    var lifeStage: LifeStage?

    // Money (the monthly budget is `BudgetState.monthlyBudget`).
    var monthlyIncome: Double?
    var monthlySavingsGoal: Double?
    var mainExpenses: [String] = []

    // Productivity (the weekly focus goal is `ProductivityState.weeklyFocusGoalHours`).
    var mainGoal = ""
    var dailyWorkHours: Double?

    // Business (the activity and the monthly goal are in `BusinessState`).
    var businessClients: Int?

    // Studies.
    var studyField = ""
    var weeklyStudyHours: Double?

    var provided: Set<ProvidedFact> = []
    /// Values already changed in a space before « Mes informations » existed have been taken over.
    var migrated = false

    enum CodingKeys: String, CodingKey {
        case lastName, interests, skippedTopics, birthYear, heightCm, weightKg, weightLog, sex, genderDetail, calculationSex
        case fitnessGoal, fitnessLevel, stepGoal
        case nutritionAim, calculatedActivity, nutritionAuto, customTargets, monthlyIncome, monthlySavingsGoal, mainExpenses, mainGoal, dailyWorkHours
        case businessClients, studyField, weeklyStudyHours, provided, migrated
        case weightPlan, lifeStage, targetsGoal, goalFocus
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastName = c.value(.lastName, "")
        // An interest or a topic a newer version added is dropped rather than failing the whole profile.
        interests = c.value(.interests, [String]()).compactMap(Interest.init(rawValue:))
        skippedTopics = c.value(.skippedTopics, [String]()).compactMap(ProfileTopic.init(rawValue:))
        birthYear = c.optional(.birthYear)
        heightCm = c.optional(.heightCm)
        weightKg = c.optional(.weightKg)
        weightLog = c.value(.weightLog, [])
        sex = c.optional(.sex)
        genderDetail = c.value(.genderDetail, "")
        calculationSex = c.optional(.calculationSex)
        fitnessGoal = c.optional(.fitnessGoal)
        fitnessLevel = c.optional(.fitnessLevel)
        stepGoal = c.optional(.stepGoal)
        nutritionAim = c.optional(.nutritionAim)
        calculatedActivity = c.optional(.calculatedActivity)
        nutritionAuto = c.optional(.nutritionAuto)
        customTargets = Set(c.value(.customTargets, [String]()).compactMap(NutritionTarget.init(rawValue:)))
        monthlyIncome = c.optional(.monthlyIncome)
        monthlySavingsGoal = c.optional(.monthlySavingsGoal)
        mainExpenses = c.value(.mainExpenses, [])
        mainGoal = c.value(.mainGoal, "")
        dailyWorkHours = c.optional(.dailyWorkHours)
        businessClients = c.optional(.businessClients)
        studyField = c.value(.studyField, "")
        weeklyStudyHours = c.optional(.weeklyStudyHours)
        provided = Set(c.value(.provided, [String]()).compactMap(ProvidedFact.init(rawValue:)))
        migrated = c.value(.migrated, false)
        weightPlan = c.optional(.weightPlan)
        lifeStage = c.optional(.lifeStage)
        targetsGoal = c.optional(.targetsGoal)
        goalFocus = c.optional(.goalFocus)
    }

    /// The one goal of the person, for Sport and Nutrition. An account that has only one of the two older
    /// fields keeps it; both agreeing: the sport goal (more precise); both contradicting: the nutrition aim,
    /// as the calculation always read it, until the person chooses their goal again.
    var goal: FitnessGoal? {
        switch (fitnessGoal, nutritionAim) {
        case (nil, nil): nil
        case let (goal?, nil): goal
        case let (nil, aim?): FitnessGoal.from(aim)
        case let (goal?, aim?): goal.nutritionAim == aim ? goal : FitnessGoal.from(aim)
        }
    }

    /// The loss, maintaining or gain of the goal (what the weight goal and the safety rules read).
    var aim: NutritionAim? { goal?.nutritionAim }

    /// The calculation whose protein a plan of this aim uses: the real goal (sèche 2,2 g/kg, prise de masse…)
    /// when it goes the same way as the plan, else the plain loss, maintaining or gain.
    func macroGoal(for aim: NutritionAim) -> NutritionCalculator.Goal {
        if let goal, goal.nutritionAim == aim { return goal.calculatorGoal }
        return aim.calculatorGoal
    }

    /// Whether « enceinte ou allaitante ? » is asked: for any goal of loss or gain, wherever it was chosen
    /// (Sport or Nutrition), and not of a man.
    var asksLifeStage: Bool { (aim == .lose || aim == .gain) && sex != .male }

    /// Chooses the goal for both Sport and Nutrition (nil takes it back); the older aim follows it.
    mutating func setGoal(_ goal: FitnessGoal?) {
        if goal != self.goal { goalFocus = nil }
        fitnessGoal = goal
        nutritionAim = goal?.nutritionAim
    }

    /// Under 18, from the birthday (exact) or the birth year (one year is taken off the age, which can be
    /// one too high) or the situation chosen.
    func isMinor(birthday: Date? = nil, now: Date = Date()) -> Bool {
        if lifeStage == .minor { return true }
        guard let years = age(birthday: birthday, now: now) else { return false }
        return (birthday == nil ? years - 1 : years) < 18
    }

    var isMinor: Bool { isMinor(birthday: nil, now: Date()) }

    func knows(_ fact: ProvidedFact) -> Bool { provided.contains(fact) }

    /// Whether the daily nutrition targets follow the calculation.
    var followsNutritionCalculation: Bool {
        nutritionAuto ?? (calculatedActivity != nil || !knows(.kcalTarget))
    }

    /// The reference for the calorie formula: the gender itself when binary, else the chosen reference or the average.
    var calculatorSex: NutritionCalculator.Sex? {
        guard let sex else { return nil }
        return sex.isBinary ? sex.calculatorSex : (calculationSex ?? .neutral)
    }

    /// Sets the weight and keeps it in the history (one value a day).
    mutating func recordWeight(_ kilograms: Double?, at date: Date = Date()) {
        weightKg = kilograms.flatMap { $0 > 0 ? $0 : nil }
        guard let weightKg else { return }
        weightLog.removeAll { DateMath.isSameDay($0.date, date) }
        weightLog.append(ValuePoint(date: date, value: weightKg))
        weightLog.sort { $0.date < $1.date }
        if weightLog.count > 730 { weightLog.removeFirst(weightLog.count - 730) }
    }

    /// The weights of a period, oldest first; the current weight counts for today when nothing was logged.
    func weights(from start: Date, to end: Date) -> [ValuePoint] {
        var points = weightLog.filter { $0.date >= DateMath.startOfDay(start) && $0.date <= end }
        if points.isEmpty, let weightKg, weightLog.isEmpty { points = [ValuePoint(date: end, value: weightKg)] }
        return points
    }

    /// Age in whole years, from the birthday when known (exact), else from the birth year.
    func age(birthday: Date?, now: Date = Date()) -> Int? {
        if let birthday {
            return DateMath.calendar.dateComponents([.year], from: birthday, to: now).year
        }
        guard let birthYear else { return nil }
        return DateMath.calendar.component(.year, from: now) - birthYear
    }

    /// The date « Ajouter ma date de naissance » starts from: 1 January of the birth year already given (so the
    /// age the calculations use does not move), else 1 January 2000.
    var startingBirthday: Date {
        let year = DateMath.calendar.component(.year, from: Date())
        if let birthYear, birthYear >= 1900, birthYear <= year { return Holidays.make(birthYear, 1, 1) }
        return Holidays.make(2000, 1, 1)
    }

    /// The topics to ask about or show, in the order the interests were picked, without repeats.
    var topics: [ProfileTopic] {
        var seen = Set<ProfileTopic>()
        return interests.flatMap(\.topics).filter { seen.insert($0).inserted }
    }

    /// Spaces put forward first, in the order the interests were picked.
    var preferredSpaces: [Space] {
        var seen = Set<Space>()
        return interests.flatMap(\.spaces).filter { seen.insert($0).inserted }
    }

    /// Store categories put forward first.
    var preferredCategories: [WidgetCategory] {
        var seen = Set<WidgetCategory>()
        return interests.flatMap(\.categories).filter { seen.insert($0).inserted }
    }

    /// Everything first-launch examples need, for previews and review captures.
    static var sample: UserProfile {
        var profile = UserProfile()
        profile.interests = [.sport, .nutrition, .budget, .productivity]
        profile.birthYear = DateMath.calendar.component(.year, from: Date()) - 27
        profile.heightCm = 175
        profile.weightKg = 78
        // Ten weeks of weigh-ins, slowly going up (the goal is to gain muscle).
        for week in 0..<10 {
            // Whole days (noon), so the sample is the same after saving and reading back.
            let day = DateMath.calendar.date(byAdding: .day, value: -7 * (9 - week), to: DateMath.startOfDay(Date())) ?? Date()
            let date = day.addingTimeInterval(12 * 3600)
            let value = 76.4 + Double(week) * 0.18 + (week % 3 == 1 ? 0.2 : 0)
            profile.weightLog.append(ValuePoint(date: date, value: (value * 10).rounded() / 10))
        }
        profile.weightLog[profile.weightLog.count - 1].value = 78
        profile.sex = .male
        profile.fitnessGoal = .bulk
        profile.fitnessLevel = .intermediate
        profile.stepGoal = 10_000
        profile.nutritionAim = .gain
        profile.nutritionAuto = true
        profile.monthlyIncome = 3_000
        profile.monthlySavingsGoal = 400
        profile.mainGoal = tr("Finir le projet Ardane")
        profile.provided = Set(ProvidedFact.allCases)
        profile.migrated = true
        return profile
    }
}

extension UserProfile: StoredState { static var file: StoreFile { .profile } }

extension DomainData {
    /// Whether the user gave this value. Example data (no profile loaded) counts as given.
    func knows(_ fact: ProvidedFact) -> Bool {
        profile?.knows(fact) ?? true
    }

    /// Whether the body weight used by estimates is the user's own.
    var knowsWeight: Bool {
        profile.map { $0.weightKg != nil } ?? true
    }
}
