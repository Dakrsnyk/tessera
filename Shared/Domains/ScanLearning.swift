import Foundation

/// How a journal entry was created. Nil on the entries saved before this was recorded.
enum EntryOrigin: String, Codable, Hashable {
    /// Validated from the recap of a scan (barcode or photo).
    case scan
    /// Typed or picked by the person (search, favourites, widgets…).
    case manual
}

/// An interval for a quantity that is not exactly known (« ≈ 420–560 kcal »).
struct NutrientRange: Hashable {
    var low: Double
    var high: Double

    var midpoint: Double { (low + high) / 2 }

    static func + (lhs: NutrientRange, rhs: NutrientRange) -> NutrientRange {
        NutrientRange(low: lhs.low + rhs.low, high: lhs.high + rhs.high)
    }

    /// The bounds rounded to a multiple of `step` (low rounded down, high rounded up): a range shown to
    /// the person never looks more precise than it is.
    func rounded(to step: Double) -> NutrientRange {
        guard step > 0, low.isFinite, high.isFinite else { return self }
        return NutrientRange(low: (low / step).rounded(.down) * step, high: (high / step).rounded(.up) * step)
    }
}

/// How far off a quantity of a scan can be, as a share of its value, by where it comes from.
enum ScanUncertainty {
    /// A packaged product or a quantity the person typed (weighed): the label's own tolerance.
    static let weighed = 0.05
    /// The usual portion of a food of a table, not weighed.
    static let usualPortion = 0.30
    /// A food and a portion guessed from the photo of a dish.
    static let photoEstimate = 0.40

    static func range(of value: Double, ratio: Double) -> NutrientRange {
        NutrientRange(low: max(0, value * (1 - ratio)), high: value * (1 + ratio))
    }
}

/// One thing the person decided after a scan: what the analysis detected and what they kept. Stored on the
/// iPhone only.
struct ScanCorrection: Codable, Hashable {
    var date: Date
    /// The labels the photo analysis gave to the food (lowercase, without separators).
    var labels: [String]
    /// The food the analysis proposed for those labels (nil: the person added the food themselves).
    var detectedFoodID: String?
    /// The quantity proposed (nil: none was).
    var initialGrams: Double?
    var validatedFoodID: String
    var validatedGrams: Double
    /// A correction that looks wrong (an absurd quantity): kept for the record, never used to learn.
    var quarantined: Bool = false

    enum CodingKeys: String, CodingKey {
        case date, labels, detectedFoodID, initialGrams, validatedFoodID, validatedGrams, quarantined
    }
}

extension ScanCorrection {
    /// Tolerant: a missing or wrong field takes a harmless value, never an error.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = c.value(.date, Date(timeIntervalSince1970: 0))
        labels = c.value(.labels, [])
        detectedFoodID = c.optional(.detectedFoodID)
        initialGrams = c.optional(.initialGrams)
        validatedFoodID = c.value(.validatedFoodID, "")
        validatedGrams = c.value(.validatedGrams, 0)
        quarantined = c.value(.quarantined, false)
    }
}

/// What the app learned, on this iPhone, from the corrections of the person after a scan: which food they
/// usually keep for a label, and how much of it they usually eat. Nothing is sent anywhere.
///
/// - A preference counts only from `minimumAgreeing` agreeing corrections, so one correction never decides.
/// - The usual quantity of a food is the median of the valid corrections (one odd value moves it little),
///   and also needs `minimumAgreeing` of them.
/// - A correction outside the plausible quantities, or ten times away from the usual quantity of that food,
///   is quarantined: it stays in the list but is never used.
struct ScanLearning: Codable, Hashable {
    static let maximumCorrections = 500
    static let minimumAgreeing = 2
    /// A quantity this many times above (or below) the median of the food is quarantined.
    static let outlierFactor = 10.0

    var corrections: [ScanCorrection] = []
    /// « Contribuer à l'amélioration »: off by default. It sends nothing for now (there is no server): it
    /// only remembers the choice of the person.
    var contributionEnabled = false

    enum CodingKeys: String, CodingKey { case corrections, contributionEnabled }

    /// The quantities that make sense for a food: oils, butter and fat condiments are eaten by the
    /// spoonful, the rest by the plate.
    static func plausibleGrams(for food: FoodItem) -> ClosedRange<Double> {
        food.kcal >= 700 ? 1...100 : 5...1_500
    }

    // MARK: Recording

    /// Keeps a correction. Not finite, zero, negative quantities and corrections without a food are dropped;
    /// a quantity outside `plausibleGramsRange`, or ten times the median (or a tenth of it) of the valid
    /// corrections of the same food, is stored as quarantined. At most `maximumCorrections` are kept, the
    /// oldest go first.
    mutating func record(_ correction: ScanCorrection, plausibleGramsRange: ClosedRange<Double>) {
        var entry = correction
        guard entry.validatedGrams.isFinite, entry.validatedGrams > 0, !entry.validatedFoodID.isEmpty else { return }
        if let initial = entry.initialGrams, !(initial.isFinite && initial > 0) { entry.initialGrams = nil }
        if !plausibleGramsRange.contains(entry.validatedGrams) {
            entry.quarantined = true
        } else if let median = Self.median(validGrams(forFoodID: entry.validatedFoodID)),
                  entry.validatedGrams > median * Self.outlierFactor || entry.validatedGrams < median / Self.outlierFactor {
            entry.quarantined = true
        }
        corrections.append(entry)
        if corrections.count > Self.maximumCorrections {
            corrections.removeFirst(corrections.count - Self.maximumCorrections)
        }
    }

    // MARK: Reading

    private func validGrams(forFoodID id: String) -> [Double] {
        corrections.filter { !$0.quarantined && $0.validatedFoodID == id }.map(\.validatedGrams)
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }

    /// The food the person usually keeps for a label of the photo analysis, only when it is reliable: at
    /// least `minimumAgreeing` valid corrections for it, and at least twice as many as for all the others.
    func preferredFoodID(forLabel label: String) -> String? {
        let key = FoodLabelMatcher.cleaned(label)
        guard !key.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for correction in corrections where !correction.quarantined && !correction.validatedFoodID.isEmpty {
            if correction.labels.contains(where: { FoodLabelMatcher.cleaned($0) == key }) {
                counts[correction.validatedFoodID, default: 0] += 1
            }
        }
        guard let best = counts.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }) else { return nil }
        let others = counts.values.reduce(0, +) - best.value
        guard best.value >= Self.minimumAgreeing, best.value >= 2 * others else { return nil }
        return best.key
    }

    /// The quantity the person usually keeps for a food (median of the valid corrections), only from
    /// `minimumAgreeing` of them.
    func usualGrams(forFoodID id: String) -> Double? {
        let grams = validGrams(forFoodID: id)
        guard grams.count >= Self.minimumAgreeing else { return nil }
        return Self.median(grams)
    }
}

extension ScanLearning {
    /// Tolerant: a missing field is the empty / off value.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        corrections = c.value(.corrections, [])
        contributionEnabled = c.value(.contributionEnabled, false)
    }
}
