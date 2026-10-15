import Foundation

enum FoodSource: String, Codable, Hashable {
    /// `nutrientFile`: the Canadian Nutrient File bundled with the app (generic foods).
    case builtin, openFoodFacts, custom, nutrientFile
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
    /// Fats, minerals and vitamins per 100 g, when the source gives them (Canadian Nutrient File, Open
    /// Food Facts). Nil for foods saved before they were read.
    var micros: Micronutrients?

    var displayName: String {
        guard let brand, !brand.isEmpty else { return name }
        return "\(name) · \(brand)"
    }

    func nutrients(grams: Double) -> NutritionTotals {
        let factor = grams / 100
        return NutritionTotals(
            kcal: kcal * factor, protein: protein * factor, carbs: carbs * factor, fat: fat * factor, fiber: fiber * factor,
            sugars: sugars.map { $0 * factor }, saturatedFat: saturatedFat.map { $0 * factor },
            sodiumMg: sodiumMg.map { $0 * factor }, cholesterolMg: cholesterolMg.map { $0 * factor },
            micros: micros.map { $0.scaled(factor) } ?? Micronutrients()
        )
    }
}

/// Fats, minerals, vitamins and a few more (caffeine, alcohol): per 100 g on a food, per day on totals. A
/// value the source doesn't give stays nil, never a zero made up.
struct Micronutrients: Codable, Hashable {
    var monounsaturatedFat: Double?
    var polyunsaturatedFat: Double?
    var potassiumMg: Double?
    var calciumMg: Double?
    var ironMg: Double?
    var magnesiumMg: Double?
    var vitaminCMg: Double?
    /// Retinol activity equivalents (RAE).
    var vitaminAMcg: Double?
    var vitaminDMcg: Double?
    var vitaminB12Mcg: Double?
    /// Dietary folate equivalents (DFE).
    var folateMcg: Double?
    // Read since the nutrients of Premium: nil in the foods saved before.
    var transFat: Double?
    /// Every omega-3 fatty acid (alpha-linolenic, EPA, DHA…), grams.
    var omega3Fat: Double?
    /// Every omega-6 fatty acid (linoleic…), grams.
    var omega6Fat: Double?
    var zincMg: Double?
    var phosphorusMg: Double?
    var seleniumMcg: Double?
    var copperMg: Double?
    var manganeseMg: Double?
    /// Alpha-tocopherol.
    var vitaminEMg: Double?
    var vitaminKMcg: Double?
    /// Vitamin B1.
    var thiaminMg: Double?
    /// Vitamin B2.
    var riboflavinMg: Double?
    /// Vitamin B3, in niacin equivalents where the source gives them (Canadian Nutrient File).
    var niacinMg: Double?
    /// Vitamin B5.
    var pantothenicAcidMg: Double?
    var vitaminB6Mg: Double?
    var cholineMg: Double?
    var caffeineMg: Double?
    /// Grams of ethanol.
    var alcohol: Double?

    static let all: [WritableKeyPath<Micronutrients, Double?>] = [
        \.monounsaturatedFat, \.polyunsaturatedFat, \.potassiumMg, \.calciumMg, \.ironMg, \.magnesiumMg,
        \.vitaminCMg, \.vitaminAMcg, \.vitaminDMcg, \.vitaminB12Mcg, \.folateMcg,
        \.transFat, \.omega3Fat, \.omega6Fat, \.zincMg, \.phosphorusMg, \.seleniumMcg, \.copperMg, \.manganeseMg,
        \.vitaminEMg, \.vitaminKMcg, \.thiaminMg, \.riboflavinMg, \.niacinMg, \.pantothenicAcidMg, \.vitaminB6Mg,
        \.cholineMg, \.caffeineMg, \.alcohol,
    ]

    var isEmpty: Bool { Self.all.allSatisfy { self[keyPath: $0] == nil } }

    func scaled(_ factor: Double) -> Micronutrients {
        var copy = self
        for path in Self.all { copy[keyPath: path] = self[keyPath: path].map { $0 * factor } }
        return copy
    }

