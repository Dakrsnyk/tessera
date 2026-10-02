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
    // Per 100 g, when the source gives them (nil: unknown, never shown as zero).
    var sugars: Double?
    var saturatedFat: Double?
    /// Milligrams.
    var sodiumMg: Double?
    /// Milligrams.
    var cholesterolMg: Double?

    var displayName: String {
        guard let brand, !brand.isEmpty else { return name }
        return "\(name) · \(brand)"
    }

    func nutrients(grams: Double) -> NutritionTotals {
        let factor = grams / 100
        return NutritionTotals(
            kcal: kcal * factor, protein: protein * factor, carbs: carbs * factor, fat: fat * factor, fiber: fiber * factor,
            sugars: sugars.map { $0 * factor }, saturatedFat: saturatedFat.map { $0 * factor },
            sodiumMg: sodiumMg.map { $0 * factor }, cholesterolMg: cholesterolMg.map { $0 * factor }
        )
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }

    /// Québec usage: déjeuner, dîner, souper.
    var title: String {
        switch self {
        case .breakfast: tr("Déjeuner")
        case .lunch: tr("Dîner")
        case .dinner: tr("Souper")
        case .snack: tr("Collation")
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
    // Known only for the foods whose source gives them: nil when no food eaten had the value.
    var sugars: Double? = nil
    var saturatedFat: Double? = nil
    var sodiumMg: Double? = nil
    var cholesterolMg: Double? = nil

    private static func add(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case (nil, nil): nil
        default: (a ?? 0) + (b ?? 0)
        }
    }

    static func + (lhs: NutritionTotals, rhs: NutritionTotals) -> NutritionTotals {
        NutritionTotals(
            kcal: lhs.kcal + rhs.kcal, protein: lhs.protein + rhs.protein, carbs: lhs.carbs + rhs.carbs, fat: lhs.fat + rhs.fat, fiber: lhs.fiber + rhs.fiber,
            sugars: add(lhs.sugars, rhs.sugars), saturatedFat: add(lhs.saturatedFat, rhs.saturatedFat),
            sodiumMg: add(lhs.sodiumMg, rhs.sodiumMg), cholesterolMg: add(lhs.cholesterolMg, rhs.cholesterolMg)
        )
    }
}

struct NutritionGoals: Codable, Hashable {
    var kcal: Double = 2_200
    var protein: Double = 130
    var carbs: Double = 250
    var fat: Double = 70
    var fiber: Double = 30
    /// Daily limits (not targets): the usual public-health guides, changeable by the person.
    var sugarsMax: Double = 50
    var saturatedFatMax: Double = 20
    var sodiumMaxMg: Double = 2_300

    init(kcal: Double = 2_200, protein: Double = 130, carbs: Double = 250, fat: Double = 70, fiber: Double = 30,
         sugarsMax: Double = 50, saturatedFatMax: Double = 20, sodiumMaxMg: Double = 2_300) {
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugarsMax = sugarsMax
        self.saturatedFatMax = saturatedFatMax
        self.sodiumMaxMg = sodiumMaxMg
    }

    enum CodingKeys: String, CodingKey { case kcal, protein, carbs, fat, fiber, sugarsMax, saturatedFatMax, sodiumMaxMg }

    /// Tolerant: goals saved before the limits existed keep their values.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = NutritionGoals()
        kcal = c.value(.kcal, d.kcal)
        protein = c.value(.protein, d.protein)
        carbs = c.value(.carbs, d.carbs)
        fat = c.value(.fat, d.fat)
        fiber = c.value(.fiber, d.fiber)
        sugarsMax = c.value(.sugarsMax, d.sugarsMax)
        saturatedFatMax = c.value(.saturatedFatMax, d.saturatedFatMax)
        sodiumMaxMg = c.value(.sodiumMaxMg, d.sodiumMaxMg)
    }
}

/// A meal kept by the person to log again in one tap (« Mes repas »).
struct SavedMeal: Codable, Hashable, Identifiable {
    struct Item: Codable, Hashable {
        var food: FoodItem
        var grams: Double
    }

    var id = UUID()
    var name: String
    var items: [Item]
    var createdAt = Date()

    var totals: NutritionTotals { items.reduce(NutritionTotals()) { $0 + $1.food.nutrients(grams: $1.grams) } }

