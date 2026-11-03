import Foundation

// Mass of a food: m = V × ρ, with the density ρ read from `food-densities.json` (built from the Canadian Nutrient
// File by `scripts/build_food_densities.py`) and a personal factor learned from the corrections of the person.
// Masses in g, volumes in ml (= cm³), densities in g/ml.

/// How a household measure of the Canadian Nutrient File was written, hence what its density means.
enum DensityMeasureKind: String, Hashable, Sendable {
    /// « 125ml »: a cup of the food as the file describes it. Dense for a liquid, a cream or a canned fruit, but a
    /// cup of cooked meat or rice is a cup of crumbs or grains, air included (the median of the meats is 0.575 g/ml
    /// for the `plain` cups as it is 0.566 for the `pieces` cups): `plain` does not mean « solid ».
    case plain
    /// « 250ml chopped », « 125ml cubes »: a cup of cut pieces, the air between them included.
    case pieces
    /// « 1 can (284 ml) »: the contents of a container, a true density.
    case container

    /// True for a density of the food itself, with no air between pieces: the only kind that can describe a solid
    /// piece (a steak, a fillet, an egg, a whole fruit). `plain` and `pieces` are densities of a heap or of loose
    /// food, far under the density of the solid (a steak is not a cup of crumbs).
    var isTrueDensity: Bool { self == .container }
}

/// The apparent density of one food of the Canadian Nutrient File, with its provenance: grams of the measure and
/// the text of the measure.
struct MeasuredDensity: Hashable, Sendable {
    var gPerMl: Double
    var measure: String
    var measureGrams: Double
    var kind: DensityMeasureKind
}

/// The density of a family of foods (the 10 families of `FoodCategory`): the median of its measured foods.
struct FamilyDensityPrior: Hashable, Sendable {
    var family: String
    var sampleCount: Int
    var gPerMl: Double
    var p25: Double
    var p75: Double
    /// The standard deviation of ln(density) among those foods.
    var spreadLog: Double
}

/// Where a density comes from, to show it honestly.
enum DensityProvenance: Hashable, Sendable {
    /// The food's own household measure.
    case measured(foodID: String, measure: String, measureGrams: Double)
    /// No density for this food: the median of its family.
    case family(name: String, sampleCount: Int)
    /// Not even a family: the median of every food of the file.
    case overall(sampleCount: Int)
}

/// A density as a log-normal estimate (g/ml), and where it comes from.
struct DensityLookup: Hashable, Sendable {
    var estimate: ScanEstimate
    var provenance: DensityProvenance
}

/// The densities of `food-densities.json`. Never a value made up: a food with a household measure in ml has its own
/// density; any other has the density of its family with a wide σ; with no table at all there is no density.
struct FoodDensityTable: Sendable {
    /// À MESURER: the σ of ln(density) for a household measure in ml. A cup of cooked rice is not the heap on the plate.
    static let measuredSigmaLog = 0.20
    /// À MESURER: the same for the contents of a container (a can of soup), a true density.
    static let containerSigmaLog = 0.10
    /// The σ of ln(density) is never under this for a family or for the whole file: a prior, not a precise value.
    static let familySigmaFloor = 0.30
    /// The filter of the table (g/ml), applied again when the file is read.
    static let densityRange = 0.15...2.0

    let measures: [Int: MeasuredDensity]
    let families: [String: FamilyDensityPrior]
    let overall: FamilyDensityPrior?
    /// The family of the CNF foods that have no density of their own (by CNF identifier).
    let familyOfOtherFoods: [Int: String]

    init(
        measures: [Int: MeasuredDensity] = [:], families: [String: FamilyDensityPrior] = [:],
        overall: FamilyDensityPrior? = nil, familyOfOtherFoods: [Int: String] = [:]
    ) {
        self.measures = measures
        self.families = families
        self.overall = overall
        self.familyOfOtherFoods = familyOfOtherFoods
    }

    static let empty = FoodDensityTable()

    var isEmpty: Bool { measures.isEmpty && families.isEmpty && overall == nil }

    /// The table bundled with the app (`food-densities.json`). Empty where the file is absent (the widget extension).
    static let bundled: FoodDensityTable = {
        guard let url = Bundle.main.url(forResource: "food-densities", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return FoodDensityTable.empty }
        return FoodDensityTable.decode(data) ?? FoodDensityTable.empty
    }()

    // MARK: Reading the file

    /// Tolerant: a row or a family that is not as expected is skipped, a density outside `densityRange` is dropped.
    /// Nil when the data is not a JSON object.
    static func decode(_ data: Data) -> FoodDensityTable? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        func number(_ value: Any?) -> Double? { (value as? NSNumber)?.doubleValue }

        var measures: [Int: MeasuredDensity] = [:]
        for row in (root["foods"] as? [[Any]]) ?? [] where row.count >= 4 {
            guard let id = (row[0] as? NSNumber)?.intValue, let density = number(row[1]), densityRange.contains(density),
                  let measure = row[2] as? String, let grams = number(row[3]), grams.isFinite, grams > 0 else { continue }
            let kindText: String? = row.count > 4 ? row[4] as? String : nil
            let kind = kindText.flatMap { DensityMeasureKind(rawValue: $0) } ?? .plain
            measures[id] = MeasuredDensity(gPerMl: density, measure: measure, measureGrams: grams, kind: kind)
        }

