import Foundation

enum FoodSource: String, Codable, Hashable {
    case builtin, openFoodFacts, custom
}

/// Nutrition values are per 100 g (or 100 ml).
struct FoodItem: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var brand: String?
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var servingGrams: Double
    var servingName: String
    var source: FoodSource
    var barcode: String?

    var displayName: String {
        guard let brand, !brand.isEmpty else { return name }
        return "\(name) · \(brand)"
    }

    func nutrients(grams: Double) -> NutritionTotals {
        let factor = grams / 100
        return NutritionTotals(kcal: kcal * factor, protein: protein * factor, carbs: carbs * factor, fat: fat * factor, fiber: fiber * factor)
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }

    /// Québec usage: déjeuner, dîner, souper.
    var title: String {
        switch self {
        case .breakfast: "Déjeuner"
        case .lunch: "Dîner"
        case .dinner: "Souper"
        case .snack: "Collation"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "moon.stars"
        case .snack: "carrot"
        }
    }

    /// The meal a new entry most likely belongs to at this time of day.
    static func current(at date: Date = Date()) -> MealType {
        let hour = DateMath.calendar.component(.hour, from: date)
        switch hour {
        case 4..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default: return .snack
        }
    }

    /// The next main meal still ahead today.
    static func next(after date: Date = Date()) -> MealType? {
        let hour = DateMath.calendar.component(.hour, from: date)
        switch hour {
        case ..<10: return .breakfast
        case 10..<14: return .lunch
        case 14..<20: return .dinner
        default: return nil
        }
    }
}

struct FoodEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var meal: MealType
    var food: FoodItem
    var grams: Double

    var totals: NutritionTotals { food.nutrients(grams: grams) }
}

struct NutritionTotals: Hashable {
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var fiber: Double = 0

    static func + (lhs: NutritionTotals, rhs: NutritionTotals) -> NutritionTotals {
        NutritionTotals(kcal: lhs.kcal + rhs.kcal, protein: lhs.protein + rhs.protein, carbs: lhs.carbs + rhs.carbs, fat: lhs.fat + rhs.fat, fiber: lhs.fiber + rhs.fiber)
    }
}

struct NutritionGoals: Codable, Hashable {
    var kcal: Double = 2_200
    var protein: Double = 130
    var carbs: Double = 250
    var fat: Double = 70
    var fiber: Double = 30
}

struct NutritionState: Codable, Hashable {
    var goals = NutritionGoals()
    var entries: [FoodEntry] = []
    var favorites: [FoodItem] = []
    var customFoods: [FoodItem] = []
    var recentFoods: [FoodItem] = []

    enum CodingKeys: String, CodingKey { case goals, entries, favorites, customFoods, recentFoods }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goals = c.value(.goals, NutritionGoals())
        entries = c.value(.entries, [])
        favorites = c.value(.favorites, [])
        customFoods = c.value(.customFoods, [])
        recentFoods = c.value(.recentFoods, [])
    }

    mutating func log(_ food: FoodItem, grams: Double, meal: MealType, at date: Date = Date()) {
        entries.append(FoodEntry(date: date, meal: meal, food: food, grams: grams))
        recentFoods.removeAll { $0.id == food.id }
        recentFoods.insert(food, at: 0)
        if recentFoods.count > 20 { recentFoods.removeLast(recentFoods.count - 20) }
        let cutoff = date.addingTimeInterval(-120 * 86_400)
        entries.removeAll { $0.date < cutoff }
    }
}

enum NutritionMath {
    static func entries(_ state: NutritionState, on day: Date) -> [FoodEntry] {
        state.entries.filter { DateMath.isSameDay($0.date, day) }.sorted { $0.date < $1.date }
    }

    static func totals(_ state: NutritionState, on day: Date) -> NutritionTotals {
        entries(state, on: day).reduce(NutritionTotals()) { $0 + $1.totals }
    }

    static func totals(of meal: MealType, _ state: NutritionState, on day: Date) -> NutritionTotals {
        entries(state, on: day).filter { $0.meal == meal }.reduce(NutritionTotals()) { $0 + $1.totals }
    }

    /// Calories per day for the last `days` days, oldest first (today last).
    static func dailyCalories(_ state: NutritionState, days: Int, until date: Date) -> [Double] {
        (0..<days).reversed().map { offset in
            let day = DateMath.calendar.date(byAdding: .day, value: -offset, to: date) ?? date
            return totals(state, on: day).kcal
        }
    }

    /// Average over the days that have at least one entry (skipping untracked days).
    static func average(_ state: NutritionState, days: Int, until date: Date) -> Double? {
        let tracked = dailyCalories(state, days: days, until: date).filter { $0 > 0 }
        return tracked.isEmpty ? nil : Stats.average(tracked)
    }

    /// Consecutive days with at least one logged meal, ending today (or yesterday).
    static func trackingStreak(_ state: NutritionState, until date: Date) -> Int {
        let keys = Set(state.entries.map { DateMath.dayKey($0.date) })
        var day = keys.contains(DateMath.dayKey(date)) ? date : DateMath.calendar.date(byAdding: .day, value: -1, to: date) ?? date
        var count = 0
        while keys.contains(DateMath.dayKey(day)) {
            count += 1
            guard let previous = DateMath.calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// Calories suggested for the next meal: what's left, split across the main meals still ahead.
    static func nextMealBudget(_ state: NutritionState, at date: Date) -> (meal: MealType, kcal: Double, protein: Double)? {
        guard let meal = MealType.next(after: date) else { return nil }
        let today = totals(state, on: date)
        let remainingKcal = max(0, state.goals.kcal - today.kcal)
        let remainingProtein = max(0, state.goals.protein - today.protein)
        let mealsLeft: Double
        switch meal {
        case .breakfast: mealsLeft = 3
        case .lunch: mealsLeft = 2
        default: mealsLeft = 1
        }
        return (meal, remainingKcal / mealsLeft, remainingProtein / mealsLeft)
    }
}

/// Estimates daily needs (Mifflin-St Jeor) to suggest a starting goal the user can adjust.
enum NutritionCalculator {
    enum Sex: String, CaseIterable, Identifiable { case female, male; var id: String { rawValue } }
    enum Activity: Double, CaseIterable, Identifiable {
        case sedentary = 1.2, light = 1.375, moderate = 1.55, active = 1.725
        var id: Double { rawValue }
        var title: String {
            switch self {
            case .sedentary: "Sédentaire"
            case .light: "Légère (1–3 séances)"
            case .moderate: "Modérée (3–5 séances)"
            case .active: "Élevée (6–7 séances)"
            }
        }
    }
    enum Goal: Double, CaseIterable, Identifiable {
        case lose = -0.15, maintain = 0, gain = 0.1
        var id: Double { rawValue }
        var title: String {
            switch self {
            case .lose: "Perdre doucement"
            case .maintain: "Maintenir"
            case .gain: "Prendre du muscle"
            }
        }
    }

    static func goals(sex: Sex, age: Int, heightCm: Double, weightKg: Double, activity: Activity, goal: Goal) -> NutritionGoals {
        let sexOffset: Double = sex == .male ? 5 : -161
        let base: Double = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + sexOffset
        let kcal = max(1_400, (base * activity.rawValue * (1 + goal.rawValue)).rounded())
        let protein = (weightKg * (goal == .gain ? 2.0 : 1.6)).rounded()
        let fat = (kcal * 0.28 / 9).rounded()
        let carbs = max(0, ((kcal - protein * 4 - fat * 9) / 4).rounded())
        return NutritionGoals(kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: 30)
    }
}