    init(name: String, items: [Item]) {
        self.name = name
        self.items = items
    }

    enum CodingKeys: String, CodingKey { case id, name, items, createdAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID())
        name = c.value(.name, tr("Mon repas"))
        items = c.value(.items, [])
        createdAt = c.value(.createdAt, Date())
    }
}

struct NutritionState: Codable, Hashable {
    var goals = NutritionGoals()
    var entries: [FoodEntry] = []
    var favorites: [FoodItem] = []
    var customFoods: [FoodItem] = []
    var recentFoods: [FoodItem] = []
    var savedMeals: [SavedMeal] = []

    enum CodingKeys: String, CodingKey { case goals, entries, favorites, customFoods, recentFoods, savedMeals }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goals = c.value(.goals, NutritionGoals())
        entries = c.value(.entries, [])
        favorites = c.value(.favorites, [])
        customFoods = c.value(.customFoods, [])
        recentFoods = c.value(.recentFoods, [])
        savedMeals = c.value(.savedMeals, [])
    }

    mutating func log(_ food: FoodItem, grams: Double, meal: MealType, at date: Date = Date()) {
        entries.append(FoodEntry(date: date, meal: meal, food: food, grams: grams))
        recentFoods.removeAll { $0.id == food.id }
        recentFoods.insert(food, at: 0)
        if recentFoods.count > 20 { recentFoods.removeLast(recentFoods.count - 20) }
        let cutoff = date.addingTimeInterval(-400 * 86_400)
        entries.removeAll { $0.date < cutoff }
    }

    /// The same food, another quantity or another meal.
    mutating func updateEntry(_ id: UUID, grams: Double? = nil, meal: MealType? = nil) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        if let grams, grams > 0 { entries[index].grams = grams }
        if let meal { entries[index].meal = meal }
    }

    mutating func deleteEntry(_ id: UUID) {
        entries.removeAll { $0.id == id }
    }

    /// Logs every food of a saved meal (or of an earlier meal) into one meal of a day.
    mutating func log(_ items: [SavedMeal.Item], meal: MealType, on day: Date, at now: Date = Date()) {
        let date = NutritionMath.entryDate(for: meal, on: day, now: now)
        for item in items where item.grams > 0 {
            log(item.food, grams: item.grams, meal: meal, at: date)
        }
    }

    /// Keeps a meal of a day under a name, to log it again later.
    @discardableResult
    mutating func saveMeal(_ meal: MealType, on day: Date, name: String) -> SavedMeal? {
        let items = NutritionMath.entries(self, on: day).filter { $0.meal == meal }.map { SavedMeal.Item(food: $0.food, grams: $0.grams) }
        guard !items.isEmpty else { return nil }
        let saved = SavedMeal(name: name.trimmed.isEmpty ? meal.title : name.trimmed, items: items)
        savedMeals.insert(saved, at: 0)
        return saved
    }

    mutating func toggleFavorite(_ food: FoodItem) {
        if favorites.contains(where: { $0.id == food.id }) {
            favorites.removeAll { $0.id == food.id }
        } else {
            favorites.insert(food, at: 0)
        }
    }

    func isFavorite(_ food: FoodItem) -> Bool { favorites.contains { $0.id == food.id } }
}

enum NutritionMath {
    /// The time a new entry gets on a day: now for today, else a usual time for the meal,
    /// so a food added to yesterday's dinner is counted on yesterday.
    static func entryDate(for meal: MealType, on day: Date, now: Date = Date()) -> Date {
        if DateMath.isSameDay(day, now) { return now }
        let hour: Int = switch meal {
        case .breakfast: 8
        case .lunch: 12
        case .dinner: 19
        case .snack: 16
        }
        return DateMath.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

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

    /// Calories suggested for the next meal: what's left, split across the main meals still ahead
    /// that have nothing logged yet.
    static func nextMealBudget(_ state: NutritionState, at date: Date) -> (meal: MealType, kcal: Double, protein: Double)? {
        guard let first = MealType.next(after: date) else { return nil }
        let logged = Set(entries(state, on: date).map(\.meal))
        let mainMeals: [MealType] = [.breakfast, .lunch, .dinner]
        let ahead = mainMeals.drop(while: { $0 != first }).filter { !logged.contains($0) }
        guard let meal = ahead.first else { return nil }
        let today = totals(state, on: date)
        let remainingKcal = max(0, state.goals.kcal - today.kcal)
        let remainingProtein = max(0, state.goals.protein - today.protein)
        let mealsLeft = Double(ahead.count)
        return (meal, remainingKcal / mealsLeft, remainingProtein / mealsLeft)
    }
}

extension NutritionMath {
    /// A meal eaten on an earlier day, offered to log again.
    struct PastMeal: Identifiable, Hashable {
        var day: Date
        var meal: MealType
        var items: [SavedMeal.Item]
        var id: String { "\(DateMath.dayKey(day))-\(meal.rawValue)" }
        var totals: NutritionTotals { items.reduce(NutritionTotals()) { $0 + $1.food.nutrients(grams: $1.grams) } }
        var summary: String { items.map(\.food.name).joined(separator: ", ") }
    }