        func prior(_ name: String, _ value: Any?) -> FamilyDensityPrior? {
            guard let record = value as? [String: Any], let density = number(record["gPerMl"]), densityRange.contains(density),
                  let count = (record["n"] as? NSNumber)?.intValue, count > 0 else { return nil }
            return FamilyDensityPrior(
                family: name, sampleCount: count, gPerMl: density, p25: number(record["p25"]) ?? density,
                p75: number(record["p75"]) ?? density, spreadLog: max(0, number(record["spreadLog"]) ?? 0)
            )
        }
        var families: [String: FamilyDensityPrior] = [:]
        for (name, value) in (root["categories"] as? [String: Any]) ?? [:] {
            if let family = prior(name, value) { families[name] = family }
        }

        var familyOfOtherFoods: [Int: String] = [:]
        for (name, value) in (root["familyOfOtherFoods"] as? [String: Any]) ?? [:] {
            for item in (value as? [Any]) ?? [] {
                if let id = (item as? NSNumber)?.intValue { familyOfOtherFoods[id] = name }
            }
        }
        return FoodDensityTable(
            measures: measures, families: families, overall: prior("overall", root["overall"]), familyOfOtherFoods: familyOfOtherFoods
        )
    }

    // MARK: Lookup

    /// « cnf.4464 » → 4464 (the identifier of a Canadian Nutrient File food as `NutrientFile` writes it).
    static func cnfIdentifier(of foodID: String) -> Int? {
        guard foodID.hasPrefix("cnf.") else { return nil }
        return Int(foodID.dropFirst(4))
    }

    /// The density of a food as an estimate in g/ml.
    ///
    /// - A food with a household measure in ml has its own density (σ 0.20, 0.10 for a container).
    /// - Otherwise the density of its family: `family` if given, else the family of the built-in table, else the
    ///   family the file knows for a CNF food. σ is the spread of the family, at least 0.30. It is the median of all
    ///   the cups of the family, `plain` and `pieces` mixed: a prior of loose food. The file does not split it by
    ///   kind of measure, and the split would not make a solid of it (see `DensityMeasureKind.plain`).
    /// - Otherwise the median of the whole file (same σ rule). With an empty table: nil, never an invented value.
    /// - `isSolidPiece` has NO default value: the caller says what is on the plate.
    ///   - A heap or a loose food (rice, salad, ground or diced meat, cut fruit): `false`. Every measure of the
    ///     file and the density of the family are densities of that kind of food (a cup, air included).
    ///   - A solid piece (a steak, a fillet, an egg, a whole fruit): `true`. The cups of the file are far too low
    ///     for it (the family of the meats is 0.57 g/ml per cup: the mass of a steak would be about 45 % too low,
    ///     outside the interval), and the table has no density of solid pieces. Only the contents of a container
    ///     (a true density, `DensityMeasureKind.isTrueDensity`) are offered; otherwise nil, never a family density,
    ///     and the quantity has to come from elsewhere (the usual portion).
    func lookup(for food: FoodItem, family: FoodCategory? = nil, isSolidPiece: Bool) -> DensityLookup? {
        let cnfID = Self.cnfIdentifier(of: food.id)
        if let cnfID, let measured = measures[cnfID] {
            if isSolidPiece && !measured.kind.isTrueDensity { return nil }
            let sigma = measured.kind == .container ? Self.containerSigmaLog : Self.measuredSigmaLog
            guard let estimate = ScanEstimate(median: measured.gPerMl, sigmaLog: sigma, sources: [.measuredDensity]) else { return nil }
            return DensityLookup(
                estimate: estimate, provenance: .measured(foodID: food.id, measure: measured.measure, measureGrams: measured.measureGrams)
            )
        }
        if isSolidPiece { return nil }
        let familyName = family?.rawValue ?? FoodDatabase.category(of: food)?.rawValue ?? cnfID.flatMap { familyOfOtherFoods[$0] }
        if let familyName, let prior = families[familyName],
           let estimate = ScanEstimate(
               median: prior.gPerMl, sigmaLog: max(Self.familySigmaFloor, prior.spreadLog), sources: [.categoryDensity]
           ) {
            return DensityLookup(estimate: estimate, provenance: .family(name: familyName, sampleCount: prior.sampleCount))
        }
        if let overall,
           let estimate = ScanEstimate(
               median: overall.gPerMl, sigmaLog: max(Self.familySigmaFloor, overall.spreadLog), sources: [.categoryDensity]
           ) {
            return DensityLookup(estimate: estimate, provenance: .overall(sampleCount: overall.sampleCount))
        }
        return nil
    }
}

// MARK: - Personal factor

