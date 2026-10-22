import Foundation

/// One food of the recap shown after a scan, with the quantity that will be logged.
///
/// - `isEstimate` false: the food comes from a table or from the person (a product found by its
///   barcode, a food of the table, a custom food) and the quantity is theirs.
/// - `isEstimate` true: the food and its portion were guessed from a photo of a dish. The calories
///   and macronutrients are computed from the values of the food, for the estimated quantity.
struct ScanLine: Identifiable, Hashable {
    let id: UUID
    var food: FoodItem
    var grams: Double
    var isEstimate: Bool
    /// How sure the photo analysis is of the food (0 to 1). Nil for a food chosen by the person.
    var confidence: Double?

    init(id: UUID = UUID(), food: FoodItem, grams: Double, isEstimate: Bool = false, confidence: Double? = nil) {
        self.id = id
        self.food = food
        self.grams = grams
        self.isEstimate = isEstimate
        self.confidence = confidence
    }

    var totals: NutritionTotals { food.nutrients(grams: grams) }

    /// An estimate the analysis is not sure of.
    var isLowConfidence: Bool {
        guard isEstimate, let confidence else { return false }
        return confidence < ScanRecap.lowConfidence
    }

    /// « peu sûr » / « assez sûr »: the confidence in words, only for an estimate that has one.
    var confidenceWord: String? {
        guard isEstimate, confidence != nil else { return nil }
        return isLowConfidence ? tr("peu sûr") : tr("assez sûr")
    }
}

/// What a scan found, editable before it is logged: a product read from a barcode, or the foods
/// guessed from the photo of a dish. Pure logic with no view, so it can be tested; the screen only
/// shows it.
struct ScanRecap: Hashable {
    static let minGrams = 1.0
    static let maxGrams = 5_000.0
    /// Under this confidence an estimate is shown as « peu sûr ».
    static let lowConfidence = 0.5

    var lines: [ScanLine] = []

    init(lines: [ScanLine] = []) {
        self.lines = lines
    }

    /// The foods guessed from a photo: each one an estimate, in its usual portion.
    init(proposals: [MealProposal]) {
        for proposal in proposals { add(proposal) }
    }

    /// One food chosen or found by its barcode, in its usual portion (not an estimate).
    init(food: FoodItem) {
        add(food)
    }

    // MARK: Editing

    /// A quantity kept between `minGrams` and `maxGrams`.
    static func clamped(_ grams: Double) -> Double {
        guard grams.isFinite else { return minGrams }
        return min(maxGrams, max(minGrams, grams))
    }

    private static func usualGrams(of food: FoodItem) -> Double {
        food.servingGrams > 0 ? food.servingGrams : 100
    }

    /// Adds a food (its usual portion unless `grams` is given). A food already in the recap is not added
    /// twice: its quantity grows. Returns the id of the line.
    @discardableResult
    mutating func add(_ food: FoodItem, grams: Double? = nil, isEstimate: Bool = false, confidence: Double? = nil) -> UUID {
        let amount = Self.clamped(grams ?? Self.usualGrams(of: food))
        let line = ScanLine(food: food, grams: amount, isEstimate: isEstimate, confidence: confidence)
        lines.append(line)
        lines = Self.merge(lines)
        return lines.first { $0.food.id == food.id }?.id ?? line.id
    }

    /// A food proposed from a photo, in the portion proposed, as an estimate.
    @discardableResult
    mutating func add(_ proposal: MealProposal) -> UUID {
        add(proposal.food, grams: proposal.grams, isEstimate: proposal.isEstimate, confidence: proposal.confidence)
    }

    mutating func remove(_ id: UUID) {
        lines.removeAll { $0.id == id }
    }

    /// Another food for the same line, with the same quantity. The line stays an estimate if it was one
    /// (the quantity still is), but the confidence belonged to the food that was replaced. If the new
    /// food is already in the recap, the two lines become one.
    mutating func replace(_ id: UUID, with food: FoodItem) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[index].food = food
        lines[index].confidence = nil
        lines = Self.merge(lines)
    }

    /// The quantity of a line, kept between `minGrams` and `maxGrams`. A value that is not a number is ignored.
    mutating func setGrams(_ id: UUID, _ grams: Double) {
        guard grams.isFinite, let index = lines.firstIndex(where: { $0.id == id }) else { return }
        lines[index].grams = Self.clamped(grams)
    }

    // MARK: Reading

    var isEmpty: Bool { lines.isEmpty }

    var totals: NutritionTotals {
        lines.reduce(NutritionTotals()) { $0 + $1.totals }
    }

    /// True when something in the recap is a guess.
    var hasEstimate: Bool { lines.contains { $0.isEstimate } }

    /// There is something to log, and every quantity is a real one.
    var canConfirm: Bool {
        !lines.isEmpty && lines.allSatisfy { $0.grams.isFinite && $0.grams >= Self.minGrams }
    }

    /// The recap with a food that appears on several lines kept once: the first line stays (id and place),
    /// the quantities are added, it is an estimate if one of the lines was, and it keeps the lowest confidence.
    var merged: ScanRecap {
        ScanRecap(lines: Self.merge(lines))
    }

    private static func merge(_ lines: [ScanLine]) -> [ScanLine] {
        var result: [ScanLine] = []
        for line in lines {
            guard let index = result.firstIndex(where: { $0.food.id == line.food.id }) else {
                result.append(line)
                continue
            }
            result[index].grams = clamped(result[index].grams + line.grams)
            result[index].isEstimate = result[index].isEstimate || line.isEstimate
            switch (result[index].confidence, line.confidence) {
            case let (a?, b?): result[index].confidence = min(a, b)
            case let (nil, b?): result[index].confidence = b
            default: break
            }
        }
        return result
    }

    // MARK: Logging

    /// Writes every line into the journal (a food seen twice is written once) and returns how many
    /// entries were added. A food already logged less than `window` seconds around `date` is a double
    /// tap or the same barcode scanned again: it is skipped, like the quick add of the widgets. A
    /// `window` of 0 turns that off (a day that is not today, where every entry gets the same usual time).
    @discardableResult
    func commit(into state: inout NutritionState, meal: MealType, at date: Date, window: TimeInterval = NutritionState.quickAddWindow) -> Int {
        var logged = 0
        for line in merged.lines where line.grams >= Self.minGrams {
            let foodID = line.food.id
            let isDoubleTap = window > 0 && state.entries.contains {
                $0.food.id == foodID && abs(date.timeIntervalSince($0.date)) < window
            }
            if isDoubleTap { continue }
            state.log(line.food, grams: line.grams, meal: meal, at: date)
            logged += 1
        }
        return logged
    }
}