    /// The last meals of a kind before a day, most recent first, each day once, identical meals once.
    static func previousMeals(_ meal: MealType, _ state: NutritionState, before day: Date, limit: Int = 5) -> [PastMeal] {
        let start = DateMath.startOfDay(day)
        let byDay = Dictionary(grouping: state.entries.filter { $0.meal == meal && $0.date < start }) { DateMath.dayKey($0.date) }
        var seen = Set<[String]>()
        var result: [PastMeal] = []
        for key in byDay.keys.sorted(by: >) {
            guard let entries = byDay[key]?.sorted(by: { $0.date < $1.date }), let first = entries.first else { continue }
            let signature = entries.map { "\($0.food.id)@\(Int($0.grams))" }
            guard seen.insert(signature).inserted else { continue }
            result.append(PastMeal(day: first.date, meal: meal, items: entries.map { SavedMeal.Item(food: $0.food, grams: $0.grams) }))
            if result.count >= limit { break }
        }
        return result
    }

    /// A nutrient known for only part of what was eaten.
    struct Coverage: Hashable {
        var known: Int
        var total: Int
        var isComplete: Bool { known == total }
    }

    static func coverage(_ entries: [FoodEntry], _ value: KeyPath<FoodItem, Double?>) -> Coverage {
        Coverage(known: entries.filter { $0.food[keyPath: value] != nil }.count, total: entries.count)
    }

    // MARK: Periods

    struct PeriodStats: Hashable {
        /// Every day of the period, oldest first.
        var days: [Date]
        /// Calories per day (0 for a day without entries).
        var kcalPerDay: [Double]
        /// Days with at least one entry.
        var trackedDays: Int
        var averages: NutritionTotals
        /// Tracked days within 10 % of the calorie goal.
        var daysOnTarget: Int
        var goal: Double
    }