/// What the person's corrections say about the quantities the scanner proposes: r = grams validated / grams
/// proposed, as a multiplicative factor on the next mass.
///
/// - The factor is the geometric median of the ratios of the VALID corrections (the ones `ScanLearning` did not
///   quarantine, with a ratio not ten times off), pulled toward 1 when there are few: the weight of the data is
///   n / (n + 3), so 3 corrections give half of the correction, 30 give 91 %.
/// - It is learned per food from `ScanLearning.minimumAgreeing` corrections; with fewer, from all the foods
///   together (5 corrections at least); with fewer still, there is none (factor 1).
/// - It is kept between ×0.5 and ×2: a person is not twice off for ever, a wrong habit must not run away.
/// - The corrections stored by the previous pipeline compare the usual portion with the weight kept: they are in
///   the same list (the correction has no mark of the pipeline yet).
struct PersonalQuantityFactor: Hashable, Sendable {
    enum Scope: String, Hashable, Sendable {
        /// Nothing learned yet: the factor is 1.
        case unlearned
        case food
        case global
    }

    var factor: Double
    var scope: Scope
    var sampleCount: Int

    /// À MESURER: the weight of the prior (1, no correction) in the shrinking, in corrections.
    static let priorStrength = 3.0
    /// À MESURER: the fewest corrections, all foods together, to apply a global factor.
    static let globalMinimumSamples = 5
    static let bounds = 0.5...2.0

    static let identity = PersonalQuantityFactor(factor: 1, scope: .unlearned, sampleCount: 0)

    /// The ratios validated / proposed of the corrections that can be used.
    static func ratios(of corrections: [ScanCorrection]) -> [Double] {
        corrections.compactMap { correction -> Double? in
            guard !correction.quarantined, let initial = correction.initialGrams, initial.isFinite, initial > 0,
                  correction.validatedGrams.isFinite, correction.validatedGrams > 0 else { return nil }
            let ratio = correction.validatedGrams / initial
            guard ratio <= ScanLearning.outlierFactor, ratio >= 1 / ScanLearning.outlierFactor else { return nil }
            return ratio
        }
    }

    private static func shrunk(_ ratios: [Double], scope: Scope) -> PersonalQuantityFactor {
        let logs = ratios.map { log($0) }.sorted()
        let middle = logs.count / 2
        let medianLog = logs.count % 2 == 1 ? logs[middle] : (logs[middle - 1] + logs[middle]) / 2
        let weight = Double(logs.count) / (Double(logs.count) + priorStrength)
        let factor = min(bounds.upperBound, max(bounds.lowerBound, exp(weight * medianLog)))
        return PersonalQuantityFactor(factor: factor, scope: scope, sampleCount: logs.count)
    }

    static func learn(from learning: ScanLearning, foodID: String) -> PersonalQuantityFactor {
        let ofFood = ratios(of: learning.corrections.filter { $0.validatedFoodID == foodID })
        if ofFood.count >= ScanLearning.minimumAgreeing { return shrunk(ofFood, scope: .food) }
        let overall = ratios(of: learning.corrections)
        if overall.count >= globalMinimumSamples { return shrunk(overall, scope: .global) }
        return identity
    }

    /// The estimate with its median multiplied by the factor (and the personal factor among its sources). The
    /// estimate itself when there is no factor to apply.
    func applying(to estimate: ScanEstimate) -> ScanEstimate {
        guard scope != .unlearned, let corrected = estimate.scaled(by: factor, adding: .personalFactor) else { return estimate }
        return corrected
    }
}

// MARK: - Mass

enum ScanMass {
    /// m = V × ρ: the medians multiply, σ² = σ_V² + σ_ρ² (independent errors). Nil when the product is not a
    /// positive finite number.
    static func mass(volume: ScanEstimate, density: ScanEstimate) -> ScanEstimate? {
        volume.multiplied(by: density)
    }
}

/// An estimate of a mass in g from a volume in ml. `isSolidPiece` is always given by the caller (see
/// `FoodDensityTable.lookup`): there is deliberately no shortcut without it, because the default that was there
/// (`false`, a heap) gave a steak the density of a cup of crumbs. Nil when no density fits: the quantity then comes
/// from the usual portion.
protocol FoodMassEstimating {
    func estimateMass(volume: ScanEstimate, food: FoodItem, family: FoodCategory?, isSolidPiece: Bool) -> ScanEstimate?
}

/// The mass by density, then corrected by what the person taught the app. Nil when there is no density.
struct DensityMassEstimator: FoodMassEstimating {
    var table: FoodDensityTable
    var personalFactor: PersonalQuantityFactor

    init(table: FoodDensityTable = FoodDensityTable.bundled, personalFactor: PersonalQuantityFactor = PersonalQuantityFactor.identity) {
        self.table = table
        self.personalFactor = personalFactor
    }

    func estimateMass(volume: ScanEstimate, food: FoodItem, family: FoodCategory?, isSolidPiece: Bool) -> ScanEstimate? {
        guard let density = table.lookup(for: food, family: family, isSolidPiece: isSolidPiece),
              let mass = ScanMass.mass(volume: volume, density: density.estimate) else { return nil }
        return personalFactor.applying(to: mass)
    }
}