    static func + (lhs: Micronutrients, rhs: Micronutrients) -> Micronutrients {
        var sum = Micronutrients()
        for path in all {
            switch (lhs[keyPath: path], rhs[keyPath: path]) {
            case (nil, nil): sum[keyPath: path] = nil
            case let (a, b): sum[keyPath: path] = (a ?? 0) + (b ?? 0)
            }
        }
        return sum
    }
}

/// Every nutrient Ardane follows, in the order shown. Calories, protein, carbohydrates and fat are free;
/// every other one is Premium (`isPremium`): its values are kept either way and shown with Premium.
enum Nutrient: String, CaseIterable, Identifiable {
    case kcal, protein, carbs, fat, fiber
    case sugars, saturatedFat, transFat, cholesterol, sodium, caffeine, alcohol
    case monounsaturatedFat, polyunsaturatedFat, omega3, omega6
    case potassium, calcium, iron, magnesium, zinc, phosphorus, selenium, copper, manganese
    case vitaminA, vitaminC, vitaminD, vitaminE, vitaminK, thiamin, riboflavin, niacin, pantothenicAcid, vitaminB6, folate, vitaminB12, choline
    var id: String { rawValue }

    /// The sections they are shown in.
    enum Group: CaseIterable {
        case energy, limits, fats, minerals, vitamins

        var title: String {
            switch self {
            case .energy: tr("Objectifs")
            case .limits: tr("À limiter")
            case .fats: tr("Acides gras")
            case .minerals: tr("Minéraux")
            case .vitamins: tr("Vitamines")
            }
        }

        var nutrients: [Nutrient] { Nutrient.allCases.filter { $0.group == self } }
    }

    var group: Group {
        switch self {
        case .kcal, .protein, .carbs, .fat, .fiber: .energy
        case .sugars, .saturatedFat, .transFat, .cholesterol, .sodium, .caffeine, .alcohol: .limits
        case .monounsaturatedFat, .polyunsaturatedFat, .omega3, .omega6: .fats
        case .potassium, .calcium, .iron, .magnesium, .zinc, .phosphorus, .selenium, .copper, .manganese: .minerals
        default: .vitamins
        }
    }

    /// The four free ones.
    static let free: [Nutrient] = [.kcal, .protein, .carbs, .fat]

    var isPremium: Bool { !Self.free.contains(self) }

    /// Its daily target (« Mes infos »), when a recognized reference gives one.
    var target: NutritionTarget? { NutritionTarget(rawValue: rawValue) }

    var title: String {
        switch self {
        case .kcal: tr("Calories")
        case .protein: tr("Protéines")
        case .carbs: tr("Glucides")
        case .fat: tr("Lipides")
        case .fiber: tr("Fibres")
        case .sugars: tr("Sucres")
        case .saturatedFat: tr("Gras saturés")
        case .transFat: tr("Gras trans")
        case .cholesterol: tr("Cholestérol")
        case .sodium: tr("Sodium")
        case .caffeine: tr("Caféine")
        case .alcohol: tr("Alcool")
        case .monounsaturatedFat: tr("Gras monoinsaturés")
        case .polyunsaturatedFat: tr("Gras polyinsaturés")
        case .omega3: tr("Oméga-3")
        case .omega6: tr("Oméga-6")
        case .potassium: tr("Potassium")
        case .calcium: tr("Calcium")
        case .iron: tr("Fer")
        case .magnesium: tr("Magnésium")
        case .zinc: tr("Zinc")
        case .phosphorus: tr("Phosphore")
        case .selenium: tr("Sélénium")
        case .copper: tr("Cuivre")
        case .manganese: tr("Manganèse")
        case .vitaminA: tr("Vitamine A")
        case .vitaminC: tr("Vitamine C")
        case .vitaminD: tr("Vitamine D")
        case .vitaminE: tr("Vitamine E")
        case .vitaminK: tr("Vitamine K")
        case .thiamin: tr("Thiamine (B1)")
        case .riboflavin: tr("Riboflavine (B2)")
        case .niacin: tr("Niacine (B3)")
        case .pantothenicAcid: tr("Acide pantothénique (B5)")
        case .vitaminB6: tr("Vitamine B6")
        case .folate: tr("Folates (B9)")
        case .vitaminB12: tr("Vitamine B12")
        case .choline: tr("Choline")
        }
    }

