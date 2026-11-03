import Foundation

// The food data behind one door: search, one food by identifier, its portions, densities and cooking yields, and
// where each value comes from. The scanner and the nutrition screens only know `FoodRepository`; what answers is
// `SQLiteFoodRepository` (App/Core, reads `ardane-food.sqlite`) or, where that file is absent, the old
// `cnf-foods.json` through `NutrientFile`.
//
// This file has no SQLite and no UIKit: it is compiled in the widget extension too, which never has the database.

/// Codes of the nutrients of the pack: the `Nutrient_Code` of the Canadian Nutrient File 2026 (the same numbers as
/// the USDA nutrient numbers), and two totals Ardane derives. A value the pack does not have is unknown, never 0.
enum FoodNutrientCode {
    static let protein = 203
    static let fat = 204
    static let carbs = 205
    static let alcohol = 221
    static let energy = 208
    static let caffeine = 262
    static let sugars = 269
    static let fibre = 291
    static let calcium = 301
    static let iron = 303
    static let potassium = 306
    static let sodium = 307
    static let vitaminK = 430
    static let cholesterol = 601
    static let saturatedFat = 606
    /// Sum of the omega-3 fatty acids of the food, derived by Ardane (the 2026 file has no total).
    static let omega3 = 10001
    /// Sum of the omega-6 fatty acids of the food, derived by Ardane.
    static let omega6 = 10002
}

/// Where a nutrient value comes from.
struct RepositoryProvenance: Hashable {
    /// What kind of evidence stands behind a value, the same for every source.
    enum Kind: Int {
        case analytical = 1, calculated, imputed, assumedZero, usda, label, other, provisional, international
        /// Added up by Ardane from other values of the same food.
        case derived
    }

    /// `Nutrient_Source_Code` of the Canadian file, or the USDA derivation identifier; nil when the file gives none.
    var sourceCode: Int?
    var kind: Kind?
    /// The wording of the source code, in French when the file has it.
    var label: String?
    var observations: Int?
    var standardError: Double?

    var isDerived: Bool { kind == .derived }
}

/// One way to measure a food: a household measure (« 1 medium », « 250 ml »), the inedible part, or another conversion.
struct RepositoryPortion: Hashable {
    enum Kind: Int {
        /// The weight of a measure, in grams.
        case household = 6
        /// Percentage of the food that is not eaten (bones, peel…), as the file publishes it.
        case refuse = 3
        /// Other conversion of the Canadian file (« amount to make 250 ml »).
        case conversion = 9
    }

    var label: String
    var grams: Double
    var kind: Kind
    /// The serving the app proposes by default.
    var isDefault: Bool
    /// Set when the measure is a volume.
    var milliliters: Double?
}

/// The apparent density of a food in g/ml, derived from one of its household measures in volume.
struct RepositoryDensity: Hashable {
    enum Kind: Int {
        /// « 250 ml »: a cup of the food as the file describes it.
        case plain = 1
        /// « 250 ml chopped »: pieces, with air between them.
        case pieces
        /// « 250 ml mashed »: no air between the parts.
        case dense
        /// « 1 can (284 ml) »: the contents of a container, a true density.
        case container
    }

    var gPerMl: Double
    var kind: Kind
    var measure: String
    var measureGrams: Double
    var milliliters: Double
}

/// A USDA cooking yield of a cooked meat or poultry: the percentage of the raw weight that is left.
struct RepositoryYield: Hashable {
    var method: String
    var percent: Double
    var observations: Int?
    var standardDeviation: Double?
    var minimumPercent: Double?
    var maximumPercent: Double?
    var moistureChangePercent: Double?
    var fatChangePercent: Double?
    /// The raw food, when the pack has it.
    var rawFoodID: String?

    /// Cooked weight ÷ raw weight.
    var factor: Double { percent / 100 }
}

/// Warnings the build of the pack raises on a food. Nothing is corrected: the values are the source's.
struct FoodQualityFlags: OptionSet {
    let rawValue: Int