    /// Averages over the tracked days of a period (a day without anything logged isn't a zero day).
    static func stats(_ state: NutritionState, from start: Date, to end: Date) -> PeriodStats {
        var days: [Date] = []
        var cursor = DateMath.startOfDay(start)
        let last = DateMath.startOfDay(end)
        while cursor <= last, days.count < 400 {
            days.append(cursor)
            guard let next = DateMath.calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        let dayTotals = days.map { NutritionMath.totals(state, on: $0) }
        let tracked = zip(days, dayTotals).filter { pair in !NutritionMath.entries(state, on: pair.0).isEmpty }.map { $0.1 }
        let count = Double(max(tracked.count, 1))
        let sum = tracked.reduce(NutritionTotals()) { $0 + $1 }
        let averages = NutritionTotals(kcal: sum.kcal / count, protein: sum.protein / count, carbs: sum.carbs / count, fat: sum.fat / count, fiber: sum.fiber / count)
        let goal = state.goals.kcal
        let onTarget = tracked.filter { goal > 0 && abs($0.kcal - goal) <= goal * 0.1 }.count
        return PeriodStats(days: days, kcalPerDay: dayTotals.map { $0.kcal }, trackedDays: tracked.count, averages: averages, daysOnTarget: onTarget, goal: goal)
    }

    // MARK: Ideas

    /// What is left for the day, only from the person's own targets.
    struct Remaining: Hashable {
        var kcal: Double?
        var protein: Double?
        var fiber: Double?
    }

    static func remaining(_ state: NutritionState, on day: Date, knowsKcal: Bool, knowsProtein: Bool) -> Remaining {
        let today = totals(state, on: day)
        return Remaining(
            kcal: knowsKcal ? state.goals.kcal - today.kcal : nil,
            protein: knowsProtein ? state.goals.protein - today.protein : nil,
            fiber: state.goals.fiber - today.fiber
        )
    }

    struct Idea: Identifiable, Hashable {
        var food: FoodItem
        var grams: Double
        var id: String { food.id }
        var totals: NutritionTotals { food.nutrients(grams: grams) }
    }

    /// Foods of the built-in table rich in protein per calorie, at a usual portion that fits what is left.
    static func proteinIdeas(within kcal: Double?, limit: Int = 6) -> [Idea] {
        ideas(sortedBy: { $0.protein / max($0.kcal, 1) }, minimum: { $0.protein >= 8 }, within: kcal, limit: limit)
    }

    /// Foods rich in fibre per calorie.
    static func fiberIdeas(within kcal: Double?, limit: Int = 6) -> [Idea] {
        ideas(sortedBy: { $0.fiber / max($0.kcal, 1) }, minimum: { $0.fiber >= 2.5 }, within: kcal, limit: limit)
    }

    /// Dishes whose usual portion fits the calories left (between 60 % and 100 % of them).
    static func mealIdeas(for kcal: Double, limit: Int = 6) -> [Idea] {
        FoodDatabase.foods(in: .dishes)
            .map { Idea(food: $0, grams: $0.servingGrams) }
            .filter { $0.totals.kcal <= kcal && $0.totals.kcal >= kcal * 0.45 }
            .sorted { $0.totals.protein > $1.totals.protein }
            .prefix(limit)
            .map { $0 }
    }

    private static func ideas(sortedBy score: (FoodItem) -> Double, minimum: (FoodItem) -> Bool, within kcal: Double?, limit: Int) -> [Idea] {
        FoodDatabase.all
            .filter { minimum($0) && FoodDatabase.category(of: $0) != .drinks }
            .map { Idea(food: $0, grams: $0.servingGrams) }
            .filter { kcal == nil || $0.totals.kcal <= max(kcal ?? 0, 0) }
            .sorted { score($0.food) > score($1.food) }
            .prefix(limit)
            .map { $0 }
    }
}

/// Estimates daily needs (Mifflin-St Jeor) to suggest a starting goal the user can adjust.
enum NutritionCalculator {
    /// The reference used by the formula. `neutral` averages the two (for non-binary people or when the
    /// user prefers not to say): the result sits between the female and male estimates.
    enum Sex: String, Codable, CaseIterable, Identifiable {
        case female, male, neutral
        var id: String { rawValue }

        var offset: Double {
            switch self {
            case .female: -161
            case .male: 5
            case .neutral: -78
            }
        }

        var title: String {
            switch self {
            case .female: tr("Femme")
            case .male: tr("Homme")
            case .neutral: tr("Moyenne des deux")
            }
        }
    }
    enum Activity: Double, Codable, CaseIterable, Identifiable {
        case sedentary = 1.2, light = 1.375, moderate = 1.55, active = 1.725
        var id: Double { rawValue }
        var title: String {
            switch self {
            case .sedentary: tr("Sédentaire")
            case .light: tr("Légère (1–3 séances)")
            case .moderate: tr("Modérée (3–5 séances)")
            case .active: tr("Élevée (6–7 séances)")
            }
        }
    }
    enum Goal: Double, CaseIterable, Identifiable {
        case lose = -0.15, maintain = 0, gain = 0.1
        var id: Double { rawValue }
        var title: String {
            switch self {
            case .lose: tr("Perdre doucement")
            case .maintain: tr("Maintenir")
            case .gain: tr("Prendre du muscle")
            }
        }
    }

    static func goals(sex: Sex, age: Int, heightCm: Double, weightKg: Double, activity: Activity, goal: Goal) -> NutritionGoals {
        let base: Double = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + sex.offset
        let kcal = max(1_400, (base * activity.rawValue * (1 + goal.rawValue)).rounded())
        let protein = (weightKg * (goal == .gain ? 2.0 : 1.6)).rounded()
        let fat = (kcal * 0.28 / 9).rounded()
        let carbs = max(0, ((kcal - protein * 4 - fat * 9) / 4).rounded())
        return NutritionGoals(kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: 30)
    }
}