    var unit: String {
        switch self {
        case .kcal: "kcal"
        case .protein, .carbs, .fat, .fiber, .sugars, .saturatedFat, .transFat, .alcohol,
             .monounsaturatedFat, .polyunsaturatedFat, .omega3, .omega6: "g"
        case .vitaminA, .vitaminD, .vitaminK, .folate, .vitaminB12, .selenium: "µg"
        default: "mg"
        }
    }

    /// Decimals worth showing (2,4 µg of B12, 1,2 mg of thiamin, 13 mg of iron, 2 100 kcal).
    var decimals: Int {
        switch self {
        case .vitaminB12, .vitaminD, .transFat, .omega3, .copper, .manganese, .thiamin, .riboflavin, .vitaminB6: 1
        default: 0
        }
    }

    /// « 13 », « 2,4 »: the number alone.
    func number(_ value: Double) -> String {
        decimals > 0 ? TF.decimal(value, decimals) : TF.int(value)
    }

    /// « 13 mg », « 2,4 µg ».
    func format(_ value: Double) -> String {
        "\(number(value)) \(unit)"
    }

    /// An amount of one food: a few more decimals for the small ones (« 0,08 mg », « 1,4 g »).
    func formatAmount(_ value: Double) -> String {
        guard self != .kcal else { return format(value) }
        let digits = value == 0 ? 0 : (value < 1 ? 2 : (value < 10 ? 1 : decimals))
        return "\(digits > 0 ? TF.decimal(value, digits) : TF.int(value)) \(unit)"
    }

    /// What foods add up to, nil when no food gave the value.
    func value(in totals: NutritionTotals) -> Double? {
        switch self {
        case .kcal: totals.kcal
        case .protein: totals.protein
        case .carbs: totals.carbs
        case .fat: totals.fat
        case .fiber: totals.fiber
        case .sugars: totals.sugars
        case .saturatedFat: totals.saturatedFat
        case .cholesterol: totals.cholesterolMg
        case .sodium: totals.sodiumMg
        default: microsPath.flatMap { totals.micros[keyPath: $0] }
        }
    }

    /// The value on a food (per 100 g), to know whether a day's total is complete. Nil for the ones every
    /// food has.
    var foodPath: KeyPath<FoodItem, Double?>? {
        switch self {
        case .kcal, .protein, .carbs, .fat, .fiber: nil
        case .sugars: \.sugars
        case .saturatedFat: \.saturatedFat
        case .cholesterol: \.cholesterolMg
        case .sodium: \.sodiumMg
        case .transFat: \.micros?.transFat
        case .caffeine: \.micros?.caffeineMg
        case .alcohol: \.micros?.alcohol
        case .monounsaturatedFat: \.micros?.monounsaturatedFat
        case .polyunsaturatedFat: \.micros?.polyunsaturatedFat
        case .omega3: \.micros?.omega3Fat
        case .omega6: \.micros?.omega6Fat
        case .potassium: \.micros?.potassiumMg
        case .calcium: \.micros?.calciumMg
        case .iron: \.micros?.ironMg
        case .magnesium: \.micros?.magnesiumMg
        case .zinc: \.micros?.zincMg
        case .phosphorus: \.micros?.phosphorusMg
        case .selenium: \.micros?.seleniumMcg
        case .copper: \.micros?.copperMg
        case .manganese: \.micros?.manganeseMg
        case .vitaminA: \.micros?.vitaminAMcg
        case .vitaminC: \.micros?.vitaminCMg
        case .vitaminD: \.micros?.vitaminDMcg
        case .vitaminE: \.micros?.vitaminEMg
        case .vitaminK: \.micros?.vitaminKMcg
        case .thiamin: \.micros?.thiaminMg
        case .riboflavin: \.micros?.riboflavinMg
        case .niacin: \.micros?.niacinMg
        case .pantothenicAcid: \.micros?.pantothenicAcidMg
        case .vitaminB6: \.micros?.vitaminB6Mg
        case .folate: \.micros?.folateMcg
        case .vitaminB12: \.micros?.vitaminB12Mcg
        case .choline: \.micros?.cholineMg
        }
    }

