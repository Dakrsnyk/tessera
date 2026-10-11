import Foundation

// « Mes informations »: what the user tells Ardane about themselves, entered once and reused by every
// widget. Each fact has exactly one home. Most live here, in `UserProfile`; the ones a space already
// keeps (nutrition targets, weekly workouts, monthly budget…) stay in that space's data, and the profile
// only records that the user actually gave them, so a default value is never shown as theirs.

/// What the user is interested in, picked at the first launch. It decides which questions are asked and
/// what Ardane puts forward first, never what it hides.
enum Interest: String, Codable, CaseIterable, Identifiable {
    case sport, nutrition, finance, budget, business, studies, productivity, travel, car, weather, design, wellbeing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sport: tr("Sport")
        case .nutrition: tr("Nutrition")
        case .finance: tr("Finance")
        case .budget: tr("Budget")
        case .business: tr("Business")
        case .studies: tr("Études")
        case .productivity: tr("Productivité")
        case .travel: tr("Voyage")
        case .car: tr("Automobile")
        case .weather: tr("Météo")
        case .design: tr("Design")
        case .wellbeing: tr("Bien-être")
        }
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
        case .weather: "cloud.sun.fill"
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
        case .weather: "3B82F6"
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
        case .business: [.business]
        case .studies: [.student]
        case .productivity: [.productivity]
        case .travel: [.travel]
        case .car: [.car]
        case .weather: []
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
        case .business: [.business]
        case .studies: [.student]
        case .productivity: [.productivity]
        case .travel: [.travel]
        case .car: [.car]
        case .weather: [.weather]
        case .design: [.time]
        case .wellbeing: [.wellbeing]
        }
    }

    /// The questions it leads to (finance and budget share theirs). Nil when there is nothing worth asking.
    var topic: ProfileTopic? {
        switch self {
        case .sport: .sport
        case .nutrition: .nutrition
        case .finance, .budget: .money
        case .business: .business
        case .studies: .studies
        case .productivity: .productivity
        case .car: .car
        case .weather: .weather
        case .wellbeing: .wellbeing
        case .travel, .design: nil
        }
    }
}

/// A group of personal information: one page of questions, one card of « Mes informations ».
enum ProfileTopic: String, Codable, CaseIterable, Identifiable {
    case sport, nutrition, money, business, productivity, studies, car, weather, wellbeing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sport: tr("Sport")
        case .nutrition: tr("Nutrition")
        case .money: tr("Finances")
        case .business: tr("Business")
        case .productivity: tr("Productivité")
        case .studies: tr("Études")
        case .car: tr("Automobile")
        case .weather: tr("Météo")
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
        case .weather: "cloud.sun.fill"
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
        case .weather: "3B82F6"
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
        case .weather: tr("Ta ville, pour la météo de tes widgets.")
        case .wellbeing: tr("Ton objectif d'eau et une première habitude à suivre.")
        }
    }
}

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case bulk, weightLoss, cut, performance, maintain, strength, endurance
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
        }
    }

    /// The nutrition aim that goes with it, suggested when both are asked.
    var nutritionAim: NutritionAim {
        switch self {
        case .bulk, .strength: .gain
        case .weightLoss, .cut: .lose
        case .performance, .maintain, .endurance: .maintain
        }
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
    var fitnessGoal: FitnessGoal?
    var fitnessLevel: FitnessLevel?
    /// Steps a day, for « Mon Quotidien » (the steps come from the iPhone's motion sensor).
    var stepGoal: Int?

    // Nutrition (the daily targets are `NutritionState.goals`).
    var nutritionAim: NutritionAim?
    /// Set when the daily targets come from « Calculer pour moi » (with this activity): they then follow
    /// the weight, the age, the height, the aim… Typing a target by hand clears it.
    var calculatedActivity: NutritionCalculator.Activity?

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
        case nutritionAim, calculatedActivity, monthlyIncome, monthlySavingsGoal, mainExpenses, mainGoal, dailyWorkHours
        case businessClients, studyField, weeklyStudyHours, provided, migrated
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
    }

    func knows(_ fact: ProvidedFact) -> Bool { provided.contains(fact) }

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

    /// The topics to ask about or show, in the order the interests were picked, without repeats.
    var topics: [ProfileTopic] {
        var seen = Set<ProfileTopic>()
        return interests.compactMap(\.topic).filter { seen.insert($0).inserted }
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