    /// The energy differs from 4 kcal/g protein and carbohydrate, 9 kcal/g fat, 7 kcal/g alcohol by more than
    /// `FoodEnergyCheck`'s tolerance.
    static let energy = FoodQualityFlags(rawValue: 1)
    static let macrosOver100g = FoodQualityFlags(rawValue: 2)
    static let fibreOverCarbs = FoodQualityFlags(rawValue: 4)
    static let sugarsOverCarbs = FoodQualityFlags(rawValue: 8)
    static let saturatedOverFat = FoodQualityFlags(rawValue: 16)
}

/// Raw or cooked, deduced from the names of the food (the sources have no such field).
enum FoodPreparationState: Int {
    case notStated = 0, raw, cooked
    /// Canned, frozen, dried, pickled, cured, smoked.
    case processed
}

/// The energy check of the build (`scripts/food_db/build.py`, `quality_flags`), the same rule.
enum FoodEnergyCheck {
    /// The tolerance is the larger of this many kilocalories…
    static let toleranceKcal = 15.0
    /// … and this share of the published energy.
    static let toleranceRatio = 0.15

    /// kcal per 100 g from the macros (4, 4, 9 and 7 for alcohol), or nil when a macro is unknown.
    static func energyFromMacros(protein: Double?, carbs: Double?, fat: Double?, alcohol: Double?) -> Double? {
        guard let protein, let carbs, let fat else { return nil }
        return 4 * protein + 4 * carbs + 9 * fat + 7 * (alcohol ?? 0)
    }

    /// True when the published energy is within the tolerance of the energy of the macros; true too when a macro is
    /// unknown (nothing to compare).
    static func isConsistent(kcal: Double, protein: Double?, carbs: Double?, fat: Double?, alcohol: Double? = nil) -> Bool {
        guard let computed = energyFromMacros(protein: protein, carbs: carbs, fat: fat, alcohol: alcohol) else { return true }
        return abs(kcal - computed) <= max(toleranceKcal, toleranceRatio * kcal)
    }

    /// The same check on a food of the repository (its unknown macros are left out).
    static func isConsistent(_ food: FoodItem) -> Bool {
        isConsistent(kcal: food.kcal, protein: food.knownProtein, carbs: food.knownCarbs, fat: food.knownFat, alcohol: food.micros?.alcohol)
    }
}

/// The door to the food data. `preferFrench` picks the French name where the source has one (the USDA foods have
/// only an English name).
protocol FoodRepository: AnyObject {
    /// The foods whose names (or alternate names) have a word starting with every word of the query, accents and case
    /// ignored; the closest and shortest names first.
    func search(_ query: String, limit: Int, preferFrench: Bool) -> [FoodItem]
    /// One food. `cnf.<number>` identifiers of the earlier edition are resolved through the alias table; nil when the
    /// identifier is not (or no longer) in the repository.
    func item(id: String, preferFrench: Bool) -> FoodItem?
    /// The identifier the repository uses today for this one (the same, or the alias); nil when unknown.
    func resolvedID(of id: String) -> String?
    func portions(id: String, preferFrench: Bool) -> [RepositoryPortion]
    /// Every density derived for the food, the most representative first. Empty: no density, never a made-up one.
    func densities(id: String) -> [RepositoryDensity]
    func cookingYields(id: String) -> [RepositoryYield]
    /// Where the value of a nutrient (a `FoodNutrientCode`, or any code of the pack) comes from; nil when the pack has
    /// no value for it.
    func provenance(id: String, nutrient: Int) -> RepositoryProvenance?
    func qualityFlags(id: String) -> FoodQualityFlags?
    func preparationState(id: String) -> FoodPreparationState?
}

extension FoodRepository {
    func search(_ query: String, limit: Int = 60) -> [FoodItem] {
        search(query, limit: limit, preferFrench: Localization.isFrench)
    }

    func item(id: String) -> FoodItem? {
        item(id: id, preferFrench: Localization.isFrench)
    }

    func portions(id: String) -> [RepositoryPortion] {
        portions(id: id, preferFrench: Localization.isFrench)
    }

    /// The density to use for a food: the first of `densities(id:)`.
    func density(id: String) -> RepositoryDensity? {
        densities(id: id).first
    }
}