    private var microsPath: WritableKeyPath<Micronutrients, Double?>? {
        switch self {
        case .transFat: \.transFat
        case .caffeine: \.caffeineMg
        case .alcohol: \.alcohol
        case .monounsaturatedFat: \.monounsaturatedFat
        case .polyunsaturatedFat: \.polyunsaturatedFat
        case .omega3: \.omega3Fat
        case .omega6: \.omega6Fat
        case .potassium: \.potassiumMg
        case .calcium: \.calciumMg
        case .iron: \.ironMg
        case .magnesium: \.magnesiumMg
        case .zinc: \.zincMg
        case .phosphorus: \.phosphorusMg
        case .selenium: \.seleniumMcg
        case .copper: \.copperMg
        case .manganese: \.manganeseMg
        case .vitaminA: \.vitaminAMcg
        case .vitaminC: \.vitaminCMg
        case .vitaminD: \.vitaminDMcg
        case .vitaminE: \.vitaminEMg
        case .vitaminK: \.vitaminKMcg
        case .thiamin: \.thiaminMg
        case .riboflavin: \.riboflavinMg
        case .niacin: \.niacinMg
        case .pantothenicAcid: \.pantothenicAcidMg
        case .vitaminB6: \.vitaminB6Mg
        case .folate: \.folateMcg
        case .vitaminB12: \.vitaminB12Mcg
        case .choline: \.cholineMg
        case .kcal, .protein, .carbs, .fat, .fiber, .sugars, .saturatedFat, .cholesterol, .sodium: nil
        }
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
    var micros = Micronutrients()

    /// Salt from sodium (1 g of sodium is 2.5 g of salt, the conversion on nutrition labels).
    var saltG: Double? { sodiumMg.map { $0 * 2.5 / 1_000 } }

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
            sodiumMg: add(lhs.sodiumMg, rhs.sodiumMg), cholesterolMg: add(lhs.cholesterolMg, rhs.cholesterolMg),
            micros: lhs.micros + rhs.micros
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
    /// Daily intakes of the adult reference values (Dietary Reference Intakes, National Academies),
    /// set for the person by `NutritionCalculator` once their age and gender are known.
    var potassiumMg: Double = 3_000
    var calciumMg: Double = 1_000
    var ironMg: Double = 13
    var magnesiumMg: Double = 360
    var vitaminCMg: Double = 85
    var vitaminAMcg: Double = 800
    var vitaminDMcg: Double = 15
    var vitaminB12Mcg: Double = 2.4
    var folateMcg: Double = 400
    // The nutrients of Premium: the average of the female and male references until the calculation
    // knows the person.
    /// Under 1 % of the calories (WHO).
    var transFatMax: Double = 2.4
    /// Health Canada's limit for adults.
    var caffeineMaxMg: Double = 400
    var omega3Fat: Double = 1.4
    var omega6Fat: Double = 15
    var zincMg: Double = 10
    var phosphorusMg: Double = 700
    var seleniumMcg: Double = 55
    var copperMg: Double = 0.9
    var manganeseMg: Double = 2.1
    var vitaminEMg: Double = 15
    var vitaminKMcg: Double = 105
    var thiaminMg: Double = 1.2
    var riboflavinMg: Double = 1.2
    var niacinMg: Double = 15
    var pantothenicAcidMg: Double = 5
    var vitaminB6Mg: Double = 1.3
    var cholineMg: Double = 488

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

    enum CodingKeys: String, CodingKey {
        case kcal, protein, carbs, fat, fiber, sugarsMax, saturatedFatMax, sodiumMaxMg
        case potassiumMg, calciumMg, ironMg, magnesiumMg, vitaminCMg, vitaminAMcg, vitaminDMcg, vitaminB12Mcg, folateMcg
        case transFatMax, caffeineMaxMg, omega3Fat, omega6Fat, zincMg, phosphorusMg, seleniumMcg, copperMg, manganeseMg
        case vitaminEMg, vitaminKMcg, thiaminMg, riboflavinMg, niacinMg, pantothenicAcidMg, vitaminB6Mg, cholineMg
    }

    subscript(target: NutritionTarget) -> Double {
        get { self[keyPath: target.goalPath] }
        set { self[keyPath: target.goalPath] = newValue }
    }

    /// Tolerant: goals saved before the limits or the nutrients of Premium existed keep their values.
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
        potassiumMg = c.value(.potassiumMg, d.potassiumMg)
        calciumMg = c.value(.calciumMg, d.calciumMg)
        ironMg = c.value(.ironMg, d.ironMg)
        magnesiumMg = c.value(.magnesiumMg, d.magnesiumMg)
        vitaminCMg = c.value(.vitaminCMg, d.vitaminCMg)
        vitaminAMcg = c.value(.vitaminAMcg, d.vitaminAMcg)
        vitaminDMcg = c.value(.vitaminDMcg, d.vitaminDMcg)
        vitaminB12Mcg = c.value(.vitaminB12Mcg, d.vitaminB12Mcg)
        folateMcg = c.value(.folateMcg, d.folateMcg)
        transFatMax = c.value(.transFatMax, d.transFatMax)
        caffeineMaxMg = c.value(.caffeineMaxMg, d.caffeineMaxMg)
        omega3Fat = c.value(.omega3Fat, d.omega3Fat)
        omega6Fat = c.value(.omega6Fat, d.omega6Fat)
        zincMg = c.value(.zincMg, d.zincMg)
        phosphorusMg = c.value(.phosphorusMg, d.phosphorusMg)
        seleniumMcg = c.value(.seleniumMcg, d.seleniumMcg)
        copperMg = c.value(.copperMg, d.copperMg)
        manganeseMg = c.value(.manganeseMg, d.manganeseMg)
        vitaminEMg = c.value(.vitaminEMg, d.vitaminEMg)
        vitaminKMcg = c.value(.vitaminKMcg, d.vitaminKMcg)
        thiaminMg = c.value(.thiaminMg, d.thiaminMg)
        riboflavinMg = c.value(.riboflavinMg, d.riboflavinMg)
        niacinMg = c.value(.niacinMg, d.niacinMg)
        pantothenicAcidMg = c.value(.pantothenicAcidMg, d.pantothenicAcidMg)
        vitaminB6Mg = c.value(.vitaminB6Mg, d.vitaminB6Mg)
        cholineMg = c.value(.cholineMg, d.cholineMg)
    }
}

/// A daily target of « Mes infos › Nutrition »: calculated from the person's body, aim and activity,
/// or typed by them (then kept as they are when the calculation changes). Each one is the target of the
/// nutrient of the same name; cholesterol, alcohol and the mono- and polyunsaturated fats have none.
enum NutritionTarget: String, Codable, CaseIterable, Identifiable {
    case kcal, protein, carbs, fat, fiber
    case sugars, saturatedFat, transFat, sodium, caffeine
    case omega3, omega6
    case potassium, calcium, iron, magnesium, zinc, phosphorus, selenium, copper, manganese
    case vitaminA, vitaminC, vitaminD, vitaminE, vitaminK, thiamin, riboflavin, niacin, pantothenicAcid, vitaminB6, folate, vitaminB12, choline
    var id: String { rawValue }

    typealias Group = Nutrient.Group

    var nutrient: Nutrient { Nutrient(rawValue: rawValue) ?? .kcal }

    var group: Group { nutrient.group }

    /// A ceiling not to go over (sugars, saturated and trans fats, sodium, caffeine), rather than an amount
    /// to reach.
    var isLimit: Bool { group == .limits }

    /// Every target but the calories and the three macronutrients.
    var isPremium: Bool { nutrient.isPremium }

    var title: String { nutrient.title }

    var unit: String { nutrient.unit }

    /// Decimals worth showing (2,4 µg of B12, 13 mg of iron, 2 100 kcal).
    var decimals: Int { nutrient.decimals }

    var goalPath: WritableKeyPath<NutritionGoals, Double> {
        switch self {
        case .kcal: \.kcal
        case .protein: \.protein
        case .carbs: \.carbs
        case .fat: \.fat
        case .fiber: \.fiber
        case .sugars: \.sugarsMax
        case .saturatedFat: \.saturatedFatMax
        case .transFat: \.transFatMax
        case .sodium: \.sodiumMaxMg
        case .caffeine: \.caffeineMaxMg
        case .omega3: \.omega3Fat
        case .omega6: \.omega6Fat
        case .potassium: \.potassiumMg
        case .calcium: \.calciumMg
        case .iron: \.ironMg
        case .magnesium: \.magnesiumMg
        case .zinc: \.zincMg
        case .phosphorus: \.phosphorusMg
        case .selenium: \.seleniumMcg
        case .copper: \.copperMg
        case .manganese: \.manganeseMg
        case .vitaminA: \.vitaminAMcg
        case .vitaminC: \.vitaminCMg
        case .vitaminD: \.vitaminDMcg
        case .vitaminE: \.vitaminEMg
        case .vitaminK: \.vitaminKMcg
        case .thiamin: \.thiaminMg
        case .riboflavin: \.riboflavinMg
        case .niacin: \.niacinMg
        case .pantothenicAcid: \.pantothenicAcidMg
        case .vitaminB6: \.vitaminB6Mg
        case .folate: \.folateMcg
        case .vitaminB12: \.vitaminB12Mcg
        case .choline: \.cholineMg
        }
    }

    /// What a day's foods add up to, nil when no food eaten gave the value.
    func eaten(_ totals: NutritionTotals) -> Double? { nutrient.value(in: totals) }

    /// The value on a food (per 100 g), to know whether a day's total is complete.
    var foodPath: KeyPath<FoodItem, Double?>? { nutrient.foodPath }

    /// The targets that follow the calories when only the calories were typed by hand.
    var followsCalories: Bool { [.protein, .carbs, .fat, .fiber, .sugars, .saturatedFat, .transFat].contains(self) }

    /// The facts widgets read as « the person's own target ».
    var providedFact: ProvidedFact? {
        switch self {
        case .kcal: .kcalTarget
        case .protein: .proteinTarget
        case .carbs: .carbsTarget
        case .fat: .fatTarget
        default: nil
        }
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

    /// The steps of the calculation, shown under « Comment c'est calculé ».
    struct Breakdown: Hashable {
        /// Resting energy (Mifflin-St Jeor, 1990).
        var restingKcal: Double
        /// With the activity factor: the energy spent in a day.
        var dailyKcal: Double
        /// The aim's change (−15 %, 0, +10 %).
        var goalAdjustment: Double
        /// Grams of protein per kilogram of body weight.
        var proteinPerKg: Double
    }

    /// Grams of protein per kilogram: more to keep muscle while losing weight or to build it, more with
    /// training (International Society of Sports Nutrition: 1,4 to 2,0 g/kg for active people), and at
    /// least the adult reference otherwise.
    static func proteinPerKg(activity: Activity, goal: Goal) -> Double {
        switch goal {
        case .lose: 1.8
        case .gain: 2.0
        case .maintain: activity == .sedentary || activity == .light ? 1.2 : 1.6
        }
    }

    static func breakdown(sex: Sex, age: Int, heightCm: Double, weightKg: Double, activity: Activity, goal: Goal) -> Breakdown {
        let resting = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + sex.offset
        return Breakdown(restingKcal: resting.rounded(), dailyKcal: (resting * activity.rawValue).rounded(),
                         goalAdjustment: goal.rawValue, proteinPerKg: proteinPerKg(activity: activity, goal: goal))
    }

    /// Every daily target from the body, the activity and the aim:
    /// - calories: Mifflin-St Jeor × activity factor × aim (−15 % to lose, +10 % to gain), 1 400 at least;
    /// - protein: `proteinPerKg` × weight, within 35 % of the calories (the upper bound of the AMDR);
    /// - fat: 28 % of the calories (AMDR 20–35 %); carbohydrates: the rest;
    /// - fibre: 14 g per 1 000 kcal (Dietary Guidelines); sugars and saturated fat: under 10 % of the
    ///   calories each (WHO); sodium: under 2 300 mg (Health Canada);
    /// - minerals and vitamins: the Dietary Reference Intakes for the age and gender (the average of both
    ///   references for `neutral`);
    /// - Premium: trans fat under 1 % of the calories (WHO), caffeine 400 mg at most (Health Canada),
    ///   omega-3 and omega-6 at the adequate intakes of alpha-linolenic and linoleic acids, and the
    ///   Dietary Reference Intakes of the other minerals and vitamins (none for cholesterol or alcohol).
    /// `kcal`: calories typed by the person, which the macronutrients then follow.
    static func goals(sex: Sex, age: Int, heightCm: Double, weightKg: Double, activity: Activity, goal: Goal, kcal typed: Double? = nil) -> NutritionGoals {
        let steps = breakdown(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg, activity: activity, goal: goal)
        let kcal = typed ?? max(1_400, (steps.dailyKcal * (1 + goal.rawValue)).rounded())
        let protein = min(weightKg * steps.proteinPerKg, kcal * 0.35 / 4).rounded()
        let fat = (kcal * 0.28 / 9).rounded()
        let carbs = max(0, ((kcal - protein * 4 - fat * 9) / 4).rounded())
        var goals = NutritionGoals(kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: (kcal / 1_000 * 14).rounded(),
                                   sugarsMax: (kcal * 0.10 / 4).rounded(), saturatedFatMax: (kcal * 0.10 / 9).rounded(), sodiumMaxMg: 2_300)
        let reference = References(sex: sex)
        goals.potassiumMg = reference.value(female: 2_600, male: 3_400)
        goals.calciumMg = reference.value(female: age > 50 ? 1_200 : 1_000, male: age > 70 ? 1_200 : 1_000)
        goals.ironMg = reference.value(female: age > 50 ? 8 : 18, male: 8)
        goals.magnesiumMg = reference.value(female: age > 30 ? 320 : 310, male: age > 30 ? 420 : 400)
        goals.vitaminCMg = reference.value(female: 75, male: 90)
        goals.vitaminAMcg = reference.value(female: 700, male: 900)
        goals.vitaminDMcg = age > 70 ? 20 : 15
        goals.vitaminB12Mcg = 2.4
        goals.folateMcg = 400
        // The nutrients of Premium.
        goals.transFatMax = (kcal * 0.01 / 9 * 10).rounded() / 10
        goals.caffeineMaxMg = 400
        goals.omega3Fat = reference.value(female: 1.1, male: 1.6, places: 1)
        goals.omega6Fat = reference.value(female: age > 50 ? 11 : 12, male: age > 50 ? 14 : 17)
        goals.zincMg = reference.value(female: 8, male: 11)
        goals.phosphorusMg = 700
        goals.seleniumMcg = 55
        goals.copperMg = 0.9
        goals.manganeseMg = reference.value(female: 1.8, male: 2.3, places: 1)
        goals.vitaminEMg = 15
        goals.vitaminKMcg = reference.value(female: 90, male: 120)
        goals.thiaminMg = reference.value(female: 1.1, male: 1.2, places: 1)
        goals.riboflavinMg = reference.value(female: 1.1, male: 1.3, places: 1)
        goals.niacinMg = reference.value(female: 14, male: 16)
        goals.pantothenicAcidMg = 5
        goals.vitaminB6Mg = age > 50 ? reference.value(female: 1.5, male: 1.7, places: 1) : 1.3
        goals.cholineMg = reference.value(female: 425, male: 550)
        return goals
    }

    /// The adult reference values of the gender used by the formula.
    private struct References {
        let sex: Sex

        /// `places`: the decimals the average of both keeps (1,15 mg of thiamin → 1,2).
        func value(female: Double, male: Double, places: Int = 0) -> Double {
            let factor = pow(10, Double(places))
            switch sex {
            case .female: return female
            case .male: return male
            case .neutral: return ((female + male) * factor / 2).rounded() / factor
            }
        }
    }
}
